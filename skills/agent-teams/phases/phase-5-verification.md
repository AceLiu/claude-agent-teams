# Phase 5 — 验证（测试 + 审查 + 交付 + Retro）

合并原 Phase 5（测试审查）、Phase 6（交付）、Phase 7（retro）。

---

## 5.0 自动化扫描（Leader 执行）

### 变更识别

```bash
git diff {base-branch}...HEAD --name-only  # 限定后续审查范围
```

### 编译检查

前端: `npm run build` / `npx tsc --noEmit`。后端: `mvn compile`。Python: `python -m py_compile`。
失败 → FAIL，停止。

### 安全扫描（Grep）

| 扫描项 | 级别 |
|--------|------|
| 硬编码密码/Token | P0 |
| 敏感信息日志 | P0 |
| SQL 拼接 | P0 |
| debugger/console.log 残留 | P1 |
| TODO/FIXME | P2 |

### 依赖检查

unused import、新增依赖版本号、`npm audit` / `mvn dependency-check`。

### 产出

`.team/reviews/auto-scan.md`。Critical → 自动修复循环（max 3 轮）。

---

## 5.1 渐进式测试执行（Tester Agent）

> API 测试 + 数据验证测试已在 Phase 4 并行编写。E2E 测试在本阶段补写。
> 渐进策略：**API → 数据验证 → E2E**，逐层推进，每层通过后再进入下一层。

### Step 1: 执行 API 测试（首次通过率 ~90%）

派 Tester Agent，输入：
- Phase 4 编写的 API 测试代码
- contracts.md（对照标准）
- Dev 产出的功能代码

```bash
npm test / pytest / mvn test  # 只跑 API 测试
```

API 测试失败 → Tester 修复（通常是 URL 前缀、认证方式微调）→ 重跑。
API 测试通过 → 进入 Step 2。

### Step 2: 执行数据验证测试（首次通过率 ~85%）

```bash
npm test -- --testPathPattern=data-validation  # 只跑数据验证
```

数据验证失败 → 检查响应结构是否与 contracts.md 一致 → 修复 → 重跑。
数据验证通过 → 进入 Step 3。

### Step 3: E2E 测试（仅含 UI 项目）

> **跳过条件**：纯后端 API / CLI / 脚本项目跳过此步骤（Phase 3 角色加载时未加载 Frontend Dev 即视为无 UI）。
> E2E 在 Phase 4 未编写（避免 selector 猜测导致 ~40% 失败率）。
> 此时 Dev 代码已完成，Tester 基于 **UI 契约 + 实际代码** 执行 E2E。

提供两种方式，**优先使用 Chrome MCP**：

#### 方式 A — Chrome MCP 交互式测试（推荐，首次通过率 ~90%）

**前置条件**: 
- 首次使用 Chrome MCP 时，确保已初始化: `bash ~/.claude/skills/chrome-webmcp/ensure-chrome.sh`
- 验证 MCP 工具可用: 通过 ToolSearch 搜索 `chrome-webmcp` 确认工具已加载

Tester 通过 `chrome-webmcp` skill 直接操控真实浏览器验证 UI 行为。

**前置**：Leader 在 Tester prompt 中附加 Chrome MCP 使用指引：
```
E2E 测试使用 Chrome MCP 交互式执行：
1. 启动 Chrome: bash ~/.claude/skills/chrome-webmcp/ensure-chrome.sh
2. 通过 ToolSearch 加载 MCP 工具: ToolSearch "select:mcp__chrome-webmcp__navigate_page,mcp__chrome-webmcp__click,..."
3. 按 TC 用例逐条执行，每步截图取证
```

**Tester 执行流程**：

```
逐条 TC（标注"自动化"的）：
  1. navigate_page → 目标路由
  2. fill / click → 按 TC 步骤操作
  3. wait_for → 等待异步加载
  4. take_snapshot → 验证 DOM 内容（文本、元素存在性）
  5. take_screenshot → 截图存证到 .team/screenshots/e2e/{tc-id}.png
  6. list_network_requests → 验证 API 调用正确（路径、状态码、响应结构）
  7. list_console_messages → 检查无 JS 报错
  8. evaluate_script → 执行自定义断言（如检查表格行数、计算结果）
```

**Chrome MCP 的独有优势**：
- **实时三角校验**：`list_network_requests`（API 响应）+ `take_snapshot`（UI 显示）同步对比
- **无 selector 猜测问题**：直接用 `take_snapshot` 获取真实 DOM，基于实际结构操作
- **交互式调试**：失败时可即时检查页面状态，无需重跑整个测试
- **控制台监控**：`list_console_messages` 捕获运行时 JS 错误

**首次通过率提升原因**：直接操控真实浏览器，无 Playwright selector 匹配失败问题。

