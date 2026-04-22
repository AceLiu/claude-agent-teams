# Agent Teams 速查卡

## 定级

| 条件 | 级别 | 一句话 |
|------|------|--------|
| ≤3 文件 ≤50 行，无接口/DB | **S+** | 全自动 |
| AC≤5，单角色，无跨模块 | **S** | 写 task 就行 |
| 默认 | **M** | 最常用 |
| AC>10 或 ≥3 角色或跨模块 | **L** | 完整流程 |

交互式定级: `bash grade.sh $PROJECT`

## 各级别产出物

| 产出物 | S+ | S | M | L |
|--------|:--:|:-:|:-:|:-:|
| `tasks/task-*.md` | 自动 | ✓ | ✓ | ✓ |
| `spec-lite.md` | - | - | ✓ | - |
| `spec.md` (完整) | - | - | - | ✓ |
| `testcases.md` | - | - | ✓ | ✓ |
| `design.md` | - | - | - | ✓ |
| `contracts.md` | - | - | 简版 | ✓ |
| `traceability.md` | - | - | - | ✓ |
| Critic 终审 | - | - | 条件 | ✓ |
| retro | - | - | 可选 | ✓ |

## M 级速查（最常用）

```
1. bash init-team.sh $P --grade=M
2. 派 Architect → spec-lite.md → 用户确认
3. Leader 拆 task ∥ 派 Tester 写 TC
4. 并行派 TaskExecutor×N → 收 PASS/ESCALATE
   → 全部 PASS → Architect 批量审查
5. bash validate-all.sh $P M
   → 自动扫描 → 测试 → 交付
```

## Executor 状态

| 状态 | 含义 | Leader 动作 |
|------|------|------------|
| `PASS` | 实现+自检完成 | 收集，等批量审查 |
| `NEEDS_CONTEXT` | 信息不够 | 补信息重派 |
| `ESCALATE` | 2 次失败 | 派 Debugger 诊断 |

## 验证命令

| 命令 | 用途 |
|------|------|
| `bash validate-all.sh $P M` | 一键门控（推荐） |
| `bash validate-spec.sh $P M` | Spec ID + 覆盖率 |
| `bash validate-testcases.sh $P M` | TC 字段 + P 分布 |
| `bash validate-contracts.sh $P` | 契约 vs 源码 |
| `bash team-status.sh $P` | 团队状态 |
| `bash task-dependency.sh $P` | 任务依赖+冲突 |

## Phase 间 compact

```
Phase 3 完成 → /compact（丢弃 Phase 1-3 框架文档）
Phase 4 完成 → /compact（丢弃 Executor prompt）
```

## 角色速记

| 角色 | 一句话 | 何时派 |
|------|--------|--------|
| TaskExecutor | 写代码+自检+报告 | Phase 4 |
| Architect | 设计 + 批量审查 | Phase 2, 4, 5 |
| Tester | 写 TC + 执行测试 | Phase 3-5 |
| Reviewer | Spec/Design 审查 | Phase 1-2 |
| Critic | 独立第三方终审 | L 级 |
| Debugger | ESCALATE 时诊断 | 按需 |
