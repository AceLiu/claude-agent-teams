# Agent Teams 知识库体系

> v4.0.0 | 路径：`~/.claude/agent-kb/`
> 分两层：**系统知识库**（全局地图）+ **经验知识库**（踩坑沉淀）
> 与各项目 CLAUDE.md 配合：系统知识库提供"全局地图"，CLAUDE.md 提供"局部详情"

## 定位

| 存什么 | 存哪里 | 谁写 |
|--------|--------|------|
| 跨项目的系统架构、调用链路、依赖关系、全局规范 | `~/.claude/agent-kb/{系统名}/` | `/knowledge init` |
| 开发过程中沉淀的经验、踩坑、模式 | `~/.claude/agent-kb/{系统名}/insights/` | Phase 5.10 retro + `/knowledge learn` |
| Spec 模板（高频需求类型的预填骨架） | `~/.claude/agent-kb/{系统名}/templates/` | 手动维护 + retro 提炼 |
| 组件内部知识（接口、表结构、入口文件） | 各项目 `CLAUDE.md` | **不在此管理** |

## 目录结构

```
~/.claude/agent-kb/
├── {系统名}/                     # 按系统/产品线隔离
│   ├── .meta.json               # 元信息（扫描时间、统计）
│   ├── overview.md              # 系统全景（仓库结构、技术栈、业务流程、部署架构）
│   ├── call-chains.md           # 核心业务调用链路（端到端）
│   ├── dependencies.md          # 服务依赖关系（谁依赖谁、构建顺序）
│   ├── conventions.md           # 全局编码规范（跨项目统一）
│   ├── pitfalls.md              # 全局踩坑记录（架构级）
│   ├── glossary.md              # 业务术语表
│   ├── insights/                # 经验知识库
│   │   ├── _index.md            # 路由表（关键词 → 文件映射）
│   │   ├── platform/            # 跨项目通用经验
│   │   │   └── *.md
│   │   └── business/            # 特定业务域经验
│   │       └── *.md
│   └── templates/               # Spec 模板库
│       ├── _index.md            # 模板索引
│       └── *.md                 # 各模板文件
├── _global/                     # 全局经验（不属于特定系统）
│   └── insights/
│       ├── _index.md
│       ├── platform/
│       └── business/
└── README.md                    # 知识库使用说明
```

> **为什么用 `~/.claude/agent-kb/` 而非 `~/knowledge-base/`**：与 Agent Teams 的 Phase 5.10 retro 已有的写入路径对齐，且在 `~/.claude/` 下统一管理。

## 命令

```
/knowledge init                    # 首次初始化：扫描代码仓库，生成系统知识库
/knowledge status                  # 查看知识库状态（文件列表、统计、上次更新时间）
/knowledge update                  # 增量更新：基于 git log 检测变更，更新受影响的知识文件
/knowledge refresh [文件]          # 定向刷新：重新生成指定文件（chains/deps/conventions/pitfalls）
/knowledge learn                   # 经验沉淀：从当前对话/工作区提炼经验写入 insights/
/knowledge search "关键词"          # 搜索知识库
```

---

## 铁律

```
1. 只写跨组件的系统级知识，组件内部知识由各项目 CLAUDE.md 承载
2. 每条事实必须有代码路径或配置引用，无依据不得写入
3. 调用链路必须端到端（从入口到数据层），不写半截
4. 经验条目必须经用户确认后才写入（HARD GATE）
5. 不在流水线执行过程中自动触发 init/update（各 Phase 只读取，/learn 除外）
6. 不修改任何项目的 CLAUDE.md（但可创建：兜底规则）
7. CLAUDE.md 兜底创建：Phase 1 检查目标仓库，缺失时自动创建最小版本（技术栈+构建命令+项目结构）
```

---

## 系统知识库（6 个核心文件）

### overview.md — 系统全景

**回答**：这个系统是什么、有哪些仓库、用什么技术栈、核心业务怎么流转。

```markdown
# {系统名} — 系统全景

## 系统定位
（一段话：做什么、给谁用、当前状态）

## 子系统划分
| 子系统 | 简称 | 职责 | 核心流程 |
|--------|------|------|----------|

## 代码仓库结构
（目录树：顶层仓库 → 内部项目，标注每个项目属于哪个子系统）

## 技术栈
| 层面 | 技术 | 版本 |
|------|------|------|
| 前端 | Vue 3 + TypeScript + Vite | ... |
| 后端 | Spring Boot + Dubbo + MyBatis | ... |
| 数据库 | MySQL + Redis | ... |
| 构建 | Maven / pnpm | ... |

## 核心业务流程
（ASCII 流程图：端到端的主流程）

## 部署架构概要
（部署区域、环境列表、关键基础设施）

## 知识库目录
（指向其他文件的链接索引）
```

