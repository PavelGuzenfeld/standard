"""Slice test: run the python-quality lint step the way a consumer PR does."""

import re
import shutil
import subprocess
import textwrap
from pathlib import Path

import pytest

WORKFLOW = Path(__file__).parent.parent / ".github/workflows/python-quality.yml"

def _diff_quality_has_ruff():
    if shutil.which("diff-quality") is None:
        return False
    help_text = subprocess.run(
        ["diff-quality", "--help"], capture_output=True, text=True
    ).stdout
    return "ruff.check" in help_text


pytestmark = pytest.mark.skipif(
    not _diff_quality_has_ruff() or shutil.which("ruff") is None,
    reason="needs diff-quality with the ruff.check driver and ruff on PATH",
)


def _input_defaults(text):
    return dict(
        re.findall(
            r"^      (\w+):\n        type: \w+\n        default: '([^']*)'", text, re.M
        )
    )


def _lint_script(overrides):
    text = WORKFLOW.read_text()
    defaults = {**_input_defaults(text), **overrides}
    step = re.search(
        r"- name: Run diff-aware linting\n.*?run: \|\n(.*?)\n        continue-on-error",
        text,
        re.S,
    )
    script = textwrap.dedent(step.group(1))
    script = re.sub(r"\$\{\{ inputs\.base_ref \|\|[^}]*\}\}", "main", script)
    return re.sub(r"\$\{\{ inputs\.(\w+) \}\}", lambda m: defaults[m.group(1)], script)


def _lint(tmp_path, source, overrides):
    def git(*args):
        subprocess.run(["git", *args], cwd=tmp_path, check=True, capture_output=True)

    git("init", "-b", "main")
    git("config", "user.email", "t@example.com")
    git("config", "user.name", "t")
    (tmp_path / "base.py").write_text("X = 1\n")
    git("add", ".")
    git("commit", "-m", "base")
    git("update-ref", "refs/remotes/origin/main", "HEAD")
    (tmp_path / "change.py").write_text(source)
    git("add", ".")
    git("commit", "-m", "change")
    return subprocess.run(
        ["bash", "-c", _lint_script(overrides)],
        cwd=tmp_path,
        capture_output=True,
        text=True,
    )


class TestDefaultRuffSelect:
    def test_pascal_case_function_fails_default(self, tmp_path):
        result = _lint(tmp_path, "def ParseFrame():\n    return 1\n", {})
        assert result.returncode != 0
        assert "N802" in result.stdout + result.stderr

    def test_star_import_fails_default(self, tmp_path):
        result = _lint(tmp_path, "from os.path import *\n", {})
        assert result.returncode != 0
        assert "F403" in result.stdout + result.stderr

    def test_pascal_case_function_passes_when_consumer_drops_naming(self, tmp_path):
        assert _lint(
            tmp_path, "def ParseFrame():\n    return 1\n", {"ruff_select": "E,W,I"}
        ).returncode == 0

    def test_snake_case_function_passes_default(self, tmp_path):
        assert _lint(tmp_path, "def parse_frame():\n    return 1\n", {}).returncode == 0
