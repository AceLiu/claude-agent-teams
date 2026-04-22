# Agent Teams Changelog

## v4.2.1 — 安全与稳定性修复

**修复**
- `init-team.sh` / `build-prompt.sh` / `validate-all.sh`：BASE_DIR 改用 `${BASH_SOURCE[0]}`，避免被 `source` 调用时 `$0` 指向调用方 shell 导致 Hook 路径写入 `.claude/settings.json` 错误，协作模式永久失效
- `leader-sync.sh`：重写 Worker 状态汇总逻辑，node 直接从文件读 JSON（不再把 `cat` 出的原始内容拼入 `node -e` 字符串），避免被篡改的 status 文件触发代码执行；同时新增 JSON 解析错误捕获与告警透出，不再静默吞掉异常
- `build-prompt.sh`：对 `WORKER_ROLE` 参数增加格式校验（仅允许小写字母/数字/连字符），防止路径遍历与 mktemp 模板注入
- `send-message.sh`：消息文件名加入 `$$` + `$RANDOM` 后缀，防止同一秒多条消息因伪毫秒时间戳冲突互相覆盖

**安装器**
- `install.sh` 启动时检查 bash ≥ 4（macOS 系统自带 bash 3.2 不满足 `declare -A`）
- `install.sh` 用 `find -exec chmod` 递归给所有 `.sh` 加执行位（原 glob 不覆盖子目录脚本）

## v4.2.0 — Executor 分级自检 + 按仓库合并 + Sonnet 优先

- **Executor 按 complexity 分级自检**：每个 task 的 `complexity` 字段（low/medium/high）决定 Executor 的自检深度，避免对简单改动过度审查
- **同仓库 task 合并 Executor**：多个 task 若在同一仓库，合并交给单个 Executor 顺序执行，减少 subagent 冷启动开销
- **Model Routing 改 Sonnet 优先**：跨仓库一致性检查等范围受限场景从 Opus 降级到 Sonnet，成本下降
- **三审查角色正式纳入**：`critic`（L 必须 / M 条件触发）、`evidence-collector`（Phase 4 含 UI 任务）、`reality-checker`（Phase 5 含 UI 项目）
- SKILL.md 版本号升到 4.2.0（但本版 CHANGELOG 条目此前缺失，v4.2.1 补录）

## v4.1.0 — Task Executor 模式

**核心变更**：Phase 4 引入 Task Executor 模式，将 Leader 逐 task 协调的 Dev→Review→Fix 循环，改为独立 Executor 全权处理 + Architect 批量审查。

**Leader 上下文节省 ~70%**（5-task M 级项目：~85K → ~25K）。

- 新增 `task-executor` Agent 角色定义（`~/.claude/agents/task-executor.md`）
  - 单 task 全生命周期：理解→实现→自检→结构化报告
  - 内置 3 维自检：接口契约 + AC 验收标准 + 代码质量
  - 3 种状态：PASS / NEEDS_CONTEXT / ESCALATE（取代旧 4 状态协议）
- Phase 4 重构为 4 步流程：
  - 4.0 并行派发 TaskExecutor(s) + Tester
  - 4.1 收集 Executor 结果（轻量摘要，不含源码）
  - 4.2 Architect/Reviewer 批量审查（一次调用审查所有 task diff）
  - 4.2+ Critic（L 级不变）/ 4.3 EvidenceCollector（不变）
