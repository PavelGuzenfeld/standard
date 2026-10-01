import pytest


@pytest.fixture(autouse=True)
def _run_from_tmp_path(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
