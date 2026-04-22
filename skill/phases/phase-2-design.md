# Phase 2 — 设计

Architect Agent 产出 design.md（5 章）+ contracts.md + traceability.md + solution-design.html。

> TC 由 Tester 在 Phase 3 并行编写，不在本阶段产出。

> M 级可走简化版 `phase-2-m-lite.md`，条件见 `grade-rules.md`。
> **注意**: phase-2-m-lite.md 仅适用于 M 级。L 级必须走本文档的完整设计流程。

## 步骤

### 2.0 数据库探索（按需）

需求涉及 DB 变更时，通过 subagent 探索表结构。**严禁主会话执行 DB 查询**。

触发：代码中有 SQL/Mapper 变更、表结构依赖。纯前端/配置变更跳过。

subagent 返回摘要：表结构、字段分布、索引、问题。

### 2.1 加载知识库

- `call-chains.md` → 调用链路
- `dependencies.md` → 依赖关系
- `conventions.md` → 编码规范
- `pitfalls.md` → 踩坑（填充风险表）
- `insights/` → 按关键词匹配经验
- 不存在 → 跳过

### 2.2 代码探索（不可跳过）

追踪调用链（入口→业务→数据），标注文件:行号，确认框架约束，识别影响文件。

**铁律：方案必须基于代码现状。**

### 2.3 派发 Architect Agent

- 使用 `subagent_type="architect"` 派发（角色定义自动加载）
- 输入：spec.md + testcases.md(§1 AC) + 代码探索结果 + 知识库摘要 + DB 摘要
- 产出：design.md + contracts.md

### 2.4 自动化审核

```bash
bash validate-spec.sh {project_root}
bash validate-contracts.sh {project_root}
```

### 2.5 Reviewer 审核（subagent 化）

派 Reviewer subagent（opus），prompt 包含 design.md + contracts.md + 检查清单：

**design.md 检查项**：
- [ ] 调用链完整，标注文件:行号
- [ ] 每个 DEC-xxx ≥2 方案 + 5 维评分 + 自审核 7 项全勾
- [ ] 选定理由 ≤3 点 + 排除理由 + 实施代码
- [ ] 每条 R-xxx 有技术缓解措施
- [ ] 技术栈兼容、无过度设计
- [ ] L 级：可观测性（日志/监控/告警）完整

**contracts.md 检查项**：
- [ ] 每个 API-xxx：入参出参(required/optional) + 行为 + 错误码 + 示例 + 幂等性

Reviewer 返回 PASS/FAIL。FAIL → 打回 Architect。

### 2.6 更新追溯矩阵

Leader 整合 `.team/traceability.md`（G↔NFR↔DEC↔API↔AC↔R）。TC 列在 Phase 3 Tester 完成后补充。

### 2.7 生成 solution-design.html

整合 spec + design + contracts 核心内容，带样式单文件 HTML。L 级必须，M 级可选。Phase 3 TC 完成后可追加更新。

### 2.8 生成 CLAUDE.md

在项目根目录生成上下文恢复文件。

```markdown
# {项目名称}
> {一句话需求概述}

## 流水线状态
- [x] 需求分析 — .team/spec.md
- [x] 方案设计 — .team/design.md, .team/contracts.md
- [ ] 任务拆解 — 待 Phase 3
- [ ] 开发 — 待 Phase 4
- [ ] 验证 — 待 Phase 5

## 关键决策
- DEC-001: {摘要}
```

---

## 参考规范

### design.md 模板（5 章 + ADR）

```markdown
# {需求标题} — 方案设计
> 日期 | 版本: v1.0 | 关联: spec.md v1.0

## 1. 现状分析（调用链路 + 问题汇总）
## 2. 方案决策（DEC-xxx: 方案对比 + 5 维评分 + 自审核 + 实施代码 + 风险缓解）
## 3. 数据变更（DDL + 回滚）
## 4. 可观测性（日志/监控/告警）
## 5. ADR — 架构决策记录
## 6. 评审修正（仅多视角评审时）
```

### ADR 模板

每个影响系统结构、技术选型、或难以撤销的决策，写一条 ADR。

```markdown
### ADR-{NNN}: {决策标题}

**状态**: Proposed / Accepted / Deprecated / Superseded by ADR-{NNN}

**上下文**
{是什么问题迫使我们做这个决策？描述约束、背景、压力}

**决策**
{我们决定做什么？一句话说清楚}

**后果**
- 变好的：{...}
- 变难的：{...}
- 需要注意的：{...}
```

**ADR 触发条件**（满足任意一条就写）：
- 技术选型（用 A 库还是 B 库）
- 架构模式（单体 / 微服务 / 事件驱动）
- 难以撤销的设计（DB schema、API 版本策略）
- 与现有系统明显不一致的做法

### contracts.md 格式

每个 API-xxx：类型、入参出参(required/optional)、行为、幂等性、版本兼容、错误码、请求/响应示例。

**UI 契约章节**（含 UI 的前端项目必写）：

contracts.md 末尾增加 `## UI 契约` 章节，供 Dev 和 Tester 共享 UI 层约定，消除 E2E 测试的 selector 猜测：

```markdown
## UI 契约

### 路由表
| 页面 | 路径 | 参数 | 说明 |
|------|------|------|------|
| 用户列表 | /users | ?page=&size= | 主列表页 |
| 创建用户 | /users/create | - | 新建表单 |

### data-testid 约定
| 元素 | data-testid | 所在页面 |
|------|-------------|---------|
| 提交按钮 | submit-btn | 所有表单 |
| 搜索框 | search-input | 列表页 |
| 数据表格 | data-table | 列表页 |
| 删除按钮 | delete-btn | 表格行内 |

### 表单字段
| 字段 | name/id | label 文本 |
|------|---------|-----------|
| 用户名 | username | 用户名 |
| 手机号 | phone | 手机号 |
```

**要求**：
- Dev 按 UI 契约添加 `data-testid`，Tester 按 UI 契约写 `getByTestId()`
- UI 契约变更按 C 类变更处理（见 `change-protocol.md`）
- 纯后端 API 项目跳过此章节

### 5 维评分

确定性/可控性/可逆性/运维友好/生态兼容，各 1-5 分，总分 25。

### DEC 自审核（7 项）

回退路径 / 无多余复杂性 / 运行环境 / 部署顺序 / SQL 可回滚 / 接口兼容 / 并发安全

### 分片审查

变更 >10 文件或 >3 模块 → 按模块分片审查。Phase 5 同理按维度拆（架构+数据 / 安全+错误 / 并发+业务+规范）。
