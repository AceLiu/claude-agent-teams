#!/usr/bin/env bash
# validate-spec.sh — 自动检查 Spec 文档体系的 ID 连续性和追溯覆盖率
# 用法: bash validate-spec.sh {project_root}
# 产出: 标准输出 PASS/FAIL 报告，退出码 0=全通过 1=有失败

set -euo pipefail

PROJECT_ROOT="${1:-.}"
TEAM_DIR="${PROJECT_ROOT}/.team"

# 分级参数
GRADE="${2:-M}"
case "$GRADE" in
  S+|S) MIN_G_AC_COV=0; MIN_AC_TC_COV=0; REQUIRE_TRACEABILITY=false; CHECK_DEC=false ;;
  M)    MIN_G_AC_COV=70; MIN_AC_TC_COV=70; REQUIRE_TRACEABILITY=false; CHECK_DEC=true ;;
  L)    MIN_G_AC_COV=100; MIN_AC_TC_COV=80; REQUIRE_TRACEABILITY=true; CHECK_DEC=true ;;
  *)    MIN_G_AC_COV=70; MIN_AC_TC_COV=70; REQUIRE_TRACEABILITY=false; CHECK_DEC=true ;;
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

# ─── 检查文件存在 ───
echo ""
echo "═══ Spec 文档体系验证 ═══"
info "级别: ${GRADE} | G→AC≥${MIN_G_AC_COV}% | AC→TC≥${MIN_AC_TC_COV}%"
echo ""
echo "── 文件存在性 ──"

SPEC="${TEAM_DIR}/spec.md"
TESTCASES="${TEAM_DIR}/testcases.md"
CONTRACTS="${TEAM_DIR}/contracts.md"
DESIGN="${TEAM_DIR}/design.md"
TRACEABILITY="${TEAM_DIR}/traceability.md"

for f in "$SPEC" "$TESTCASES" "$CONTRACTS" "$DESIGN"; do
    if [[ -f "$f" ]]; then
        pass "$(basename "$f") 存在"
    else
        fail "$(basename "$f") 不存在"
    fi
done

if [[ ! -f "$SPEC" ]]; then
    echo ""
    fail "spec.md 不存在，无法继续验证"
    exit 1
fi

# ─── 提取各类 ID ───
echo ""
echo "── ID 提取 ──"

extract_ids() {
    local file="$1"
    local prefix="$2"
    if [[ ! -f "$file" ]]; then
        echo ""
        return
    fi
    grep -oE "${prefix}-[0-9]+" "$file" 2>/dev/null | sort -t'-' -k2 -n | uniq
}

G_IDS=$(extract_ids "$SPEC" "G")
NFR_IDS=$(extract_ids "$SPEC" "NFR")
A_IDS=$(extract_ids "$SPEC" "A")
D_IDS=$(extract_ids "$SPEC" "D")
R_IDS=$(extract_ids "$SPEC" "R")
AC_IDS=$(extract_ids "$TESTCASES" "AC")
TC_IDS=$(extract_ids "$TESTCASES" "TC")
API_IDS=$(extract_ids "$CONTRACTS" "API")
DEC_IDS=$(extract_ids "$DESIGN" "DEC")

count_ids() { echo "$1" | grep -c . 2>/dev/null || echo 0; }

G_COUNT=$(count_ids "$G_IDS")
NFR_COUNT=$(count_ids "$NFR_IDS")
A_COUNT=$(count_ids "$A_IDS")
D_COUNT=$(count_ids "$D_IDS")
R_COUNT=$(count_ids "$R_IDS")
AC_COUNT=$(count_ids "$AC_IDS")
TC_COUNT=$(count_ids "$TC_IDS")
API_COUNT=$(count_ids "$API_IDS")
DEC_COUNT=$(count_ids "$DEC_IDS")

info "G-xxx: ${G_COUNT}  NFR-xxx: ${NFR_COUNT}  A-xxx: ${A_COUNT}  D-xxx: ${D_COUNT}"
info "R-xxx: ${R_COUNT}  AC-xxx: ${AC_COUNT}  TC-xxx: ${TC_COUNT}"
info "API-xxx: ${API_COUNT}  DEC-xxx: ${DEC_COUNT}"

# ─── ID 连续性检查 ───
echo ""
echo "── ID 连续性 ──"