### call-chains.md — 核心调用链路

**回答**：这个功能的调用链路是什么？从 Controller 入口到最终数据库的完整路径。

```markdown
# 核心业务调用链路

## 编写规则
- 每条链路标注：入口(Controller/Job) → 中间服务(Dubbo/HTTP) → 数据层(DAO/表)
- 标注组件归属和文件路径
- 只收录高频变更的核心链路，不求全

---

## 1. {业务场景名}

```
[入口] {组件} {Controller}.{method}()
  → [Dubbo] {组件} {ServiceImpl}.{method}()
    → [DAO] {表名} INSERT/SELECT/UPDATE
```

涉及组件: ...
涉及仓库: ...
```

### dependencies.md — 服务依赖关系

**回答**：改了这个组件的接口，谁会受影响？构建顺序是什么？

```markdown
# 服务依赖关系

## Dubbo 接口依赖矩阵
| 接口 (api 模块) | 提供方 | 消费方 |
|----------------|--------|--------|

## Maven 依赖关系
| 组件 | 依赖 | 说明 |
|------|------|------|

## 构建顺序
1. api 模块 → 2. 核心 service → 3. 下游 service → 4. web/job
```

### conventions.md — 全局编码规范

**回答**：在这个系统里写代码，应该遵循什么约定？

```markdown
# 全局编码规范

## 后端
- 包命名：...
- 响应封装：统一使用 Result<T>
- 注入方式：@Resource（项目约定）
- JSON 库：统一用 xxx
- 异常处理：...

## 前端
- 组件命名：PascalCase
- API 封装：统一 axios 实例 + 拦截器
- 状态管理：Pinia
- 样式方案：...
```

### pitfalls.md — 全局踩坑记录

**回答**：这个系统有什么坑要避开？

```markdown
# 全局踩坑记录

## 架构级
- **{坑名}**：{描述} → **解法**：{怎么避免}

## 跨组件
- **{坑名}**：{描述} → **解法**：{怎么避免}

## 部署
- **{坑名}**：{描述} → **解法**：{怎么避免}
```

> 组件内部的坑放各项目 CLAUDE.md，不放这里。

### glossary.md — 术语表

**回答**：这个业务术语是什么意思？

```markdown
# 业务术语表

| 术语 | 英文 | 含义 | 上下文 |
|------|------|------|--------|
```

---

## 经验知识库（insights/）

### 收录标准

**收录**：
- 需要 >3 轮工具调用才解决的坑
- 被用户纠正的假设
- 用户解释的非显而易见的业务概念
- 跨模块的平台级模式
- 非显而易见的技术约束（如"某中间件版本极旧，不能用新 API"）

**排除**：
- 读代码就能知道的（各项目 CLAUDE.md 的职责）
- 单次需求的临时信息
- 已在顶层文件中记录的（conventions.md、pitfalls.md）
- 未经验证的推测
- 包含特定文件路径的内容（用角色描述替代，如 `{api模块}/`）

### 经验条目格式

```markdown
---
id: INS-{系统名}-{序号}
type: pitfall | pattern | convention
scope: global | {系统名}
keywords: [关键词列表]
source: {来源需求或对话}
created: YYYY-MM-DD
confidence: 0.8
---

## {标题}

**Why:** {原因/背景}

**How to apply:** {应用场景和方法}
```

### 路由表（_index.md）

```markdown
# 经验知识路由表

| 关键词 | 文件 | 类型 | 简述 |
|--------|------|------|------|
| 事务, 自调用 | platform/spring-transaction.md | pitfall | @Transactional 自调用不生效 |
| 权限, 越权 | business/permission-patterns.md | pattern | 权限校验的标准模式 |
```

### 置信度机制

| 事件 | 操作 |
|------|------|
| 经验被触发且有用 | confidence +0.1（上限 1.0） |
| 经验被触发但不相关 | confidence -0.2（下限 0.0） |
| confidence ≤ 0.3 | Phase 5.10 retro 建议用户删除 |
| 超过 6 个月未触发 | 标记 `[dormant]`，不再自动注入但保留 |

---

## Spec 模板库（templates/）

从 Phase 5.10 retro 和日常开发中提炼高频需求模式，预填 ID 追溯链 + 方案对比 + 测试用例。

### 模板索引（_index.md）

```markdown
# Spec 模板索引

| 模板名 | 文件 | 适用场景 | 预填内容 |
|--------|------|---------|---------|
| crud | crud.md | 增删改查 | 4 G-xxx + 4 API + 10 TC + 追溯矩阵 |
| permission-fix | permission-fix.md | 权限漏洞修复 | 3 方案对比 + 5 TC |
| report-query | report-query.md | 报表查询+导出 | 查询/导出方案对比 + 8 TC + 部署计划 |
```

