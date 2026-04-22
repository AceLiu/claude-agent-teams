# Phase 4 — 并行开发（Task Executor 模式）

> **v4.1.0 重构**：引入 Task Executor 模式，将原来 Leader 逐 task 协调的 Dev→Review→Fix 循环，
> 改为每个 task 由独立 Executor 全权处理，Leader 只做派发和收集。
> **Leader 上下文节省 ~70%**（从 ~85K 降至 ~25K，以 5-task M 级项目估算）。

## 架构概览

```
Phase 4（新）:

  4.0 Leader 并行派发
      ├─ TaskExecutor(task-001)  ← 独立上下文：实现 + 自检 + 报告
      ├─ TaskExecutor(task-002)  ← 可并行（无依赖时）
      ├─ TaskExecutor(task-003)
      ├─ Tester Agent            ← 并行写 API 测试 + 数据验证测试（不变）
      └─ 有依赖的 task 串行等待

  4.1 Leader 收集 Executor 结果
      ├─ PASS → 记录
      ├─ NEEDS_CONTEXT → 补信息 → 重派
      └─ ESCALATE → Debugger 诊断 / 上报用户

  4.2 批量质量审查（Architect / Reviewer）
      ├─ 一次 subagent 调用审查所有 task 的 diff
      ├─ Spec 合规 + 代码质量合并审查
      ├─ NEEDS_FIX → 定向重派 Executor 修复
      └─ APPROVED → 4.3

  4.2+ Critic（仅 L 级）
      └─ 独立终审，与原流程一致

  4.3 视觉截图验收（含 UI 任务，EvidenceCollector）
      └─ 与原流程一致
```

**与原流程的关键区别**：
| | 原 Phase 4 | 新 Phase 4 |
|---|---|---|
| Leader 职责 | 每个 task：Read 文件→构建 prompt→收结果→派 Reviewer→收结果→处理修复 | 批量派发 Executor → 收集报告 → 派一次 Architect 批量审查 |
| 每 task Leader 上下文消耗 | ~17K（Dev prompt + Review prompt + 修复循环） | ~4K（Executor prompt + 摘要） |
| Review 方式 | 逐 task 派发 Architect/Reviewer | Executor 自检 + Architect 批量终审 |
| 并行能力 | Leader 串行处理每个 task 的 Review | 所有无依赖 task 天然并行 |

---

## 测试代码并行编写（不变）

Phase 4 开始时，Leader **同时派发** TaskExecutor(s) 和 Tester：

```
┌─ TaskExecutor(s): 写功能代码 + 单元测试 + 自检
│
├─ Tester Agent: 写 API 测试 + 数据验证测试（基于 contracts.md，不写 E2E）
│
└─ 两者并行，基于 contracts.md 各自工作，互不阻塞
    E2E 测试延后到 Phase 5（Dev 代码完成后，基于 UI 契约 + 实际代码编写）
```

### 职责划分

| 测试层 | 谁写 | 依据 | 何时写 | 首次通过率 |
|--------|------|------|--------|-----------|
| 单元测试 | **TaskExecutor** | 实现细节（TDD） | Phase 4 编码时 | ~95% |
| API 测试 | **Tester** | contracts.md | Phase 4 并行 | ~90% |
| 数据验证 | **Tester** | spec.md AC + contracts.md | Phase 4 并行 | ~85% |
| E2E 测试 | **Tester** | UI 契约 + Dev 实际代码 | **Phase 5**（延后） | ~80% |

### Tester 派发（不变）

Leader 在派发 Executor 的同一消息中，并行派发 Tester Agent：
- 使用 `subagent_type="tester"` 派发
- 输入：testcases.md + contracts.md + spec.md
- 指令：编写 **API 测试 + 数据验证测试**（不写 E2E）
- 产出：API 测试文件 + 数据验证测试文件，静态存放，Phase 5 执行

---

## 4.0 标准模式 — Task Executor 派发

### Context 注入规则

Leader 派发 Executor 时，**必须先 Read 相关文件，将内容拼入 prompt**。禁止让 Executor 自行读取。

