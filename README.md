# Claude Code 多子 Agent 工作流

一套可安装、可审计、可回退的 Claude Code 多 Agent 审查工作流。它不让所有 Agent 无条件出场，而是按任务风险选择角色，用结构化交接减少方向错误、隐性假设和范围失控。

## 为什么做这个项目

单 Agent 很容易在同一条思路里同时完成“提出方案、实现、证明自己正确”。本项目把互相冲突的职责拆开：

| 角色 | 负责回答 | 典型时机 |
|---|---|---|
| `premise-overturner` | 方向值得做吗，有没有更小路线？ | 实现前 |
| `assumption-challenger` | 方案默认了哪些“应该没问题”？ | 实现前、最终复审 |
| `test-designer` | 用什么最小证据证明做对了？ | 复杂任务实现前 |
| `metric-gate` | “更好”是否有基线和数据？ | 性能/质量任务验证后 |
| `rollback-planner` | 改坏后怎样恢复？ | 高风险变更前 |
| `range-creep-guardian` | 最终改动是否超出需求？ | 实现后 |

## 工作流

```text
需求四要素
   │
   ├─ 前提审查 ── stop / 缩小方案 / 继续
   │
   ├─ 假设审查 ── 风险、缓解、验证
   │
   ├─ [按风险选择] 测试设计 / 指标守门 / 回滚规划
   │
   ├─ 实现与独立验证
   │
   └─ 范围审查 + 最终假设复审 + 交付报告
```

默认的三审查模式只启用前提、假设和范围角色。算法、性能和高风险变更才增加其他角色，避免为了“多 Agent”而增加无意义的耗时和 Token。

## 应用案例：机器视觉项目概念扩展

![Claude Code 多 Agent 机器视觉决策流程](./assets/vision-multi-agent-workflow.png)

这张图展示本方法在机器视觉项目中的领域化设计：从需求澄清、采集与标注，到数据诊断、预处理、最小实验、三审三查和复盘沉淀。

> 这是概念扩展示例，不是当前安装包清单。本仓库当前可安装的是上方六角色通用审查框架；图中的 `vision-requirement-agent` 等领域 Agent 尚未发布。

## 仓库结构

```text
agents/                  六个 Claude Code 子 Agent 定义
skills/three-review/     日常三审查编排 Skill
skills/six-role-drill/   六角色只读回归演练 Skill
docs/                    架构、交接协议、安全和评测方法
examples/                最小任务输入与示例输出
evals/cases.json         20 个固定评测任务
scripts/                 安装、卸载和静态校验脚本
```

## 快速开始

要求：已安装 Claude Code。安装器使用带 SHA-256 的所有权清单（`.claude-multi-agent-workflow/manifest.tsv`）：

- **必须显式指定目标根**：PowerShell 需 `-TargetRoot`，Bash 需 `TARGET_ROOT`。缺失时安装/卸载在任何写入前非零退出，**没有**默认写入 `~/.claude` 的行为。
- **冲突保护**：目标已存在但清单无所有权证明时，安装失败且零写入。
- **修改保护**：已安装文件被改动后，卸载失败且零删除；需手动处理冲突后重试。
- **清单路径校验**：安装/卸载拒绝缺失、额外、重复、空白、格式错误、绝对路径、盘符、`.`/`..` 或任何目标根逃逸路径；校验通过前零写入、零删除。
- **幂等**：未改动的已安装文件可安全重装/升级。
- **卸载**：只删除清单证明归属本项目且哈希未变的文件；无关文件保留，目录仅在为空时删除。

请先向临时目录安装验证，确认无误后再用于真实 `~/.claude`：

Windows PowerShell：

```powershell
./scripts/install.ps1 -TargetRoot "$env:TEMP\claude-workflow-test"
./scripts/uninstall.ps1 -TargetRoot "$env:TEMP\claude-workflow-test"
```

macOS / Linux：

```bash
TARGET_ROOT="$(mktemp -d)" bash ./scripts/install.sh
TARGET_ROOT="$TARGET_ROOT" bash ./scripts/uninstall.sh
```

安装后在 Claude Code 中输入：

```text
/three-review

我现在的问题：导出接口在空数据时返回 500。
我希望得到的结果：空数据时返回只有表头的 CSV。
这次不要做：不改数据库，不重构其他导出逻辑。
完成标准：自动测试覆盖有数据、空数据和非法筛选条件。
```

若卸载因“文件已被修改”失败，请先比对差异；确认要丢弃改动时手动删除对应文件与清单，或恢复文件哈希后重试。不要手工删除他人文件。

隔离安装回归（不触碰真实 `~/.claude`）：

```bash
npm run test:install:ps   # Windows
npm run test:install:sh   # Linux/macOS
```

## 验证

静态验证用于检查仓库结构、Agent frontmatter、固定输出键、评测集数量和敏感信息模式：

```bash
npm test
```

主行为评测由 Mimo 按 [`MIMO.md`](./MIMO.md) 执行。仓库当前不会把“文件存在”冒充成“多 Agent 质量已提升”；真实对照结果应写入 `evals/results/` 后再更新本 README。

## 设计边界

- Agent 输出是审查意见，不是事实来源；仍需测试或人工审批。
- 网页、文档、终端输出均按不可信数据处理。
- 默认最小权限；推送、删除、生产变更和外部发送保留人工确认。
- Trace 只保留任务输入、角色判定和可公开证据，不保存隐藏推理、凭据或本机绝对路径。
- 不保证所有 Claude Code 版本、模型或兼容端点都支持子 Agent；失败时允许清晰标记的主 Agent 模拟，但不能伪装成真实 spawn。

## 状态

当前版本：`v0.2.0 Experimental`。已验证六角色/Skill 结构、所有权安装与零损害卸载（Windows/Linux 隔离测试）。真实 spawn 与 5-case smoke 为实验可运行证据；本仓库**不声称多 Agent 提升质量**。完整 20-case 三组重复评测是 `v1.0.0` 门槛。

## License

[MIT](./LICENSE)
