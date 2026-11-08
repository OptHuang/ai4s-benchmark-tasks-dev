#!/usr/bin/env python3
"""Validate an AI4S Markdown task proposal using only the standard library."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DOMAINS = {
    "mathematical-sciences",
    "physical-sciences",
    "chemical-materials-sciences",
    "life-sciences",
    "medical-neuroscience-health-sciences",
    "earth-environmental-sciences",
    "computer-information-sciences",
    "engineering-sciences",
}
ENGINEERING_DISCIPLINES = {
    "electronic-engineering",
    "mechanical-engineering",
    "aerospace-engineering",
    "energy-engineering",
    "automation-control-robotics",
}
TASK_TYPES = {"workflow_automation", "frontier_research"}
REQUIRED_SECTIONS = tuple(range(0, 9))
# Template prompts and <kebab-case> tokens only: scientific prose legitimately
# uses "<" and ">" for inequalities, arrows and HTML such as <sup>.
PLACEHOLDER = re.compile(
    r"(?i:\bTODO\b|REPLACE WITH|replace-domain|请在此(?:用自然语言)?回答|请填写标题"
    r"|Please answer here|Enter title)"
    r"|<[a-z0-9]+(?:-[a-z0-9]+)+>"
)


def metadata_value(text: str, english_label: str) -> str | None:
    """Read a bullet field from either an English-only or bilingual label."""
    label_re = re.compile(
        rf"(?:^|/\s*){re.escape(english_label)}(?:\s*\([^)]*\))?\s*$",
        re.IGNORECASE,
    )
    for line in text.splitlines():
        match = re.match(r"^-\s*(.+?)\s*:\s*(.*?)\s*$", line)
        if not match or not label_re.search(match.group(1)):
            continue
        value = match.group(2).strip().strip("`")
        return value or None
    return None


def sections(text: str) -> dict[int, str]:
    found: dict[int, tuple[int, int]] = {}
    matches = list(re.finditer(r"^##\s+(\d+)\.\s+.+$", text, re.MULTILINE))
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        found[int(match.group(1))] = (match.end(), end)
    return {number: text[start:end].strip() for number, (start, end) in found.items()}


def validate(path: Path, repo_root: Path) -> list[str]:
    errors: list[str] = []
    text = path.read_text(encoding="utf-8")
    proposal_id = metadata_value(text, "Proposal ID")
    domain = metadata_value(text, "Primary domain")
    discipline = metadata_value(text, "Secondary discipline")
    research_area = metadata_value(text, "Research area")
    task_type = metadata_value(text, "Task type")

    if not proposal_id or not re.fullmatch(r"AI4S-[A-Z0-9]+(?:-[A-Z0-9]+)+", proposal_id):
        errors.append("Proposal ID must use uppercase AI4S-... kebab form")
    if domain not in DOMAINS:
        errors.append(f"Primary domain must be one of: {', '.join(sorted(DOMAINS))}")
    if domain == "engineering-sciences":
        if discipline not in ENGINEERING_DISCIPLINES:
            errors.append(
                "Engineering Sciences proposals require Secondary discipline to be one of: "
                + ", ".join(sorted(ENGINEERING_DISCIPLINES))
            )
    elif discipline:
        errors.append("Secondary discipline must be left blank unless Primary domain is engineering-sciences")
    if not research_area:
        errors.append("Research area is required and may be entered as free text")
    if task_type not in TASK_TYPES:
        errors.append("Task type must be workflow_automation or frontier_research")

    parsed = sections(text)
    for number in REQUIRED_SECTIONS:
        if number not in parsed:
            errors.append(f"Missing section: ## {number}.")
        elif not parsed[number]:
            errors.append(f"Section {number} is empty")

    placeholder = PLACEHOLDER.search(text)
    if placeholder:
        errors.append(f"Proposal still contains template placeholder text: {placeholder.group(0)!r}")

    if path.name != "TEMPLATE.md" and "examples" not in path.parts:
        try:
            relative = path.resolve().relative_to((repo_root / "proposals").resolve())
        except ValueError:
            errors.append("Proposal must live under proposals/<domain>/<task-slug>.md")
        else:
            if len(relative.parts) != 2:
                errors.append("Proposal path must be proposals/<domain>/<task-slug>.md")
            elif domain and relative.parts[0] != domain:
                errors.append("Proposal directory must match Primary domain")
            if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", path.stem):
                errors.append("Proposal filename must be lowercase kebab-case")

    if proposal_id:
        for other in (repo_root / "proposals").rglob("*.md"):
            if other.resolve() == path.resolve() or other.name == "TEMPLATE.md":
                continue
            other_id = metadata_value(other.read_text(encoding="utf-8"), "Proposal ID")
            if other_id == proposal_id:
                errors.append(f"Duplicate Proposal ID also used by {other.relative_to(repo_root)}")
                break
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("proposal", type=Path, nargs="+")
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    failed = False
    for path in args.proposal:
        errors = validate(path, args.repo_root)
        if errors:
            failed = True
            print(f"FAIL {path}")
            for error in errors:
                print(f"  - {error}")
        else:
            print(f"PASS {path}")
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
