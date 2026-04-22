#!/usr/bin/env bash
# 启动一个 Worker Agent 在 tmux 后台 session 中
# 用法: launch-worker.sh <project-root> <worker-role> <task1> [task2] [task3] ...
set -euo pipefail

PROJECT_ROOT="${1:?用法: launch-worker.sh <project-root> <worker-role> <task1> [task2] [task3] ...}"
WORKER_ROLE="${2:?缺少 worker-role 参数}"
shift 2

if [ $# -eq 0 ]; then
  echo "[ERROR] 至少需要一个 task 参数"
  exit 1
fi

TASKS=("$@")
FIRST_TASK="${TASKS[0]}"
TASK_COUNT=${#TASKS[@]}

SESSION_NAME="worker-${WORKER_ROLE}"
AGENT_DEF="$HOME/.claude/agents/${WORKER_ROLE}.md"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. 前置检查
if ! command -v tmux &>/dev/null; then
  echo "[ERROR] 需要安装 tmux: brew install tmux"
  exit 1
fi

if ! command -v claude &>/dev/null; then
  echo "[ERROR] 需要安装 claude CLI"
  exit 1
fi

if [ ! -f "$AGENT_DEF" ]; then
  echo "[ERROR] 角色定义文件不存在: $AGENT_DEF"
  exit 1
fi

# 2. 检查 session 是否已存在
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "[WARN] tmux session '${SESSION_NAME}' 已存在，跳过启动"
  exit 0
fi

# 3. 初始化 Worker 目录（v3.4.0 简化版）
mkdir -p "${PROJECT_ROOT}/.team/messages/inbox/${WORKER_ROLE}"
mkdir -p "${PROJECT_ROOT}/.team/status"

# 4. 初始化状态文件（JSON 格式）
TIMESTAMP=$(date +%s)
STATUS_FILE="${PROJECT_ROOT}/.team/status/${WORKER_ROLE}.json"
TMP_STATUS=$(mktemp "${STATUS_FILE}.XXXXXX")
cat > "$TMP_STATUS" << EOF
{
  "role": "${WORKER_ROLE}",
  "task": "${FIRST_TASK}",
  "phase": "starting",
  "progress": "正在初始化...",
  "status": "in_progress",
  "updated_at": ${TIMESTAMP},
  "needs_attention": false
}
EOF
mv "$TMP_STATUS" "$STATUS_FILE"

# 5. 启动 tmux session
LAUNCH_SCRIPT=$(mktemp /tmp/worker-launch-XXXXXX.sh)

if [ "$TASK_COUNT" -eq 1 ]; then
  # 单任务模式：直接构建 prompt 并运行 claude（向后兼容）
  PROMPT_FILE=$(bash "${BASE_DIR}/build-prompt.sh" "$WORKER_ROLE" "$PROJECT_ROOT" "$FIRST_TASK") || {
    echo "[ERROR] prompt 构建失败，Worker 未启动"
    exit 1
  }
  if [ -z "$PROMPT_FILE" ] || [ ! -f "$PROMPT_FILE" ]; then
    echo "[ERROR] prompt 文件不存在: $PROMPT_FILE"
    exit 1
  fi

  cat > "$LAUNCH_SCRIPT" << LAUNCH_EOF
#!/usr/bin/env bash
export WORKER_ID='${WORKER_ROLE}'
export PROJECT_ROOT='${PROJECT_ROOT}'
claude -p "\$(cat '${PROMPT_FILE}')" || true
rm -f '${PROMPT_FILE}'
echo '[Worker ${WORKER_ROLE} 已完成]'
sleep 3
rm -f '${LAUNCH_SCRIPT}'
LAUNCH_EOF
else
  # 多任务模式：通过 worker-loop.sh 循环执行
  # 将任务列表写入临时文件，避免 shell word splitting 和 glob 展开
  TASK_LIST_FILE=$(mktemp /tmp/worker-tasks-XXXXXX.txt)
  printf '%s\n' "${TASKS[@]}" > "$TASK_LIST_FILE"

  cat > "$LAUNCH_SCRIPT" << LAUNCH_EOF
#!/usr/bin/env bash
export WORKER_ID='${WORKER_ROLE}'
export PROJECT_ROOT='${PROJECT_ROOT}'
TASK_ARGS=()
while IFS= read -r line; do
  [ -n "\$line" ] && TASK_ARGS+=("\$line")
done < '${TASK_LIST_FILE}'
bash '${BASE_DIR}/worker-loop.sh' '${WORKER_ROLE}' '${PROJECT_ROOT}' "\${TASK_ARGS[@]}"
rm -f '${TASK_LIST_FILE}' '${LAUNCH_SCRIPT}'
LAUNCH_EOF
fi

chmod +x "$LAUNCH_SCRIPT"
tmux new-session -d -s "$SESSION_NAME" -c "$PROJECT_ROOT" "bash '$LAUNCH_SCRIPT'"

echo "[OK] Worker '${WORKER_ROLE}' 已在 tmux session '${SESSION_NAME}' 中启动"
echo "     任务数: ${TASK_COUNT}"
echo "     任务列表: ${TASKS[*]}"
echo "     查看: tmux attach -t ${SESSION_NAME}"
echo "     状态: cat ${PROJECT_ROOT}/.team/status/${WORKER_ROLE}.json"
