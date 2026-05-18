"""Text renderers: human-readable output for all CLI commands."""

import json


def render_pack_list(packs):
    for pack in packs:
        clients = ", ".join(pack["supported_clients"])
        installed = "installed" if pack.get("installed") else "not installed"
        print(f"{pack['id']}: {pack['label']} | trust {pack['trust_level']} | {pack['asset_count']} assets | {installed} | clients: {clients}")


def render_pack_show(pack):
    print(f"{pack['id']}: {pack['label']}")
    print(f"  trust: {pack['trust_level']}")
    print(f"  installed: {'yes' if pack.get('installed') else 'no'}")
    print(f"  description: {pack['description']}")
    print(f"  clients: {', '.join(pack['supported_clients'])}")
    print(f"  tools: {', '.join(pack['required_tools'])}")
    print(f"  assets ({pack['asset_count']}):")
    for asset in pack["assets"]:
        print(f"    - {asset['id']} [{asset['type']}] support={asset['support_tier']} trust={asset['trust_level']} installed={'yes' if asset.get('installed') else 'no'}")


def render_skill_status(payload):
    state = "installed" if payload.get("installed") else "not installed"
    print(f"{payload['id']}: {state} | {payload['path']}")
    if payload.get("message"):
        print(payload["message"])


def render_skill_verify(payload):
    ok = "ok" if payload.get("ok") else "FAIL"
    print(f"{payload['id']}: {ok} | {payload['path']}")
    for check in payload.get("checks", []):
        state = "ok" if check["ok"] else "FAIL"
        print(f"  {check['name']}: {state} {check.get('detail', '')}".rstrip())


def render_scenario_list(scenarios):
    for scenario in scenarios:
        profiles = ", ".join(scenario["recommended_profiles"])
        packs = ", ".join(scenario["recommended_packs"])
        print(f"{scenario['id']}: {scenario['label']} | profiles: {profiles} | packs: {packs}")


def render_scenario_show(scenario):
    print(f"{scenario['id']}: {scenario['label']}")
    print(f"  description: {scenario['description']}")
    print(f"  profiles: {', '.join(scenario['recommended_profiles'])}")
    print(f"  packs: {', '.join(scenario['recommended_packs'])}")
    print(f"  client_target: {scenario['client_target']}")


def render_provider_list(providers):
    for provider in providers:
        if provider["id"] == "local-cluster":
            readiness = "local profile active" if provider["configured"] else "local profile inactive"
            print(f"{provider['id']}: {provider['label']} | {readiness} | risk {provider['risk_level']} | verified {provider['last_verified_at']}")
            continue
        flag = "ready" if provider["configured"] else "unset"
        print(f"{provider['id']}: {provider['label']} | env {provider['env_var']} ({flag}) | risk {provider['risk_level']} | verified {provider['last_verified_at']}")


def _catalog_model_short_id(provider_id, model_id):
    prefix = f"{provider_id}/"
    if model_id.startswith(prefix):
        return model_id[len(prefix):]
    return model_id


def render_provider_models(provider_id, models):
    if not models:
        print(f"{provider_id}: no catalog models recorded")
        return
    for model in models:
        short_id = _catalog_model_short_id(provider_id, model["id"])
        context = model.get("context_length")
        context_label = str(context) if context is not None else "?"
        print(f"{short_id}: context {context_label} | verified {model['last_verified_at']}")


def render_provider_status(payload):
    print(f"Providers: {payload['configured_count']} configured, {payload['unconfigured_count']} unconfigured")
    if payload["configured"]:
        print("  configured:")
        render_provider_list(payload["configured"])
    if payload["unconfigured"]:
        print("  unconfigured:")
        render_provider_list(payload["unconfigured"])


def _render_verify_row(record):
    status = record["status"]
    latency = f"{record['latency_ms']}ms" if record["latency_ms"] is not None else ""
    detail = record.get("reason") or record.get("endpoint") or ""
    print(f"{record['id']:<18}| {status:<6}| {latency:<10}| {detail}")


def render_provider_verify_single(record):
    _render_verify_row(record)


def render_provider_verify_all(payload):
    for record in payload["results"]:
        _render_verify_row(record)
    summary = payload["summary"]
    print(f"Summary: {summary['ok']} ok, {summary['skipped']} skipped, {summary['error']} error")


def render_doctor_text(report):
    ok = "ok" if report["ok"] else "FAIL"
    profile_id = report["active_profile_id"] or "(none)"
    print(f"Doctor: {ok} | active profile: {profile_id}")
    print(f"State root: {report['state_root']}")
    failures = report.get("failures", [])
    if failures:
        print(f"Failures ({len(failures)}):")
        for path in failures:
            print(f"  - {path}")
    missing_sources = [c for c in report["checks"] if c["kind"] == "source" and not c["exists"]]
    missing_generated = [c for c in report["checks"] if c["kind"] == "generated" and not c["exists"]]
    if missing_sources:
        print(f"Missing sources: {len(missing_sources)}")
    if missing_generated:
        print(f"Missing generated state: {len(missing_generated)} (run lac profile apply <profile>)")
    commands = report["commands"]
    cmd_line = ", ".join(f"{name}={'yes' if exists else 'no'}" for name, exists in commands.items())
    print(f"Commands: {cmd_line}")
    command_hints = report.get("command_install_hints", {})
    if command_hints:
        print("Missing command install notes:")
        for name, hint in command_hints.items():
            print(f"  - {name}: {hint['summary']}")
            for command in hint.get("commands", []):
                print(f"    install: {command}")
    runtime = report["runtime"]
    running = "yes" if runtime.get("running") else "no"
    health = "yes" if runtime.get("health_reachable") else "no"
    print(f"Runtime: {runtime['url']} | running={running} | health={health}")
    providers = report["provider_readiness"]
    configured = sum(1 for p in providers if p["configured"])
    print(f"Providers: {configured}/{len(providers)} configured")
    assets = report["assets"]
    print(f"Assets: {assets['catalog_asset_count']} cataloged | {assets['pack_count']} packs | {assets['opencode_agents']} agents | {assets['opencode_skills']} skills")
    print("Run with --json for full detail.")


def render_smoke_text(report):
    profile_id = report.get("active_profile_id") or "(none)"
    if report.get("skipped"):
        print(f"Smoke: skipped ({report.get('reason')}) | profile: {profile_id}")
        print("Run with --json for full detail.")
        return
    ok = "ok" if report.get("ok") else "FAIL"
    print(f"Smoke: {ok} | profile: {profile_id}")
    if "error" in report:
        print(f"Error: {report['error']}")
    if "model_count" in report:
        print(f"Runtime: {report.get('runtime_url')} | models: {report['model_count']}")
    if "benchmark_ms" in report:
        print(f"Benchmark: {report['benchmark_ms']} ms")
    preview = report.get("chat_content_preview")
    if preview:
        print(f"Reply preview: {preview}")
    print("Run with --json for full detail.")
