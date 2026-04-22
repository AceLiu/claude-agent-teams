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
  PROJ_SPEC_TOTAL=0
  PROJ_DEV_TOTAL=0
  PROJ_REVIEW_TOTAL=0
  PROJ_TEST_TOTAL=0
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
          (p.spec||{}).duration_min||0,
          (p.develop||{}).duration_min||0,
          (p.review||{}).duration_min||0,
          (p.testing||{}).duration_min||0,
          (p.spec||{}).rework_count||0,
          (p.develop||{}).rework_count||0,
          (p.review||{}).rework_count||0,
          (p.testing||{}).rework_count||0,
          bugs.P0||0, bugs.P1||0, bugs.P2||0,
          cov.coverage_rate||0
        ].join('|'));
      } catch(e) { process.exit(1); }
    " 2>/dev/null) || continue

    IFS='|' read -r REQ_NAME LEVEL DATE SPEC_DUR DEV_DUR REVIEW_DUR TEST_DUR \
      SPEC_RW DEV_RW REVIEW_RW TEST_RW BUGS_P0 BUGS_P1 BUGS_P2 COV_RATE <<< "$METRICS_JSON"

    REWORK=$((SPEC_RW + DEV_RW + REVIEW_RW + TEST_RW))
    TOTAL_DUR=$((SPEC_DUR + DEV_DUR + REVIEW_DUR + TEST_DUR))

    if [ "$SHOW_ALL" = true ]; then
      echo "  ### ${REQ_NAME} (${LEVEL}级, ${DATE})"
      echo "  | 阶段 | 耗时(min) | 返工次数 |"
      echo "  |------|-----------|----------|"
      echo "  | Spec | ${SPEC_DUR} | ${SPEC_RW} |"
      echo "  | Dev  | ${DEV_DUR} | ${DEV_RW} |"
      echo "  | Review | ${REVIEW_DUR} | ${REVIEW_RW} |"
      echo "  | Test | ${TEST_DUR} | ${TEST_RW} |"
      echo "  | **总计** | **${TOTAL_DUR}** | **${REWORK}** |"
      echo "  Bugs: P0=${BUGS_P0} P1=${BUGS_P1} P2=${BUGS_P2} | 覆盖率: ${COV_RATE}"
      echo ""
    fi

    PROJ_SPEC_TOTAL=$((PROJ_SPEC_TOTAL + SPEC_DUR))
    PROJ_DEV_TOTAL=$((PROJ_DEV_TOTAL + DEV_DUR))
    PROJ_REVIEW_TOTAL=$((PROJ_REVIEW_TOTAL + REVIEW_DUR))
    PROJ_TEST_TOTAL=$((PROJ_TEST_TOTAL + TEST_DUR))
    PROJ_REWORK_TOTAL=$((PROJ_REWORK_TOTAL + REWORK))
    TOTAL_REWORK=$((TOTAL_REWORK + REWORK))
    TOTAL_BUGS_P0=$((TOTAL_BUGS_P0 + BUGS_P0))
    TOTAL_BUGS_P1=$((TOTAL_BUGS_P1 + BUGS_P1))
    TOTAL_BUGS_P2=$((TOTAL_BUGS_P2 + BUGS_P2))
  done

  TOTAL_TASKS=$((TOTAL_TASKS + FILE_COUNT))

  if [ "$FILE_COUNT" -gt 0 ]; then
    AVG_SPEC=$((PROJ_SPEC_TOTAL / FILE_COUNT))
    AVG_DEV=$((PROJ_DEV_TOTAL / FILE_COUNT))
    AVG_REVIEW=$((PROJ_REVIEW_TOTAL / FILE_COUNT))
    AVG_TEST=$((PROJ_TEST_TOTAL / FILE_COUNT))
    AVG_REWORK=$((PROJ_REWORK_TOTAL / FILE_COUNT))

    echo "  需求总数: ${FILE_COUNT}"
    echo "  平均耗时(min): Spec=${AVG_SPEC} Dev=${AVG_DEV} Review=${AVG_REVIEW} Test=${AVG_TEST}"
    echo "  平均返工次数: ${AVG_REWORK}"

    # 返工热力图：找出返工最多的阶段
    MAX_RW=$PROJ_SPEC_TOTAL
    MAX_PHASE="Spec"
    [ "$PROJ_DEV_TOTAL" -gt "$MAX_RW" ] && MAX_RW=$PROJ_DEV_TOTAL && MAX_PHASE="Dev"
    [ "$PROJ_REVIEW_TOTAL" -gt "$MAX_RW" ] && MAX_RW=$PROJ_REVIEW_TOTAL && MAX_PHASE="Review"
    [ "$PROJ_TEST_TOTAL" -gt "$MAX_RW" ] && MAX_RW=$PROJ_TEST_TOTAL && MAX_PHASE="Test"
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
