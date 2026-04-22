# Spec 模板索引

## 可用模板

| 模板名 | 文件 | 适用场景 | 触发关键词 |
|--------|------|---------|-----------|
| crud | crud.md | 标准增删改查功能 | 增删改查、CRUD、新增管理页面 |
| permission-fix | permission-fix.md | 权限漏洞/越权修复 | 权限修复、越权、角色限制 |
| report-query | report-query.md | 报表/统计查询 + 导出 | 报表、统计、查询导出 |

## 使用方式

Phase 1 PM Agent 自动匹配或 Leader 显式指定：

1. **自动匹配**：PM 根据需求描述关键词匹配模板
2. **显式指定**：用户在需求中提到模板名称（如"按 CRUD 模板来"）

匹配到模板后，PM 基于模板骨架填充具体内容，而非从零开始。

## 贡献新模板

1. 在 `templates/` 下创建 `{模板名}.md`
2. 在本文件中添加一行索引
3. 模板需包含：spec.md 骨架 + contracts.md 骨架 + testcases.md 骨架 + 追溯矩阵
