#!/usr/bin/env bash
# CLI 监控工具：读取 .team/status/state.json 输出格式化表格
# 用法: team-status.sh <project-root> [--watch]
# 替代 Web Dashboard

set -euo pipefail

PROJECT_ROOT="${1:-.}"
WATCH_MODE=false

for arg in "$@"; do
  [ "$arg" = "--watch" ] && WATCH_MODE=true
done

STATE_FILE="${PROJECT_ROOT}/.team/status/state.json"

print_status() {
  if [ ! -f "$STATE_FILE" ]; then
    echo "❌ 状态文件不存在: $STATE_FILE"
    echo "   请确认协作模式已初始化"
    return 1
  fi

  node -e "
    const fs = require('fs');
    try {
      const state = JSON.parse(fs.readFileSync('$STATE_FILE', 'utf-8'));
      const now = Math.floor(Date.now() / 1000);

      // 清屏（watch 模式）
      if ('$WATCH_MODE' === 'true') process.stdout.write('\x1B[2J\x1B[0f');

      console.log('┌' + '─'.repeat(78) + '┐');
      console.log('│ Agent Teams Status' + ' '.repeat(59) + '│');
      console.log('│ Updated: ' + new Date(state.updated_at * 1000).toLocaleTimeString() + ' '.repeat(78 - 21 - new Date(state.updated_at * 1000).toLocaleTimeString().length) + '│');
      console.log('├' + '─'.repeat(16) + '┬' + '─'.repeat(12) + '┬' + '─'.repeat(14) + '┬' + '─'.repeat(27) + '┬' + '─'.repeat(7) + '┤');
      console.log('│ Role           │ Task       │ Phase        │ Progress                  │ Age   │');
      console.log('├' + '─'.repeat(16) + '┼' + '─'.repeat(12) + '┼' + '─'.repeat(14) + '┼' + '─'.repeat(27) + '┼' + '─'.repeat(7) + '┤');

      const workers = state.workers || {};
      for (const [role, w] of Object.entries(workers)) {
        const age = now - (w.updated_at || 0);
        let ageStr;
        if (age < 60) ageStr = age + 's';
        else if (age < 3600) ageStr = Math.floor(age / 60) + 'm';
        else ageStr = Math.floor(age / 3600) + 'h';

        const statusIcon = w.status === 'done' ? '✅' :
                          w.status === 'in_progress' ? '🔄' :
                          w.status === 'blocked' ? '🚫' :
                          w.status === 'failed' ? '❌' : '⏳';

        const r = (role + statusIcon).padEnd(16).slice(0, 15);
        const t = (w.task || '-').padEnd(12).slice(0, 11);
        const ph = (w.phase || '-').padEnd(14).slice(0, 13);
        const pg = (w.progress || '-').padEnd(27).slice(0, 26);
        const a = ageStr.padEnd(7).slice(0, 6);

        console.log('│ ' + r + '│ ' + t + '│ ' + ph + '│ ' + pg + '│ ' + a + '│');
      }

      console.log('└' + '─'.repeat(16) + '┴' + '─'.repeat(12) + '┴' + '─'.repeat(14) + '┴' + '─'.repeat(27) + '┴' + '─'.repeat(7) + '┘');

      // 告警
      if (state.alerts && state.alerts.length > 0) {
        console.log('');
        console.log('⚠️  Alerts:');
        state.alerts.forEach(a => console.log('   ' + a));
      }
    } catch (e) {
      console.error('解析状态文件失败:', e.message);
      process.exit(1);
    }
  "
}

if [ "$WATCH_MODE" = true ]; then
  echo "监控模式已启动，Ctrl+C 退出..."
  while true; do
    print_status || exit 1
    sleep 10
  done
else
  print_status
fi
