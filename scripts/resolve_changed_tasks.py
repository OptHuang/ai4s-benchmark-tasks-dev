#!/usr/bin/env python3
"""List the task directories that a change touches, for oracle/nop validation.

Changed files are taken from the merge base of BASE and HEAD, so commits that
landed on the base branch after the PR branched are not attributed to the PR.
Each changed file is mapped to the shallowest directory that has a task.toml at
HEAD, which handles both tasks/<domain>/<task>/ and
tasks/engineering-sciences/<discipline>/<task>/. A task deleted by the change
has no task.toml left at HEAD and is skipped.

Changes to the validation tooling itself select the reference smoke tasks, so
a validator edit is exercised against one workflow task and one frontier task.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

TASK_ROOTS = ("tasks", "reference-tasks")
VALIDATION_TOOLING = (
    "ci_checks/",
    "scripts/validate_task.sh",
    "scripts/run_task_checks.sh",
    "scripts/resolve_changed_tasks.py",
    "task-template.toml",
    ".github/workflows/validate-task.yml",
)
SMOKE_TASKS = (
    "reference-tasks/earth-environmental-sciences/sparse-network-assimilation",
    "reference-tasks/mathematical-sciences/first-autocorrelation-inequality",
)


def git(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), *args], check=True, capture_output=True, text=True
    )
    return result.stdout.strip()


def changed_files(repo: Path, base: str, head: str) -> list[str]:
    merge_base = git(repo, "merge-base", base, head)
    diff = git(repo, "diff", "--name-only", "--no-renames", merge_base, head)
    return [line for line in diff.splitlines() if line]


def has_task_toml(repo: Path, head: str, directory: str) -> bool:
    result = subprocess.run(
        ["git", "-C", str(repo), "cat-file", "-e", f"{head}:{directory}/task.toml"],
        capture_output=True,
    )
    return result.returncode == 0


def task_dir_for(repo: Path, head: str, path: str) -> str | None:
    parts = path.split("/")
    if parts[0] not in TASK_ROOTS:
        return None
    # Shallowest match first, so a fixture task.toml nested inside a task's
    # tests/ or environment/ never shadows the task itself.
    for depth in range(3, len(parts)):
        candidate = "/".join(parts[:depth])
        if has_task_toml(repo, head, candidate):
            return candidate
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n", 1)[0])
    parser.add_argument("--base", required=True, help="base commit of the PR")
    parser.add_argument("--head", default="HEAD", help="head commit of the PR")
    parser.add_argument("--repo", type=Path, default=Path.cwd(), help="git repository")
    args = parser.parse_args()

    files = changed_files(args.repo, args.base, args.head)
    tasks: set[str] = set()
    for path in files:
        task = task_dir_for(args.repo, args.head, path)
        if task:
            tasks.add(task)
        elif path.split("/")[0] in TASK_ROOTS and path.count("/") >= 2:
            print(f"note: {path} is not inside a current task (deleted task?)", file=sys.stderr)
    if any(path.startswith(VALIDATION_TOOLING) for path in files):
        print("note: validation tooling changed; adding reference smoke tasks", file=sys.stderr)
        tasks.update(SMOKE_TASKS)
    for task in sorted(tasks):
        print(task)
    return 0


if __name__ == "__main__":
    sys.exit(main())
