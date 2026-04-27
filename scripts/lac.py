#!/usr/bin/env python3
import argparse
import copy
import json
import os
import platform
import shutil
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

# Allow importing shared utilities from scripts/lib/
_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))

from lib.jsonc import load_jsonc  # noqa: E402


VERSION = "0.1.0"

ROOT = _SCRIPT_DIR.parent
STATE_ROOT = Path(os.environ.get("AI_CLUSTER_STATE_ROOT", ROOT / "state"))
PORT = int(os.environ.get("AI_CLUSTER_PORT", "8080"))
HOST = os.environ.get("AI_CLUSTER_HOST", "127.0.0.1")
OMLX_PORT = int(os.environ.get("AI_OMLX_PORT", os.environ.get("OMLX_PORT", "8000")))
LOCAL_MLX_MODEL_IDS = {
  # Qwen 3.6 MLX quants (Unsloth)
  "qwen3.6-27b-q3": "Qwen3.6-27B-UD-MLX-6bit",
  "qwen3.6-27b-q4": "Qwen3.6-27B-UD-MLX-6bit",
  "qwen3.6-35b-a3b-q8": "Qwen3.6-35B-A3B-MLX-8bit",
  # Gemma 4 MLX Dynamic quants (Unsloth)
  # Dense 31B — each quant maps to its own bit depth
  "gemma-4-31b-q4": "gemma-4-31b-it-UD-MLX-4bit",
  "gemma-4-31b-q8": "gemma-4-31b-it-UD-MLX-8bit",
  "gemma-4-31b-bf16": "gemma-4-31b-it-UD-MLX-bf16",
  "gemma-4-e4b-q8": "gemma-4-E4B-it-MLX-8bit",
  # MoE 26B-A4B: 8bit (only Unsloth MLX quant available for this variant)
  "gemma-4-26b-a4b-q4": "gemma-4-26b-a4b-it-UD-MLX-8bit",
}


def utc_now():
  return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def load_json(path):
  return json.loads(path.read_text(encoding="utf-8"))


def write_text(path, content):
  path.parent.mkdir(parents=True, exist_ok=True)
  path.write_text(content, encoding="utf-8")


def write_json(path, payload):
  path.parent.mkdir(parents=True, exist_ok=True)
  path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def as_runtime_path(path):
  return str(path).replace("\\", "/")


def command_exists(name):
  return shutil.which(name) is not None


def _host_install_platform():
  if sys.platform == "darwin":
    return "macos"
  if sys.platform.startswith("win"):
    return "windows"
  return "linux"


def _install_hint(tool_id, env_var=None):
  platform_id = _host_install_platform()
  hints = {
    "python": {
      "summary": "Install Python 3 and make sure python3, python, or py is on PATH.",
      "macos": ["brew install python"],
      "linux": ["sudo apt install python3"],
      "windows": ["winget install Python.Python.3.12"],
      "docs": "https://www.python.org/downloads/",
    },
    "opencode": {
      "summary": "Install the OpenCode CLI, then restart your shell so opencode is on PATH.",
      "macos": ["curl -fsSL https://opencode.ai/install | bash", "npm install -g opencode-ai"],
      "linux": ["curl -fsSL https://opencode.ai/install | bash", "npm install -g opencode-ai"],
      "windows": ["npm install -g opencode-ai"],
      "docs": "https://opencode.ai/docs",
    },
    "llama-server": {
      "summary": "Install llama.cpp and make sure the llama-server binary is on PATH.",
      "macos": ["brew install llama.cpp"],
      "linux": [
        "git clone https://github.com/ggml-org/llama.cpp",
        "cmake -B llama.cpp/build -S llama.cpp -DLLAMA_CURL=ON",
        "cmake --build llama.cpp/build --config Release -j",
      ],
      "windows": ["Download a llama.cpp release and add the folder containing llama-server.exe to PATH."],
      "docs": "https://github.com/ggml-org/llama.cpp",
    },
    "omlx": {
      "summary": "Install oMLX only on Apple Silicon macOS when you want MLX serving.",
      "macos": ["brew tap jundot/omlx https://github.com/jundot/omlx", "brew install omlx"],
      "linux": ["oMLX is macOS/Apple Silicon only; use llama.cpp on Linux."],
      "windows": ["oMLX is macOS/Apple Silicon only; use llama.cpp on Windows."],
      "docs": "https://github.com/jundot/omlx",
    },
    "hf": {
      "summary": "Install the Hugging Face CLI if you want authenticated model downloads or MLX repo staging.",
      "macos": ["python3 -m pip install --user 'huggingface_hub[cli]'"],
      "linux": ["python3 -m pip install --user 'huggingface_hub[cli]'"],
      "windows": ["py -3 -m pip install --user \"huggingface_hub[cli]\""],
      "docs": "https://huggingface.co/docs/huggingface_hub/guides/cli",
    },
  }
  if env_var:
    return {
      "summary": f"Set {env_var} in your shell before running init/provider verification.",
      "commands": [f"export {env_var}=..."] if platform_id != "windows" else [f"$env:{env_var} = \"...\""],
      "docs": "docs/providers/AUTHENTICATION.md",
    }
  hint = hints.get(tool_id)
  if not hint:
    return None
  return {
    "summary": hint["summary"],
    "commands": hint.get(platform_id, []),
    "docs": hint.get("docs"),
  }


def log_info(message):
  print(message, file=sys.stderr)


def _normalize_local_runtime(value):
  normalized = (value or "").strip().lower()
  if normalized in {"", "auto"}:
    return "auto"
  if normalized in {"omlx", "mlx"}:
    return "omlx"
  if normalized in {"llama", "llama.cpp", "llamacpp", "llama-server"}:
    return "llama.cpp"
  raise SystemExit(f"Unsupported AI_LOCAL_RUNTIME: {value}. Use auto, omlx, or llama.cpp.")


def _local_model_name(selector):
  if not selector.startswith("local-cluster/"):
    return ""
  return selector.split("/", 1)[1]


def _profile_supports_omlx(profile, verbose=False):
  if not profile or profile.get("runtime_mode") != "local":
    if verbose:
      log_info(f"[omlx] Profile '{profile.get('id', '?')}' rejected: not a local runtime profile")
    return False
  model_ids = {
    _local_model_name(profile.get("default_model", "")),
    _local_model_name(profile.get("small_model", "")),
  }
  unsupported = [mid for mid in model_ids if mid and mid not in LOCAL_MLX_MODEL_IDS]
  if unsupported:
    if verbose:
      log_info(f"[omlx] Profile '{profile.get('id')}' rejected: no MLX model ID mapped for {', '.join(unsupported)}")
    return False
  return bool(model_ids)


def selected_local_runtime(profile=None, verbose=False):
  requested = _normalize_local_runtime(os.environ.get("AI_LOCAL_RUNTIME", "auto"))
  if requested != "auto":
    if requested == "omlx" and sys.platform != "darwin":
      if verbose:
        log_info(f"[runtime] oMLX is only supported on macOS. Ignoring AI_LOCAL_RUNTIME=omlx.")
    elif requested == "omlx" and not _profile_supports_omlx(profile, verbose=verbose):
      if verbose:
        log_info("[runtime] Requested oMLX runtime is not compatible with this profile. Falling back to llama.cpp.")
    else:
      if verbose:
        log_info(f"[runtime] Using requested runtime: {requested}")
      return requested
  if sys.platform == "darwin" and _profile_supports_omlx(profile, verbose=False):
    omlx_bin = os.environ.get("OMLX_BIN", "omlx")
    if not command_exists(omlx_bin):
      if verbose:
        log_info(f"[runtime] oMLX auto-selection skipped: `{omlx_bin}` is not in PATH")
    else:
      if verbose:
        log_info(f"[runtime] Auto-selected oMLX runtime (macOS + MLX models detected)")
      return "omlx"
  elif verbose and sys.platform == "darwin":
    log_info("[runtime] oMLX auto-selection skipped: profile is not eligible")
  if verbose:
    log_info(f"[runtime] Using default runtime: llama.cpp")
  return "llama.cpp"


def runtime_paths(ctx, runtime):
  if runtime == "omlx":
    return {
      "pid": ctx.paths["omlx_pid"],
      "state": ctx.paths["omlx_state"],
      "log": ctx.paths["omlx_log"],
      "label": "oMLX",
    }
  return {
    "pid": ctx.paths["llama_pid"],
    "state": ctx.paths["llama_state"],
    "log": ctx.paths["llama_log"],
    "label": "llama.cpp",
  }


def local_runtime_port(runtime):
  return OMLX_PORT if runtime == "omlx" else PORT


def local_runtime_base_url(runtime):
  return f"http://{HOST}:{local_runtime_port(runtime)}"


def read_text(path):
  return path.read_text(encoding="utf-8")


