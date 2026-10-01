import pytest

from standard_ci.checker import check
from standard_ci.cli import main

CONFIG = "workflows:\n  - cpp-quality\n"


def _project(tmp_path, extra_files):
    (tmp_path / ".standard.yml").write_text(CONFIG)
    wf_dir = tmp_path / ".github" / "workflows"
    wf_dir.mkdir(parents=True)
    (wf_dir / "cpp-quality.yml").write_text("name: C++ Quality\n")
    for name, text in extra_files.items():
        (wf_dir / name).write_text(text)
    return tmp_path


def _placeholder_errors(project):
    return [
        msg
        for level, msg in check(str(project))
        if level == "error" and "REQUIRED_" in msg
    ]


def test_placeholder_in_input_value_is_reported_with_file_key_and_line(tmp_path):
    text = "jobs:\n  q:\n    with:\n      docker_image: REQUIRED_DOCKER_IMAGE\n"
    project = _project(tmp_path, {"cpp-quality.yml": text})
    assert _placeholder_errors(project) == [
        "cpp-quality.yml:4: docker_image still has placeholder REQUIRED_DOCKER_IMAGE"
    ]


def test_placeholder_in_workflow_outside_config_is_reported(tmp_path):
    project = _project(tmp_path, {"extra.yaml": "with:\n  foo: REQUIRED_FOO\n"})
    assert _placeholder_errors(project) == [
        "extra.yaml:2: foo still has placeholder REQUIRED_FOO"
    ]


def test_every_placeholder_is_reported(tmp_path):
    text = "with:\n  a: REQUIRED_A\n  b: 1\n  c: REQUIRED_C\n"
    project = _project(tmp_path, {"cpp-quality.yml": text})
    assert len(_placeholder_errors(project)) == 2


def test_replaced_placeholder_gives_no_finding(tmp_path):
    text = "with:\n  docker_image: ghcr.io/org/img:1\n"
    project = _project(tmp_path, {"cpp-quality.yml": text})
    assert _placeholder_errors(project) == []


def test_placeholder_in_comment_is_ignored(tmp_path):
    text = "with:\n  # docker_image: REQUIRED_DOCKER_IMAGE\n  a: 1 # REQUIRED_A\n"
    project = _project(tmp_path, {"cpp-quality.yml": text})
    assert _placeholder_errors(project) == []


def test_required_prefix_in_key_or_inside_value_is_ignored(tmp_path):
    text = "env:\n  REQUIRED_TOKEN: abc\n  note: see REQUIRED_NOTE\n"
    project = _project(tmp_path, {"cpp-quality.yml": text})
    assert _placeholder_errors(project) == []


def test_quoted_placeholder_is_reported(tmp_path):
    project = _project(tmp_path, {"cpp-quality.yml": "with:\n  a: 'REQUIRED_A'\n"})
    assert len(_placeholder_errors(project)) == 1


def test_cli_exits_one_on_placeholder(tmp_path, capsys):
    project = _project(tmp_path, {"cpp-quality.yml": "with:\n  a: REQUIRED_A\n"})
    with pytest.raises(SystemExit) as excinfo:
        main(["check", "--output-dir", str(project)])
    assert excinfo.value.code == 1
    assert "ERROR: cpp-quality.yml:2: a still has placeholder REQUIRED_A" in (
        capsys.readouterr().out
    )
