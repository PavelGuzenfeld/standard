"""End-to-end tests for the standard-ci CLI."""

import json
from unittest import mock

import pytest

from standard_ci.checker import check
from standard_ci.cli import main
from standard_ci.config import read_config, write_config
from standard_ci.workflows import ALL_WORKFLOWS

FAKE_SHA = "abc123def456789012345678901234567890abcd"
FAKE_TAG = "v2.2.3.4"


def _mock_resolve(tag=None):
    return FAKE_SHA, FAKE_TAG


class TestCLIInit:
    def test_init_minimal_noninteractive_cpp(self, tmp_path):
        project = tmp_path / "myproject"
        project.mkdir()
        (project / "CMakeLists.txt").touch()

        with mock.patch("standard_ci.cli.resolve_tag_sha", side_effect=_mock_resolve):
            main(
                [
                    "init",
                    "--preset",
                    "minimal",
                    "--non-interactive",
                    "--output-dir",
                    str(project),
                ]
            )

        wf_dir = project / ".github" / "workflows"
        assert (wf_dir / "cpp-quality.yml").exists()
        assert (wf_dir / "infra-lint.yml").exists()

        config = read_config(str(project / ".standard.yml"))
        assert config["preset"] == "minimal"
        assert config["sha"] == FAKE_SHA
        assert config["tag"] == FAKE_TAG
        assert "cpp-quality" in config["workflows"]

        content = (wf_dir / "cpp-quality.yml").read_text()
        assert FAKE_SHA in content
        assert FAKE_TAG in content

    def test_init_recommended_noninteractive_python(self, tmp_path):
        project = tmp_path / "pyproject"
        project.mkdir()
        (project / "pyproject.toml").touch()

        with mock.patch("standard_ci.cli.resolve_tag_sha", side_effect=_mock_resolve):
            main(
                [
                    "init",
                    "--preset",
                    "recommended",
                    "--non-interactive",
                    "--output-dir",
                    str(project),
                ]
            )

        wf_dir = project / ".github" / "workflows"
        assert (wf_dir / "python-quality.yml").exists()
        assert (wf_dir / "sast-python.yml").exists()
        assert (wf_dir / "infra-lint.yml").exists()
        assert not (wf_dir / "cpp-quality.yml").exists()

    def test_init_full_noninteractive_both(self, tmp_path):
        project = tmp_path / "fullproject"
        project.mkdir()
        (project / "CMakeLists.txt").touch()
        (project / "pyproject.toml").touch()

        with mock.patch("standard_ci.cli.resolve_tag_sha", side_effect=_mock_resolve):
            main(
                [
                    "init",
                    "--preset",
                    "full",
                    "--non-interactive",
                    "--output-dir",
                    str(project),
                ]
            )

        wf_dir = project / ".github" / "workflows"
        assert (wf_dir / "cpp-quality.yml").exists()
        assert (wf_dir / "python-quality.yml").exists()
        assert (wf_dir / "sast-python.yml").exists()
        assert (wf_dir / "infra-lint.yml").exists()

        content = (wf_dir / "cpp-quality.yml").read_text()
        assert "enable_clang_format: true" in content
        assert "ban_cout: true" in content


class TestCLICheck:
    def test_check_passes(self, tmp_path):
        project = tmp_path / "checkproject"
        project.mkdir()
        (project / "CMakeLists.txt").touch()

        with mock.patch("standard_ci.cli.resolve_tag_sha", side_effect=_mock_resolve):
            main(
                [
                    "init",
                    "--preset",
                    "minimal",
                    "--non-interactive",
                    "--output-dir",
                    str(project),
                ]
            )

        cpp_quality = project / ".github" / "workflows" / "cpp-quality.yml"
        cpp_quality.write_text(
            cpp_quality.read_text().replace("REQUIRED_DOCKER_IMAGE", "ghcr.io/o/i:1")
        )
        main(["check", "--output-dir", str(project)])

    def test_check_fails_no_config(self, tmp_path, capsys):
        try:
            main(["check", "--output-dir", str(tmp_path)])
            assert False, "Should have exited"
        except SystemExit as e:
            assert e.code == 1
        captured = capsys.readouterr()
        assert "not found" in captured.out


