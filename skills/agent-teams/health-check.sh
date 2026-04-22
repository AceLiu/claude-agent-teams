#!/usr/bin/env bash
# 检查所有 Worker 的健康状态
# 用法: health-check.sh [project-root] [--stale-threshold=300]
set -euo pipefail

PROJECT_ROOT="${1:-.}"
STALE_THRESHOLD="${LEADER_STALE_THRESHOLD:-600}"  # 默认 10 分钟无更新视为异常，与 leader-sync.sh 保持一致

for arg in "$@"; do
  if [[ "$arg" =~ ^--stale-threshold=(.+)$ ]]; then
    STALE_THRESHOLD="${BASH_REMATCH[1]}"
  fi
done

STATUS_DIR="${PROJECT_ROOT}/.team/status"
NOW=$(date +%s)
ISSUES=()
HEALTHY=0
TOTAL=0

if [ ! -d "$STATUS_DIR" ]; then
  echo "[HEALTH] 无 Worker 状态目录"
  exit 0
fi

for f in "$STATUS_DIR"/*.json; do
  [ -f "$f" ] || continue
  BASENAME=$(basename "$f" .json)
  [ "$BASENAME" = "state" ] && continue
  TOTAL=$((TOTAL + 1))

  WORKER="$BASENAME"
  STATUS=$(node -e "try{console.log(JSON.parse(require('fs').readFileSync('$f','utf-8')).status||'')}catch(e){console.log('')}" 2>/dev/null)
  UPDATED=$(node -e "try{console.log(JSON.parse(require('fs').readFileSync('$f','utf-8')).updated_at||0)}catch(e){console.log(0)}" 2>/dev/null)

  if [ -n "$UPDATED" ] && [ "$UPDATED" -gt 0 ]; then
    ELAPSED=$((NOW - UPDATED))
  else
    ELAPSED=999999
  fi

  # 已完成/已关闭的 Worker 不检查超时
  if [ "$STATUS" = "done" ] || [ "$STATUS" = "shutdown" ]; then
    HEALTHY=$((HEALTHY + 1))
    echo "[OK] ${WORKER}: ${STATUS}"
    continue
  fi

  # 失败的 Worker 标记为异常但不检查超时
  if [ "$STATUS" = "failed" ]; then
    ISSUES+=("[FAILED] ${WORKER}: 任务执行失败")
    continue
  fi

  # 检查 tmux session 是否存活（通过 .hooks-active 判断协作模式）
  if [ -f "${PROJECT_ROOT}/.claude/.hooks-active" ]; then
    SESSION_NAME="worker-${WORKER}"
    if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
      ISSUES+=("[DEAD] ${WORKER}: tmux session 不存在，但状态为 ${STATUS}")
      continue
    fi
  fi

  # 检查是否超时无更新
  if [ "$ELAPSED" -gt "$STALE_THRESHOLD" ]; then
    ELAPSED_MIN=$((ELAPSED / 60))
    ISSUES+=("[STALE] ${WORKER}: ${ELAPSED_MIN}m 无更新（状态: ${STATUS}）")
    continue
  fi

  HEALTHY=$((HEALTHY + 1))
  echo "[OK] ${WORKER}: ${STATUS} (${ELAPSED}s ago)"
done

echo ""
echo "--- 健康检查摘要 ---"
echo "Worker 总数: ${TOTAL}"
echo "健康: ${HEALTHY}"
echo "异常: ${#ISSUES[@]}"

if [ ${#ISSUES[@]} -gt 0 ]; then
  echo ""
  echo "--- 异常详情 ---"
  for issue in "${ISSUES[@]}"; do
    echo "  $issue"
  done
  exit 1
fi
