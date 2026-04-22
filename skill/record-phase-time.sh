#!/usr/bin/env bash
# 记录 Phase 开始/结束时间到 metrics.json
# 用法: record-phase-time.sh <project-root> <phase> <start|end>
# phase: phase1_requirements | phase2_design | phase3_tasking | phase4_development | phase5_verification
# 示例: record-phase-time.sh . phase1_requirements start
set -euo pipefail

PROJECT_ROOT="${1:?用法: record-phase-time.sh <project-root> <phase> <start|end>}"
PHASE="${2:?缺少 phase 参数}"
ACTION="${3:?缺少 action 参数 (start|end)}"

METRICS_FILE="${PROJECT_ROOT}/.team/metrics.json"

if [ ! -f "$METRICS_FILE" ]; then
  echo "[ERROR] metrics.json 不存在: $METRICS_FILE" >&2
  exit 1
fi

# 验证 phase 参数
case "$PHASE" in
  phase1_requirements|phase2_design|phase3_tasking|phase4_development|phase5_verification) ;;
  # 兼容旧键名（已废弃，建议迁移）
  spec|develop|review|testing)
    echo "[WARN] 旧 phase 键名 '${PHASE}' 已废弃，请使用 phase1_requirements/phase2_design/phase3_tasking/phase4_development/phase5_verification" >&2 ;;
  *) echo "[ERROR] 无效 phase: ${PHASE}" >&2; exit 1 ;;
esac

# 验证 action 参数
case "$ACTION" in
  start|end) ;;
  *) echo "[ERROR] 无效 action: ${ACTION}，合法值: start|end" >&2; exit 1 ;;
esac

NOW_TS=$(date +%s)

node -e "
  try {
    const fs = require('fs');
    const metrics = JSON.parse(fs.readFileSync('${METRICS_FILE}', 'utf-8'));
    const phase = metrics.phases['${PHASE}'];
    if ('${ACTION}' === 'start') {
      phase.start_ts = ${NOW_TS};
      console.log('[METRICS] ${PHASE} 开始计时: ' + new Date(${NOW_TS} * 1000).toLocaleString());
    } else {
      phase.end_ts = ${NOW_TS};
      if (phase.start_ts > 0) {
        phase.duration_min = Math.round((${NOW_TS} - phase.start_ts) / 60);
        console.log('[METRICS] ${PHASE} 结束，耗时 ' + phase.duration_min + ' 分钟');
      }
    }
    fs.writeFileSync('${METRICS_FILE}', JSON.stringify(metrics, null, 2));
  } catch (e) {
    console.error('[ERROR] metrics 更新失败:', e.message);
    process.exit(1);
  }
"
