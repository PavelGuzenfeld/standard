"""Slice test: run the python-quality lint step the way a consumer PR does."""

import os
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


needs_ruff_driver = pytest.mark.skipif(
    not _diff_quality_has_ruff() or shutil.which("ruff") is None,
    reason="needs diff-quality with the ruff.check driver and ruff on PATH",
)


def _input_defaults(text):
    return dict(
        re.findall(
            r"^      (\w+):\n        type: \w+\n        default: '([^']*)'", text, re.M
        )
    )


def _step(text, name):
    return re.search(
        rf"- name: {name}\n(.*?)(?=\n      - name|\n    outputs:)", text, re.S
    ).group(1)


def _step_env(name, overrides):
    text = WORKFLOW.read_text()
    defaults = {**_input_defaults(text), **overrides}
    env_block = re.search(r"env:\n((?:          .*\n)+)", _step(text, name)).group(1)
    env = {}
    for variable, expression in re.findall(r"^          (\w+): (.*)$", env_block, re.M):
        if "inputs.base_ref" in expression:
            env[variable] = "main"
            continue
        env[variable] = defaults[re.search(r"inputs\.(\w+)", expression).group(1)]
    return env


def _step_script(name):
    run = re.search(
        r"run: \|\n(.*?)(?:\n        continue-on-error.*)?\Z",
        _step(WORKFLOW.read_text(), name),
        re.S,
    )
    return textwrap.dedent(run.group(1))


def _lint_script():
    return _step_script("Run diff-aware linting")


def _lint(tmp_path, source, overrides, path=None):
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
        ["bash", "-c", _lint_script()],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        env={
            **os.environ,
            **({"PATH": f"{path}:{os.environ['PATH']}"} if path else {}),
            **_step_env("Run diff-aware linting", overrides),
        },
    )


@needs_ruff_driver
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
        assert (
            _lint(
                tmp_path, "def ParseFrame():\n    return 1\n", {"ruff_select": "E,W,I"}
            ).returncode
            == 0
        )

    def test_snake_case_function_passes_default(self, tmp_path):
        assert _lint(tmp_path, "def parse_frame():\n    return 1\n", {}).returncode == 0

    def test_line_over_88_columns_passes_default_like_pyproject(self, tmp_path):
        assert _lint(tmp_path, f'X = "{"a" * 100}"\n', {}).returncode == 0

    def test_line_over_88_columns_fails_when_consumer_clears_ignore(self, tmp_path):
        result = _lint(tmp_path, f'X = "{"a" * 100}"\n', {"ruff_ignore": ""})
        assert result.returncode != 0
        assert "E501" in result.stdout + result.stderr


def _stub_executable(directory, name, body):
    path = directory / name
    path.write_text(f"#!/bin/bash\n{body}\n")
    path.chmod(0o755)


class TestLintWithoutRuffDriver:
    def test_diff_quality_lacking_ruff_driver_fails_with_reason(self, tmp_path):
        stubs = tmp_path / "stubs"
        stubs.mkdir()
        _stub_executable(stubs, "diff-quality", "echo 'drivers: pycodestyle flake8'")
        result = _lint(tmp_path, "X = 2\n", {}, path=stubs)
        assert result.returncode != 0
        assert "ruff.check" in result.stdout + result.stderr


def _install_script():
    return _step_script("Install dependencies")


def _pip_arguments(tmp_path, overrides, python_is_old):
    stubs = tmp_path / "stubs"
    stubs.mkdir()
    _stub_executable(stubs, "pip", f'echo "$@" >> {tmp_path}/pip.log')
    _stub_executable(stubs, "python", f"exit {0 if python_is_old else 1}")
    subprocess.run(
        ["bash", "-c", _install_script()],
        cwd=tmp_path,
        env={
            **os.environ,
            "PATH": f"{stubs}:{os.environ['PATH']}",
            **_step_env("Install dependencies", overrides),
        },
        check=True,
    )
    return (tmp_path / "pip.log").read_text()


class TestPinnedVersions:
    def test_ruff_default_matches_pre_commit_pin(self):
        config = (WORKFLOW.parent.parent.parent / ".pre-commit-config.yaml").read_text()
        pinned = re.search(r"ruff-pre-commit\n\s+rev: v(\S+)", config).group(1)
        assert _input_defaults(WORKFLOW.read_text())["ruff_version"] == pinned

    def test_old_python_gets_last_diff_cover_supporting_it(self, tmp_path):
        assert "diff-cover==9.2.0" in _pip_arguments(tmp_path, {}, python_is_old=True)

    def test_new_python_gets_diff_cover_with_ruff_driver(self, tmp_path):
        assert "diff-cover==10.5.1" in _pip_arguments(tmp_path, {}, python_is_old=False)

    def test_old_python_gets_flake8_pinned_to_its_requirements_marker(self, tmp_path):
        log = _pip_arguments(tmp_path, {"python_linter": "flake8"}, python_is_old=True)
        assert "flake8==7.1.2" in log

    def test_new_python_gets_flake8_pinned_to_its_requirements_marker(self, tmp_path):
        log = _pip_arguments(tmp_path, {"python_linter": "flake8"}, python_is_old=False)
        assert "flake8==7.4.1" in log

    def test_explicit_diff_cover_version_wins_on_old_python(self, tmp_path):
        log = _pip_arguments(tmp_path, {"diff_cover_version": "8.0.0"}, True)
        assert "diff-cover==8.0.0" in log
