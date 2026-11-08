#!/usr/bin/env bash
# Run Harbor oracle and nop under the task-type-specific reference contract.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <task-dir>" >&2
  exit 2
fi
TASK_DIR="${1%/}"
if [ -n "${AI4S_VALIDATION_OUT:-}" ]; then
  OUT_ROOT="$AI4S_VALIDATION_OUT/${TASK_DIR//\//__}"
  mkdir -p "$OUT_ROOT"
else
  OUT_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/ai4s-harbor-validation.XXXXXX")
fi
ROOT=$(cd "$(dirname "$0")/.." && pwd)

task_type=$(python3 - "$TASK_DIR/task.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as handle:
    print(tomllib.load(handle)["metadata"]["task_type"])
PY
)
if [ "$task_type" = "frontier_research" ]; then
  oracle_expected=0
else
  oracle_expected=1
fi

run_and_reward() {
  local agent="$1" out="$2" log="$3"
  # Keep Harbor's build/run stream visible even though this function is used
  # in command substitution. Only the parsed reward is emitted on stdout.
  harbor run -p "$TASK_DIR" --agent "$agent" -o "$out" 2>&1 | tee "$log" >&2
  sed -nE 's/.*Mean[:[:space:]]+([0-9]+([.][0-9]+)?).*/\1/p' "$log" | tail -1
}

oracle_reward=$(run_and_reward oracle "$OUT_ROOT/oracle" "$OUT_ROOT/oracle.log")
if [ "$oracle_reward" != "$oracle_expected" ] && [ "$oracle_reward" != "$oracle_expected.0" ] && [ "$oracle_reward" != "$oracle_expected.000" ]; then
  echo "FAIL: oracle mean reward is ${oracle_reward:-unparseable}, expected $oracle_expected for $task_type" >&2
  echo "Logs retained at $OUT_ROOT" >&2
  exit 1
fi
oracle_check=(python3 "$ROOT/ci_checks/check-verifier-output.py" "$OUT_ROOT/oracle"
  --expect-reward "$oracle_expected" --require-ctrf --no-reward-json)
if [ "$task_type" = "frontier_research" ]; then
  oracle_check+=(--expect-valid true --expect-match-sota true)
fi
"${oracle_check[@]}"

nop_reward=$(run_and_reward nop "$OUT_ROOT/nop" "$OUT_ROOT/nop.log")
if [ "$nop_reward" != "0" ] && [ "$nop_reward" != "0.0" ] && [ "$nop_reward" != "0.000" ]; then
  echo "FAIL: nop mean reward is ${nop_reward:-unparseable}, expected 0" >&2
  echo "Logs retained at $OUT_ROOT" >&2
  exit 1
fi

nop_check=(python3 "$ROOT/ci_checks/check-verifier-output.py" "$OUT_ROOT/nop"
  --expect-reward 0 --require-ctrf --no-reward-json)
if [ "$task_type" = "frontier_research" ]; then
  nop_check+=(--expect-valid false --expect-match-sota false)
fi
"${nop_check[@]}"

echo "PASS: task_type=$task_type oracle=$oracle_reward nop=$nop_reward"
echo "Run artifacts: $OUT_ROOT"
