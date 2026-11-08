#!/usr/bin/env bash
# Run deterministic TBS-derived checks plus the minimal AI4S checks.
set -u

MODE="formal"
if [ "${1:-}" = "--reference" ]; then
  MODE="reference"
  shift
fi
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 [--reference] <task-dir>" >&2
  exit 2
fi

TASK_DIR="${1%/}"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

checks=(
  check-dockerfile-references.sh
  check-dockerfile-sanity.sh
  check-dockerfile-platform.sh
  check-task-absolute-path.sh
  check-test-file-references.sh
  check-test-sh-sanity.sh
  check-task-fields.sh
  check-task-structure.sh
  check-task-timeout.sh
  check-instruction-suffix.sh
  check-gpu-types.sh
  check-task-resources.sh
  check-allow-internet.sh
  check-task-slug.sh
  check-separate-verifier.sh
  check-verifier-tooling-baked.sh
  check-trial-network-fetch.sh
  check-pip-pinning.sh
  check-pytest-version.sh
  check-nproc.sh
  check-compose-host-binds.sh
  check-binary-reward.sh
  check-task-readme.sh
)

failed=0
for check in "${checks[@]}"; do
  echo "===== $check ====="
  bash "ci_checks/$check" "$TASK_DIR" || failed=1
done

if [ "$MODE" = "formal" ]; then
  echo "===== check-task-path.sh ====="
  bash ci_checks/check-task-path.sh "$TASK_DIR" || failed=1
  echo "===== check-canary.sh ====="
  bash ci_checks/check-canary.sh "$TASK_DIR" || failed=1
  python3 ci_checks/check-ai4s-metadata.py "$TASK_DIR" || failed=1
else
  python3 ci_checks/check-ai4s-metadata.py --reference "$TASK_DIR" || failed=1
fi

python3 ci_checks/check-task-proposal-link.py "$TASK_DIR" \
  --base-root "${AI4S_PROPOSAL_BASE_ROOT:-$ROOT}" || failed=1
exit "$failed"