> **角色定义由 Claude Code 通过 `subagent_type="task-executor"` 自动加载**，无需手动 Read。
> Leader 只需注入任务上下文和角色上下文。

### 读取策略（Leader 只读一次）— v4.2.0 上下文预编译

Leader 在 Phase 4 开始时**批量读取公共文件**，后续所有 Executor 复用：

| 文件 | 读取时机 | 注入方式 |
|------|---------|---------|
| contracts.md | Phase 4 开始时读一次 | **无需再按 task 裁剪** — Phase 3 已将相关契约内联到 task 文件中 |
| design.md | Phase 4 开始时读一次 | 每个 Executor 只注入相关设计决策片段 |
| task-{NNN}.md | 按需读取 | 全文注入（已包含内联契约和内联 AC） |
| detail/{role}-{task}.md | 按需读取 | 全文注入对应 Executor |
| design-system.md | Phase 4 开始时读一次（如有） | 注入 UI 相关 Executor |

> **v4.2.0 变化**：Phase 3 拆解时已将 contracts.md 和 testcases.md 的相关片段内联到每个 task 文件中，
> Executor 只需读 task 文件即可获得所有必要上下文，**不再需要读 5 个文件拼合理解**。

### 知识注入策略（Leader 构建 Executor prompt 时）

> 知识库 `~/.claude/agent-kb/{系统名}/` 存在时执行，不存在则跳过。

Leader 在 Phase 4 开始时**批量读取知识文件**，按 task 筛选后注入各 Executor prompt：

| 知识文件 | 注入方式 | 上下文预算 |
|---------|---------|-----------|
| `conventions.md` | 全文注入（通常 ≤500 tokens） | 所有 Executor 共享 |
| `pitfalls.md` | 匹配当前 task 涉及模块的条目 | ≤3 条 / task |
| `insights/_index.md` | 按 task 关键词匹配，读取对应经验文件 | ≤3 条 / task，confidence ≥0.5 |
| 项目 `.claude/rules/{模块}.md` | task 涉及该模块目录时全文注入 | 按需 |

**注入位置**：在 Executor prompt 的 `## 相关设计决策` 之后新增 `## 知识库参考` 小节。

**触发经验淘汰**：如果注入的经验条目被 Executor 在报告中标注为"不相关"，Leader 更新该条目的 confidence（-0.2）。

### 派发流程 — v4.2.0 按仓库合并 Executor

**核心变化**：不再 1 task = 1 Executor，改为 **1 仓库 = 1 Executor**。
Phase 3 已按 `repo` 字段分组（见 phase-3-tasking.md），Leader 在此按分组派发。

**1. 构建 prompt 并并行派发各仓库 Executor：**

使用**同一条消息中的多个 Agent/Task tool 调用**并行派发。每个 Executor prompt 包含：

```
[由 subagent_type="task-executor" 自动加载角色定义]

## 角色上下文
你负责{前端/后端/iOS/Android}开发。技术栈：{React/Spring Boot/Swift/...}
工作仓库：{仓库路径}
{如有 Designer 产出：所有样式值必须引用设计系统 Token，严禁硬编码}

## 任务列表（按依赖顺序执行）
### Task 1: {task-001.md 全文，含内联契约和内联 AC}
### Task 2: {task-002.md 全文，含内联契约和内联 AC}
...（同仓库的所有 task）

## 相关设计决策
{design.md 中与该仓库相关的部分}

## 详细设计
{detail/ 中该仓库相关的文件，如有}

## 设计规范（如有）
{design-system.md + 对应页面设计 + 参考实现}

## 自检分级
按每个 task 的 complexity 字段执行对应深度的自检：
- light: 完成即 PASS，报告一句话
- standard: 对照内联契约检查签名和返回值
- complex: 完整自检 + 边界 case 验证

## 返回要求
按 Task Executor Report 格式返回。每个 task 单独报告状态。
```

**Model 选择**：取该仓库所有 task 中 `model` 字段的**最高值**（有一个 opus 则整个 Executor 用 opus，否则 sonnet）。

> **默认 sonnet**（v4.2.0）：除非 task 标注 `complexity: complex`，否则 model 默认 sonnet。
> Sonnet 输出速度约为 Opus 的 3 倍，大多数 CRUD 和配置任务 Sonnet 完全胜任。