#### 方式 B — Playwright 脚本测试（适合 CI/回归）

编写可复用的 Playwright 自动化脚本，适用于需要反复执行的回归场景。

Tester 编写 E2E 时的依据：
1. **contracts.md UI 契约章节**：`data-testid` 约定、路由表、表单字段名
2. **Dev 实际代码**：Leader Read Dev 产出的关键组件/页面代码，拼入 Tester prompt
3. **testcases.md 中标注 `(自动化)` 的 TC**：作为 E2E 用例来源

E2E 代码规范（Playwright）：
1. **Selector 策略**：优先 `getByTestId()`，其次 `getByRole()` / `getByLabel()`
2. **路由**：直接使用 UI 契约中的路由表
3. **测试数据**：从 contracts.md 请求/响应示例提取
4. **认证**：从 design.md 认证方案推导 auth setup
5. **截图检查点**：关键步骤插入 `page.screenshot()`
6. **有 Designer 时**：`expect(page).toHaveScreenshot()` 与基线对比（≤5%）

```bash
npx playwright test --reporter=list,html
```

#### 方式选择策略

| 场景 | 推荐方式 | 原因 |
|------|---------|------|
| Phase 5 首次 E2E 验证 | **Chrome MCP** | 快速验证 + 即时截图 + 无 selector 问题 |
| 需要反复回归的测试 | Playwright 脚本 | 可复用、CI 集成 |
| 调试失败用例 | **Chrome MCP** | 交互式定位问题 |
| 三角校验（API vs UI vs DB） | **Chrome MCP** | `list_network_requests` + `take_snapshot` 实时对比 |
| 视觉回归（有 Designer） | Playwright | `toHaveScreenshot()` 像素级对比 |

E2E 失败 → 修复后重跑（单层内 max 2 轮）。

### Step 4: 收集产出物

- 测试报告 → `.team/test-reports/`
- 截图 → `.team/screenshots/e2e/`（Chrome MCP 截图 + Playwright 截图）
- Trace（Playwright 失败用例）→ `.team/test-reports/traces/`
- Bug 通报：send-message.sh 发给 Dev，附失败用例 + 截图 + 错误日志

产出：`.team/test-reports/report.md`

### 渐进执行收益

| 指标 | 旧方案（Phase 4 写全部→Phase 5 一次跑） | 新方案（渐进式） |
|------|--------------------------------------|----------------|
| Phase 4 并行测试首次通过率 | ~60%（含 E2E 猜测） | ~88%（只含 API+数据验证） |
| Phase 5 E2E 首次通过率 | ~60%（selector 适配） | ~80%（基于 UI 契约+实际代码） |
| Phase 5 平均返工轮次 | 1.5 轮 | 0.5 轮 |

---

## 5.2 系统级终态验收（RealityChecker，含 UI 项目）

> **触发条件**：项目含 UI（Phase 3 加载了 Frontend Dev / Designer）。纯后端/脚本项目跳过。
> **执行时机**：5.1 E2E 测试全部通过后，5.3 Spec 符合性之前。

### 派发方式

使用 `subagent_type="reality-checker"` 派发（角色定义自动加载），prompt 中拼入以下上下文：

- spec.md 的 G-xxx 需求目标列表（全文）
- Phase 4 所有 EvidenceCollector 截图目录列表（`.team/screenshots/evidence/`）
- contracts.md UI 契约章节（路由表 + data-testid 约定）
- 应用访问地址
- Chrome MCP 使用指引（同 Step 3 方式 A），RealityChecker 通过 Chrome MCP 直接操控浏览器完成端到端用户旅程验证

### 裁决处理

| 结论 | 处理 |
|------|------|
| `APPROVED` | 继续 5.4 |
| `NEEDS_WORK`（含 P0）| 按 **QA FAIL 模板**将截图 + 问题清单 + 精确修复指令转发 Dev → 修复后重新执行 5.1 Step 3 E2E + 5.2（max 3 轮） |
| `NEEDS_WORK`（仅 P1）| 记录到 `.team/reviews/p1-backlog.md`，不阻断，继续 5.4 |
| 3 轮后仍 NEEDS_WORK | 按 **Escalation Report 模板**（`templates/handoff-templates.md` §4）生成升级报告，上报用户决策 |

### 产出

- 截图 → `.team/screenshots/reality-check/`
- 报告 → `.team/reviews/reality-check.md`

---

## 5.3 Spec 符合性（Architect Agent）

> **M 级合并**：5.4 + 5.5 合并为一次 Architect subagent 执行，产出 `.team/reviews/combined-review.md`（同时包含 Spec 符合性和代码质量结论）。L 级分开执行，分别产出 `spec-conformance.md` 和 `quality-deep.md`。

### 分片策略

变更 >10 文件或 >3 模块 → 按模块分片，每片独立 subagent，最后汇总。

