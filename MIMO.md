# Mimo 主测试任务书

Mimo 负责本项目的主要行为验收和三组对照评测。开始前按顺序阅读 `README.md`、`CLAUDE.md`、`docs/evaluation.md`、`TASKS.md` 和本文件；只在本仓库内修改。

## 测试前边界

- 不复制用户完整 `.claude` 目录，不读取或提交 `settings.local.json`。
- 不提交凭据、私人转录、隐藏推理、本机绝对路径或未经脱敏的 trace。
- 不把静态校验通过写成“多 Agent 效果提升”。
- 不改 `evals/cases.json` 后再对同一轮结果打分；发现 case 问题时单独记录，下一版再修订。
- GitHub 登录只使用系统凭据；不得向用户索要 Token 文本。

## MIMO-001 · 仓库静态基线

运行并记录退出码与摘要：

```powershell
npm test
git diff --check
```

确认六个 Agent、两个 Skill、20 个评测 case 均被校验到。

## MIMO-002 · 隔离安装/卸载

必须用临时目录，不能直接覆盖用户真实 `.claude`：

```powershell
$sandbox = Join-Path $env:TEMP 'claude-multi-agent-install-test'
New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
./scripts/install.ps1 -TargetRoot $sandbox
Get-ChildItem -Recurse $sandbox
./scripts/uninstall.ps1 -TargetRoot $sandbox
Get-ChildItem -Recurse $sandbox
```

验收：安装后恰有六个 Agent 文件与两个 Skill；卸载后这些目标消失，预先放入的无关文件仍存在。测试结束后可删除该明确临时目录。

## MIMO-003 · 六角色机制回归

在 Claude Code 中以 `examples/minimal-task.md` 为只读对象执行 `/six-role-drill`。

验收：

- 六个角色各有固定输出键和实质内容。
- 至少一个角色是真实 spawn；如果六个全部 simulated，本项失败。
- 对象前后大小、修改时间和哈希不变。
- 结尾有“六角色出场自证”。

记录 Claude Code 版本、模型、端点类型、各角色 spawn/simulated/failed，不记录隐藏推理。

## MIMO-004 · 20-case 三组对照

按 `docs/evaluation.md` 运行：`single`、`three-review`、`risk-routed`。每个 case 每组至少重复 3 次，起点、模型和权限一致。

先对 E01、E04、E08、E11、E14 做 5-case smoke test；路由或记录格式不合格时先停止正式评测。Smoke 通过后再跑全部 20 case。

结果至少记录：关键缺陷召回率、误报率、范围遵守率、完成标准满足率、墙钟耗时；Token 无法获得时写 `null`，不得估算。

## MIMO-005 · 结果回填

1. 把原始结果放在 `evals/results/`，先脱敏再决定哪些文件公开。
2. 新建 `docs/evaluation-report.md`，写环境、日期、方法、样本量、失败 case 和三组汇总。
3. 只有数据支持时才在 README 写提升结论，同时说明成本。
4. 更新 `TASKS.md` 与 `VERSION.md`，附实际命令和结果。

## 失败停止条件

- 安装/卸载触碰测试根目录以外的文件。
- 发现 Token、私人路径或未脱敏 trace。
- 六角色全部 simulated。
- 三组对照的模型、权限或任务输入不一致。
- 无法确认测试从同一仓库快照开始。

触发任一条件时停止正式评测，保留已获得的非敏感诊断并如实报告。
