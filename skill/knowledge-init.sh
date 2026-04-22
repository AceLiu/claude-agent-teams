#!/usr/bin/env bash
# knowledge-init.sh — 自动扫描项目生成初版知识库
# 用法: bash knowledge-init.sh <project_root> [--full]
# 模式: 快速模式(默认,30s) / 完整模式(--full,2-5min)

set -euo pipefail

PROJECT_ROOT="${1:?用法: knowledge-init.sh <project_root> [--full|--from-history]}"
PROJECT_NAME=$(basename "$PROJECT_ROOT")
KB_DIR="$HOME/.claude/agent-kb/${PROJECT_NAME}"
FULL_MODE=false
FROM_HISTORY=false
[[ "${2:-}" == "--full" ]] && FULL_MODE=true
[[ "${2:-}" == "--from-history" ]] && FROM_HISTORY=true

# 颜色
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'

info() { echo -e "  ${CYAN}ℹ${NC} $1"; }
pass() { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }

echo ""
echo "═══ 知识库初始化 ═══"
echo ""
info "项目: ${PROJECT_NAME}"
info "路径: ${PROJECT_ROOT}"
info "模式: $(if $FULL_MODE; then echo '完整'; else echo '快速'; fi)"
echo ""

# 创建目录结构
mkdir -p "$KB_DIR/insights/platform"
mkdir -p "$KB_DIR/insights/business"
TODAY=$(date +%Y-%m-%d)

# ─── 1. 技术栈检测 ───
echo "── 技术栈检测 ──"

TECH_STACK=""
PACKAGE_MANAGER=""
BUILD_CMD=""
TEST_CMD=""
FRAMEWORK=""

# Node.js 生态
if [[ -f "$PROJECT_ROOT/package.json" ]]; then
    TECH_STACK="${TECH_STACK}Node.js, "
    # 检测包管理器
    if [[ -f "$PROJECT_ROOT/pnpm-lock.yaml" ]]; then
        PACKAGE_MANAGER="pnpm"
    elif [[ -f "$PROJECT_ROOT/yarn.lock" ]]; then
        PACKAGE_MANAGER="yarn"
    elif [[ -f "$PROJECT_ROOT/bun.lockb" ]]; then
        PACKAGE_MANAGER="bun"
    else
        PACKAGE_MANAGER="npm"
    fi

    # 检测框架
    if grep -q '"next"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
        FRAMEWORK="${FRAMEWORK}Next.js, "
    fi
    if grep -q '"react"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
        FRAMEWORK="${FRAMEWORK}React, "
    fi
    if grep -q '"vue"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
        FRAMEWORK="${FRAMEWORK}Vue, "
    fi
    if grep -q '"express"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
        FRAMEWORK="${FRAMEWORK}Express, "
    fi
    if grep -q '"fastify"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
        FRAMEWORK="${FRAMEWORK}Fastify, "
    fi
    if grep -q '"hono"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
        FRAMEWORK="${FRAMEWORK}Hono, "
    fi

    # TypeScript
    if [[ -f "$PROJECT_ROOT/tsconfig.json" ]]; then
        TECH_STACK="${TECH_STACK}TypeScript, "
    fi

    # 检测构建和测试命令
    BUILD_CMD=$(node -e "try{const p=require('$PROJECT_ROOT/package.json');console.log(p.scripts?.build||'')}catch{}" 2>/dev/null || true)
    TEST_CMD=$(node -e "try{const p=require('$PROJECT_ROOT/package.json');console.log(p.scripts?.test||'')}catch{}" 2>/dev/null || true)
fi

# Python 生态
if [[ -f "$PROJECT_ROOT/requirements.txt" || -f "$PROJECT_ROOT/pyproject.toml" || -f "$PROJECT_ROOT/setup.py" ]]; then
    TECH_STACK="${TECH_STACK}Python, "
    if [[ -f "$PROJECT_ROOT/pyproject.toml" ]]; then
        PACKAGE_MANAGER="${PACKAGE_MANAGER:+${PACKAGE_MANAGER}, }uv/pip"
    fi
    if grep -qr "django" "$PROJECT_ROOT/requirements.txt" 2>/dev/null || grep -q "django" "$PROJECT_ROOT/pyproject.toml" 2>/dev/null; then
        FRAMEWORK="${FRAMEWORK}Django, "
    fi
    if grep -qr "fastapi" "$PROJECT_ROOT/requirements.txt" 2>/dev/null || grep -q "fastapi" "$PROJECT_ROOT/pyproject.toml" 2>/dev/null; then
        FRAMEWORK="${FRAMEWORK}FastAPI, "
    fi
    if grep -qr "flask" "$PROJECT_ROOT/requirements.txt" 2>/dev/null; then
        FRAMEWORK="${FRAMEWORK}Flask, "
    fi
