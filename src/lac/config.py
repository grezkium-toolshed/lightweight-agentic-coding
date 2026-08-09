"""Config rendering: opencode config, catalog selectors, MLX model mapping."""

import copy
import configparser
import os

from lac.lib.jsonc import load_jsonc
from lac.network import url as network_url


LOCAL_MLX_MODEL_IDS = {
    "qwen3.6-27b-q3": "Qwen3.6-27B-UD-MLX-6bit",
    "qwen3.6-27b-q4": "Qwen3.6-27B-UD-MLX-6bit",
    "qwen3.6-35b-a3b-q8": "Qwen3.6-35B-A3B-MLX-8bit",
    "gemma-4-31b-q4": "gemma-4-31b-it-UD-MLX-4bit",
    "gemma-4-31b-q8": "gemma-4-31b-it-UD-MLX-8bit",
    "gemma-4-31b-bf16": "gemma-4-31b-it-UD-MLX-bf16",
    "gemma-4-e4b-q8": "gemma-4-E4B-it-MLX-8bit",
    "gemma-4-26b-a4b-q4": "gemma-4-26b-a4b-it-UD-MLX-8bit",
}

MIN_OPENCODE_CONTEXT = 32_768
MIN_OPENCODE_INPUT_BUDGET = 24_576


def _local_model_name(selector):
    if not selector.startswith("local-cluster/"):
        return ""
    return selector.split("/", 1)[1]


def _output_cap_for_context(runtime_context):
    if runtime_context <= 32_768:
        return 4_096
    if runtime_context < 131_072:
        return 8_192
    return 16_384


def _profile_local_limits(ctx, profile, template):
    selected_ids = {
        _local_model_name(profile.get(field, ""))
        for field in ("default_model", "small_model")
    }
    selected_ids.discard("")
    if profile.get("runtime_mode") != "local" and not selected_ids:
        return {}

    preset_path = ctx.root / profile["preset"]
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        parser.read_string("[global]\n" + preset_path.read_text(encoding="utf-8"))
    except (OSError, configparser.Error) as exc:
        raise SystemExit(f"Could not parse preset context limits from {preset_path}: {exc}") from exc

    provider_models = template["provider"]["local-cluster"]["models"]
    limits = {}
    for model_id in parser.sections():
        if model_id in {"global", "*"} or not parser.has_option(model_id, "model"):
            continue
        if not parser.has_option(model_id, "ctx-size") or not parser.has_option(model_id, "fit-ctx"):
            raise SystemExit(f"Profile '{profile['id']}' model '{model_id}' must define ctx-size and fit-ctx.")
        try:
            runtime_context = parser.getint(model_id, "ctx-size")
            fitting_context = parser.getint(model_id, "fit-ctx")
        except ValueError as exc:
            raise SystemExit(
                f"Profile '{profile['id']}' has an invalid context for local model '{model_id}'."
            ) from exc
        if runtime_context != fitting_context:
            raise SystemExit(
                f"Profile '{profile['id']}' model '{model_id}' has ctx-size {runtime_context} "
                f"but fit-ctx {fitting_context}."
            )

        model_entry = provider_models.get(model_id)
        if model_entry is None:
            raise SystemExit(f"OpenCode template is missing local model '{model_id}'.")
        model_entry = copy.deepcopy(model_entry)
        limit = model_entry.setdefault("limit", {})
        capability = limit.get("context")
        declared_output = int(limit.get("output", _output_cap_for_context(runtime_context)))
        output = min(declared_output, _output_cap_for_context(runtime_context))
        required = max(MIN_OPENCODE_CONTEXT, MIN_OPENCODE_INPUT_BUDGET + output)
        if runtime_context < required:
            raise SystemExit(
                f"Profile '{profile['id']}' gives local model '{model_id}' {runtime_context} context "
                f"tokens; OpenCode requires at least {required} for its fixed prompt and response headroom."
            )
        if capability is not None and runtime_context > int(capability):
            raise SystemExit(
                f"Profile '{profile['id']}' gives local model '{model_id}' {runtime_context} context "
                f"tokens, exceeding its declared capability of {capability}."
            )
        limit["context"] = runtime_context
        limit["output"] = output
        limits[model_id] = model_entry

    missing = sorted(selected_ids - limits.keys())
    if missing:
        raise SystemExit(
            f"Profile '{profile['id']}' selects local models missing from its preset: {', '.join(missing)}."
        )
    return limits


