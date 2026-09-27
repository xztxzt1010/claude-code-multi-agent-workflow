# Mimo 执行手册 · 02 多子 Agent 工作流

本文件是 Mimo 在独立对话框中的唯一主任务书。请先完整阅读本仓库全部 Markdown，再从 `GATE-00` 顺序执行；不得跳 Gate，不得把静态检查写成效果提升。

## 本轮目标与授权边界

目标：把当前私有仓库整理为可公开的 `v0.2.0 Experimental` 候选版，补齐安装所有权、跨平台隔离测试、真实六角色 smoke、5-case 评测冒烟和干净克隆证据。

本轮允许：

- 在 `mimo/v0.2.0-public-hardening` 分支修改安装/卸载脚本、测试、CI 和文档。
- 推送该私有候选分支并创建 PR；不得自行合并。
- 在系统临时目录进行安装、卸载与空克隆验收。

本轮禁止：

- 不得触碰或读取用户真实 `~/.claude`；所有脚本测试必须显式传入临时 `TargetRoot`。
- 不得向用户索要或展示 GitHub Token、密码、Cookie、恢复码。
- 不得把仓库改为 Public，不得合并 PR、打 Tag、建 Release、删除分支或修改仓库安全/保护规则。
- 不得提交凭据、私人转录、隐藏推理、本机绝对路径、未经脱敏的 trace 或原始模型会话。
- 不得修改已冻结的 `evals/cases.json` 后继续给同一轮结果打分。

任何 GitHub 写操作前，先在输出中写明目标仓库、分支和动作。若目标不是 `xztxzt1010/claude-code-multi-agent-workflow`，立即停止。

## GATE-00 · 基线、登录与分支

1. 记录但不要改写：当前分支、HEAD、远端、工作区状态、默认分支、仓库可见性、最近 CI。
2. 当前已知基线为 `main@970ffb6`，远端为 `xztxzt1010/claude-code-multi-agent-workflow`，仓库应为 Private。若不一致，停止并报告。
3. GitHub 登录只使用 GitHub CLI 的系统凭据：

```powershell
gh auth status -h github.com
gh api user --jq .login
```

如尚未登录，使用浏览器设备授权：

```powershell
gh auth login -h github.com --web --git-protocol https
```

权限不足时才刷新最小所需范围：

```powershell
gh auth refresh -h github.com -s repo -s workflow
```

验收：账号必须为 `xztxzt1010`；不得复制 Token 到聊天或文件。偶发 TLS/网络超时只重试只读检查，不得因此改凭据。

4. 检查当前工作区中的任务书差异；以当前 `main` 为起点创建 `mimo/v0.2.0-public-hardening`，先提交本轮计划文档，再开始代码修改。不得直接提交到 `main`。
5. 运行并记录退出码：

```powershell
npm test
git diff --check
```

预期静态基线：6 个 Agent、2 个 Skill、20 个固定 case、30 个文件扫描通过。

## GATE-01 · 安装所有权与零损害卸载

当前脚本会覆盖并删除同名文件，不满足公开条件。实现 PowerShell 与 Bash 语义一致的所有权清单，建议位于目标根目录：

```text
.claude-multi-agent-workflow/manifest.tsv
```

清单至少记录项目标识、相对路径和安装完成后的 SHA-256；不得记录绝对路径、用户名或凭据。

### 安装契约

- 复制前一次性预检全部 8 个目标（6 个 Agent 文件、2 个 Skill 的项目文件），预检通过前不得写任何目标文件。
- 目标不存在：允许安装。
- 目标存在且清单证明由本项目持有，并且当前哈希等于旧清单哈希：允许幂等重装/升级。
- 目标存在但无所有权证明，或用户已修改已安装文件：非零退出，并保证零新增、零覆盖、零部分升级。
- 不得使用强制覆盖任意用户文件的逻辑；不得以“先备份再覆盖”绕过冲突。
- 所有文件成功复制后才发布新清单；尽量使用同目录临时文件后原子替换。

### 卸载契约

- 无清单时拒绝卸载，不得按文件名猜测所有权。
- 删除前一次性核验清单中的全部路径和哈希；任一文件被修改或状态不明时，非零退出且零删除。
- 只删除清单证明由本项目安装且当前哈希仍匹配的文件。
- 无关文件必须保留；目录仅在为空时删除，禁止递归删除可能包含用户内容的目录。
- 最后删除清单；任何中间错误必须明确报告，不得声称卸载成功。

允许修改：四个安装/卸载脚本、必要的测试脚本/fixture、`package.json`、CI、README 与安全/维护/任务/版本文档。不要改六个 Agent、两个 Skill 或冻结评测集，除非发现独立 P0 缺陷并先停止报告。

## GATE-02 · Windows / Linux 隔离验收与 CI

为 PowerShell 和 Bash 各建立自动化隔离测试。每次只使用新建的系统临时目录，并在清理前解析绝对路径、确认它位于系统临时根目录下；绝不以 `$HOME`、`~`、工作区根或未解析变量作为递归删除目标。

