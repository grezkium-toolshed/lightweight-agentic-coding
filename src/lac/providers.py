"""Provider management: verification, catalog, readiness."""

import json
import os
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone


def utc_now():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def log_info(message):
    import sys
    print(message, file=sys.stderr)


def command_exists(name):
    import shutil
    return shutil.which(name) is not None


def _get_provider_entry(ctx, provider_id):
    catalog = json.loads(ctx.paths["provider_catalog"].read_text(encoding="utf-8"))
    for entry in catalog["providers"]:
        if entry["id"] == provider_id:
            return entry
    raise SystemExit(f"Unknown provider: {provider_id}")


def _opencode_base_urls(ctx):
    from lac.lib.jsonc import load_jsonc
    template = load_jsonc(ctx.paths["opencode_template"])
    providers = template.get("provider", {})
    urls = {}
    for pid, block in providers.items():
        base = block.get("options", {}).get("baseURL")
        if base:
            urls[pid] = base.rstrip("/")
    return urls


def _resolve_verify_endpoint(ctx, provider_id, rule):
    if "endpoint" in rule:
        return rule["endpoint"]
    urls = _opencode_base_urls(ctx)
    base = urls.get(provider_id)
    if not base:
        raise SystemExit(
            f"No baseURL found for provider '{provider_id}' in opencode.template.jsonc"
        )
    return base + rule.get("path", "/models")


def _openrouter_is_free_model(model):
    pricing = model.get("pricing")
    if isinstance(pricing, dict):
        price_fields = [
            "prompt", "completion", "request", "image", "web_search",
            "internal_reasoning", "input_cache_read", "input_cache_write",
        ]
        seen_any = False
        for field in price_fields:
            if field not in pricing:
                continue
            seen_any = True
            value = pricing[field]
            try:
                if float(value) != 0.0:
                    return False
            except (TypeError, ValueError):
                return False
        if seen_any:
            return True
    model_id = str(model.get("id", ""))
    return model_id.endswith(":free")


def parse_openrouter_models_response(body):
    if isinstance(body, str):
        payload = json.loads(body)
    elif isinstance(body, dict):
        payload = body
    else:
        raise SystemExit("OpenRouter models response must be JSON text or a decoded object.")
    data = payload.get("data", [])
    if not isinstance(data, list):
        raise SystemExit("OpenRouter models response missing data array.")
    return [model for model in data if isinstance(model, dict) and _openrouter_is_free_model(model)]


def _normalize_openrouter_catalog_models(models, verified_at, risk_level):
    catalog_models = []
    for model in models:
        model_id = str(model.get("id", "")).strip()
        if not model_id:
            continue
        entry = {
            "id": f"openrouter/{model_id}",
            "last_verified_at": verified_at,
            "verification_method": "live-openrouter-models-probe",
            "risk_level": risk_level,
        }
        for field in ("name", "description", "pricing", "top_provider", "supported_parameters"):
            if field in model:
                entry[field] = model[field]
        context_length = model.get("context_length")
        if context_length is None:
            top_provider = model.get("top_provider")
            if isinstance(top_provider, dict):
                context_length = top_provider.get("context_length")
        if context_length is not None:
            entry["context_length"] = context_length
        catalog_models.append(entry)
    catalog_models.sort(key=lambda item: item["id"])
    return catalog_models


def _fetch_openrouter_free_models(ctx, timeout=5):
    provider = _get_provider_entry(ctx, "openrouter")
    env_value = os.environ.get(provider["env_var"], "")
    if not env_value:
        raise SystemExit(f"env {provider['env_var']} not set")
    endpoint = _resolve_verify_endpoint(ctx, "openrouter", PROVIDER_VERIFICATION["openrouter"])
    headers = {"Authorization": f"Bearer {env_value}"}
    request_headers = dict(headers)
    request_headers["Content-Type"] = "application/json"
    request = urllib.request.Request(endpoint, headers=request_headers, method="GET")
    with urllib.request.urlopen(request, timeout=timeout) as response:
        raw = response.read().decode("utf-8")
    body = json.loads(raw)
    return parse_openrouter_models_response(body if isinstance(body, dict) else raw)


PROVIDER_VERIFICATION = {
    "local-cluster": {
        "endpoint": "http://127.0.0.1:8080/health",
        "auth": "none",
        "always_probe": True,
    },
    "openrouter": {"path": "/models", "auth": "bearer"},
    "opencode-go": {"path": "/models", "auth": "bearer"},
    "opencode-zen": {"path": "/models", "auth": "bearer"},
    "codex-auth": {"path": "/models", "auth": "bearer"},
    "nvidia-nim": {"path": "/models", "auth": "bearer"},
    "antigravity": {"path": "/models", "auth": "bearer"},
    "z-ai": {"path": "/models", "auth": "bearer"},
    "anthropic": {
        "endpoint": "https://api.anthropic.com/v1/models",
        "auth": "x-api-key",
    },
}


