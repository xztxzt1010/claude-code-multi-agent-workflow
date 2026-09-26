# 交接协议

角色之间不共享无限上下文，而使用最小交接信封：

```yaml
schema_version: "1.0"
task_id: export-empty-csv
stage: assumption
problem: 空数据导出返回 500
desired_outcome: 空数据返回只有表头的 CSV
out_of_scope:
  - 不改数据库
  - 不重构其他导出逻辑
done_when:
  - 有数据、空数据和非法筛选条件测试通过
artifacts:
  - src/export.ts
  - test/export.test.ts
evidence: []
open_risks: []
```

## 约束

- `task_id` 在一次任务中保持稳定。
- 角色只消费完成职责所需字段，不索取无关聊天历史。
- `evidence` 只能记录实际运行的命令和结果摘要。
- 无证据的推断进入 `open_risks`，不能写成已验证事实。
- 输出不符合角色固定格式时，主 Agent最多要求重试一次；再次失败则标记该角色失败并继续可安全执行的部分。
- 任何角色提出超出 `out_of_scope` 的操作，必须回到主 Agent 和用户重新授权。

## 统一角色状态

```text
spawn       真实子 Agent 返回合格输出
simulated   子 Agent 不可用，主 Agent明确模拟
skipped     风险路由判定无需出场
failed      已调用但输出无效或超时
blocked     缺少必要信息或权限，不能安全继续
```
