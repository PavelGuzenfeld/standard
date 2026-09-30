"""Tests for .standard.yml config read/write."""

from standard_ci.config import read_config, read_config_string, write_config


class TestConfigRoundtrip:
    def test_flat_values(self, tmp_path):
        path = str(tmp_path / ".standard.yml")
        data = {"version": "0.12.0", "preset": "recommended", "sha": "abc123"}
        write_config(path, data)
        result = read_config(path)
        assert result["version"] == "0.12.0"
        assert result["preset"] == "recommended"
        assert result["sha"] == "abc123"

    def test_nested_dict(self, tmp_path):
        path = str(tmp_path / ".standard.yml")
        data = {
            "version": "0.12.0",
            "cpp-quality": {
                "enable_clang_format": True,
                "ban_cout": False,
                "docker_image": "ghcr.io/org/image:latest",
            },
        }
        write_config(path, data)
        result = read_config(path)
        assert result["cpp-quality"]["enable_clang_format"] is True
        assert result["cpp-quality"]["ban_cout"] is False
        assert result["cpp-quality"]["docker_image"] == "ghcr.io/org/image:latest"

    def test_list_values(self, tmp_path):
        path = str(tmp_path / ".standard.yml")
        data = {"workflows": ["cpp-quality", "python-quality", "infra-lint"]}
        write_config(path, data)
        result = read_config(path)
        assert result["workflows"] == ["cpp-quality", "python-quality", "infra-lint"]

    def test_bool_values(self, tmp_path):
        path = str(tmp_path / ".standard.yml")
        data = {"enabled": True, "disabled": False}
        write_config(path, data)
        result = read_config(path)
        assert result["enabled"] is True
        assert result["disabled"] is False

    def test_empty_string(self, tmp_path):
        path = str(tmp_path / ".standard.yml")
        data = {"value": ""}
        write_config(path, data)
        result = read_config(path)
        assert result["value"] == ""

    def test_read_nonexistent(self, tmp_path):
        path = str(tmp_path / "missing.yml")
        assert read_config(path) == {}

    def test_numeric_values(self, tmp_path):
        path = str(tmp_path / ".standard.yml")
        data = {"count": 42, "ratio": 3.14}
        write_config(path, data)
        result = read_config(path)
        assert result["count"] == 42
        assert result["ratio"] == 3.14


class TestStringQuoting:
    def _written(self, tmp_path, value):
        path = tmp_path / ".standard.yml"
        write_config(str(path), {"key": value})
        return path.read_text().splitlines()[2]

    def test_value_with_colon_is_quoted(self, tmp_path):
        assert self._written(tmp_path, "a:b") == "key: 'a:b'"

    def test_plain_word_is_not_quoted(self, tmp_path):
        assert self._written(tmp_path, "hello") == "key: hello"

    def test_reserved_word_string_is_quoted_and_stays_a_string(self, tmp_path):
        path = tmp_path / ".standard.yml"
        write_config(str(path), {"key": "true"})
        assert path.read_text().splitlines()[2] == "key: 'true'"
        assert read_config(str(path))["key"] == "true"


class TestParsing:
    def test_empty_value_in_nested_mapping_is_none(self):
        assert read_config_string("a:\n  b: \n") == {"a": {"b": None}}

    def test_null_literal_is_none(self):
        assert read_config_string("a: null\n") == {"a": None}

    def test_comment_line_with_colon_is_ignored(self):
        assert read_config_string("# note: x\nkey: v\n") == {"key": "v"}

    def test_top_level_key_after_nested_block_is_not_nested(self):
        parsed = read_config_string("a:\n  b: 1\nc: 2\n")
        assert parsed == {"a": {"b": 1}, "c": 2}

    def test_indented_pair_with_no_open_key_is_read_as_top_level(self):
        assert read_config_string("  x: 1\n") == {"x": 1}
