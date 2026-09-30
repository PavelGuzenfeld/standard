"""Slice test: run the ruff-check action's lint step the way a consumer PR does."""

import os
import re
import shutil
import subprocess
import textwrap
from pathlib import Path

import pytest

ACTION = Path(__file__).parent.parent / "actions/ruff-check/action.yml"

pytestmark = pytest.mark.skipif(
    shutil.which("diff-quality") is None or shutil.which("ruff") is None,
    reason="needs diff-quality and ruff on PATH",
)


def _input_defaults(text):
    return dict(
        re.findall(
            r"^  (\w+):\n    description: '[^']*'\n    default: '([^']*)'", text, re.M
        )
    )


def _lint_script(overrides, workdir):
    text = ACTION.read_text()
    defaults = {**_input_defaults(text), **overrides}
    step = re.search(r"- id: lint\n.*?run: \|\n(.*)", text, re.S)
    script = textwrap.dedent(step.group(1))
    script = re.sub(r"\$\{\{ inputs\.base_ref \|\|[^}]*\}\}", "main", script)
    script = script.replace("${{ runner.temp }}", str(workdir))
    return re.sub(r"\$\{\{ inputs\.(\w+) \}\}", lambda m: defaults[m.group(1)], script)


def _lint_passes(tmp_path, source, overrides):
    def git(*args):
        subprocess.run(["git", *args], cwd=tmp_path, check=True, capture_output=True)

    git("init", "-b", "main")
    git("config", "user.email", "t@example.com")
    git("config", "user.name", "t")
    (tmp_path / "src").mkdir()
    (tmp_path / "src/base.py").write_text("X = 1\n")
    git("add", ".")
    git("commit", "-m", "base")
    git("update-ref", "refs/remotes/origin/main", "HEAD")
    (tmp_path / "src/change.py").write_text(source)
    git("add", ".")
    git("commit", "-m", "change")
    result = subprocess.run(
        ["bash", "-c", _lint_script(overrides, tmp_path)],
        cwd=tmp_path,
        capture_output=True,
        env={"PATH": os.environ["PATH"], "GITHUB_OUTPUT": str(tmp_path / "out")},
    )
    return result.returncode == 0


class TestDefaultRuffSelect:
    def test_pascal_case_function_fails_default(self, tmp_path):
        assert not _lint_passes(tmp_path, "def ParseFrame():\n    return 1\n", {})

    def test_pascal_case_function_passes_when_consumer_drops_naming(self, tmp_path):
        assert _lint_passes(
            tmp_path, "def ParseFrame():\n    return 1\n", {"ruff_select": "E,W,I"}
        )

    def test_snake_case_function_passes_default(self, tmp_path):
        assert _lint_passes(tmp_path, "def parse_frame():\n    return 1\n", {})
