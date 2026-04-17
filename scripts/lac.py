#!/usr/bin/env python3
import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
STATE_ROOT = Path(os.environ.get("AI_CLUSTER_STATE_ROOT", ROOT / "state"))
PORT = int(os.environ.get("AI_CLUSTER_PORT", "8080"))
HOST = os.environ.get("AI_CLUSTER_HOST", "127.0.0.1")


def utc_now():
  return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def strip_jsonc(text):
  return "\n".join(
    line for line in text.splitlines() if not line.lstrip().startswith("//")
  )


def load_json(path):
  return json.loads(path.read_text(encoding="utf-8"))


def load_jsonc(path):
  return json.loads(strip_jsonc(path.read_text(encoding="utf-8")))


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


def read_text(path):
  return path.read_text(encoding="utf-8")


def request_json(url, method="GET", payload=None, timeout=5):
  headers = {}
  data = None
  if payload is not None:
    headers["Content-Type"] = "application/json"
    data = json.dumps(payload).encode("utf-8")
  request = urllib.request.Request(url, data=data, headers=headers, method=method)
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


class Context:
  def __init__(self):
    self.root = ROOT
    self.state_root = STATE_ROOT
    self.paths = {
      "profile_manifest": self.root / "runtime-config/profiles.json",
      "opencode_template": self.root / "opencode.jsonc",
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


def render_opencode_config(ctx, profile_id, profile):
  template = load_jsonc(ctx.paths["opencode_template"])
  template["model"] = profile["default_model"]
  template["small_model"] = profile["small_model"]
  write_json(ctx.paths["opencode_config"], template)
  return ctx.paths["opencode_config"]


def render_preset(ctx, profile):
  models_dir = Path(os.environ.get("AI_MODELS_DIR", ctx.root / "models"))
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


def profile_apply(ctx, profile_id, render_target="opencode"):
  profile = ctx.get_profile(profile_id)
  render_preset(ctx, profile)
  render_opencode_config(ctx, profile_id, profile)
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


def collect_provider_readiness(ctx):
  catalog = load_json(ctx.paths["provider_catalog"])
  results = []
  for provider in catalog["providers"]:
    env_var = provider["env_var"]
    results.append(
      {
        "id": provider["id"],
        "label": provider["label"],
        "env_var": env_var,
        "configured": bool(os.environ.get(env_var)),
        "risk_level": provider["risk_level"],
        "last_verified_at": provider["last_verified_at"],
      }
    )
  return results


def collect_runtime_status(ctx):
  runtime = {
    "host": HOST,
    "port": PORT,
    "url": f"http://{HOST}:{PORT}",
    "log_path": str(ctx.paths["llama_log"]),
    "pid_path": str(ctx.paths["llama_pid"]),
    "running": False,
    "health_reachable": False,
  }

  if ctx.paths["llama_pid"].is_file():
    try:
      pid = int(ctx.paths["llama_pid"].read_text(encoding="utf-8").strip())
    except ValueError:
      pid = 0
    runtime["pid"] = pid
    runtime["running"] = is_pid_running(pid)

  if ctx.paths["llama_state"].is_file():
    runtime["launch"] = load_json(ctx.paths["llama_state"])

  try:
    health, _ = request_json(f"http://{HOST}:{PORT}/health", timeout=2)
    runtime["health_reachable"] = True
    runtime["health"] = health
  except Exception:
    runtime["health_reachable"] = False

  return runtime


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
    "python3": command_exists("python3") or command_exists("python"),
  }

  active_profile_id = ctx.active_profile_id()
  active_profile = ctx.active_profile()
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
    for name, exists in commands.items():
      if name in {"opencode", "llama-server"} and not exists:
        failures.append(name)

  report["ok"] = not failures
  report["failures"] = failures
  write_json(ctx.paths["doctor_report"], report)
  return report


