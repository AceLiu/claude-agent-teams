#!/usr/bin/env bash
# 在 tmux session 内循环执行多个任务
# 用法: worker-loop.sh <worker-role> <project-root> <task1> [task2] [task3] ...
set -euo pipefail

WORKER_ROLE="${1:?用法: worker-loop.sh <worker-role> <project-root> <task1> [task2] [task3] ...}"
PROJECT_ROOT="${2:?缺少 project-root 参数}"
shift 2

if [ $# -eq 0 ]; then
  echo "[ERROR] 至少需要一个 task 参数" >&2
  exit 1
fi

TASKS=("$@")
TOTAL=${#TASKS[@]}
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 辅助函数：写入 JSON 状态文件
# 用法: write_status <status> <task> <progress> [needs_attention]
write_status() {
  local status="$1" task="$2" progress="$3" attention="${4:-false}"
  local timestamp
  timestamp=$(date +%s)
  local json="{
  \"role\": \"${WORKER_ROLE}\",
  \"task\": \"${task}\",
  \"phase\": \"${status}\",
  \"status\": \"${status}\",
  \"progress\": \"${progress}\",
  \"updated_at\": ${timestamp},
  \"needs_attention\": ${attention}
}"
  local status_file="${PROJECT_ROOT}/.team/status/${WORKER_ROLE}.json"
  local tmp_status
  tmp_status=$(mktemp "${status_file}.XXXXXX")
  echo "$json" > "$tmp_status"
  mv "$tmp_status" "$status_file"
}

echo "========================================"
echo " Worker: ${WORKER_ROLE}"
echo " 任务队列: ${TOTAL} 个任务"
echo " 任务列表: ${TASKS[*]}"
echo "========================================"
echo ""

for i in "${!TASKS[@]}"; do
  TASK_FILE="${TASKS[$i]}"
  TASK_NUM=$((i + 1))

  echo "----------------------------------------"
  echo " [${TASK_NUM}/${TOTAL}] 开始任务: ${TASK_FILE}"
  echo "----------------------------------------"

  # 1. 更新状态为 starting
  write_status "starting" "$TASK_FILE" "正在初始化，准备执行任务 ${TASK_NUM}/${TOTAL}"

  # 2. 构建 prompt（多任务模式传 --auto-next，最后一个任务不传）
  if [ "$TASK_NUM" -lt "$TOTAL" ]; then
    PROMPT_FILE=$(bash "${BASE_DIR}/build-prompt.sh" "$WORKER_ROLE" "$PROJECT_ROOT" "$TASK_FILE" --auto-next)
  else
    PROMPT_FILE=$(bash "${BASE_DIR}/build-prompt.sh" "$WORKER_ROLE" "$PROJECT_ROOT" "$TASK_FILE")
  fi

  # 3. 执行 claude
  echo " [${TASK_NUM}/${TOTAL}] 正在执行 claude..."
  TASK_EXIT=0
  claude -p "$(cat "$PROMPT_FILE")" || TASK_EXIT=$?

  # 4. 清理 prompt 文件
  rm -f "$PROMPT_FILE"

  # 5. 根据退出码判断成功/失败
  TASK_PATH="${PROJECT_ROOT}/.team/tasks/${TASK_FILE}.md"
  if [ "$TASK_EXIT" -ne 0 ]; then
    # 任务失败：更新状态并通知 Team Leader
    write_status "failed" "$TASK_FILE" "任务执行失败 (exit code: ${TASK_EXIT})" "true"

    if [ -f "$TASK_PATH" ]; then
      if head -1 "$TASK_PATH" | grep -q '^---'; then
        perl -pi -e 's/^status:.*/status: failed/' "$TASK_PATH" 2>/dev/null || true
      fi
    fi

    # 通知 Team Leader
    bash "${BASE_DIR}/send-message.sh" \
      "${WORKER_ROLE}" team-leader completion \
      "[FAILED] 任务 ${TASK_FILE} 执行失败 (exit code: ${TASK_EXIT})，请检查并决定是否重试" \
      "${PROJECT_ROOT}" 2>/dev/null || true

    echo ""
    echo " [${TASK_NUM}/${TOTAL}] 任务 ${TASK_FILE} 失败 (exit: ${TASK_EXIT})"
    echo " 跳过后续任务，等待 Team Leader 指示。"
    echo ""
    # 协作模式（WORKER_ID 已设置）下自动退出，避免 read 阻塞 tmux
    if [ -n "${WORKER_ID:-}" ]; then
      echo "[Worker ${WORKER_ROLE} 因任务失败而停止]"
      sleep 5
      exit 1
    fi
    echo "[Worker ${WORKER_ROLE} 因任务失败而停止，按 Enter 关闭]"
    read
    exit 1
  fi

  # 6. 任务成功：更新 task 文件状态为 review
  if [ -f "$TASK_PATH" ]; then
    if head -1 "$TASK_PATH" | grep -q '^---'; then
      perl -pi -e 's/^status:.*/status: review/' "$TASK_PATH" 2>/dev/null || true
    fi
  fi

  # 7. 更新状态为 done
  write_status "done" "$TASK_FILE" "任务 ${TASK_NUM}/${TOTAL} 已完成" "true"

  echo ""
  echo " [${TASK_NUM}/${TOTAL}] 任务 ${TASK_FILE} 已完成"

  # 8. 如果还有下一个任务，短暂等待避免资源竞争
  if [ "$TASK_NUM" -lt "$TOTAL" ]; then
    echo " 等待 3 秒后开始下一个任务..."
    sleep 3
  fi
done

echo ""
echo "========================================"
echo " 所有 ${TOTAL} 个任务已完成！"
echo " Worker: ${WORKER_ROLE}"
echo "========================================"
echo ""

# ====== s11 自主认领：队列完成后扫描未认领任务 ======
# 仅协作模式启用，通过环境变量 AUTO_CLAIM=1 开启
if [ -n "${WORKER_ID:-}" ] && [ "${AUTO_CLAIM:-0}" = "1" ]; then
  POLL_INTERVAL=${CLAIM_POLL_INTERVAL:-10}
  IDLE_TIMEOUT=${CLAIM_IDLE_TIMEOUT:-60}
  CLAIMED_COUNT=0

  echo "[Auto-claim] 进入空闲扫描，每 ${POLL_INTERVAL}s 检查一次，超时 ${IDLE_TIMEOUT}s"

  # 更新状态为 idle
  write_status "idle" "(scanning)" "已完成分配任务，正在扫描未认领任务..."

  # 使用 while 循环 + 手动计数，确保认领后能重置超时
  ELAPSED=0
  while [ "$ELAPSED" -lt "$IDLE_TIMEOUT" ]; do
    sleep "$POLL_INTERVAL"
    ELAPSED=$((ELAPSED + POLL_INTERVAL))

    # 检查是否收到未读的 shutdown 指令
    INBOX_DIR="${PROJECT_ROOT}/.team/messages/inbox/${WORKER_ROLE}"
    if [ -d "$INBOX_DIR" ]; then
      SHUTDOWN_MSG=""
      for msg_file in "$INBOX_DIR"/*-directive.md; do
        [ -f "$msg_file" ] || continue
        if grep -q "^read: false" "$msg_file" 2>/dev/null && grep -qi "shutdown" "$msg_file" 2>/dev/null; then
          SHUTDOWN_MSG="$msg_file"
          perl -pi -e 's/^read: false/read: true/' "$msg_file" 2>/dev/null || true
          break
        fi
      done
      if [ -n "$SHUTDOWN_MSG" ]; then
        echo "[Auto-claim] 收到 shutdown 指令，退出"
        break
      fi
    fi

    # 扫描 pending 且无 owner 的 task
    UNCLAIMED=$(find "${PROJECT_ROOT}/.team/tasks/" -name "task-*.md" -exec \
      sh -c 'grep -l "^status: pending" "$1" 2>/dev/null | while read f; do
        if ! grep -q "^owner:" "$f" || grep -q "^owner: *$" "$f"; then echo "$f"; fi
      done' _ {} \; 2>/dev/null | head -1)

    if [ -n "$UNCLAIMED" ]; then
      TASK_BASENAME=$(basename "$UNCLAIMED" .md)
      echo "[Auto-claim] 发现未认领任务: ${TASK_BASENAME}"

      # 原子认领：用 mkdir 作为锁（mkdir 是原子操作，先成功的 Worker 获得锁）
      LOCK_DIR="${PROJECT_ROOT}/.team/tasks/.lock-${TASK_BASENAME}"
      if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        echo "[Auto-claim] 任务 ${TASK_BASENAME} 已被其他 Worker 认领，跳过"
        continue
      fi

      # 认领成功，写入 owner
      if ! grep -q "^owner:" "$UNCLAIMED"; then
        perl -pi -e "s/^(status: )pending/\${1}in_progress\nowner: ${WORKER_ROLE}/" "$UNCLAIMED" 2>/dev/null
      else
        perl -pi -e "s/^owner:.*/owner: ${WORKER_ROLE}/" "$UNCLAIMED" 2>/dev/null
        perl -pi -e 's/^status:.*/status: in_progress/' "$UNCLAIMED" 2>/dev/null
      fi

      # 通知 Leader
      bash "${BASE_DIR}/send-message.sh" \
        "${WORKER_ROLE}" team-leader completion \
        "[AUTO-CLAIM] ${WORKER_ROLE} 自主认领任务 ${TASK_BASENAME}" \
        "${PROJECT_ROOT}" 2>/dev/null || true

      # 构建 prompt 并执行
      PROMPT_FILE=$(bash "${BASE_DIR}/build-prompt.sh" "$WORKER_ROLE" "$PROJECT_ROOT" "$TASK_BASENAME")
      write_status "working" "$TASK_BASENAME" "自主认领任务，正在执行..."

      TASK_EXIT=0
      claude -p "$(cat "$PROMPT_FILE")" || TASK_EXIT=$?
      rm -f "$PROMPT_FILE"
      rmdir "$LOCK_DIR" 2>/dev/null || true

      if [ "$TASK_EXIT" -eq 0 ]; then
        perl -pi -e 's/^status:.*/status: review/' "$UNCLAIMED" 2>/dev/null || true
        echo "[Auto-claim] 任务 ${TASK_BASENAME} 完成"
        CLAIMED_COUNT=$((CLAIMED_COUNT + 1))
      else
        perl -pi -e 's/^status:.*/status: failed/' "$UNCLAIMED" 2>/dev/null || true
        bash "${BASE_DIR}/send-message.sh" \
          "${WORKER_ROLE}" team-leader completion \
          "[FAILED] 自主认领的任务 ${TASK_BASENAME} 执行失败 (exit: ${TASK_EXIT})" \
          "${PROJECT_ROOT}" 2>/dev/null || true
        echo "[Auto-claim] 任务 ${TASK_BASENAME} 失败，停止自主认领"
        break
      fi

      # 重置 idle 计时
      ELAPSED=0
      write_status "idle" "(scanning)" "已完成认领任务，继续扫描..."
    fi
  done

  echo "[Auto-claim] 空闲扫描结束，额外完成 ${CLAIMED_COUNT} 个任务"
fi

# 退出
if [ -n "${WORKER_ID:-}" ]; then
  write_status "shutdown" "" "Worker 已退出"
  echo "[Worker ${WORKER_ROLE} 全部任务已完成]"
  sleep 3
else
  echo "[Worker ${WORKER_ROLE} 全部任务已完成，按 Enter 关闭]"
  read
fi
