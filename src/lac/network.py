"""Local network allocation and persistence for lac services.

The network contract is deliberately small: local services bind to loopback by
default, ports can be overridden explicitly, and automatic fallback is only
used for lac-owned default allocations.  The persisted record lives in the
user-state root so an installed copy never writes configuration into its wheel.
"""

import json
import os
import shutil
import socket
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse


CONTRACT_TYPE = "lac.network.v1"
CONTRACT_VERSION = 1
LOOPBACK_HOSTS = {"127.0.0.1", "::1", "localhost"}
DEFAULTS = {
    "runtime": {"bind_host": "127.0.0.1", "connect_host": "127.0.0.1", "port": 8080},
    "omlx": {"bind_host": "127.0.0.1", "connect_host": "127.0.0.1", "port": 8000},
    "ds4": {"bind_host": "127.0.0.1", "connect_host": "127.0.0.1", "port": 8000},
    "openchamber": {"bind_host": "127.0.0.1", "connect_host": "127.0.0.1", "port": 3000},
    "opencode": {"bind_host": "127.0.0.1", "connect_host": "127.0.0.1", "port": 4095},
}


def _network_path(ctx):
    return ctx.state_root / "network.v1.json"


def _read_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SystemExit(f"Invalid lac network configuration at {path}: {exc}") from exc


def _validate_record(record, source):
    if not isinstance(record, dict):
        raise SystemExit(f"Invalid lac network configuration in {source}: expected an object.")
    if record.get("contractType") != CONTRACT_TYPE or record.get("version") != CONTRACT_VERSION:
        raise SystemExit(
            f"Invalid lac network configuration in {source}: expected "
            f"{CONTRACT_TYPE} version {CONTRACT_VERSION}."
        )
    services = record.get("services", {})
    if not isinstance(services, dict):
        raise SystemExit(f"Invalid lac network configuration in {source}: services must be an object.")
    return services


def _file_services(path):
    if not path or not path.is_file():
        return {}
    return _validate_record(_read_json(path), str(path))


def _port(value, source):
    try:
        port = int(value)
    except (TypeError, ValueError) as exc:
        raise SystemExit(f"Invalid port from {source}: {value!r}.") from exc
    if not 1 <= port <= 65535:
        raise SystemExit(f"Invalid port from {source}: {port}; use 1 through 65535.")
    return port


def _host(value, source, allow_remote=False):
    host = str(value).strip()
    if not host:
        raise SystemExit(f"Invalid empty host from {source}.")
    if host not in LOOPBACK_HOSTS:
        raise SystemExit(
            f"Refusing non-loopback bind host {host!r} from {source}. "
            "Remote runtime binding is not supported in this release because lac does not provide "
            "an authenticated remote listener. Use an authenticated tunnel to the loopback runtime instead."
        )
    return host


def _service_env(service):
    if service == "runtime":
        return ("LAC_PORT", "LAC_BIND_HOST", "LAC_CONNECT_HOST")
    if service == "omlx":
        return ("AI_OMLX_PORT", "LAC_BIND_HOST", "LAC_CONNECT_HOST")
    if service == "ds4":
        return ("DS4_PORT", "LAC_BIND_HOST", "LAC_CONNECT_HOST")
    if service == "openchamber":
        return ("OPENCHAMBER_PORT", None, None)
    return ("OPENCODE_PORT", None, None)


def _configured_services(ctx):
    configured = os.environ.get("LAC_NETWORK_CONFIG")
    if not configured:
        return {}
    return _file_services(Path(configured).expanduser())


def _service_values(services, service):
    value = services.get(service, {})
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise SystemExit(f"Invalid {service} entry in lac network configuration: expected an object.")
    return value


def resolve_service(ctx, service, *, cli_port=None, cli_bind_host=None, allow_remote=False):
    """Return the effective service endpoints without reserving a port.

    Precedence is CLI, environment, optional `LAC_NETWORK_CONFIG`, persisted
    state, then the shipped default.  Persisted values are marked automatic so
    they may be reallocated inside the documented fallback window.
    """
    if service not in DEFAULTS:
        raise SystemExit(f"Unknown lac network service: {service}")
    default = dict(DEFAULTS[service])
    configured = _service_values(_configured_services(ctx), service)
    persisted = _service_values(_file_services(_network_path(ctx)), service)
    port_env, bind_env, connect_env = _service_env(service)

    if cli_port is not None:
        port, port_source = _port(cli_port, "--port"), "cli"
    elif os.environ.get(port_env):
        port, port_source = _port(os.environ[port_env], port_env), "env"
    elif service == "runtime" and os.environ.get("AI_CLUSTER_PORT"):
        port, port_source = _port(os.environ["AI_CLUSTER_PORT"], "AI_CLUSTER_PORT (deprecated; use LAC_PORT)"), "env"
    elif "port" in configured:
        port, port_source = _port(configured["port"], "LAC_NETWORK_CONFIG"), "config"
    elif persisted.get("automatic") is True and "port" in persisted:
        port = _port(persisted["port"], "network.v1.json")
        port_source = "persisted"
    else:
        port, port_source = default["port"], "default"

    bind_value = cli_bind_host
    bind_source = "--bind-host" if cli_bind_host is not None else None
    if bind_value is None and bind_env and os.environ.get(bind_env):
        bind_value, bind_source = os.environ[bind_env], bind_env
    if bind_value is None and service in {"runtime", "omlx", "ds4"} and os.environ.get("LAC_HOST"):
        bind_value, bind_source = os.environ["LAC_HOST"], "LAC_HOST (deprecated; use LAC_BIND_HOST)"
    if bind_value is None and service in {"runtime", "omlx", "ds4"} and os.environ.get("AI_CLUSTER_HOST"):
        bind_value, bind_source = os.environ["AI_CLUSTER_HOST"], "AI_CLUSTER_HOST (deprecated; use LAC_BIND_HOST)"
    if bind_value is None and "bind_host" in configured:
        bind_value, bind_source = configured["bind_host"], "LAC_NETWORK_CONFIG"
    if bind_value is None and persisted.get("automatic") is True and "bind_host" in persisted:
        bind_value, bind_source = persisted["bind_host"], "network.v1.json"
    if bind_value is None:
        bind_value, bind_source = default["bind_host"], "default"
    bind_host = _host(bind_value, bind_source, allow_remote=allow_remote)

    connect_value = None
    connect_source = None
    if connect_env and os.environ.get(connect_env):
        connect_value, connect_source = os.environ[connect_env], connect_env
    elif "connect_host" in configured:
        connect_value, connect_source = configured["connect_host"], "LAC_NETWORK_CONFIG"
    elif persisted.get("automatic") is True and "connect_host" in persisted:
        connect_value, connect_source = persisted["connect_host"], "network.v1.json"
    else:
        connect_value, connect_source = default["connect_host"], "default"
    connect_host = _host(connect_value, connect_source)
    return {
        "service": service,
        "port": port,
        "port_source": port_source,
        "bind_host": bind_host,
        "bind_source": bind_source,
        "connect_host": connect_host,
        "connect_source": connect_source,
        "automatic": port_source in {"default", "persisted"},
        "allocation_source": "automatic-default" if port_source == "default" else port_source,
    }


