# Phase 5.9 — 知识沉淀（/learn）

> Phase 5 验证通过后触发。从本轮 `.team/` 产出物 + 代码变更中提炼可复用知识。
> L 级必做，M 级 rework_count ≥3 时建议。
>
> **核心原则：只沉淀可复用的规律，不搬运需求特定的细节。**

---

## Step 1: 信息收集

### 1.1 读取本轮产出物

必须读取：

- `.team/spec.md` — 需求规格和验收标准
- `.team/design.md` — 技术方案和决策（如有）
- `.team/reviews/batch-review.md` — 批量审查发现的问题
- `.team/reviews/quality-deep.md` — 质量深度审查（如有）
- `.team/test-reports/report.md` — 测试报告（如有）

可选读取（有则读）：

- `.team/reviews/critic-final.md` — Critic 终审
- `.team/reviews/reality-check.md` — UI 终态验收
- `.team/reviews/spec-conformance.md` — Spec 符合性

### 1.2 读取代码变更

```bash
cd {project_root}
git diff main...HEAD --stat    # 变更文件列表
git diff main...HEAD           # 变更详情
git log main...HEAD --oneline  # commit 记录
```

### 1.3 读取现有知识库（用于去重）

项目级：

- `~/.claude/agent-kb/{系统名}/conventions.md`
- `~/.claude/agent-kb/{系统名}/pitfalls.md`
- `~/.claude/agent-kb/{系统名}/glossary.md`
- `~/.claude/agent-kb/{系统名}/overview.md`
- `~/.claude/agent-kb/{系统名}/insights/_index.md`（路由表）

仓库级：

- 目标仓库的 `CLAUDE.md`
- 目标仓库的 `.claude/rules/`（如有）

> 知识库不存在 → 跳过去重，直接进 Step 2。

---

## Step 2: 分析提炼（8 维度）

从以下维度寻找可沉淀的知识：

