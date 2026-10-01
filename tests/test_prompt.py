"""Tests for the interactive prompt helpers."""

from unittest.mock import patch

import pytest

from standard_ci.prompt import ask_value, ask_yn


def _answer(text):
    return patch("builtins.input", return_value=text)


class TestAskYn:
    def test_blank_answer_takes_a_true_default(self):
        with _answer("  "):
            assert ask_yn("Go?", default=True) is True

    def test_blank_answer_takes_a_false_default(self):
        with _answer(""):
            assert ask_yn("Go?", default=False) is False

    @pytest.mark.parametrize("text", ["y", "Y", "yes", " YES "])
    def test_answers_starting_with_y_are_yes(self, text):
        with _answer(text):
            assert ask_yn("Go?", default=False) is True

    @pytest.mark.parametrize("text", ["n", "no", "maybe"])
    def test_other_answers_are_no_even_when_default_is_yes(self, text):
        with _answer(text):
            assert ask_yn("Go?", default=True) is False

    def test_hint_marks_the_default_as_capital(self):
        with _answer("") as ask:
            ask_yn("Go?", default=True)
            ask_yn("Go?", default=False)
        assert [c.args[0] for c in ask.call_args_list] == [
            "Go? [Y/n] ",
            "Go? [y/N] ",
        ]

    @pytest.mark.parametrize("error", [EOFError, KeyboardInterrupt])
    def test_interrupted_input_exits_with_status_one(self, error, capsys):
        with patch("builtins.input", side_effect=error):
            with pytest.raises(SystemExit) as exc:
                ask_yn("Go?")
        assert exc.value.code == 1
        assert capsys.readouterr().out == "\n"


class TestAskValue:
    def test_answer_is_returned_stripped(self):
        with _answer("  value \n"):
            assert ask_value("Name?", default="dflt") == "value"

    def test_blank_answer_returns_the_default(self):
        with _answer("   "):
            assert ask_value("Name?", default="dflt") == "dflt"

    def test_prompt_shows_the_default_in_brackets(self):
        with _answer("") as ask:
            ask_value("Name?", default="dflt")
        assert ask.call_args.args[0] == "Name? [dflt] "

    def test_prompt_has_no_brackets_without_a_default(self):
        with _answer("") as ask:
            assert ask_value("Name?") == ""
        assert ask.call_args.args[0] == "Name? "

    @pytest.mark.parametrize("error", [EOFError, KeyboardInterrupt])
    def test_interrupted_input_exits_with_status_one(self, error, capsys):
        with patch("builtins.input", side_effect=error):
            with pytest.raises(SystemExit) as exc:
                ask_value("Name?")
        assert exc.value.code == 1
        assert capsys.readouterr().out == "\n"