**2. 跨仓库依赖处理：**

等上游仓库 Executor 返回 PASS 后再启动下游仓库 Executor。下游 prompt 中附加上游的修改文件列表。

典型依赖链：`API 定义仓库 → 实现仓库 → 网关仓库 → 前端仓库`

---

### 4.1.1 L 级大项目编排（≥5 Task）

**任务依赖分析**

> **工具**: `bash task-dependency.sh {project_root}` 自动扫描 task 文件，检测文件冲突，输出分批派发建议。

派发 Executor 前，Leader 必须分析任务间依赖：

```
1. 构建依赖图:
   独立任务（无文件交叉）→ 可完全并行
   有依赖任务（共享文件/接口）→ 按拓扑序执行

2. 分批派发:
   Batch 1: 所有独立任务（并行）
   Batch 2: 依赖 Batch 1 的任务（等 Batch 1 全 PASS）
   Batch 3: 依赖 Batch 2 的任务
```

**文件冲突检测**

Leader 在拆 Task 时标注每个 Task 的修改文件列表。两个 Task 修改同一文件时：
- **同文件不同函数**: 可并行，批量审查时重点检查合并
- **同文件同函数**: 不可并行，按依赖序执行
- **接口提供方 vs 消费方**: 提供方先行，消费方后行

**分片审查标准（≥10 Task）**

| 变更规模 | 审查策略 | 分片方式 |
|---------|---------|---------|
| 5-9 Task | Architect 一次审查 | 不分片 |
| 10-15 Task | 按模块分 2-3 片 | 每片 ≤6 Task |
| >15 Task | 按功能域分 3-5 片 | 每片 ≤5 Task + 跨片接口检查 |

每片审查完成后汇总到 `reviews/batch-review.md`，最后做一次跨片一致性检查。

**分片审查聚合流程（强制）**：
1. 每片 Architect 产出 `.team/reviews/batch-review-{片号}.md`
2. 全部分片完成后，Leader 汇总到 `.team/reviews/batch-review.md`
3. Leader 做**跨片一致性检查**（强制）：
   - 共享接口的入参/出参是否一致
   - 共享数据模型的字段定义是否一致
   - 错误码/状态码是否冲突
4. 一致性检查不通过 → 定向重派相关 Executor 修复

**ESCALATE 自动升级**

```
Executor ESCALATE
  → Leader 自动派 Debugger（无需手工判断）
  → Debugger 诊断后返回 4 选 1:
     a) 补充 context → Leader 重派同 Executor
     b) 升级 model (sonnet→opus) → Leader 重派
     c) 拆分 task → Leader 拆为 2 个子 task
     d) 上报用户 → Leader 转发诊断报告
  → 最多 3 轮（每个 task），超过则强制上报用户
```

---

## 4.1 收集 Executor 结果

Leader 逐个处理 Executor 返回：

| 状态 | Leader 处理 |
|------|------------|
| `PASS` | 记录修改文件列表 + AC 自检结果 + Concerns，等待批量审查 |
| `NEEDS_CONTEXT` | 补充 Executor 请求的具体信息，重新派发（同一 task） |
| `ESCALATE` | 按协议处理：派 Debugger 诊断 → 根据诊断升级 model / 拆 task / 上报用户 |

**Leader 在此阶段的上下文消耗**：每个 Executor 只返回结构化摘要（~1K token），不含源代码。

### 前后端联调（≥2 Executor 且存在前后端分离时）

全部 Executor 返回 PASS 后，如果存在前后端分离：

1. Leader 派发一个额外的 `task-executor`，prompt 包含：
   - Backend 实际实现的接口文件路径（Leader Read 后注入）
   - Frontend 已实现的代码路径
   - contracts.md 作为对照
   - 指令："对接真实接口，替换 Mock，验证联调通过"
2. 联调 Executor 返回 PASS → 进入 4.2

### 联调检查清单（附在联调 Executor prompt 中）

