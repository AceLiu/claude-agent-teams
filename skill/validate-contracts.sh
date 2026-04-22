#!/usr/bin/env bash
# 契约校验工具 - 自动检查源代码是否符合 contracts.md
# 用法: validate-contracts.sh <project-root> [--strict]
set -euo pipefail

PROJECT_ROOT="${1:?用法: validate-contracts.sh <project-root> [--strict]}"
STRICT=false
GRADE="M"
for arg in "$@"; do
  [[ "$arg" == "--strict" ]] && STRICT=true
  [[ "$arg" =~ ^--grade=(.+)$ ]] && GRADE="${BASH_REMATCH[1]}"
done

CONTRACTS_FILE="${PROJECT_ROOT}/.team/contracts.md"
REPORT_FILE="${PROJECT_ROOT}/.team/reviews/contract-validation.md"

# 源码搜索目录（排除常见非源码目录）
SRC_DIRS=("src" "app" "pages" "routes" "controllers" "handlers" "api" "server" "lib")
EXCLUDE_DIRS="node_modules|.git|dist|build|.next|__pycache__|.team|vendor|target"

if [ ! -f "$CONTRACTS_FILE" ]; then
  echo "[ERROR] contracts.md 不存在: $CONTRACTS_FILE" >&2
  exit 1
fi

# S/S+ 级跳过契约校验
if [[ "$GRADE" == "S" || "$GRADE" == "S+" ]]; then
    echo "[validate-contracts] S/S+ 级跳过契约校验"
    exit 0
fi

mkdir -p "$(dirname "$REPORT_FILE")"

# ─── 初始化计数器 ───
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
PASS=0
FAIL=0
WARN=0
DETAILS=""

# ─── 辅助函数 ───

# 在项目源码中搜索关键词，返回匹配文件列表
search_source() {
  local pattern="$1"
  local found_files=""
  for dir in "${SRC_DIRS[@]}"; do
    local full_dir="${PROJECT_ROOT}/${dir}"
    [ -d "$full_dir" ] || continue
    local matches
    matches=$(grep -rl --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
      --include='*.py' --include='*.go' --include='*.java' --include='*.rs' --include='*.rb' \
      --include='*.php' --include='*.vue' --include='*.svelte' \
      -E "$pattern" "$full_dir" 2>/dev/null | grep -vE "$EXCLUDE_DIRS" || true)
    if [ -n "$matches" ]; then
      found_files="${found_files}${matches}"$'\n'
    fi
  done
  echo "$found_files" | sed '/^$/d' | sort -u
}

# 在特定文件周围搜索关键词（±50行上下文）
search_near_route() {
  local file="$1"
  local route_pattern="$2"
  local keyword="$3"
  # 找到 route 定义行号
  local line_nums
  line_nums=$(grep -nE "$route_pattern" "$file" 2>/dev/null | head -5 | cut -d: -f1 || true)
  [ -z "$line_nums" ] && return 1
  # 在 route 附近搜索 keyword
  for line_num in $line_nums; do
    local start=$((line_num > 50 ? line_num - 50 : 1))
    local end=$((line_num + 100))
    if sed -n "${start},${end}p" "$file" 2>/dev/null | grep -qE "$keyword"; then
      return 0
    fi
  done
  return 1
}

# ─── 解析 contracts.md ───

# 提取 API 定义块
# 格式假设:
#   ### API-001: 描述
#   **路径**: `POST /api/v1/xxx`  或  - **路径**: POST /api/v1/xxx
#   **请求体** / **Request Body**:
#   - `field` (required): type
#   **错误码** / **Error Codes**:
#   - `4xx` — description

current_api=""
current_method=""
current_path=""
current_required_fields=()
current_error_codes=()
api_count=0

