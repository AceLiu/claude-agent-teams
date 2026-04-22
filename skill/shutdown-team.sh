#!/usr/bin/env bash
# 关闭所有 Worker tmux session 和清理残留进程
# 用法: shutdown-team.sh [project-root]
set -euo pipefail

PROJECT_ROOT="${1:-.}"

echo "=== 关闭 Agent Teams 协作模式 ==="

# 1. 关闭所有 worker tmux session
KILLED=0
for session in $(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^worker-' || true); do
  tmux kill-session -t "$session" 2>/dev/null && {
    echo "[STOPPED] tmux session: $session"
    KILLED=$((KILLED + 1))
  }
done
echo "已关闭 ${KILLED} 个 Worker session"

# 2. 清理孤儿 claude 进程（由 Worker 启动但 tmux 退出后残留的）
# 通过环境变量 WORKER_ID 匹配，因为 launch-worker.sh 会 export WORKER_ID
ORPHAN_KILLED=0
for pid in $(pgrep -f "claude" 2>/dev/null || true); do
  # 检查该进程的环境变量是否包含 WORKER_ID（说明是 Worker 启动的 claude）
  PROC_ENV=$(ps -o command= -p "$pid" 2>/dev/null || echo "")
  # 检查父进程是否已不在 tmux 中
  PPID_NAME=$(ps -o comm= -p "$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')" 2>/dev/null || echo "")
  if [ "$PPID_NAME" != "tmux" ] && [ "$PPID_NAME" != "tmux: server" ] && [ "$PPID_NAME" != "bash" ]; then
    # 通过 /proc 或 ps 判断是否是 Worker 进程（macOS 无法直接读 /proc）
    # 保守策略：只清理已没有父进程的 claude -p 进程
    if echo "$PROC_ENV" | grep -q "claude.*-p" 2>/dev/null; then
      kill "$pid" 2>/dev/null && {
        echo "[CLEANED] 孤儿 claude 进程 (PID: $pid)"
        ORPHAN_KILLED=$((ORPHAN_KILLED + 1))
      }
    fi
  fi
done
[ "$ORPHAN_KILLED" -gt 0 ] && echo "已清理 ${ORPHAN_KILLED} 个孤儿进程"

# 3. 清除项目级 Hook 配置
HOOK_MARKER="${PROJECT_ROOT}/.claude/.hooks-active"
if [ -f "$HOOK_MARKER" ]; then
  SETTINGS_FILE="${PROJECT_ROOT}/.claude/settings.json"
  BACKUP_FILE="${PROJECT_ROOT}/.claude/settings.json.pre-collab"

  if [ -f "$BACKUP_FILE" ]; then
    cp "$BACKUP_FILE" "$SETTINGS_FILE"
    rm -f "$BACKUP_FILE"
    echo "[RESTORED] 项目 Hook 配置已恢复"
  fi
  rm -f "$HOOK_MARKER"
else
  echo "[SKIP] 未找到 Hook 激活标记"
fi

# 5. 清理广播已读标记文件
BROADCAST_DIR="${PROJECT_ROOT}/.team/messages/broadcast"
if [ -d "$BROADCAST_DIR" ]; then
  MARKERS_CLEANED=0
  for marker in "$BROADCAST_DIR"/*.read-*; do
    [ -f "$marker" ] || continue
    rm -f "$marker"
    MARKERS_CLEANED=$((MARKERS_CLEANED + 1))
  done
  [ "$MARKERS_CLEANED" -gt 0 ] && echo "[CLEANED] ${MARKERS_CLEANED} 个广播已读标记"
fi

echo ""
echo "=== Agent Teams 协作模式已关闭 ==="
echo "  .team/ 目录保留，可查看历史记录"
echo "  如需完全清理: rm -rf ${PROJECT_ROOT}/.team"