- [ ] CORS 配置正确
- [ ] 认证方式对齐（Authorization Header 格式、Token 获取方式）[参考 contracts.md 认证章节]
- [ ] 分页参数对齐（命名、起始值）[参考 contracts.md 分页约定]
- [ ] 错误码映射一致 [参考 contracts.md 错误码章节]
- [ ] 日期格式对齐（ISO 8601 / 时间戳）[参考 contracts.md 数据格式章节]
- [ ] 空值处理对齐（null / undefined / 空字符串）[参考 contracts.md 数据格式章节]

---

## 4.2 批量质量审查（Architect / Reviewer）— v4.2.0 按级别裁剪

> **v4.2.0 变化**：Executor 自检（尤其是 `standard` 和 `complex` 级别）已覆盖大部分质量问题。
> 独立批量审查**按级别裁剪**，避免"第三次理解同一份代码"的冗余开销。

### 审查策略（按级别）

| 级别 | 批量审查方式 | 理由 |
|------|------------|------|
| **M 级** | **跳过独立审查** — Executor 自检 + Phase 5 验证已足够 | M 级 task 少（≤5），自检覆盖率高，独立审查的边际收益低 |
| **L 级** | **仅做跨仓库一致性检查** — 不重复审查单 task 代码质量 | L 级多仓库并行，跨仓库接口一致性是自检无法覆盖的盲区 |

### M 级：跳过 4.2，直接进入 4.3（或 Phase 5）

全部 Executor PASS 后，Leader 直接进入下一步。Executor 的 `standard`/`complex` 自检报告作为质量记录保留。

### L 级：跨仓库一致性检查（精简版）

1. **收集变更范围**：
   ```bash
   git diff --name-only {base}...HEAD
   ```

2. **派发 Architect**（`model: "sonnet"`），prompt 只包含：
   - 所有 Executor 报告的 Concerns 汇总（~1K）
   - **仅跨仓库接口相关的文件**（Dubbo 接口定义、REST Controller 签名、DTO 类）
   - 指令："只检查跨仓库一致性，不重复审查单 task 代码质量"

3. **审查内容（仅 2 个维度）**：

   **维度 A — 跨仓库接口一致性**：
   - API 提供方与消费方的签名是否匹配
   - DTO 字段定义是否一致（提供方 vs 消费方）
   - 错误码是否冲突
   - 共享数据模型的字段定义是否一致

   **维度 B — Executor Concerns 交叉验证**：
   - 检查 Executor 报告中标注 ⚠️ 的问题
   - 多个 Executor 产出之间的命名风格是否一致

4. **处理结果**：

   | 结论 | 处理 |
   |------|------|
   | `APPROVED` | 进入 4.2+ Critic（L 级）或 4.3 |
   | `NEEDS_FIX` | 定向重派对应 Executor 修复 → 重新一致性检查 |

   连续 3 次 NEEDS_FIX → 按 **Escalation Report 模板**上报用户。

### 与 v4.1.0 的对比

| 指标 | v4.1.0（完整批量审查） | v4.2.0（按级别裁剪） |
|------|----------------------|---------------------|
| Architect 调用次数 | 1 次（全量审查） | M 级 0 次 / L 级 1 次（精简版） |
| Architect 审查范围 | 4 个维度（契约+AC+质量+一致性） | L 级仅 2 个维度（一致性+Concerns） |
| Model | L 级 opus | L 级 sonnet（范围缩小后 sonnet 足够） |
| 预估耗时 | 5-8 分钟 | M 级 0 / L 级 2-3 分钟 |

---

## 4.2+ Critic 独立审查（仅 L 级）

> Architect 的 Phase 4.2 APPROVED 后，Leader 额外派发 Critic 做独立终审。
> M 级和 S 级跳过。

### Leader 操作步骤

1. 派发 Critic Agent（`model: "opus"`），prompt 包含：
   - Architect 的 `batch-review.md`（避免重复已发现的问题）
   - 变更文件列表 + 关键文件内容
   - 指令："从 Critic 视角审查，输出到 `.team/reviews/critic-check.md`"

