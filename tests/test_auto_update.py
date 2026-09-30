"""Tests for the auto_update module."""

import os
from unittest import mock
from unittest.mock import patch

import pytest

from standard_ci.auto_update import (
    _check_existing_pr,
    _run,
    _run_checked,
    _update_single_repo,
    auto_update_repos,
)


def _sample_scan_results():
    return [
        {
            "repo": "org/current-repo",
            "has_config": True,
            "current_tag": "v1.0.0",
            "current_sha": "sha_latest",
            "up_to_date": True,
            "workflows": ["cpp-quality"],
            "issues": [],
        },
        {
            "repo": "org/drifted-repo",
            "has_config": True,
            "current_tag": "v0.9.0",
            "current_sha": "sha_old",
            "up_to_date": False,
            "workflows": ["cpp-quality"],
            "issues": ["SHA drift: v0.9.0 -> v1.0.0"],
        },
        {
            "repo": "org/no-config",
            "has_config": False,
            "current_tag": None,
            "current_sha": None,
            "up_to_date": False,
            "workflows": [],
            "issues": ["No .standard.yml found"],
        },
    ]


class TestAutoUpdateRepos:
    def test_dry_run_no_side_effects(self):
        messages = auto_update_repos(
            _sample_scan_results(),
            latest_tag="v1.0.0",
            latest_sha="sha_latest",
            dry_run=True,
            token="test-token",
        )
        assert any("Would update org/drifted-repo" in m for m in messages)
        assert not any("current-repo" in m for m in messages)
        assert not any("no-config" in m for m in messages)

    def test_skips_up_to_date(self):
        results = [_sample_scan_results()[0]]
        messages = auto_update_repos(
            results,
            latest_tag="v1.0.0",
            latest_sha="sha_latest",
            dry_run=True,
            token="test-token",
        )
        assert any("up to date" in m.lower() for m in messages)

    def test_skips_no_config(self):
        results = [_sample_scan_results()[2]]
        messages = auto_update_repos(
            results,
            latest_tag="v1.0.0",
            latest_sha="sha_latest",
            dry_run=True,
            token="test-token",
        )
        assert any("up to date" in m.lower() for m in messages)

    @patch("standard_ci.auto_update._check_existing_pr", return_value=True)
    def test_skips_existing_pr(self, mock_check):
        results = [_sample_scan_results()[1]]
        messages = auto_update_repos(
            results,
            latest_tag="v1.0.0",
            latest_sha="sha_latest",
            dry_run=False,
            token="test-token",
        )
        assert any("already open" in m.lower() for m in messages)

    @patch("standard_ci.auto_update._check_existing_pr", return_value=False)
    @patch("standard_ci.auto_update._update_single_repo")
    def test_opens_pr_for_drifted(self, mock_update, mock_check):
        results = [_sample_scan_results()[1]]
        messages = auto_update_repos(
            results,
            latest_tag="v1.0.0",
            latest_sha="sha_latest",
            dry_run=False,
            token="test-token",
        )
        mock_update.assert_called_once()
        assert any("Opened PR" in m for m in messages)

    @patch("standard_ci.auto_update._check_existing_pr", return_value=False)
    @patch("standard_ci.auto_update._update_single_repo", side_effect=RuntimeError("clone failed"))
    def test_handles_failure_gracefully(self, mock_update, mock_check):
        results = [_sample_scan_results()[1]]
        messages = auto_update_repos(
            results,
            latest_tag="v1.0.0",
            latest_sha="sha_latest",
            dry_run=False,
            token="test-token",
        )
        assert any("Failed" in m for m in messages)


def _drifted(repo, tag="v0.9.0", sha="sha_old"):
    return {
        "repo": repo,
        "has_config": True,
        "current_tag": tag,
        "current_sha": sha,
        "up_to_date": False,
        "workflows": [],
        "issues": [],
    }


def _completed(stdout="", returncode=0, stderr=""):
    return mock.Mock(stdout=stdout, returncode=returncode, stderr=stderr)


