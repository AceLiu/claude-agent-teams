# Agent Teams for Claude Code

**多 Agent 协作开发框架** — 在 Claude Code 里用一个指令，启动产品经理、架构师、开发、测试、审查员等 15 个角色，按 Spec 驱动流程并行协作完成需求。

```
需求一句话
   ↓
产品经理 → PRD + 验收标准
架构师 → 设计方案 + 接口契约
TaskExecutor × N → 并行编码 + 自检
Reviewer / Critic → 代码审查
Tester → 渐进式测试（API → 数据 → E2E）
   ↓
交付 + 知识沉淀
```

## 特性

- **Spec 驱动**：从需求 → 设计 → 契约 → 测试 → 编码，每一步都有可审查产出
- **ID 追溯**：AC（验收标准）→ TC（测试用例）→ Task 全链路可追溯
- **分级执行**：S+ / S / M / L 四档，小活不过度流程，大活不失控
- **并行开发**：多个 TaskExecutor 在 git worktree 中独立工作，避免冲突
- **知识沉淀**：每个项目的架构、调用链、踩坑自动写入 `~/.claude/agent-kb/`，下次复用

## 环境要求

| 必需 | 可选 |
|------|------|
| [Claude Code](https://docs.claude.com/claude-code) ≥ 2.0 | `tmux`（L 级多窗口 worker 需要）|
| Python 3.8+ | `jq`（部分 JSON 解析脚本）|
| Bash 4+ | `chrome-webmcp` skill（Phase 5 E2E 测试可选）|

## 安装

```bash
git clone https://github.com/<your-org>/claude-agent-teams.git
cd claude-agent-teams
bash install.sh
```

安装器会：
1. 复制 `skill/` → `~/.claude/skills/agent-teams/`
2. 复制 `agents/*.md` → `~/.claude/agents/`（15 个角色定义）
3. 自动备份已存在的同名文件到 `~/.claude/*.backup.<时间戳>/`
4. 检测 tmux/jq/python3 可选依赖

**重要**：安装后**重启 Claude Code**（或新开会话），让它重新扫描 agents 目录。

## 快速开始

在任意项目目录下打开 Claude Code，输入：

```
启动团队开发：我要做一个 xxx 功能
```

触发词（任一即可）：
- `启动团队开发` / `team mode` / `团队模式` / `Agent Teams`
- `quick fix` / `快速修` / `小活`（走 S 级精简流程）

skill 会自动引导你走完 Phase 1 → 2 → 3 → 4 → 5，每个阶段都会停下让你审核。

详细用法见 `~/.claude/skills/agent-teams/QUICKSTART.md`（安装后生成）。

## 目录结构

```
claude-agent-teams/
├── README.md           # 本文件
├── install.sh          # 安装器
├── uninstall.sh        # 卸载器
├── LICENSE
├── skill/              # → ~/.claude/skills/agent-teams/
│   ├── SKILL.md        # skill 入口（含触发词）
│   ├── QUICKSTART.md   # 1 页纸上手指南
│   ├── CHANGELOG.md    # 版本历史
│   ├── CHEATSHEET.md   # 常用指令速查
│   ├── TROUBLESHOOTING.md
│   ├── phases/         # Phase 1-5 详细流程
│   ├── checklists/     # 代码审查清单
│   ├── templates/      # 常见场景模板（CRUD、handoff 等）
│   ├── schema/         # Spec 格式定义
│   ├── knowledge/      # agent-kb 知识库规范
│   ├── docs/           # 故障排查 / 恢复指南
│   └── *.sh / *.py     # 辅助脚本
│
└── agents/             # → ~/.claude/agents/ (15 个角色)
    ├── product-manager.md
    ├── architect.md
    ├── task-executor.md
    ├── frontend-dev.md
    ├── backend-dev.md
    ├── ios-dev.md
    ├── android-dev.md
    ├── ai-assistant.md
    ├── designer.md
    ├── documentation-writer.md
    ├── reviewer.md
    ├── critic.md
    ├── debugger.md
    ├── evidence-collector.md
    └── reality-checker.md
```

## 工作流概览

| 级别 | 触发条件 | 流程 |
|------|---------|------|
| **S+** | 改动 ≤ 3 文件、≤ 50 行、无接口/DB 变更 | Dev → Review → 完成 |
| **S** | "quick fix" / "小活" | Leader 出 task → Dev → Review |
| **M** | AC ≤ 14 且文件 ≤ 15 | Phase 1-5 全流程（Phase 2 可走 lite 版）|
| **L** | AC ≥ 15 或文件 > 15 | Phase 1-5 全流程 + Critic 终审 + 多 worker 并行 |

分级自动判定，用户可override。

## 状态目录

skill 运行时会在 `~/.claude/` 下创建：

| 目录 | 用途 | 是否重要 |
|------|------|---------|
| `~/.claude/agent-kb/<项目名>/` | 知识库：架构、调用链、踩坑 | ⭐⭐⭐ 重要（跨会话复用）|
| `~/.claude/metrics/` | 团队指标：phase 耗时、质量数据 | ⭐ 可选（改进用）|

项目级产出物写在每个项目的 `.team/` 目录下（随项目 git 管理）。

## 卸载

```bash
bash uninstall.sh
```

卸载器只删 skill 和 agents，**保留** `~/.claude/agent-kb/` 和 `~/.claude/metrics/`（你的工作记录）。如需彻底清理，手动 `rm -rf`。

## 贡献

Issue / PR 欢迎。提 PR 前请：
1. 在本地跑 `bash install.sh` 验证能装上
2. 修改 skill 文档后更新 `skill/CHANGELOG.md`
3. 新增 agent 角色时，确保 frontmatter 包含 `name` 和 `description`

## License

MIT（详见 `LICENSE`）
