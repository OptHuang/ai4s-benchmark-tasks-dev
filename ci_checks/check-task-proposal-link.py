#!/usr/bin/env python3
"""Verify that a task points to an already-present, matching Markdown proposal.

Pass the base branch checkout as --base-root (CI does), so a proposal added in
the same PR as its task does not count as merged.
"""

from __future__ import annotations

import argparse
import re
import sys
import tomllib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def proposal_value(text: str, label: str) -> str | None:
    label_re = re.compile(
        rf"(?:^|/\s*){re.escape(label)}(?:\s*\([^)]*\))?\s*$",
        re.IGNORECASE,
    )
    for line in text.splitlines():
        match = re.match(r"^-\s*(.+?)\s*:\s*(.*?)\s*$", line)
        if match and label_re.search(match.group(1)):
            value = match.group(2).strip().strip("`")
            return value or None
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("task_dir", type=Path)
    parser.add_argument("--base-root", type=Path, default=REPO_ROOT)
    args = parser.parse_args()
    with (args.task_dir / "task.toml").open("rb") as handle:
        config = tomllib.load(handle)
    metadata = config.get("metadata", {})
    proposal_path = metadata.get("proposal_path")
    proposal_id = metadata.get("proposal_id")
    task_type = metadata.get("task_type")
    if not isinstance(proposal_path, str) or not proposal_path.startswith("proposals/"):
        print("FAIL: task.toml must contain a repo-relative proposals/... proposal_path")
        return 1
    candidate = (args.base_root.resolve() / proposal_path).resolve()
    proposals_root = (args.base_root.resolve() / "proposals").resolve()
    try:
        candidate.relative_to(proposals_root)
    except ValueError:
        print("FAIL: proposal_path escapes proposals/")
        return 1
    on_base = args.base_root.resolve() != REPO_ROOT
    where = "the base branch" if on_base else "this checkout (merge status is checked in CI)"
    if not candidate.is_file():
        print(f"FAIL: proposal {proposal_path} is absent from {where}; merge the proposal PR first")
        return 1
    text = candidate.read_text(encoding="utf-8")
    expected = {
        "Proposal ID": proposal_id,
        "Task type": task_type,
        "Primary domain": metadata.get("domain"),
        "Secondary discipline": metadata.get("field") or None,
        "Research area": metadata.get("subfield") or None,
    }
    failed = False
    for label, task_value in expected.items():
        proposal = proposal_value(text, label)
        if proposal != task_value:
            print(f"FAIL: {label} mismatch: proposal={proposal!r}, task.toml={task_value!r}")
            failed = True
    if failed:
        return 1
    print(f"PASS: {args.task_dir} links proposal {proposal_path} on {where}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
