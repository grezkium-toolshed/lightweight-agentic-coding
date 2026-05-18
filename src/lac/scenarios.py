"""Scenario catalog: list and show."""

import json


def scenario_list(ctx):
    catalog = json.loads(ctx.paths["scenario_catalog"].read_text(encoding="utf-8"))
    return catalog["scenarios"]


def scenario_show(ctx, scenario_id):
    for scenario in scenario_list(ctx):
        if scenario["id"] == scenario_id:
            return scenario
    raise SystemExit(f"Unknown scenario: {scenario_id}")