class TestCLIUpdate:
    def test_update_dry_run(self, tmp_path, capsys):
        project = tmp_path / "updateproject"
        project.mkdir()
        (project / "CMakeLists.txt").touch()

        with mock.patch("standard_ci.cli.resolve_tag_sha", side_effect=_mock_resolve):
            main(
                [
                    "init",
                    "--preset",
                    "minimal",
                    "--non-interactive",
                    "--output-dir",
                    str(project),
                ]
            )

        new_sha = "new123def456789012345678901234567890neww"
        new_tag = "v3.0.0"

        def _mock_new(tag=None):
            return new_sha, new_tag

        with mock.patch("standard_ci.cli.resolve_tag_sha", side_effect=_mock_new):
            main(
                [
                    "update",
                    "--dry-run",
                    "--output-dir",
                    str(project),
                ]
            )

        captured = capsys.readouterr()
        assert "Would update" in captured.out

        content = (project / ".github" / "workflows" / "cpp-quality.yml").read_text()
        assert FAKE_SHA in content

    def test_update_applies(self, tmp_path):
        project = tmp_path / "updateproject2"
        project.mkdir()
        (project / "CMakeLists.txt").touch()

        with mock.patch("standard_ci.cli.resolve_tag_sha", side_effect=_mock_resolve):
            main(
                [
                    "init",
                    "--preset",
                    "minimal",
                    "--non-interactive",
                    "--output-dir",
                    str(project),
                ]
            )

        new_sha = "new123def456789012345678901234567890neww"
        new_tag = "v3.0.0"

        def _mock_new(tag=None):
            return new_sha, new_tag

        with mock.patch("standard_ci.cli.resolve_tag_sha", side_effect=_mock_new):
            main(
                [
                    "update",
                    "--output-dir",
                    str(project),
                ]
            )

        content = (project / ".github" / "workflows" / "cpp-quality.yml").read_text()
        assert new_sha in content
        assert FAKE_SHA not in content

        config = read_config(str(project / ".standard.yml"))
        assert config["sha"] == new_sha
        assert config["tag"] == new_tag


NEW_SHA = "b" * 40
OLD_SHA = "a" * 40


def _exit_code(argv):
    with pytest.raises(SystemExit) as excinfo:
        main(argv)
    return excinfo.value.code


def _init(project, *extra):
    with mock.patch("standard_ci.cli.resolve_tag_sha", side_effect=_mock_resolve):
        main(["init", "--output-dir", str(project), *extra])