fi

# Go 生态
if [[ -f "$PROJECT_ROOT/go.mod" ]]; then
    TECH_STACK="${TECH_STACK}Go, "
    PACKAGE_MANAGER="${PACKAGE_MANAGER:+${PACKAGE_MANAGER}, }go mod"
fi

# 数据库检测
DB_TYPE=""
if grep -rq "postgres\|postgresql\|pg" "$PROJECT_ROOT/package.json" "$PROJECT_ROOT/requirements.txt" "$PROJECT_ROOT/go.mod" 2>/dev/null; then
    DB_TYPE="${DB_TYPE}PostgreSQL, "
fi
if grep -rq "mysql\|mariadb" "$PROJECT_ROOT/package.json" "$PROJECT_ROOT/requirements.txt" 2>/dev/null; then
    DB_TYPE="${DB_TYPE}MySQL, "
fi
if grep -rq "mongodb\|mongoose" "$PROJECT_ROOT/package.json" "$PROJECT_ROOT/requirements.txt" 2>/dev/null; then
    DB_TYPE="${DB_TYPE}MongoDB, "
fi
if grep -rq "redis" "$PROJECT_ROOT/package.json" "$PROJECT_ROOT/requirements.txt" 2>/dev/null; then
    DB_TYPE="${DB_TYPE}Redis, "
fi
if grep -rq "sqlite" "$PROJECT_ROOT/package.json" "$PROJECT_ROOT/requirements.txt" 2>/dev/null; then
    DB_TYPE="${DB_TYPE}SQLite, "
fi

# 清理尾部逗号
TECH_STACK=$(echo "$TECH_STACK" | sed 's/, $//')
FRAMEWORK=$(echo "$FRAMEWORK" | sed 's/, $//')
DB_TYPE=$(echo "$DB_TYPE" | sed 's/, $//')

pass "技术栈: ${TECH_STACK:-未识别}"
pass "框架: ${FRAMEWORK:-未识别}"
pass "包管理器: ${PACKAGE_MANAGER:-未识别}"
pass "数据库: ${DB_TYPE:-未检测到}"

# ─── 2. 模块扫描 ───
echo ""
echo "── 模块扫描 ──"

