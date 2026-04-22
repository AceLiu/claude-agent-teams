# 需求变更管理与 Phase 回溯协议

## 变更分类

| 类型 | 示例 | 影响范围 | 处理 |
|------|------|---------|------|
| **A: 文案/样式** | 按钮文字、颜色 | 单个 task | 直接改，不回退 |
| **B: 功能逻辑** | 新增字段、改校验 | 1-3 task | 改 task + 通知 Dev |
| **B+: UI 契约微调** | 新增/修改 data-testid、调整路由 | contracts.md UI 契约 + Tester | 就地改 contracts.md + 通知 Tester，不回退 |
| **B+: 接口兼容修补** | 增加 optional 参数、调整字段名 | contracts.md + 相关 Dev | 就地改 contracts.md + 通知 Dev/Tester，不回退 |
| **C: 接口 breaking change** | 删除 API、改 required、改响应结构 | contracts.md + Dev + Tester | 回退 Phase 2 |
| **D: 架构变更** | 方案调整、新增模块 | design.md + 全部 Dev | 回退 Phase 2 |

## 变更流程

1. Leader 判定类型（A/B/C/D），在 task 备注或 commit message 中记录原因和影响
2. 用户确认
3. 执行：
   - A/B：直接改 task，send-message.sh 通知 Dev
   - C/D：回退 Phase 2，更新 design.md/contracts.md，受影响 task 标 `invalidated`
4. metrics.json `rework_count` +1

## 变更冻结期

- Phase 5 进行中：禁止 C/D 类变更，仅 A/B/B+
- Phase 5 E2E 编写阶段：UI 契约（data-testid/路由表）允许 B+ 修改，API 接口契约冻结
- 必须 C/D → 终止测试，回退 Phase 2，需用户显式确认

## Phase 回溯协议

### 文档更新规则

- 版本号递增（v1.0 → v1.1），第 6 章变更记录
- **ID 追加不重编**：新增 ID 从当前最大编号续（G-003 后续 G-004），已有 ID 不删不改
- 废弃 ID 标注 `[废弃]` 但保留编号，防止引用断裂

### 受影响 task 处理

- 相关 in_progress task → `invalidated`，send-message.sh 通知 Dev 停止
- 无关 task → 继续
- 回溯后为变更部分生成新 task（新 TASK-xxx）

### 回溯触发表

| 发现阶段 | 问题类型 | 回溯到 | 更新文档 |
|---------|---------|--------|---------|
| Phase 3 | 需求遗漏 | Phase 1 | spec.md, testcases.md §1 |
| Phase 3 | 架构缺陷 | Phase 2 | design.md, contracts.md, testcases.md §2 |
| Phase 4 | 接口不可行 | Phase 2 | design.md §2, contracts.md |
| Phase 5 | 需求理解错误 | Phase 1 | spec.md, 全链路 |
| Phase 5 | 方案缺陷 | Phase 2 | design.md, 受影响 task 重派 |

### 回溯后验证

运行 `validate-spec.sh` 重新验证覆盖率。
