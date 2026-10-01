"""Validate workflow files match .standard.yml configuration."""

import os
import re

from standard_ci.config import read_config
from standard_ci.workflows import ALL_WORKFLOWS

REPO = "PavelGuzenfeld/standard"

PLACEHOLDER_LINE = re.compile(
    r"^\s*(?P<key>[A-Za-z0-9_-]+):\s*[\"']?(?P<value>REQUIRED_[A-Za-z0-9_]+)"
)


def _placeholder_issues(workflows_dir):
    issues = []
    if not os.path.isdir(workflows_dir):
        return issues
    for filename in sorted(os.listdir(workflows_dir)):
        if not filename.endswith((".yml", ".yaml")):
            continue
        with open(os.path.join(workflows_dir, filename)) as f:
            for line_number, line in enumerate(f, start=1):
                match = PLACEHOLDER_LINE.match(line)
                if match:
                    issues.append(
                        (
                            "error",
                            f"{filename}:{line_number}: {match['key']} "
                            f"still has placeholder {match['value']}",
                        )
                    )
    return issues


def check(project_dir="."):
    """Validate setup. Returns list of (level, message) tuples."""
    issues = []
    config_path = os.path.join(project_dir, ".standard.yml")
    config = read_config(config_path)

    if not config:
        issues.append(
            ("error", ".standard.yml not found — run `standard-ci init` first")
        )
        return issues

    workflows_dir = os.path.join(project_dir, ".github", "workflows")
    enabled = config.get("workflows", [])
    if not enabled:
        issues.append(("error", "No workflows listed in .standard.yml"))
        return issues

    pinned_sha = config.get("sha", "")
    pinned_tag = config.get("tag", "")

    for wf_name in enabled:
        if wf_name not in ALL_WORKFLOWS:
            issues.append(("warning", f"Unknown workflow '{wf_name}' in .standard.yml"))
            continue

        wf = ALL_WORKFLOWS[wf_name]
        wf_path = os.path.join(workflows_dir, wf["filename"])

        if not os.path.exists(wf_path):
            issues.append(
                ("error", f"Missing workflow file: .github/workflows/{wf['filename']}")
            )
            continue

        with open(wf_path) as f:
            content = f.read()

        if pinned_sha:
            ref_pattern = f"{REPO}/{wf['ref_path']}@"
            if ref_pattern in content:
                match = re.search(re.escape(ref_pattern) + r"([0-9a-f]{40})", content)
                if match:
                    file_sha = match.group(1)
                    if file_sha != pinned_sha:
                        issues.append(
                            (
                                "warning",
                                f"{wf['filename']}: SHA mismatch — "
                                f"file has {file_sha[:12]}, "
                                f"config has {pinned_sha[:12]}",
                            )
                        )
                else:
                    issues.append(
                        ("warning", f"{wf['filename']}: not pinned to a full SHA")
                    )

    issues.extend(_placeholder_issues(workflows_dir))

    if not issues:
        tag_info = f" ({pinned_tag})" if pinned_tag else ""
        issues.append(
            ("ok", f"All {len(enabled)} workflows match .standard.yml{tag_info}")
        )

    return issues