| # | 维度 | 信号来源 | 沉淀目标 |
|---|------|---------|---------|
| 1 | Agent 理解错误导致的代码问题 | batch-review / quality-deep 中的修复记录 | conventions.md 或 pitfalls.md |
| 2 | 本轮发现的编码约定 | code diff + review findings | conventions.md |
| 3 | 本轮踩的坑 | review / 开发过程中的修复 | pitfalls.md |
| 4 | 新技术模式（跨模块可复用） | design.md 中的方案决策 | insights/platform/*.md |
| 5 | 术语发现或修正 | spec.md 中的消歧记录 | glossary.md |
| 6 | 模块新增或职责变更 | code diff / task 文件 | overview.md |
| 7 | 特定目录的编码约束 | review 中反复出现的同类问题 | 项目 `.claude/rules/{模块}.md` |
| 8 | 跨项目通用经验 | design.md / review 中的通用发现 | insights/business/*.md |

---

## Step 3: 分类输出（建议清单）

按沉淀位置分组展示，每条含操作、内容、来源：

```markdown
## 建议清单

### 项目级（直接写入 agent-kb/{系统名}/）

#### conventions.md

| # | 操作 | 内容 | 来源 |
|---|------|------|------|
| 1 | 新增 | {具体规范描述} | batch-review #N |

#### pitfalls.md

| # | 操作 | 内容 | 来源 |
|---|------|------|------|
| 2 | 新增 | {具体踩坑描述} → **解法**：{怎么避免} | review / develop 踩坑 |

#### insights/{platform|business}/{文件名}.md（新建）

| # | 操作 | 内容 | 来源 |
|---|------|------|------|
| 3 | 新建 | {经验标题}：{描述} | design.md 方案决策 |

### 仓库级（写入项目仓库）

#### .claude/rules/{模块}.md（新建/追加）

| # | 操作 | 内容 | 来源 | scope |
|---|------|------|------|-------|
| 4 | 新建 | {目录}下的{约束描述} | review 反复出现 | project |

### 团队级（仅标记，当前不执行）

| # | 内容 | 来源 | 备注 |
|---|------|------|------|
| 5 | {跨项目通用的发现} | {来源} | scope: team，预留未来共享 |

### 无需沉淀

（列出分析过但判定不需要沉淀的内容及理由）
```

### 质量检查

在展示清单前，自我检查：

- [ ] 每条建议是否有明确来源？无依据的删除
- [ ] 是否与现有知识库内容重复？重复的删除
- [ ] 是否是需求特定的细节而非可复用规律？特定细节的删除
- [ ] 建议数量是否合理？超过 15 条考虑是否过度沉淀
- [ ] 内容是否通用化（不含临时路径、一次性信息）？

---

## Step 4: ★ HARD-GATE — 用户审核

展示完整建议清单，等待用户逐条确认：

- **确认**：保留，进入 Step 5 写入
- **修改**：用户调整内容后保留
- **删除**：不沉淀该条
- **全部确认无误后**，进入 Step 5

---

## Step 5: 写入

### 5.1 项目级写入

对用户确认的项目级建议，直接写入 `~/.claude/agent-kb/{系统名}/` 对应文件。

经验条目使用标准格式：

```markdown
---
id: INS-{系统名}-{序号}
type: pitfall | pattern | convention
scope: project
keywords: [关键词列表]
source: {来源需求或对话}
created: YYYY-MM-DD
confidence: 0.5
---

## {标题}

**Why:** {原因/背景}

**How to apply:** {应用场景和方法}
```

写入后更新 `insights/_index.md` 路由表。

### 5.2 仓库级写入

对用户确认的仓库级建议：

```bash
cd {仓库路径}
# 创建或追加 .claude/rules/{模块}.md
git add .claude/rules/
git commit -m "docs: /learn 知识沉淀 — {需求简称}"
```

### 5.3 团队级标记

scope: team 的条目写入 `.team/learn-summary.md` 的「团队级待处理」小节，不自动写入任何共享位置。
未来接入团队共享机制时，此处走 PR 流程。

### 5.4 生成 learn-summary.md

写入 `.team/learn-summary.md`：

```markdown
# /learn 知识沉淀总结

## 基本信息

- 需求：{需求名称}
- 执行时间：{YYYY-MM-DD}
- 涉及仓库：{仓库列表}

## 沉淀统计

- 项目级：{N} 条（已写入 agent-kb）
- 仓库级：{M} 条（已 commit）
- 团队级：{K} 条（待未来共享）
- 无需沉淀：{J} 条

## 沉淀明细

（将用户确认后的最终清单记录于此）

## 团队级待处理

（scope: team 的条目列表，预留未来共享）
```

---

## 铁律

```
1. 只沉淀可复用的规律，不搬运需求特定的细节
2. 每条建议必须有来源（产出物/代码引用），无依据不写入
3. 必须对比现有知识库内容去重，已有的不重复写入
4. 经验条目必须经用户确认后才写入（HARD GATE 不可跳过）
5. 不修改 overview.md 的已有描述语义（可补充模块，不可改写定位）
6. "无需沉淀"是合法结论，不为沉淀而沉淀
7. 不含具体文件路径的临时信息（用角色描述替代）
```

## 危险信号

```
绝不要：
- 把 spec.md / design.md 的内容原封不动搬到知识库
- 为了让清单显得丰富而凑条目
- 跳过用户审核直接写入
- 在没有读取现有知识库的情况下建议写入（会重复）
- 把代码细节（接口列表、表结构）写入 agent-kb（那是 CLAUDE.md 的职责）

始终要：
- 在建议中给出具体的写入位置（哪个文件的哪个章节）
- 区分项目级/仓库级/团队级
- 用户删除某条建议时不追问原因
- 写入前再次确认文件路径正确
```

## 常见自我合理化

| 自我合理化 | 现实 |
|----------|------|
| "这个需求的细节以后可能有用，先存着" | 需求细节留在 .team/，只有抽象出的规律才进知识库 |
| "这条虽然已有类似的，但角度不同值得保留" | 如果行为一致，就是重复。补充到已有条目，不新增 |
| "用户可能忘了审核这条，我先写入" | 不可以，每条必须用户明确确认后才能写入 |
| "这个经验太细了但我觉得有价值" | 组件内部知识放 .claude/rules/，不放 agent-kb |
