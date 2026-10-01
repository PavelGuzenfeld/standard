"""Tests for starter workflow template generation."""

import json
from unittest.mock import MagicMock, patch

import pytest

from standard_ci.starters import (
    TEMPLATES,
    _run_gh,
    generate_all_files,
    generate_properties_json,
    generate_starter_workflow,
    install_starters,
)

FAKE_SHA = "abc123def456789012345678901234567890abcd"
FAKE_TAG = "v0.14.1"


class TestGenerateStarterWorkflow:
    def test_cpp_quality_has_sha_pin(self):
        tmpl = TEMPLATES[0]
        assert tmpl["slug"] == "standard-cpp-quality"
        yaml = generate_starter_workflow(tmpl, FAKE_SHA, FAKE_TAG)
        assert f"@{FAKE_SHA}" in yaml
        assert f"# {FAKE_TAG}" in yaml

    def test_cpp_quality_has_default_branch(self):
        tmpl = TEMPLATES[0]
        yaml = generate_starter_workflow(tmpl, FAKE_SHA, FAKE_TAG)
        assert "$default-branch" in yaml

    def test_cpp_quality_docker_image_is_failing_placeholder(self):
        tmpl = TEMPLATES[0]
        yaml = generate_starter_workflow(tmpl, FAKE_SHA, FAKE_TAG)
        assert "docker_image: REQUIRED_DOCKER_IMAGE\n" in yaml
        assert "TODO" not in yaml

    def test_python_quality_has_sast(self):
        tmpl = TEMPLATES[1]
        assert tmpl["slug"] == "standard-python-quality"
        yaml = generate_starter_workflow(tmpl, FAKE_SHA, FAKE_TAG)
        assert "sast-python.yml" in yaml
        assert "python-quality.yml" in yaml

    def test_full_quality_has_all_workflows(self):
        tmpl = TEMPLATES[2]
        assert tmpl["slug"] == "standard-full-quality"
        yaml = generate_starter_workflow(tmpl, FAKE_SHA, FAKE_TAG)
        assert "cpp-quality.yml" in yaml
        assert "python-quality.yml" in yaml
        assert "sast-python.yml" in yaml
        assert "infra-lint.yml" in yaml

    def test_full_quality_infra_has_cmake_lint(self):
        tmpl = TEMPLATES[2]
        yaml = generate_starter_workflow(tmpl, FAKE_SHA, FAKE_TAG)
        assert "enable_cmake_lint: true" in yaml


class TestGenerateProperties:
    def test_valid_json(self):
        for tmpl in TEMPLATES:
            raw = generate_properties_json(tmpl)
            data = json.loads(raw)
            assert "name" in data
            assert "description" in data
            assert "filePatterns" in data

    def test_cpp_file_patterns(self):
        tmpl = TEMPLATES[0]
        data = json.loads(generate_properties_json(tmpl))
        assert "CMakeLists.txt" in data["filePatterns"]

    def test_python_file_patterns(self):
        tmpl = TEMPLATES[1]
        data = json.loads(generate_properties_json(tmpl))
        assert "pyproject.toml" in data["filePatterns"]


class TestGenerateAllFiles:
    def test_generates_7_files(self):
        files = generate_all_files(FAKE_SHA, FAKE_TAG)
        assert len(files) == 7

    def test_all_paths_under_workflow_templates(self):
        files = generate_all_files(FAKE_SHA, FAKE_TAG)
        for path in files:
            assert path.startswith("workflow-templates/")

    def test_icon_svg_present(self):
        files = generate_all_files(FAKE_SHA, FAKE_TAG)
        assert "workflow-templates/standard-icon.svg" in files

    def test_all_ymls_have_sha(self):
        files = generate_all_files(FAKE_SHA, FAKE_TAG)
        for path, content in files.items():
            if path.endswith(".yml"):
                assert FAKE_SHA in content


def _completed(stdout="", returncode=0, stderr=""):
    return MagicMock(stdout=stdout, returncode=returncode, stderr=stderr)


class _FakeProcesses:
    def __init__(self, view_rc=0, status_out="?? changed\n", push_rc=0, push_err=""):
        self.calls = []
        self._view_rc = view_rc
        self._status_out = status_out
        self._push_rc = push_rc
        self._push_err = push_err

    def __call__(self, cmd, **kwargs):
        self.calls.append((cmd, kwargs))
        if cmd[:3] == ["gh", "repo", "view"]:
            return _completed(returncode=self._view_rc)
        if cmd[:2] == ["git", "status"]:
            return _completed(stdout=self._status_out)
        if cmd[:2] == ["git", "push"]:
            return _completed(returncode=self._push_rc, stderr=self._push_err)
        return _completed()

    def commands(self):
        return [cmd for cmd, _ in self.calls]

    def kwargs_of(self, cmd_prefix):
        for cmd, kwargs in self.calls:
            if cmd[: len(cmd_prefix)] == cmd_prefix:
                return kwargs
        raise AssertionError(f"no call starting with {cmd_prefix}")