check_continuity() {
    local ids="$1"
    local prefix="$2"
    local count
    count=$(count_ids "$ids")

    if [[ "$count" -eq 0 ]]; then
        info "${prefix}-xxx: 无 ID（跳过）"
        return
    fi

    local expected=1
    local broken=0
    while IFS= read -r id; do
        local num
        num=$(echo "$id" | grep -oE '[0-9]+$' | sed 's/^0*//')
        num=${num:-0}
        if [[ "$num" -ne "$expected" ]]; then
            broken=1
            fail "${prefix}-xxx 跳号: 期望 ${prefix}-$(printf '%03d' $expected)，实际 ${id}"
        fi
        ((expected++))
    done <<< "$ids"

    if [[ "$broken" -eq 0 ]]; then
        pass "${prefix}-xxx 连续 (${count} 条)"
    fi
}

check_continuity "$G_IDS" "G"
check_continuity "$NFR_IDS" "NFR"
check_continuity "$A_IDS" "A"
check_continuity "$D_IDS" "D"
check_continuity "$R_IDS" "R"
check_continuity "$AC_IDS" "AC"
check_continuity "$API_IDS" "API"
check_continuity "$DEC_IDS" "DEC"

# TC 使用模块前缀，不检查纯数字连续性，只检查存在性
if [[ "$TC_COUNT" -gt 0 ]]; then
    pass "TC-xxx 存在 (${TC_COUNT} 条)"
else
    if [[ -f "$TESTCASES" ]]; then
        warn "TC-xxx: 0 条（testcases.md 存在但无 TC）"
    fi
fi

# ─── 追溯覆盖率 ───
echo ""
echo "── 追溯覆盖率 ──"

# G → AC 覆盖率
if [[ "$G_COUNT" -gt 0 && -f "$TESTCASES" ]]; then
    uncovered_g=""
    covered=0
    while IFS= read -r gid; do
        if grep -q "$gid" "$TESTCASES" 2>/dev/null; then
            ((covered++))
        else
            uncovered_g="${uncovered_g} ${gid}"
        fi
    done <<< "$G_IDS"
    pct=$((covered * 100 / G_COUNT))
    if [[ "$MIN_G_AC_COV" -eq 0 ]]; then
        info "G→AC: S/S+ 级跳过覆盖率检查"
    elif [[ "$pct" -ge "$MIN_G_AC_COV" ]]; then
        pass "G→AC 覆盖率: ${covered}/${G_COUNT} (${pct}%)"
    else
        fail "G→AC 覆盖率: ${covered}/${G_COUNT} (${pct}%) — 低于 ${MIN_G_AC_COV}%"
        if [[ -n "$uncovered_g" ]]; then
            info "  缺失 AC 的目标:${uncovered_g}"
            info "  修复建议: 在 testcases.md §1 为上述 G-xxx 补充 AC 条目"
        fi
    fi
else
    info "G→AC: 无法检查（G=${G_COUNT}, testcases=$([ -f "$TESTCASES" ] && echo '存在' || echo '不存在')）"
fi

# NFR → AC 覆盖率
if [[ "$NFR_COUNT" -gt 0 && -f "$TESTCASES" ]]; then
    uncovered_nfr=""
    covered=0
    while IFS= read -r nid; do
        if grep -q "$nid" "$TESTCASES" 2>/dev/null; then
            ((covered++))
        else
            uncovered_nfr="${uncovered_nfr} ${nid}"
        fi
    done <<< "$NFR_IDS"
    pct=$((covered * 100 / NFR_COUNT))
    if [[ "$MIN_G_AC_COV" -eq 0 ]]; then
        info "NFR→AC: S/S+ 级跳过覆盖率检查"
    elif [[ "$pct" -ge "$MIN_G_AC_COV" ]]; then
        pass "NFR→AC 覆盖率: ${covered}/${NFR_COUNT} (${pct}%)"
    else
        fail "NFR→AC 覆盖率: ${covered}/${NFR_COUNT} (${pct}%) — 低于 ${MIN_G_AC_COV}%"
        if [[ -n "$uncovered_nfr" ]]; then
            info "  缺失 AC 的目标:${uncovered_nfr}"
            info "  修复建议: 在 testcases.md §1 为上述 NFR-xxx 补充 AC 条目"
        fi
    fi
else
    info "NFR→AC: 无法检查"
fi