class TestInitPrompts:
    def _answers(self, asked, overrides):
        def fake_yn(question, default=True):
            asked.append(question)
            if question in overrides:
                return overrides[question]
            return default

        return fake_yn

    def _fake_value(self, asked):
        def fake_value(question, default=""):
            asked.append(question)
            return "ghcr.io/o/i:1"

        return fake_value

    def test_interactive_init_without_markers_asks_languages_and_honours_answers(
        self, tmp_path
    ):
        asked = []
        overrides = {"Enable C++ workflows?": True, "  Enable clang-format?": False}
        with mock.patch(
            "standard_ci.cli.ask_yn", side_effect=self._answers(asked, overrides)
        ), mock.patch(
            "standard_ci.prompt.ask_value", side_effect=self._fake_value(asked)
        ):
            _init(tmp_path, "--preset", "full")

        assert "Enable C++ workflows?" in asked
        assert "Enable Python workflows?" in asked
        wf_dir = tmp_path / ".github" / "workflows"
        assert (wf_dir / "cpp-quality.yml").exists()
        assert not (wf_dir / "python-quality.yml").exists()
        config = read_config(str(tmp_path / ".standard.yml"))
        assert config["cpp-quality"]["docker_image"] == "ghcr.io/o/i:1"
        assert config["cpp-quality"]["enable_clang_format"] is False

    def test_runtime_group_booleans_are_not_prompted(self, tmp_path):
        asked = []
        overrides = {
            "Enable C++ workflows?": True,
            "  Enable ASan/UBSan sanitizer tests?": False,
        }
        with mock.patch(
            "standard_ci.cli.ask_yn", side_effect=self._answers(asked, overrides)
        ), mock.patch(
            "standard_ci.prompt.ask_value", side_effect=self._fake_value(asked)
        ):
            _init(tmp_path, "--preset", "full")

        assert "  Enable ASan/UBSan sanitizer tests?" not in asked
        config = read_config(str(tmp_path / ".standard.yml"))
        assert config["cpp-quality"]["enable_sanitizers"] is True

    def test_detected_language_skips_the_language_questions(self, tmp_path):
        (tmp_path / "pyproject.toml").touch()
        asked = []
        with mock.patch(
            "standard_ci.cli.ask_yn", side_effect=self._answers(asked, {})
        ), mock.patch(
            "standard_ci.prompt.ask_value", side_effect=self._fake_value(asked)
        ):
            _init(tmp_path)

        assert "Enable C++ workflows?" not in asked
        assert "Enable Python workflows?" not in asked

    def test_non_interactive_init_without_markers_asks_nothing(self, tmp_path):
        with mock.patch(
            "standard_ci.cli.ask_yn", side_effect=AssertionError("prompted")
        ):
            _init(tmp_path, "--non-interactive")

        config = read_config(str(tmp_path / ".standard.yml"))
        assert config["workflows"] == ["infra-lint"]

    def test_empty_preset_required_input_is_prompted(self, tmp_path):
        (tmp_path / "CMakeLists.txt").touch()
        asked = []
        preset = {"recommended": {"cpp-quality": {"docker_image": ""}}}
        with mock.patch("standard_ci.cli.ALL_PRESETS", preset), mock.patch(
            "standard_ci.cli.ask_yn", side_effect=self._answers(asked, {})
        ), mock.patch(
            "standard_ci.prompt.ask_value", side_effect=self._fake_value(asked)
        ):
            _init(tmp_path)

        config = read_config(str(tmp_path / ".standard.yml"))
        assert config["cpp-quality"]["docker_image"] == "ghcr.io/o/i:1"

    def test_filled_preset_required_input_is_not_prompted(self, tmp_path):
        (tmp_path / "CMakeLists.txt").touch()
        asked = []
        preset = {"recommended": {"cpp-quality": {"docker_image": "preset/img:9"}}}
        with mock.patch("standard_ci.cli.ALL_PRESETS", preset), mock.patch(
            "standard_ci.cli.ask_yn", side_effect=self._answers(asked, {})
        ), mock.patch(
            "standard_ci.prompt.ask_value", side_effect=self._fake_value(asked)
        ):
            _init(tmp_path)

        config = read_config(str(tmp_path / ".standard.yml"))
        assert config["cpp-quality"]["docker_image"] == "preset/img:9"

    def test_workflow_missing_from_registry_is_skipped_and_the_rest_are_generated(
        self, tmp_path
    ):
        with mock.patch("standard_ci.cli.COMMON_WORKFLOWS", ["ghost", "infra-lint"]):
            _init(tmp_path, "--non-interactive")

        config = read_config(str(tmp_path / ".standard.yml"))
        assert config["workflows"] == ["infra-lint"]
        assert (tmp_path / ".github" / "workflows" / "infra-lint.yml").exists()


class TestPinnedTagMessage:
    def test_init_announces_the_pinned_tag_and_resolves_it(self, tmp_path, capsys):
        resolve = mock.Mock(side_effect=_mock_resolve)
        with mock.patch("standard_ci.cli.resolve_tag_sha", resolve):
            main(
                [
                    "init",
                    "--non-interactive",
                    "--pin",
                    "v1.2",
                    "--output-dir",
                    str(tmp_path),
                ]
            )
        resolve.assert_called_once_with("v1.2")
        assert "Resolving tag v1.2..." in capsys.readouterr().out

    def test_update_announces_the_pinned_tag(self, tmp_path, capsys):
        write_config(
            str(tmp_path / ".standard.yml"),
            {"tag": "v0.9", "sha": OLD_SHA, "workflows": []},
        )
        with mock.patch(
            "standard_ci.cli.resolve_tag_sha", return_value=(NEW_SHA, "v1.2")
        ):
            main(["update", "--pin", "v1.2", "--output-dir", str(tmp_path)])
        assert "Resolving tag v1.2..." in capsys.readouterr().out

    def test_install_starters_announces_the_pinned_tag(self, capsys):
        with mock.patch(
            "standard_ci.cli.resolve_tag_sha", return_value=(NEW_SHA, "v1.2")
        ), mock.patch("standard_ci.starters.install_starters", return_value=["done"]):
            main(["install-starters", "--org", "o", "--pin", "v1.2"])
        assert "Resolving tag v1.2..." in capsys.readouterr().out


