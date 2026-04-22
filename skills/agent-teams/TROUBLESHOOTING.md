# Agent Teams 故障排除指南

> 遇到问题时先查本文档，再上报用户。

## 1. Executor ESCALATE

### 决策树

```
Executor 返回 ESCALATE
  │
  ├─ Leader 自动派 Debugger（L 级强制，M 级推荐）
  │
  └─ Debugger 诊断返回 4 选 1:
      │
      ├─ a) 补充 context
      │   → Leader 补充缺失信息（spec/contracts/知识库片段）
      │   → 重派同 Executor，prompt 中加入补充内容
      │   → 示例: "缺少 API-003 的认证方式 → 从 contracts.md 提取认证章节注入"
      │
      ├─ b) 升级 model
      │   → sonnet 不够 → 重派为 opus
      │   → 适用场景: 跨模块逻辑判断、复杂状态机、并发安全
      │   → 注意: 仅升级失败的 task，其他 task 保持 sonnet
      │
      ├─ c) 拆分 task
      │   → 原 task 过大或含隐性依赖
      │   → Leader 拆为 2-3 个子 task（task-{NNN}a, task-{NNN}b）
      │   → 子 task 保留原 task 的 AC 关联
      │   → 重新检查依赖关系后分批派发
      │
      └─ d) 上报用户
          → 技术上无法自动解决（外部依赖、权限、业务决策）
          → 使用 Escalation Report 模板（handoff-templates.md §4）
          → 必须附: 诊断摘要 + 已尝试方案 + 3 个建议选项
```

### 重试上限

- 每个 task 最多 3 轮 ESCALATE→Debugger 循环
- 超过 3 轮 → 强制上报用户，附完整诊断历史
- 不同 task 的重试计数独立

### 常见 ESCALATE 原因及处理

| 原因 | 频率 | 处理 |
|------|------|------|
| 缺少接口定义 | 高 | 补 context: 从 contracts.md 提取 |
| 跨模块依赖不清 | 高 | 补 context: 从 design.md 提取调用链 |
| 实现复杂度超预期 | 中 | 升级 model 或拆分 task |
| 测试环境问题 | 中 | 上报用户（需人工介入） |
| 第三方 API 不可用 | 低 | 上报用户 + 建议 mock 方案 |

---

## 2. 批量审查 NEEDS_FIX

### 处理流程

```
Architect 批量审查返回 NEEDS_FIX
  │
  ├─ 1. Architect 按 task 分组问题清单
  │     格式: TASK-001: [问题1, 问题2]
  │            TASK-003: [问题3]
  │
  ├─ 2. Leader 定向重派
  │     → 只重派有问题的 Executor（不重派已 PASS 的）
  │     → prompt 中注入: 原 task + Architect 的修复指令
  │     → 修复指令必须具体到文件和行为（不接受"优化一下"）
  │
  ├─ 3. Executor 修复后重新提交
  │     → 状态仍为 PASS/NEEDS_CONTEXT/ESCALATE
  │     → 报告中标注"修复轮次: 第 N 轮"
  │
  └─ 4. Architect 重新批量审查
        → 仅审查修复的 task（不重复审查已通过的）
        → 最多 3 轮，超过上报用户
```

### 常见 NEEDS_FIX 问题

| 问题类型 | 修复指令示例 |
|---------|------------|
| 接口不匹配 | "API-001 响应缺少 `avatar` 字段，在 src/api/users.ts 第 42 行的返回对象中添加" |
| 错误码未处理 | "contracts.md 定义了 409 冲突错误，在 createUser handler 中添加唯一性检查" |
| 命名不一致 | "task-001 用 `userId`，task-003 用 `user_id`，统一为 `userId`（参考 contracts.md）" |
| 缺少边界检查 | "AC-003 要求处理空列表，在 src/services/list.ts getItems() 添加 length === 0 分支" |

---

## 3. Phase 中途问题

### 3.1 需要升级级别

```
发现复杂度超预期（如 M 级发现需要跨模块）
  │
  ├─ Phase 1-2 阶段发现:
  │   → 直接升级（改 .team/.grade 文件）
  │   → 补充 L 级必需文档（design.md, traceability.md）
  │   → 重新执行 validate-all.sh 确认文档齐全
  │
  ├─ Phase 3 阶段发现:
  │   → 升级级别
  │   → 已拆好的 task 保留，补充新 task
  │   → 补派 Critic（L 级必需）
  │
  └─ Phase 4 阶段发现:
      → 暂停开发
      → 回退到 Phase 2/3 补充设计
      → 见 change-protocol.md B+ 类变更流程
```

