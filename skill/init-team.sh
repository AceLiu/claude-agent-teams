#!/usr/bin/env bash
# 初始化项目的 .team/ 协作目录
# 用法: init-team.sh [project-root] [--collab]
set -euo pipefail

PROJECT_ROOT="${1:-.}"
COLLAB_MODE=false
GRADE=""
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

for arg in "$@"; do
  [ "$arg" = "--collab" ] && COLLAB_MODE=true
  [[ "$arg" =~ ^--grade=(.+)$ ]] && GRADE="${BASH_REMATCH[1]}"
done

TEAM_DIR="$PROJECT_ROOT/.team"

# --- S 级快速通道：只创建 tasks/ 和 reviews/，跳过所有重量级初始化 ---
if [ "$GRADE" = "S" ]; then
  mkdir -p "$TEAM_DIR/tasks"
  mkdir -p "$TEAM_DIR/reviews"
  echo "S" > "$TEAM_DIR/.grade"
  echo "✅ .team/ S 级快速初始化完成（仅 tasks/ + reviews/）"
  exit 0
fi

# --- S+ 级 Autopilot：同 S 级 ---
if [ "$GRADE" = "S+" ]; then
  mkdir -p "$TEAM_DIR/tasks"
  mkdir -p "$TEAM_DIR/reviews"
  echo "S+" > "$TEAM_DIR/.grade"
  # 生成 task 模板
  cat > "$TEAM_DIR/tasks/task-001.md" << 'TPLEOF'
# TASK-001: [标题]

## 需求
<!-- 1-2 句话描述要做什么 -->

## 验收标准
- [ ] AC-001: [具体可验证的条件]

## 变更范围
- [ ] `path/to/file.ts` — [修改内容]

## 备注
<!-- 可选 -->
TPLEOF
  echo "✅ .team/ S+ 级初始化完成（含 task 模板）"
  exit 0
fi

if [ -d "$TEAM_DIR" ]; then
  echo "⚠️  .team/ 目录已存在于 $PROJECT_ROOT"
  echo "跳过基础初始化，保留现有数据。"
else
  mkdir -p "$TEAM_DIR/tasks"
  mkdir -p "$TEAM_DIR/designs/ref-impl"
  mkdir -p "$TEAM_DIR/reviews"
  mkdir -p "$TEAM_DIR/test-reports"

  cat > "$TEAM_DIR/board.md" << 'EOF'
# Team Board

<!-- Agent 间的讨论、决策、@通知 -->
<!-- 格式: ## [时间戳] @发送者 → @接收者 -->
EOF

  cat > "$TEAM_DIR/status.md" << 'EOF'
# Team Status

| 角色 | 状态 | 当前任务 |
|------|------|----------|
| Team Leader | active | 初始化团队 |
| Product Manager | pending | - |
| Architect | pending | - |
| Tester | pending | - |
| Designer | - | 未加载 |
| Frontend Dev (Web) | - | 未加载 |
| iOS Dev | - | 未加载 |
| Android Dev | - | 未加载 |
| Backend Dev | - | 未加载 |
| AI Assistant | - | 未加载 |
| Documentation Writer | - | 未加载 |
EOF

  cat > "$TEAM_DIR/metrics.json" << 'METRICS_EOF'
{
  "project": "",
  "requirement": "",
  "level": "",
  "date": "",
  "phases": {
    "phase1_requirements": { "duration_min": 0, "rework_count": 0, "start_ts": 0, "end_ts": 0 },
    "phase2_design":        { "duration_min": 0, "rework_count": 0, "start_ts": 0, "end_ts": 0 },
    "phase3_tasking":       { "duration_min": 0, "rework_count": 0, "start_ts": 0, "end_ts": 0 },
    "phase4_development":   { "duration_min": 0, "rework_count": 0, "start_ts": 0, "end_ts": 0 },
    "phase5_verification":  { "duration_min": 0, "rework_count": 0, "start_ts": 0, "end_ts": 0 }
  },
  "bugs": { "P0": 0, "P1": 0, "P2": 0 },
  "coverage": {
    "acceptance_criteria_total": 0,
    "test_skeleton_covered": 0,
    "coverage_rate": 0.0
  },
  "retro": {
    "executed": false,
    "insights_generated": 0
  }
}
METRICS_EOF

  # 知识库自动初始化
  PROJECT_NAME=$(basename "$PROJECT_ROOT")
  KB_DIR="$HOME/.claude/agent-kb/$PROJECT_NAME"
  if [ ! -d "$KB_DIR" ]; then
    mkdir -p "$KB_DIR/insights/platform"
    mkdir -p "$KB_DIR/insights/business"
    TODAY=$(date +%Y-%m-%d)

    cat > "$KB_DIR/overview.md" << KBEOF