flush_api() {
  [ -z "$current_api" ] && return

  api_count=$((api_count + 1))
  local api_pass=true
  local api_detail=""
  local route_files=""

  # 构建路由搜索模式：将路径参数 :id / {id} 转为通配
  local path_pattern
  path_pattern=$(echo "$current_path" | sed 's/:[a-zA-Z_]*/.*/g; s/{[a-zA-Z_]*}/.*/g')
  # 同时搜索原始路径字符串
  local path_literal
  path_literal=$(echo "$current_path" | sed 's/[.[\*^$()+?{}|\\]/\\&/g')

  # 1. 搜索路由定义
  route_files=$(search_source "(${path_pattern}|${path_literal})" || true)

  if [ -z "$route_files" ]; then
    # 尝试只用路径末段搜索
    local tail_segment
    tail_segment=$(echo "$current_path" | awk -F/ '{print $NF}' | sed 's/:[a-zA-Z_]*/[^/]*/g; s/{[a-zA-Z_]*}/[^/]*/g')
    if [ -n "$tail_segment" ] && [ "$tail_segment" != "*" ]; then
      route_files=$(search_source "$tail_segment" || true)
    fi
  fi

  if [ -z "$route_files" ]; then
    api_detail+=$'\n'"  - **路由定义**: FAIL - 未找到匹配 \`${current_method} ${current_path}\` 的路由"
    api_detail+=$'\n'"  - ⚡ **修复建议**: 在源码中创建 \`${current_method} ${current_path}\` 路由处理函数"
    api_pass=false
  else
    local file_list
    file_list=$(echo "$route_files" | sed "s|${PROJECT_ROOT}/||g" | head -5 | tr '\n' ', ' | sed 's/,$//')
    api_detail+=$'\n'"  - **路由定义**: PASS - 找到于 \`${file_list}\`"
  fi

  # 2. 检查 required 字段
  if [ ${#current_required_fields[@]} -gt 0 ]; then
    local missing_fields=()
    local found_fields=()
    for field in "${current_required_fields[@]}"; do
      local field_found=false
      # 先在路由文件中搜索
      if [ -n "$route_files" ]; then
        while IFS= read -r rf; do
          [ -z "$rf" ] && continue
          if grep -qE "(${field}|$(echo "$field" | sed 's/_/[_-]/g'))" "$rf" 2>/dev/null; then
            field_found=true
            break
          fi
        done <<< "$route_files"
      fi
      # 全局搜索兜底
      if ! $field_found; then
        local global_match
        global_match=$(search_source "\\b${field}\\b" || true)
        [ -n "$global_match" ] && field_found=true
      fi
      if $field_found; then
        found_fields+=("$field")
      else
        missing_fields+=("$field")
      fi
    done

    if [ ${#missing_fields[@]} -eq 0 ]; then
      api_detail+=$'\n'"  - **必填字段** (${#current_required_fields[@]}): PASS"
    else
      local missing_str
      missing_str=$(IFS=', '; echo "${missing_fields[*]}")
      if $STRICT; then
        api_detail+=$'\n'"  - **必填字段**: FAIL - 未找到: \`${missing_str}\`"
        api_detail+=$'\n'"  - ⚡ **修复建议**: 在路由处理中添加 \`${missing_str}\` 字段的解析和校验"
        api_pass=false
      else
        api_detail+=$'\n'"  - **必填字段**: WARN - 未找到: \`${missing_str}\`（可能为动态引用或序列化名不同）"
        api_detail+=$'\n'"  - ⚡ **修复建议**: 在路由处理中添加 \`${missing_str}\` 字段的解析和校验"
        WARN=$((WARN + 1))
      fi
    fi
  fi

  # 3. 检查错误码
  if [ ${#current_error_codes[@]} -gt 0 ]; then
    local missing_codes=()
    local found_codes=()
    for code in "${current_error_codes[@]}"; do
      local code_found=false
      if [ -n "$route_files" ]; then
        while IFS= read -r rf; do
          [ -z "$rf" ] && continue
          if grep -qE "(${code}|HttpStatus|status.*${code}|StatusCode)" "$rf" 2>/dev/null; then
            code_found=true
            break
          fi
        done <<< "$route_files"
      fi
      if ! $code_found; then
        local global_match
        global_match=$(search_source "\\b${code}\\b" || true)
        [ -n "$global_match" ] && code_found=true
      fi
      if $code_found; then
        found_codes+=("$code")
      else
        missing_codes+=("$code")
      fi
    done

    if [ ${#missing_codes[@]} -eq 0 ]; then
      api_detail+=$'\n'"  - **错误码** (${#current_error_codes[@]}): PASS"
    else
      local missing_str
      missing_str=$(IFS=', '; echo "${missing_codes[*]}")
      if $STRICT; then
        api_detail+=$'\n'"  - **错误码**: FAIL - 未找到: \`${missing_str}\`"
        api_pass=false
      else
        api_detail+=$'\n'"  - **错误码**: WARN - 未找到: \`${missing_str}\`（可能使用统一错误处理中间件）"
        WARN=$((WARN + 1))
      fi
    fi
  fi

  # 汇总
  local status_icon
  if $api_pass; then
    PASS=$((PASS + 1))
    status_icon="PASS"
  else
    FAIL=$((FAIL + 1))
    status_icon="FAIL"
  fi

  DETAILS+=$'\n'"### ${current_api} — \`${current_method} ${current_path}\` [${status_icon}]"
  DETAILS+="${api_detail}"
  DETAILS+=$'\n'

  # 重置
  current_api=""
  current_method=""
  current_path=""
  current_required_fields=()
  current_error_codes=()
}

# 状态机解析
in_fields_section=false
in_errors_section=false

while IFS= read -r line; do
  # 检测 API 标题行: ### API-NNN 或 ## API-NNN
  if echo "$line" | grep -qE '^#{2,4}\s+API-[0-9]+'; then
    flush_api
    current_api=$(echo "$line" | sed 's/^#*\s*//')
    in_fields_section=false
    in_errors_section=false
    continue
  fi

  # 如果还没进入 API 块，跳过
  [ -z "$current_api" ] && continue

  # 检测路径行
  if echo "$line" | grep -qiE '(路径|path|endpoint).*[`:]'; then
    extracted=$(echo "$line" | grep -oE '(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\s+/[^ `"'"'"']*' | head -1)
    if [ -n "$extracted" ]; then
      current_method=$(echo "$extracted" | awk '{print $1}')
      current_path=$(echo "$extracted" | awk '{print $2}')
    fi
    in_fields_section=false
    in_errors_section=false
    continue
  fi

  # 检测请求体/字段段落开始
  if echo "$line" | grep -qiE '(请求体|request.?body|请求参数|required.?fields|字段|parameters)'; then
    in_fields_section=true
    in_errors_section=false
    continue
  fi

  # 检测错误码段落开始
  if echo "$line" | grep -qiE '(错误码|error.?code|status.?code|错误响应|error.?response)'; then
    in_fields_section=false
    in_errors_section=true
    continue
  fi

  # 检测新段落开始（非列表项），重置 section
  if echo "$line" | grep -qE '^#{2,4}\s+[^A]|^\*\*[^-]'; then
    if ! echo "$line" | grep -qiE '(路径|path|请求|响应|错误|field|param)'; then
      in_fields_section=false
      in_errors_section=false
    fi
  fi

  # 解析 required 字段: - `fieldName` (required)
  if $in_fields_section; then
    if echo "$line" | grep -qiE '\(required\)|（必填）|必选|\*\*$'; then
      field_name=$(echo "$line" | grep -oE '`[a-zA-Z_][a-zA-Z0-9_]*`' | head -1 | tr -d '`')
      if [ -n "$field_name" ]; then
        current_required_fields+=("$field_name")
      fi
    fi
  fi

  # 解析错误码: - `4xx` 或 - 4xx
  if $in_errors_section; then
    error_code=$(echo "$line" | grep -oE '\b[1-5][0-9]{2}\b' | head -1)
    if [ -n "$error_code" ]; then
      current_error_codes+=("$error_code")
    fi
  fi

done < "$CONTRACTS_FILE"

# 别忘了最后一个 API
flush_api

# ─── 生成报告 ───

TOTAL=$((PASS + FAIL))
OVERALL="PASS"
EXIT_CODE=0
if [ "$FAIL" -gt 0 ]; then
  OVERALL="FAIL"
  EXIT_CODE=1
fi

cat > "$REPORT_FILE" << EOF
# 契约校验报告

> 生成时间: ${TIMESTAMP}
> 项目路径: \`${PROJECT_ROOT}\`
> 模式: $(if $STRICT; then echo "strict"; else echo "normal"; fi)

## 摘要

| 指标 | 值 |
|------|-----|
| API 总数 | ${TOTAL} |
| 通过 | ${PASS} |
| 失败 | ${FAIL} |
| 警告 | ${WARN} |
| **总体结果** | **${OVERALL}** |

## 详细结果
${DETAILS}
## 说明

- **PASS**: 路由、必填字段、错误码均在源码中找到匹配
- **FAIL**: 关键定义（路由路径）在源码中未找到
- **WARN**: 字段或错误码未直接匹配，可能使用了动态引用或统一中间件处理
- strict 模式下 WARN 会升级为 FAIL

> 本报告基于 grep 启发式匹配，存在误报可能。建议由 Architect 人工审查补充。
EOF

echo "[validate-contracts] 报告已生成: ${REPORT_FILE}"
echo "[validate-contracts] 结果: ${TOTAL} APIs — ${PASS} pass, ${FAIL} fail, ${WARN} warn → ${OVERALL}"
exit $EXIT_CODE