### 3.2 需要降级级别

```
发现实际比预期简单（如 L 级实际只需 3 个 task）
  │
  → 不建议中途降级（已产出的文档不浪费）
  → 可选: 跳过 Critic 终审（仅 Architect 审查即可）
  → 可选: retro 改为可选
```

### 3.3 需求变更

参考 `phases/change-protocol.md`，按变更类型处理：

| 类型 | 定义 | 处理 |
|------|------|------|
| A 类 | 文案/样式微调 | 直接修改，不回退 Phase |
| B 类 | 新增/修改 AC（≤3 条） | 更新 spec + testcases，不回退 |
| B+ 类 | 新增/修改 AC（>3 条）或接口变更 | 回退到 Phase 2 重新设计 |
| C 类 | 架构变更 | 回退到 Phase 1 重新分析 |
| D 类 | 需求推翻 | 关闭当前，重新开始 |

---

## 4. Worker/tmux 问题（L 级协作模式）

### Worker 无响应

```bash
# 1. 检查 Worker 健康
bash health-check.sh {project_root}

# 2. 查看 Worker 状态
bash team-status.sh {project_root}

# 3. 手动连接 tmux 检查
tmux attach -t agent-teams-{role}

# 4. 重启 Worker（最后手段）
bash shutdown-team.sh {project_root}
bash launch-worker.sh {project_root} {role} {task}
```

### 状态文件异常

```bash
# 检查状态文件是否为有效 JSON
cat .team/status/{role}.json | python3 -m json.tool

# 状态不一致时，手动重置
echo '{"status":"idle","task":"","updated":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > .team/status/{role}.json
```

### 消息堆积

消息用 `read: false/true` 标记已读，文件不会自动删除。堆积多了手动归档：

```bash
# 统计各 Worker 的 inbox 文件数
find .team/messages/inbox -name '*.md' | wc -l

# 归档已读消息（read: true）
mkdir -p .team/messages/archive
find .team/messages/{inbox,outbox} -name '*.md' \
  -exec grep -l '^read: true' {} \; \
  | xargs -I{} mv {} .team/messages/archive/
```

---

## 5. 验证脚本失败

### validate-spec.sh 常见失败

| 错误 | 原因 | 修复 |
|------|------|------|
| "G-xxx 跳号" | ID 编号不连续 | 按顺序重编号（G-001, G-002, ...） |
| "G→AC 覆盖率 低于 70%" | 部分 G 无对应 AC | 查看输出中列出的缺失 G-xxx，补充 AC |
| "孤立 AC: AC-xxx" | AC 未关联 G/NFR | 在 testcases.md §1 表格中补充关联 |
| "DEC 自审核未勾选" | Architect 未完成审核 | 在 design.md 中勾选所有 [ ] 项 |
| "traceability.md 不存在" | L 级缺必需文件 | 执行 Phase 2 或手动创建 |

### validate-testcases.sh 常见失败

| 错误 | 原因 | 修复 |
|------|------|------|
| "列数不足" | TC 行少于 10 个字段 | 补全缺失列（用 `-` 占位） |
| "P 分布偏离" | 优先级分配不均 | 参考目标比例调整 TC 优先级 |
| "反向用例占比偏低" | 缺少异常测试 | 用 5 维拆解法补充边界/异常用例 |
| "未关联 AC" | TC 缺少 AC 引用 | 在 TC 表格第 2 列补充 AC-xxx |

### validate-contracts.sh 常见失败

| 错误 | 原因 | 修复 |
|------|------|------|
| "未找到路由定义" | 源码中无匹配路由 | 确认路径拼写，或创建路由处理函数 |
| "必填字段未找到" | 字段名可能不同 | 检查序列化别名（如 camelCase vs snake_case） |
| "错误码未找到" | 可能用统一中间件 | 用 --strict 模式确认，或标记为已知差异 |

---

## 6. 上下文管理

### 何时 /compact

| 时机 | 操作 | 保留 | 丢弃 |
|------|------|------|------|
| Phase 3 完成 | `/compact` | spec/design 摘要、task 列表 | Phase 1-3 详细文档内容 |
| Phase 4 完成 | `/compact` | 批量审查结果、测试状态 | Executor prompt 构建内容 |
| 批量审查 3 轮后 | `/compact` | 最新审查结果 | 前几轮审查细节 |

### 上下文爆炸预防

- Leader 不要 Read 大文件（>200 行）全文，用 Grep 提取关键段
- Executor 报告控制在 ~1K token（表格格式，不含源码）
- 批量审查时 Architect 只看 diff，不看全文件