def request_json(url, method="GET", payload=None, timeout=5, headers=None):
  request_headers = dict(headers or {})
  data = None
  if payload is not None:
    request_headers["Content-Type"] = "application/json"
    data = json.dumps(payload).encode("utf-8")
  request = urllib.request.Request(url, data=data, headers=request_headers, method=method)
  with urllib.request.urlopen(request, timeout=timeout) as response:
    raw = response.read().decode("utf-8")
  return json.loads(raw), raw


def is_pid_running(pid):
  if not pid:
    return False
  try:
    os.kill(pid, 0)
  except OSError:
    return False
  return True


def _strip_global_json_flag(argv):
  json_mode = False
  filtered = []
  for arg in argv:
    if arg == "--json":
      json_mode = True
      continue
    filtered.append(arg)
  return filtered, json_mode


def _openrouter_is_free_model(model):
  pricing = model.get("pricing")
  if isinstance(pricing, dict):
    price_fields = [
      "prompt",
      "completion",
      "request",
      "image",
      "web_search",
      "internal_reasoning",
      "input_cache_read",
      "input_cache_write",
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


def _fetch_openrouter_free_models(ctx, timeout=5):
  provider = _get_provider_entry(ctx, "openrouter")
  env_value = os.environ.get(provider["env_var"], "")
  if not env_value:
    raise SystemExit(f"env {provider['env_var']} not set")

  endpoint = _resolve_verify_endpoint(ctx, "openrouter", PROVIDER_VERIFICATION["openrouter"])
  headers = {"Authorization": f"Bearer {env_value}"}
  body, raw = request_json(endpoint, timeout=timeout, headers=headers)
  return parse_openrouter_models_response(body if isinstance(body, dict) else raw)


def _verify_provider_record(ctx, provider_id, timeout=5, include_internal=False):
  entry = _get_provider_entry(ctx, provider_id)
  env_var = entry["env_var"]
  env_value = os.environ.get(env_var, "")
  configured = bool(env_value)

  rule = PROVIDER_VERIFICATION.get(provider_id)
  if rule is None:
    return {
      "id": provider_id,
      "env_var": env_var,
      "configured": configured,
      "endpoint": None,
      "status": "skipped",
      "http_code": None,
      "latency_ms": None,
      "reason": "no verification rule registered",
      "verified_at": utc_now(),
    }

  endpoint = _resolve_verify_endpoint(ctx, provider_id, rule)
  always = rule.get("always_probe", False)

  if not configured and not always:
    return {
      "id": provider_id,
      "env_var": env_var,
      "configured": False,
      "endpoint": endpoint,
      "status": "skipped",
      "http_code": None,
      "latency_ms": None,
      "reason": f"env {env_var} not set",
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
    "id": provider_id,
    "env_var": env_var,
    "configured": configured,
    "endpoint": endpoint,
    "status": status,
    "http_code": http_code,
    "latency_ms": latency_ms,
    "reason": reason,
    "verified_at": utc_now(),
  }

  if include_internal and status == "ok" and provider_id == "openrouter":
    record["parsed_models"] = _normalize_openrouter_catalog_models(
      parse_openrouter_models_response(raw_body),
      verified_at=datetime.now(timezone.utc).date().isoformat(),
      risk_level=entry["risk_level"],
    )

  return record


class Context:
  def __init__(self):
    self.root = ROOT
    self.state_root = STATE_ROOT
    self.paths = {
      "profile_manifest": self.root / "runtime-config/profiles.json",
      "opencode_template": self.root / "opencode.template.jsonc",
      "asset_catalog": self.root / "catalog/assets.json",
      "workflow_catalog": self.root / "catalog/workflow-packs.json",
      "provider_catalog": self.root / "catalog/providers.json",
      "scenario_catalog": self.root / "catalog/scenarios.json",
      "active_profile": self.state_root / "active/profile.txt",
      "active_profile_summary": self.state_root / "active/profile.json",
      "active_preset": self.state_root / "runtime/presets.active.ini",
      "opencode_config": self.state_root / "clients/opencode/opencode.json",
      "llama_pid": self.state_root / "runtime/llama-server.pid",
      "llama_state": self.state_root / "runtime/llama-server.json",
      "llama_log": self.state_root / "logs/llama-server.log",
      "omlx_pid": self.state_root / "runtime/omlx.pid",
      "omlx_state": self.state_root / "runtime/omlx.json",
      "omlx_log": self.state_root / "logs/omlx.log",
      "doctor_report": self.state_root / "reports/doctor.json",
      "smoke_report": self.state_root / "reports/smoke.json",
    }
    self.profile_manifest = load_json(self.paths["profile_manifest"])
    self.profiles = self.profile_manifest["profiles"]

  def get_profile(self, profile_id):
    profile = self.profiles.get(profile_id)
    if profile is None:
      raise SystemExit(f"Unknown profile: {profile_id}")
    return profile

  def active_profile_id(self):
    if self.paths["active_profile"].is_file():
      return self.paths["active_profile"].read_text(encoding="utf-8").strip()
    return ""

  def active_profile(self):
    profile_id = self.active_profile_id()
    if not profile_id:
      return None
    return self.profiles.get(profile_id)


def render_opencode_config(ctx, profile_id, profile, verbose_runtime=True):
  template = copy.deepcopy(load_jsonc(ctx.paths["opencode_template"]))
  runtime = selected_local_runtime(profile, verbose=verbose_runtime)
  default_model = _resolve_catalog_selector(ctx, profile["default_model"])
  small_model = _resolve_catalog_selector(ctx, profile["small_model"])
  if runtime == "omlx":
    log_info(f"[config] Rendering OpenCode config for oMLX runtime (port {local_runtime_port(runtime)})")
    provider = template["provider"]["local-cluster"]
    provider["name"] = "Local oMLX Cluster"
    provider["options"]["baseURL"] = f"{local_runtime_base_url(runtime)}/v1"
    mapped_models = {}
    for model_id, mlx_id in LOCAL_MLX_MODEL_IDS.items():
      if model_id in provider["models"]:
        mapped_models[mlx_id] = provider["models"][model_id]
    provider["models"] = mapped_models
    if default_model.startswith("local-cluster/"):
      default_model = f"local-cluster/{LOCAL_MLX_MODEL_IDS.get(_local_model_name(default_model), _local_model_name(default_model))}"
    if small_model.startswith("local-cluster/"):
      small_model = f"local-cluster/{LOCAL_MLX_MODEL_IDS.get(_local_model_name(small_model), _local_model_name(small_model))}"
  template["model"] = default_model
  template["small_model"] = small_model
  _inject_provider_catalog_models(template, "openrouter", _openrouter_catalog_models(ctx))
  write_json(ctx.paths["opencode_config"], template)
  return ctx.paths["opencode_config"]


def render_preset(ctx, profile):
  models_dir = Path(os.environ.get("AI_MODELS_DIR", str(ctx.root / "models")))
  preset_path = ctx.root / profile["preset"]
  if not preset_path.is_file():
    raise SystemExit(f"Preset template missing: {preset_path}")
  rendered = read_text(preset_path)
  rendered = rendered.replace("__MODELS_DIR__", as_runtime_path(models_dir))
  rendered = rendered.replace("__CLUSTER_ROOT__", as_runtime_path(ctx.root))
  write_text(ctx.paths["active_preset"], rendered)
  return ctx.paths["active_preset"]


def load_asset_catalog(ctx):
  return load_json(ctx.paths["asset_catalog"])


def load_workflow_catalog(ctx):
  return load_json(ctx.paths["workflow_catalog"])


def build_pack_summary(ctx):
  asset_catalog = load_asset_catalog(ctx)
  workflow_catalog = load_workflow_catalog(ctx)
  asset_by_id = {asset["id"]: asset for asset in asset_catalog["assets"]}
  packs = []
  for pack in workflow_catalog["packs"]:
    pack_assets = [asset_by_id[asset_id] for asset_id in pack["assets"]]
    packs.append(
      {
        "id": pack["id"],
        "label": pack["label"],
        "description": pack["description"],
        "supported_clients": pack["supported_clients"],
        "required_tools": pack["required_tools"],
        "trust_level": pack["trust_level"],
        "asset_count": len(pack_assets),
        "assets": pack_assets,
      }
    )
  return packs


def render_client(ctx, target):
  packs = build_pack_summary(ctx)
  manifest = {
    "generated_at": utc_now(),
    "target": target,
    "pack_count": len(packs),
    "packs": packs,
  }

  if target == "opencode":
    path = ctx.root / ".opencode/render-manifest.json"
    write_json(path, manifest)
    write_json(ctx.state_root / "clients/opencode/manifest.json", manifest)
    return {
      "target": target,
      "manifest_path": str(path),
      "pack_count": len(packs),
      "runtime_asset_root": str(ctx.root / ".opencode"),
    }

  if target == "claude-code":
    target_root = ctx.state_root / "clients/claude-code"
    target_root.mkdir(parents=True, exist_ok=True)
    template_root = ctx.root / "templates/claude-code"
    shutil.copytree(template_root, target_root / "templates", dirs_exist_ok=True)
    lines = [
      "# Claude Code Adapter",
      "",
      "This adapter reuses the curated Local AI Cluster workflow packs as references for Claude Code.",
      "",
      "## Included Packs",
      "",
    ]
    for pack in packs:
      lines.append(f"- `{pack['id']}`: {pack['description']}")
    lines.append("")
    lines.append("OpenCode remains the lead runtime target. This adapter is a reviewed reference bundle.")
    write_text(target_root / "README.md", "\n".join(lines) + "\n")
    write_json(target_root / "manifest.json", manifest)
    return {
      "target": target,
      "manifest_path": str(target_root / "manifest.json"),
      "pack_count": len(packs),
      "render_root": str(target_root),
    }

  if target == "codex-reference":
    target_root = ctx.state_root / "clients/codex-reference"
    target_root.mkdir(parents=True, exist_ok=True)
    lines = [
      "# Codex Reference Adapter",
      "",
      "This adapter provides a reference view of the curated workflow packs for Codex-style environments.",
      "",
      "## Workflow Packs",
      "",
    ]
    for pack in packs:
      lines.append(f"- `{pack['id']}`: trust `{pack['trust_level']}`, tools `{', '.join(pack['required_tools'])}`")
    lines.append("")
    lines.append("Use the asset catalog for source attribution, support tier, and permission notes.")
    write_text(target_root / "README.md", "\n".join(lines) + "\n")
    write_json(target_root / "manifest.json", manifest)
    return {
      "target": target,
      "manifest_path": str(target_root / "manifest.json"),
      "pack_count": len(packs),
      "render_root": str(target_root),
    }

  raise SystemExit(f"Unsupported client target: {target}")


def pack_list(ctx):
  packs = build_pack_summary(ctx)
  return [
    {
      "id": pack["id"],
      "label": pack["label"],
      "trust_level": pack["trust_level"],
      "asset_count": pack["asset_count"],
      "supported_clients": pack["supported_clients"],
      "required_tools": pack["required_tools"],
    }
    for pack in packs
  ]


def pack_show(ctx, pack_id):
  for pack in build_pack_summary(ctx):
    if pack["id"] == pack_id:
      return pack
  raise SystemExit(f"Unknown pack: {pack_id}")


def scenario_list(ctx):
  catalog = load_json(ctx.paths["scenario_catalog"])
  return catalog["scenarios"]


def scenario_show(ctx, scenario_id):
  for scenario in load_json(ctx.paths["scenario_catalog"])["scenarios"]:
    if scenario["id"] == scenario_id:
      return scenario
  raise SystemExit(f"Unknown scenario: {scenario_id}")


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


PROVIDER_VERIFICATION = {
  "local-cluster": {
    "endpoint": f"http://{HOST}:{PORT}/health",
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


def _get_provider_entry(ctx, provider_id):
  catalog = load_json(ctx.paths["provider_catalog"])
  for entry in catalog["providers"]:
    if entry["id"] == provider_id:
      return entry
  raise SystemExit(f"Unknown provider: {provider_id}")


def verify_provider(ctx, provider_id, timeout=5):
  record = _verify_provider_record(ctx, provider_id, timeout=timeout, include_internal=False)
  return record


def verify_all_providers(ctx, timeout=5):
  catalog = load_json(ctx.paths["provider_catalog"])
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
  catalog = load_json(catalog_path)
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
  write_json(catalog_path, catalog)
  return updated


def profile_list(ctx):
  rows = []
  for profile_id, profile in ctx.profiles.items():
    rows.append(
      {
        "id": profile_id,
        "label": profile["label"],
        "runtime_mode": profile["runtime_mode"],
        "verification_tier": profile["verification_tier"],
        "primary_workload": profile["primary_workload"],
        "recommended_for": profile["recommended_for"],
        "supported_clients": profile["supported_clients"],
      }
    )
  return rows


def profile_apply(ctx, profile_id, render_target="opencode", verbose_runtime=True):
  profile = ctx.get_profile(profile_id)
  render_preset(ctx, profile)
  render_opencode_config(ctx, profile_id, profile, verbose_runtime=verbose_runtime)
  write_text(ctx.paths["active_profile"], f"{profile_id}\n")
  summary = {
    "applied_at": utc_now(),
    "profile": profile,
    "profile_id": profile_id,
    "state_root": str(ctx.state_root),
    "generated": {
      "active_profile": str(ctx.paths["active_profile"]),
      "active_preset": str(ctx.paths["active_preset"]),
      "opencode_config": str(ctx.paths["opencode_config"]),
    },
  }
  write_json(ctx.paths["active_profile_summary"], summary)
  render_result = render_client(ctx, render_target)
  summary["render"] = render_result
  return summary


def _provider_configured(ctx, provider):
  if provider["id"] == "local-cluster":
    profile = ctx.active_profile()
    return bool(profile and profile.get("runtime_mode") == "local")
  return bool(os.environ.get(provider["env_var"]))


def collect_provider_readiness(ctx):
  catalog = load_json(ctx.paths["provider_catalog"])
  results = []
  for provider in catalog["providers"]:
    results.append(
      {
        "id": provider["id"],
        "label": provider["label"],
        "env_var": provider["env_var"],
        "configured": _provider_configured(ctx, provider),
        "risk_level": provider["risk_level"],
        "last_verified_at": provider["last_verified_at"],
      }
    )
  return results


def collect_runtime_status(ctx):
  profile = ctx.active_profile()
  runtime = selected_local_runtime(profile)
  port = local_runtime_port(runtime)
  health_path = "/v1/models" if runtime == "omlx" else "/health"

  paths = runtime_paths(ctx, runtime)
  pid_path = paths["pid"]
  state_path = paths["state"]
  log_path = paths["log"]

  runtime_info = {
    "runtime": runtime,
    "host": HOST,
    "port": port,
    "url": f"http://{HOST}:{port}",
    "log_path": str(log_path),
    "pid_path": str(pid_path),
    "running": False,
    "health_reachable": False,
  }

  if pid_path.is_file():
    try:
      pid = int(pid_path.read_text(encoding="utf-8").strip())
    except ValueError:
      pid = 0
    runtime_info["pid"] = pid
    runtime_info["running"] = is_pid_running(pid)

  if state_path.is_file():
    runtime_info["launch"] = load_json(state_path)

  try:
    health, _ = request_json(f"http://{HOST}:{port}{health_path}", timeout=2)
    runtime_info["health_reachable"] = True
    runtime_info["health"] = health
  except Exception:
    runtime_info["health_reachable"] = False

  return runtime_info


def doctor(ctx, strict=False, bootstrap_hint=False):
  checks = []

  def add_check(kind, path, exists, generated=False, hint=None):
    checks.append(
      {
        "kind": kind,
        "path": str(path),
        "exists": exists,
        "generated": generated,
        "hint": hint,
      }
    )

  source_paths = [
    ctx.paths["opencode_template"],
    ctx.paths["profile_manifest"],
    ctx.paths["asset_catalog"],
    ctx.paths["workflow_catalog"],
    ctx.paths["provider_catalog"],
    ctx.paths["scenario_catalog"],
  ]
  for path in source_paths:
    add_check("source", path, path.is_file())

  generated_paths = [
    ctx.paths["active_preset"],
    ctx.paths["active_profile"],
    ctx.paths["opencode_config"],
  ]
  for path in generated_paths:
    add_check(
      "generated",
      path,
      path.is_file(),
      generated=True,
      hint="Run ./bin/lac profile apply <profile> to regenerate state." if bootstrap_hint else None,
    )

  commands = {
    "opencode": command_exists("opencode"),
    "llama-server": command_exists("llama-server"),
    "omlx": command_exists("omlx"),
    "python3": command_exists("python3") or command_exists("python"),
  }

  active_profile_id = ctx.active_profile_id()
  active_profile = ctx.active_profile()
  required_command_names = {"opencode", "python3"}
  if active_profile and active_profile.get("runtime_mode") != "cloud":
    runtime = selected_local_runtime(active_profile)
    required_command_names.add("omlx" if runtime == "omlx" else "llama-server")
  command_install_hints = {
    name: _install_hint("python" if name == "python3" else name)
    for name, exists in commands.items()
    if name in required_command_names and not exists
  }
  runtime_status = collect_runtime_status(ctx)
  asset_catalog = load_asset_catalog(ctx)
  workflow_catalog = load_workflow_catalog(ctx)

  report = {
    "generated_at": utc_now(),
    "state_root": str(ctx.state_root),
    "checks": checks,
    "active_profile_id": active_profile_id,
    "active_profile": active_profile,
    "commands": commands,
    "command_install_hints": command_install_hints,
    "provider_readiness": collect_provider_readiness(ctx),
    "runtime": runtime_status,
    "assets": {
      "catalog_asset_count": len(asset_catalog["assets"]),
      "pack_count": len(workflow_catalog["packs"]),
      "opencode_agents": len(list((ctx.root / ".opencode/agents").glob("*.md"))),
      "opencode_skills": len(list((ctx.root / ".opencode/skills").glob("*/SKILL.md"))),
    },
  }

  failures = []
  for check in checks:
    if not check["exists"] and not check["generated"]:
      failures.append(check["path"])

  if strict:
    if active_profile and active_profile["runtime_mode"] != "cloud" and not runtime_status["health_reachable"]:
      failures.append("runtime health endpoint")
    required_runtime = runtime_status.get("runtime", "llama.cpp")
    required_commands = {"opencode", "omlx" if required_runtime == "omlx" else "llama-server"}
    for name, exists in commands.items():
      if name in required_commands and not exists:
        failures.append(name)

  report["ok"] = not failures
  report["failures"] = failures
  write_json(ctx.paths["doctor_report"], report)
  return report


def smoke(ctx, timeout):
  profile = ctx.active_profile()
  profile_id = ctx.active_profile_id()
  runtime = selected_local_runtime(profile)
  base_url = local_runtime_base_url(runtime)
  report = {
    "generated_at": utc_now(),
    "active_profile_id": profile_id,
    "profile": profile,
    "timeout_seconds": timeout,
    "runtime": runtime,
    "runtime_url": base_url,
    "client_assets": {
      "agents": len(list((ctx.root / ".opencode/agents").glob("*.md"))),
      "skills": len(list((ctx.root / ".opencode/skills").glob("*/SKILL.md"))),
    },
  }

  if profile and profile["runtime_mode"] == "cloud":
    report["skipped"] = True
    report["reason"] = "cloud-profile"
    report["ok"] = ctx.paths["opencode_config"].is_file()
    write_json(ctx.paths["smoke_report"], report)
    return report

  started = time.time()
  health = {}
  if runtime != "omlx":
    try:
      health, _ = request_json(f"{base_url}/health", timeout=timeout)
    except Exception as exc:
      report["ok"] = False
      report["error"] = f"health request failed: {exc}"
      write_json(ctx.paths["smoke_report"], report)
      return report

  try:
    models, _ = request_json(f"{base_url}/v1/models", timeout=timeout)
  except Exception as exc:
    report["ok"] = False
    report["error"] = f"models request failed: {exc}"
    write_json(ctx.paths["smoke_report"], report)
    return report

  chat_payload = {
    "model": load_json(ctx.paths["opencode_config"]).get("model", "local-cluster/default").split("/", 1)[1],
    "messages": [{"role": "user", "content": "Say hello in one word."}],
    "max_tokens": 16,
    "temperature": 0.1,
  }
  try:
    chat, _ = request_json(
      f"{base_url}/v1/chat/completions",
      method="POST",
      payload=chat_payload,
      timeout=timeout,
    )
  except Exception as exc:
    report["ok"] = False
    report["error"] = f"chat request failed: {exc}"
    write_json(ctx.paths["smoke_report"], report)
    return report

  elapsed_ms = int((time.time() - started) * 1000)
  choices = chat.get("choices", [])
  content = ""
  if choices:
    content = choices[0].get("message", {}).get("content", "")

  report.update(
    {
      "ok": bool(choices),
      "health": health,
      "model_count": len(models.get("data", [])),
      "chat_content_preview": content[:80],
      "benchmark_ms": elapsed_ms,
    }
  )
  write_json(ctx.paths["smoke_report"], report)
  return report


def write_runtime_state(state_path, pid_path, payload):
  write_json(state_path, payload)
  write_text(pid_path, f"{payload['pid']}\n")


def runtime_start(ctx, show_logs=False, tail_hint=True, foreground=False):
  profile = ctx.active_profile()
  profile_id = ctx.active_profile_id()
  if profile and profile["runtime_mode"] == "cloud":
    return {
      "ok": True,
      "skipped": True,
      "reason": f"Active profile '{profile_id}' is cloud-only.",
    }

  preset = ctx.paths["active_preset"]
  if not preset.is_file():
    raise SystemExit(f"Missing preset file: {preset}\nRun ./bin/lac profile apply <profile> first.")

  runtime = selected_local_runtime(profile, verbose=True)
  port = local_runtime_port(runtime)
  base_url = local_runtime_base_url(runtime)
  status = collect_runtime_status(ctx)
  if status["running"] and status["health_reachable"]:
    return {
      "ok": True,
      "running": True,
      "message": f"{runtime} already running at {base_url}",
      "log_path": status.get("log_path"),
    }

  paths = runtime_paths(ctx, runtime)
  pid_path = paths["pid"]
  state_path = paths["state"]
  log_path = paths["log"]

  log_path.parent.mkdir(parents=True, exist_ok=True)
  if log_path.exists():
    backup = log_path.with_suffix(log_path.suffix + ".1")
    if backup.exists():
      backup.unlink()
    log_path.replace(backup)

  env = os.environ.copy()
  if runtime == "omlx":
    if not command_exists(os.environ.get("OMLX_BIN", "omlx")):
      raise SystemExit("oMLX runtime selected but `omlx` is not in PATH. Install with Homebrew or set AI_LOCAL_RUNTIME=llama.cpp.")
    models_dir = Path(os.environ.get("AI_MODELS_DIR", str(ctx.root / "models"))) / "mlx"
    env["OMLX_MODEL_DIR"] = str(models_dir)
    env["OMLX_HOST"] = HOST
    env["OMLX_PORT"] = str(port)
    command = [os.environ.get("OMLX_BIN", "omlx"), "serve", "--model-dir", str(models_dir)]
    ready_url = f"{base_url}/v1/models"
  else:
    env["LLAMA_ARG_JINJA"] = "true"
    command = [
      os.environ.get("LLAMA_SERVER_BIN", "llama-server"),
      "--jinja",
      "--models-preset",
      str(preset),
      "--port",
      str(port),
      "--host",
      HOST,
    ]
    ready_url = f"{base_url}/health"

  def _write_runtime_state(payload):
    write_json(state_path, payload)
    write_text(pid_path, f"{payload['pid']}\n")

  if foreground:
    started_at = utc_now()

    def _foreground_cleanup(signum=None, frame=None):
      if signum is not None:
        log_info(f"\n[{runtime}] Received signal {signum}, shutting down...")
      try:
        process.terminate()
        process.wait(timeout=5)
      except (subprocess.TimeoutExpired, OSError):
        try:
          process.kill()
          process.wait(timeout=3)
        except Exception:
          pass
      pid_path.unlink(missing_ok=True)
      if signum is not None:
        raise SystemExit(128 + signum)

    original_sigint = signal.getsignal(signal.SIGINT)
    original_sigterm = signal.getsignal(signal.SIGTERM)
    signal.signal(signal.SIGINT, _foreground_cleanup)
    signal.signal(signal.SIGTERM, _foreground_cleanup)

    process = subprocess.Popen(command, env=env)
    payload = {
      "started_at": started_at,
      "ready_at": None,
      "launch_latency_ms": None,
      "pid": process.pid,
      "port": port,
      "host": HOST,
      "log_path": str(log_path),
      "profile_id": profile_id,
      "runtime": runtime,
      "foreground": True,
    }
    _write_runtime_state(payload)
    try:
      exit_code = process.wait()
    finally:
      signal.signal(signal.SIGINT, original_sigint)
      signal.signal(signal.SIGTERM, original_sigterm)
      pid_path.unlink(missing_ok=True)
    return {
      "ok": exit_code == 0,
      "running": False,
      "foreground": True,
      "exit_code": exit_code,
      "message": f"{runtime} exited with code {exit_code}",
    }

  started_at = utc_now()
  flags = 0
  kwargs = {}
  if os.name == "nt":
    flags = subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS
  else:
    kwargs["start_new_session"] = True

  log_handle = log_path.open("a", encoding="utf-8")
  process = subprocess.Popen(
    command,
    stdout=log_handle,
    stderr=subprocess.STDOUT,
    env=env,
    creationflags=flags,
    **kwargs,
  )

  ready = False
  for _ in range(60):
    time.sleep(1)
    if process.poll() is not None:
      break
    try:
      request_json(ready_url, timeout=2)
      ready = True
      break
    except Exception:
      continue

  if not ready:
    log_handle.close()
    recent = ""
    if log_path.exists():
      recent = "\n".join(log_path.read_text(encoding="utf-8").splitlines()[-20:])
    raise SystemExit(f"{runtime} failed to start.\nRecent logs:\n{recent}")

  ready_at = utc_now()
  payload = {
    "started_at": started_at,
    "ready_at": ready_at,
    "launch_latency_ms": int((datetime.fromisoformat(ready_at.replace("Z", "+00:00")) - datetime.fromisoformat(started_at.replace("Z", "+00:00"))).total_seconds() * 1000),
    "pid": process.pid,
    "port": port,
    "host": HOST,
    "log_path": str(log_path),
    "profile_id": profile_id,
    "runtime": runtime,
  }
  _write_runtime_state(payload)
  log_handle.close()

  result = {
    "ok": True,
    "running": True,
    "url": base_url,
    "log_path": str(log_path),
    "launch_latency_ms": payload["launch_latency_ms"],
  }

  if show_logs and command_exists("tail") and os.name != "nt":
    subprocess.run(["tail", "-f", str(log_path)], check=False)
  elif tail_hint:
    result["tail_hint"] = f"tail -f {log_path}"
  return result


def runtime_stop(ctx):
  runtime = selected_local_runtime(ctx.active_profile())
  paths = runtime_paths(ctx, runtime)
  pid_path = paths["pid"]
  label = paths["label"]
  if not pid_path.is_file():
    return {"ok": True, "running": False, "message": f"No {label} pid file found."}
  pid = int(pid_path.read_text(encoding="utf-8").strip())
  if not is_pid_running(pid):
    pid_path.unlink(missing_ok=True)
    return {"ok": True, "running": False, "message": f"{label} process was not running."}

  sig = signal.SIGTERM if os.name != "nt" else signal.SIGTERM
  os.kill(pid, sig)
  for _ in range(10):
    time.sleep(0.5)
    if not is_pid_running(pid):
      break
  if is_pid_running(pid):
    os.kill(pid, signal.SIGKILL if os.name != "nt" else signal.SIGTERM)
  pid_path.unlink(missing_ok=True)
  return {"ok": True, "running": False, "message": f"Stopped {label} pid {pid}."}


def runtime_status(ctx):
  report = collect_runtime_status(ctx)
  report["active_profile_id"] = ctx.active_profile_id()
  return report


def run_models_sync(profile_id):
  if os.name == "nt":
    command = [
      "pwsh",
      "-NoLogo",
      "-NoProfile",
      "-File",
      str(ROOT / "scripts/setup-models-device.ps1"),
      "-Profile",
      profile_id,
    ]
  else:
    command = ["bash", str(ROOT / "scripts/setup-models-device.sh"), "--profile", profile_id]
  result = subprocess.run(command, check=False)
  return result.returncode


def client_open(ctx, target, desktop=False):
  if target != "opencode":
    raise SystemExit("Only the OpenCode runtime target supports launch.")
  config_path = ctx.paths["opencode_config"]
  if not config_path.is_file():
    raise SystemExit(f"Missing generated OpenCode config: {config_path}\nRun ./bin/lac profile apply <profile> first.")

  env = os.environ.copy()
  env["OPENCODE_CONFIG"] = str(config_path)

  if desktop:
    app_name = os.environ.get("OPENCODE_DESKTOP_APP", "OpenCode")
    if sys.platform == "darwin":
      candidates = [
        Path("/Applications") / f"{app_name}.app" / "Contents/MacOS" / app_name,
        Path.home() / "Applications" / f"{app_name}.app" / "Contents/MacOS" / app_name,
      ]
      for executable in candidates:
        if executable.is_file():
          subprocess.Popen([str(executable)], env=env, start_new_session=True)
          return {
            "ok": True,
            "target": target,
            "desktop": True,
            "message": f"Launched {app_name} desktop with generated config: {config_path}",
          }
      if command_exists("open"):
        result = subprocess.run(["open", "-a", app_name], env=env, check=False)
        if result.returncode != 0:
          raise SystemExit(f"Failed to launch {app_name}. Set OPENCODE_DESKTOP_APP if the app name differs.")
        return {
          "ok": True,
          "target": target,
          "desktop": True,
          "message": f"Launched {app_name} desktop. If it was already running, restart it so OPENCODE_CONFIG is picked up: {config_path}",
        }
    raise SystemExit("Desktop auto-launch is only implemented for macOS.")

  if not command_exists("opencode"):
    raise SystemExit("opencode is not in PATH.")
  completed = subprocess.run(["opencode"], env=env, check=False)
  return {"ok": completed.returncode == 0, "target": target, "desktop": False}


def render_pack_list(packs):
  for pack in packs:
    clients = ", ".join(pack["supported_clients"])
    print(
      f"{pack['id']}: {pack['label']} | trust {pack['trust_level']} | "
      f"{pack['asset_count']} assets | clients: {clients}"
    )


def render_pack_show(pack):
  print(f"{pack['id']}: {pack['label']}")
  print(f"  trust: {pack['trust_level']}")
  print(f"  description: {pack['description']}")
  print(f"  clients: {', '.join(pack['supported_clients'])}")
  print(f"  tools: {', '.join(pack['required_tools'])}")
  print(f"  assets ({pack['asset_count']}):")
  for asset in pack["assets"]:
    print(
      f"    - {asset['id']} [{asset['type']}] "
      f"support={asset['support_tier']} trust={asset['trust_level']}"
    )


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
      print(
        f"{provider['id']}: {provider['label']} | {readiness} | "
        f"risk {provider['risk_level']} | verified {provider['last_verified_at']}"
      )
      continue
    flag = "ready" if provider["configured"] else "unset"
    print(
      f"{provider['id']}: {provider['label']} | env {provider['env_var']} ({flag}) | "
      f"risk {provider['risk_level']} | verified {provider['last_verified_at']}"
    )


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
  print(
    f"Providers: {payload['configured_count']} configured, "
    f"{payload['unconfigured_count']} unconfigured"
  )
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
  print(
    f"Summary: {summary['ok']} ok, {summary['skipped']} skipped, "
    f"{summary['error']} error"
  )


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
    print(f"Missing generated state: {len(missing_generated)} (run ./bin/lac profile apply <profile>)")

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
  print(
    f"Assets: {assets['catalog_asset_count']} cataloged | "
    f"{assets['pack_count']} packs | "
    f"{assets['opencode_agents']} agents | "
    f"{assets['opencode_skills']} skills"
  )
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


RAM_BUCKETS = [
  (120, ["128gb-multi", "128gb-qwen122b", "128gb-minimax"], "gemma-64gb"),
  (60, ["64gb"], "gemma-64gb"),
  (30, ["32gb"], "gemma-32gb"),
  (22, ["24gb"], "gemma-24gb"),
  (14, ["16gb"], "gemma-16gb"),
  (0, ["gemma-16gb"], "gemma-16gb"),
]


FAMILY_DESCRIPTIONS = {
  "qwen": "Qwen 3.6 — default. Stronger coding and agentic tool-use. Best for most workflows.",
  "gemma": "Gemma 4 — multilingual leader. Stronger EU-language handling, competitive reasoning.",
}


CLOUD_PROVIDER_HINTS = {
  "opencode-go": "$10/mo subscription. Curated model list. Recommended hosted overlay. Uses OPENCODE_GO_API_KEY.",
  "openrouter": "Free tier, rate-limited. Good trial fallback. Uses OPENROUTER_API_KEY.",
  "opencode-zen": "Pay-per-request (beta). Broader catalog than Go. Uses OPENCODE_ZEN_API_KEY.",
  "codex-auth": "Reuse ChatGPT Plus/Pro/Team via third-party OAuth helper. Uses OPENAI_API_KEY.",
  "anthropic": "Claude 4.x family (API key only — subscription does NOT work). Uses ANTHROPIC_API_KEY.",
  "antigravity": "Hosted fallback for frontier-grade cloud coding. Uses ANTIGRAVITY_API_KEY.",
  "z-ai": "Z.AI GLM family. Uses ZAI_API_KEY.",
  "nvidia-nim": "NVIDIA free/trial OpenAI-compatible endpoints. Uses NVIDIA_API_KEY.",
}


def detect_total_ram_gb():
  try:
    if sys.platform == "darwin":
      raw = subprocess.check_output(["sysctl", "-n", "hw.memsize"], stderr=subprocess.DEVNULL)
      return int(raw.strip()) / (1024 ** 3)
    if sys.platform.startswith("linux"):
      meminfo = Path("/proc/meminfo").read_text(encoding="utf-8")
      for line in meminfo.splitlines():
        if line.startswith("MemTotal:"):
          kb = int(line.split()[1])
          return kb / (1024 ** 2)
    if os.name == "nt":
      raw = subprocess.check_output(
        [
          "powershell.exe",
          "-NoProfile",
          "-Command",
          "(Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize",
        ],
        stderr=subprocess.DEVNULL,
      )
      kb = int(raw.strip())
      return kb / (1024 ** 2)
  except Exception:
    return None
  return None


def detect_hardware():
  return {
    "os": sys.platform,
    "arch": platform.machine(),
    "ram_gb": detect_total_ram_gb(),
  }


def _bucket_for_ram(ram_gb):
  if ram_gb is None:
    return RAM_BUCKETS[-2]
  for threshold, qwen_profiles, gemma_profile in RAM_BUCKETS:
    if ram_gb >= threshold:
      return (threshold, qwen_profiles, gemma_profile)
  return RAM_BUCKETS[-1]


def recommend_profile(ram_gb, family="qwen"):
  _, qwen_profiles, gemma_profile = _bucket_for_ram(ram_gb)
  if family == "gemma":
    return gemma_profile
  return qwen_profiles[0]


def family_alternatives(ram_gb):
  _, qwen_profiles, gemma_profile = _bucket_for_ram(ram_gb)
  return {
    "qwen": qwen_profiles[0],
    "gemma": gemma_profile,
  }


def _prompt_yes_no(prompt, default=True):
  suffix = "[Y/n]" if default else "[y/N]"
  while True:
    answer = input(f"{prompt} {suffix} ").strip().lower()
    if not answer:
      return default
    if answer in {"y", "yes"}:
      return True
    if answer in {"n", "no"}:
      return False


def _prompt_choice(prompt, choices, default_index=0):
  while True:
    print(prompt)
    for idx, (key, label) in enumerate(choices):
      marker = "*" if idx == default_index else " "
      print(f"  {marker} {idx + 1}. {key} — {label}")
    raw = input(f"Pick [1-{len(choices)}, default {default_index + 1}]: ").strip()
    if not raw:
      return choices[default_index][0]
    try:
      idx = int(raw) - 1
    except ValueError:
      print("Enter a number.")
      continue
    if 0 <= idx < len(choices):
      return choices[idx][0]
    print("Out of range.")


def _prompt_multiselect(prompt, choices, preselected):
  selected = set(preselected)
  print(prompt)
  print("Toggle by number. Blank line to accept.")
  while True:
    for idx, (key, label) in enumerate(choices):
      marker = "[x]" if key in selected else "[ ]"
      print(f"  {marker} {idx + 1}. {key} — {label}")
    raw = input(f"Toggle [1-{len(choices)}] or Enter to accept: ").strip()
    if not raw:
      return [key for key, _ in choices if key in selected]
    try:
      idx = int(raw) - 1
    except ValueError:
      print("Enter a number or press Enter to accept.")
      continue
    if 0 <= idx < len(choices):
      key = choices[idx][0]
      if key in selected:
        selected.remove(key)
      else:
        selected.add(key)
    else:
      print("Out of range.")


def _parse_cloud_arg(cloud_arg, no_cloud):
  if no_cloud:
    return []
  if not cloud_arg:
    return []
  return [item.strip() for item in cloud_arg.split(",") if item.strip()]


def _validate_cloud_ids(ctx, cloud_ids):
  catalog = load_json(ctx.paths["provider_catalog"])
  known = {p["id"] for p in catalog["providers"] if p["id"] != "local-cluster"}
  invalid = [cid for cid in cloud_ids if cid not in known]
  if invalid:
    raise SystemExit(f"Unknown cloud provider(s): {', '.join(invalid)}. Known: {', '.join(sorted(known))}")


def _provider_id_from_model(model_selector):
  if not isinstance(model_selector, str) or "/" not in model_selector:
    return ""
  return model_selector.split("/", 1)[0]


def _profile_provider_ids(profile):
  provider_ids = []
  for field in ("default_model", "small_model"):
    provider_id = _provider_id_from_model(profile.get(field, ""))
    if provider_id and provider_id not in provider_ids:
      provider_ids.append(provider_id)
  return provider_ids


def _init_recommendation(profile_id, profile, hardware):
  ram_gb = hardware.get("ram_gb")
  alternatives = family_alternatives(ram_gb)
  recommended_profile = recommend_profile(ram_gb)
  if profile["runtime_mode"] == "cloud":
    recommended_path = "cloud-only zero-download profile"
  else:
    recommended_path = "local-first with optional OpenCode Go and OpenRouter overlays"
  return {
    "selected_profile": profile_id,
    "selected_label": profile["label"],
    "selected_runtime_mode": profile["runtime_mode"],
    "hardware_recommended_profile": recommended_profile,
    "family_alternatives": alternatives,
    "default_cloud_overlays": ["opencode-go", "openrouter"],
    "recommended_path": recommended_path,
  }


def _status_item(item_id, label, ready, detail, command=None, optional=False, install_hint=None):
  item = {
    "id": item_id,
    "label": label,
    "status": "ready" if ready else ("optional" if optional else "blocked"),
    "detail": detail,
  }
  if command:
    item["command"] = command
  if install_hint and item["status"] != "ready":
    item["install_hint"] = install_hint
  return item


def _init_required_provider_ids(ctx, profile, cloud_ids):
  required = []
  known_cloud = {p["id"] for p in load_json(ctx.paths["provider_catalog"])["providers"] if p["id"] != "local-cluster"}
  for provider_id in _profile_provider_ids(profile) + list(cloud_ids):
    if provider_id in known_cloud and provider_id not in required:
      required.append(provider_id)
  return required


def _init_prerequisites(ctx, profile, cloud_ids):
  required = [
    _status_item(
      "python",
      "Python 3",
      command_exists("python3") or command_exists("python"),
      "Required to run the lac CLI.",
      command="python3 --version",
      install_hint=_install_hint("python"),
    ),
    _status_item(
      "opencode",
      "OpenCode CLI",
      command_exists("opencode"),
      "Required for `./bin/lac client open opencode`.",
      command="opencode --version",
      install_hint=_install_hint("opencode"),
    ),
  ]

  if profile.get("local_runtime_required"):
    runtime = selected_local_runtime(profile)
    runtime_command = "omlx" if runtime == "omlx" else "llama-server"
    required.append(
      _status_item(
        runtime_command,
        "Local runtime",
        command_exists(runtime_command),
        f"Required to start the selected local runtime ({runtime}).",
        command=f"{runtime_command} --help",
        install_hint=_install_hint(runtime_command),
      )
    )

  provider_catalog = {p["id"]: p for p in load_json(ctx.paths["provider_catalog"])["providers"]}
  for provider_id in _init_required_provider_ids(ctx, profile, cloud_ids):
    provider = provider_catalog[provider_id]
    env_var = provider["env_var"]
    env_command = f"$env:{env_var} = \"...\"" if _host_install_platform() == "windows" else f"export {env_var}=..."
    required.append(
      _status_item(
        f"{provider_id}-api-key",
        f"{provider['label']} API key",
        bool(os.environ.get(env_var)),
        f"Set {env_var} to use {provider_id}.",
        command=env_command,
        install_hint=_install_hint(f"{provider_id}-api-key", env_var=env_var),
      )
    )

  optional = [
    _status_item(
      "hf",
      "Hugging Face CLI",
      command_exists("hf") or command_exists("huggingface-cli"),
      "Optional helper for `./bin/lac models sync`.",
      command="hf --version",
      optional=True,
      install_hint=_install_hint("hf"),
    ),
    _status_item(
      "omlx",
      "oMLX",
      command_exists("omlx"),
      "Optional macOS MLX runtime when compatible models are selected.",
      command="omlx --help",
      optional=True,
      install_hint=_install_hint("omlx"),
    ),
  ]

  return {"required": required, "optional": optional}


def _init_readiness(prerequisites, profile):
  required = prerequisites["required"]
  blocked = [item for item in required if item["status"] == "blocked"]
  ready = [item for item in required if item["status"] == "ready"]
  readiness = [
    {
      "id": "config-rendered",
      "label": "Runtime config rendered",
      "status": "ready",
      "detail": "Generated state and client config are in place.",
    },
    {
      "id": "required-prerequisites",
      "label": "Required prerequisites",
      "status": "ready" if not blocked else "blocked",
      "detail": f"{len(ready)}/{len(required)} required checks are ready.",
    },
  ]
  if profile.get("downloads_required"):
    readiness.append(
      {
        "id": "model-downloads",
        "label": "Model weights",
        "status": "blocked",
        "detail": "Run the model sync command before starting the local runtime.",
      }
    )
  else:
    readiness.append(
      {
        "id": "model-downloads",
        "label": "Model weights",
        "status": "ready",
        "detail": "Selected profile does not require local model downloads.",
      }
    )
  return readiness


def _init_status(readiness):
  return "blocked" if any(item["status"] == "blocked" for item in readiness) else "ready"


def _next_steps(ctx, profile_id, cloud_ids, also_download_profile=None):
  profile = ctx.get_profile(profile_id)
  steps = []
  for cid in cloud_ids:
    hint = CLOUD_PROVIDER_HINTS.get(cid, "see docs/providers/AUTHENTICATION.md")
    steps.append(f"Enable {cid}: {hint}")
  if profile.get("downloads_required"):
    steps.append(f"Download models: ./bin/lac models sync {profile_id}")
    if also_download_profile and also_download_profile != profile_id:
      steps.append(f"Also download alternate family weights: ./bin/lac models sync {also_download_profile}")
  if profile.get("local_runtime_required"):
    steps.append("Start runtime: ./bin/lac runtime start")
  else:
    required_providers = _init_required_provider_ids(ctx, profile, cloud_ids)
    for provider_id in required_providers:
      steps.append(f"Verify {provider_id}: ./bin/lac provider verify {provider_id}")
  steps.append("Open client: ./bin/lac client open opencode")
  return steps


def init_wizard(ctx, yes=False, profile=None, cloud=None, no_cloud=False, also_download=False):
  hardware = detect_hardware()
  ram_gb = hardware["ram_gb"]

  if yes:
    chosen_profile = profile or recommend_profile(ram_gb)
    ctx.get_profile(chosen_profile)
    cloud_ids = _parse_cloud_arg(cloud, no_cloud)
    if not cloud_ids and not no_cloud and cloud is None:
      cloud_ids = ["opencode-go", "openrouter"]
    _validate_cloud_ids(ctx, cloud_ids)
    also_download_profile = None
  else:
    ram_label = f"{ram_gb:.1f} GB" if ram_gb is not None else "unknown"
    print(f"Detected: {hardware['os']} / {hardware['arch']} / RAM {ram_label}")
    alternates = family_alternatives(ram_gb)

    family_choices = [
      ("qwen", FAMILY_DESCRIPTIONS["qwen"]),
      ("gemma", FAMILY_DESCRIPTIONS["gemma"]),
    ]
    family = _prompt_choice("Which local model family?", family_choices, default_index=0)
    recommended = recommend_profile(ram_gb, family=family)

    if profile:
      ctx.get_profile(profile)
      chosen_profile = profile
    else:
      print(f"Recommended profile for your hardware: {recommended}")
      if not _prompt_yes_no("Use this profile?", default=True):
        print("Available profiles:")
        options = [(pid, ctx.profiles[pid]["label"]) for pid in ctx.profiles]
        chosen_profile = _prompt_choice("Pick a profile:", options, default_index=list(ctx.profiles).index(recommended))
      else:
        chosen_profile = recommended

    also_download_profile = None
    other_family = "gemma" if family == "qwen" else "qwen"
    other_profile = alternates[other_family]
    if other_profile != chosen_profile:
      if _prompt_yes_no(
        f"Also download {other_family.capitalize()} weights ({other_profile}) for optional switching?",
        default=False,
      ):
        also_download_profile = other_profile

    cloud_choices = [(cid, CLOUD_PROVIDER_HINTS[cid]) for cid in CLOUD_PROVIDER_HINTS]
    cloud_ids = _prompt_multiselect(
      "Which hosted model overlays do you want in addition to local models?",
      cloud_choices,
      preselected=["opencode-go", "openrouter"],
    )

  summary = profile_apply(ctx, chosen_profile, verbose_runtime=False)
  chosen_profile_record = ctx.get_profile(chosen_profile)
  prerequisites = _init_prerequisites(ctx, chosen_profile_record, cloud_ids)
  readiness = _init_readiness(prerequisites, chosen_profile_record)
  generated = dict(summary["generated"])
  generated["client_manifest"] = summary["render"]["manifest_path"]

  result = {
    "applied": True,
    "status": _init_status(readiness),
    "profile": chosen_profile,
    "cloud": cloud_ids,
    "hardware": hardware,
    "recommendation": _init_recommendation(chosen_profile, chosen_profile_record, hardware),
    "prerequisites": prerequisites,
    "readiness": readiness,
    "generated": generated,
    "also_download_profile": also_download_profile,
    "state_root": summary["state_root"],
    "next_steps": _next_steps(ctx, chosen_profile, cloud_ids, also_download_profile=also_download_profile),
  }
  return result


def _render_init_section(title, items):
  print(title)
  for item in items:
    marker = {
      "ready": "ready",
      "blocked": "blocked",
      "optional": "optional",
    }.get(item["status"], item["status"])
    print(f"  - {marker}: {item['label']} — {item['detail']}")
    if item.get("command") and item["status"] == "blocked":
      print(f"    next: {item['command']}")
    install_hint = item.get("install_hint")
    if install_hint and item["status"] != "ready":
      print(f"    note: {install_hint['summary']}")
      for command in install_hint.get("commands", []):
        print(f"    install: {command}")


def render_init_text(result):
  hardware = result["hardware"]
  ram_label = f"{hardware['ram_gb']:.1f} GB" if hardware.get("ram_gb") is not None else "unknown"
  recommendation = result["recommendation"]
  print("Local AI Cluster init")
  print(f"Status: {result['status']}")
  print(f"Detected: {hardware['os']} / {hardware['arch']} / RAM {ram_label}")
  print(f"Selected profile: {result['profile']} ({recommendation['selected_label']})")
  print(f"Recommended path: {recommendation['recommended_path']}")
  if result["cloud"]:
    print(f"Cloud overlays selected: {', '.join(result['cloud'])}")
  elif recommendation["selected_runtime_mode"] == "cloud":
    print("Cloud overlays: none added (selected profile is already cloud-only)")
  else:
    print("Cloud overlays: none (pure local)")
  print("Generated:")
  for label, path in result["generated"].items():
    print(f"  - {label}: {path}")
  _render_init_section("Readiness:", result["readiness"])
  _render_init_section("Required checks:", result["prerequisites"]["required"])
  optional_blocked = [item for item in result["prerequisites"]["optional"] if item["status"] != "ready"]
  if optional_blocked:
    _render_init_section("Optional checks:", optional_blocked)
  print("Next steps:")
  for step in result["next_steps"]:
    print(f"  - {step}")


def emit(payload, json_mode=False, kind=None):
  if json_mode:
    print(json.dumps(payload, indent=2))
    return

  if kind == "pack-list":
    render_pack_list(payload)
    return
  if kind == "pack-show":
    render_pack_show(payload)
    return
  if kind == "scenario-list":
    render_scenario_list(payload)
    return
  if kind == "scenario-show":
    render_scenario_show(payload)
    return
  if kind == "provider-list":
    render_provider_list(payload)
    return
  if kind == "provider-models":
    render_provider_models(payload["provider_id"], payload["models"])
    return
  if kind == "provider-status":
    render_provider_status(payload)
    return
  if kind == "provider-verify":
    render_provider_verify_single(payload)
    return
  if kind == "provider-verify-all":
    render_provider_verify_all(payload)
    return
  if kind == "doctor":
    render_doctor_text(payload)
    return
  if kind == "smoke":
    render_smoke_text(payload)
    return
  if kind == "init":
    render_init_text(payload)
    return

  if isinstance(payload, list):
    for item in payload:
      print(
        f"{item['id']}: {item['label']} | {item['runtime_mode']} | "
        f"{item['verification_tier']} | {', '.join(item['recommended_for'])}"
      )
    return

  if isinstance(payload, dict):
    if payload.get("desktop") and payload.get("message"):
      print(payload["message"])
      return
    if payload.get("profile_id") and payload.get("generated"):
      print(f"Applied profile: {payload['profile_id']}")
      print(f"State root: {payload['state_root']}")
      print(f"Generated OpenCode config: {payload['generated']['opencode_config']}")
      return
    if payload.get("running") and payload.get("url"):
      print(f"llama-server ready at {payload['url']}")
      print(f"Log file: {payload['log_path']}")
      if payload.get("tail_hint"):
        print(f"Tail logs: {payload['tail_hint']}")
      return
    if payload.get("target") and payload.get("manifest_path"):
      print(f"Rendered {payload['target']} adapter: {payload['manifest_path']}")
      return
    if payload.get("message"):
      print(payload["message"])
      return
    if payload.get("skipped") and payload.get("reason"):
      print(payload["reason"])
      return

  print(json.dumps(payload, indent=2))


def build_parser():
  parser = argparse.ArgumentParser(prog="lac", description="Local AI Cluster 2.0 CLI")
  parser.add_argument("--version", action="version", version=f"lac {VERSION}")
  parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON")
  subparsers = parser.add_subparsers(dest="command", required=True)

  doctor_parser = subparsers.add_parser("doctor")
  doctor_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
  doctor_parser.add_argument("--strict", action="store_true")
  doctor_parser.add_argument("--bootstrap-hint", action="store_true")

  smoke_parser = subparsers.add_parser("smoke")
  smoke_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
  smoke_parser.add_argument("--timeout", type=int, default=int(os.environ.get("SMOKE_TIMEOUT", "30")))

  profile_parser = subparsers.add_parser("profile")
  profile_sub = profile_parser.add_subparsers(dest="profile_command", required=True)
  profile_list_parser = profile_sub.add_parser("list")
  profile_list_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
  profile_apply_parser = profile_sub.add_parser("apply")
  profile_apply_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
  profile_apply_parser.add_argument("profile_id")
  profile_apply_parser.add_argument("--render-target", default="opencode")

  models_parser = subparsers.add_parser("models")
  models_sub = models_parser.add_subparsers(dest="models_command", required=True)
  models_sync_parser = models_sub.add_parser("sync")
  models_sync_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
  models_sync_parser.add_argument("profile_id")

  runtime_parser = subparsers.add_parser("runtime")
  runtime_sub = runtime_parser.add_subparsers(dest="runtime_command", required=True)
  runtime_start_parser = runtime_sub.add_parser("start")
  runtime_start_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
  runtime_start_parser.add_argument("--foreground", action="store_true", help="Run llama-server attached to this terminal for visible logs")
  runtime_start_parser.add_argument("--show-logs", action="store_true")
  runtime_start_parser.add_argument("--no-tail-hint", action="store_true")
  runtime_status_parser = runtime_sub.add_parser("status")
  runtime_status_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
  runtime_stop_parser = runtime_sub.add_parser("stop")
  runtime_stop_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)

  client_parser = subparsers.add_parser("client")
  client_sub = client_parser.add_subparsers(dest="client_command", required=True)
  client_render_parser = client_sub.add_parser("render")
  client_render_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
  client_render_parser.add_argument("target", choices=["opencode", "claude-code", "codex-reference"])
  client_open_parser = client_sub.add_parser("open")
  client_open_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
  client_open_parser.add_argument("target", choices=["opencode"])
  client_open_parser.add_argument("--desktop", action="store_true")

  pack_parser = subparsers.add_parser("pack")
  pack_sub = pack_parser.add_subparsers(dest="pack_command", required=True)
  pack_list_parser = pack_sub.add_parser("list")
  pack_list_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
  pack_show_parser = pack_sub.add_parser("show")
  pack_show_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
  pack_show_parser.add_argument("pack_id")

  scenario_parser = subparsers.add_parser("scenario")
  scenario_sub = scenario_parser.add_subparsers(dest="scenario_command", required=True)
  scenario_list_parser = scenario_sub.add_parser("list")
  scenario_list_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
  scenario_show_parser = scenario_sub.add_parser("show")
  scenario_show_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
  scenario_show_parser.add_argument("scenario_id")

  provider_parser = subparsers.add_parser("provider")
  provider_sub = provider_parser.add_subparsers(dest="provider_command", required=True)
  provider_list_parser = provider_sub.add_parser("list")
  provider_list_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
  provider_models_parser = provider_sub.add_parser("models")
  provider_models_parser.add_argument("provider_id")
  provider_models_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
  provider_status_parser = provider_sub.add_parser("status")
  provider_status_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
  provider_verify_parser = provider_sub.add_parser("verify")
  provider_verify_parser.add_argument(
    "provider_id", nargs="?", help="Provider id (omit with --all)"
  )
  provider_verify_parser.add_argument(
    "--all", action="store_true", dest="all_providers", help="Verify every catalog provider"
  )
  provider_verify_parser.add_argument(
    "--timeout", type=int, default=5, help="Per-request timeout in seconds"
  )
  provider_verify_parser.add_argument(
    "--refresh-catalog",
    action="store_true",
    dest="refresh_catalog",
    help="Update last_verified_at in catalog/providers.json on success",
  )
  provider_verify_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)

  init_parser = subparsers.add_parser("init", help="Interactive onboarding wizard")
  init_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
  init_parser.add_argument("--yes", action="store_true", help="Non-interactive; accept defaults or flag values")
  init_parser.add_argument("--profile", help="Profile id to apply (skip recommendation)")
  init_parser.add_argument("--cloud", help="Comma-separated cloud provider ids to enable (non-interactive)")
  init_parser.add_argument("--no-cloud", action="store_true", help="Do not enable any cloud overlay")

  return parser


def main():
  parser = build_parser()
  argv, json_mode = _strip_global_json_flag(sys.argv[1:])
  args = parser.parse_args(argv)
  args.json = bool(getattr(args, "json", False) or json_mode)
  ctx = Context()

  if args.command == "doctor":
    report = doctor(ctx, strict=args.strict, bootstrap_hint=args.bootstrap_hint)
    emit(report, args.json, kind="doctor")
    raise SystemExit(0 if report["ok"] or not args.strict else 1)

  if args.command == "smoke":
    report = smoke(ctx, timeout=args.timeout)
    emit(report, args.json, kind="smoke")
    raise SystemExit(0 if report.get("ok", False) else 1)

  if args.command == "profile":
    if args.profile_command == "list":
      emit(profile_list(ctx), args.json)
      return
    if args.profile_command == "apply":
      emit(profile_apply(ctx, args.profile_id, render_target=args.render_target), args.json)
      return

  if args.command == "models":
    if args.models_command == "sync":
      raise SystemExit(run_models_sync(args.profile_id))

  if args.command == "runtime":
    if args.runtime_command == "start":
      emit(
        runtime_start(
          ctx,
          show_logs=args.show_logs,
          tail_hint=not args.no_tail_hint,
          foreground=args.foreground,
        ),
        args.json,
      )
      return
    if args.runtime_command == "status":
      emit(runtime_status(ctx), args.json)
      return
    if args.runtime_command == "stop":
      emit(runtime_stop(ctx), args.json)
      return

  if args.command == "client":
    if args.client_command == "render":
      emit(render_client(ctx, args.target), args.json)
      return
    if args.client_command == "open":
      emit(client_open(ctx, args.target, desktop=args.desktop), args.json)
      return

  if args.command == "pack":
    if args.pack_command == "list":
      emit(pack_list(ctx), args.json, kind="pack-list")
      return
    if args.pack_command == "show":
      emit(pack_show(ctx, args.pack_id), args.json, kind="pack-show")
      return

  if args.command == "scenario":
    if args.scenario_command == "list":
      emit(scenario_list(ctx), args.json, kind="scenario-list")
      return
    if args.scenario_command == "show":
      emit(scenario_show(ctx, args.scenario_id), args.json, kind="scenario-show")
      return

  if args.command == "provider":
    if args.provider_command == "list":
      emit(provider_list(ctx), args.json, kind="provider-list")
      return
    if args.provider_command == "models":
      payload = {
        "provider_id": args.provider_id,
        "models": provider_models(ctx, args.provider_id),
      }
      emit(payload if not args.json else payload["models"], args.json, kind="provider-models")
      return
    if args.provider_command == "status":
      emit(provider_status(ctx), args.json, kind="provider-status")
      return
    if args.provider_command == "verify":
      if args.all_providers and args.provider_id:
        parser.error("provider verify: pass either <provider_id> or --all, not both")
      if not args.all_providers and not args.provider_id:
        parser.error("provider verify: pass a provider_id or --all")
      if args.all_providers:
        results = [
          _verify_provider_record(ctx, p["id"], timeout=args.timeout, include_internal=args.refresh_catalog)
          for p in load_json(ctx.paths["provider_catalog"])["providers"]
        ]
        payload = {"results": results}
        payload["summary"] = {
          "ok": sum(1 for r in results if r["status"] == "ok"),
          "skipped": sum(1 for r in results if r["status"] == "skipped"),
          "error": sum(1 for r in results if r["status"] == "error"),
          "total": len(results),
        }
        if args.refresh_catalog:
          refresh_provider_catalog(ctx, payload["results"])
          for record in payload["results"]:
            record.pop("parsed_models", None)
        emit(payload, args.json, kind="provider-verify-all")
        raise SystemExit(1 if payload["summary"]["error"] else 0)
      record = _verify_provider_record(
        ctx,
        args.provider_id,
        timeout=args.timeout,
        include_internal=args.refresh_catalog,
      )
      if args.refresh_catalog:
        refresh_provider_catalog(ctx, [record])
        record.pop("parsed_models", None)
      emit(record, args.json, kind="provider-verify")
      raise SystemExit(1 if record["status"] == "error" else 0)

  if args.command == "init":
    result = init_wizard(
      ctx,
      yes=args.yes,
      profile=args.profile,
      cloud=args.cloud,
      no_cloud=args.no_cloud,
    )
    emit(result, args.json, kind="init")
    return

  parser.error("Unknown command")


if __name__ == "__main__":
  main()
