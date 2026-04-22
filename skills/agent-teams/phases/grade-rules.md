# 分级规则与各级别 Phase 跳过表

## S+ Autopilot 判定

同时满足以下条件 → S+：
- 改动预估 ≤3 个文件且总行数 ≤50 行
- 无接口变更、无数据库变更
- 用户未要求 Leader 人工审核

**流程**：Leader 写 task → Dev(sonnet) → Reviewer(sonnet, 自动派发) → 自动验收
- Leader 不审核 Dev 产出，Reviewer 通过即完成
- Reviewer 不通过 → Dev 修正 → 重审（max 2 轮）→ 仍不通过才上报 Leader
- 完成后展示变更摘要，用户可回滚

## S 级判定

满足以下**全部**条件 → S 级：
1. 仅涉及 1 个 Dev 角色
2. AC ≤ 5 条
3. 无跨模块接口依赖
4. 无数据库 schema 变更

**显式触发**：用户说 "quick fix"/"快速修"/"小活" → 直接 S 级。

**级别升级**：S 级 Review 发现复杂度超预期（如 AC 覆盖不全、需要跨模块联调），Reviewer 返回 FAIL 且建议升级 → Leader 升级到 M 级，从 Phase 1 开始补充 spec.md。已完成的代码变更保留作为 Phase 4 Dev 的参考。

**流程**：
```
Leader 提炼 task-001.md（需求 + AC ≤5 条）
  → Dev subagent（sonnet）
  → Reviewer subagent（sonnet）：审查质量 + AC 覆盖 + 安全
  → Leader 验收 → 完成
```

**S 级初始化**：
```bash
bash init-team.sh {project_root} --grade=S
# 只创建 tasks/ + reviews/，跳过 board/status/metrics/知识库
```

**task 文件格式**：
```yaml
---
title: "简要标题"
owner: {dev-role}
status: pending
model: sonnet
grade: S
---

## 需求
（3-5 句话）

## 验收标准
- [ ] AC1
- [ ] AC2
```

## M 级判定

不满足 S 级条件，且不满足 L 级条件 → M 级。

**M 级特性**：
- Phase 2 可走简化版（`phase-2-m-lite.md`），该路径同时替代 Phase 1+2，Architect 一次产出 spec-lite.md
- Phase 2 简化条件：需求清晰（G-xxx 可直接提取、无歧义、技术栈已知）
- **文档深度按需裁剪**（v4.1.0）：M-lite 内分精简/标准两档，简单变更（AC≤5、≤1 新接口、无 DB 变更、无风险）可省略风险/技术方案/追溯矩阵/TC 完整字段，详见 `phase-2-m-lite.md`
- Phase 3：1-3 个任务，标准模式，跳过 Designer；详细设计（Phase 3.7）简化为 Dev 在 task 备注或消息中 2-3 段说明方案，无需产出独立文件；task 文件内联契约和 AC（v4.2.0）
- Phase 4：TaskExecutor 按仓库合并 + 自检分级（v4.2.0）；**跳过 4.2 独立批量审查**（Executor 自检 + Phase 5 验证已足够）
- Phase 5：5.0 自动扫描 + 测试 + 全局审查合并；跳过 Critic
- Phase 5 末尾 retro：默认跳过（rework_count ≥3 时建议执行）

## L 级判定

满足以下任一条件 → L 级：
1. ≥3 个 Dev 角色的代码产出
2. 跨模块接口依赖且工作量较大
3. AC ≥ 15 条
4. 数据库 + API + 前端变更同时发生

**L 级特性**：完整 Phase 1-5 + Critic 审查 + 协作模式（tmux）+ retro 必做。

> **L 级编排要求**: ≥5 Task 时必须做任务依赖分析和分批派发（见 phase-4-development.md §4.1.1）。
> **v4.2.0**: Phase 4.2 精简为跨仓库一致性检查（仅检查接口匹配和 Concerns），不重复审查单 task 代码质量。
> ESCALATE 处理为**强制自动化**：Leader 必须自动派 Debugger 诊断，不得跳过或手工处理。最多 3 轮，超过则强制上报用户。

### 量化边界速查

| 指标 | S+ | S | M | L |
|------|:--:|:-:|:-:|:-:|
| AC 数量 | ≤3 | ≤5 | 6-14 | ≥15 |
| 文件变更 | ≤3 | ≤5 | 6-15 | >15 |
| 开发角色 | 0 | 1 | 1-2 | ≥3 |
| 跨模块 | 否 | 否 | 可能 | 是 |
| DB/API 变更 | 否 | 可选 | 可选 | 常见 |

> 多指标冲突时取**较高级别**。如 AC=8(M) 但跨 3 模块(L) → 取 L 级。

## 各级别 Phase 跳过表

| Phase / 步骤 | S+ | S | M | L |
|-------------|:--:|:-:|:-:|:-:|
| Phase 1 需求+分级 | 跳过 | 跳过 | ✅ | ✅ |
| Phase 2 设计 | 跳过 | 跳过 | ✅ 或 M-lite | ✅ |
| Phase 3 拆解 | 跳过 | 跳过 | ✅（无 Designer；详细设计简化为 task 备注说明） | ✅ |
| Phase 4 开发 | ✅(自动) | ✅ | ✅ | ✅ |
| Phase 4 Review | ✅(自动) | ✅ | **跳过**（v4.2.0） | 跨仓库一致性检查+Critic |
| Phase 5.0 自动扫描 | 跳过 | 跳过 | ✅ | ✅ |
| Phase 5.1 测试执行+适配 | 跳过 | 跳过 | ✅ | ✅ |
| Phase 5.3 Spec 符合性 | 跳过 | 跳过 | 合并 | ✅ |
| Phase 5.4 代码质量深度 | 跳过 | 跳过 | 合并 | ✅ |
| Phase 5 Critic | 跳过 | 跳过 | 条件触发(P1≥3) | ✅ |
| Phase 5 交付 | 跳过 | 跳过 | ✅ | ✅ |
| Phase 5 retro | 跳过 | 跳过 | 条件触发 | ✅ |
| PM | 不调用 | 不调用 | ✅ | ✅ |
| Architect | 不调用 | 不调用 | ✅ | ✅ |
| Tester | 不调用 | 不调用 | ✅ | ✅ |
| Critic | 不调用 | 不调用 | 不调用 | ✅ |
| Designer | 不调用 | 不调用 | 不调用 | 按需 |
| Debugger | 按需 | 按需 | 按需 | 按需 |

## 度量计时

Leader 在每个 Phase 开始时 `date +%s`，结束时计算耗时写入 `.team/metrics.json`。
