# Phase 3 - 任务拆解与分配（Team Leader + Tester）

## 执行步骤

### 3.0 并行派发 Tester 编写 TC 规格（与拆解同步）

**在 Leader 开始拆解的同时**，派发 Tester Agent 编写 testcases.md §2（测试用例规格）：

- 使用 `subagent_type="tester"` 派发（角色定义自动加载）
- 输入：spec.md + testcases.md(§1 AC) + contracts.md
- **M-lite 路径**：如果 spec-lite.md 中已有 TC 骨架，额外传入骨架内容，指令 Tester "基于骨架细化补充，不从头重写"
- Tester 产出：testcases.md §2（TC-xxx，10 字段规格）

> 此阶段 Tester 只写 **TC 规格**（"测什么"），不写测试代码（"怎么测"）。测试代码在 Phase 4 与 Dev 并行编写。

Tester 和 Leader 拆解**并行执行**（两个 Task tool 在同一消息中派发），互不阻塞。

**Join point**：两者都完成后，Leader 执行步骤 4（关联 TC 到 task）。如果 Tester 先完成，TC 暂存；如果 Leader 先完成 task 拆解，等待 Tester 返回后再关联。

**TC 10 字段规范**：

`| ID | 关联AC | 关联API | 类型 | 级别 | 标题 | 前置 | 步骤 | 预期 | 反向 |`

- ID: `TC-{模块}-{4位}`（如 `TC-AUTH-0001`）
- 类型: 功能/兼容/易用/安全/可靠/数据/集成/稳定/移动/埋点
- 级别: P1(10%)/P2(40%)/P3(20%)/P4(20%)/P5(10%)
- 适合自动化的标题加 `(自动化)` 后缀
- 每 G-xxx ≥8-15 条，正:反 ≈ 4:6

**设计方法（强制应用）**：等价类划分、边界值分析、因果图法、决策表法、状态转换图、场景法

**Tester 完成后**：
1. `bash validate-testcases.sh {project_root}`
2. Leader 审核 TC（字段完整、覆盖率 L≥80% M≥70%）
3. 更新 traceability.md（补充 TC 列）
4. 关联 TC 到对应 task 文件的 `test_ref` 字段

---

1. **读取 spec.md 和 design.md**

2. **拆解任务**：
   - 每个任务写入 `.team/tasks/task-{NNN}.md`
   - 标注 Assignee、Priority、Depends On
   - 标记哪些任务可以并行（无依赖关系）

   **Task 文件模板**：
   ```markdown
   ---
   id: task-{NNN}
   title: {任务标题}
   assignee: {角色标识符，如 frontend-dev}
   priority: P0 | P1 | P2
   depends_on: [task-{NNN}, ...]  # 无依赖则为空数组 []
   status: pending | in_progress | needs_context | review | done | done_with_concerns | failed | invalidated
   model: sonnet | opus  # 默认 sonnet，仅复杂任务用 opus（见下方 Model Routing）
   complexity: light | standard | complex  # 自检分级（见下方说明）
   repo: {仓库名}  # 该 task 操作的仓库，用于按仓库合并 Executor
   files: [src/xxx, src/yyy]  # 可修改的文件范围
   ---

   ## 任务描述
   （具体的开发任务说明）

   ## 验收标准
   - [ ] AC-{NNN}: ...
   - [ ] AC-{NNN}: ...

   ## 技术要点
   （关键实现提示，引用 design.md 或 contracts.md 中的相关部分）

   ## 内联契约（Leader 从 contracts.md 中提取，Executor 无需自行查找）
   （该 task 涉及的接口契约全文，由 Leader 在 Phase 3 拆解时从 contracts.md 中复制粘贴到此处）

   ## 内联 AC（Leader 从 testcases.md 中提取）
   （该 task 关联的验收标准详情，由 Leader 从 testcases.md 中复制到此处）
   ```

   ### Task complexity 分级（v4.2.0）

   Leader 拆解时为每个 task 标注 complexity，决定 Phase 4 的自检深度和模型选择：

   | complexity | 定义 | 自检方式 | 默认 model |
   |-----------|------|---------|-----------|
   | `light` | 机械实现：DTO、Mapper、配置文件、路由注册 | 跳过自检，直接 PASS，报告一句话 | sonnet |
   | `standard` | 标准 CRUD：Controller、Service 常规逻辑 | 对照内联契约检查签名和返回值 | sonnet |
   | `complex` | 复杂逻辑：状态机、跨服务编排、算法、并发 | 完整自检 + 边界 case 验证 | opus |

   ### 按仓库合并 Executor（v4.2.0）

   Leader 拆解完所有 task 后，**按 `repo` 字段分组**，同一仓库的 task 合并为一个 Executor：

   ```
   合并前（10 个 Executor）：
     task-001 repo=service-user  ┐
     task-002 repo=service-user  ├→ Executor-1（service-user，串行执行 001→002→003）
     task-003 repo=service-user  ┘
     task-004 repo=rest-sell-service → Executor-2
     task-005 repo=hx-ssp-webapp ┐
     task-006 repo=hx-ssp-webapp ├→ Executor-3（hx-ssp-webapp，串行执行）
     task-007 repo=hx-ssp-webapp ┘
     ...

   合并后（≤ 仓库数 个 Executor）：
     同仓库内的 task 按 depends_on 拓扑排序后串行执行
     不同仓库的 Executor 之间并行
   ```

   **合并规则**：
   - 同 `repo` 的 task **必须合并**为一个 Executor
   - 合并后的 Executor prompt 包含该仓库所有 task 的内联契约和 AC
   - 仓库内 task 按 depends_on 排序，无依赖的可并行写（同一 Executor 内顺序执行即可）
   - 跨仓库依赖（如 API jar 发版）：标注在 depends_on 中，Leader 控制 Executor 派发顺序

