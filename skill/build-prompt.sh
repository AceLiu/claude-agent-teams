#!/usr/bin/env bash
# 构建 Worker 的 prompt 文件
# 用法: build-prompt.sh <worker-role> <project-root> <task-file> [--auto-next]
# 输出: prompt 文件路径到 stdout
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORKER_ROLE="${1:?用法: build-prompt.sh <worker-role> <project-root> <task-file> [--auto-next]}"
PROJECT_ROOT="${2:?缺少 project-root 参数}"
TASK_FILE="${3:?缺少 task-file 参数}"
AUTO_NEXT="${4:-}"

# 防御性校验：WORKER_ROLE 只能是小写字母/数字/连字符，防止路径遍历与 mktemp 模板注入
if ! [[ "$WORKER_ROLE" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "[ERROR] 非法 worker-role: $WORKER_ROLE (仅允许小写字母/数字/连字符)" >&2
  exit 1
fi

AGENT_DEF="$HOME/.claude/agents/${WORKER_ROLE}.md"
BASE_DIR="$SCRIPT_DIR"

# 检查角色定义文件
if [ ! -f "$AGENT_DEF" ]; then
  echo "[ERROR] 角色定义文件不存在: $AGENT_DEF" >&2
  exit 1
fi

# 创建 prompt 文件
PROMPT_FILE=$(mktemp "/tmp/worker-prompt-${WORKER_ROLE}-$(date +%s)-XXXXXX")

# 角色定义
cat "$AGENT_DEF" >> "$PROMPT_FILE"
echo -e "\n\n---\n" >> "$PROMPT_FILE"

# 任务内容（防止路径遍历：过滤 ../ 和绝对路径）
if echo "$TASK_FILE" | grep -qE '(\.\./|^/)'; then
  echo "[ERROR] 非法 task 文件名: $TASK_FILE" >&2
  exit 1
fi
TASK_PATH="${PROJECT_ROOT}/.team/tasks/${TASK_FILE}.md"
if [ -f "$TASK_PATH" ]; then
  echo "## 你的任务" >> "$PROMPT_FILE"
  echo "" >> "$PROMPT_FILE"
  cat "$TASK_PATH" >> "$PROMPT_FILE"
  echo -e "\n" >> "$PROMPT_FILE"
fi

# 方案设计参考（v3.7.0: architecture.md → design.md）
DESIGN_PATH="${PROJECT_ROOT}/.team/design.md"
ARCH_PATH="${PROJECT_ROOT}/.team/architecture.md"
if [ -f "$DESIGN_PATH" ]; then
  echo "## 方案设计参考" >> "$PROMPT_FILE"
  echo "" >> "$PROMPT_FILE"
  cat "$DESIGN_PATH" >> "$PROMPT_FILE"
  echo -e "\n" >> "$PROMPT_FILE"
elif [ -f "$ARCH_PATH" ]; then
  # 兼容旧会话
  echo "## 架构参考" >> "$PROMPT_FILE"
  echo "" >> "$PROMPT_FILE"
  cat "$ARCH_PATH" >> "$PROMPT_FILE"
  echo -e "\n" >> "$PROMPT_FILE"
fi

# 设计规范（前端/设计师/测试/iOS/Android 角色需要）
if [[ "$WORKER_ROLE" == *"frontend"* ]] || [[ "$WORKER_ROLE" == *"designer"* ]] || \
   [[ "$WORKER_ROLE" == *"tester"* ]] || [[ "$WORKER_ROLE" == *"ios"* ]] || \
   [[ "$WORKER_ROLE" == *"android"* ]]; then
  DESIGN_SYSTEM="${PROJECT_ROOT}/.team/designs/design-system.md"
  if [ -f "$DESIGN_SYSTEM" ]; then
    echo "## 设计系统" >> "$PROMPT_FILE"
    echo "" >> "$PROMPT_FILE"
    cat "$DESIGN_SYSTEM" >> "$PROMPT_FILE"
    echo -e "\n" >> "$PROMPT_FILE"
  fi
fi

# === SDD 知识注入 (v3.0.0) ===
KNOWLEDGE_INJECTION=$(python3 "${SCRIPT_DIR}/build-prompt.py" "$PROJECT_ROOT" "$TASK_FILE" 2>/dev/null || true)
if [ -n "$KNOWLEDGE_INJECTION" ]; then
  echo "" >> "$PROMPT_FILE"
  echo "$KNOWLEDGE_INJECTION" >> "$PROMPT_FILE"
fi

# 工作规范
cat >> "$PROMPT_FILE" << RULES
## 工作规范

你是一个在协作模式下运行的 Worker Agent，请严格遵守以下规范：

1. **进度更新**：每完成一个子步骤，更新 \`.team/status/${WORKER_ROLE}.json\`：
   - 更新 JSON 中的 \`status\`（working/waiting/blocked/done）和 \`progress\` 字段
   - worker-sync.sh Hook 会自动更新 \`updated_at\` 时间戳

2. **重要进展汇报**：通过以下命令通知 Team Leader：
   \`\`\`bash
   bash ${BASE_DIR}/send-message.sh \\
     "${WORKER_ROLE}" team-leader progress "你的进展描述" "${PROJECT_ROOT}"
   \`\`\`

3. **任务完成**：完成全部工作后：
   - 将 status 设为 \`done\`，progress 设为 \`100\`
   - 发送 completion 消息：
   \`\`\`bash
   bash ${BASE_DIR}/send-message.sh \\
     "${WORKER_ROLE}" team-leader completion "任务完成摘要" "${PROJECT_ROOT}"
   \`\`\`

4. **用户直接干预回报**：如果用户直接在你的终端和你对话（而不是通过 Team Leader 转达），
   干预结束后必须发送 intervention 消息：
   \`\`\`bash
   bash ${BASE_DIR}/send-message.sh \\
     "${WORKER_ROLE}" team-leader intervention "用户干预内容和你的调整摘要" "${PROJECT_ROOT}"
   \`\`\`

5. **响应 Team Leader 消息**：Hook 会自动将 Team Leader 的消息传递给你，
   你会看到 \`[TEAM MESSAGE]\` 或 \`[URGENT MESSAGE]\` 标记。收到后必须优先响应并调整工作方向。

6. **跨角色协作**：如果需要其他 Worker 的配合，通过 send-message.sh 写入 board.md 或通知 Team Leader 转达。
RULES

# 如果是自动调度模式，追加提示
if [ "$AUTO_NEXT" = "--auto-next" ]; then
  cat >> "$PROMPT_FILE" << 'AUTO_HINT'

> 注意：完成本任务后，系统会自动为你分配下一个任务（如果有的话），你不需要手动做任何事。
AUTO_HINT
fi

# 输出 prompt 文件路径
echo "$PROMPT_FILE"