两套实现至少覆盖：

1. 空目标首次安装成功，准确得到 6 个 Agent 与 2 个 Skill。
2. 未修改状态下幂等重装成功。
3. 预置同名冲突时安装失败，且无部分写入。
4. 目标中的无关文件在安装和卸载后均保留。
5. 用户修改一个已安装文件后，卸载失败且其他项目文件也未被部分删除。
6. 未修改状态下完整卸载成功，清单消失，无关文件仍在。

CI 至少在 `windows-latest` 与 `ubuntu-latest` 上运行 `npm test` 和各自安装测试。第三方 Action 必须固定到完整 commit SHA，并在注释中标版本；可采用：

```yaml
actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
actions/setup-node@820762786026740c76f36085b0efc47a31fe5020 # v7.0.0
```

验收：本机两套可运行检查与远端所有 CI job 绿色；失败时修复根因，不得放宽断言或只在 CI 中跳过。

## GATE-03 · 对外叙事与安装说明

- README 首屏先展示仓库真实可安装的通用六角色工作流；机器视觉图移动到“应用案例/概念扩展示例”，保留“图中领域 Agent 尚未发布”的醒目说明。
- 快速开始明确冲突保护、所有权清单、修改后拒绝卸载和手动处理办法。
- 状态统一写为 `v0.2.0 Experimental`：已验证结构与安装安全，不声称多 Agent 提升质量。
- `package.json` 的 `private: true` 保留，它用于阻止误发 npm 包，不影响 GitHub 公开。
- 更新 `docs/security.md`、`MAINTENANCE.md`、`TASKS.md`、`VERSION.md`，避免“只按同名删除”这类不准确表述。

## GATE-04 · 最小行为证据

### 六角色真实机制回归

以 `examples/minimal-task.md` 为只读对象执行 `/six-role-drill`：

- 六个角色均有固定输出键和实质内容。
- 至少一个角色必须是真实 spawn；六个全部 simulated 则失败。
- 对象前后大小、修改时间、哈希不变。
- 记录 Claude Code 版本、模型/端点类型、权限和各角色 `spawned / simulated / failed`；不保存隐藏推理。

### 5-case smoke

按 `docs/evaluation.md` 冻结环境，使用 E01、E04、E08、E11、E14 验证 `single`、`three-review`、`risk-routed` 的路由、记录格式与可评分性。模型、权限、输入和起点必须一致；Token 无法获取时写 `null`，不得估算。

本轮只要求 smoke 作为实验可运行证据，不得从 5 题推导质量提升百分比。完整 20 case × 3 模式 × 每组 3 次重复继续作为 `v1.0.0` 门槛。

验收：保存脱敏后的环境、运行摘要、失败项与限制；原始私人会话和隐藏推理不入库。真实 spawn 或 smoke 因外部条件无法执行时，停止在 Private，不得假装通过。

## GATE-05 · 私有候选与空克隆报告

1. 提交并推送 `mimo/v0.2.0-public-hardening`，创建面向 `main` 的 PR，但不要合并。
2. 在新的系统临时目录从 GitHub 空克隆候选分支；Windows 验证 PowerShell，Linux/可用 Bash 环境验证 Bash；重复静态检查和隔离安装测试。
3. 扫描 tracked files 与本分支新增历史：凭据、`.env`、本机绝对路径、私人数据、大文件、许可证和 Markdown 链接。
4. 确认 README 图片可见、CI 绿色、默认安装说明与脚本一致。
5. 更新 `TASKS.md`、`VERSION.md`，输出 GATE-05 报告：
   - 基线/候选/目标 SHA 与 URL
   - 每条命令及退出码
   - Windows/Linux 测试矩阵
   - 六角色与 5-case smoke 摘要
   - 敏感信息、许可证、图片和空克隆结果
   - 剩余风险、回滚引用

完成后停止，等待所有者分别批准：① 是否合并 PR；② 是否改为 Public；③ 是否建立 `v0.2.0` Tag/Release 与仓库安全配置。不得把一次批准扩展到其他动作。

## GATE-06 · 后续单独批准后才执行

只有获得明确批准后，才可依次处理合并、Public、仓库描述/Topics、`v0.2.0` Experimental Release、Secret Scanning/Push Protection、main 保护与匿名克隆复验。每项完成后报告实际配置和可回滚引用。

## 全局失败停止条件

- 目标仓库、账号、基线或分支不符合 GATE-00。
- 任一测试触碰真实 `~/.claude` 或临时根之外的文件。
- 安装冲突产生部分写入，或卸载删除无所有权/已修改/无关文件。
- 发现 Token、私人路径、未脱敏 trace 或隐藏推理将被提交。
- 六角色全部 simulated，或三组 smoke 的模型、权限、输入、起点不一致。
- 无法证明测试从同一候选 SHA 开始。

触发任一条件：停止后续 Gate，保留非敏感诊断，如实报告，不得以降低标准换取绿色。