def _install(fake, **kwargs):
    with patch("standard_ci.starters.subprocess.run", side_effect=fake):
        return install_starters("org", FAKE_SHA, FAKE_TAG, **kwargs)


class TestPropertiesFormat:
    def test_properties_are_indented_two_spaces_with_trailing_newline(self):
        template = {"properties": {"name": "n", "categories": ["a"]}}
        assert generate_properties_json(template) == (
            '{\n  "name": "n",\n  "categories": [\n    "a"\n  ]\n}\n'
        )


class TestRunGh:
    def test_runs_gh_with_args_and_returns_stripped_stdout_and_status(self):
        with patch("standard_ci.starters.subprocess.run") as run:
            run.return_value = _completed(stdout=" out\n")
            assert _run_gh(["repo", "view", "x"]) == ("out", 0)
        assert run.call_args.args[0] == ["gh", "repo", "view", "x"]

    def test_gh_call_times_out_after_thirty_seconds(self):
        with patch("standard_ci.starters.subprocess.run") as run:
            run.return_value = _completed()
            _run_gh(["repo", "view", "x"])
        assert run.call_args.kwargs["timeout"] == 30

    def test_failure_raises_with_command_and_stderr(self):
        with patch("standard_ci.starters.subprocess.run") as run:
            run.return_value = _completed(returncode=1, stderr=" no luck\n")
            with pytest.raises(RuntimeError, match=r"^gh repo view x: no luck$"):
                _run_gh(["repo", "view", "x"])

    def test_failure_is_returned_when_status_is_not_checked(self):
        with patch("standard_ci.starters.subprocess.run") as run:
            run.return_value = _completed(returncode=1)
            assert _run_gh(["repo", "view", "x"], check_rc=False) == ("", 1)

    def test_success_does_not_raise_when_status_is_checked(self):
        with patch("standard_ci.starters.subprocess.run") as run:
            run.return_value = _completed(returncode=0, stderr="warning")
            assert _run_gh(["repo", "view", "x"], check_rc=True) == ("", 0)


class TestInstallStarters:
    def test_existing_repo_is_cloned_written_committed_and_pushed(self):
        fake = _FakeProcesses(view_rc=0)
        messages = _install(fake)
        assert messages[0] == "Pushed 7 files to org/.github"
        assert messages[1:] == [
            f"  {path}" for path in sorted(generate_all_files(FAKE_SHA, FAKE_TAG))
        ]
        assert ["gh", "repo", "create"] not in [c[:3] for c in fake.commands()]
        assert fake.kwargs_of(["git", "clone"])["timeout"] == 30
        assert ["git", "commit", "-m"] == fake.commands()[-2][:3]
        assert fake.commands()[-2][3] == (
            f"feat: update starter workflow templates to {FAKE_TAG}"
        )
        assert fake.commands()[-1] == ["git", "push"]
        assert fake.kwargs_of(["git", "push"])["timeout"] == 30

    def test_clone_url_is_the_orgs_dot_github_repo(self):
        fake = _FakeProcesses()
        _install(fake)
        clone = [c for c in fake.commands() if c[:2] == ["git", "clone"]][0]
        assert clone[2] == "git@github.com:org/.github.git"

    def test_missing_repo_without_create_flag_raises_and_creates_nothing(self):
        fake = _FakeProcesses(view_rc=1)
        with pytest.raises(RuntimeError, match=r"org/\.github does not exist"):
            _install(fake, create_repo=False)
        assert [c[:3] for c in fake.commands()] == [["gh", "repo", "view"]]

    def test_missing_repo_with_create_flag_creates_it_public_then_pushes(self):
        fake = _FakeProcesses(view_rc=1)
        messages = _install(fake, create_repo=True)
        create = [c for c in fake.commands() if c[:3] == ["gh", "repo", "create"]]
        assert len(create) == 1
        assert create[0][3:5] == ["org/.github", "--public"]
        assert messages[0] == "Created repo: org/.github"
        assert messages[1] == "Pushed 7 files to org/.github"

    def test_clean_working_tree_reports_up_to_date_and_pushes_nothing(self):
        fake = _FakeProcesses(status_out="  \n")
        messages = _install(fake)
        assert messages == ["No changes — starter workflows already up to date."]
        assert ["git", "push"] not in fake.commands()
        assert not [c for c in fake.commands() if c[:2] == ["git", "commit"]]

    def test_push_failure_raises_with_stderr(self):
        fake = _FakeProcesses(push_rc=1, push_err=" rejected\n")
        with pytest.raises(RuntimeError, match=r"^git push failed: rejected$"):
            _install(fake)

    def test_dry_run_with_create_flag_lists_the_plan_and_runs_nothing(self):
        fake = _FakeProcesses()
        messages = _install(fake, dry_run=True, create_repo=True)
        assert messages[:3] == [
            "Target: org/.github",
            "Would create repo if missing: org/.github",
            "Would write 7 files:",
        ]
        assert fake.calls == []