class TestExitCodes:
    def test_init_exits_one_when_tag_cannot_be_resolved(self, tmp_path, capsys):
        with mock.patch(
            "standard_ci.cli.resolve_tag_sha", side_effect=RuntimeError("no tags")
        ):
            assert _exit_code(["init", "--output-dir", str(tmp_path)]) == 1
        assert "Error: no tags" in capsys.readouterr().err

    def test_update_exits_one_without_a_config(self, tmp_path, capsys):
        assert _exit_code(["update", "--output-dir", str(tmp_path)]) == 1
        assert ".standard.yml not found" in capsys.readouterr().err

    def test_update_exits_one_when_tag_cannot_be_resolved(self, tmp_path, capsys):
        write_config(str(tmp_path / ".standard.yml"), {"sha": OLD_SHA, "workflows": []})
        with mock.patch(
            "standard_ci.cli.resolve_tag_sha", side_effect=RuntimeError("no tags")
        ):
            assert _exit_code(["update", "--output-dir", str(tmp_path)]) == 1
        assert "Error: no tags" in capsys.readouterr().err

    def test_install_starters_exits_one_when_tag_cannot_be_resolved(self, capsys):
        with mock.patch(
            "standard_ci.cli.resolve_tag_sha", side_effect=RuntimeError("no tags")
        ):
            assert _exit_code(["install-starters", "--org", "o"]) == 1
        assert "Error: no tags" in capsys.readouterr().err

    def test_install_starters_exits_one_when_install_fails(self, capsys):
        with mock.patch(
            "standard_ci.cli.resolve_tag_sha", return_value=(NEW_SHA, "v1")
        ), mock.patch(
            "standard_ci.starters.install_starters",
            side_effect=RuntimeError("no .github repo"),
        ):
            assert _exit_code(["install-starters", "--org", "o"]) == 1
        assert "Error: no .github repo" in capsys.readouterr().err

    def test_no_subcommand_prints_usage_and_exits_one(self, capsys):
        assert _exit_code([]) == 1
        assert "usage: standard-ci" in capsys.readouterr().out


class TestUpdateWorkflowSelection:
    def _project(self, tmp_path, workflows, present):
        write_config(
            str(tmp_path / ".standard.yml"),
            {"tag": "v0.9.0", "sha": OLD_SHA, "workflows": workflows},
        )
        wf_dir = tmp_path / ".github" / "workflows"
        wf_dir.mkdir(parents=True)
        for name in present:
            (wf_dir / name).write_text(f"uses: x@{OLD_SHA} # v0.9.0\n")
        return wf_dir

    def _update(self, tmp_path):
        with mock.patch(
            "standard_ci.cli.resolve_tag_sha", return_value=(NEW_SHA, "v1.0.0")
        ):
            main(["update", "--output-dir", str(tmp_path)])

    def test_unknown_workflow_name_does_not_stop_later_workflows(
        self, tmp_path, capsys
    ):
        wf_dir = self._project(tmp_path, ["ghost", "infra-lint"], ["infra-lint.yml"])
        self._update(tmp_path)
        assert (
            wf_dir / "infra-lint.yml"
        ).read_text() == f"uses: x@{NEW_SHA} # v1.0.0\n"
        assert "Updated 1 workflow(s): v0.9.0 -> v1.0.0" in capsys.readouterr().out

    def test_missing_workflow_file_does_not_stop_later_workflows(
        self, tmp_path, capsys
    ):
        wf_dir = self._project(
            tmp_path, ["infra-lint", "python-quality"], ["python-quality.yml"]
        )
        self._update(tmp_path)
        assert (
            wf_dir / "python-quality.yml"
        ).read_text() == f"uses: x@{NEW_SHA} # v1.0.0\n"
        assert "Updated 1 workflow(s)" in capsys.readouterr().out

    def test_no_matching_workflow_reports_zero_updated(self, tmp_path, capsys):
        self._project(tmp_path, ["infra-lint"], [])
        self._update(tmp_path)
        assert "Updated 0 workflow(s): v0.9.0 -> v1.0.0" in capsys.readouterr().out

    def test_config_without_sha_leaves_workflow_files_untouched(self, tmp_path, capsys):
        write_config(
            str(tmp_path / ".standard.yml"),
            {"tag": "v0.9.0", "workflows": ["infra-lint"]},
        )
        wf_dir = tmp_path / ".github" / "workflows"
        wf_dir.mkdir(parents=True)
        (wf_dir / "infra-lint.yml").write_text("abc\n")
        self._update(tmp_path)
        assert (wf_dir / "infra-lint.yml").read_text() == "abc\n"
        assert "Updated 0 workflow(s)" in capsys.readouterr().out


