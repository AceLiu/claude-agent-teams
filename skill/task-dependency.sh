#!/usr/bin/env bash
# task-dependency.sh — 任务依赖分析与拓扑排序
# 用法: bash task-dependency.sh <project_root>
# 产出: 依赖图 + 文件冲突检测 + 分批派发建议
# 退出码: 0=无冲突 1=有冲突（需人工确认）

set -euo pipefail

PROJECT_ROOT="${1:?用法: task-dependency.sh <project_root>}"
TASK_DIR="${PROJECT_ROOT}/.team/tasks"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
info() { echo -e "  ${CYAN}ℹ${NC} $1"; }

CONFLICTS=0
TASK_COUNT=0

echo ""
echo -e "${BOLD}═══ 任务依赖分析 ═══${NC}"
echo ""

# ─── 检查 task 目录 ───
if [[ ! -d "$TASK_DIR" ]]; then
    fail "任务目录不存在: ${TASK_DIR}"
    exit 1
fi

# ─── 提取每个 task 的修改文件列表 ───
declare -A TASK_FILES  # task_id -> file list (newline separated)
declare -A TASK_DEPS   # task_id -> depends_on list
declare -A TASK_AC     # task_id -> AC list

echo "── 任务扫描 ──"

for task_file in "$TASK_DIR"/task-*.md; do
    [[ -f "$task_file" ]] || continue
    ((TASK_COUNT++))

    task_id=$(basename "$task_file" .md | sed 's/task-/TASK-/' | tr '[:lower:]' '[:upper:]')
    # 简化 task_id: task-001 -> TASK-001
    task_id_short=$(basename "$task_file" .md)

    # 提取修改文件列表
    # 匹配格式: - [ ] `path/to/file` 或 - `path/to/file` 或 `path/to/file.ts`
    files=$(grep -oE '`[a-zA-Z0-9_./-]+\.[a-zA-Z]+`' "$task_file" 2>/dev/null | tr -d '`' | grep -E '\.(ts|tsx|js|jsx|py|go|java|rs|rb|vue|svelte|css|scss|html|sql|md)$' | sort -u || true)

    TASK_FILES["$task_id_short"]="$files"

    # 提取 depends_on
    deps=$(grep -iE '(depends_on|依赖|前置任务|depends|blocked.by)' "$task_file" 2>/dev/null | grep -oE '(TASK-[0-9]+|task-[0-9]+)' | tr '[:upper:]' '[:lower:]' | sort -u || true)
    TASK_DEPS["$task_id_short"]="$deps"

    # 提取 AC
    acs=$(grep -oE 'AC-[0-9]+' "$task_file" 2>/dev/null | sort -u | tr '\n' ',' | sed 's/,$//' || true)
    TASK_AC["$task_id_short"]="$acs"

    file_count=$(echo "$files" | grep -c . 2>/dev/null || echo 0)
    dep_count=$(echo "$deps" | grep -c . 2>/dev/null || echo 0)

    info "${task_id_short}: ${file_count} 个文件, ${dep_count} 个依赖, AC=[${acs:-无}]"
done

if [[ "$TASK_COUNT" -eq 0 ]]; then
    fail "未找到任何 task 文件"
    exit 1
fi

echo ""
info "共 ${TASK_COUNT} 个任务"

# ─── 文件冲突检测 ───
echo ""
echo "── 文件冲突检测 ──"

declare -A FILE_OWNERS  # file -> task list

# 建立文件→任务映射
for task_id in "${!TASK_FILES[@]}"; do
    files="${TASK_FILES[$task_id]}"
    [[ -z "$files" ]] && continue
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        if [[ -n "${FILE_OWNERS[$f]:-}" ]]; then
            FILE_OWNERS["$f"]="${FILE_OWNERS[$f]} ${task_id}"
        else
            FILE_OWNERS["$f"]="$task_id"
        fi
    done <<< "$files"
done

# 检测冲突
CONFLICT_PAIRS=""
for f in "${!FILE_OWNERS[@]}"; do
    owners="${FILE_OWNERS[$f]}"
    owner_count=$(echo "$owners" | wc -w | tr -d ' ')
    if [[ "$owner_count" -gt 1 ]]; then
        ((CONFLICTS++))
        warn "文件冲突: ${f}"
        info "  修改方: ${owners}"
        CONFLICT_PAIRS="${CONFLICT_PAIRS}${owners} (${f})\n"
    fi
done

if [[ "$CONFLICTS" -eq 0 ]]; then
    pass "无文件冲突 — 所有任务可完全并行"