---
updated: $TODAY
---

# 项目概览

## 技术栈
<!-- Agent 首次分析项目时自动填充 -->

## 核心模块
<!-- 模块名 + 一句话职责 -->

## 部署方式
<!-- 本地开发 / 测试 / 生产 -->
KBEOF

    cat > "$KB_DIR/pitfalls.md" << PITEOF
---
updated: $TODAY
---

# 踩坑记录

<!-- 格式：
## PIT-001: 简短标题
- **原因**: 为什么会出问题
- **正确做法**: 应该怎么做
- **来源**: 时间 + 事件
- **关键词**: [关键词1, 关键词2]
-->
PITEOF

    echo "  ✅ 已初始化项目知识库: $KB_DIR"
  fi

  echo "✅ .team/ 基础目录已初始化 (v4.0.0)"
fi

# --- 按级别生成文档模板 ---
if [ -n "$GRADE" ]; then
  echo "$GRADE" > "$TEAM_DIR/.grade"

  # S 级已在前面处理，此处处理 M 和 L 级
  if [ "$GRADE" = "M" ]; then
    # M 级: 生成 spec-lite 模板
    if [ ! -f "$TEAM_DIR/spec-lite.md" ]; then
      cat > "$TEAM_DIR/spec-lite.md" << 'MSPEC'
# spec-lite: [功能名称]

> 级别: M | 状态: draft

## 1. 需求描述

### 1.1 背景
<!-- 为什么要做这个功能？1-2 句 -->

### 1.2 目标
| ID | 目标 |
|----|------|
| G-001 | [用户能 xxx] |
| G-002 | [系统能 xxx] |

## 2. 验收标准

| ID | 描述 | 关联 G |
|----|------|--------|
| AC-001 | [具体可验证的条件] | G-001 |
| AC-002 | [具体可验证的条件] | G-001 |
| AC-003 | [具体可验证的条件] | G-002 |

## 3. 接口契约

### API-001: [接口名称]
- **路径**: `POST /api/v1/xxx`
- **请求体**:
  - `field1` (required): string — 描述
  - `field2` (optional): number — 描述
- **响应**: `{ id: string, status: string }`
- **错误码**: 400(参数错误), 401(未授权), 404(不存在)

<!-- 需要更多接口？复制上方模板 -->

## 4. 技术方案（标准深度必填，精简深度可选）
<!-- 实现思路 2-3 段 -->

## 5. 风险评估（标准深度必填，精简深度可选）

| ID | 风险 | 影响 | 缓解方案 |
|----|------|------|----------|
| R-001 | [风险描述] | [影响范围] | [缓解措施] |
MSPEC
      echo "  ✅ 已生成 spec-lite.md 模板"
    fi

    # M 级: 生成 testcases 模板
    if [ ! -f "$TEAM_DIR/testcases.md" ]; then
      cat > "$TEAM_DIR/testcases.md" << 'MTC'
# 测试用例

## §1 验收标准

| ID | 描述 | 关联 G | 优先级 |
|----|------|--------|--------|
| AC-001 | [从 spec-lite.md 复制] | G-001 | P2 |

## §2 测试用例

| ID | AC | API | 类型 | 级别 | 标题 | 前置条件 | 步骤 | 预期结果 | 反向 |
|----|----|-----|------|------|------|----------|------|----------|------|
| TC-MOD-0001 | AC-001 | API-001 | 功能 | P2 | [标题] | [前置] | [步骤] | [预期] | 否 |
| TC-MOD-0002 | AC-001 | API-001 | 功能 | P3 | [反向: 标题] | [前置] | [步骤] | [预期错误] | 是 |
MTC
      echo "  ✅ 已生成 testcases.md 模板"
    fi

    # M 级: 生成 contracts 模板
    if [ ! -f "$TEAM_DIR/contracts.md" ]; then
      cat > "$TEAM_DIR/contracts.md" << 'MCON'
# 接口契约

<!-- 从 spec-lite.md §3 展开详细定义 -->

### API-001: [接口名称]

**路径**: `POST /api/v1/xxx`

**请求体**:
- `field1` (required): string — 描述
- `field2` (optional): number — 描述

**响应 (200)**:
```json
{
  "id": "string",
  "status": "string"
}
```

**错误码**:
- `400` — 参数校验失败
- `401` — 未授权
- `404` — 资源不存在
MCON
      echo "  ✅ 已生成 contracts.md 模板"
    fi

  elif [ "$GRADE" = "L" ]; then
    # L 级: 生成完整 spec 模板
    if [ ! -f "$TEAM_DIR/spec.md" ]; then
      cat > "$TEAM_DIR/spec.md" << 'LSPEC'
# Spec: [项目/功能名称]

