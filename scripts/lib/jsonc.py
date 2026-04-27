#!/usr/bin/env python3
"""Shared JSONC helpers for Local AI Cluster verify scripts."""

import json
from pathlib import Path


def strip_jsonc(text: str) -> str:
    """Remove // comments from JSONC text. Does NOT handle block comments."""
    return "\n".join(
        line for line in text.splitlines() if not line.lstrip().startswith("//")
    )


def load_jsonc(path: Path) -> dict:
    """Load a JSONC file, stripping // comments before parsing."""
    raw = path.read_text(encoding="utf-8")
    cleaned = strip_jsonc(raw)
    return json.loads(cleaned)
