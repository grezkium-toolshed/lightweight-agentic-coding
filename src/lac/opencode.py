"""OpenCode launch environment and read-only coexistence diagnostics."""

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

from lac.lib.jsonc import load_jsonc


OPENCODE_INSPECTION_TIMEOUT = 10


def opencode_env(ctx, base=None):
    """Return the environment used for lac-managed OpenCode processes."""
    env = dict(base if base is not None else os.environ)
    env["OPENCODE_CONFIG"] = str(ctx.paths["opencode_config"])
    env["OPENCODE_CONFIG_DIR"] = str(ctx.paths["opencode_config_dir"])
    env["OPENCODE_DISABLE_AUTOUPDATE"] = "1"
    return env


def _config_sources(ctx, cwd=None, env=None):
    env = env or os.environ
    sources = []
    seen = set()

    def add(kind, path, require_exists=True):
        if not path:
            return
        path = Path(path).expanduser().resolve()
        key = str(path)
        if key in seen or (require_exists and not path.is_file()):
            return
        seen.add(key)
        sources.append({"kind": kind, "path": key})

    add("lac-generated", ctx.paths["opencode_config"], require_exists=False)
    custom = env.get("OPENCODE_CONFIG")
    if custom and Path(custom).expanduser() != ctx.paths["opencode_config"]:
        add("environment", custom)

    global_root = Path(env.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "opencode"
    for name in ("opencode.json", "opencode.jsonc"):
        add("global", global_root / name)

    current = Path(cwd or Path.cwd()).resolve()
    for candidate in (current, *current.parents):
        for name in ("opencode.json", "opencode.jsonc"):
            add("project", candidate / name)
        if (candidate / ".git").exists():
            break
    return sources


def _warning(code, message, remediation, severity="warning"):
    return {
        "code": code,
        "severity": severity,
        "message": message,
        "remediation": remediation,
    }


def _inspection_failure(ctx, code, message, remediation, cwd=None, env=None):
    return {
        "checked": False,
        "detected_config_sources": _config_sources(ctx, cwd=cwd, env=env),
        "warnings": [_warning(code, message, remediation)],
    }


def _parse_effective_config(output):
    output = (output or "").strip()
    if not output:
        raise ValueError("OpenCode returned no configuration")
    try:
        value = json.loads(output)
    except json.JSONDecodeError:
        start = output.find("{")
        end = output.rfind("}")
        if start < 0 or end <= start:
            raise
        value = json.loads(output[start:end + 1])
    if not isinstance(value, dict):
        raise ValueError("OpenCode effective configuration is not an object")
    return value


def _allowed_plugins(ctx):
    try:
        generated = load_jsonc(ctx.paths["opencode_config"])
    except (OSError, ValueError):
        return set()
    plugins = generated.get("plugin", [])
    return {str(item) for item in plugins} if isinstance(plugins, list) else set()


def inspect_opencode_coexistence(ctx, profile=None, env=None, cwd=None, command=None, runner=None):
    """Inspect OpenCode's merged config without changing or persisting it."""
    launch_env = opencode_env(ctx, env)
    sources = _config_sources(ctx, cwd=cwd, env=launch_env)
    if not ctx.paths["opencode_config"].is_file():
        return _inspection_failure(
            ctx,
            "effective-config-unavailable",
            "The generated lac OpenCode config does not exist.",
            "Run `lac profile apply <profile>` and retry.",
            cwd=cwd,
            env=launch_env,
        )

    command = command or shutil.which("opencode")
    if not command:
        return _inspection_failure(
            ctx,
            "effective-config-unavailable",
            "OpenCode is unavailable, so lac could not inspect the merged configuration.",
            "Install the validated OpenCode version, then run `lac doctor` again.",
            cwd=cwd,
            env=launch_env,
        )

    run = runner or subprocess.run
    try:
        completed = run(
            [command, "debug", "config", "--pure"],
            env=launch_env,
            cwd=str(Path(cwd or Path.cwd()).resolve()),
            capture_output=True,
            text=True,
            timeout=OPENCODE_INSPECTION_TIMEOUT,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return _inspection_failure(
            ctx,
            "effective-config-unavailable",
            "OpenCode effective-config inspection timed out after 10 seconds.",
            "Run `opencode debug config --pure` manually and review inherited settings.",
            cwd=cwd,
            env=launch_env,
        )
    except OSError as exc:
        return _inspection_failure(
            ctx,
            "effective-config-unavailable",
            f"OpenCode effective-config inspection could not start: {exc}.",
            "Check the OpenCode executable and run `lac doctor` again.",
            cwd=cwd,
            env=launch_env,
        )
    if completed.returncode != 0:
        return _inspection_failure(
            ctx,
            "effective-config-unavailable",
            f"OpenCode effective-config inspection exited with code {completed.returncode}.",
            "Run `opencode debug config --pure` manually and resolve its error.",
            cwd=cwd,
            env=launch_env,
        )
    try:
        effective = _parse_effective_config(completed.stdout)
    except (ValueError, json.JSONDecodeError):
        return _inspection_failure(
            ctx,
            "effective-config-unavailable",
            "OpenCode returned an unreadable effective configuration.",
            "Run `opencode debug config --pure` manually and review its output.",
            cwd=cwd,
            env=launch_env,
        )

    warnings = []
    inherited = [source for source in sources if source["kind"] != "lac-generated"]
    if inherited:
        warnings.append(_warning(
            "existing-config-merged",
            "OpenCode merged existing global or project configuration into this lac session.",
            "Review the detected sources and the warnings below; lac does not modify those files.",
            severity="info",
        ))

    if effective.get("share") != "disabled":
        warnings.append(_warning(
            "sharing-enabled",
            f"Effective OpenCode sharing mode is {effective.get('share', 'unset')!r}, not 'disabled'.",
            "Set `share` to `disabled` in the later-precedence project config before treating the session as local-only.",
        ))
    if effective.get("autoupdate") is not False:
        warnings.append(_warning(
            "autoupdate-enabled",
            "Effective OpenCode configuration does not disable automatic updates.",
            "Set `autoupdate` to false; lac also disables updates in the launch environment.",
        ))

    profile = profile or {}
    if profile.get("runtime_mode") == "local":
        expected_provider = str(profile.get("default_model", "local-cluster/default")).split("/", 1)[0]
        selected_model = str(effective.get("model", ""))
        if not selected_model.startswith(f"{expected_provider}/"):
            warnings.append(_warning(
                "nonlocal-default-model",
                f"Effective default model {selected_model or '(unset)'} does not use {expected_provider}.",
                "Select the generated local model or remove the later-precedence model override.",
            ))
        enabled = effective.get("enabled_providers")
        if isinstance(enabled, list) and expected_provider not in enabled:
            warnings.append(_warning(
                "local-provider-unavailable",
                f"Effective enabled_providers excludes the required {expected_provider} provider.",
                "Allow the local provider or remove the later-precedence enabled_providers restriction.",
            ))

    plugins = effective.get("plugin", [])
    if isinstance(plugins, list):
        extras = sorted({str(item) for item in plugins} - _allowed_plugins(ctx))
        if extras:
            warnings.append(_warning(
                "extra-plugin",
                f"Inherited OpenCode plugins are active: {', '.join(extras)}.",
                "Review or disable inherited plugins before using confidential workspace content.",
            ))

    mcp = effective.get("mcp", {})
    if isinstance(mcp, dict):
        enabled_mcp = sorted(
            name for name, value in mcp.items()
            if not isinstance(value, dict) or value.get("enabled", True) is not False
        )
        if enabled_mcp:
            warnings.append(_warning(
                "enabled-mcp",
                f"Effective OpenCode MCP integrations are enabled: {', '.join(enabled_mcp)}.",
                "Disable or review those integrations before treating the session as local-only.",
            ))

    permission = effective.get("permission", {})
    edit = permission.get("edit") if isinstance(permission, dict) else None
    if edit != "ask":
        warnings.append(_warning(
            "edit-without-approval",
            f"Effective workspace edit permission is {edit or 'unset'!r}, not 'ask'.",
            "Set `permission.edit` to `ask`, or work in Git/a disposable copy and review all changes.",
        ))

    return {
        "checked": True,
        "detected_config_sources": sources,
        "warnings": warnings,
    }


def print_opencode_warnings(report):
    for warning in report.get("warnings", []):
        label = "note" if warning.get("severity") == "info" else "warning"
        print(f"[lac {label}] {warning['code']}: {warning['message']}", file=sys.stderr)
        print(f"[lac {label}] next: {warning['remediation']}", file=sys.stderr)
