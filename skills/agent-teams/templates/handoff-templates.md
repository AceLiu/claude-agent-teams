# Handoff Templates — 结构化交接协议

> Agent 间交接必须使用以下模板，禁止自由格式传递。Leader 负责在 prompt 中附带正确模板的格式要求。

---

## 1. Task Handoff（通用任务交接）

Agent 完成任务后返回给 Leader 的标准格式。

```markdown
## Task Handoff — {task-id}

**From**: {角色名}
**Status**: DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED

### 产出物
- {文件路径}: {变更描述}

### 变更摘要
{2-3 句话说明做了什么}

### Concerns（DONE_WITH_CONCERNS 时必填）
- {concern-1}: {具体描述 + 影响范围}

### Blockers（BLOCKED 时必填）
- {blocker-1}: {原因 + 已尝试的方案}

### 下游依赖提示
{后续 Agent 需要注意什么}
```

---

## 2. QA PASS（审查/验收通过）

Reviewer / Architect / EvidenceCollector / RealityChecker 给出通过结论时使用。

```markdown
## QA PASS — {task-id / phase}

**Reviewer**: {角色名}
**Verdict**: APPROVED ✅
**Scope**: {审查范围描述}

### 通过项
| # | 检查项 | 状态 | 备注 |
|---|--------|------|------|
| 1 | {检查项} | ✅ | — |

### 表扬
- {值得保留的好做法}

### Minor Notes（不阻断，供参考）
- 💭 {可选改进建议}
```

---

## 3. QA FAIL（审查/验收未通过）

审查未通过时使用。**每个问题必须包含精确修复指令**，禁止模糊反馈。

```markdown
## QA FAIL — {task-id / phase}

**Reviewer**: {角色名}
**Verdict**: NEEDS_FIX ❌
**Retry**: {当前第几次} / 3

### 问题清单

#### Issue {N}: [{类别}] - {🔴 Blocker / 🟡 Suggestion}
- **Expected**: {应该发生什么}
- **Actual**: {实际发生什么}
- **Evidence**: {截图文件名 / 测试输出 / 代码位置}
- **Fix instruction**: {具体修复动作，不要模糊}
- **File(s) to modify**: {精确文件路径}

### 修复约束
- Fix ONLY the issues listed above
- Do NOT introduce new features or refactor unrelated code
- Do NOT change files not listed in "File(s) to modify" unless necessary for the fix

### 通过项（已确认 OK 的部分）
- {无需重复检查的内容}
```

---

## 4. Escalation Report（升级报告）

**触发条件**：同一任务/检查点 retry 达到 3 次仍未通过。

```markdown
## Escalation Report — {task-id}

**Escalated by**: {角色名}
**Phase**: {当前 Phase}
**Retry history**: 3/3 exhausted

### 失败摘要
| Retry | 主要问题 | 修复尝试 | 结果 |
|-------|---------|---------|------|
| 1 | {问题} | {做了什么} | FAIL |
| 2 | {问题} | {做了什么} | FAIL |
| 3 | {问题} | {做了什么} | FAIL |

### Root Cause Analysis
{为什么连续 3 次失败？是能力问题、方案问题、还是外部依赖问题？}

### 阻塞影响
- **直接阻塞的任务**: {task-id 列表}
- **时间影响**: {估计延迟}
- **质量影响**: {如果跳过会怎样}

### 建议方案（5 选 1）

| # | 方案 | 风险 | 推荐度 |
|---|------|------|--------|
| A | **换角色/重新派发** — 用不同角色或策略重新执行 | 低 | ★★★ |
| B | **拆分任务** — 将问题部分拆成更小的子任务 | 低 | ★★★ |
| C | **修改方案** — 回到 design.md 调整技术方案 | 中 | ★★ |
| D | **接受现状** — 记录为已知问题，不阻断交付 | 中 | ★ |
| E | **推迟** — 移出当前迭代，记入 backlog | 低 | ★★ |

### Leader 决策
{由 Leader 填写选择的方案 + 理由}
```

---

## 5. Phase Gate Handoff（Phase 间门控）

Phase 转换时由 Leader 填写的门控文档。

> 产出位置: `.team/reviews/phase-gate-{from}-to-{to}.md`（如 `phase-gate-3-to-4.md`）

```markdown
## Phase Gate — Phase {N} → Phase {N+1}

**Date**: {timestamp}
**Project**: {项目名}
**Level**: S / M / L

### 准入检查

| # | Gate 条件 | 状态 | Evidence |
|---|-----------|------|----------|
| 1 | {条件描述} | ✅/❌ | {证据：文件路径 / 审查报告} |

### Phase {N} 产出物清单

| 产出物 | 路径 | 状态 |
|--------|------|------|
| {文档/代码} | {路径} | ✅ 存在 / ❌ 缺失 |

### 风险登记（携带进下一 Phase 的风险）

| Risk | Severity | Mitigation | Owner |
|------|----------|------------|-------|
| {风险} | High/Med/Low | {缓解措施} | {角色} |

### 决策
- **READY** → 进入 Phase {N+1}
- **NEEDS WORK** → 返回 Phase {N} 补充（具体补充项：{...}）
- **NOT READY** → 升级到用户决策
```

---

## 使用规则

1. **Leader 职责**：在派发 subagent 的 prompt 末尾附加对应模板格式要求，指定"请按 {模板名} 格式返回结果"
2. **Subagent 职责**：严格按模板格式输出，不得省略必填字段
3. **QA FAIL 约束**：每个 Issue 的 `Fix instruction` 必须具体到可执行的动作，禁止写"请改进"、"请优化"等模糊指令
4. **Escalation 触发**：任何环节 retry ≥ 3 次，必须使用 Escalation Report 模板上报，禁止无限重试
5. **Phase Gate**：Phase 1→2、2→3、4→5 转换时必须填写 Phase Gate Handoff（S 级可省略）
