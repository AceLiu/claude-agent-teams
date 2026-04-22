#!/usr/bin/env bash
# 分析 Agent Teams 度量数据，输出聚合报告
# 用法: analyze-metrics.sh [--project <name>] [--all]
set -euo pipefail

METRICS_BASE="$HOME/.claude/metrics"
TARGET_PROJECT=""
SHOW_ALL=false

while [ $# -gt 0 ]; do
  case "$1" in
    --project) TARGET_PROJECT="$2"; shift 2 ;;
    --all) SHOW_ALL=true; shift ;;
    *) shift ;;
  esac
done

if [ ! -d "$METRICS_BASE" ]; then
  echo "暂无度量数据。运行 Agent Teams 完成一次交付后会自动生成。"
  exit 0
fi

echo "============================================"
echo " Agent Teams 度量分析报告"
echo " 生成时间: $(date '+%Y-%m-%d %H:%M')"
echo "============================================"
echo ""

# 收集所有项目或指定项目
if [ -n "$TARGET_PROJECT" ]; then
  PROJECTS=("$TARGET_PROJECT")
else
  PROJECTS=()
  for dir in "$METRICS_BASE"/*/; do
    [ -d "$dir" ] || continue
    PROJECTS+=("$(basename "$dir")")
  done
fi

if [ ${#PROJECTS[@]} -eq 0 ]; then
  echo "暂无度量数据。"
  exit 0
fi

TOTAL_TASKS=0
TOTAL_REWORK=0
TOTAL_BUGS_P0=0
TOTAL_BUGS_P1=0
TOTAL_BUGS_P2=0

for project in "${PROJECTS[@]}"; do
  PROJECT_DIR="${METRICS_BASE}/${project}"
  [ -d "$PROJECT_DIR" ] || continue

  echo "## 项目: ${project}"
  echo ""

  FILE_COUNT=0
  PROJ_P1_TOTAL=0
  PROJ_P2_TOTAL=0
  PROJ_P3_TOTAL=0
  PROJ_P4_TOTAL=0
  PROJ_P5_TOTAL=0
  PROJ_REWORK_TOTAL=0

  for f in "$PROJECT_DIR"/*.json; do
    [ -f "$f" ] || continue
    FILE_COUNT=$((FILE_COUNT + 1))

    # 用 node 解析 JSON（避免 eval 注入风险）
    METRICS_JSON=$(node -e "
      const fs = require('fs');
      try {
        const d = JSON.parse(fs.readFileSync('$f', 'utf-8'));
        const p = d.phases || {};
        const bugs = d.bugs || {};
        const cov = d.coverage || {};
        const safe = s => String(s || '').replace(/[^a-zA-Z0-9_\-.\/ ]/g, '');
        console.log([
          safe(d.requirement || 'unknown'),
          safe(d.level || '?'),
          safe(d.date || '?'),
          (p.phase1_requirements||{}).duration_min||0,
          (p.phase2_design||{}).duration_min||0,
          (p.phase3_tasking||{}).duration_min||0,
          (p.phase4_development||{}).duration_min||0,
          (p.phase5_verification||{}).duration_min||0,
          (p.phase1_requirements||{}).rework_count||0,
          (p.phase2_design||{}).rework_count||0,
          (p.phase3_tasking||{}).rework_count||0,
          (p.phase4_development||{}).rework_count||0,
          (p.phase5_verification||{}).rework_count||0,
          bugs.P0||0, bugs.P1||0, bugs.P2||0,
          cov.coverage_rate||0
        ].join('|'));
      } catch(e) { process.exit(1); }
    " 2>/dev/null) || continue

    IFS='|' read -r REQ_NAME LEVEL DATE P1_DUR P2_DUR P3_DUR P4_DUR P5_DUR \
      P1_RW P2_RW P3_RW P4_RW P5_RW BUGS_P0 BUGS_P1 BUGS_P2 COV_RATE <<< "$METRICS_JSON"

    REWORK=$((P1_RW + P2_RW + P3_RW + P4_RW + P5_RW))
    TOTAL_DUR=$((P1_DUR + P2_DUR + P3_DUR + P4_DUR + P5_DUR))

    if [ "$SHOW_ALL" = true ]; then
      echo "  ### ${REQ_NAME} (${LEVEL}级, ${DATE})"
      echo "  | 阶段 | 耗时(min) | 返工次数 |"
      echo "  |------|-----------|----------|"
      echo "  | P1 需求 | ${P1_DUR} | ${P1_RW} |"
      echo "  | P2 设计 | ${P2_DUR} | ${P2_RW} |"
      echo "  | P3 拆解 | ${P3_DUR} | ${P3_RW} |"
      echo "  | P4 开发 | ${P4_DUR} | ${P4_RW} |"
      echo "  | P5 验证 | ${P5_DUR} | ${P5_RW} |"
      echo "  | **总计** | **${TOTAL_DUR}** | **${REWORK}** |"
      echo "  Bugs: P0=${BUGS_P0} P1=${BUGS_P1} P2=${BUGS_P2} | 覆盖率: ${COV_RATE}"
      echo ""
    fi

    PROJ_P1_TOTAL=$((PROJ_P1_TOTAL + P1_DUR))
    PROJ_P2_TOTAL=$((PROJ_P2_TOTAL + P2_DUR))
    PROJ_P3_TOTAL=$((PROJ_P3_TOTAL + P3_DUR))
    PROJ_P4_TOTAL=$((PROJ_P4_TOTAL + P4_DUR))
    PROJ_P5_TOTAL=$((PROJ_P5_TOTAL + P5_DUR))
    PROJ_REWORK_TOTAL=$((PROJ_REWORK_TOTAL + REWORK))
    TOTAL_REWORK=$((TOTAL_REWORK + REWORK))
    TOTAL_BUGS_P0=$((TOTAL_BUGS_P0 + BUGS_P0))
    TOTAL_BUGS_P1=$((TOTAL_BUGS_P1 + BUGS_P1))
    TOTAL_BUGS_P2=$((TOTAL_BUGS_P2 + BUGS_P2))
  done

  TOTAL_TASKS=$((TOTAL_TASKS + FILE_COUNT))

  if [ "$FILE_COUNT" -gt 0 ]; then
    AVG_P1=$((PROJ_P1_TOTAL / FILE_COUNT))
    AVG_P2=$((PROJ_P2_TOTAL / FILE_COUNT))
    AVG_P3=$((PROJ_P3_TOTAL / FILE_COUNT))
    AVG_P4=$((PROJ_P4_TOTAL / FILE_COUNT))
    AVG_P5=$((PROJ_P5_TOTAL / FILE_COUNT))
    AVG_REWORK=$((PROJ_REWORK_TOTAL / FILE_COUNT))

    echo "  需求总数: ${FILE_COUNT}"
    echo "  平均耗时(min): P1=${AVG_P1} P2=${AVG_P2} P3=${AVG_P3} P4=${AVG_P4} P5=${AVG_P5}"
    echo "  平均返工次数: ${AVG_REWORK}"

    # 耗时最长阶段
    MAX_DUR=$PROJ_P1_TOTAL
    MAX_PHASE="P1 需求"
    [ "$PROJ_P2_TOTAL" -gt "$MAX_DUR" ] && MAX_DUR=$PROJ_P2_TOTAL && MAX_PHASE="P2 设计"
    [ "$PROJ_P3_TOTAL" -gt "$MAX_DUR" ] && MAX_DUR=$PROJ_P3_TOTAL && MAX_PHASE="P3 拆解"
    [ "$PROJ_P4_TOTAL" -gt "$MAX_DUR" ] && MAX_DUR=$PROJ_P4_TOTAL && MAX_PHASE="P4 开发"
    [ "$PROJ_P5_TOTAL" -gt "$MAX_DUR" ] && MAX_DUR=$PROJ_P5_TOTAL && MAX_PHASE="P5 验证"
    echo "  耗时最长阶段: ${MAX_PHASE}"
  fi
  echo ""
done

echo "============================================"
echo " 全局汇总"
echo "============================================"
echo "需求总数: ${TOTAL_TASKS}"
echo "总返工次数: ${TOTAL_REWORK}"
echo "Bug 分布: P0=${TOTAL_BUGS_P0} P1=${TOTAL_BUGS_P1} P2=${TOTAL_BUGS_P2}"

if [ "$TOTAL_TASKS" -gt 0 ]; then
  AVG_GLOBAL_REWORK=$((TOTAL_REWORK / TOTAL_TASKS))
  echo "平均返工次数/需求: ${AVG_GLOBAL_REWORK}"
fi
echo ""
