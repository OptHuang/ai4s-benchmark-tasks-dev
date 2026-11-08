#!/usr/bin/env bash
# Regression tests for ci_checks/check-verifier-output.py on synthetic Harbor output.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
CHECK="${CHECK:-$ROOT/ci_checks/check-verifier-output.py}"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/ai4s-verifier-output-tests.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# make_trial NAME REWARD COMMA_SEPARATED_TEST_STATUSES [DETAILS_JSON] [SUMMARY_OVERRIDES_JSON]
make_trial() {
  python3 - "$TMP/$1/job/trial/verifier" "$2" "$3" "${4:-}" "${5:-}" <<'PY'
import json
import sys
from pathlib import Path

out, reward, statuses, details, overrides = sys.argv[1:6]
out = Path(out)
out.mkdir(parents=True)
(out / "reward.txt").write_text(f"{reward}\n")
tests = [{"name": f"test_{i}", "status": s} for i, s in enumerate(statuses.split(","))]
summary = {k: sum(t["status"] == k for t in tests) for k in ("passed", "failed", "skipped", "pending", "other")}
summary["tests"] = len(tests)
summary.update(json.loads(overrides or "{}"))
(out / "ctrf.json").write_text(json.dumps({"results": {"summary": summary, "tests": tests}}))
if details:
    (out / "reward-details.json").write_text(details)
PY
}

expect_pass() {
  local name="$1"
  shift
  if ! python3 "$CHECK" "$@" >/dev/null; then
    echo "FAIL: $name: consistent output was rejected" >&2
    python3 "$CHECK" "$@" >&2 || true
    exit 1
  fi
  echo "PASS positive: $name"
}

expect_fail() {
  local name="$1" message="$2" output
  shift 2
  if output=$(python3 "$CHECK" "$@" 2>&1); then
    echo "FAIL: $name: inconsistent output was accepted" >&2
    exit 1
  fi
  if [[ "$output" != *"$message"* ]]; then
    printf 'FAIL: %s failed without the expected error %q:\n%s\n' "$name" "$message" "$output" >&2
    exit 1
  fi
  echo "PASS negative: $name"
}

ORACLE=(--expect-reward 0 --require-ctrf --no-reward-json --expect-valid true --expect-match-sota true)
NOP=(--expect-reward 0 --require-ctrf --no-reward-json --expect-valid false --expect-match-sota false)
FRONTIER_ORACLE='{"valid": true, "match_sota": true, "scientific_score": 1.5029, "improvement_over_sota": 0.0, "reward": 0}'
FRONTIER_NOP='{"valid": false, "match_sota": false, "scientific_score": null, "improvement_over_sota": null, "reward": 0}'
REWARD_MISMATCH='{"valid": true, "match_sota": true, "scientific_score": 1.5029, "improvement_over_sota": 0.0, "reward": 1}'
GARBAGE_SCORE='{"valid": true, "match_sota": true, "scientific_score": "garbage", "improvement_over_sota": "garbage", "reward": 0}'
NO_REWARD='{"valid": false, "match_sota": false, "scientific_score": null, "improvement_over_sota": null}'

make_trial workflow-oracle 1 passed,passed
expect_pass "workflow oracle" "$TMP/workflow-oracle" --expect-reward 1 --require-ctrf --no-reward-json

make_trial frontier-oracle 0 passed,passed,failed "$FRONTIER_ORACLE"
expect_pass "frontier oracle reproduces the frozen SOTA" "$TMP/frontier-oracle" "${ORACLE[@]}"

make_trial frontier-nop 0 failed,failed,failed "$FRONTIER_NOP"
expect_pass "frontier nop is invalid" "$TMP/frontier-nop" "${NOP[@]}"

make_trial summary-hides-failure 1 failed '' '{"passed": 1, "failed": 0}'
expect_fail "CTRF summary contradicts the test statuses" "test(s) in results.tests have that status" \
  "$TMP/summary-hides-failure" --expect-reward 1 --require-ctrf

make_trial details-reward-mismatch 0 passed,passed,failed "$REWARD_MISMATCH"
expect_fail "details reward contradicts reward.txt" "the two reward records disagree" \
  "$TMP/details-reward-mismatch" "${ORACLE[@]}"

make_trial garbage-score 0 passed,passed,failed "$GARBAGE_SCORE"
expect_fail "valid result with a non-numeric score" "needs a finite number" \
  "$TMP/garbage-score" "${ORACLE[@]}"

make_trial details-without-reward 0 failed,failed,failed "$NO_REWARD"
expect_fail "details without a reward" "missing reward" "$TMP/details-without-reward" "${NOP[@]}"

echo "All verifier-output regression tests passed."