### 使用方式

Phase 1 PM 产出 spec.md 时，Leader 检查是否有匹配模板：
1. 自动匹配：从需求描述中提取关键词，与模板索引匹配
2. 手动指定：用户说"用 crud 模板"
3. 匹配到 → PM prompt 中注入模板内容，PM 基于模板填空补充
4. 未匹配 → 从零写起

---

## 与 Agent Teams 各 Phase 的集成

### 读取（各 Phase 按需加载）

| Phase | 读什么 | 用途 |
|-------|--------|------|
| Phase 1 § 0 | overview.md, glossary.md, insights/_index.md | Leader 预加载：PM 理解业务上下文 + 匹配相关经验 |
| Phase 1 § 0 | templates/_index.md（知识库 + 内置） | Leader 匹配 Spec 模板 |
| Phase 1 § 0 | 目标仓库 CLAUDE.md 存在性检查 | 不存在 → Phase 1 结束后兜底创建 |
| Phase 2 架构 | call-chains.md, dependencies.md | Architect 了解调用链路和影响范围 |
| Phase 2 架构 | conventions.md, pitfalls.md | Architect 遵循规范、避坑、填充风险表 |
| Phase 3 拆任务 | dependencies.md | Leader 确定构建顺序和部署依赖 |
| Phase 4 § 4.0 | conventions.md, pitfalls.md, insights/, .claude/rules/ | Leader 注入 Executor prompt（见 phase-4 知识注入策略） |
| Phase 5.3 Spec 符合性 | conventions.md | Architect 检查规范一致性 |
| Phase 5.4 质量审查 | pitfalls.md, insights/（confidence ≥0.7） | Architect 针对已知坑点做定向检查 |

### 写入（Phase 5.9 /learn + 手动）

| 触发 | 写什么 | 写到哪 |
|------|--------|--------|
| Phase 5.9 /learn | 8 维度提炼：conventions / pitfalls / insights / glossary / overview 增量 | agent-kb/{系统名}/ 对应文件 |
| Phase 5.9 /learn | 特定目录编码约束 | 项目 `.claude/rules/{模块}.md` |
| `/knowledge learn` | 流水线外的探索性经验 | insights/ |
| `/knowledge init/update` | 系统知识（overview/chains/deps/conventions/pitfalls） | 顶层文件 |
| `/knowledge init --from-history` | 从历史 `.team/` 产出批量提炼 | 全部知识文件 |
| 手动维护 | Spec 模板 | templates/ |

> Phase 5.9 /learn 完整流程见 `phases/phase-5-learn.md`。

### 知识库不存在时的行为

各 Phase 读取知识库时，如果 `~/.claude/agent-kb/` 不存在或为空：

```
知识库目录 ~/.claude/agent-kb/ 不存在。
建议执行 /knowledge init 初始化系统知识库，可提升 Spec/Review 质量。
（不阻塞当前流程，继续执行）
```

> 知识库是**增强项**，不是**必需项**。没有知识库也能跑完整流程，只是 PM/Architect/Reviewer 少了上下文。

### 模板与知识库解耦

Spec 模板有两个存放位置，**互不依赖**：

| 位置 | 用途 | 何时可用 |
|------|------|---------|
| `{SKILL_DIR}/templates/` | Agent Teams 内置模板（CRUD/权限/报表） | **始终可用**，不依赖知识库 |
| `~/.claude/agent-kb/{系统名}/templates/` | 项目特定模板（从 retro 沉淀） | 需先 `/knowledge init` |

Phase 1 匹配顺序：先查知识库模板 → 再查内置模板 → 都没有则从零开始。

---

## 初始化流程（/knowledge init）

### 快速模式（v3.8.0 冷启动）

首次使用 Agent Teams 且知识库为空时，Leader 可触发快速初始化。**不需要用户提供额外信息**，直接从当前项目推断：

```
1. 扫描当前目录的项目标识文件：
   - package.json → 前端技术栈（React/Vue/Next.js + 依赖列表）
   - pom.xml / build.gradle → 后端技术栈（Spring Boot/Dubbo 版本）
   - README.md / CLAUDE.md → 项目描述、开发规范
   - .git/config → 仓库远程地址、仓库名

2. 自动生成初版知识文件（标注 [auto-generated]）：
   - overview.md: 从 README + 目录结构推断系统定位和技术栈
   - conventions.md: 从 .eslintrc / .prettierrc / editorconfig + 实际代码模式推断编码规范
   - 其他文件留空模板（call-chains.md / dependencies.md / pitfalls.md / glossary.md）

3. 提示用户：
   「已基于项目结构自动生成初版知识库，标注 [auto-generated]。
   建议在首次开发完成后执行 /knowledge update 补充调用链路和依赖关系。」
```