class TestCheckOutput:
    def test_levels_are_labelled_and_warnings_do_not_fail(self, tmp_path, capsys):
        issues = [("ok", "fine"), ("warning", "hmm")]
        with mock.patch("standard_ci.cli.check", return_value=issues):
            main(["check", "--output-dir", str(tmp_path)])
        assert capsys.readouterr().out.splitlines() == ["OK: fine", "WARNING: hmm"]

    def test_errors_are_labelled_and_fail(self, tmp_path, capsys):
        with mock.patch("standard_ci.cli.check", return_value=[("error", "bad")]):
            assert _exit_code(["check", "--output-dir", str(tmp_path)]) == 1
        assert capsys.readouterr().out == "ERROR: bad\n"


SHA_A = "a" * 40
SHA_B = "b" * 40


def _checked_project(tmp_path, workflows, sha="", tag="", files=None):
    config = {"workflows": workflows}
    if sha:
        config["sha"] = sha
    if tag:
        config["tag"] = tag
    write_config(str(tmp_path / ".standard.yml"), config)
    wf_dir = tmp_path / ".github" / "workflows"
    wf_dir.mkdir(parents=True)
    for name, content in (files or {}).items():
        (wf_dir / name).write_text(content)
    return str(tmp_path)


def _pinned(wf_name, ref):
    ref_path = ALL_WORKFLOWS[wf_name]["ref_path"]
    return f"uses: PavelGuzenfeld/standard/{ref_path}@{ref}\n"


class TestCheckerIssues:
    def test_unknown_workflow_does_not_stop_the_remaining_checks(self, tmp_path):
        project = _checked_project(tmp_path, ["bogus", "cpp-quality"])
        assert check(project) == [
            ("warning", "Unknown workflow 'bogus' in .standard.yml"),
            ("error", "Missing workflow file: .github/workflows/cpp-quality.yml"),
        ]

    def test_missing_file_does_not_stop_the_remaining_checks(self, tmp_path):
        project = _checked_project(tmp_path, ["cpp-quality", "infra-lint"])
        assert check(project) == [
            ("error", "Missing workflow file: .github/workflows/cpp-quality.yml"),
            ("error", "Missing workflow file: .github/workflows/infra-lint.yml"),
        ]

    def test_matching_sha_reports_ok_with_count_and_tag(self, tmp_path):
        project = _checked_project(
            tmp_path,
            ["cpp-quality", "infra-lint"],
            sha=SHA_A,
            tag="v1.2.3",
            files={
                "cpp-quality.yml": _pinned("cpp-quality", SHA_A),
                "infra-lint.yml": _pinned("infra-lint", SHA_A),
            },
        )
        assert check(project) == [
            ("ok", "All 2 workflows match .standard.yml (v1.2.3)")
        ]

    def test_ok_message_omits_tag_when_config_has_none(self, tmp_path):
        project = _checked_project(
            tmp_path,
            ["cpp-quality"],
            files={"cpp-quality.yml": "name: whatever\n"},
        )
        assert check(project) == [("ok", "All 1 workflows match .standard.yml")]

    def test_sha_mismatch_warns_with_twelve_char_prefixes(self, tmp_path):
        project = _checked_project(
            tmp_path,
            ["cpp-quality"],
            sha=SHA_A,
            files={"cpp-quality.yml": _pinned("cpp-quality", SHA_B)},
        )
        assert check(project) == [
            (
                "warning",
                "cpp-quality.yml: SHA mismatch — "
                f"file has {'b' * 12}, config has {'a' * 12}",
            )
        ]

    def test_reference_without_full_sha_warns_not_pinned(self, tmp_path):
        project = _checked_project(
            tmp_path,
            ["cpp-quality"],
            sha=SHA_A,
            files={"cpp-quality.yml": _pinned("cpp-quality", "v1.2.3")},
        )
        assert check(project) == [
            ("warning", "cpp-quality.yml: not pinned to a full SHA")
        ]

    def test_file_not_referencing_the_workflow_is_not_sha_checked(self, tmp_path):
        project = _checked_project(
            tmp_path,
            ["cpp-quality"],
            sha=SHA_A,
            files={"cpp-quality.yml": "name: local copy\n"},
        )
        assert check(project) == [("ok", "All 1 workflows match .standard.yml")]