def _render_dcp_config(ctx, local_models):
    import json

    config = copy.deepcopy(load_jsonc(ctx.paths["dcp_template"]))
    compress = config.setdefault("compress", {})
    min_limits = {}
    max_limits = {}
    for selector, limit in sorted(local_models.items()):
        context = int(limit["context"])
        output = int(limit["output"])
        min_limits[selector] = context // 2
        max_limits[selector] = min((context * 3) // 4, context - output - 1)
    compress["modelMinLimits"] = min_limits
    compress["modelMaxLimits"] = max_limits
    compress["nudgeFrequency"] = 1
    ctx.paths["opencode_config_dir"].mkdir(parents=True, exist_ok=True)
    ctx.paths["dcp_config"].write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")


def _catalog_model_short_id(provider_id, model_id):
    prefix = f"{provider_id}/"
    if model_id.startswith(prefix):
        return model_id[len(prefix):]
    return model_id


def _catalog_model_matches_selector(provider_id, model, selector):
    model_id = str(model.get("id", ""))
    short_id = _catalog_model_short_id(provider_id, model_id)
    return selector in {model_id, short_id}


def _resolve_catalog_selector(ctx, selector):
    if not isinstance(selector, str) or not selector.startswith("@catalog:"):
        return selector
    spec = selector[len("@catalog:"):]
    prefer = []
    if "/prefer=" in spec:
        provider_id, prefer_raw = spec.split("/prefer=", 1)
        prefer = [item.strip() for item in prefer_raw.split(",") if item.strip()]
    else:
        provider_id = spec
    provider = _get_provider_entry(ctx, provider_id)
    models = provider.get("models", [])
    if not models:
        raise SystemExit(f"Catalog provider '{provider_id}' has no stored models for selector '{selector}'.")
    if prefer:
        for preferred in prefer:
            for model in models:
                if _catalog_model_matches_selector(provider_id, model, preferred):
                    return model["id"]
        raise SystemExit(
            f"No preferred model matched selector '{selector}'. Available: "
            f"{', '.join(model['id'] for model in models)}"
        )
    return models[0]["id"]


def _build_opencode_model_entry(template_models, provider_id, model):
    short_id = _catalog_model_short_id(provider_id, model["id"])
    existing = template_models.get(short_id, {}) if isinstance(template_models, dict) else {}
    limit = dict(existing.get("limit", {}))
    context_length = model.get("context_length")
    if context_length is None:
        context_length = model.get("top_provider", {}).get("context_length")
    if context_length is not None:
        limit["context"] = context_length
    if "output" not in limit:
        output = None
        top_provider = model.get("top_provider")
        if isinstance(top_provider, dict):
            output = top_provider.get("max_completion_tokens")
        if output is None:
            output = 8192
        limit["output"] = output
    entry = {}
    if limit.get("context") is not None and limit.get("output") is not None:
        entry["limit"] = limit
    for field in ("name", "description", "supported_parameters"):
        if field in model:
            entry[field] = model[field]
    if "pricing" in model:
        entry["pricing"] = model["pricing"]
    if "top_provider" in model:
        entry["top_provider"] = model["top_provider"]
    return short_id, entry


def _inject_provider_catalog_models(template, provider_id, models):
    providers = template.get("provider", {})
    provider_block = providers.get(provider_id)
    if not provider_block or not models:
        return
    template_models = provider_block.get("models", {})
    generated_models = {}
    for model in models:
        short_id, entry = _build_opencode_model_entry(template_models, provider_id, model)
        generated_models[short_id] = entry
    provider_block["models"] = generated_models


def _openrouter_catalog_models(ctx):
    provider = _get_provider_entry(ctx, "openrouter")
    return provider.get("models", [])


def _get_provider_entry(ctx, provider_id):
    import json
    catalog = json.loads(ctx.paths["provider_catalog"].read_text(encoding="utf-8"))
    for entry in catalog["providers"]:
        if entry["id"] == provider_id:
            return entry
    raise SystemExit(f"Unknown provider: {provider_id}")


def _opencode_base_urls(ctx):
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


def render_opencode_config(ctx, profile_id, profile, verbose_runtime=True, runtime_endpoint=None):
    import sys
    from lac.runtime import selected_local_runtime, local_runtime_endpoint

    def log_info(message):
        print(message, file=sys.stderr)

    template = copy.deepcopy(load_jsonc(ctx.paths["opencode_template"]))
    runtime = selected_local_runtime(profile, verbose=verbose_runtime)
    default_model = _resolve_catalog_selector(ctx, profile["default_model"])
    small_model = _resolve_catalog_selector(ctx, profile["small_model"])
    local_limits = _profile_local_limits(ctx, profile, template)
    provider = template["provider"]["local-cluster"]
    provider["models"] = local_limits
    endpoint = runtime_endpoint or local_runtime_endpoint(ctx, runtime)
    runtime_url = network_url(endpoint["connect_host"], endpoint["port"])
    provider["options"]["baseURL"] = f"{runtime_url}/v1"
    ds4_provider = template["provider"]["ds4"]
    for model_id, model_entry in ds4_provider["models"].items():
        limit = model_entry.setdefault("limit", {})
        context = int(limit.get("context", 262_144))
        if runtime == "ds4":
            context = int(os.environ.get("DS4_CTX", context))
        output = min(int(limit.get("output", 16_384)), _output_cap_for_context(context))
        required = max(MIN_OPENCODE_CONTEXT, MIN_OPENCODE_INPUT_BUDGET + output)
        if context < required:
            raise SystemExit(
                f"The ds4 model '{model_id}' exposes {context} context tokens; "
                f"OpenCode requires at least {required} for its fixed prompt and response headroom."
            )
        limit["context"] = context
        limit["output"] = output
    if runtime == "omlx":
        log_info(f"[config] Rendering OpenCode config for oMLX runtime ({runtime_url})")
        provider["name"] = "Local oMLX Cluster"
        mapped_models = {}
        default_local_id = _local_model_name(default_model)
        for model_id, model_entry in local_limits.items():
            mlx_id = LOCAL_MLX_MODEL_IDS.get(model_id)
            if not mlx_id:
                continue
            if mlx_id not in mapped_models or model_id == default_local_id:
                mapped_models[mlx_id] = model_entry
        provider["models"] = mapped_models
        if default_model.startswith("local-cluster/"):
            default_model = f"local-cluster/{LOCAL_MLX_MODEL_IDS.get(_local_model_name(default_model), _local_model_name(default_model))}"
        if small_model.startswith("local-cluster/"):
            small_id = _local_model_name(small_model)
            default_id = _local_model_name(default_model)
            small_model = f"local-cluster/{LOCAL_MLX_MODEL_IDS.get(small_id, LOCAL_MLX_MODEL_IDS.get(default_id, default_id))}"
    elif runtime == "ds4":
        log_info(f"[config] Rendering OpenCode config for ds4 runtime ({runtime_url})")
        ds4_provider["options"]["baseURL"] = f"{runtime_url}/v1"
    template["model"] = default_model
    template["small_model"] = small_model
    _inject_provider_catalog_models(template, "openrouter", _openrouter_catalog_models(ctx))

    import json
    local_dcp_models = {
        f"local-cluster/{model_id}": model_entry["limit"]
        for model_id, model_entry in template["provider"]["local-cluster"]["models"].items()
    }
    local_dcp_models.update({
        f"ds4/{model_id}": model_entry["limit"]
        for model_id, model_entry in template["provider"]["ds4"]["models"].items()
    })
    _render_dcp_config(ctx, local_dcp_models)
    ctx.paths["opencode_config"].write_text(json.dumps(template, indent=2) + "\n", encoding="utf-8")
    return ctx.paths["opencode_config"]