# AC → TC 覆盖率
if [[ "$AC_COUNT" -gt 0 && "$TC_COUNT" -gt 0 ]]; then
    uncovered_ac=""
    covered=0
    while IFS= read -r acid; do
        if grep -q "$acid" "$TESTCASES" 2>/dev/null && echo "$TC_IDS" | head -1 >/dev/null; then
            # 检查 §2 中是否有 TC 行引用了该 AC
            if grep -E "^\\|.*${acid}" "$TESTCASES" 2>/dev/null | grep -qE "TC-" 2>/dev/null; then
                ((covered++))
            else
                uncovered_ac="${uncovered_ac} ${acid}"
            fi
        else
            uncovered_ac="${uncovered_ac} ${acid}"
        fi
    done <<< "$AC_IDS"
    pct=$((covered * 100 / AC_COUNT))
    if [[ "$MIN_AC_TC_COV" -eq 0 ]]; then
        info "AC→TC: S/S+ 级跳过覆盖率检查"
    elif [[ "$pct" -ge "$MIN_AC_TC_COV" ]]; then
        pass "AC→TC 覆盖率: ${covered}/${AC_COUNT} (${pct}%)"
    else
        fail "AC→TC 覆盖率: ${covered}/${AC_COUNT} (${pct}%) — 低于 ${MIN_AC_TC_COV}%"
        if [[ -n "$uncovered_ac" ]]; then
            info "  缺失 TC 的验收标准:${uncovered_ac}"
            info "  修复建议: 在 testcases.md §2 为上述 AC-xxx 补充 TC 条目"
        fi
    fi
else
    info "AC→TC: 无法检查（AC=${AC_COUNT}, TC=${TC_COUNT}）"
fi

# API 覆盖率（每个 API 应在 contracts.md 中有定义）
if [[ "$API_COUNT" -gt 0 ]]; then
    pass "API-xxx 定义: ${API_COUNT} 个接口"
else
    if [[ -f "$CONTRACTS" ]]; then
        warn "contracts.md 存在但未检测到 API-xxx 定义"
    fi
fi

# R → design.md 缓解方案覆盖
if [[ "$R_COUNT" -gt 0 && -f "$DESIGN" ]]; then
    uncovered_r=""
    covered=0
    while IFS= read -r rid; do
        if grep -q "$rid" "$DESIGN" 2>/dev/null; then
            ((covered++))
        else
            uncovered_r="${uncovered_r} ${rid}"
        fi
    done <<< "$R_IDS"
    pct=$((covered * 100 / R_COUNT))
    if [[ "$pct" -ge 100 ]]; then
        pass "R→缓解方案 覆盖率: ${covered}/${R_COUNT} (${pct}%)"
    else
        fail "R→缓解方案 覆盖率: ${covered}/${R_COUNT} (${pct}%) — 需 100%"
        if [[ -n "$uncovered_r" ]]; then
            info "  缺失缓解方案的风险:${uncovered_r}"
            info "  修复建议: 在 design.md 中为上述 R-xxx 补充缓解方案"
        fi
    fi
else
    info "R→缓解方案: 无法检查"
fi

# ─── 孤立 ID 检查 ───
echo ""
echo "── 孤立 ID 检查 ──"

# AC 无 G/NFR 关联（在 §1 验收标准表中检查）
if [[ "$AC_COUNT" -gt 0 && -f "$TESTCASES" ]]; then
    orphan_ac=0
    while IFS= read -r acid; do
        # 在 testcases.md 中找到包含该 AC 的行，检查是否也包含 G-xxx 或 NFR-xxx
        ac_lines=$(grep -E "$acid" "$TESTCASES" 2>/dev/null || true)
        if [[ -n "$ac_lines" ]]; then
            if ! echo "$ac_lines" | grep -qE "(G-[0-9]+|NFR-[0-9]+)"; then
                warn "孤立 AC: ${acid} — 未关联任何 G/NFR"
                ((orphan_ac++))
            fi
        fi
    done <<< "$AC_IDS"
    if [[ "$orphan_ac" -eq 0 ]]; then
        pass "无孤立 AC（全部关联 G/NFR）"
    else
        fail "${orphan_ac} 条 AC 未关联 G/NFR"
        info "  修复建议: 在 testcases.md §1 的 AC 行中补充关联的 G-xxx/NFR-xxx"
    fi
fi

