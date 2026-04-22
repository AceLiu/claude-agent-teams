#!/usr/bin/env bash
# validate-testcases.sh — 自动检查 testcases.md 的字段完整性、优先级分布和正反向比例
# 用法: bash validate-testcases.sh {project_root}
# 产出: 标准输出统计报告 + PASS/FAIL，退出码 0=通过 1=失败

set -euo pipefail

PROJECT_ROOT="${1:-.}"
TESTCASES="${PROJECT_ROOT}/.team/testcases.md"

GRADE="${2:-M}"
case "$GRADE" in
  S+|S) SKIP_P_DIST=true; SKIP_G_TC=true; MIN_AUTO_PCT=0 ;;
  M)    SKIP_P_DIST=false; SKIP_G_TC=false; MIN_AUTO_PCT=30 ;;
  L)    SKIP_P_DIST=false; SKIP_G_TC=false; MIN_AUTO_PCT=50 ;;
  *)    SKIP_P_DIST=false; SKIP_G_TC=false; MIN_AUTO_PCT=30 ;;
esac

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; ((ERRORS++)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; ((WARNINGS++)); }
info() { echo -e "  ${CYAN}ℹ${NC} $1"; }

echo ""
echo "═══ 测试用例验证 ═══"
echo ""
info "级别: ${GRADE}"

# ─── 文件检查 ───
if [[ ! -f "$TESTCASES" ]]; then
    fail "testcases.md 不存在: ${TESTCASES}"
    exit 1
fi

# ─── 提取 §2 测试用例表格行 ───
# TC 行格式: | TC-xxx | AC-xxx | ... |
TC_LINES=$(grep -E '^\|[[:space:]]*TC-' "$TESTCASES" 2>/dev/null || true)
TC_COUNT=$(echo "$TC_LINES" | grep -c . 2>/dev/null || echo 0)

echo "── 基本统计 ──"
info "测试用例总数: ${TC_COUNT}"

if [[ "$TC_COUNT" -eq 0 ]]; then
    fail "testcases.md §2 中未检测到 TC 行"
    exit 1
fi

# ─── 字段完整性检查 ───
echo ""
echo "── 字段完整性（10 字段）──"

# 期望格式: | ID | AC | API | 类型 | 级别 | 标题 | 前置 | 步骤 | 预期 | 反向 |
# 即 10 个内容列 = 11 个 | 分隔符
INCOMPLETE=0
while IFS= read -r line; do
    # 统计 | 数量
    pipe_count=$(echo "$line" | tr -cd '|' | wc -c | tr -d ' ')
    if [[ "$pipe_count" -lt 11 ]]; then
        ((INCOMPLETE++))
        tc_id=$(echo "$line" | grep -oE 'TC-[A-Z]+-[0-9]+|TC-[0-9]+' | head -1)
        warn "${tc_id:-未知TC}: 列数不足 (${pipe_count} 个分隔符，期望 ≥11)"
    fi
done <<< "$TC_LINES"

if [[ "$INCOMPLETE" -eq 0 ]]; then
    pass "全部 TC 均为 10 列完整"
else
    fail "${INCOMPLETE}/${TC_COUNT} 条 TC 列数不完整"
fi

# 检查空字段
EMPTY_FIELDS=0
while IFS= read -r line; do
    # 提取各列内容（跳过首尾 |）
    cols=$(echo "$line" | sed 's/^|//;s/|$//' | tr '|' '\n')
    col_idx=0
    while IFS= read -r col; do
        ((col_idx++))
        trimmed=$(echo "$col" | xargs 2>/dev/null || echo "$col")
        if [[ -z "$trimmed" ]]; then
            ((EMPTY_FIELDS++))
        fi
    done <<< "$cols"
done <<< "$TC_LINES"

if [[ "$EMPTY_FIELDS" -eq 0 ]]; then
    pass "无空字段"
else
    warn "${EMPTY_FIELDS} 个空字段（应填 '无' 或 '-'）"
fi

# ─── 优先级分布 ───
echo ""
echo "── 优先级分布（P1-P5）──"

