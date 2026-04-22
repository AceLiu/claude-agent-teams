# Spec 文档格式规范

## 概述

Agent Teams Phase 1-2 产出多份文档，通过 ID 系统互相引用，驱动后续 Phase 3-5。

| 文档 | 回答 | 路径 | 产出阶段 |
|------|------|------|---------|
| spec.md | 做什么 | .team/spec.md | Phase 1 (PM) |
| testcases.md | 怎么验 | .team/testcases.md | Phase 1 §1 AC (PM) + Phase 3 §2 TC (Tester) |
| design.md | 怎么做 | .team/design.md | Phase 2 (Architect) |
| contracts.md | 接口契约 | .team/contracts.md | Phase 2 (Architect) |
| traceability.md | 追溯矩阵 | .team/traceability.md | Phase 1 初建 + Phase 2 完善 |
| solution-design.html | 可视化总览 | .team/solution-design.html | Phase 2 (Leader) |

## ID 编号规则

| 类型 | 前缀 | 示例 | 定义位置 | 引用位置 |
|------|------|------|---------|---------|
| 需求目标 | G- | G-001 | spec.md §1.2 | 全部文档 |
| 非功能需求 | NFR- | NFR-001 | spec.md §1.3 | design.md, tasks |
| 假设 | A- | A-001 | spec.md §1.6 | design.md（验证） |
| 依赖 | D- | D-001 | spec.md §1.6 | tasks（协调） |
| 验收标准 | AC- | AC-001 | testcases.md §1 | testcases.md §2 |
| 决策点 | DEC- | DEC-001 | design.md §2 | traceability.md |
| 接口契约 | API- | API-001 | contracts.md | tasks, design.md |
| 测试用例 | TC- | TC-001 | testcases.md §2 | tasks |
| 风险 | R- | R-001 | spec.md §4 | design.md（缓解） |
| 任务 | TASK- | TASK-001 | tasks/task-{NNN}.md | traceability.md |

**编号规则**：
- 同类 ID 从 001 开始，连续编号，不跳号
- 所有 ID 在整个 `.team/` 文档体系内唯一
- 通过 _ref 字段或文本引用互相关联

## 追溯链

```
G-001 → AC-001,002 → TC-001,002 → TASK-001
  ↓                                    ↑
DEC-001 → API-001 ─────────────────────┘
  ↓
R-001 → 缓解方案（design.md §2）
  ↑
A-001（假设条件，影响 DEC 选择）
D-001（外部依赖，影响 TASK 排期）
```

## TC 字段规范

testcases.md §2 中每条 TC 必须包含 10 个字段：

| 字段 | 格式要求 |
|------|---------|
| ID | `TC-{模块缩写}-{4位序号}`，如 `TC-AUTH-0001` |
| 关联 AC | AC-xxx（必须至少一个） |
| 关联 API | API-xxx 或 `-` |
| 类型 | 功能/兼容性/易用性/安全性/可靠性/数据/集成/稳定性/移动端/埋点 |
| 级别 | P1(10%) / P2(40%) / P3(20%) / P4(20%) / P5(10%) |
| 标题 | 主谓宾结构，适合自动化的加 `(自动化)` 后缀 |
| 前置条件 | 无特殊条件填 `无` |
| 步骤 | `1.操作A 2.操作B`，编号递增 |
| 预期结果 | `1.结果A 2.结果B`，与步骤一一对应 |
| 反向用例 | `是` / `否` |

**数量要求**：每个 G-xxx 至少 8-15 条 TC，正向:反向约 4:6。

## 覆盖率要求

| 级别 | 需求→AC | AC→TC | 接口覆盖 |
|------|--------|-------|---------|
| L 级 | 100% | ≥80%（场景级） | 100% |
| M 级 | 100% | ≥70%（AC 级） | 100% |
| S 级 | 不要求 ID 系统 | - | - |

## 状态流转

spec.md 元信息中的 `状态` 字段：

```
draft → approved → developing → verifying → done
         ↑                         ↓
         └── rejected ←────────────┘
```

## 文档间关系

```
spec.md（做什么）
  ├── §2 → contracts.md（接口契约）
  ├── §3 → testcases.md（验收标准 + 测试用例）
  ├── §4 → R-xxx → design.md §2（风险缓解）
  └── §5 → traceability.md（追溯矩阵）

design.md（怎么做）
  ├── §1 → 代码现状分析
  ├── §2 → DEC-xxx（方案决策 + 评分 + 自审核）
  ├── §3 → 数据变更（DDL + 回滚）
  └── §4 → 可观测性（日志/监控/告警）

tasks/task-{NNN}.md（具体步骤）
  ├── test_ref → TC-xxx
  ├── api_ref → API-xxx
  ├── risk_ref → R-xxx
  └── Context Brief（自足上下文）
```
