#!/usr/bin/env bash
# Worker PostToolUse Hook: 更新自己的状态文件 + 检查 Leader 指令
# 替代原 check-inbox.sh + update-status.sh
# 依赖环境变量: WORKER_ID, PROJECT_ROOT

[ -z "${WORKER_ID:-}" ] && exit 0
[ -z "${PROJECT_ROOT:-}" ] && exit 0

STATUS_DIR="${PROJECT_ROOT}/.team/status"
STATUS_FILE="${STATUS_DIR}/${WORKER_ID}.json"
INBOX="${PROJECT_ROOT}/.team/messages/inbox/${WORKER_ID}"

# --- 1. 更新状态文件时间戳 ---
if [ -f "$STATUS_FILE" ]; then
  TIMESTAMP=$(date +%s)
  # 用 node 更新 JSON（比 sed 安全）
  node -e "
    const fs = require('fs');
    try {
      const s = JSON.parse(fs.readFileSync('$STATUS_FILE', 'utf-8'));
      s.updated_at = $TIMESTAMP;
      fs.writeFileSync('$STATUS_FILE', JSON.stringify(s, null, 2));
    } catch(e) {}
  " 2>/dev/null
fi

# --- 2. 检查 Leader 指令（仍用 send-message.sh 下发） ---
output=""
shopt -s nullglob

if [ -d "$INBOX" ]; then
  for f in "$INBOX"/*.md; do
    [ -f "$f" ] || continue
    if grep -q "^read: false" "$f" 2>/dev/null; then
      perl -pi -e 's/^read: false/read: true/' "$f" 2>/dev/null || true
      content=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2' "$f")
      from=$(awk -F': ' '/^from:/{print $2; exit}' "$f")
      type=$(awk -F': ' '/^type:/{print $2; exit}' "$f")
      priority=$(awk -F': ' '/^priority:/{print $2; exit}' "$f")

      if [ "$priority" = "urgent" ]; then
        output+="[URGENT DIRECTIVE from ${from}] (${type}): ${content}"$'\n'
      else
        output+="[DIRECTIVE from ${from}] (${type}): ${content}"$'\n'
      fi
    fi
  done
fi

if [ -n "$output" ]; then
  echo "$output"
  echo "请根据以上 Leader 指令调整你的工作方向。"
fi
