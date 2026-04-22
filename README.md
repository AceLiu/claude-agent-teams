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
| [Claude Code](https://docs.claude.com/claude-code) ≥ 2.1 | `tmux`（L 级多窗口 worker 需要）|
| `bash` ≥ 4（macOS 建议 `brew install bash`）| `jq`（部分 JSON 解析脚本）|
| Python 3.8+ | `chrome-webmcp` skill（Phase 5 E2E 测试可选）|
| Node.js（用于状态同步脚本）| |

## 安装

在 Claude Code 会话中执行两条命令：

```
/plugin marketplace add AceLiu/claude-agent-teams
/plugin install agent-teams@claude-agent-teams
```

第一条把本仓库注册为 marketplace，第二条装 plugin。Claude Code 会自动：
- 将 `skills/agent-teams/` 注册为可用 skill
- 将 `agents/*.md` 注册为可用 subagent 角色（15 个）

安装后**重启 Claude Code**（或新开会话）让它重新扫描。

### 升级

```
/plugin update agent-teams
```

### 卸载

```
/plugin uninstall agent-teams
```

## 快速开始

在任意项目目录下打开 Claude Code，输入：

```
启动团队开发：我要做一个 xxx 功能
```

触发词（任一即可）：
- `启动团队开发` / `team mode` / `团队模式` / `Agent Teams`
- `quick fix` / `快速修` / `小活`（走 S 级精简流程）

skill 会自动引导你走完 Phase 1 → 2 → 3 → 4 → 5，每个阶段都会停下让你审核。

详细用法见 `skills/agent-teams/QUICKSTART.md`。

## 工作流概览

| 级别 | 触发条件 | 流程 |
|------|---------|------|
| **S+** | 改动 ≤ 3 文件、≤ 50 行、无接口/DB 变更 | Dev → Review → 完成 |
| **S** | "quick fix" / "小活" | Leader 出 task → Dev → Review |
| **M** | AC ≤ 14 且文件 ≤ 15 | Phase 1-5 全流程（Phase 2 可走 lite 版）|
| **L** | AC ≥ 15 或文件 > 15 | Phase 1-5 全流程 + Critic 终审 + 多 worker 并行 |

分级自动判定，用户可 override。

## 仓库结构

```
claude-agent-teams/                    # marketplace + plugin 同仓库
├── .claude-plugin/
│   ├── plugin.json                    # plugin manifest
│   └── marketplace.json               # marketplace 索引
├── skills/
│   └── agent-teams/                   # skill 主体（44 文件）
│       ├── SKILL.md                   # skill 入口（触发词）
│       ├── QUICKSTART.md              # 1 页纸上手指南
│       ├── phases/                    # Phase 1-5 详细流程
│       ├── checklists/ templates/ ...
│       └── *.sh / *.py                # 辅助脚本
├── agents/                            # 15 个 subagent 角色定义
│   ├── product-manager.md   architect.md   task-executor.md
│   ├── frontend-dev.md      backend-dev.md ios-dev.md
│   ├── android-dev.md       ai-assistant.md designer.md
│   ├── documentation-writer.md reviewer.md critic.md
│   ├── debugger.md          evidence-collector.md reality-checker.md
├── README.md  LICENSE  .gitignore
```

## 状态目录

skill 运行时会在 `~/.claude/` 下创建：

| 目录 | 用途 | 是否重要 |
|------|------|---------|
| `~/.claude/agent-kb/<项目名>/` | 知识库：架构、调用链、踩坑 | ⭐⭐⭐ 重要（跨会话复用）|
| `~/.claude/metrics/` | 团队指标：phase 耗时、质量数据 | ⭐ 可选（改进用）|

项目级产出物写在每个项目的 `.team/` 目录下（随项目 git 管理）。

## 版本

- **Plugin 版本**（对外）：查看 `.claude-plugin/plugin.json` 或 `/plugin info agent-teams`
- **Skill 版本**（内部）：查看 `skills/agent-teams/SKILL.md` frontmatter 或 `CHANGELOG.md`

## 贡献

Issue / PR 欢迎。提 PR 前请：
1. 在本地用 `/plugin marketplace add /path/to/claude-agent-teams`（指向本地 clone）验证能装上
2. 修改 skill 后同步更新 `skills/agent-teams/CHANGELOG.md`
3. 新增 agent 角色时，同时更新 `.claude-plugin/plugin.json` 的 `agents` 数组（必须显式列出每个文件路径）

## License

MIT（详见 `LICENSE`）