快速模式**不阻塞流程**，生成的文件可能不完整但比空知识库好。后续通过 `/knowledge update` 逐步完善。

### 完整模式（适用于多仓库系统）

#### Step 1：确定系统上下文

```
1. 读取项目 CLAUDE.md → 系统名称、代码仓库路径
2. 如果信息不足 → 向用户询问：
   - 系统名称（用于创建子目录）
   - 代码仓库根路径（可多个）
   - 前端/后端技术栈
3. 创建 ~/.claude/agent-kb/{系统名}/ 目录结构
```

### Step 2：扫描仓库

```
1. 扫描代码仓库根路径，识别 Git 仓库（含 .git）
2. 每个仓库内识别项目（pom.xml / package.json）
3. 展示发现结果，请用户确认范围
```

**HARD-GATE：用户确认扫描范围。**

### Step 3：生成知识文件

使用 Explore subagent 并行扫描各仓库：

| 文件 | 生成方式 |
|------|---------|
| overview.md | 从 README、pom.xml、package.json、目录结构推断 → 用户确认 |
| call-chains.md | 从 Controller/Job 入口追踪 Dubbo/HTTP 调用到 DAO → 用户确认要追踪哪些链路 |
| dependencies.md | 从 pom.xml + @DubboReference/@Reference 扫描 → 生成依赖矩阵 |
| conventions.md | 从实际代码模式推断（命名、分层、异常处理、响应封装） |
| pitfalls.md | 从代码中识别风险模式（版本冲突、双仓库、配置散落） |
| glossary.md | 从代码注释和 README 提取业务术语 |

### Step 4：写入元信息

```json
{
  "systemName": "xxx",
  "lastScanTime": "2026-03-25T12:00:00",
  "repoRoots": ["/Users/ace/code/xxx"],
  "techStack": { "frontend": "Vue 3 + TS", "backend": "Spring Boot + Dubbo" },
  "files": {
    "overview.md": "2026-03-25T12:00:00",
    "call-chains.md": "2026-03-25T12:00:00"
  },
  "stats": {
    "chainCount": 8,
    "conventionCount": 12,
    "pitfallCount": 15,
    "insightCount": 0,
    "templateCount": 0
  }
}
```

---

## 增量更新（/knowledge update）

```
1. 读取 .meta.json → 上次扫描时间
2. 对每个仓库执行 git log --oneline --since={上次时间}
3. 分析变更内容：
   - 新增 Dubbo 接口 → 更新 dependencies.md
   - 新增 Controller/Job → 提示用户是否补充 call-chains.md
   - pom.xml/package.json 变更 → 更新 dependencies.md
   - 配置文件变更 → 检查是否影响 pitfalls.md
4. 更新受影响的文件
5. 更新 .meta.json 时间戳
6. 展示变化摘要
```

---

## 经验沉淀（/knowledge learn）

适用场景：
- 流水线外的探索性工作中发现了值得记录的经验
- 用户在对话中解释了重要的业务概念
- 开发/调试过程中踩了坑

流程：
1. 扫描当前对话上下文 + `.team/` 下的产出物（如果存在）
2. 提炼候选经验条目，评估是否值得沉淀
3. 展示候选列表，用户确认（**HARD GATE**）
4. 通用化检查（不含具体仓库路径、临时信息）
5. 写入 insights/（新建或追加），更新 _index.md 路由表

---

## 知识库架构概览

| 维度 | 说明 |
|------|------|
| 路径 | `~/.claude/agent-kb/{系统名}/` |
| 多系统支持 | 按系统名隔离子目录 |
| 知识文件 | 6 个核心文件（overview/call-chains/dependencies/conventions/pitfalls/glossary） |
| 经验库 | insights/ + 置信度机制 + 路由表 |
| Spec 模板 | `{SKILL_DIR}/templates/`（CRUD/权限修复/报表查询） |
| 写入方式 | Phase 5.10 retro + `/knowledge learn` |
| 读取集成 | 各 Phase 按需加载（PM 读 overview、Architect 读 chains/deps/conventions、Reviewer 读 pitfalls/insights） |
| 不存在时 | 提示但不阻塞 |

---

## 危险信号

**绝不要：**
- 写组件内部知识（接口列表、表结构、入口文件）— 那是各项目 CLAUDE.md 的职责
- 在没有源码证据的情况下写入"推测"
- 调用链路只写一半（必须端到端）
- 修改任何项目的 CLAUDE.md
- 在流水线执行中自动触发 init/update
- 经验条目未经用户确认就写入

**始终要：**
- 每条事实附带代码路径引用
- 调用链路标注每个环节的组件归属和文件路径
- 经验条目经用户确认后写入
- 标注空白（"未追踪"比编造好）
- 向用户确认核心链路的选择，不自行猜测
