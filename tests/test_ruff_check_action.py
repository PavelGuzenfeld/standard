"""Slice test: run the ruff-check action's lint step the way a consumer PR does."""

import os
import re
import shutil
import subprocess
import textwrap
from pathlib import Path

import pytest

ACTION = Path(__file__).parent.parent / "actions/ruff-check/action.yml"


def _diff_quality_has_ruff():
    if shutil.which("diff-quality") is None:
        return False
    help_text = subprocess.run(
        ["diff-quality", "--help"], capture_output=True, text=True
    ).stdout
    return "ruff.check" in help_text


needs_ruff_driver = pytest.mark.skipif(
    not _diff_quality_has_ruff() or shutil.which("ruff") is None,
    reason="needs diff-quality with the ruff.check driver and ruff on PATH",
)


def _input_defaults(text):
    return dict(
        re.findall(
            r"^  (\w+):\n    description: '[^']*'\n    default: '([^']*)'", text, re.M
        )
    )


def _lint_step(text):
    return re.search(r"- id: lint\n(.*)", text, re.S).group(1)


def _lint_env(overrides):
    text = ACTION.read_text()
    defaults = {**_input_defaults(text), **overrides}
    env_block = re.search(r"env:\n((?:        .*\n)+)", _lint_step(text)).group(1)
    env = {}
    for name, expression in re.findall(r"^        (\w+): (.*)$", env_block, re.M):
        if "inputs.base_ref" in expression:
            env[name] = "main"
            continue
        env[name] = defaults[re.search(r"inputs\.(\w+)", expression).group(1)]
    return env


def _lint_script():
    run = re.search(r"run: \|\n(.*)", _lint_step(ACTION.read_text()), re.S)
    return textwrap.dedent(run.group(1))


def _run_lint(workdir, overrides, path):
    return subprocess.run(
        ["bash", "-c", _lint_script()],
        cwd=workdir,
        capture_output=True,
        text=True,
        env={
            "PATH": path,
            "GITHUB_OUTPUT": str(workdir / "out"),
            **_lint_env(overrides),
        },
    )


def _lint(tmp_path, source, overrides):
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
    return _run_lint(tmp_path, overrides, os.environ["PATH"])


@needs_ruff_driver
class TestDefaultRuffSelect:
    def test_pascal_case_function_fails_default(self, tmp_path):
        result = _lint(tmp_path, "def ParseFrame():\n    return 1\n", {})
        assert result.returncode != 0
        assert "N802" in result.stdout + result.stderr

    def test_pascal_case_function_passes_when_consumer_drops_naming(self, tmp_path):
        assert (
            _lint(
                tmp_path, "def ParseFrame():\n    return 1\n", {"ruff_select": "E,W,I"}
            ).returncode
            == 0
        )

    def test_snake_case_function_passes_default(self, tmp_path):
        assert _lint(tmp_path, "def parse_frame():\n    return 1\n", {}).returncode == 0


class TestMissingRuffCheckDriver:
    def test_driverless_diff_quality_fails_with_the_python_version_advice(
        self, tmp_path
    ):
        stub_dir = tmp_path / "stub"
        stub_dir.mkdir()
        stub = stub_dir / "diff-quality"
        stub.write_text("#!/bin/sh\necho 'usage: diff-quality --violations=flake8'\n")
        stub.chmod(0o755)
        result = _run_lint(tmp_path, {}, f"{stub_dir}{os.pathsep}{os.environ['PATH']}")
        assert result.returncode == 1
        assert (
            "::error::installed diff-cover has no ruff.check driver"
            " (needs Python 3.10+); use a newer python_version"
        ) in result.stdout