P1=$(echo "$TC_LINES" | grep -cE '\|\s*P1\s*\|' 2>/dev/null || echo 0)
P2=$(echo "$TC_LINES" | grep -cE '\|\s*P2\s*\|' 2>/dev/null || echo 0)
P3=$(echo "$TC_LINES" | grep -cE '\|\s*P3\s*\|' 2>/dev/null || echo 0)
P4=$(echo "$TC_LINES" | grep -cE '\|\s*P4\s*\|' 2>/dev/null || echo 0)
P5=$(echo "$TC_LINES" | grep -cE '\|\s*P5\s*\|' 2>/dev/null || echo 0)
P_UNKNOWN=$((TC_COUNT - P1 - P2 - P3 - P4 - P5))

pct() {
    if [[ "$TC_COUNT" -gt 0 ]]; then
        echo $(( $1 * 100 / TC_COUNT ))
    else
        echo 0
    fi
}

P1_PCT=$(pct $P1)
P2_PCT=$(pct $P2)
P3_PCT=$(pct $P3)
P4_PCT=$(pct $P4)
P5_PCT=$(pct $P5)

info "P1(冒烟):  ${P1} 条 (${P1_PCT}%)  目标 ~10%"
info "P2(基本):  ${P2} 条 (${P2_PCT}%)  目标 ~40%"
info "P3(核心反向): ${P3} 条 (${P3_PCT}%)  目标 ~20%"
info "P4(基本反向): ${P4} 条 (${P4_PCT}%)  目标 ~20%"
info "P5(低频):  ${P5} 条 (${P5_PCT}%)  目标 ~10%"

if [[ "$P_UNKNOWN" -gt 0 ]]; then
    fail "${P_UNKNOWN} 条 TC 优先级无法识别（非 P1-P5）"
fi

# 检查分布偏差（允许 ±15%）
check_pct_range() {
    local actual=$1
    local target=$2
    local label=$3
    local low=$((target - 15))
    local high=$((target + 15))
    [[ "$low" -lt 0 ]] && low=0
    if [[ "$actual" -lt "$low" || "$actual" -gt "$high" ]]; then
        warn "${label}: ${actual}% 偏离目标 ${target}%（允许 ${low}%-${high}%）"
        info "  修复建议: 调整 TC 优先级，${label} 目标 ${target}%±15%"
    fi
}

if $SKIP_P_DIST; then
    info "S/S+ 级跳过 P 分布偏差检查"
else
    if [[ "$TC_COUNT" -ge 10 ]]; then
        check_pct_range "$P1_PCT" 10 "P1"
        check_pct_range "$P2_PCT" 40 "P2"
        check_pct_range "$P3_PCT" 20 "P3"
        check_pct_range "$P4_PCT" 20 "P4"
        check_pct_range "$P5_PCT" 10 "P5"
    else
        info "TC 数量 < 10，跳过分布偏差检查"
    fi
fi

# ─── 正反向比例 ───
echo ""
echo "── 正反向比例 ──"

REVERSE=$(echo "$TC_LINES" | grep -ciE '\|\s*是\s*\|?\s*$' 2>/dev/null || echo 0)
FORWARD=$((TC_COUNT - REVERSE))

if [[ "$TC_COUNT" -gt 0 ]]; then
    FWD_PCT=$((FORWARD * 100 / TC_COUNT))
    REV_PCT=$((REVERSE * 100 / TC_COUNT))
else
    FWD_PCT=0
    REV_PCT=0
fi

info "正向: ${FORWARD} 条 (${FWD_PCT}%)  反向: ${REVERSE} 条 (${REV_PCT}%)"
info "目标比例: 正向 ~40%, 反向 ~60%"

if [[ "$REV_PCT" -lt 30 && "$TC_COUNT" -ge 8 ]]; then
    warn "反向用例占比 ${REV_PCT}%，偏低（目标 ≥40%）"
fi
if [[ "$FWD_PCT" -lt 20 && "$TC_COUNT" -ge 8 ]]; then
    warn "正向用例占比 ${FWD_PCT}%，偏低（目标 ≥30%）"
fi

# ─── 每 G-xxx 的 TC 数量 ───
echo ""
echo "── 每功能点 TC 数量 ──"

if $SKIP_G_TC; then
    info "S/S+ 级跳过每 G TC 数量检查"