class TestSubprocessHelpers:
    def test_run_strips_stdout_and_returns_exit_code(self):
        with mock.patch("standard_ci.auto_update.subprocess.run",
                        return_value=_completed("out\n", 3)):
            assert _run(["x"]) == ("out", 3)

    def test_run_defaults_to_thirty_second_timeout(self):
        with mock.patch("standard_ci.auto_update.subprocess.run",
                        return_value=_completed()) as run:
            _run(["x"])
        assert run.call_args.kwargs["timeout"] == 30

    def test_run_checked_defaults_to_thirty_second_timeout(self):
        with mock.patch("standard_ci.auto_update.subprocess.run",
                        return_value=_completed()) as run:
            _run_checked(["x"])
        assert run.call_args.kwargs["timeout"] == 30

    def test_run_checked_returns_stdout_on_exit_zero(self):
        with mock.patch("standard_ci.auto_update.subprocess.run",
                        return_value=_completed("fine\n", 0)):
            assert _run_checked(["x"]) == "fine"

    def test_run_checked_raises_with_stderr_on_exit_one(self):
        with mock.patch("standard_ci.auto_update.subprocess.run",
                        return_value=_completed("", 1, "boom\n")):
            with pytest.raises(RuntimeError, match="failed: boom"):
                _run_checked(["git", "push", "origin"])


class TestCheckExistingPr:
    def _check(self, stdout, returncode=0):
        with mock.patch("standard_ci.auto_update.subprocess.run",
                        return_value=_completed(stdout, returncode)) as run:
            found = _check_existing_pr("org/r", "branch", token="T")
        return found, run

    def test_one_open_pr_is_found(self):
        found, _ = self._check('[{"number": 7}]')
        assert found is True

    def test_empty_pr_list_is_not_found(self):
        found, _ = self._check("[]")
        assert found is False

    def test_gh_failure_exit_one_is_not_found_even_with_output(self):
        found, _ = self._check('[{"number": 7}]', returncode=1)
        assert found is False

    def test_unparseable_output_is_not_found(self):
        found, _ = self._check("not json")
        assert found is False

    def test_null_output_is_not_found(self):
        found, _ = self._check(None)
        assert found is False

    def test_gh_call_has_fifteen_second_timeout_and_token(self):
        _, run = self._check("[]")
        assert run.call_args.kwargs["timeout"] == 15
        assert run.call_args.kwargs["env"]["GH_TOKEN"] == "T"


class TestAutoUpdateReposDispatch:
    def test_dry_run_reports_old_tag_and_unknown_when_tag_missing(self):
        repos = [_drifted("org/a", tag="v0.9.0"), _drifted("org/b", tag=None)]
        messages = auto_update_repos(repos, "v1.0.0", "sha_new", dry_run=True, token="T")
        assert messages == [
            "Would update org/a: v0.9.0 -> v1.0.0",
            "Would update org/b: unknown -> v1.0.0",
        ]

    @patch("standard_ci.auto_update._check_existing_pr", return_value=True)
    def test_every_repo_with_open_pr_is_skipped_not_just_the_first(self, _check):
        repos = [_drifted("org/a"), _drifted("org/b")]
        messages = auto_update_repos(repos, "v1.0.0", "sha_new", token="T")
        assert [m.split(":")[0] for m in messages] == ["Skipped org/a", "Skipped org/b"]

    @patch("standard_ci.auto_update._update_single_repo")
    @patch("standard_ci.auto_update._check_existing_pr", return_value=False)
    def test_old_sha_and_old_tag_are_forwarded_with_empty_sha_for_none(self, _check, update):
        repos = [_drifted("org/a", sha="sha_old"), _drifted("org/b", tag=None, sha=None)]
        auto_update_repos(repos, "v1.0.0", "sha_new", token="T")
        first, second = update.call_args_list
        assert first.args[:5] == ("org/a", "sha_old", "v0.9.0", "sha_new", "v1.0.0")
        assert second.args[:5] == ("org/b", "", "unknown", "sha_new", "v1.0.0")

    @patch("standard_ci.auto_update._check_existing_pr", return_value=True)
    def test_explicit_token_is_used_over_environment(self, check, monkeypatch):
        monkeypatch.setenv("GITHUB_TOKEN", "from-env")
        auto_update_repos([_drifted("org/a")], "v1.0.0", "sha_new", token="explicit")
        assert check.call_args.args[2] == "explicit"

    @patch("standard_ci.auto_update._check_existing_pr", return_value=True)
    def test_environment_token_is_used_when_none_given(self, check, monkeypatch):
        monkeypatch.setenv("GITHUB_TOKEN", "from-env")
        auto_update_repos([_drifted("org/a")], "v1.0.0", "sha_new")
        assert check.call_args.args[2] == "from-env"