# TASK 无 AC 关联
TASK_DIR="${TEAM_DIR}/tasks"
if [[ -d "$TASK_DIR" ]]; then
    task_files=$(find "$TASK_DIR" -name 'task-*.md' 2>/dev/null || true)
    if [[ -n "$task_files" ]]; then
        orphan_task=0
        while IFS= read -r tf; do
            [[ -f "$tf" ]] || continue
            if ! grep -qE "AC-[0-9]+" "$tf"; then
                warn "孤立 TASK: $(basename "$tf") — 未关联任何 AC"
                info "  修复建议: 在 task 文件的验收标准部分补充关联的 AC-xxx"
                ((orphan_task++))
            fi
        done <<< "$task_files"
        if [[ "$orphan_task" -eq 0 ]]; then
            pass "无孤立 TASK（全部关联 AC）"
        fi
    fi
fi

# ─── 追溯矩阵完整性 ───
echo ""
echo "── 追溯矩阵 (traceability.md) ──"

if [[ -f "$TRACEABILITY" ]]; then
    trace_missing=0
    while IFS= read -r gid; do
        if ! grep -q "$gid" "$TRACEABILITY" 2>/dev/null; then
            warn "追溯矩阵缺失: ${gid} 未出现在 traceability.md"
            ((trace_missing++))
        fi
    done <<< "$G_IDS"
    if [[ "$trace_missing" -eq 0 ]]; then
        pass "追溯矩阵覆盖全部 G-xxx (${G_COUNT} 条)"
    else
        fail "追溯矩阵缺失 ${trace_missing}/${G_COUNT} 个 G-xxx"
    fi
else
    if $REQUIRE_TRACEABILITY; then
        fail "L 级必须有 traceability.md"
    else
        info "traceability.md 不存在（${GRADE} 级可选）"
    fi
fi

# ─── DEC 自审核完整性 ───
if $CHECK_DEC && [[ "$DEC_COUNT" -gt 0 && -f "$DESIGN" ]]; then
    echo ""
    echo "── DEC 自审核检查 ──"
    incomplete_dec=0

    while IFS= read -r dec; do
        # 提取 DEC 块内容（从该 DEC 到下一个 DEC 或文件末尾）
        dec_block=$(sed -n "/${dec}/,/^###.*DEC-\|^## /p" "$DESIGN" 2>/dev/null | head -50)
        unchecked=$(echo "$dec_block" | grep -c '\[ \]' 2>/dev/null || echo 0)
        total_checks=$(echo "$dec_block" | grep -cE '\[[ x]\]' 2>/dev/null || echo 0)

        if [[ "$total_checks" -eq 0 ]]; then
            warn "${dec}: 无自审核清单（可能格式不匹配）"
        elif [[ "$unchecked" -gt 0 ]]; then
            fail "${dec}: ${unchecked}/${total_checks} 项自审核未勾选"
            info "  修复建议: 在 design.md 中完成 ${dec} 的自审核，勾选所有 [ ] 项"
            ((incomplete_dec++))
        else
            pass "${dec}: 自审核全部完成 (${total_checks} 项)"
        fi
    done <<< "$DEC_IDS"

    if [[ "$incomplete_dec" -eq 0 ]]; then
        pass "全部 DEC 自审核已完成"
    fi
fi

# ─── spec.md 章节完整性 ───
echo ""
echo "── spec.md 章节检查 ──"

check_section() {
    local file="$1"
    local pattern="$2"
    local label="$3"
    if grep -qE "$pattern" "$file" 2>/dev/null; then
        pass "$label"
    else
        fail "$label 缺失"
    fi
}

check_section "$SPEC" "^## 1\." "第 1 章: 需求"
check_section "$SPEC" "^## 2\." "第 2 章: 接口契约（引用）"
check_section "$SPEC" "^## 3\." "第 3 章: 验收标准（引用）"
check_section "$SPEC" "^## 4\." "第 4 章: 风险评估"
check_section "$SPEC" "^## 5\." "第 5 章: 追溯矩阵"
check_section "$SPEC" "^## 6\." "第 6 章: 变更记录"

# ─── 总结 ───
echo ""
echo "═══ 验证结果 ═══"
echo ""

TOTAL=$((ERRORS + WARNINGS))
if [[ "$ERRORS" -eq 0 && "$WARNINGS" -eq 0 ]]; then
    echo -e "${GREEN}PASS${NC} — 全部检查通过"
elif [[ "$ERRORS" -eq 0 ]]; then
    echo -e "${YELLOW}PASS (有警告)${NC} — ${WARNINGS} 个警告"
else
    echo -e "${RED}FAIL${NC} — ${ERRORS} 个错误, ${WARNINGS} 个警告"
fi

echo ""
exit $((ERRORS > 0 ? 1 : 0))