def _verify_provider_record(ctx, provider_id, timeout=5, include_internal=False):
    entry = _get_provider_entry(ctx, provider_id)
    env_var = entry["env_var"]
    env_value = os.environ.get(env_var, "")
    configured = bool(env_value)
    rule = PROVIDER_VERIFICATION.get(provider_id)
    if rule is None:
        return {
            "id": provider_id, "env_var": env_var, "configured": configured,
            "endpoint": None, "status": "skipped", "http_code": None,
            "latency_ms": None, "reason": "no verification rule registered",
            "verified_at": utc_now(),
        }
    endpoint = _resolve_verify_endpoint(ctx, provider_id, rule)
    always = rule.get("always_probe", False)
    if not configured and not always:
        return {
            "id": provider_id, "env_var": env_var, "configured": False,
            "endpoint": endpoint, "status": "skipped", "http_code": None,
            "latency_ms": None, "reason": f"env {env_var} not set",
            "verified_at": utc_now(),
        }
    headers = {}
    auth = rule["auth"]
    if auth == "bearer" and env_value:
        headers["Authorization"] = f"Bearer {env_value}"
    elif auth == "x-api-key" and env_value:
        headers["x-api-key"] = env_value
        headers["anthropic-version"] = "2023-06-01"
    request = urllib.request.Request(endpoint, headers=headers, method="GET")
    started = time.monotonic()
    status = "error"
    http_code = None
    reason = None
    raw_body = ""
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            http_code = response.status
            raw_body = response.read().decode("utf-8")
        status = "ok" if 200 <= (http_code or 0) < 300 else "error"
        if status == "error":
            reason = f"unexpected http {http_code}"
    except urllib.error.HTTPError as exc:
        http_code = exc.code
        reason = f"http {exc.code} {exc.reason}"
    except urllib.error.URLError as exc:
        reason = f"unreachable: {exc.reason}"
    except TimeoutError:
        reason = f"timeout after {timeout}s"
    except Exception as exc:
        reason = f"{type(exc).__name__}: {exc}"
    latency_ms = int((time.monotonic() - started) * 1000)
    record = {
        "id": provider_id, "env_var": env_var, "configured": configured,
        "endpoint": endpoint, "status": status, "http_code": http_code,
        "latency_ms": latency_ms, "reason": reason, "verified_at": utc_now(),
    }
    if include_internal and status == "ok" and provider_id == "openrouter":
        record["parsed_models"] = _normalize_openrouter_catalog_models(
            parse_openrouter_models_response(raw_body),
            verified_at=datetime.now(timezone.utc).date().isoformat(),
            risk_level=entry["risk_level"],
        )
    return record


def verify_provider(ctx, provider_id, timeout=5):
    return _verify_provider_record(ctx, provider_id, timeout=timeout, include_internal=False)


def verify_all_providers(ctx, timeout=5):
    catalog = json.loads(ctx.paths["provider_catalog"].read_text(encoding="utf-8"))
    results = [_verify_provider_record(ctx, p["id"], timeout=timeout, include_internal=False) for p in catalog["providers"]]
    summary = {
        "ok": sum(1 for r in results if r["status"] == "ok"),
        "skipped": sum(1 for r in results if r["status"] == "skipped"),
        "error": sum(1 for r in results if r["status"] == "error"),
        "total": len(results),
    }
    return {"results": results, "summary": summary}


def refresh_provider_catalog(ctx, results):
    catalog_path = ctx.paths["provider_catalog"]
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    today = datetime.now(timezone.utc).date().isoformat()
    by_id = {r["id"]: r for r in results}
    updated = []
    for entry in catalog["providers"]:
        result = by_id.get(entry["id"])
        if result and result["status"] == "ok":
            entry["last_verified_at"] = today
            entry["verification_method"] = "cli-reachability-probe"
            parsed_models = result.get("parsed_models")
            if parsed_models is not None:
                entry["models"] = parsed_models
            updated.append(entry["id"])
    catalog_path.write_text(json.dumps(catalog, indent=2) + "\n", encoding="utf-8")
    return updated


def _provider_configured(ctx, provider):
    if provider["id"] == "local-cluster":
        profile = ctx.active_profile()
        return bool(profile and profile.get("runtime_mode") == "local")
    return bool(os.environ.get(provider["env_var"]))


def collect_provider_readiness(ctx):
    catalog = json.loads(ctx.paths["provider_catalog"].read_text(encoding="utf-8"))
    results = []
    for provider in catalog["providers"]:
        results.append({
            "id": provider["id"],
            "label": provider["label"],
            "env_var": provider["env_var"],
            "configured": _provider_configured(ctx, provider),
            "risk_level": provider["risk_level"],
            "last_verified_at": provider["last_verified_at"],
        })
    return results


def provider_list(ctx):
    return collect_provider_readiness(ctx)


def provider_models(ctx, provider_id):
    entry = _get_provider_entry(ctx, provider_id)
    return entry.get("models", [])


def provider_status(ctx):
    readiness = collect_provider_readiness(ctx)
    configured = [p for p in readiness if p["configured"]]
    unconfigured = [p for p in readiness if not p["configured"]]
    return {
        "configured_count": len(configured),
        "unconfigured_count": len(unconfigured),
        "configured": configured,
        "unconfigured": unconfigured,
    }
