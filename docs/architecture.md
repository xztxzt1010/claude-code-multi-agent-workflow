# 架构与设计决策

## 目标

工作流处理的是“同一个 Agent 同时提出、实现并评价方案”造成的自我确认偏差。设计选择是职责分离与结构化交接，而不是无限增加角色。

## 控制面与执行面

- 主 Agent 是控制面：解释用户意图、选择角色、维护任务状态、实施改动并向用户负责。
- 子 Agent 是审查面：在限定输入下给出单一职责判断，不直接扩大范围或替代主 Agent 修改代码。
- 测试和工具是证据面：独立验证角色结论与实现结果。
- 人是授权面：批准范围变化、外部发送、生产写入和不可逆操作。

## 动态路由

固定六角色流程会让简单任务付出不必要成本，也容易制造重复意见。因此默认使用三审查核心：

```text
premise -> assumption -> implementation -> range -> assumption(final)
```

路由器只在完成标准需要时加入：

- `test-designer`：正确性不能靠简单静态检查证明。
- `metric-gate`：出现性能、稳定性、准确率或质量提升声称。
- `rollback-planner`：变更涉及难恢复的数据、权限或生产环境。

## 状态机

| 状态 | 允许转移 | 阻断条件 |
|---|---|---|
| premise | assumption, stopped | 方向需重议或信息不足 |
| assumption | test, implementation, stopped | 未缓解的高风险假设 |
| test | implementation, stopped | 无可行验证路径 |
| implementation | validation | 实现失败或需要新授权 |
| validation | metric, rollback, range | 完成标准未满足 |
| metric | range, stopped | 证据不足时禁止质量声称 |
| rollback | range, stopped | 无可接受恢复路径 |
| range | final, implementation | 检测到越界改动 |
| final | done | 仍有未披露验证缺口 |

## 可观测性

最小 trace 只记录任务 ID、阶段、角色、spawn/simulated/skipped、结构化判定、证据引用、耗时和可获得的 Token 数据。它不记录隐藏推理、凭据或整段私人会话。