3. **按需加载可选角色**：
   扫描项目判断需要哪些角色：

   **Designer**：
   - 有 UI 界面需求（PRD 中涉及页面、表单、交互）→ 加载

   **Frontend Dev（三选一，默认 Web）**：
   - 有 `.xcodeproj`/`.xcworkspace`/`Podfile`/`Package.swift`(iOS) → **iOS Dev**
   - 有 `build.gradle`/`settings.gradle`/`AndroidManifest.xml` → **Android Dev**
   - 有 `package.json`/`tsconfig.json`/`.html`/React/Vue/Next.js → **Frontend Dev (Web)**（默认）
   - 用户显式声明平台时，按声明加载
   - 跨平台项目（如同时有 Web + iOS）可同时加载多个前端角色

   **Backend Dev**：
   - 有 API routes/`schema.prisma`/`models/`/server 文件 → 加载

   **AI Assistant**：
   - 有 prompt/LLM/MCP 相关代码或需求 → 加载

   **Documentation Writer**：
   - PRD 中要求产出用户文档、技术文档、API 文档 → 加载
   - 用户显式要求写文档 → 加载
   - Phase 4 与 Dev 并行派发，基于 spec.md + contracts.md + design.md 编写文档
   - 产出 `.team/docs/`，基于 Diataxis 框架（Tutorial/How-to/Reference/Explanation）
   - Phase 5 审查时 Architect 一并检查文档与实现的一致性

   用户也可以显式指定任何角色组合。

4. **并行任务文件冲突检测**：
   Leader 校验所有标记为可并行（无 depends_on）的 task 的 `files` 字段：
   - 任意两个并行 task 的 files **有交集** → 标记为有依赖，改为串行
   - 或使用 `isolation: "worktree"` 隔离执行（仅标准模式支持）
   - 交集判断包含目录级别：`src/components/` 与 `src/components/Button.tsx` 视为有交集

5. **更新 status.md 和 board.md**

### board.md 结构化格式

Team Leader 初始化 board.md 后，所有角色按以下格式写入：

```markdown
## [YYYY-MM-DD HH:mm] @发送者 → @接收者

**类型**: 问题 / 反馈 / 通知 / 决策
**关联**: task-{NNN} / Phase {N} / AC-{NNN}

内容正文...

### 回复（如有）
@回复者 [时间]: 回复内容
```

> 按时间倒序排列（最新在最前）。Leader 定期清理已解决的条目到 `.team/board-archive.md`。

6. **模式判断**（Team Leader 决定）：
   - 角色数 ≤ 2 且无前后端协调 → **标准模式**（后续 Phase 按现有流程）
   - 角色数 ≥ 3 且涉及前后端 + 测试多方协调 → **协作模式**（进入 Phase 3.1）

## Phase 3.1 - 协作模式基础设施初始化

> 仅在协作模式下执行此阶段。

1. **初始化协作基础设施**：
   ```bash
   bash ~/.claude/skills/agent-teams/init-team.sh "{project_root}" --collab
   ```

