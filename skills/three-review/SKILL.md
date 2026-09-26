---
name: three-review
description: 对功能开发、行为修复、重构、架构、算法、性能及跨文件改动执行风险分级的多 Agent 审查。小型问答和单行文案修改不启用。
---

# Three-Review Workflow

目标是让改动方向正确、假设清楚、范围受控、结果可证。流程不是角色表演，也不要求六个角色固定全员出场。

## 1. 建立任务契约

从用户请求提取并展示：问题、期望结果、不要做、完成标准。只有会实质改变方案的关键要素缺失时才提一个简短问题，否则写出明确假设继续。

启动状态：

```text
Workflow: three-review
Stage: premise
Scope: 本轮只处理 <边界>
```

## 2. 风险路由

| 条件 | 必选角色 |
|---|---|
| 功能、行为修复、跨文件改动 | premise-overturner, assumption-challenger, range-creep-guardian |
| 算法、复杂业务、数据处理 | 上述角色 + test-designer |
| 性能、稳定性、质量声称 | 上述角色 + test-designer + metric-gate |
| 数据库、权限、生产部署、不可逆写入 | 上述相关角色 + rollback-planner |

简单解释、查找和单行文案修改直接处理，不启动本 Skill。

## 3. 编排顺序

1. `premise-overturner` 审查方向。
2. `assumption-challenger` 审查方案。
3. 按风险调用测试、指标或回滚角色。
4. 主 Agent 执行最小实现和独立验证；审查 Agent 不代替实现者。
5. `range-creep-guardian` 审查最终 diff。
6. `assumption-challenger` 对最终 diff 复审。
7. 主 Agent 汇总交付报告。

优先使用真实子 Agent。工具不可用时可以在主对话中逐个模拟，但必须标记 `[simulated role: <name>]`，不得声称为 spawn。

## 4. 停止条件

- `DO_NOT_BUILD_YET` 或 `RECONSIDER_DIRECTION`：停止实现，交给用户决定。
- `HIGH_RISK`：先补充风险缓解或验证，再实现。
- `RANGE_CREEP_DETECTED`：移出越界改动后再交付。
- 指标证据不足：保留事实结果，但不得宣称质量已经提升。
- 需要新的权限、生产写入、外部发送或不可逆操作：请求人工审批。

## 5. 交接信封

每个角色只能依赖明确提供的上下文，至少包含：

```yaml
task_id: stable-id
stage: premise|assumption|test|implementation|metric|rollback|range|final
problem: string
desired_outcome: string
out_of_scope: [string]
done_when: [string]
artifacts: [path-or-reference]
evidence: [command-and-result]
open_risks: [string]
```

不得传递隐藏推理、Token、凭据、本机权限配置或无关聊天历史。

## 6. 最终报告

```text
改了什么：<文件与行为>
验证了什么：<实际命令和结果>
没验证什么：<明确缺口>
剩余风险：<风险和下一步>
角色记录：<spawn / simulated / skipped，以及路由理由>
```