2. Critic 审查维度（与 Architect 互补）：
   - 架构绕行（是否绕过了设计约束）
   - 边界条件（空值、零值、极端输入、并发）
   - 错误处理（异常是否被吞掉、错误信息是否泄漏内部细节）
   - 隐藏耦合（未经契约声明的隐式依赖）
   - 安全风险
   - 测试盲区

3. `APPROVED` → 进入 4.3。`NEEDS_FIX` → 定向重派 Executor → 重新 Critic。连续 3 次 → Escalation Report。

---

## 4.3 视觉截图验收（含 UI 任务，EvidenceCollector）

> **触发条件**：task 含 UI 变更时执行。纯后端/脚本任务跳过。
> **执行时机**：4.2（或 4.2+ Critic）APPROVED 后。

### Leader 操作步骤

1. 使用 `subagent_type="evidence-collector"` 派发，prompt 包含：
   - 含 UI 的 task 的 AC 列表（全文）
   - Dev 实现的关键组件/页面路径
   - UI 契约（contracts.md UI 章节的 data-testid / 路由表）
   - 应用访问地址

2. EvidenceCollector 产出：
   - 截图 → `.team/screenshots/evidence/{task-id}/`
   - 报告 → `.team/reviews/evidence-{task-id}.md`

3. 裁决：
   - `PASS` → task 标记 done
   - `FAIL`（< 3 次）→ QA FAIL 模板转发 Executor 修复 → 重新 4.3
   - `FAIL`（≥ 3 次）→ Escalation Report 上报用户

**全部 task 完成后 → 进入 Phase 5**

---

## 契约变更同步

Phase 4 开发过程中若 contracts.md 发生变更（C 类变更）：
- Leader 在重派 Executor 时注入更新后的 contracts 片段
- 同时通知 Tester 更新受影响的测试代码
- 变更管理流程见 `phases/change-protocol.md`

---

## 协作模式（tmux，仅 L 级）

> L 级大型项目可选择 tmux 协作模式，此时 TaskExecutor 通过 Worker 进程运行。
> 标准模式（Task tool）是默认推荐方式，tmux 模式为可选增强。

1. **启动 Worker**：
   ```bash
   bash launch-worker.sh "{project_root}" task-executor task-003
   ```
   并行启动无依赖任务的 Worker：
   ```bash
   bash launch-worker.sh /path/to/project task-executor task-003 &
   bash launch-worker.sh /path/to/project task-executor task-004 &
   wait
   ```

2. **运行期间 Leader 职责**：
   - 主窗口保持与用户的实时交互
   - 用户下达纠偏指令时使用 `send-message.sh` 推送
   - `leader-sync.sh` Hook 自动汇总 Worker 状态
   - 使用 `team-status.sh --watch` 持续监控

3. **串行任务**：等上游 Worker 状态变为 `done` 后再启动下游。

4. **健康检查**：`leader-sync.sh` 自动检测超过 5 分钟无更新的 Worker 并告警。

### 协作模式限制

> Worker 使用 `claude -p` (pipe 模式) 运行：
> - 执行过程中无法与用户直接交互
> - 干预 Worker 通过 `send-message.sh` 发送 directive
> - tmux attach 可查看输出，无法与 claude 交互
> - 真正的交互式干预需关闭 Worker 重新派发

---

## SDD 增强

**知识注入**：Worker 启动时通过 `build-prompt.py` 自动注入项目知识。

---

## Leader Phase 4 操作速查

```
Phase 4 Leader Checklist:

1. □ 批量 Read 公共文件（contracts.md, design.md, design-system.md）
2. □ 按 task 依赖关系分组（并行组 / 串行链）
3. □ 同一消息并行派发：所有无依赖 TaskExecutor + Tester
4. □ 逐个处理 Executor 返回（PASS/NEEDS_CONTEXT/ESCALATE）
5. □ 有依赖 task：上游 PASS 后启动下游 Executor
6. □ 前后端联调（如需）
7. □ 全部 PASS → 派发 Architect 批量审查
8. □ 批量审查 NEEDS_FIX → 定向重派 Executor → 重新审查
9. □ L 级：Critic 终审
10. □ 含 UI：EvidenceCollector 截图验收
11. □ 全部完成 → 更新 status.md → 进入 Phase 5
```
