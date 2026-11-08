#!/usr/bin/env bash
# Positive and negative regression tests for the file-proposal validator.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/ai4s-validator-tests.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/proposals/earth-environmental-sciences"
VALID="$ROOT/proposals/examples/sparse-network-assimilation.md"

# Fixtures share one Proposal ID, so every negative after the first would also
# fail as a duplicate; require the specific error so each rule is really tested.
expect_fail() {
  local name="$1" file="$2" message="$3" output
  if output=$(python3 "$ROOT/scripts/check_proposal.py" --repo-root "$TMP" "$file" 2>&1); then
    echo "FAIL: negative fixture unexpectedly passed: $name" >&2
    exit 1
  fi
  if [[ "$output" != *"$message"* ]]; then
    printf 'FAIL: %s failed without the expected error %q:\n%s\n' "$name" "$message" "$output" >&2
    exit 1
  fi
  echo "PASS negative: $name"
}

python3 "$ROOT/scripts/check_proposal.py" "$VALID" >/dev/null
echo "PASS positive: official normalized example"

cp "$VALID" "$TMP/proposals/earth-environmental-sciences/invalid-type.md"
sed -i 's/`workflow_automation`/`both`/' "$TMP/proposals/earth-environmental-sciences/invalid-type.md"
expect_fail invalid-type "$TMP/proposals/earth-environmental-sciences/invalid-type.md" "Task type must be"

cp "$VALID" "$TMP/proposals/earth-environmental-sciences/invalid-domain.md"
sed -i 's/`earth-environmental-sciences`/`not-a-domain`/' "$TMP/proposals/earth-environmental-sciences/invalid-domain.md"
expect_fail invalid-domain "$TMP/proposals/earth-environmental-sciences/invalid-domain.md" "Primary domain must be one of"

cp "$VALID" "$TMP/proposals/earth-environmental-sciences/missing-research-area.md"
sed -i 's/\(Research area (free text)\): .*/\1:/' "$TMP/proposals/earth-environmental-sciences/missing-research-area.md"
expect_fail missing-research-area "$TMP/proposals/earth-environmental-sciences/missing-research-area.md" "Research area is required"

cp "$VALID" "$TMP/proposals/earth-environmental-sciences/empty-section.md"
perl -0pi -e 's/(## 8\.[^\n]*\n).*\z/$1/s' "$TMP/proposals/earth-environmental-sciences/empty-section.md"
expect_fail empty-section "$TMP/proposals/earth-environmental-sciences/empty-section.md" "Section 8 is empty"

cp "$VALID" "$TMP/proposals/earth-environmental-sciences/nonengineering-secondary.md"
sed -i 's/Secondary discipline (required only for Engineering Sciences):$/Secondary discipline (required only for Engineering Sciences): `mechanical-engineering`/' "$TMP/proposals/earth-environmental-sciences/nonengineering-secondary.md"
expect_fail nonengineering-secondary "$TMP/proposals/earth-environmental-sciences/nonengineering-secondary.md" "Secondary discipline must be left blank"

mkdir -p "$TMP/proposals/engineering-sciences"
cp "$ROOT/proposals/examples/reactor-safety-control.md" "$TMP/proposals/engineering-sciences/invalid-engineering-secondary.md"
sed -i 's/`automation-control-robotics`/`not-an-engineering-discipline`/' "$TMP/proposals/engineering-sciences/invalid-engineering-secondary.md"
expect_fail invalid-engineering-secondary "$TMP/proposals/engineering-sciences/invalid-engineering-secondary.md" "Engineering Sciences proposals require Secondary discipline"

PLACEHOLDER_ROOT="$TMP/placeholder-root"
mkdir -p "$PLACEHOLDER_ROOT/proposals/earth-environmental-sciences"
INEQUALITIES="$PLACEHOLDER_ROOT/proposals/earth-environmental-sciences/inequalities.md"
cp "$VALID" "$INEQUALITIES"
printf '\nPass if MAE < 0.05 and R^2 > 0.9.\n\n- p < 0.01\n- relax -> DOS; area in m<sup>2</sup>\n' >> "$INEQUALITIES"
python3 "$ROOT/scripts/check_proposal.py" --repo-root "$PLACEHOLDER_ROOT" "$INEQUALITIES" >/dev/null
echo "PASS positive: inequalities, arrows and HTML are not placeholders"

for prompt in '请在此用自然语言回答。' 'Please answer here in prose.' 'Run it on <task-slug>.'; do
  cp "$VALID" "$TMP/proposals/earth-environmental-sciences/template-prompt.md"
  printf '\n%s\n' "$prompt" >> "$TMP/proposals/earth-environmental-sciences/template-prompt.md"
  expect_fail "template placeholder: $prompt" "$TMP/proposals/earth-environmental-sciences/template-prompt.md" \
    "template placeholder text"
done

cp "$VALID" "$TMP/proposals/earth-environmental-sciences/duplicate-a.md"
cp "$VALID" "$TMP/proposals/earth-environmental-sciences/duplicate-b.md"
expect_fail duplicate-proposal-id "$TMP/proposals/earth-environmental-sciences/duplicate-a.md" "Duplicate Proposal ID"

echo "All proposal validator regression tests passed."
