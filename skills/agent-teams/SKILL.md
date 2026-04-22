---
name: agent-teams
description: "多 Agent 协作开发团队：产品经理定需求、架构师出方案、开发并行编码、测试审查验收。触发词：启动团队开发、team mode、团队模式、Agent Teams、启动协作开发、quick fix、快速修、小活"
version: 4.2.1
---

# Agent Teams v4.2.1

多角色 subagent 协作开发框架。Spec 驱动、ID 追溯、分级执行。

> 首次使用？先看 **`QUICKSTART.md`** — 1 页纸搞懂"拿到需求该做什么"。
> 完整版本历史见 `CHANGELOG.md`。

## 分级与模式

| 级别 | 触发 | Dev 数 | 执行方式 | Phase |
|------|------|--------|----------|-------|
| **S+** | 极简改动（≤3 文件 ≤50 行，无接口/DB 变更） | 1 | Autopilot：Dev→Review→自动完成 | 无 |
| **S** | "quick fix"/"快速修"/"小活" | 1 | Leader 写 task→Dev→Review→验收 | 无 |
| **M** | AC ≤14 且文件变更 ≤15 | 1-2 | TaskExecutor 并行 + 批量审查 + 联调轮 | 1→2→3→4→5 |
| **L** | AC ≥15 或文件变更 >15 | ≥3 | TaskExecutor 并行 + 批量审查 + [可选]tmux | 1→2→3→4→5 |

> 分级规则详见 `phases/grade-rules.md`。M 级可走 Phase 2 简化版（`phase-2-m-lite.md`）。

## Phase 流程

```
M/L 级：
Phase 1: 需求+分级 → PM 产出 spec.md + testcases.md(AC) → 分级 → 用户确认
  ↓
Phase 2: 设计 → Architect 产出 design.md + contracts.md
  ↓       （M 级可走 phase-2-m-lite.md；L 级必走完整 Phase 1→2，不可跳过）
Phase 3: 拆解 → Leader 拆 task ∥ Tester 写 TC（并行）+ [可选]Designer + 详细设计
  ↓
Phase 4: 开发 → TaskExecutor 独立实现+自检 ∥ Tester 写 API+数据验证测试（并行，E2E 延后）
  ↓       全部 PASS → Architect 批量审查 → [L:Critic] → [含UI] EvidenceCollector 截图验收
Phase 5: 验证 → 自动扫描 → 渐进测试(API→数据→E2E补写+执行) → [含UI] RealityChecker 终态验收 → Spec 符合性 → 质量深度 → [L:Critic] → 交付 + /learn 知识沉淀
```

### Phase 文件索引

| Phase | 文件 | 关键产出 |
|-------|------|----------|
| 1 | `phases/phase-1-requirements.md` | `.team/spec.md`, `testcases.md`(§1 AC), 级别判定 |
| 2 | `phases/phase-2-design.md` | `.team/design.md`, `contracts.md`, `traceability.md`(初版), `solution-design.html` |
| 2M | `phases/phase-2-m-lite.md` | `.team/spec-lite.md`（M 级合并产出，支持精简/标准两档深度） |
| 3 | `phases/phase-3-tasking.md` | `.team/tasks/task-{NNN}.md`, `testcases.md`(§2 TC, Tester 并行), UI 设计, 详细设计 |
| 4 | `phases/phase-4-development.md` | TaskExecutor 独立实现+自检, Tester API+数据验证测试(并行), 批量审查 `reviews/batch-review.md` |
| 5 | `phases/phase-5-verification.md` | 渐进测试(API→数据→E2E补写+执行), `reviews/`, `test-reports/`, `metrics.json` |
| 5.9 | `phases/phase-5-learn.md` | 知识沉淀：8 维度提炼 → 分类 → 用户审核 → 写入 agent-kb + learn-summary.md |
| — | `phases/grade-rules.md` | S+/S/M/L 判定规则、各级别 Phase 跳过表 |
| — | `phases/change-protocol.md` | 需求变更管理、Phase 回溯协议 |

> **按需加载**：进入 Phase 时才 Read 对应文件，不要预读。

## 角色

### 核心角色

| 角色 | subagent_type | 职责 | 启动条件 |
|------|--------------|------|---------|
| Team Leader | 你自己 | 分发、决策、与用户沟通 | 始终 |
| Product Manager | `product-manager` | 需求→spec.md | M/L |
| Architect | `architect` | 设计、批量审查 | M/L |
| **TaskExecutor** | `task-executor` | **单 task 全生命周期：实现+自检+报告** | **M/L Phase 4** |
| Tester | `tester` | 测试计划、执行 | M/L |
| Reviewer | `reviewer` | 检查清单驱动审查 | M/L（Phase 1/2） |
| Critic | `critic` | 独立质量审查 | L 必须 / M 条件触发(P1≥3) |
| Debugger | `debugger` | 根因分析 | Executor ESCALATE 时 |
| EvidenceCollector | `evidence-collector` | 截图驱动任务级 QA 门控 | Phase 4 含 UI 任务 |
| RealityChecker | `reality-checker` | 截图驱动系统级终态验收 | Phase 5 含 UI 项目 |

