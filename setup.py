"""Minimal setup shim.

Project metadata lives in pyproject.toml (the single source of truth); the version is read
from src/lac/__init__.py via [tool.setuptools.dynamic]. This file exists only to regenerate
the bundled data before the build collects it.
"""

import sys
from pathlib import Path

from setuptools import setup

ROOT = Path(__file__).parent

# Regenerate src/lac/data/ (gitignored) from the canonical top-level trees before the build
# collects package data. When building from an unpacked sdist, scripts/ is not shipped and
# src/lac/data is already staged, so the import fails harmlessly and we skip.
sys.path.insert(0, str(ROOT / "scripts"))
try:
    import stage_data  # noqa: E402
    stage_data.stage()
except ImportError:
    pass

setup()
