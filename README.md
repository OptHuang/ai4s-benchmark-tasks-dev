# AI4S Benchmark Tasks — Dev Preview

[中文版](README_zh.md)

> This invitation-only `-dev` repository is for the first expert cohort. A
> separate production repository will be created after the workflow is tested.

AI4S evaluates research agents with the
[Harbor](https://github.com/harbor-framework/harbor) task format and harness.
Tasks in this preview should be solvable primarily through code and terminal
tools; computer-use extensions are deferred.

## Workflow

1. Install Harbor and configure model access.
2. Run a complete reference task.
3. Write, validate, and submit a task proposal.
4. After proposal approval, build the Harbor task.
5. Run static checks, oracle/nop, and model evaluation.
6. Submit the complete task PR.

Do not implement a formal task before its proposal has been approved and merged.

## Task types

Choose exactly one according to the final success criterion:

- **Scientific workflow automation (`workflow_automation`)** centers on a
  complex workflow from real scientific research. The agent must complete
  multiple interdependent research stages and produce verifiable results.
- **Frontier research (`frontier_research`)** centers on a frontier problem with
  important scientific or application value to the field. The agent must
  autonomously explore methods and achieve a verifiable improvement over a
  frozen current-SOTA baseline. Its oracle reproduces that baseline and is
  expected to be valid but receive reward `0`; only a qualifying improvement
  receives reward `1`.

> [!IMPORTANT]
> **Difficulty requirement:** Every task must meaningfully challenge frontier
> large language models. Its expected success rate on frontier models from both
> Anthropic and OpenAI must be below 30%.

## Quickstart

### 1. Install Harbor and configure model access

Requirements: Git, Docker, Python 3.11+, and
[`uv`](https://docs.astral.sh/uv/).

```bash
uv tool install --force "harbor==0.24.0"
docker version
harbor --version
```

For agent/model trials, set the API key required by your provider, for example:

```bash
export ANTHROPIC_API_KEY=<your-key>
export OPENAI_API_KEY=<your-key>
```

Only set keys you actually use, and never commit them. See Harbor's
[pre-integrated agents](https://docs.harborframework.com/agents/pre-integrated-agents)
and [authentication resolution](https://docs.harborframework.com/agents/agent-auth-resolution)
for supported agents, model names, API keys, and native CLI authentication.

### 2. Run a reference task

```bash
TASK=reference-tasks/earth-environmental-sciences/sparse-network-assimilation
bash scripts/run_task_checks.sh --reference "$TASK"
harbor run -p "$TASK" -a oracle
harbor run -p "$TASK" -a nop
```

For workflow tasks, oracle should receive reward `1` and nop `0`. For frontier
tasks, oracle should receive reward `0` with `valid=true` and `match_sota=true`.
Five complete examples are listed in [reference-tasks/](reference-tasks/README.md), with matching
proposals in [proposals/examples/](proposals/examples/).

### 3. Submit a proposal

Every proposal needs a controlled primary domain, an Engineering-only controlled
secondary discipline, and a required free-text research area.

#### Primary domains

| Primary domain | Required slug |
|---|---|
| Mathematical Sciences | `mathematical-sciences` |
| Physical Sciences | `physical-sciences` |
| Chemical and Materials Sciences | `chemical-materials-sciences` |
| Life Sciences | `life-sciences` |
| Medical, Neuroscience and Health Sciences | `medical-neuroscience-health-sciences` |
| Earth and Environmental Sciences | `earth-environmental-sciences` |
| Computer and Information Sciences | `computer-information-sciences` |
| Engineering Sciences | `engineering-sciences` |

#### Engineering Sciences secondary disciplines

| Secondary discipline | Required slug |
|---|---|
| Electronic Engineering | `electronic-engineering` |
| Mechanical Engineering | `mechanical-engineering` |
| Aerospace Engineering | `aerospace-engineering` |
| Energy Engineering | `energy-engineering` |
| Automation, Control and Robotics | `automation-control-robotics` |

For an interdisciplinary task, choose the single primary domain that best
matches its core scientific question and evaluation. Contact the project lead
if no category fits; do not create a new controlled slug.

Copy [proposals/TEMPLATE.md](proposals/TEMPLATE.md), and use the completed files
in [proposals/examples/](proposals/examples/) as references:

```bash
git checkout -b proposal/<task-slug>
mkdir -p proposals/<primary-domain>
cp proposals/TEMPLATE.md proposals/<primary-domain>/<task-slug>.md
python3 scripts/check_proposal.py proposals/<primary-domain>/<task-slug>.md
git diff --check
```

Then open one proposal-only PR. Begin implementation after the proposal is
approved and merged.

### 4. Build the Harbor task

For a non-engineering task:

```bash
git checkout -b task/<task-slug>
harbor tasks init <task-slug> --org ai4s-benchmark \
  --include-canary-strings \
  --metadata-template task-template.toml \
  -p tasks/<primary-domain>/
python3 scripts/apply_canary.py tasks/<primary-domain>/<task-slug>
```

For an Engineering Sciences task:

```bash
harbor tasks init <task-slug> --org ai4s-benchmark \
  --include-canary-strings \
  --metadata-template task-template.toml \
  -p tasks/engineering-sciences/<secondary-discipline>/
python3 scripts/apply_canary.py tasks/engineering-sciences/<secondary-discipline>/<task-slug>
```

Harbor writes its own canary; `scripts/apply_canary.py` replaces it with the
AI4S canary that `ci_checks/check-canary.sh` requires. Re-run it whenever you
add files under `solution/`, `tests/` or `authoring/`.

Follow the [Harbor task format](https://harborframework.com/docs/task-format)
and the inline instructions in [task-template.toml](task-template.toml).

| Component | Purpose |
|---|---|
| `task.toml` | metadata, proposal linkage, artifacts, resources, and timeouts |
| `instruction.md` | complete agent-facing task and output requirements |
| `environment/` | agent-visible software and data |
| `solution/` | workflow reference solution, or frozen-SOTA oracle for a frontier task |
| `tests/` | separate no-network verifier and binary reward |
| `README.md` | required task summary covering difficulty, reference solution, and verification |

Generate the required task README scaffold with:

```bash
python3 tools/task-readme/generate.py <task-path>
```

### 5. Self-check and evaluate

```bash
bash scripts/run_task_checks.sh <task-path>
harbor run -p <task-path> -a oracle -k 5
harbor run -p <task-path> -a nop
```

Workflow oracle must pass stably and nop must score zero. A frontier oracle must
instead reproduce the registered SOTA with `valid=true`, `match_sota=true`, and
reward `0`; `scripts/validate_task.sh` checks the appropriate contract from
`task_type`. Run a frontier agent/model with:

```bash
harbor run -p <task-path> \
  --agent <agent-adapter> \
  --model <provider/model> \
  -k 3
```

Use [rubrics/task-implementation.toml](rubrics/task-implementation.toml) for the
LLM implementation review and [rubrics/trial-analysis.toml](rubrics/trial-analysis.toml)
for trajectory review.

### 6. Submit the task

Open one task PR linked to its merged proposal. Summarize the self-check and
model-evaluation results; the PR template and reviewers will request any further
evidence needed.

See [REVIEWING.md](REVIEWING.md) for reviewer responsibilities and
[TASK_REVIEW_AUTOMATION.md](TASK_REVIEW_AUTOMATION.md) for automated checks.

## License

Apache-2.0. Third-party attribution is retained in [NOTICE](NOTICE).
