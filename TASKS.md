# 项目任务

## 已完成基线

- [x] AGENT-001：整理六个单一职责角色和两个 Skill
- [x] AGENT-002：隔离公开配置与本机私有权限文件
- [x] AGENT-003：建立仓库结构、交接协议、状态机与停止条件
- [x] AGENT-004：冻结 20 个固定评测任务与三组对照方法
- [x] AGENT-005：增加零依赖静态校验与基础 CI

## v0.2.0 Experimental · 公开前 P0

- [ ] GATE-00：核验 `main@970ffb6`、GitHub 身份、Private 状态并创建候选分支
- [ ] GATE-01：为 PowerShell/Bash 安装器增加所有权清单、全量预检与哈希保护
- [ ] GATE-02：覆盖六种破坏性边界并在 Windows/Ubuntu CI 通过
- [ ] GATE-03：README 先展示真实六角色实现，准确说明实验状态与安装边界
- [ ] GATE-04A：六角色只读回归通过，至少一个角色真实 spawn
- [ ] GATE-04B：E01/E04/E08/E11/E14 三模式 smoke 可复现、已脱敏
- [ ] GATE-05A：候选分支与 PR 建立，CI 全绿
- [ ] GATE-05B：Windows/Linux 空克隆复验、敏感信息/许可证/链接检查通过
- [ ] GATE-05C：Mimo 提交候选报告并停止等待三项所有者批准
- [ ] GATE-06：经单独批准后再处理合并、Public、Release 与安全配置

## v1.0.0 · 效果证据门槛

- [ ] EVAL-101：完成 20 case × 3 模式 × 每模式至少 3 次重复
- [ ] EVAL-102：公开脱敏方法、样本量、失败 case、质量/成本指标与限制
- [ ] EVAL-103：只有数据支持时才发布提升结论，并同时说明耗时与 Token 成本
- [ ] EVAL-104：验证失败重试、预算上限和人工审批节点

## 后续增强

- [ ] AGENT-101：根据真实结果调整动态路由规则
- [ ] AGENT-102：为角色输出增加可机读 JSON Schema 与 grader
- [ ] AGENT-103：做模型与 Prompt 版本对照实验