2. **协作模式限制确认**（告知用户）：
   - Worker 使用 `claude -p` 运行，**无法与用户直接交互**
   - 干预 Worker 需通过 `send-message.sh` 发送 directive
   - `tmux attach` 可查看输出但无法输入
   - 确认用户理解并同意后继续

3. **验证 CLI 监控可用**：运行 `team-status.sh {project_root}` 确认输出正常

4. **更新 status.md**

## Phase 3.5 - UI 设计（Designer Agent，可选）

> 仅在加载了 Designer 角色时执行此阶段，否则跳过直接进入 Phase 3.7。
> 使用 `subagent_type='designer'` 派发（角色定义自动加载）。

1. **派发 Designer Agent（第一轮：设计系统）**：
   - 产出 `.team/designs/design-system.md` + `.team/designs/ref-impl/style-guide.html`

2. **Team Leader 代审设计系统**：
   - [ ] 美学方向明确，有独特辨识度
   - [ ] 色板完整（品牌色、中性色、语义色），无遗漏场景
   - [ ] 字体系统层次清晰，与项目技术栈兼容
   - [ ] 间距/圆角/阴影的阶梯合理，无魔法值
   - [ ] 动效规范统一
   - [ ] 全局布局模式适配 PRD 中的所有页面类型

3. **派发 Designer Agent（第二轮：页面设计 + 参考实现）**：
   - 产出 `.team/designs/design-spec.md` + `.team/designs/ref-impl/{page-name}.html`

4. **Team Leader 代审页面设计**：
   - [ ] 覆盖 PRD 中所有涉及 UI 的功能点
   - [ ] 所有页面严格遵循 design-system.md Token，无硬编码
   - [ ] 跨页面视觉一致性
   - [ ] 交互规范完整（含空状态、加载态、错误态）
   - [ ] 组件复用性好，无重复设计
   - [ ] 响应式策略明确

5. **更新 status.md**

6. **设计 Token 校验规则**（Leader 确认后生效）：
   - CSS/样式文件中禁止出现硬编码色值（如 `#FF5500`、`rgb(255,85,0)`），必须使用 CSS 变量或 Token 引用
   - 禁止硬编码间距值（如 `margin: 13px`），必须使用设计系统定义的间距阶梯
   - Frontend Dev 的 Self-Review Checklist 中已包含此项检查
   - Leader 可在 Phase 5 代码审查时要求 Architect 重点检查 Token 使用率

## Phase 3.7 - 详细设计（Dev Agents）

> 每个 Dev Agent 在编码前必须产出简要技术方案，经 Leader 确认后再进入 Phase 4 编码。
> M 级需求可简化为口头确认（在 board.md 中说明方案即可）。

### 执行步骤

1. **Leader 派发详细设计任务**：
   - 每个 Dev Agent 根据分配的 task + design.md + contracts.md，产出详细设计文档
   - 写入 `.team/designs/detail/{role}-{task}.md`

2. **详细设计文档模板**：

   ```markdown
   # 详细设计: {task 标题}

   ## 模块结构
   涉及的文件和模块，新增/修改哪些文件

   ## 数据模型
   关键数据结构、数据库表变更（如适用）

   ## 核心流程
   关键业务逻辑的处理步骤（伪代码或流程描述）

   ## 接口调用
   调用哪些 API（引用 contracts.md 中的 API 编号），调用顺序和错误处理

   ## 状态管理（前端适用）
   页面/组件的状态流转

   ## 风险与依赖
   技术风险点、对其他模块的依赖
   ```

3. **Leader 快速审查**：
   - [ ] [必须] 模块结构清晰，文件范围与 task 定义一致
   - [ ] [必须] 核心流程覆盖主要场景
   - [ ] [建议] 数据模型合理，无冗余
   - [ ] [建议] 风险识别完整

   不通过 → board.md 反馈 → Dev 修改设计
   通过 → 进入 Phase 4 编码

4. **更新 status.md**

### M 级简化

M 级需求的详细设计可简化：
- Dev 在 board.md 中用 2-3 段文字说明技术方案
- Leader 确认"OK"即可进入 Phase 4
- 无需产出独立的详细设计文件

## Dev 状态协议

> **状态协议**: Phase 4 使用 TaskExecutor 协议（PASS/NEEDS_CONTEXT/ESCALATE），详见 phase-4-development.md §4.0。
> S/S+ 级仍使用 Implementer 协议（DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED）。
