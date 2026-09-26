# 评测方法

## 问题

多 Agent 是否比单 Agent 更能发现关键缺陷，以及增加的时间和 Token 是否值得？

## 三组对照

1. `single`：单 Agent 直接计划、实现、验证。
2. `three-review`：前提、假设、范围三个核心角色。
3. `risk-routed`：核心角色加按风险选择的测试、指标或回滚角色。

三组使用同一模型版本、工具权限、仓库快照和任务输入。每个 case 至少重复 3 次；无法固定随机性的环境要在报告中说明。

## 指标

| 指标 | 固定口径 |
|---|---|
| 关键缺陷召回率 | 被指出的 gold 缺陷数 / gold 缺陷总数 |
| 误报率 | 无法映射到 gold 或真实失败路径的缺陷数 / 全部缺陷报告数 |
| 范围遵守率 | 未产生越界行为的运行次数 / 总运行次数 |
| 完成标准满足率 | 全部 `done_when` 有独立证据的运行次数 / 总运行次数 |
| 平均耗时 | 从首个任务输入到最终报告的墙钟秒数平均值 |
| Token 成本 | 平台可观测的输入与输出 Token 总和；不可获得时记 `null` |

## 记录格式

每次运行保存到 `evals/results/<date>-<mode>.json`，至少包含：

```json
{
  "environment": {"model": "", "claudeCodeVersion": ""},
  "mode": "single|three-review|risk-routed",
  "runs": [{"caseId": "E01", "repeat": 1, "durationSeconds": 0, "tokens": null}],
  "summary": {"criticalRecall": 0, "falsePositiveRate": 0, "scopeCompliance": 0}
}
```

结果文件默认被 `.gitignore` 排除，只有脱敏、复核并明确选择公开的汇总结果才应强制加入 Git。

## 防止评测污染

- 不向被测 Agent 提供 gold 缺陷。
- Grader 在回答完成后评分。
- 同一 case 的三组对照使用相同起点。
- 不因某组失败而临时修改任务文本。
- 先冻结 `evals/cases.json`，再运行正式对照。