else
    # 从 spec.md 提取 G-xxx
    SPEC="${PROJECT_ROOT}/.team/spec.md"
    if [[ -f "$SPEC" ]]; then
        G_IDS=$(grep -oE 'G-[0-9]+' "$SPEC" 2>/dev/null | sort -t'-' -k2 -n | uniq)
        G_COUNT=$(echo "$G_IDS" | grep -c . 2>/dev/null || echo 0)

        if [[ "$G_COUNT" -gt 0 ]]; then
            UNDER_MIN=0
            while IFS= read -r gid; do
                # 通过 AC 间接关联: G → AC → TC
                # 先找该 G 关联的 AC
                acs=$(grep -E "$gid" "$TESTCASES" 2>/dev/null | grep -oE 'AC-[0-9]+' | sort -u)
                tc_for_g=0
                if [[ -n "$acs" ]]; then
                    while IFS= read -r ac; do
                        count=$(echo "$TC_LINES" | grep -c "$ac" 2>/dev/null || echo 0)
                        tc_for_g=$((tc_for_g + count))
                    done <<< "$acs"
                fi
                if [[ "$tc_for_g" -lt 8 ]]; then
                    warn "${gid}: ${tc_for_g} 条 TC（最低 8 条）"
                    info "  修复建议: 为 ${gid} 补充 TC，参考 5 维拆解法（正向/边界/异常/状态/数据）"
                    ((UNDER_MIN++))
                else
                    pass "${gid}: ${tc_for_g} 条 TC"
                fi
            done <<< "$G_IDS"

            if [[ "$UNDER_MIN" -eq 0 ]]; then
                pass "所有 G-xxx 均 ≥8 条 TC"
            fi
        else
            info "spec.md 中未检测到 G-xxx"
        fi
    else
        info "spec.md 不存在，跳过 G-xxx TC 数量检查"
    fi
fi

# ─── 自动化标注检查 ───
echo ""
echo "── 自动化标注 ──"

AUTO_COUNT=$(echo "$TC_LINES" | grep -c '(自动化)' 2>/dev/null || echo 0)
AUTO_PCT=$((AUTO_COUNT * 100 / TC_COUNT))
info "标注 (自动化) 的用例: ${AUTO_COUNT}/${TC_COUNT} (${AUTO_PCT}%)"

if [[ "$MIN_AUTO_PCT" -gt 0 && "$AUTO_PCT" -lt "$MIN_AUTO_PCT" ]]; then
    warn "自动化标注率 ${AUTO_PCT}%，建议提高（目标 ≥${MIN_AUTO_PCT}%）"
fi

# ─── AC 关联检查 ───
echo ""
echo "── AC 关联完整性 ──"

NO_AC=0
while IFS= read -r line; do
    if ! echo "$line" | grep -qE 'AC-[0-9]+'; then
        ((NO_AC++))
        tc_id=$(echo "$line" | grep -oE 'TC-[A-Z]+-[0-9]+|TC-[0-9]+' | head -1)
        warn "${tc_id:-未知TC}: 未关联 AC-xxx"
        info "  修复建议: 为 ${tc_id:-未知TC} 在第 2 列补充关联的 AC-xxx"
    fi
done <<< "$TC_LINES"

if [[ "$NO_AC" -eq 0 ]]; then
    pass "全部 TC 均关联了 AC-xxx"
else
    fail "${NO_AC} 条 TC 未关联 AC-xxx"
fi

# ─── 总结 ───
echo ""
echo "═══ 验证结果 ═══"
echo ""
echo "  总计: ${TC_COUNT} 条 TC"
echo "  P 分布: P1=${P1} P2=${P2} P3=${P3} P4=${P4} P5=${P5}"
echo "  正反向: 正向=${FORWARD}(${FWD_PCT}%) 反向=${REVERSE}(${REV_PCT}%)"
echo "  自动化: ${AUTO_COUNT}(${AUTO_PCT}%)"
echo ""

if [[ "$ERRORS" -eq 0 && "$WARNINGS" -eq 0 ]]; then
    echo -e "${GREEN}PASS${NC} — 全部检查通过"
elif [[ "$ERRORS" -eq 0 ]]; then
    echo -e "${YELLOW}PASS (有警告)${NC} — ${WARNINGS} 个警告"
else
    echo -e "${RED}FAIL${NC} — ${ERRORS} 个错误, ${WARNINGS} 个警告"
fi

echo ""
exit $((ERRORS > 0 ? 1 : 0))
