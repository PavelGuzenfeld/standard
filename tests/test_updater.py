"""Tests for tag and SHA resolution."""

import json
from unittest.mock import MagicMock, patch

import pytest

from standard_ci.updater import _resolve_via_api, _resolve_via_git, resolve_tag_sha

SHA_NEW = "1" * 40
SHA_OLD = "2" * 40
SHA_OLDEST = "3" * 40


def _api_response(tags):
    response = MagicMock()
    response.read.return_value = json.dumps(tags).encode()
    response.__enter__ = lambda s: s
    response.__exit__ = MagicMock(return_value=False)
    return response


def _tag_entry(name, sha):
    return {"name": name, "commit": {"sha": sha}}


API_TAGS = [
    _tag_entry("v3.0.0", SHA_NEW),
    _tag_entry("v2.0.0", SHA_OLD),
    _tag_entry("v1.0.0", SHA_OLDEST),
]


def _git_result(stdout="", returncode=0, stderr=""):
    return MagicMock(returncode=returncode, stdout=stdout, stderr=stderr)


def _ls_remote(*pairs):
    return "".join(f"{sha}\trefs/tags/{name}\n" for sha, name in pairs)


class TestResolveViaApi:
    @patch("standard_ci.updater.urllib.request.urlopen")
    def test_latest_is_the_first_tag_listed(self, mock_urlopen):
        mock_urlopen.return_value = _api_response(API_TAGS)
        assert _resolve_via_api(None) == (SHA_NEW, "v3.0.0")

    @patch("standard_ci.updater.urllib.request.urlopen")
    def test_named_tag_returns_that_tags_sha(self, mock_urlopen):
        mock_urlopen.return_value = _api_response(API_TAGS)
        assert _resolve_via_api("v1.0.0") == (SHA_OLDEST, "v1.0.0")

    @patch("standard_ci.updater.urllib.request.urlopen")
    def test_unknown_tag_raises(self, mock_urlopen):
        mock_urlopen.return_value = _api_response(API_TAGS)
        with pytest.raises(RuntimeError, match="Tag v9.9.9 not found"):
            _resolve_via_api("v9.9.9")

    @patch("standard_ci.updater.urllib.request.urlopen")
    def test_empty_tag_list_raises(self, mock_urlopen):
        mock_urlopen.return_value = _api_response([])
        with pytest.raises(RuntimeError, match="No tags found"):
            _resolve_via_api(None)

    @patch("standard_ci.updater.urllib.request.urlopen")
    def test_request_times_out_after_ten_seconds(self, mock_urlopen):
        mock_urlopen.return_value = _api_response(API_TAGS)
        _resolve_via_api(None)
        assert mock_urlopen.call_args.kwargs["timeout"] == 10


class TestResolveViaGit:
    @patch("standard_ci.updater.subprocess.run")
    def test_latest_is_the_highest_version_not_the_last_listed(self, mock_run):
        mock_run.return_value = _git_result(
            _ls_remote(
                (SHA_OLD, "v1.9.0"),
                (SHA_OLDEST, "v1.10.0"),
                (SHA_OLD, "v1.2.0"),
                (SHA_NEW, "v1.11.0"),
            )
        )
        assert _resolve_via_git(None) == (SHA_NEW, "v1.11.0")

    @patch("standard_ci.updater.subprocess.run")
    def test_latest_is_the_highest_even_when_listed_first(self, mock_run):
        mock_run.return_value = _git_result(
            _ls_remote((SHA_NEW, "v3.0.0"), (SHA_OLD, "v2.0.0"), (SHA_OLDEST, "v1.0.0"))
        )
        assert _resolve_via_git(None) == (SHA_NEW, "v3.0.0")

    @patch("standard_ci.updater.subprocess.run")
    def test_named_tag_returns_that_tags_sha(self, mock_run):
        mock_run.return_value = _git_result(
            _ls_remote((SHA_NEW, "v3.0.0"), (SHA_OLD, "v2.0.0"))
        )
        assert _resolve_via_git("v2.0.0") == (SHA_OLD, "v2.0.0")

    @patch("standard_ci.updater.subprocess.run")
    def test_unknown_tag_raises(self, mock_run):
        mock_run.return_value = _git_result(_ls_remote((SHA_NEW, "v3.0.0")))
        with pytest.raises(RuntimeError, match="Tag v9.9.9 not found via git"):
            _resolve_via_git("v9.9.9")

    @patch("standard_ci.updater.subprocess.run")
    def test_peeled_annotated_tag_ref_loses_its_suffix(self, mock_run):
        mock_run.return_value = _git_result(f"{SHA_NEW}\trefs/tags/v3.0.0^{{}}\n")
        assert _resolve_via_git(None) == (SHA_NEW, "v3.0.0")

    @patch("standard_ci.updater.subprocess.run")
    def test_empty_listing_raises(self, mock_run):
        mock_run.return_value = _git_result("")
        with pytest.raises(RuntimeError, match="No tags found via git ls-remote"):
            _resolve_via_git(None)

    @patch("standard_ci.updater.subprocess.run")
    def test_nonzero_exit_raises_with_stderr(self, mock_run):
        mock_run.return_value = _git_result(returncode=128, stderr="fatal: boom\n")
        with pytest.raises(RuntimeError, match="git ls-remote failed: fatal: boom$"):
            _resolve_via_git(None)

    @patch("standard_ci.updater.subprocess.run")
    def test_exit_status_one_is_also_a_failure(self, mock_run):
        mock_run.return_value = _git_result(
            _ls_remote((SHA_NEW, "v3.0.0")), returncode=1, stderr="denied"
        )
        with pytest.raises(RuntimeError, match="git ls-remote failed: denied"):
            _resolve_via_git(None)

    @patch("standard_ci.updater.subprocess.run", side_effect=FileNotFoundError)
    def test_missing_git_binary_raises(self, mock_run):
        with pytest.raises(RuntimeError, match="git not found"):
            _resolve_via_git(None)

    @patch("standard_ci.updater.subprocess.run")
    def test_ls_remote_times_out_after_fifteen_seconds(self, mock_run):
        mock_run.return_value = _git_result(_ls_remote((SHA_NEW, "v3.0.0")))
        _resolve_via_git(None)
        assert mock_run.call_args.kwargs["timeout"] == 15


class TestResolveTagSha:
    @patch("standard_ci.updater.subprocess.run")
    @patch("standard_ci.updater.urllib.request.urlopen", side_effect=OSError("down"))
    def test_api_failure_falls_back_to_git(self, mock_urlopen, mock_run):
        mock_run.return_value = _git_result(_ls_remote((SHA_OLD, "v2.0.0")))
        assert resolve_tag_sha() == (SHA_OLD, "v2.0.0")
