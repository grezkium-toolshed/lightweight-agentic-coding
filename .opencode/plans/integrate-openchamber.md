# Plan: Integrate OpenChamber

**Status:** Draft
**Upstream:** https://github.com/openchamber/openchamber
**Arch:** web/PWA/desktop GUI for OpenCode — provides phone/tablet access (like Codex or Claude Code mobile)

---

## What We're Building

Add `openchamber` as a fourth client target alongside `opencode`, `claude-code`, `codex-reference` in the `lac` CLI. OpenChamber handles the heavy UI/tunnel lifting — we just need to teach `lac` to launch it pointing at the local cluster, and document the Tailscale/Cloudflare remote access patterns.

---

## Files to Change

### Phase 1 — CLI integration

| File | Change |
|---|---|
| `src/lac/clients.py` | Add `render_client` and `client_open` handlers for `openchamber` |
| `src/lac/cli.py` | Register `openchamber` in parser choices, add `--remote-host` arg, add install hint, add to doctor checks |
| `src/lac/data/opencode/opencode.template.jsonc` | No change (OpenChamber doesn't add models) |

**`render_client(ctx, "openchamber")` — new case in `render_client()`:**
- Create `state/clients/openchamber/` directory
- Write `manifest.json` with pack summary (same pattern as `codex-reference`)
- Write `README.md` with connection guidance
- Write `openchamber.env` containing:
  ```
  OPENCODE_CONFIG=/path/to/state/clients/opencode/opencode.json
  ```
- Return render path + pack count

**`client_open(ctx, "openchamber", desktop, remote_host)` — extend `client_open()`:**
- Check `openchamber` in PATH (show install hint if missing)
- Check generated OpenCode config exists at `state/clients/opencode/opencode.json`
- Two launch modes:
  - **Same-machine (default):** set `OPENCODE_CONFIG`, launch `openchamber`
  - **Remote (Tailscale):** if `--remote-host` provided, set `OPENCODE_HOST=<url>` + `OPENCODE_SKIP_START=true`, launch `openchamber`
- `--desktop` on macOS: `open -a OpenChamber` with env

**`cli.py` — parser changes:**
- Add `"openchamber"` to `client_render_parser` choices
- Add `"openchamber"` to `client_open_parser` choices
- Add `--remote-host` optional arg to client open parser
- Add openchamber to `_install_hint()`:
  ```python
  "openchamber": {
      "summary": "Install OpenChamber — web/PWA/desktop UI for OpenCode.",
      "macos": [
          "curl -fsSL https://raw.githubusercontent.com/openchamber/openchamber/main/scripts/install.sh | bash",
          "brew install openchamber/tap/openchamber  # alt"
      ],
      "linux": ["curl -fsSL https://raw.githubusercontent.com/openchamber/openchamber/main/scripts/install.sh | bash"],
      "windows": ["curl -fsSL https://raw.githubusercontent.com/openchamber/openchamber/main/scripts/install.sh | bash"],
      "docs": "https://github.com/openchamber/openchamber",
  }
  ```
- Add `openchamber` to doctor command checks

### Phase 2 — Profile & catalog updates

| File | Change |
|---|---|
| `runtime-config/profiles.json` | Add `openchamber` to supported_clients |
| `src/lac/data/runtime-config/profiles.json` | Mirror |
| `src/lac/data/catalog/workflow-packs.json` | Add `openchamber` to pack supported_clients |
| `catalog/workflow-packs.json` | Mirror |
| `src/lac/data/catalog/scenarios.json` | No change (optional future addition) |

Add `"openchamber"` to `supported_clients` in these profiles:
- `64gb`
- `128gb-multi`
- `128gb-qwen122b`
- `128gb-minimax`
- `openrouter`

Skip: `16gb`, `macos-16gb`, `gemma-16gb`, `gemma-24gb`, `24gb` (low-RAM/constrained machines)

Add `"openchamber"` to pack `supported_clients`:
- `coding`
- `research`
- `office`
- `team-rollout`

### Phase 3 — Documentation

| File | Change |
|---|---|
| `docs/providers/OPENCHAMBER.md` (new) | Full setup guide |
| `docs/providers/README.md` | Add link |
| `docs/use-cases/ONBOARDING_32GB_PLUS.md` | Add optional OpenChamber step |
| `docs/architecture.md` | Add to client integrations |
| `docs/CONFLUENCE_QWEN35_MIGRATION_GUIDE.md` | Note new client |

**New doc: `docs/providers/OPENCHAMBER.md`**

```markdown
# OpenChamber — Web, Mobile & Desktop Access

OpenChamber is a web/PWA/desktop interface for OpenCode that gives you
phone/tablet access to your local AI cluster — like Codex/Claude Code mobile.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/openchamber/openchamber/main/scripts/install.sh | bash
```

On macOS you can also use Homebrew:
```bash
brew install openchamber/tap/openchamber
```

## Launch (same machine)

```bash
lac client open openchamber
```

Or with the desktop app:
```bash
lac client open openchamber --desktop
```

## Remote access with Tailscale (recommended)

Tailscale provides plug-and-play VPN. Once installed, your machines are
on the same private network — no port forwarding, no certificates.

1. Install Tailscale on your dev machine and phone/tablet
2. Note your Tailscale IP:
   ```bash
   tailscale ip -4
   ```
3. Start OpenCode in serve mode:
   ```bash
   opencode serve --port 4095 \
     --state state/clients/opencode/opencode.json
   ```
4. Launch OpenChamber bound to Tailscale:
   ```bash
   lac client open openchamber --remote-host http://100.x.x.x:4095
   ```
5. On your phone, open `http://100.x.x.x:3000` in a browser,
   or install the PWA for an app-like experience.

**Port configuration notes:**
- OpenChamber web UI defaults to port 3000 (`--port 3000` / `OPENCHAMBER_PORT`)
- OpenCode serve defaults to port 4095 (`--port 4095` / `OPENCODE_PORT`)
- If ports conflict, set env vars before launching:
  ```bash
  export OPENCHAMBER_PORT=4000
  export OPENCODE_PORT=4096
  ```

## Remote access with Cloudflare tunnel

OpenChamber has built-in Cloudflare tunnel support for environments
without Tailscale.

**Quick tunnel (ephemeral):**
```bash
openchamber tunnel start --provider cloudflare --mode quick --qr
```
Scan the QR code on your phone — valid until the tunnel stops.

**Managed tunnel (persistent hostname):**
```bash
openchamber tunnel start \
  --provider cloudflare \
  --mode managed-remote \
  --hostname app.example.com \
  --token <token>
```

**Port notes for tunnels:** Cloudflare tunnels route traffic to your
local ports. By default OpenChamber uses 3000 and OpenCode uses 4095.
These are configurable via the env vars above.

## FAQ

**Q: Do I need Tailscale AND Cloudflare?**
A: No. Tailscale is the simpler plug-and-play option. Cloudflare is
useful when you can't install Tailscale on the target device.

**Q: Can I use both at the same time?**
A: Yes. Tailscale for your own devices, Cloudflare tunnel for sharing
access with others who aren't on your tailnet.

**Q: Does this work over cellular?**
A: Yes. Tailscale routes through their DERP relays when a direct
connection isn't available. Cloudflare tunnels always go through
Cloudflare's edge.
```

---

## Launch Flows (end-user view)

```
# Same machine — minimal
lac profile apply 64gb
lac runtime start
lac client open openchamber

# Remote via Tailscale — dev machine
lac runtime start
opencode serve --port 4095 --state state/clients/opencode/opencode.json
lac client open openchamber --remote-host http://100.x.x.x:4095

# Phone connects to http://100.x.x.x:3000
```

---

## What NOT to change

- No provider/model changes — OpenChamber connects to OpenCode, not to the LLM
- No runtime changes — OpenChamber doesn't replace llama-server
- No low-RAM profiles — companion tool, not core dependency
- No changes to `opencode.template.jsonc` — OpenChamber doesn't add models or providers

## Effort

- Python: ~150 lines across `clients.py` + `cli.py`
- Markdown: ~200 lines across new + existing docs
- JSON: ~20 additions across profiles + packs
- Mirror to `src/lac/data/`: copy step