LATEST_SHA = "f" * 40


def _scan_row(repo, has_config, up_to_date, tag):
    return {
        "repo": repo,
        "has_config": has_config,
        "up_to_date": up_to_date,
        "current_tag": tag,
        "current_sha": None,
        "workflows": [],
        "issues": [],
    }


CURRENT = _scan_row("org/cur", True, True, "v1.0.0")
DRIFTED = [
    _scan_row("org/d1", True, False, "v0.9.0"),
    _scan_row("org/d2", True, False, "v0.9.0"),
]
UNCONFIGURED = [_scan_row(f"org/n{i}", False, False, None) for i in range(1, 5)]


def _patch_scan(results):
    return mock.patch(
        "standard_ci.scanner.scan_org", return_value=(results, "v1.0.0", LATEST_SHA)
    )


class TestScanReport:
    def test_each_repo_line_shows_its_status_and_bare_name(self, capsys):
        with _patch_scan([CURRENT] + DRIFTED + UNCONFIGURED):
            main(["scan", "--org", "org", "--token", "T"])
        err = capsys.readouterr().err
        assert f"  {'cur':<30} {'v1.0.0':<12} OK" in err
        assert f"  {'d1':<30} {'v0.9.0':<12} DRIFT -> v1.0.0" in err
        assert f"  {'n1':<30} {'':12} NO CONFIG" in err

    def test_summary_counts_current_drifted_and_unconfigured(self, capsys):
        with _patch_scan([CURRENT] + DRIFTED + UNCONFIGURED):
            main(["scan", "--org", "org", "--token", "T"])
        assert (
            "7 repos: 1 current, 2 drifted, 4 unconfigured" in capsys.readouterr().err
        )

    def test_scan_failure_exits_one(self, capsys):
        with mock.patch(
            "standard_ci.scanner.scan_org", side_effect=RuntimeError("rate limited")
        ):
            assert _exit_code(["scan", "--org", "org"]) == 1
        assert "Error: rate limited" in capsys.readouterr().err

    def test_exit_code_flag_fails_when_a_configured_repo_drifted(self):
        with _patch_scan([CURRENT] + DRIFTED):
            assert (
                _exit_code(["scan", "--org", "org", "--token", "T", "--exit-code"]) == 1
            )

    def test_exit_code_flag_passes_when_only_current_and_unconfigured(self):
        with _patch_scan([CURRENT] + UNCONFIGURED):
            main(["scan", "--org", "org", "--token", "T", "--exit-code"])

    def test_exit_code_flag_passes_when_every_configured_repo_is_current(self):
        with _patch_scan([CURRENT]):
            main(["scan", "--org", "org", "--token", "T", "--exit-code"])


