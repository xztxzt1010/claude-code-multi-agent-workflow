# 最小示例

## 输入

```text
我现在的问题：导出接口在结果为空时抛出异常。
我希望得到的结果：空结果返回只有表头的 CSV。
这次不要做：不改数据库，不重构其他导出接口。
完成标准：自动测试覆盖正常数据、空数据、非法筛选条件。
```

## 期望路由

```text
premise-overturner -> assumption-challenger -> test-designer
-> implementation -> range-creep-guardian -> assumption-challenger(final)
```

`metric-gate` 与 `rollback-planner` 应跳过，因为任务没有性能声称，也不涉及难恢复的生产变更。

## 结构化片段

```text
verdict: PROCEED
reason: 这是可由局部错误处理和回归测试解决的明确行为缺陷。

risk: MEDIUM_RISK
risks:
- 空数组和 null 可能走不同分支 -> 统一规范化输入 -> 分别增加负例测试

verdict: IN_SCOPE
out_of_scope:
- none
```

示例只展示协议，不代表真实项目已通过测试。