### 检查项

1. **需求目标**：逐 G-xxx 检查代码实现
2. **接口契约**：逐 API-xxx 核对入参/出参/行为/错误码
3. **风险缓解**：逐 R-xxx 验证 design.md 缓解措施已实现
4. **数据变更**：DDL 准备、索引、迁移可逆
5. **追溯覆盖**：`bash validate-spec.sh`

产出：`.team/reviews/spec-conformance.md`

---

## 5.4 代码质量深度（Architect Agent）

### 分片策略

按维度拆：片 1（架构+数据访问）、片 2（安全+错误处理）、片 3（并发+业务+规范）。

### 6 维度

| 维度 | 关注 |
|------|------|
| 架构 | 分层违反、循环依赖、模块边界 |
| 数据访问 | SQL 注入、事务边界、N+1、分页 |
| 安全 | 认证绕过、授权缺陷、XSS、SSRF |
| 错误处理 | 吞异常、泛化 catch、资源泄漏 |
| 并发性能 | 共享状态、缺同步、无界查询 |
| 业务逻辑 | 角色权限、数据一致性、API 兼容 |

参考 `checklists/code-review-checklist.md`（248 检查点，按模块动态筛选）。

产出：`.team/reviews/quality-deep.md`，每个问题标 P0/P1/P2 + 文件:行号 + 修复建议。

---

## 5.5 Critic 最终把关（仅 L 级）

### Critic 独立终审（L 级强制）

**触发时机**: Phase 4.2 Architect 批量审查 APPROVED 后，自动派 Critic。
**不可跳过**: L 级项目 Critic 终审为强制环节，即使 Architect 审查全部通过。

Critic 审查维度见 `~/.claude/agents/critic.md`。

独立于 Architect 的第三方审查。产出：`.team/reviews/critic-final.md`。

---

## 5.6 回归

Bug/审查问题 → Dev 修复 → Tester 回归。最多 3 轮，超过按 **Escalation Report 模板**上报用户。

每轮 QA 反馈必须使用 **QA FAIL 模板**，确保修复指令精确到文件和动作。

---

## 5.7 Quality Gates

- [ ] 5.0 全 PASS（无 P0/P1 遗留）
- [ ] 5.3 所有 G-xxx 有实现，API-xxx 契约一致
- [ ] 追溯覆盖率 ≥ 目标（L≥80%, M≥70%）
- [ ] P1 测试全通过，0 个 P0 Bug
- [ ] 代码审查 APPROVED
- [ ] [含UI] Phase 4 所有 task 的 EvidenceCollector PASS
- [ ] [含UI] E2E 通过，[有Designer] 视觉回归 ≤5%
- [ ] [含UI] RealityChecker APPROVED，`.team/reviews/reality-check.md` 存在

结论：**APPROVED**（全 PASS）或 **REJECTED**（有 P0/P1 未修复）。

产出汇总：`.team/reviews/review-summary.md`

---

## 5.8 交付（原 Phase 6）

1. 汇总：变更文件、spec 完成度、测试结果、审查结论
2. 展示交付摘要给用户
3. 用户验收
4. 度量写入 `.team/metrics.json` → 归档 `~/.claude/metrics/{项目名}/`
5. 协作模式清理：`bash shutdown-team.sh {project_root}`

---

## 5.9 知识沉淀（/learn）

> **完整流程见 `phases/phase-5-learn.md`**，按需加载。

**触发**：L 级必做，M 级 rework_count ≥3 时建议。

**概要**：从 `.team/` 产出物 + 代码变更中，按 8 维度提炼可复用知识 → 分类为项目级/仓库级/团队级 → 用户逐条审核（HARD GATE）→ 写入对应位置 → 生成 `.team/learn-summary.md`。

### 经验淘汰（各 Phase 读取 insights/ 时执行）

- 触发且有用 → confidence +0.1（上限 1.0）
- 触发但不相关 → confidence -0.2（下限 0.0）
- ≤0.3 → 建议用户删除
- 6 个月未触发 → 标记 `[dormant]`，不再自动注入但保留

---

## 自动修复循环

```
ROUND = 0, MAX = 3
while ROUND < MAX:
    findings = run_review(failed_phase)
    fixable = [可自动修复的: console.log→log, unused import, 缺@Override, 空catch→log]
    if not fixable: break
    apply_fixes → ROUND++ → 重跑
if still_has_issues: "已达 3 轮上限，剩余需人工处理"
```

## 问题分级

| 级别 | 标记 | 定义 | 处理 |
|------|------|------|------|
| Critical | P0 | 安全漏洞、数据丢失 | 必须修复 |
| Major | P1 | 规范违反、边界缺失 | 必须修复 |
| Minor | P2 | 风格建议 | 记录可忽略 |