MODULES=""
# 扫描 src/ 下的一级目录
if [[ -d "$PROJECT_ROOT/src" ]]; then
    while IFS= read -r dir; do
        mod_name=$(basename "$dir")
        file_count=$(find "$dir" -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.py' -o -name '*.go' \) 2>/dev/null | wc -l | tr -d ' ')
        MODULES="${MODULES}\n| ${mod_name} | ${file_count} 文件 | <!-- 一句话职责 --> |"
        info "${mod_name}/ — ${file_count} 个源文件"
    done < <(find "$PROJECT_ROOT/src" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)
fi

# 也扫描 app/ pages/ routes/ 等
for scan_dir in app pages routes controllers handlers api server lib; do
    target="$PROJECT_ROOT/$scan_dir"
    if [[ -d "$target" && "$scan_dir" != "src" ]]; then
        file_count=$(find "$target" -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.py' -o -name '*.go' \) 2>/dev/null | wc -l | tr -d ' ')
        MODULES="${MODULES}\n| ${scan_dir} | ${file_count} 文件 | <!-- 一句话职责 --> |"
        info "${scan_dir}/ — ${file_count} 个源文件"
    fi
done

# ─── 3. 入口文件检测 ───
echo ""
echo "── 入口文件检测 ──"

ENTRY_FILES=""
for entry in "src/index.ts" "src/main.ts" "src/app.ts" "src/server.ts" "pages/_app.tsx" "app/layout.tsx" "src/index.js" "src/main.js" "main.go" "cmd/main.go" "app.py" "main.py" "manage.py"; do
    if [[ -f "$PROJECT_ROOT/$entry" ]]; then
        ENTRY_FILES="${ENTRY_FILES}- \`${entry}\`\n"
        pass "入口: ${entry}"
    fi
done

# ─── 4. 生成 overview.md ───
cat > "$KB_DIR/overview.md" << OVERVIEW_EOF
---
updated: ${TODAY}
source: knowledge-init.sh ($(if $FULL_MODE; then echo '完整模式'; else echo '快速模式'; fi))
---

# 项目概览: ${PROJECT_NAME}

## 技术栈
- **语言**: ${TECH_STACK:-未识别}
- **框架**: ${FRAMEWORK:-未识别}
- **包管理器**: ${PACKAGE_MANAGER:-未识别}
- **数据库**: ${DB_TYPE:-未检测到}
- **构建命令**: \`${BUILD_CMD:-未检测}\`
- **测试命令**: \`${TEST_CMD:-未检测}\`

## 核心模块

| 模块 | 规模 | 职责 |
|------|------|------|$(echo -e "$MODULES")

## 入口文件
$(echo -e "${ENTRY_FILES:-未检测到入口文件}")

## 部署方式
<!-- 手动补充: 本地开发 / 测试 / 生产 -->
OVERVIEW_EOF

pass "已生成 overview.md"

# ─── 5. 生成 conventions.md ───
echo ""
echo "── 编码规范检测 ──"

LINT_TOOL=""
FORMAT_TOOL=""
if [[ -f "$PROJECT_ROOT/.eslintrc.js" || -f "$PROJECT_ROOT/.eslintrc.json" || -f "$PROJECT_ROOT/.eslintrc.cjs" || -f "$PROJECT_ROOT/eslint.config.js" || -f "$PROJECT_ROOT/eslint.config.mjs" ]]; then
    LINT_TOOL="ESLint"
fi
if [[ -f "$PROJECT_ROOT/.prettierrc" || -f "$PROJECT_ROOT/.prettierrc.json" || -f "$PROJECT_ROOT/.prettierrc.js" ]]; then
    FORMAT_TOOL="Prettier"
fi
if [[ -f "$PROJECT_ROOT/biome.json" ]]; then
    LINT_TOOL="${LINT_TOOL:+${LINT_TOOL}, }Biome"
    FORMAT_TOOL="${FORMAT_TOOL:+${FORMAT_TOOL}, }Biome"
fi

info "Lint: ${LINT_TOOL:-未检测}"
info "Format: ${FORMAT_TOOL:-未检测}"

cat > "$KB_DIR/conventions.md" << CONV_EOF
---
updated: ${TODAY}
---

# 编码规范

## 工具链
- **Lint**: ${LINT_TOOL:-未配置}
- **Format**: ${FORMAT_TOOL:-未配置}

## 命名约定
<!-- Agent 首次编码时自动补充 -->

## 目录结构约定
<!-- Agent 首次分析时自动补充 -->

## Git 工作流
<!-- 分支策略、commit 规范等 -->
CONV_EOF

pass "已生成 conventions.md"

# ─── 6. 生成 pitfalls.md (空模板) ───
if [[ ! -f "$KB_DIR/pitfalls.md" ]]; then
    cat > "$KB_DIR/pitfalls.md" << PIT_EOF
---
updated: ${TODAY}
---

# 踩坑记录

<!-- 格式：
## PIT-001: 简短标题
- **原因**: 为什么会出问题
- **正确做法**: 应该怎么做
- **来源**: 时间 + 事件
- **关键词**: [关键词1, 关键词2]
- **置信度**: 0.5 (初始)
-->
PIT_EOF
    pass "已生成 pitfalls.md"
fi

# ─── 7. 生成 glossary.md (空模板) ───
if [[ ! -f "$KB_DIR/glossary.md" ]]; then
    cat > "$KB_DIR/glossary.md" << GLOSS_EOF
---
updated: ${TODAY}
---

# 术语表

| 术语 | 含义 | 上下文 |
|------|------|--------|
<!-- Agent 在 Phase 1 分析需求时自动补充领域术语 -->
GLOSS_EOF
    pass "已生成 glossary.md"
fi

# ─── 8. 完整模式: 生成 call-chains.md 和 dependencies.md ───
if $FULL_MODE; then
    echo ""
    echo "── 完整模式: 调用链分析 ──"

    # 扫描 import/require 关系
    cat > "$KB_DIR/call-chains.md" << CHAIN_EOF
---
updated: ${TODAY}
source: knowledge-init.sh --full
---

# 核心调用链

<!-- 完整模式自动扫描 import/require 生成初版 -->
<!-- Agent 在 Phase 2 设计时补充关键业务流程的调用链 -->

## API 入口 → 处理链
<!-- 格式: Controller → Service → Repository → DB -->

## 事件/消息流
<!-- 格式: Publisher → Queue → Consumer → Handler -->
CHAIN_EOF
    pass "已生成 call-chains.md"

    cat > "$KB_DIR/dependencies.md" << DEPS_EOF
---
updated: ${TODAY}
source: knowledge-init.sh --full
---

# 外部依赖

## 第三方服务
<!-- API 名称 | 用途 | 文档链接 -->

## 关键依赖包
<!-- 包名 | 版本 | 用途 | 升级风险 -->
DEPS_EOF
    pass "已生成 dependencies.md"
fi

# ─── 9. 生成元数据 ───
cat > "$KB_DIR/.meta.json" << META_EOF
{
  "project": "${PROJECT_NAME}",
  "created": "${TODAY}",
  "updated": "${TODAY}",
  "mode": "$(if $FULL_MODE; then echo 'full'; else echo 'quick'; fi)",
  "version": "1.0.0",
  "files": {
    "overview": true,
    "conventions": true,
    "pitfalls": true,
    "glossary": true,
    "call-chains": $($FULL_MODE && echo 'true' || echo 'false'),
    "dependencies": $($FULL_MODE && echo 'true' || echo 'false')
  }
}
META_EOF

# ─── 10. 历史产出提炼模式 ───
if $FROM_HISTORY; then
    echo ""
    echo "── 历史产出提炼 ──"

    TEAM_DIR="$PROJECT_ROOT/.team"
    if [[ ! -d "$TEAM_DIR" ]]; then
        warn "未找到 .team/ 目录，跳过历史提炼"
    else
        # 收集历史产出文件
        HISTORY_FILES=""
        for artifact in spec.md design.md; do
            if [[ -f "$TEAM_DIR/$artifact" ]]; then
                HISTORY_FILES="${HISTORY_FILES}${TEAM_DIR}/${artifact}\n"
                pass "发现: .team/${artifact}"
            fi
        done

        # 扫描 reviews 目录
        if [[ -d "$TEAM_DIR/reviews" ]]; then
            review_count=$(find "$TEAM_DIR/reviews" -name '*.md' | wc -l | tr -d ' ')
            if [[ "$review_count" -gt 0 ]]; then
                pass "发现: .team/reviews/ (${review_count} 个文件)"
                while IFS= read -r f; do
                    HISTORY_FILES="${HISTORY_FILES}${f}\n"
                done < <(find "$TEAM_DIR/reviews" -name '*.md' -type f)
            fi
        fi

        # 扫描 test-reports 目录
        if [[ -d "$TEAM_DIR/test-reports" ]]; then
            report_count=$(find "$TEAM_DIR/test-reports" -name '*.md' | wc -l | tr -d ' ')
            if [[ "$report_count" -gt 0 ]]; then
                pass "发现: .team/test-reports/ (${report_count} 个文件)"
            fi
        fi

        # 扫描 tasks 目录
        if [[ -d "$TEAM_DIR/tasks" ]]; then
            task_count=$(find "$TEAM_DIR/tasks" -name 'task-*.md' | wc -l | tr -d ' ')
            if [[ "$task_count" -gt 0 ]]; then
                pass "发现: .team/tasks/ (${task_count} 个任务文件)"
            fi
        fi

        # 检查是否有已有的 learn-summary
        if [[ -f "$TEAM_DIR/learn-summary.md" ]]; then
            warn "已存在 learn-summary.md，历史产出可能已提炼过"
        fi

        if [[ -z "$HISTORY_FILES" ]]; then
            warn "未找到可提炼的历史产出文件"
        else
            echo ""
            info "历史产出文件已收集完毕。"
            info "请在 Claude Code 中执行以下操作完成提炼："
            echo ""
            echo "  1. 读取上述产出文件"
            echo "  2. 按 phase-5-learn.md 的 Step 2 (8 维度) 分析"
            echo "  3. 生成建议清单 → 用户审核 → 写入知识库"
            echo ""
            info "提示: 在 Claude Code 中说 '/learn' 或 '从历史产出提炼知识' 即可触发"

            # 生成历史文件清单供 Agent 读取
            echo -e "$HISTORY_FILES" > "$KB_DIR/.history-artifacts.txt"
            pass "已生成 .history-artifacts.txt（Agent 读取用）"
        fi
    fi
fi

# ─── 总结 ───
echo ""
echo "═══ 初始化完成 ═══"
echo ""
file_count=$(find "$KB_DIR" -name '*.md' | wc -l | tr -d ' ')
pass "知识库路径: ${KB_DIR}"
pass "已生成 ${file_count} 个文件"
echo ""
if ! $FULL_MODE && ! $FROM_HISTORY; then
    info "提示: 使用 --full 模式可生成更详细的 call-chains.md 和 dependencies.md"
    info "提示: 使用 --from-history 模式可从已有 .team/ 产出中批量提炼知识"
fi
info "下一步: Agent 在 Phase 1-2 中会自动读取并补充知识库内容"
