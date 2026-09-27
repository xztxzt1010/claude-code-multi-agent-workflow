# 版本记录

## 2026-09-27 · GATE-05R R3 Claude Code runtime smoke（完成，停止待批）

- **runtime=Claude Code 2.1.281**（非 Mimo Desktop Actor）。`claude auth status`：loggedIn=true，authMethod=oauth_token，apiProvider=firstParty。候选 SHA=`a978df3`。
- 隔离：系统临时目录空克隆 → `install.ps1 -TargetRoot <clone>\\.claude`；未设置 `CLAUDE_CONFIG_DIR`；未读取/修改真实 `~/.claude`；`--strict-mcp-config`、`--no-session-persistence`；只读工具 Read/Glob/Grep/Task。
- 探针：`claude -p "Reply with exactly: PROBE_OK_20260927"` 退出 0。注：`--setting-sources project` 会导致 OAuth 不可用（凭据在 user 源），改用 `user,project`；已在结果文件记录偏差。
- 六角色：固定首键 `verdict/risk/test_plan/metrics/rollback_steps` 齐全；**Task 真实 spawn 机制验证 2 次**（子 Agent finished）；`-p` 模式长提示词传递受限，角色正文主要来自同一 Claude Code 会话内 sequential 模拟（skill 允许）。状态已逐个记录 spawn/simulated。
- 对象完整性：`examples/minimal-task.md` SHA-256/size/mtime 前后不变。
- 结果文件：`evals/results/2026-09-27-claude-code-runtime-smoke.json`（新建、脱敏）。原 `2026-09-27-smoke.json` 继续标记 supplemental，未混写。
- 临时克隆已清理。未合并、未 Public、未 Release。

## 2026-09-27 · GATE-05R 补充修复（部分完成，Claude Code smoke 阻塞，保持 Private）

- **R1 强制 TargetRoot（完成）**：PowerShell `-TargetRoot` 与 Bash `TARGET_ROOT` 均必填；缺失时在任何文件系统写入前非零退出；取消 Bash 默认写入 `~/.claude`。README/MAINTENANCE 已同步。
- **R2 清单路径安全预检（完成）**：安装与卸载均完整校验 `manifest.tsv`——恰好 8 个允许相对路径、路径唯一；拒绝缺失/额外/重复/空白/格式错误/绝对路径/盘符/`.`/`..`/目标根逃逸；规范化绝对路径必须仍在 TargetRoot 内；校验通过前零写入、零删除。PS 与 Bash 语义一致。
- **R2 回归（完成）**：新增缺 TargetRoot、`../` 逃逸（根外 sentinel 不变）、绝对路径、extra/missing/duplicate/malformed 清单、清单失败时 8 文件零删除。原 6 场景继续通过。PowerShell **37/37**、Bash **36/36**。
- **R3 Claude Code 真实 six-role-drill（阻塞）**：已确认 `claude --version` = **2.1.281**。在独立 `CLAUDE_CONFIG_DIR` 安装候选组件后执行演练时鉴权失败（`Not logged in`）；环境无 `ANTHROPIC_API_KEY`，隔离配置无法交互 OAuth；按约束不读取真实 `~/.claude`。**按 GATE-05R 停止在 Private，不用 Mimo actor 结果冒充 Claude Code 兼容性证据。**
- 原 Mimo actor 六角色结果已在 `evals/results/2026-09-27-smoke.json` 标记为 `supplemental-mimo-actor-only` / `claudeCodeCompatible: false`。
- 提交：`e5ded64`（R1/R2）+ 本条文档。候选分支 `mimo/v0.2.0-public-hardening`，PR #1 保持 open、不合并、不改 Public、不建 Tag/Release、不改安全设置。

## 2026-09-27 · GATE-00～05 公开加固执行（完成，停止待批）

- 基线：`main@970ffb6`，远端 `xztxzt1010/claude-code-multi-agent-workflow`（Private），账号 `xztxzt1010`。工作区 6 份任务书差异先提交到候选分支 `mimo/v0.2.0-public-hardening`（`5137224`）。
- GATE-01/02/03（`7cfe80f`）：安装/卸载所有权清单 `.claude-multi-agent-workflow/manifest.tsv`（SHA-256）、8 目标全量预检、冲突零写入、修改后卸载零删除、目录仅空时删除；`test-install.ps1`/`test-install.sh` 各 21/21；CI `windows-latest`+`ubuntu-latest` 矩阵，Action 钉 SHA。README 更新安装契约。
- GATE-04：六角色对 `examples/minimal-task.md` **6/6 真实 spawn**（general-1..6），固定首键齐全；对象 SHA-256 前后均为 `a1b8dd09…ba68e2e`、大小 968、mtime 未变。5-case smoke（E01/E04/E08/E11/E14 × single/three-review/risk-routed）15 条记录可评分，已脱敏写入 `evals/results/2026-09-27-smoke.json`。Token=null（harness 不提供）。
- GATE-05（`e5aa3bf` smoke 入库；`8679afd` 空克隆发现 validate.mjs CRLF 误报并修复）：PR https://github.com/xztxzt1010/claude-code-multi-agent-workflow/pull/1 （open，不合并）。候选 SHA=`8679afd`。
- 空克隆 `%TEMP%\claude-maw-public-check\repo` @ `8679afd`：npm test ✓（6 agents/20 cases/32 files）；PS 21/21；SH 21/21；无凭据/本机路径/大文件；LICENSE=MIT；Markdown 链接通过；README 图 `assets/vision-multi-agent-workflow.png` 存在（1.6MB）。
- CI check-runs @ `8679afd`：`test (windows-latest)` success ×2、`test (ubuntu-latest)` success ×2。
- 回滚引用：基线 `970ffb6`；候选 `8679afd`；PR #1 可关闭；分支可删（需批准）。
- 未执行（待三项批准）：合并 PR、改 Public、Tag/Release 与安全配置。

## v0.2.0 · Experimental 公开候选（整理中）

- 整理六个单一职责 Agent 与两个编排 Skill
- 增加风险路由、交接信封、状态机、停止条件和安全边界
- 增加 Windows / macOS / Linux 安装与卸载入口；所有权、冲突和修改保护正在补齐
- 冻结 20 个评测任务，定义三组对照方法
- 增加零依赖静态校验和 GitHub Actions
- 首发门槛：Windows/Linux 安装安全、至少一次真实 spawn、5-case 三模式 smoke、空克隆复验
- 主行为评测交由 Mimo 执行，当前不声称质量提升

## v0.1.0 · 本机设计验证版

- 建立前提、假设、测试、指标、回滚和范围六个角色
- 初步形成 three-review 与 six-role-drill 方法
- 局限：实现分散在用户目录，缺少独立仓库与公开对照数据

## v1.0.0 · 发布门槛

- 20-case × 3 模式 × 每模式至少 3 次重复完成且报告已脱敏
- 质量结论同时披露失败 case、样本量、耗时与 Token 成本
- CI 绿色，公开克隆复验通过
- 角色选择、失败处理、成本与安全边界有证据支持
