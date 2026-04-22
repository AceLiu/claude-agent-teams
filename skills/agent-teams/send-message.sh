#!/usr/bin/env bash
# 发送消息到指定 Worker 或广播给全体
# 用法: send-message.sh <from> <to> <type> <content> [project-root]
# to=broadcast 时发送到广播目录
set -euo pipefail

FROM="${1:?用法: send-message.sh <from> <to> <type> <content> [project-root]}"
TO="${2:?缺少 to 参数}"
TYPE="${3:?缺少 type 参数 (directive|progress|completion|intervention|broadcast)}"
CONTENT="${4:?缺少 content 参数}"
PROJECT_ROOT="${5:-.}"

# 验证消息类型
case "$TYPE" in
  directive|progress|completion|intervention|broadcast) ;;
  *) echo "[ERROR] 无效 type: ${TYPE}，合法值: directive|progress|completion|intervention|broadcast" >&2; exit 1 ;;
esac

TIMESTAMP=$(date +%s000)

if [ "$TO" = "broadcast" ]; then
  TARGET_DIR="${PROJECT_ROOT}/.team/messages/broadcast"
elif [ "$TO" = "team-leader" ]; then
  # Anyone -> Leader: write to sender's outbox (leader-sync.sh scans all outboxes)
  TARGET_DIR="${PROJECT_ROOT}/.team/messages/outbox/${FROM}"
else
  # Leader -> Worker, or Worker -> Worker: write directly to recipient's inbox
  TARGET_DIR="${PROJECT_ROOT}/.team/messages/inbox/${TO}"
fi

mkdir -p "$TARGET_DIR"

# 文件名加 PID + RANDOM 后缀：date +%s000 只是秒级伪毫秒，同一秒多条消息
# 会产生同名文件，mv 时互相覆盖。加入 $$ (PID) + $RANDOM 确保唯一。
MSG_FILE="${TARGET_DIR}/${TIMESTAMP}-${TYPE}-$$-${RANDOM}.md"
# 原子写入：先写临时文件再 mv，防止并发竞争导致文件损坏
TEMP_FILE=$(mktemp "${TARGET_DIR}/.tmp-msg-XXXXXX")
{
  echo "---"
  echo "from: ${FROM}"
  echo "to: ${TO}"
  echo "type: ${TYPE}"
  echo "priority: normal"
  echo "timestamp: ${TIMESTAMP}"
  echo "read: false"
  echo "---"
  echo ""
  printf '%s\n' "$CONTENT"
} > "$TEMP_FILE"
mv "$TEMP_FILE" "$MSG_FILE"

echo "[SENT] ${FROM} → ${TO}: ${TYPE} (${TIMESTAMP})"