- 批量审查新增**维度 D — 跨 task 一致性**（多 Executor 产出间风格/命名/冲突检查）
- 所有级别统一合并 spec 合规 + 代码质量审查（原仅 M 级合并）
- Leader 批量读取策略：contracts.md / design.md Phase 4 开始时读一次，所有 Executor 复用
- L 级 tmux 协作模式改为可选（标准 Task tool 模式为默认推荐）
- Tester E2E 测试集成 Chrome MCP（`chrome-webmcp` skill）：
  - 新增方式 A（Chrome MCP 交互式测试）作为推荐优先方式，Playwright 降为方式 B
  - Tester 可通过 MCP 工具直接操控真实浏览器：navigate、click、fill、screenshot、snapshot、network requests、console messages
  - 实时三角校验：`list_network_requests`（API）+ `take_snapshot`（UI）同步对比
  - RealityChecker 同步支持 Chrome MCP 进行端到端用户旅程验证
  - E2E 首次通过率从 ~80%（Playwright selector 匹配）提升至 ~90%（真实浏览器直接操控）
- M 级文档深度按需裁剪：M-lite 内分精简/标准两档
  - 精简深度（AC≤5、≤1 新接口、无 DB 变更、无风险）：只填需求描述 + AC + 接口契约，省略风险/技术方案/追溯矩阵/TC 完整字段
  - 标准深度：全部章节（与 v4.0 行为一致）
  - Architect 执行中发现复杂度超预期可自行升级
- 新增 `QUICKSTART.md`：1 页纸快速入门指南，覆盖定级→执行→速查→常见问题

## v4.0.0 — 架构减重

- Phase 从 8 个合并为 5+2（phase-1~5 + grade-rules + change-protocol）
- SKILL.md 从 ~480 行瘦身至 ~250 行，版本历史移到本文件
- Leader 审核 subagent 化：检查清单交给 Reviewer subagent，Leader 只看结论
- M 级 Phase 变体：phase-2-m-lite.md 独立文件，不在通用文件中内联条件
- S/M/L 条件收敛到 grade-rules.md，各 Phase 文件只写通用流程

## v3.8.0 — 结构性问题修复

- 自动化验证脚本：validate-spec.sh + validate-testcases.sh
- Phase 回溯协议：ID 追加不重编、task invalidation、回溯触发表
- M 级 Phase 1+2 合并选项
- S+ Autopilot 模式：全自动 Dev→Review→完成
- Debugger Agent：根因分析替代盲目升级 model
- Phase 5 分片审查：按模块/维度拆分子审查
- 知识库冷启动：/knowledge init 自动扫描

## v3.7.0 — Spec 文档体系

- spec.md 6 章格式替代 prd.md，design.md 5 章替代 architecture.md
- ID 系统扩展：新增 A-xxx（假设）、D-xxx（依赖），共 10 类
- Spec 模板：CRUD/权限修复/报表查询
- testcases.md 增强：10 字段 TC、P1-P5、正反向 4:6
- solution-design.html、CLAUDE.md 生成、DB 探索 via subagent

## v3.6.0 — SDD 追溯体系

- 8 类 ID 互引系统（G/NFR/AC/R/DEC/API/TC/TASK）
- 5 维方案评分 + DEC 自审核清单
- 三阶段 Review：自动化扫描→Spec 符合性→质量深度
- 自动修复循环（max 3 轮）

## v3.5.0 — E2E 测试

- Playwright E2E 集成 + 截图证据链
- 视觉回归对比（≤5% 像素 diff）

## v3.4.0 — 通信简化

- M 级强制标准模式，协作模式仅 L 级
- 状态文件替代消息队列，Hook 三合一
- CLI 监控替代 Web Dashboard

## v3.3.0 — 分级体系

- S/M/L 三级分级
- Critic 角色（L 级独立审查）

## v3.2.0 — Review 增强

- 逐 task 双阶段 Review（Spec 合规 + 质量速审）
- Implementer 状态协议（DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED）
- Model Routing、并行文件冲突检测

## v3.1.0 — Phase 拆分

- Phase 细节拆到 phases/ 目录
- Worker 失败处理增强、health-check、analyze-metrics

## v2.0.0 — 协作模式

- 标准模式 + tmux 协作模式双轨
- Web Dashboard

## v1.0.0 — 初始版本

- 基本角色体系（PM/Architect/Dev/Tester）
- Phase 1-6 线性流程