> 所有角色定义均在 `~/.claude/agents/` 目录下，由 Claude Code 自动加载为全局 subagent。

### 可选角色（Phase 3 按需加载）

| 角色 | 脚本标识符 | 加载条件 |
|------|-----------|---------|
| Designer | `designer` | 项目含 UI |
| Frontend Dev (Web) | `frontend-dev` | package.json/React/Vue（默认） |
| iOS Dev | `ios-dev` | .xcodeproj/Podfile |
| Android Dev | `android-dev` | build.gradle |
| Backend Dev | `backend-dev` | 后端代码 |
| AI Assistant | `ai-assistant` | 涉及 LLM/MCP |
| Documentation Writer | `documentation-writer` | 需产出文档 |

### 调用模板

```
Task tool: subagent_type="{role-name}"
prompt: [任务指令 + 上下文（spec、contracts、AC 等相关内容）]
```

**重要**：角色文件由 Claude Code 从 `~/.claude/agents/` 自动加载为系统提示，无需 Leader 手动 Read 后拼入。Leader 只需将任务上下文（spec 内容、contracts 内容等）写入 prompt 即可。

### 交接协议

所有 Agent 间的交接必须使用 `templates/handoff-templates.md` 中定义的结构化模板：

| 场景 | 模板 | 用途 |
|------|------|------|
| Agent 完成任务 | Task Handoff (§1) | 标准任务交接 |
| 审查/验收通过 | QA PASS (§2) | Reviewer/Architect/EvidenceCollector/RealityChecker 通过 |
| 审查/验收未通过 | QA FAIL (§3) | 含精确修复指令的失败反馈 |
| 连续 3 次失败 | Escalation Report (§4) | 根因分析 + 5 选项方案，上报用户 |
| Phase 间转换 | Phase Gate (§5) | 门控检查（S 级可省略） |

**Leader 在派发 subagent 时，必须在 prompt 末尾指定返回格式**：如"请按 QA FAIL 模板格式返回审查结果"。

## ID 追溯体系

> 格式规范见 `schema/spec-format.md`。

| 前缀 | 类型 | 定义位置 |
|------|------|---------|
| G- | 需求目标 | spec.md §1.2 |
| NFR- | 非功能需求 | spec.md §1.3 |
| A- | 假设 | spec.md §1.6 |
| D- | 依赖 | spec.md §1.6 |
| AC- | 验收标准 | testcases.md §1 |
| R- | 风险 | spec.md §4 |
| DEC- | 决策点 | design.md §2 |
| API- | 接口契约 | contracts.md |
| TC- | 测试用例 | testcases.md §2 |
| TASK- | 任务 | tasks/task-{NNN}.md |

**追溯链**：`G→AC→TC→TASK`，`G→DEC→API→TASK`，`R→缓解方案(design.md)`

**覆盖率**：L 级 AC→TC ≥80%，M 级 ≥70%，S 级不要求。每 G-xxx 至少 8 条 TC。

## TaskExecutor 状态协议

> v4.1.0 起，Phase 4 使用 TaskExecutor 替代传统 Dev+Reviewer 循环。状态协议简化为 3 种。

| 状态 | 含义 | Leader 处理 |
|------|------|------------|
| `PASS` | 实现完成 + 自检通过 | 收集报告，M 级直接完成 / L 级等待一致性检查 |
| `NEEDS_CONTEXT` | 信息不足 | 补充信息 → 重派 |
| `ESCALATE` | 尝试 2 次仍无法解决 | **自动派 Debugger** → 4 选 1（补 context/升级 model/拆 task/上报），最多 3 轮 |

> **v4.2.0 自检分级**：Executor 按 task 的 `complexity` 字段决定自检深度：
> - `light`：跳过自检，直接 PASS，报告一句话
> - `standard`：对照内联契约检查签名和返回值
> - `complex`：完整自检 + 边界 case 验证
>
> **v4.2.0 按仓库合并**：同仓库的 task 合并为一个 Executor，减少冷启动开销。
>
> **S/S+ 级仍使用旧 Implementer 协议**（DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED），因为不走 TaskExecutor。

## Model Routing（v4.2.0 Sonnet 优先）

