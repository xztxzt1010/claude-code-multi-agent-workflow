---
name: six-role-drill
description: 对指定现存对象做全程只读的六角色回归演练，验证角色发现、真实 spawn 或明确回退、固定输出键和停止条件。
---

# Six-Role Drill

这是配置回归测试，不是日常开发流程。用户必须提供现存文件或目录；对象不存在时停止，不自行创建。

## 规则

1. 记录对象运行前的路径、大小、修改时间和内容哈希。
2. 依次调用 `premise-overturner`、`assumption-challenger`、`test-designer`、`metric-gate`、`rollback-planner`、`range-creep-guardian`。
3. 每个角色必须给出其定义要求的固定首键和至少一条针对当前对象的实质内容。
4. 优先真实 spawn；失败时允许 `[simulated role: <name>]`。六个角色全部模拟时，机制回归不通过。
5. 演练不得写入、生成、删除对象，不运行会改变对象的生成脚本，不安装依赖。
6. 再次采集大小、修改时间和哈希；任一变化都判定失败。

## 成功条件

- 有 `Workflow: three-review` 状态栏。
- 六个角色各有 spawn 或 simulated 证据，以及固定输出键。
- 至少一个角色为真实 spawn。
- 工作对象前后大小、修改时间和哈希一致。
- 结尾包含以下自证块：

```text
### 六角色出场自证
<role> : <spawn|simulated> : <输出位置> : <实质条目摘要>
```

## 报告

明确列出：改了什么（应为无）、验证了什么、没验证什么、剩余风险。不得把格式通过等同于角色判断质量通过。
