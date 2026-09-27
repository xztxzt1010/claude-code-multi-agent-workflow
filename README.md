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

要求：已安装 Claude Code。当前安装器安全加固正在按 [`MIMO.md`](./MIMO.md) 验收；在候选通过前，请只向显式临时目录安装，不要直接写入真实 `~/.claude`。

Windows PowerShell：

```powershell
./scripts/install.ps1
```

macOS / Linux：

```bash
bash ./scripts/install.sh
```

安装后在 Claude Code 中输入：

```text
/three-review

我现在的问题：导出接口在空数据时返回 500。
我希望得到的结果：空数据时返回只有表头的 CSV。
这次不要做：不改数据库，不重构其他导出逻辑。
完成标准：自动测试覆盖有数据、空数据和非法筛选条件。
```

候选安装器将使用带 SHA-256 的所有权清单：遇到无所有权的同名文件时安装应拒绝且零写入；已安装文件被用户修改后，卸载应拒绝且零删除。当前脚本完成该验收前不建议用于真实用户目录。

卸载入口：

```powershell
./scripts/uninstall.ps1
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

当前版本：`v0.2.0 Experimental`（私有候选整理中）。结构和静态规则已整理；安装安全、真实 spawn 与 5-case smoke 尚待 Mimo 验收，因此暂不公开，也不发布质量提升百分比。完整 20-case 三组重复评测是 `v1.0.0` 门槛。

## License

[MIT](./LICENSE)
