# Agent Teams Quick Start

> 拿到需求后 30 秒内决定走哪条路。

## Step 1: 定级

```
需求来了 → 问自己 3 个问题：

  Q1: 改动 ≤3 文件 ≤50 行，无接口/DB 变更？
      → Yes: S+ Autopilot（全自动，不用管）

  Q2: AC ≤5，单角色，无跨模块？
      → Yes: S 级（Leader 写 task → Dev → Review → 完成）

  Q3: AC >10 或 ≥3 个 Dev 角色或跨模块大工程？
      → Yes: L 级（完整 5 Phase + Critic + 可选 tmux）

  以上都不是 → M 级（最常用）
```

### 各级别产出物清单

| 产出物 | S+ | S | M | L |
|--------|:--:|:-:|:-:|:-:|
| `tasks/task-*.md` | 自动 | ✓ | ✓ | ✓ |
| `spec-lite.md` | - | - | ✓ | - |
| `spec.md` (完整) | - | - | - | ✓ |
| `testcases.md` | - | - | ✓ | ✓ |
| `design.md` | - | - | - | ✓ |
| `contracts.md` | - | - | 简版 | ✓ |
| `traceability.md` | - | - | - | ✓ |
| Critic 终审 | - | - | 条件触发 | ✓ |
| retro | - | - | 可选 | ✓ |

> 提示: `bash init-team.sh $PROJECT --grade=M` 会自动生成对应级别的模板文件，填空即可。
> 交互式定级: `bash grade.sh $PROJECT`

## Step 2: 按级别执行

### S+ Autopilot

```
你（Leader）: 写 task-001.md（需求 + AC）
系统自动:    Dev(sonnet) → Reviewer(sonnet) → 完成
你:          看变更摘要，确认 OK
```

### S 级

```
1. bash init-team.sh {project} --grade=S
2. 写 .team/tasks/task-001.md（需求 3-5 句 + AC ≤5 条）
3. 派 Dev subagent(sonnet)
4. 派 Reviewer subagent(sonnet)
5. 验收 → 完成
```

### M 级（最常用路径）

```
Phase 1+2 (合并): 派 Architect → 产出 spec-lite.md
                   需求简单(AC≤5)？精简深度，只填 3 个必填章节
                   用户确认 ✓

Phase 3:          Leader 拆 task（1-3 个）
                   同时派 Tester 写 TC

Phase 4:          并行派发 TaskExecutor×N + Tester
                   收集 Executor 报告（PASS/NEEDS_CONTEXT/ESCALATE）
                   全部 PASS → 派 Architect 批量审查（一次）
                   含 UI → EvidenceCollector 截图验收

Phase 5:          自动扫描 → API 测试 → 数据验证 → E2E(Chrome MCP)
                   Architect 合并审查 → 交付
```

### M 级 spec-lite 最小模板（3 必填章节）

```markdown
# spec-lite: [功能名]

## 1. 需求描述
[2-3 句话说清楚要做什么]
| ID | 目标 |
|----|------|
| G-001 | [用户能 xxx] |

## 2. 验收标准
| ID | 描述 | 关联 G |
|----|------|--------|
| AC-001 | [具体可验证的条件] | G-001 |

## 3. 接口契约
### API-001: [接口名]
- **路径**: `POST /api/v1/xxx`
- **请求体**: `{ field: string (required) }`
- **响应**: `{ id: string, status: string }`
- **错误码**: 400, 401, 404
```

> **精简深度**: AC≤5 + ≤1 新接口 + 无 DB + 无风险 → 只需以上 3 章
> **标准深度**: 加 §4 技术方案 + §5 风险评估

### L 级

```
同 M 级，额外：
  - Phase 2 走完整版（design.md 5 章 + contracts.md + ADR）
  - Phase 4 加 Critic 独立终审
  - Phase 5 加 RealityChecker + Critic 终审 + retro 必做
  - 可选 tmux 协作模式（多 Worker 并行）
```

## Step 3: 关键命令速查

| 命令 | 用途 |
|------|------|
| `bash init-team.sh {project}` | 初始化 .team/ 目录 |
| `bash validate-spec.sh {project}` | 校验 spec ID 连续性 + 追溯覆盖率 |
| `bash validate-testcases.sh {project}` | 校验 TC 字段 + P 分布 |
| `bash validate-contracts.sh {project}` | 校验接口契约 vs 源码 |
| `bash team-status.sh {project}` | 查看团队状态 |
| `bash team-status.sh {project} --watch` | 实时监控（tmux 模式） |
| `bash analyze-metrics.sh {project}` | 度量分析报告 |
| `bash knowledge-init.sh {project}` | 初始化项目知识库 |
| `bash task-dependency.sh {project}` | 分析任务依赖和文件冲突 |
| `TROUBLESHOOTING.md` | 故障排除决策树 |

## 核心角色速记

| 角色 | 一句话 | 何时派 |
|------|--------|-------|
| **TaskExecutor** | 单 task 全包：写代码+自检+报告 | Phase 4 |
| **Architect** | 设计方案 + 批量审查 | Phase 2, 4.2, 5 |
| **Tester** | 写测试 + Chrome MCP 验证 | Phase 4 并行, Phase 5 |
| **Reviewer** | Spec/Design 文档审查 | Phase 1, 2 |
| **Critic** | 独立第三方终审 | L 级 Phase 4, 5 |
| **Debugger** | Executor ESCALATE 时诊断根因 | 按需 |

## 上下文管理提醒

```
Phase 3 完成 → /compact（丢弃 Phase 1-3 框架文档）
Phase 4 完成 → /compact（丢弃 Executor prompt 构建内容）
```

## 常见问题

**Q: M 级需求很明确，还要写 spec-lite 所有章节吗？**
A: 不用。AC≤5 + ≤1 新接口 + 无 DB 变更 + 无风险 → 精简深度，只填需求描述 + AC + 接口契约。

**Q: TaskExecutor 返回 ESCALATE 怎么办？**
A: 派 Debugger 诊断 → 根据诊断：补 context 重派 / 升级 model / 拆 task / 上报用户。

**Q: E2E 测试用 Playwright 还是 Chrome MCP？**
A: 首次验证用 Chrome MCP（快+准），回归测试用 Playwright 脚本（可复用+CI）。

**Q: Phase 4 批量审查发现问题怎么办？**
A: Architect 按 task 分组问题 → 定向重派对应 Executor 修复 → 重新批量审查。最多 3 轮。
