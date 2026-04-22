# Phase 1 — 需求 + 分级

PM Agent 产出 spec.md（6 章）+ testcases.md(§1 AC)，Leader 执行分级。

## 步骤

### 0. 知识预加载（Leader 执行，Phase 1 开始前）

> 知识库是增强项，不存在时不阻塞。

1. **检查知识库**：`~/.claude/agent-kb/{系统名}/` 是否存在
   - 存在 → 读取 `overview.md` + `glossary.md`，拼入后续 PM prompt
   - 不存在 → 提示用户可执行 `bash knowledge-init.sh {project_root}` 初始化，不阻塞

2. **匹配相关经验**：读取 `insights/_index.md`，按用户需求描述中的关键词匹配
   - 匹配到 → 读取对应经验条目，拼入 PM prompt 作为背景参考
   - 未匹配 → 跳过

3. **检查 CLAUDE.md 兜底**：检查目标仓库是否有 `CLAUDE.md`
   - 没有 → Phase 1 结束后自动创建最小版本（技术栈 + 构建命令 + 项目结构概要）
   - 已有 → 跳过

4. **模板匹配**：读取 `{SKILL_DIR}/templates/_index.md` + 知识库 `templates/_index.md`（如有）
   - 匹配顺序：知识库模板 → 内置模板 → 都没有则从零开始
   - 匹配到 → 注入 PM prompt，PM 基于模板填充

### 1.1 初始化

```bash
bash ~/.claude/skills/agent-teams/init-team.sh "{project_root}"
```

### 1.3 模板匹配

| 模板 | 触发关键词 | 文件 |
|------|-----------|------|
| crud | 增删改查、CRUD、管理页面 | `templates/crud.md` |
| permission-fix | 权限修复、越权、角色限制 | `templates/permission-fix.md` |
| report-query | 报表、统计、查询导出 | `templates/report-query.md` |

### 1.4 派发 PM Agent

- 使用 `subagent_type="product-manager"` 派发（角色定义自动加载）
- 输入：用户需求 + 项目上下文 + 知识库摘要 + 模板骨架（如有）
- PM 产出：`.team/spec.md` + `.team/testcases.md`（§1 验收标准）

### 1.5 自动化审核

```bash
bash validate-spec.sh {project_root}
```

检查 ID 连续性和追溯覆盖率。FAIL → 打回 PM 补充。

### 1.6 Reviewer 审核（subagent 化）

派 Reviewer subagent（sonnet），prompt 包含 spec.md + testcases.md §1 + 以下检查清单：

**spec.md 检查项**：
- [ ] 每个 G-xxx 描述可验证
- [ ] NFR-xxx 有可度量标准和验证方式
- [ ] 非目标明确
- [ ] A-xxx 标注验证方式，D-xxx 标注负责方
- [ ] R-xxx 有概率/影响/缓解/Owner
- [ ] 「未回答问题清单」为空
- [ ] 无歧义表述

**testcases.md §1 检查项**：
- [ ] 每条 AC 有 AC-xxx 编号，关联 G-xxx 或 NFR-xxx
- [ ] Given/When/Then 格式，可测试
- [ ] 正向 + 反向场景均覆盖

Reviewer 返回 PASS/FAIL + 问题列表。FAIL → 打回 PM。

### 1.7 分级

Leader 根据 spec.md 中的 AC 条数和预估影响范围判定级别：

> 规则详见 `phases/grade-rules.md`。

向用户确认：`"本需求评估为 M/L 级，将走对应流程，确认？"`

### 1.8 用户确认

展示 spec.md + testcases.md §1 + 级别判定，请用户确认。

**★ HARD-GATE：用户确认需求和级别。**

## spec.md 模板（6 章）

```markdown
# {需求标题}
> 优先级: Px | 作者: {用户} | 创建: {日期} | 状态: draft | 版本: v1.0

## 1. 需求
### 1.1 背景
### 1.2 功能目标（G-xxx）
### 1.3 非功能性需求（NFR-xxx: 类型/描述/度量/验证方式）
### 1.4 非目标
### 1.5 约束
### 1.6 假设（A-xxx）与依赖（D-xxx）

## 2. 接口契约
> 详见 [contracts.md](contracts.md)（Phase 2 填充）

## 3. 验收标准与测试用例
> 详见 [testcases.md](testcases.md)（§1 AC 本阶段完成，§2 TC Phase 3 Tester 并行编写）

## 4. 风险评估（R-xxx: 风险/概率/影响/缓解/Owner）

## 5. 追溯矩阵（Phase 1 初建 G↔AC，Phase 2 扩展）

## 6. 变更记录
```

## testcases.md §1 模板

```markdown
# 验收标准与测试用例
> 关联: spec.md v1.0

## 1. 验收标准
| ID | 关联需求 | Given | When | Then |
|----|---------|-------|------|------|
| AC-001 | G-001 | ... | ... | ... |

## 2. 测试用例
（Phase 3 由 Tester 并行编写）
```