class TestTokenResolution:
    def test_scan_prefers_the_explicit_token_over_the_environment(self, monkeypatch):
        monkeypatch.setenv("GITHUB_TOKEN", "from-env")
        with _patch_scan([]) as scan:
            main(["scan", "--org", "org", "--token", "explicit"])
        scan.assert_called_once_with("org", "explicit")

    def test_scan_falls_back_to_the_environment_token(self, monkeypatch):
        monkeypatch.setenv("GITHUB_TOKEN", "from-env")
        with _patch_scan([]) as scan:
            main(["scan", "--org", "org"])
        scan.assert_called_once_with("org", "from-env")

    def test_dashboard_prefers_the_explicit_token_over_the_environment(
        self, monkeypatch
    ):
        monkeypatch.setenv("GITHUB_TOKEN", "from-env")
        with _patch_scan([]) as scan:
            main(["dashboard", "--org", "org", "--token", "explicit"])
        scan.assert_called_once_with("org", "explicit")

    def test_dashboard_falls_back_to_the_environment_token(self, monkeypatch):
        monkeypatch.setenv("GITHUB_TOKEN", "from-env")
        with _patch_scan([]) as scan:
            main(["dashboard", "--org", "org"])
        scan.assert_called_once_with("org", "from-env")

    def test_auto_update_prefers_the_explicit_token_over_the_environment(
        self, monkeypatch
    ):
        monkeypatch.setenv("GITHUB_TOKEN", "from-env")
        with _patch_scan([]), mock.patch(
            "standard_ci.auto_update.auto_update_repos", return_value=[]
        ) as run:
            main(["auto-update", "--org", "org", "--token", "explicit"])
        assert run.call_args.kwargs["token"] == "explicit"

    def test_auto_update_falls_back_to_the_environment_token(self, monkeypatch):
        monkeypatch.setenv("GITHUB_TOKEN", "from-env")
        with _patch_scan([]), mock.patch(
            "standard_ci.auto_update.auto_update_repos", return_value=[]
        ) as run:
            main(["auto-update", "--org", "org"])
        assert run.call_args.kwargs["token"] == "from-env"


@pytest.fixture(params=["dashboard", "auto-update"])
def scan_consumer(request):
    return request.param


class TestScanResultsInput:
    def _argv(self, command, results_file):
        return [command, "--org", "org", "--scan-results", str(results_file)]

    def test_whitespace_only_file_is_reported_as_empty(
        self, scan_consumer, tmp_path, capsys
    ):
        results = tmp_path / "scan.json"
        results.write_text("  \n")
        assert _exit_code(self._argv(scan_consumer, results)) == 1
        assert "scan results file is empty" in capsys.readouterr().err

    def test_malformed_json_exits_one_naming_the_problem(
        self, scan_consumer, tmp_path, capsys
    ):
        results = tmp_path / "scan.json"
        results.write_text("{not json")
        assert _exit_code(self._argv(scan_consumer, results)) == 1
        assert "invalid JSON in scan results" in capsys.readouterr().err

    def test_missing_file_exits_one_naming_the_file(
        self, scan_consumer, tmp_path, capsys
    ):
        results = tmp_path / "absent.json"
        assert _exit_code(self._argv(scan_consumer, results)) == 1
        assert f"scan results file not found: {results}" in capsys.readouterr().err

    def test_live_scan_failure_exits_one(self, scan_consumer, capsys):
        with mock.patch(
            "standard_ci.scanner.scan_org", side_effect=RuntimeError("rate limited")
        ):
            assert _exit_code([scan_consumer, "--org", "org"]) == 1
        assert "Error: rate limited" in capsys.readouterr().err

    def test_dashboard_renders_a_valid_results_file(self, tmp_path, capsys):
        results = tmp_path / "scan.json"
        results.write_text(
            json.dumps({"repos": [], "latest_tag": "v7.7", "latest_sha": LATEST_SHA})
        )
        main(
            [
                "dashboard",
                "--org",
                "org",
                "--format",
                "json",
                "--scan-results",
                str(results),
            ]
        )
        assert json.loads(capsys.readouterr().out)["latest_tag"] == "v7.7"

    def test_auto_update_forwards_a_valid_results_file(self, tmp_path, capsys):
        results = tmp_path / "scan.json"
        results.write_text(
            json.dumps(
                {"repos": [DRIFTED[0]], "latest_tag": "v7.7", "latest_sha": LATEST_SHA}
            )
        )
        with mock.patch(
            "standard_ci.auto_update.auto_update_repos", return_value=["opened"]
        ) as run:
            main(["auto-update", "--org", "org", "--scan-results", str(results)])
        assert run.call_args.args == ([DRIFTED[0]], "v7.7", LATEST_SHA)
        assert capsys.readouterr().out == "opened\n"
