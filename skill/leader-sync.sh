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

# --- 1. 汇总所有 Worker 状态到 state.json（用 node 单次读取，避免 shell 注入）---
# 策略：shell 只负责枚举文件路径，所有 JSON 解析与字符串拼装都在 node 内完成。
# 相比原实现（把 cat 出来的 JSON 内容拼入 node -e 代码）：
# 1. 不会因 status/*.json 内容被篡改导致任意代码执行
# 2. 不会因 JSON 解析失败而静默崩溃（2>/dev/null 曾吞掉所有错误）
STALE_THRESHOLD="${LEADER_STALE_THRESHOLD:-600}"

# 收集候选文件路径（不含 state.json 自身）
STATUS_FILES=()
for f in "$STATUS_DIR"/*.json; do
  [ -f "$f" ] || continue
  BASENAME=$(basename "$f" .json)
  [ "$BASENAME" = "state" ] && continue
  STATUS_FILES+=("$f")
done

SYNC_RESULT=""
if [ ${#STATUS_FILES[@]} -gt 0 ]; then
  # 用 stdin(JSON) 传文件列表给 node，避免命令行长度 / 转义问题
  FILES_JSON=$(printf '%s\n' "${STATUS_FILES[@]}" | node -e '
    const lines = require("fs").readFileSync(0, "utf-8").split("\n").filter(Boolean);
    process.stdout.write(JSON.stringify(lines));
  ')
  SYNC_RESULT=$(
    STALE_THRESHOLD="$STALE_THRESHOLD" \
    STATE_FILE="$STATE_FILE" \
    FILES_JSON="$FILES_JSON" \
    node -e '
      const fs = require("fs");
      const path = require("path");
      const files = JSON.parse(process.env.FILES_JSON);
      const threshold = parseInt(process.env.STALE_THRESHOLD, 10);
      const now = Math.floor(Date.now() / 1000);
      const workers = {};
      const alerts = [];

      for (const f of files) {
        const basename = path.basename(f, ".json");
        let parsed;
        try {
          parsed = JSON.parse(fs.readFileSync(f, "utf-8"));
        } catch (e) {
          alerts.push(`${basename} 状态文件损坏: ${e.message}`);
          continue;
        }
        workers[basename] = parsed;
        const updated = parseInt(parsed.updated_at || 0, 10);
        if (updated > 0) {
          const age = now - updated;
          if (age > threshold) {
            const staleMin = Math.floor(threshold / 60);
            alerts.push(`${basename} 超过 ${staleMin} 分钟无更新 (${age}s)`);
          }
        }
      }

      const state = { updated_at: now, workers, alerts };
      try {
        fs.writeFileSync(process.env.STATE_FILE, JSON.stringify(state, null, 2));
      } catch (e) {
        console.error(`[leader-sync] 写入 state.json 失败: ${e.message}`);
        process.exit(2);
      }
      // 把 alerts 透出给 shell（换行分隔，空字符串代表无告警）
      process.stdout.write(alerts.join("\n"));
    ' 2>&1
  )
  SYNC_EXIT=$?
  if [ "$SYNC_EXIT" -ne 0 ]; then
    echo "[leader-sync] node 汇总失败 (exit=$SYNC_EXIT): $SYNC_RESULT" >&2
  fi
fi

# --- 2. 输出告警 ---
if [ -n "$SYNC_RESULT" ]; then
  echo "[TEAM ALERT] Worker 异常:"
  printf '%s\n' "$SYNC_RESULT" | while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "  ⚠️  $line"
  done
fi

# --- 3. 检查 Worker 完成通知（needs_attention 字段）---
# 同样用 node 从文件读取，不通过 shell 传 JSON 字符串
output=""
for f in "$STATUS_DIR"/*.json; do
  [ -f "$f" ] || continue
  BASENAME=$(basename "$f" .json)
  [ "$BASENAME" = "state" ] && continue

  STATUS=$(
    STATUS_FILE="$f" node -e '
      try {
        const s = JSON.parse(require("fs").readFileSync(process.env.STATUS_FILE, "utf-8"));
        if (s.needs_attention) {
          process.stdout.write(`${s.status || ""}|${s.progress || ""}`);
        }
      } catch (e) {}
    '
  )
  if [ -n "$STATUS" ]; then
    output+="[${BASENAME}] ${STATUS}"$'\n'
    # 清除 needs_attention 标记
    STATUS_FILE="$f" node -e '
      const fs = require("fs");
      try {
        const p = process.env.STATUS_FILE;
        const s = JSON.parse(fs.readFileSync(p, "utf-8"));
        s.needs_attention = false;
        fs.writeFileSync(p, JSON.stringify(s, null, 2));
      } catch (e) {
        console.error(`[leader-sync] 清除 needs_attention 失败: ${e.message}`);
      }
    '
  fi
done

# --- 4. 扫描 Worker→Leader 消息（outbox 目录）---
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
