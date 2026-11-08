#!/usr/bin/env bash
# Regression tests for the oracle/nop task resolver.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
RESOLVE="$ROOT/scripts/resolve_changed_tasks.py"
REPO=$(mktemp -d "${TMPDIR:-/tmp}/ai4s-resolver-tests.XXXXXX")
trap 'rm -rf "$REPO"' EXIT

g() { git -C "$REPO" "$@"; }
add_task() { mkdir -p "$REPO/$1/tests" && echo "# $1" > "$REPO/$1/task.toml" && echo x > "$REPO/$1/tests/test.sh"; }
commit() { g add -A && g -c user.name=test -c user.email=test@example.com commit -qm "$1"; }

expect() {
  local name="$1" base="$2" head="$3" want="$4" got
  got=$(python3 "$RESOLVE" --repo "$REPO" --base "$base" --head "$head" 2>/dev/null)
  if [ "$got" != "$want" ]; then
    printf 'FAIL: %s\n--- expected ---\n%s\n--- got ---\n%s\n' "$name" "$want" "$got" >&2
    exit 1
  fi
  echo "PASS $name"
}

g init -q -b main
add_task tasks/earth-environmental-sciences/existing-task
add_task tasks/mathematical-sciences/doomed-task
add_task reference-tasks/mathematical-sciences/ref-task
echo docs > "$REPO/README.md"
commit base

g checkout -q -b pr
add_task tasks/mathematical-sciences/new-task
mkdir -p "$REPO/tasks/mathematical-sciences/new-task/tests/fixture"
echo nested > "$REPO/tasks/mathematical-sciences/new-task/tests/fixture/task.toml"
add_task tasks/engineering-sciences/mechanical-engineering/new-eng-task
commit "add tasks"
PR_HEAD=$(g rev-parse HEAD)

g checkout -q main
add_task tasks/physical-sciences/merged-elsewhere
g rm -rq tasks/mathematical-sciences/doomed-task
commit "main moves on"
MAIN_TIP=$(g rev-parse HEAD)

expect "non-engineering and engineering paths, merge-base diff" "$MAIN_TIP" "$PR_HEAD" \
"tasks/engineering-sciences/mechanical-engineering/new-eng-task
tasks/mathematical-sciences/new-task"

g checkout -q pr
g rm -rq tasks/earth-environmental-sciences/existing-task
commit "delete a task"
expect "task deleted by the PR is skipped" "$MAIN_TIP" HEAD \
"tasks/engineering-sciences/mechanical-engineering/new-eng-task
tasks/mathematical-sciences/new-task"

g checkout -q -b docs-only main
echo more >> "$REPO/README.md"
commit docs
expect "docs-only change selects nothing" "$MAIN_TIP" HEAD ""

g checkout -q -b ref-edit main
echo y >> "$REPO/reference-tasks/mathematical-sciences/ref-task/tests/test.sh"
commit "edit reference task"
expect "reference task edit" "$MAIN_TIP" HEAD "reference-tasks/mathematical-sciences/ref-task"

g checkout -q -b infra main
mkdir -p "$REPO/ci_checks" && echo check > "$REPO/ci_checks/check-new.sh"
commit "edit validator"
expect "validator change selects smoke tasks" "$MAIN_TIP" HEAD \
"reference-tasks/earth-environmental-sciences/sparse-network-assimilation
reference-tasks/mathematical-sciences/first-autocorrelation-inequality"

echo "All task resolver regression tests passed."
