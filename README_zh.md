# AI4S Benchmark Tasks — 开发预览版

[English](README.md)

> 本 `-dev` 仓库面向首批受邀领域专家，用于试行任务贡献与审核流程。流程验证完成后，
> 项目将另行建立正式仓库。

AI4S 使用 [Harbor](https://github.com/harbor-framework/harbor) 的任务格式和评测 harness
评价科研 agent。预览阶段的任务原则上应主要通过代码和命令行工具完成；computer use
扩展暂不纳入本轮开发。

## 总体流程

1. 安装 Harbor 并配置模型访问。
2. 运行一个完整参考任务。
3. 编写、校验并提交 task proposal。
4. Proposal 获批后，构建 Harbor 任务。
5. 运行静态检查、oracle/nop 和模型评测。
6. 提交完整任务 PR。

正式任务必须先完成 proposal 审核并合并，之后才能开始实现。

## 两类任务

请根据最终成功标准选择且仅选择一种：

- **科研工作流自动化任务（`workflow_automation`）**：围绕真实科研中的复杂工作流，
  要求智能体完成多个相互关联的研究环节，并产出可验证的结果。
- **前沿科研问题攻关任务（`frontier_research`）**：围绕领域内具有重要科学或应用意义
  的前沿问题，要求智能体自主探索方法，并相对冻结的当前 SOTA 取得可验证改进。此类
  任务的 oracle 用于复现 SOTA，应为有效结果但 reward 为 `0`；只有达到规定突破幅度
  的结果才能得到 reward `1`。

> [!IMPORTANT]
> **难度要求：** 所有任务都必须对前沿大语言模型具有实质挑战性；预期在 Anthropic 和
> OpenAI 的前沿模型上成功率均低于 30%。

## Quickstart

### 1. 安装 Harbor 并配置模型访问

本地需要 Git、Docker、Python 3.11 或更高版本，以及
[`uv`](https://docs.astral.sh/uv/)。

```bash
uv tool install --force "harbor==0.24.0"
docker version
harbor --version
```

运行 agent/model 时，请设置对应模型供应商要求的 API key，例如：

```bash
export ANTHROPIC_API_KEY=<your-key>
export OPENAI_API_KEY=<your-key>
```

只设置实际使用的 key，绝不要将其提交到 Git。Harbor 官方的
[预集成 agent 列表](https://docs.harborframework.com/agents/pre-integrated-agents)和
[认证解析说明](https://docs.harborframework.com/agents/agent-auth-resolution)列出了支持的
agent、模型名称、API key 和原生 CLI 登录方式。

### 2. 运行参考任务

```bash
TASK=reference-tasks/earth-environmental-sciences/sparse-network-assimilation
bash scripts/run_task_checks.sh --reference "$TASK"
harbor run -p "$TASK" -a oracle
harbor run -p "$TASK" -a nop
```

工作流任务的 oracle 应获得 reward `1`，nop 应获得 `0`。前沿任务的 oracle 应获得
reward `0`，同时输出 `valid=true` 和 `match_sota=true`。五个完整样例见
[reference-tasks/](reference-tasks/README.md)，对应 proposal 见
[proposals/examples/](proposals/examples/)。

### 3. 提交 proposal

每份 proposal 都必须填写标准一级学科、仅工程科学使用的标准二级学科，以及必填的
自由文本细分领域。

#### 一级学科

| 一级学科 | 必须使用的 slug |
|---|---|
| 数学科学 | `mathematical-sciences` |
| 物理科学 | `physical-sciences` |
| 化学与材料科学 | `chemical-materials-sciences` |
| 生命科学 | `life-sciences` |
| 医学、神经与健康科学 | `medical-neuroscience-health-sciences` |
| 地球与环境科学 | `earth-environmental-sciences` |
| 计算机与信息科学 | `computer-information-sciences` |
| 工程科学 | `engineering-sciences` |

#### 工程科学二级学科

| 二级学科 | 必须使用的 slug |
|---|---|
| 电子工程 | `electronic-engineering` |
| 机械工程 | `mechanical-engineering` |
| 航空航天工程 | `aerospace-engineering` |
| 能源工程 | `energy-engineering` |
| 自动化控制与机器人 | `automation-control-robotics` |

跨学科任务请选择最能代表核心科学问题和评价标准的一个一级学科。如果没有合理类别，
请联系项目负责人，不要自行创建新的标准 slug。

复制 [proposals/TEMPLATE.md](proposals/TEMPLATE.md)，并参考
[proposals/examples/](proposals/examples/) 中的完整样例填写：

```bash
git checkout -b proposal/<task-slug>
mkdir -p proposals/<primary-domain>
cp proposals/TEMPLATE.md proposals/<primary-domain>/<task-slug>.md
python3 scripts/check_proposal.py proposals/<primary-domain>/<task-slug>.md
git diff --check
```

随后创建一个只包含一份 proposal 的 PR。Proposal 获批并合并后再开始实现。

### 4. 构建 Harbor 任务

非工程科学任务：

```bash
git checkout -b task/<task-slug>
harbor tasks init <task-slug> --org ai4s-benchmark \
  --include-canary-strings \
  --metadata-template task-template.toml \
  -p tasks/<primary-domain>/
python3 scripts/apply_canary.py tasks/<primary-domain>/<task-slug>
```

工程科学任务：

```bash
harbor tasks init <task-slug> --org ai4s-benchmark \
  --include-canary-strings \
  --metadata-template task-template.toml \
  -p tasks/engineering-sciences/<secondary-discipline>/
python3 scripts/apply_canary.py tasks/engineering-sciences/<secondary-discipline>/<task-slug>
```

Harbor 会写入它自己的 canary；`scripts/apply_canary.py` 将其替换为
`ci_checks/check-canary.sh` 要求的 AI4S canary。之后每次在 `solution/`、`tests/`
或 `authoring/` 下新增文件，都请重新运行一次。

请遵循 [Harbor 任务格式](https://harborframework.com/docs/task-format)和
[task-template.toml](task-template.toml) 中的字段说明。

| 组件 | 用途 |
|---|---|
| `task.toml` | metadata、proposal 关联、artifacts、资源和 timeout |
| `instruction.md` | agent 可见的完整任务和输出要求 |
| `environment/` | agent 可见的软件和数据 |
| `solution/` | 工作流参考解，或前沿任务的冻结 SOTA oracle |
| `tests/` | 独立无网络 verifier 和二元 reward |
| `README.md` | 必需的任务摘要，说明难度、参考解和验证方式 |

使用以下命令生成任务 README 骨架：

```bash
python3 tools/task-readme/generate.py <task-path>
```

### 5. 自行检查与评测

```bash
bash scripts/run_task_checks.sh <task-path>
harbor run -p <task-path> -a oracle -k 5
harbor run -p <task-path> -a nop
```

工作流任务的 oracle 必须稳定通过，nop 必须得到零分。前沿任务的 oracle 则必须复现
登记的 SOTA，输出 `valid=true`、`match_sota=true` 和 reward `0`；
`scripts/validate_task.sh` 会根据 `task_type` 检查对应规则。运行前沿 agent/model：

```bash
harbor run -p <task-path> \
  --agent <agent-adapter> \
  --model <provider/model> \
  -k 3
```

LLM 实现审核使用 [rubrics/task-implementation.toml](rubrics/task-implementation.toml)，
trajectory 审核使用 [rubrics/trial-analysis.toml](rubrics/trial-analysis.toml)。

### 6. 提交完整任务

创建一个只包含一个任务的 PR，并关联已经合并的 proposal。简要汇总自行检查和模型评测
结果即可；如需其他证据，PR 模板和审核组会进一步提示。

审核角色职责见 [REVIEWING.md](REVIEWING.md)，自动检查见
[TASK_REVIEW_AUTOMATION.md](TASK_REVIEW_AUTOMATION.md)。

## 许可证

本仓库采用 Apache-2.0 许可证。第三方署名保留在 [NOTICE](NOTICE) 中。
