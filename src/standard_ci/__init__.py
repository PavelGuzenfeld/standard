from importlib import metadata

try:
    __version__ = metadata.version("standard")
except metadata.PackageNotFoundError:
    __version__ = "0+unknown"