> 级别: L | 状态: draft | 版本: v1.0

## 1. 需求

### 1.1 背景与动机
<!-- 为什么要做？业务上下文 -->

### 1.2 目标
| ID | 目标 | 优先级 |
|----|------|--------|
| G-001 | [目标描述] | Must |
| G-002 | [目标描述] | Must |
| G-003 | [目标描述] | Should |

### 1.3 非功能需求
| ID | 类别 | 描述 | 指标 |
|----|------|------|------|
| NFR-001 | 性能 | [描述] | [具体指标] |
| NFR-002 | 安全 | [描述] | [具体指标] |

### 1.4 范围（IN/OUT）
- **IN**: [包含什么]
- **OUT**: [不包含什么]

### 1.5 用户故事
<!-- 可选，按角色分组 -->

### 1.6 假设与依赖
| 类型 | ID | 描述 |
|------|-----|------|
| 假设 | A-001 | [假设条件] |
| 依赖 | D-001 | [外部依赖] |

## 2. 接口契约（引用）
> 详见 contracts.md

## 3. 验收标准（引用）
> 详见 testcases.md §1

## 4. 风险评估
| ID | 风险 | 概率 | 影响 | 缓解方案 |
|----|------|------|------|----------|
| R-001 | [风险描述] | 高/中/低 | [影响范围] | [缓解措施] |

## 5. 追溯矩阵（引用）
> 详见 traceability.md

## 6. 变更记录
| 版本 | 日期 | 变更内容 | 审批 |
|------|------|----------|------|
| v1.0 | YYYY-MM-DD | 初版 | 待审批 |
LSPEC
      echo "  ✅ 已生成 spec.md 模板"
    fi

    # L 级: testcases, contracts, design, traceability 模板
    if [ ! -f "$TEAM_DIR/testcases.md" ]; then
      cat > "$TEAM_DIR/testcases.md" << 'LTC'
# 测试用例

## §1 验收标准

| ID | 描述 | 关联 G | 关联 NFR | 优先级 |
|----|------|--------|----------|--------|
| AC-001 | [验收条件] | G-001 | - | P2 |
| AC-002 | [验收条件] | G-001 | NFR-001 | P1 |

## §2 测试用例

| ID | AC | API | 类型 | 级别 | 标题 | 前置条件 | 步骤 | 预期结果 | 反向 |
|----|----|-----|------|------|------|----------|------|----------|------|
| TC-MOD-0001 | AC-001 | API-001 | 功能 | P1 | [冒烟: 标题](自动化) | [前置] | [步骤] | [预期] | 否 |
| TC-MOD-0002 | AC-001 | API-001 | 功能 | P2 | [标题](自动化) | [前置] | [步骤] | [预期] | 否 |
| TC-MOD-0003 | AC-001 | API-001 | 功能 | P3 | [反向: 标题](自动化) | [前置] | [步骤] | [预期错误] | 是 |
LTC
      echo "  ✅ 已生成 testcases.md 模板"
    fi

    if [ ! -f "$TEAM_DIR/contracts.md" ]; then
      cat > "$TEAM_DIR/contracts.md" << 'LCON'
# 接口契约

### API-001: [接口名称]

**路径**: `POST /api/v1/xxx`

**请求体**:
- `field1` (required): string — 描述
- `field2` (optional): number — 描述

**响应 (200)**:
```json
{
  "id": "string",
  "status": "string",
  "createdAt": "ISO8601"
}
```

**错误码**:
- `400` — 参数校验失败: `{ error: string, details: object }`
- `401` — 未授权
- `403` — 无权限
- `404` — 资源不存在
- `409` — 冲突（重复创建）
- `500` — 服务端错误
LCON
      echo "  ✅ 已生成 contracts.md 模板"
    fi

    if [ ! -f "$TEAM_DIR/design.md" ]; then
      cat > "$TEAM_DIR/design.md" << 'LDES'
# 技术设计

> 级别: L | 状态: draft

## 1. 架构概述
<!-- 系统架构图（文字描述或 ASCII） -->

## 2. 设计决策

### DEC-001: [决策标题]
- **问题**: [要解决什么问题]
- **方案**: [选定方案]
- **理由**: [为什么选这个]
- **替代方案**: [考虑过的其他方案]
- **自审核清单**:
  - [ ] 满足所有相关 G-xxx 目标
  - [ ] 不违反 NFR-xxx 约束
  - [ ] 考虑了可逆性
  - [ ] 记录了 why 不只 what
  - [ ] 不存在过度抽象
  - [ ] 权衡了当前约束
  - [ ] 领域边界清晰

## 3. 数据模型
<!-- 表结构 / Schema 变更 -->

## 4. 可观测性
<!-- 日志埋点 / 监控指标 / 告警规则 -->

