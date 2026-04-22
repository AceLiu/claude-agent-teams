#!/usr/bin/env bash
# Agent Teams - Claude Code Skill Installer
# 将 agent-teams skill + 15 个 agent 角色定义安装到 ~/.claude/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$SCRIPT_DIR/skill"
AGENTS_SRC="$SCRIPT_DIR/agents"

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
SKILL_DEST="$CLAUDE_HOME/skills/agent-teams"
AGENTS_DEST="$CLAUDE_HOME/agents"

c_green() { printf '\033[32m%s\033[0m\n' "$*"; }
c_yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
c_red() { printf '\033[31m%s\033[0m\n' "$*" >&2; }

# --- 1. 环境检查 ---
if [ ! -d "$CLAUDE_HOME" ]; then
  c_red "❌ 未找到 Claude Code 配置目录: $CLAUDE_HOME"
  c_red "   请先安装 Claude Code: https://docs.claude.com/claude-code"
  c_red "   或设置环境变量 CLAUDE_HOME 指向自定义位置"
  exit 1
fi

if [ ! -d "$SKILL_SRC" ] || [ ! -d "$AGENTS_SRC" ]; then
  c_red "❌ 安装包不完整，缺少 skill/ 或 agents/ 目录"
  c_red "   请确认在仓库根目录执行 install.sh"
  exit 1
fi

# Bash 版本检查：task-dependency.sh 等脚本使用 declare -A 关联数组（需要 bash 4+）。
# macOS 自带的 /bin/bash 是 3.2，使用 #!/usr/bin/env bash 时需要 PATH 中有 bash 4+。
BASH_MAJOR="${BASH_VERSINFO[0]:-0}"
if [ "$BASH_MAJOR" -lt 4 ]; then
  c_red "❌ 当前 bash 版本过低 (${BASH_VERSION:-unknown})，需要 bash 4+"
  c_red "   macOS 用户请安装：brew install bash"
  c_red "   然后用新 bash 重试：/opt/homebrew/bin/bash install.sh  (Apple Silicon)"
  c_red "   或 /usr/local/bin/bash install.sh  (Intel)"
  exit 1
fi

c_green "▶ 开始安装 Agent Teams → $CLAUDE_HOME"
echo ""

# --- 2. 备份已存在的冲突 agent 文件 ---
BACKUP_DIR=""
for f in "$AGENTS_SRC"/*.md; do
  name="$(basename "$f")"
  dest="$AGENTS_DEST/$name"
  if [ -f "$dest" ] && ! cmp -s "$f" "$dest"; then
    if [ -z "$BACKUP_DIR" ]; then
      BACKUP_DIR="$CLAUDE_HOME/agents.backup.$(date +%Y%m%d-%H%M%S)"
      mkdir -p "$BACKUP_DIR"
      c_yellow "⚠ 检测到已有同名 agent 文件，备份到: $BACKUP_DIR"
    fi
    cp "$dest" "$BACKUP_DIR/"
    echo "   · 备份 $name"
  fi
done

# --- 3. 备份已存在的 skill 目录 ---
if [ -d "$SKILL_DEST" ]; then
  SKILL_BACKUP="$CLAUDE_HOME/skills/agent-teams.backup.$(date +%Y%m%d-%H%M%S)"
  c_yellow "⚠ 检测到已有 skill 目录，备份到: $SKILL_BACKUP"
  mv "$SKILL_DEST" "$SKILL_BACKUP"
fi

# --- 4. 安装 skill ---
mkdir -p "$SKILL_DEST"
cp -R "$SKILL_SRC/." "$SKILL_DEST/"
# 递归给所有 .sh 加执行位（glob *.sh 不会匹配子目录脚本）
find "$SKILL_DEST" -type f -name "*.sh" -exec chmod +x {} +
c_green "✓ skill 已安装: $SKILL_DEST ($(find "$SKILL_DEST" -type f | wc -l | tr -d ' ') 个文件)"

# --- 5. 安装 agents ---
mkdir -p "$AGENTS_DEST"
cp "$AGENTS_SRC"/*.md "$AGENTS_DEST/"
c_green "✓ 角色定义已安装: $AGENTS_DEST ($(ls "$AGENTS_SRC"/*.md | wc -l | tr -d ' ') 个角色)"

# --- 6. 依赖提示 ---
echo ""
c_green "▶ 可选依赖检查"
MISSING=()
command -v tmux >/dev/null 2>&1 || MISSING+=("tmux (L 级多窗口协作需要: brew install tmux)")
command -v jq >/dev/null 2>&1 || MISSING+=("jq (部分脚本解析 JSON 需要: brew install jq)")
command -v python3 >/dev/null 2>&1 || MISSING+=("python3 (build-prompt.py 需要)")

if [ ${#MISSING[@]} -eq 0 ]; then
  c_green "✓ 全部可选依赖已安装"
else
  c_yellow "⚠ 以下可选依赖缺失（不影响基础功能）:"
  for m in "${MISSING[@]}"; do echo "   · $m"; done
fi

# --- 7. 完成 ---
echo ""
c_green "✅ 安装完成！"
echo ""
cat <<EOF
下一步：
  1. 重启 Claude Code（或新开一个会话，让它重新扫描 agents 和 skills）
  2. 在项目中触发：输入 "启动团队开发" 或 "team mode" 或 /agent-teams
  3. 查看用法：~/.claude/skills/agent-teams/QUICKSTART.md

卸载：
  bash $SCRIPT_DIR/uninstall.sh

EOF