def smoke(ctx, timeout):
  profile = ctx.active_profile()
  profile_id = ctx.active_profile_id()
  report = {
    "generated_at": utc_now(),
    "active_profile_id": profile_id,
    "profile": profile,
    "timeout_seconds": timeout,
    "runtime_url": f"http://{HOST}:{PORT}",
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
  try:
    health, _ = request_json(f"http://{HOST}:{PORT}/health", timeout=timeout)
  except Exception as exc:
    report["ok"] = False
    report["error"] = f"health request failed: {exc}"
    write_json(ctx.paths["smoke_report"], report)
    return report

  try:
    models, _ = request_json(f"http://{HOST}:{PORT}/v1/models", timeout=timeout)
  except Exception as exc:
    report["ok"] = False
    report["error"] = f"models request failed: {exc}"
    write_json(ctx.paths["smoke_report"], report)
    return report

  chat_payload = {
    "model": "default",
    "messages": [{"role": "user", "content": "Say hello in one word."}],
    "max_tokens": 16,
    "temperature": 0.1,
  }
  try:
    chat, _ = request_json(
      f"http://{HOST}:{PORT}/v1/chat/completions",
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


def write_runtime_state(ctx, payload):
  write_json(ctx.paths["llama_state"], payload)
  write_text(ctx.paths["llama_pid"], f"{payload['pid']}\n")


def runtime_start(ctx, show_logs=False, tail_hint=True):
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

  status = collect_runtime_status(ctx)
  if status["running"] and status["health_reachable"]:
    return {
      "ok": True,
      "running": True,
      "message": f"llama-server already running at http://{HOST}:{PORT}",
      "log_path": str(ctx.paths["llama_log"]),
    }

  log_path = ctx.paths["llama_log"]
  log_path.parent.mkdir(parents=True, exist_ok=True)
  if log_path.exists():
    backup = log_path.with_suffix(log_path.suffix + ".1")
    if backup.exists():
      backup.unlink()
    log_path.replace(backup)

  command = [
    os.environ.get("LLAMA_SERVER_BIN", "llama-server"),
    "--models-preset",
    str(preset),
    "--port",
    str(PORT),
    "--host",
    HOST,
  ]

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
    creationflags=flags,
    **kwargs,
  )

  ready = False
  for _ in range(60):
    time.sleep(1)
    if process.poll() is not None:
      break
    try:
      request_json(f"http://{HOST}:{PORT}/health", timeout=2)
      ready = True
      break
    except Exception:
      continue

  if not ready:
    log_handle.close()
    recent = ""
    if log_path.exists():
      recent = "\n".join(log_path.read_text(encoding="utf-8").splitlines()[-20:])
    raise SystemExit(f"llama-server failed to start.\nRecent logs:\n{recent}")

  ready_at = utc_now()
  payload = {
    "started_at": started_at,
    "ready_at": ready_at,
    "launch_latency_ms": int((datetime.fromisoformat(ready_at.replace("Z", "+00:00")) - datetime.fromisoformat(started_at.replace("Z", "+00:00"))).total_seconds() * 1000),
    "pid": process.pid,
    "port": PORT,
    "host": HOST,
    "log_path": str(log_path),
    "profile_id": profile_id,
  }
  write_runtime_state(ctx, payload)
  log_handle.close()

  result = {
    "ok": True,
    "running": True,
    "url": f"http://{HOST}:{PORT}",
    "log_path": str(log_path),
    "launch_latency_ms": payload["launch_latency_ms"],
  }

  if show_logs and command_exists("tail") and os.name != "nt":
    subprocess.run(["tail", "-f", str(log_path)], check=False)
  elif tail_hint:
    result["tail_hint"] = f"tail -f {log_path}"
  return result


def runtime_stop(ctx):
  if not ctx.paths["llama_pid"].is_file():
    return {"ok": True, "running": False, "message": "No pid file found."}
  pid = int(ctx.paths["llama_pid"].read_text(encoding="utf-8").strip())
  if not is_pid_running(pid):
    ctx.paths["llama_pid"].unlink(missing_ok=True)
    return {"ok": True, "running": False, "message": "Process was not running."}

  sig = signal.SIGTERM if os.name != "nt" else signal.SIGTERM
  os.kill(pid, sig)
  for _ in range(10):
    time.sleep(0.5)
    if not is_pid_running(pid):
      break
  if is_pid_running(pid):
    os.kill(pid, signal.SIGKILL if os.name != "nt" else signal.SIGTERM)
  ctx.paths["llama_pid"].unlink(missing_ok=True)
  return {"ok": True, "running": False, "message": f"Stopped pid {pid}."}


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
    if sys.platform == "darwin" and command_exists("open"):
      result = subprocess.run(["open", "-a", app_name], env=env, check=False)
      if result.returncode != 0:
        raise SystemExit(f"Failed to launch {app_name}. Set OPENCODE_DESKTOP_APP if the app name differs.")
      return {"ok": True, "target": target, "desktop": True, "message": f"Launched {app_name} desktop."}
    raise SystemExit("Desktop auto-launch is only implemented for macOS.")

  if not command_exists("opencode"):
    raise SystemExit("opencode is not in PATH.")
  completed = subprocess.run(["opencode"], env=env, check=False)
  return {"ok": completed.returncode == 0, "target": target, "desktop": False}


def emit(payload, json_mode=False):
  if json_mode:
    print(json.dumps(payload, indent=2))
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

  return parser


def main():
  parser = build_parser()
  args = parser.parse_args()
  ctx = Context()

  if args.command == "doctor":
    report = doctor(ctx, strict=args.strict, bootstrap_hint=args.bootstrap_hint)
    emit(report, args.json)
    raise SystemExit(0 if report["ok"] or not args.strict else 1)

  if args.command == "smoke":
    report = smoke(ctx, timeout=args.timeout)
    emit(report, args.json)
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
      emit(runtime_start(ctx, show_logs=args.show_logs, tail_hint=not args.no_tail_hint), args.json)
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

  parser.error("Unknown command")


if __name__ == "__main__":
  main()
