#!/usr/bin/env bash
# Leader PostToolUse Hook: 汇总所有 Worker 状态 + 检查异常
# 替代原 check-outbox.sh
# 依赖环境变量: PROJECT_ROOT

# Worker 身份检测：设置了 WORKER_ID 且不是 team-leader 则跳过
if [ -n "${WORKER_ID:-}" ] && [ "${WORKER_ID}" != "team-leader" ]; then
  exit 0
fi
[ -z "${PROJECT_ROOT:-}" ] && exit 0

STATUS_DIR="${PROJECT_ROOT}/.team/status"
STATE_FILE="${STATUS_DIR}/state.json"
[ -d "$STATUS_DIR" ] || exit 0

shopt -s nullglob

# --- 1. 汇总所有 Worker 状态到 state.json ---
NOW=$(date +%s)
WORKERS_JSON="{"
ALERTS="[]"
FIRST=true

for f in "$STATUS_DIR"/*.json; do
  [ -f "$f" ] || continue
  BASENAME=$(basename "$f" .json)
  [ "$BASENAME" = "state" ] && continue

  CONTENT=$(cat "$f" 2>/dev/null)
  [ -z "$CONTENT" ] && continue

  # 检查是否超时（默认 10 分钟无更新，可通过 LEADER_STALE_THRESHOLD 环境变量配置，单位秒）
  STALE_THRESHOLD="${LEADER_STALE_THRESHOLD:-600}"
  UPDATED=$(node -e "try{console.log(JSON.parse(require('fs').readFileSync('$f','utf-8')).updated_at||0)}catch(e){console.log(0)}" 2>/dev/null)
  if [ -n "$UPDATED" ] && [ "$UPDATED" -gt 0 ]; then
    AGE=$((NOW - UPDATED))
    STALE_MIN=$((STALE_THRESHOLD / 60))
    if [ "$AGE" -gt "$STALE_THRESHOLD" ]; then
      ALERTS=$(node -e "const a=$ALERTS;a.push('${BASENAME} 超过 ${STALE_MIN} 分钟无更新 (${AGE}s)');console.log(JSON.stringify(a))" 2>/dev/null)
    fi
  fi

  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    WORKERS_JSON+=","
  fi
  WORKERS_JSON+="\"${BASENAME}\":${CONTENT}"
done

WORKERS_JSON+="}"

# 写入汇总文件
node -e "
  const fs = require('fs');
  const state = {
    updated_at: $NOW,
    workers: $WORKERS_JSON,
    alerts: $ALERTS
  };
  fs.writeFileSync('$STATE_FILE', JSON.stringify(state, null, 2));
" 2>/dev/null

# --- 2. 输出告警 ---
ALERT_COUNT=$(node -e "console.log($ALERTS.length)" 2>/dev/null)
if [ "$ALERT_COUNT" -gt 0 ]; then
  echo "[TEAM ALERT] Worker 异常:"
  node -e "$ALERTS.forEach(a => console.log('  ⚠️  ' + a))" 2>/dev/null
fi

# --- 3. 检查 Worker 完成通知（通过状态文件中的 needs_attention 字段） ---
output=""
for f in "$STATUS_DIR"/*.json; do
  [ -f "$f" ] || continue
  BASENAME=$(basename "$f" .json)
  [ "$BASENAME" = "state" ] && continue

  STATUS=$(node -e "try{const s=JSON.parse(require('fs').readFileSync('$f','utf-8'));if(s.needs_attention){console.log(s.status+'|'+s.progress)}}catch(e){}" 2>/dev/null)
  if [ -n "$STATUS" ]; then
    output+="[${BASENAME}] ${STATUS}"$'\n'
    # 清除 needs_attention 标记
    node -e "
      const fs = require('fs');
      try {
        const s = JSON.parse(fs.readFileSync('$f', 'utf-8'));
        s.needs_attention = false;
        fs.writeFileSync('$f', JSON.stringify(s, null, 2));
      } catch(e) {}
    " 2>/dev/null
  fi
done

# --- 4. 扫描 Worker→Leader 消息（outbox 目录） ---
OUTBOX_BASE="${PROJECT_ROOT}/.team/messages/outbox"
if [ -d "$OUTBOX_BASE" ]; then
  for worker_outbox in "$OUTBOX_BASE"/*/; do
    [ -d "$worker_outbox" ] || continue
    for f in "$worker_outbox"*.md; do
      [ -f "$f" ] || continue
      if grep -q "^read: false" "$f" 2>/dev/null; then
        perl -pi -e 's/^read: false/read: true/' "$f" 2>/dev/null || true
        from=$(awk -F': ' '/^from:/{print $2; exit}' "$f")
        type=$(awk -F': ' '/^type:/{print $2; exit}' "$f")
        content=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2' "$f")
        output+="[MESSAGE from ${from}] (${type}): ${content}"$'\n'
      fi
    done
  done
fi

if [ -n "$output" ]; then
  echo "[WORKER UPDATE]"
  echo "$output"
  echo "请根据以上状态更新你的全局视图，必要时调整任务。"
fi