> **默认 Sonnet**：Executor 默认使用 Sonnet，仅 `complexity: complex` 的 task 使用 Opus。
> Sonnet 输出速度约为 Opus 的 3 倍，大多数实现任务 Sonnet 完全胜任。

| 任务特征 | Model | 场景 |
|---------|-------|------|
| `complexity: light` | `sonnet` | DTO、Mapper、配置、路由注册 |
| `complexity: standard` | `sonnet` | CRUD Controller、Service、简单组件 |
| `complexity: complex` | `opus` | 状态机、跨服务编排、复杂算法 |
| 架构设计（Phase 2） | `opus` | Architect 产出 design.md |
| 跨仓库一致性检查（4.2） | `sonnet` | 范围缩小后 Sonnet 足够 |
| Critic（L 级） | `opus` | 独立终审需最强推理 |

ESCALATE 处理：Debugger 诊断 → 根据诊断升级 model / 拆任务 / 上报用户。

## 知识库

> 详见 `knowledge/KNOWLEDGE.md`，按需加载。

路径：`~/.claude/agent-kb/{项目目录名}/`（取项目根目录的 basename，如 /path/to/my-app → ~/.claude/agent-kb/my-app/）。核心文件：overview/call-chains/dependencies/conventions/pitfalls/glossary。
初始化：`bash knowledge-init.sh {project_root} [--full]` — 自动扫描技术栈、模块、入口文件生成初版。
经验库：`insights/`。模板：`{SKILL_DIR}/templates/`（CRUD/权限/报表，不依赖知识库）。
冷启动：`/knowledge init` 自动扫描项目生成初版。不存在时不阻塞。

## 脚本索引

| 脚本 | 用途 |
|------|------|
| `init-team.sh` | 初始化 .team/ 目录 + 按级别生成文档模板 |
| `grade.sh` | 交互式定级工具（Q1-Q3 → 推荐级别+命令） |
| `validate-all.sh` | **Phase Gate 一键门控**（聚合下方三个脚本） |
| `knowledge-init.sh` | 自动扫描项目生成初版知识库（快速/完整两种模式） |
| `validate-spec.sh` | Spec ID 连续性 + 覆盖率 + 孤立 ID + 追溯矩阵 + DEC 自审核 |
| `validate-testcases.sh` | TC 字段完整 + P 分布 + 正反比（支持 --grade） |
| `validate-contracts.sh` | 接口契约结构校验（支持 --grade） |
| `launch-worker.sh` | 启动 tmux Worker（L 级） |
| `worker-loop.sh` | Worker 多任务循环 + 自主认领 |
| `build-prompt.sh` | 构建 Worker prompt（含知识注入） |
| `send-message.sh` | Agent 间消息 |
| `shutdown-team.sh` | 关闭协作模式 |
| `health-check.sh` | Worker 健康检查 |
| `team-status.sh` | CLI 状态监控（--watch） |
| `task-dependency.sh` | 任务依赖分析 + 文件冲突检测 + 分批派发建议 |
| `analyze-metrics.sh` | 度量分析报告 |
| `record-phase-time.sh` | Phase 计时 |

Hook：`worker-sync.sh`（Worker PostToolUse）、`leader-sync.sh`（Leader PostToolUse）。

## 异常处理

| 场景 | 处理 |
|------|------|
| Agent 产出不达标 | send-message.sh 反馈 → 重派 |
| Executor ESCALATE | **自动派 Debugger** 诊断 → 4 选 1: 补 context/升级 model/拆 task/上报用户（最多 3 轮） |
| 批量审查 NEEDS_FIX | 定向重派对应 Executor 修复 → 重新批量审查 |
| 回归 3 次仍不过 | 上报用户 |
| Worker 无响应 | health-check.sh → tmux attach |
| 需求变更 | 见 `phases/change-protocol.md` |

> 详细故障排除见 `TROUBLESHOOTING.md`。

## 上下文管理

Leader 全程在线，上下文会累积。关键纪律：

- **Phase 3→4 转换时**建议 `/compact`（Phase 1-3 框架文档不再需要逐字保留）
- **Phase 4→5 转换时**再次 `/compact`（Phase 4 的 Executor prompt 构建内容可丢弃）
- **Phase 4 批量读取**：contracts.md / design.md 在 Phase 4 开始时读一次，所有 Executor 复用（见 phase-4-development.md 读取策略）
- **Executor 报告轻量化**：每个 Executor 只返回结构化摘要（~1K token），不含源代码，大幅降低 Leader 上下文占用
- **避免重复 Read**：同一个文件在同一 Phase 内只 Read 一次

## 敏感信息

文档禁止明文凭据，使用 `${API_KEY}` 占位符。测试用 mock/stub。