else
    fail "${CONFLICTS} 个文件冲突"
    echo ""
    info "冲突处理建议:"
    info "  同文件不同函数 → 可并行，批量审查重点检查合并"
    info "  同文件同函数   → 不可并行，按依赖序执行"
    info "  接口提供方 vs 消费方 → 提供方先行"
fi

# ─── 依赖图构建 ───
echo ""
echo "── 依赖关系 ──"

HAS_DEPS=false
for task_id in $(echo "${!TASK_DEPS[@]}" | tr ' ' '\n' | sort); do
    deps="${TASK_DEPS[$task_id]}"
    [[ -z "$deps" ]] && continue
    HAS_DEPS=true
    dep_list=$(echo "$deps" | tr '\n' ', ' | sed 's/,$//')
    info "${task_id} → 依赖: ${dep_list}"
done

if ! $HAS_DEPS; then
    info "无显式依赖声明"
    if [[ "$CONFLICTS" -gt 0 ]]; then
        warn "存在文件冲突但无依赖声明 — 建议在 task 文件中添加 depends_on"
    fi
fi

# ─── 拓扑排序 & 分批建议 ───
echo ""
echo "── 分批派发建议 ──"

# 简单拓扑排序: 无依赖的先行，有依赖的后行
declare -A BATCH_MAP  # task -> batch number

# 第一批: 无依赖 + 无文件冲突
batch=1
remaining_tasks=()

for task_id in $(echo "${!TASK_FILES[@]}" | tr ' ' '\n' | sort); do
    deps="${TASK_DEPS[$task_id]:-}"
    if [[ -z "$deps" ]]; then
        # 检查是否与已分配到 Batch 1 的 task 有文件冲突
        has_conflict=false
        for assigned in "${!BATCH_MAP[@]}"; do
            [[ "${BATCH_MAP[$assigned]}" != "1" ]] && continue
            # 检查两个 task 是否共享文件
            files_a="${TASK_FILES[$task_id]:-}"
            files_b="${TASK_FILES[$assigned]:-}"
            if [[ -n "$files_a" && -n "$files_b" ]]; then
                overlap=$(comm -12 <(echo "$files_a" | sort) <(echo "$files_b" | sort) 2>/dev/null | head -1)
                if [[ -n "$overlap" ]]; then
                    has_conflict=true
                    break
                fi
            fi
        done

        if $has_conflict; then
            remaining_tasks+=("$task_id")
        else
            BATCH_MAP["$task_id"]=1
        fi
    else
        remaining_tasks+=("$task_id")
    fi
done

# 分配剩余任务到后续批次
batch=2
for task_id in "${remaining_tasks[@]}"; do
    BATCH_MAP["$task_id"]=$batch
    # 简化: 有依赖或有冲突的逐个递增批次
    # 实际可优化为更精确的拓扑排序
    ((batch++))
done

# 输出分批结果
echo ""
max_batch=0
for task_id in "${!BATCH_MAP[@]}"; do
    b="${BATCH_MAP[$task_id]}"
    [[ "$b" -gt "$max_batch" ]] && max_batch=$b
done

for ((b=1; b<=max_batch; b++)); do
    batch_tasks=""
    for task_id in $(echo "${!BATCH_MAP[@]}" | tr ' ' '\n' | sort); do
        if [[ "${BATCH_MAP[$task_id]}" == "$b" ]]; then
            acs="${TASK_AC[$task_id]:-无}"
            batch_tasks="${batch_tasks}    ${task_id} [${acs}]\n"
        fi
    done
    if [[ -n "$batch_tasks" ]]; then
        if [[ "$b" -eq 1 ]]; then
            echo -e "  ${GREEN}Batch ${b}（并行）:${NC}"
        else
            echo -e "  ${YELLOW}Batch ${b}（等待 Batch $((b-1)) 完成）:${NC}"
        fi
        echo -e "$batch_tasks"
    fi
done

# ─── 总结 ───
echo "═══ 分析结果 ═══"
echo ""
echo "  任务总数: ${TASK_COUNT}"
echo "  文件冲突: ${CONFLICTS}"
echo "  批次数量: ${max_batch}"
echo ""

if [[ "$CONFLICTS" -eq 0 ]]; then
    echo -e "${GREEN}PASS${NC} — 所有任务可并行派发"
    exit 0
else
    echo -e "${YELLOW}WARN${NC} — 存在文件冲突，建议按分批顺序派发"
    echo ""
    echo "  下一步:"
    echo "    1. 检查冲突文件，确认是否为同函数修改"
    echo "    2. 同函数冲突 → 在 task 文件中添加 depends_on"
    echo "    3. 重新运行本脚本确认依赖关系"
    echo "    4. 按 Batch 顺序派发 TaskExecutor"
    exit 1
fi