## 5. 安全考量
<!-- 认证、授权、数据加密、输入校验 -->
LDES
      echo "  ✅ 已生成 design.md 模板"
    fi

    if [ ! -f "$TEAM_DIR/traceability.md" ]; then
      cat > "$TEAM_DIR/traceability.md" << 'LTRACE'
# 追溯矩阵

> 自动生成，每次更新 spec/testcases/tasks 后刷新

| G/NFR | AC | TC | TASK | 状态 |
|-------|----|----|------|------|
| G-001 | AC-001, AC-002 | TC-MOD-0001, TC-MOD-0002 | TASK-001 | draft |
| G-002 | AC-003 | TC-MOD-0003 | TASK-002 | draft |
| NFR-001 | AC-002 | TC-MOD-0004 | TASK-001 | draft |

## 覆盖率统计

- G→AC: 0/0 (0%)
- AC→TC: 0/0 (0%)
- TC→TASK: 0/0 (0%)
LTRACE
      echo "  ✅ 已生成 traceability.md 模板"
    fi
  fi
fi

# --- 协作模式额外初始化 (v3.4.0 简化版) ---
if [ "$COLLAB_MODE" = true ]; then
  echo ""
  echo "🔧 初始化协作模式..."

  # 状态目录（替代原 messages 目录）
  mkdir -p "$TEAM_DIR/status"
  # 消息目录：inbox（Leader→Worker）+ outbox（Worker→Leader）+ broadcast
  mkdir -p "$TEAM_DIR/messages/inbox"
  mkdir -p "$TEAM_DIR/messages/outbox"
  mkdir -p "$TEAM_DIR/messages/broadcast"
  echo "  ✅ 状态目录已创建"

  # 备份并配置项目级 Hook
  mkdir -p "$PROJECT_ROOT/.claude"
  SETTINGS_FILE="$PROJECT_ROOT/.claude/settings.json"
  BACKUP_FILE="$PROJECT_ROOT/.claude/settings.json.pre-collab"

  if [ -f "$SETTINGS_FILE" ] && [ ! -f "$BACKUP_FILE" ]; then
    cp "$SETTINGS_FILE" "$BACKUP_FILE"
    echo "  ✅ 原始 settings.json 已备份"
  fi

  # 写入 Hook 配置（v3.4.0: worker-sync.sh + leader-sync.sh）
  if [ -f "$SETTINGS_FILE" ]; then
    node -e "
      try {
        const fs = require('fs');
        const settings = JSON.parse(fs.readFileSync('$SETTINGS_FILE', 'utf-8'));
        settings.hooks = settings.hooks || {};
        settings.hooks.PostToolUse = settings.hooks.PostToolUse || [];
        const workerCmd = 'bash $BASE_DIR/worker-sync.sh';
        const leaderCmd = 'bash $BASE_DIR/leader-sync.sh';
        // 清除旧版 Hook
        settings.hooks.PostToolUse = settings.hooks.PostToolUse.filter(h =>
          !h.command || (!h.command.includes('check-inbox') && !h.command.includes('check-outbox') && !h.command.includes('update-status'))
        );
        if (!settings.hooks.PostToolUse.some(h => h.command && h.command.includes('worker-sync'))) {
          settings.hooks.PostToolUse.push({ matcher: '*', command: workerCmd });
        }
        if (!settings.hooks.PostToolUse.some(h => h.command && h.command.includes('leader-sync'))) {
          settings.hooks.PostToolUse.push({ matcher: '*', command: leaderCmd });
        }
        fs.writeFileSync('$SETTINGS_FILE', JSON.stringify(settings, null, 2));
      } catch (e) {
        console.error('Hook 配置失败:', e.message);
        process.exit(1);
      }
    "
  else
    cat > "$SETTINGS_FILE" << HOOKEOF
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "*",
        "command": "bash $BASE_DIR/worker-sync.sh"
      },
      {
        "matcher": "*",
        "command": "bash $BASE_DIR/leader-sync.sh"
      }
    ]
  }
}
HOOKEOF
  fi
  touch "$PROJECT_ROOT/.claude/.hooks-active"
  echo "  ✅ Hook 配置已写入"

  echo ""
  echo "🚀 协作模式初始化完成！"
  echo "  监控状态: bash $BASE_DIR/team-status.sh $PROJECT_ROOT [--watch]"
  echo "  发送指令: bash $BASE_DIR/send-message.sh <from> <to> <type> <content> $PROJECT_ROOT"
  echo "  启动 Worker: bash $BASE_DIR/launch-worker.sh $PROJECT_ROOT <role> <task>"
  echo "  关闭团队: bash $BASE_DIR/shutdown-team.sh $PROJECT_ROOT"
fi
