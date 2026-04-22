#!/usr/bin/env bash
# Agent Teams - Uninstaller
# 从 ~/.claude/ 删除 agent-teams skill 和 15 个角色定义

set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
SKILL_DEST="$CLAUDE_HOME/skills/agent-teams"
AGENTS_DEST="$CLAUDE_HOME/agents"

AGENT_ROLES=(
  ai-assistant android-dev architect backend-dev critic
  debugger designer documentation-writer evidence-collector
  frontend-dev ios-dev product-manager reality-checker
  reviewer task-executor
)

c_green() { printf '\033[32m%s\033[0m\n' "$*"; }
c_yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

# --- 1. 删除 skill ---
if [ -d "$SKILL_DEST" ]; then
  rm -rf "$SKILL_DEST"
  c_green "✓ 已删除 $SKILL_DEST"
else
  c_yellow "· skill 目录不存在，跳过: $SKILL_DEST"
fi

# --- 2. 删除 agents ---
REMOVED=0
for role in "${AGENT_ROLES[@]}"; do
  f="$AGENTS_DEST/$role.md"
  if [ -f "$f" ]; then
    rm "$f"
    REMOVED=$((REMOVED + 1))
  fi
done
c_green "✓ 已删除 $REMOVED 个角色定义"

# --- 3. 状态目录提示（不自动删，保留用户数据） ---
echo ""
c_yellow "⚠ 以下状态目录未删除（包含你的工作记录）:"
[ -d "$CLAUDE_HOME/agent-kb" ] && echo "  · $CLAUDE_HOME/agent-kb/    (知识库)"
[ -d "$CLAUDE_HOME/metrics" ] && echo "  · $CLAUDE_HOME/metrics/     (团队指标)"
echo ""
echo "如需彻底清理，手动执行:"
echo "  rm -rf $CLAUDE_HOME/agent-kb $CLAUDE_HOME/metrics"
echo ""
c_green "✅ 卸载完成"
