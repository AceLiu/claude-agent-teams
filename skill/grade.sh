#!/usr/bin/env bash
# grade.sh — 交互式定级工具
# 用法: bash grade.sh [project_root]
# 产出: 推荐级别 + 对应命令 + 产出物清单

set -euo pipefail

PROJECT_ROOT="${1:-.}"

# 颜色
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}═══ Agent Teams 定级工具 ═══${NC}"
echo ""

read -p "Q1: 改动 ≤3 文件、≤50 行，无接口/DB 变更？(y/n) " q1
if [[ "$q1" == "y" || "$q1" == "Y" ]]; then
    echo ""
    echo -e "${GREEN}→ 级别: S+ (Autopilot)${NC}"
    echo ""
    echo "  执行方式: 全自动 — Dev(sonnet)→Review→完成"
    echo "  产出物:   tasks/task-001.md (自动)"
    echo ""
    echo "  启动命令:"
    echo -e "    ${CYAN}bash init-team.sh ${PROJECT_ROOT} --grade=S+${NC}"
    echo ""
    echo "  Phase 跳过: 1-5 全跳，直接写 task 并执行"
    exit 0
fi

read -p "Q2: AC ≤5，单角色能搞定，无跨模块依赖？(y/n) " q2
if [[ "$q2" == "y" || "$q2" == "Y" ]]; then
    echo ""
    echo -e "${GREEN}→ 级别: S${NC}"
    echo ""
    echo "  执行方式: Leader 写 task → Dev → Reviewer → 验收"
    echo "  产出物:"
    echo "    ✓ tasks/task-001.md (需求 3-5 句 + AC ≤5 条)"
    echo "    ✓ reviews/ (Reviewer 产出)"
    echo ""
    echo "  启动命令:"
    echo -e "    ${CYAN}bash init-team.sh ${PROJECT_ROOT} --grade=S${NC}"
    echo ""
    echo "  Phase 跳过: Phase 1-3 跳过，直接进 Phase 4"
    exit 0
fi

read -p "Q3: AC >10 或 ≥3 Dev 角色或跨模块大工程？(y/n) " q3
if [[ "$q3" == "y" || "$q3" == "Y" ]]; then
    echo ""
    echo -e "${YELLOW}→ 级别: L (完整流程)${NC}"
    echo ""
    echo "  执行方式: 完整 5 Phase + Critic 终审 + retro 必做"
    echo "  产出物:"
    echo "    ✓ spec.md          (PM 产出，完整 6 章)"
    echo "    ✓ testcases.md     (AC + TC 全覆盖)"
    echo "    ✓ design.md        (5 章 + ADR)"
    echo "    ✓ contracts.md     (接口契约)"
    echo "    ✓ traceability.md  (追溯矩阵)"
    echo "    ✓ tasks/task-*.md  (Leader 拆解)"
    echo "    ✓ reviews/         (批量审查 + Critic 终审)"
    echo "    ✓ test-reports/    (渐进测试报告)"
    echo ""
    echo "  启动命令:"
    echo -e "    ${CYAN}bash init-team.sh ${PROJECT_ROOT} --grade=L${NC}"
    echo ""
    echo "  必须角色: PM, Architect, TaskExecutor, Tester, Reviewer, Critic"
    exit 0
fi

echo ""
echo -e "${GREEN}→ 级别: M (标准流程，最常用)${NC}"
echo ""
echo "  执行方式: Phase 1+2 合并 → Phase 3-5"
echo "  产出物:"
echo "    ✓ spec-lite.md     (Architect 产出，3-5 章)"
echo "    ✓ testcases.md     (AC + TC)"
echo "    ✓ contracts.md     (简版接口契约)"
echo "    ✓ tasks/task-*.md  (Leader 拆解，1-3 个)"
echo "    ✓ reviews/         (批量审查)"
echo ""
echo "  启动命令:"
echo -e "    ${CYAN}bash init-team.sh ${PROJECT_ROOT} --grade=M${NC}"
echo ""
echo "  角色: Architect, TaskExecutor, Tester, Reviewer"
echo "  Critic: P1 bug ≥3 时条件触发"