SHA_OLD = "a" * 40
SHA_NEW = "b" * 40


class _CloneHarness:
    def __init__(self, files):
        self.files = files
        self.commands = []
        self.written = {}
        self.gh_call = None

    def run_checked(self, args, cwd=None, timeout=30):
        self.commands.append(list(args))
        if args[:2] == ["git", "clone"]:
            wf_dir = os.path.join(args[-1], ".github", "workflows")
            os.makedirs(wf_dir)
            for name, content in self.files.items():
                with open(os.path.join(wf_dir, name), "w") as f:
                    f.write(content)
        if args[:2] == ["git", "add"]:
            wf_dir = os.path.join(cwd, ".github", "workflows")
            for name in os.listdir(wf_dir):
                with open(os.path.join(wf_dir, name)) as f:
                    self.written[name] = f.read()
        return ""

    def run(self, old_sha="", old_tag="v0.9.0", dirty=" M x"):
        real_listdir = os.listdir

        def listdir_non_workflow_first(path):
            return sorted(real_listdir(path), key=lambda n: n.endswith((".yml", ".yaml")))

        with mock.patch("standard_ci.auto_update._run_checked", side_effect=self.run_checked), \
                mock.patch("standard_ci.auto_update._run", return_value=(dirty, 0)), \
                mock.patch("standard_ci.auto_update.os.listdir",
                           side_effect=listdir_non_workflow_first), \
                mock.patch("standard_ci.auto_update.subprocess.run",
                           return_value=_completed()) as run:
            _update_single_repo(
                "org/a", old_sha, old_tag, SHA_NEW, "v1.0.0",
                "standard-ci/update-v1.0.0", "chore(deps): update standard to v1.0.0",
                "dependencies, standard-ci", "T",
            )
        self.gh_call = run.call_args
        return self

    def git_verbs(self):
        return [c[1] for c in self.commands if c[0] == "git"]


class TestUpdateSingleRepo:
    def test_yml_and_yaml_workflows_are_rewritten_and_other_files_are_not(self):
        text = f"uses: x@{SHA_OLD} # v0.9.0\n"
        harness = _CloneHarness({"a.txt": text, "b.yml": text, "c.yaml": text}).run(SHA_OLD)
        rewritten = f"uses: x@{SHA_NEW} # v1.0.0\n"
        assert harness.written == {"a.txt": text, "b.yml": rewritten, "c.yaml": rewritten}

    def test_empty_old_sha_leaves_the_sha_but_still_moves_the_tag_comment(self):
        harness = _CloneHarness({"b.yml": f"uses: x@{SHA_OLD} # v0.9.0\n"}).run(old_sha="")
        assert harness.written == {"b.yml": f"uses: x@{SHA_OLD} # v1.0.0\n"}

    def test_empty_old_tag_does_not_rewrite_ordinary_comments(self):
        harness = _CloneHarness({"b.yml": f"# keep\nuses: x@{SHA_OLD}\n"}).run(SHA_OLD, old_tag="")
        assert harness.written == {"b.yml": f"# keep\nuses: x@{SHA_NEW}\n"}

    def test_clean_clone_makes_no_commit_push_or_pr(self):
        harness = _CloneHarness({"b.yml": "nothing\n"}).run(SHA_OLD, dirty="")
        assert harness.git_verbs() == ["clone", "checkout"]
        assert harness.gh_call is None

    def test_dirty_clone_is_committed_pushed_and_opened_as_a_pr(self):
        harness = _CloneHarness({"b.yml": f"x@{SHA_OLD}\n"}).run(SHA_OLD)
        assert harness.git_verbs() == ["clone", "checkout", "add", "commit", "push"]
        cmd = harness.gh_call.args[0]
        assert cmd[:8] == [
            "gh", "pr", "create", "--repo", "org/a",
            "--title", "chore(deps): update standard to v1.0.0",
            "--body",
        ]
        assert "v0.9.0" in cmd[8] and "v1.0.0" in cmd[8]
        assert cmd[9:] == [
            "--head", "standard-ci/update-v1.0.0",
            "--label", "dependencies", "--label", "standard-ci",
        ]
        assert harness.gh_call.kwargs["timeout"] == 30