def url(host, port, path=""):
    address = f"[{host}]" if ":" in host and not host.startswith("[") else host
    return f"http://{address}:{port}{path}"


def _port_available(host, port):
    family = socket.AF_INET6 if ":" in host else socket.AF_INET
    address = "::1" if host == "localhost" and family == socket.AF_INET6 else host
    try:
        with socket.socket(family, socket.SOCK_STREAM) as probe:
            probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            probe.bind((address, port))
    except OSError:
        return False
    return True


def _write_persisted(ctx, service, effective):
    path = _network_path(ctx)
    services = _file_services(path)
    services[service] = {
        "port": effective["port"],
        "bind_host": effective["bind_host"],
        "connect_host": effective["connect_host"],
        "automatic": effective["automatic"],
        "allocation_source": effective["allocation_source"],
        "updated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    }
    record = {"contractType": CONTRACT_TYPE, "version": CONTRACT_VERSION, "services": services}
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def _listener_owner(host, port):
    """Return a best-effort local listener diagnostic without requiring lsof."""
    lsof = shutil.which("lsof")
    if not lsof:
        return ""
    try:
        result = subprocess.run(
            [lsof, "-nP", f"-iTCP@{host}:{port}", "-sTCP:LISTEN", "-t"],
            capture_output=True, text=True, check=False, timeout=2,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    pid = next((line.strip() for line in result.stdout.splitlines() if line.strip().isdigit()), "")
    return f" Listener PID {pid}." if pid else ""


def _explicit_override_command(service):
    if service in {"runtime", "omlx", "ds4"}:
        return "lac runtime start --port <free-port>"
    if service == "openchamber":
        return "lac client open openchamber --port <free-port>"
    return "OPENCODE_PORT=<free-port> lac client open openchamber"


def allocate_service(ctx, service, *, cli_port=None, cli_bind_host=None, allow_remote=False):
    """Reserve a usable lac service port or fail with an actionable collision."""
    effective = resolve_service(
        ctx, service, cli_port=cli_port, cli_bind_host=cli_bind_host, allow_remote=allow_remote
    )
    if _port_available(effective["bind_host"], effective["port"]):
        return effective
    if not effective["automatic"]:
        raise SystemExit(
            f"{service} cannot bind {effective['bind_host']}:{effective['port']} "
            f"({effective['port_source']} selection is occupied)."
            f"{_listener_owner(effective['bind_host'], effective['port'])} "
            f"Choose another explicit port: {_explicit_override_command(service)}."
        )
    requested = effective["port"]
    last_port = min(65535, requested + 20)
    for candidate in range(requested + 1, last_port + 1):
        if _port_available(effective["bind_host"], candidate):
            effective["port"] = candidate
            effective["port_source"] = "automatic-fallback"
            effective["allocation_source"] = "automatic-fallback"
            return effective
    raise SystemExit(
        f"{service} cannot bind {effective['bind_host']}:{requested}-{last_port}; "
        f"all automatic ports are occupied. Choose an explicit port: {_explicit_override_command(service)}."
    )


def persist_started_service(ctx, effective):
    """Persist the successful allocation after, never before, service startup.

    Explicit CLI/environment/config allocations are recorded for diagnostics but
    intentionally never affect a later no-override choice.
    """
    _write_persisted(ctx, effective["service"], effective)


def reset_ports(ctx):
    path = _network_path(ctx)
    existed = path.is_file()
    path.unlink(missing_ok=True)
    return {"ok": True, "reset": existed, "path": str(path)}


def port_report(ctx):
    services = {}
    for service in DEFAULTS:
        effective = resolve_service(ctx, service)
        effective["url"] = url(effective["connect_host"], effective["port"])
        effective["available"] = _port_available(effective["bind_host"], effective["port"])
        services[service] = effective
    return {
        "contractType": CONTRACT_TYPE,
        "version": CONTRACT_VERSION,
        "path": str(_network_path(ctx)),
        "services": services,
        "last_successful_allocations": _file_services(_network_path(ctx)),
    }


def validate_remote_host(value):
    parsed = urlparse(value)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname or parsed.username or parsed.password:
        raise SystemExit("--remote-host must be an http(s) URL with a host and no embedded credentials.")
    return value.rstrip("/")
