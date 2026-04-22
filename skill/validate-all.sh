#!/usr/bin/env bash
# validate-all.sh — Phase Gate 一键门控
# 用法: bash validate-all.sh {project_root} [grade] [phase]
# 退出码: 0=全部通过 1=有失败

set -euo pipefail

PROJECT_ROOT="${1:-.}"
GRADE="${2:-M}"
PHASE="${3:-all}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

TOTAL_CHECKS=0
TOTAL_PASS=0
TOTAL_FAIL=0

echo ""
echo "═══════════════════════════════════"
echo "  Phase Gate 门控验证"
echo "  项目: ${PROJECT_ROOT}"
echo "  级别: ${GRADE}"
echo "  范围: Phase ${PHASE}"
echo "═══════════════════════════════════"

run_check() {
    local name="$1"
    local cmd="$2"
    ((TOTAL_CHECKS++))
    echo ""
    echo "━━━ ${name} ━━━"
    if eval "$cmd"; then
        echo -e "→ ${name}: ${GREEN}PASS${NC}"
        ((TOTAL_PASS++))
    else
        echo -e "→ ${name}: ${RED}FAIL${NC}"
        ((TOTAL_FAIL++))
    fi
}

# S+/S 级: 仅检查 task 文件存在
if [[ "$GRADE" == "S+" || "$GRADE" == "S" ]]; then
    TEAM_DIR="${PROJECT_ROOT}/.team"
    task_count=$(find "${TEAM_DIR}/tasks" -name 'task-*.md' 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$task_count" -gt 0 ]]; then
        echo ""
        echo -e "  ${GREEN}✓${NC} ${task_count} 个 task 文件存在"
        TOTAL_PASS=1
        TOTAL_CHECKS=1
    else
        echo ""
        echo -e "  ${RED}✗${NC} 未找到 task 文件"
        TOTAL_FAIL=1
        TOTAL_CHECKS=1
    fi
else
    # M/L 级: 完整检查

    # L 级额外检查: design.md 和 traceability.md 必须存在
    if [[ "$GRADE" == "L" ]]; then
        run_check "L 级必需文档" "test -f ${PROJECT_ROOT}/.team/design.md && test -f ${PROJECT_ROOT}/.team/traceability.md && echo 'design.md + traceability.md 存在'"
    fi

    # Phase 2 Gate: spec 体系
    if [[ "$PHASE" == "all" || "$PHASE" == "2" ]]; then
        run_check "Spec 文档体系" "bash ${SCRIPT_DIR}/validate-spec.sh ${PROJECT_ROOT} ${GRADE}"
    fi

    # Phase 3 Gate: 测试用例
    if [[ "$PHASE" == "all" || "$PHASE" == "3" ]]; then
        run_check "测试用例质量" "bash ${SCRIPT_DIR}/validate-testcases.sh ${PROJECT_ROOT} ${GRADE}"
    fi

    # Phase 5 Gate: 接口契约
    if [[ "$PHASE" == "all" || "$PHASE" == "5" ]]; then
        run_check "接口契约 vs 源码" "bash ${SCRIPT_DIR}/validate-contracts.sh ${PROJECT_ROOT} --grade=${GRADE}"
    fi
fi

# ─── 总结 ───
echo ""
echo "═══════════════════════════════════"
echo "  门控结果"
echo "═══════════════════════════════════"
echo ""
echo "  检查项: ${TOTAL_CHECKS}"
echo "  通过:   ${TOTAL_PASS}"
echo "  失败:   ${TOTAL_FAIL}"
echo ""

if [[ "$TOTAL_FAIL" -eq 0 ]]; then
    echo -e "${GREEN}ALL PASS${NC} — Phase Gate 通过，可进入下一阶段"
    exit 0
else
    echo -e "${RED}FAIL${NC} — ${TOTAL_FAIL} 项检查未通过，请修复后重新验证"
    exit 1
fi
