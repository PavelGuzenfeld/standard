"""Tests for the dashboard module."""

import json

from standard_ci.dashboard import generate_dashboard


def _sample_results():
    return [
        {
            "repo": "org/alpha",
            "has_config": True,
            "current_tag": "v1.0.0",
            "current_sha": "sha111",
            "up_to_date": True,
            "workflows": ["cpp-quality", "infra-lint"],
            "issues": [],
        },
        {
            "repo": "org/beta",
            "has_config": True,
            "current_tag": "v0.9.0",
            "current_sha": "sha222",
            "up_to_date": False,
            "workflows": ["cpp-quality"],
            "issues": ["SHA drift: v0.9.0 -> v1.0.0"],
        },
        {
            "repo": "org/gamma",
            "has_config": False,
            "current_tag": None,
            "current_sha": None,
            "up_to_date": False,
            "workflows": [],
            "issues": ["No .standard.yml found"],
        },
    ]


class TestGenerateDashboardMarkdown:
    def test_contains_header(self):
        md = generate_dashboard(_sample_results(), "v1.0.0", "sha_latest", "org")
        assert "## Standard Compliance Dashboard" in md

    def test_contains_summary_counts(self):
        md = generate_dashboard(_sample_results(), "v1.0.0", "sha_latest", "org")
        assert "**3** repos scanned" in md
        assert "**1** compliant" in md
        assert "**1** drifted" in md
        assert "**1** unconfigured" in md

    def test_contains_repo_table(self):
        md = generate_dashboard(_sample_results(), "v1.0.0", "sha_latest", "org")
        assert "| alpha |" in md
        assert "| beta |" in md
        assert "| gamma |" in md

    def test_drift_details_section(self):
        md = generate_dashboard(_sample_results(), "v1.0.0", "sha_latest", "org")
        assert "### Drift Details" in md
        assert "beta" in md
        assert "v0.9.0" in md

    def test_no_drift_section_when_all_current(self):
        results = [_sample_results()[0]]
        md = generate_dashboard(results, "v1.0.0", "sha_latest", "org")
        assert "### Drift Details" not in md


class TestGenerateDashboardJSON:
    def test_valid_json(self):
        output = generate_dashboard(
            _sample_results(), "v1.0.0", "sha_latest", "org", fmt="json"
        )
        data = json.loads(output)
        assert data["org"] == "org"
        assert data["latest_tag"] == "v1.0.0"
        assert len(data["repos"]) == 3

    def test_contains_repo_data(self):
        output = generate_dashboard(
            _sample_results(), "v1.0.0", "sha_latest", "org", fmt="json"
        )
        data = json.loads(output)
        repos = {r["repo"]: r for r in data["repos"]}
        assert repos["org/alpha"]["up_to_date"]
        assert not repos["org/beta"]["up_to_date"]
        assert not repos["org/gamma"]["has_config"]


def _markdown_lines(results=None):
    if results is None:
        results = _sample_results()
    md = generate_dashboard(results, "v1.0.0", "f" * 40, "org", fmt="markdown")
    return md.splitlines()


class TestMarkdownRows:
    def test_header_shows_only_the_first_twelve_sha_characters(self):
        assert (
            "**Org:** org | **Latest:** v1.0.0 | **SHA:** `ffffffffffff`"
            in _markdown_lines()
        )

    def test_compliant_percentage_rounds_down(self):
        assert "- **1** compliant (33%)" in _markdown_lines()

    def test_compliant_percentage_is_zero_for_no_repos(self):
        assert "- **0** compliant (0%)" in _markdown_lines([])

    def test_current_repo_row_shows_its_tag_and_workflows(self):
        assert "| alpha | Yes | v1.0.0 | Current | cpp-quality, infra-lint |" in (
            _markdown_lines()
        )

    def test_drifted_repo_row_is_marked_drift_not_current(self):
        assert "| beta | Yes | v0.9.0 | **Drift** | cpp-quality |" in (
            _markdown_lines()
        )

    def test_unconfigured_repo_row_has_dash_placeholders(self):
        assert "| gamma | No | - | Unconfigured | - |" in _markdown_lines()

    def test_drift_row_shows_current_and_latest_tags(self):
        assert "| beta | v0.9.0 | v1.0.0 | Update needed |" in _markdown_lines()

    def test_drift_row_for_repo_without_tag_says_unknown(self):
        drifted = dict(_sample_results()[1], current_tag=None)
        assert "| beta | unknown | v1.0.0 | Update needed |" in _markdown_lines(
            [drifted]
        )


class TestJsonLayout:
    def test_json_is_indented_two_spaces(self):
        output = generate_dashboard([], "v1.0.0", "sha", "org", fmt="json")
        assert output == (
            '{\n  "org": "org",\n  "latest_tag": "v1.0.0",\n'
            '  "latest_sha": "sha",\n  "repos": []\n}'
        )
