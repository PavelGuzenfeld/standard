"""Tests for the standard_ci version source."""

import importlib
from importlib import metadata
from unittest import mock

import standard_ci


def _reload_with(version_side_effect):
    with mock.patch.object(metadata, "version", side_effect=version_side_effect):
        return importlib.reload(standard_ci).__version__


def test_version_comes_from_installed_package_metadata():
    assert _reload_with(lambda name: "9.8.7") == "9.8.7"
    importlib.reload(standard_ci)


def test_version_falls_back_when_package_not_installed():
    def not_installed(name):
        raise metadata.PackageNotFoundError(name)

    assert _reload_with(not_installed) == "0+unknown"
    importlib.reload(standard_ci)
