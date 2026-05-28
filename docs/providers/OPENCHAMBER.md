# OpenChamber — Web, Mobile & Desktop Access

OpenChamber is a web/PWA/desktop interface for OpenCode that gives you phone/tablet access to your local AI cluster — like Codex/Claude Code mobile. It provides a rich UI with diff viewing, multi-agent runs, voice mode, and branchable chat timelines.

The `lac` CLI integrates OpenChamber as a first-class client target. Launch it with:

```bash
lac client open openchamber
```

---

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/openchamber/openchamber/main/scripts/install.sh | bash
```

On macOS you can also use Homebrew:

```bash
brew install openchamber/tap/openchamber
```

---

## Launch (same machine)

### Terminal / web UI

```bash
lac profile apply 64gb
lac runtime start
lac client open openchamber
```

OpenChamber starts its own OpenCode process using the generated config from your local cluster. The web UI is available at `http://localhost:3000` by default.

### Desktop app (macOS)

```bash
lac client open openchamber --desktop
```

This launches the OpenChamber macOS native app with the same connection config.

---

## Remote access with Tailscale (recommended)

Tailscale provides plug-and-play VPN. Once installed, your machines are on the same private network — no port forwarding, no certificates, works over cellular.

1. Install [Tailscale](https://tailscale.com) on your dev machine and phone/tablet
2. Note your Tailscale IP:
   ```bash
   tailscale ip -4
   ```
3. Start OpenCode in serve mode on the dev machine:
   ```bash
   opencode serve --port 4095 \
     --state state/clients/opencode/opencode.json
   ```
4. Launch OpenChamber bound to the Tailscale network:
   ```bash
   lac client open openchamber --remote-host http://100.x.x.x:4095
   ```
5. On your phone/tablet, open `http://100.x.x.x:3000` in a browser
   - Install the PWA for an app-like experience (Add to Home Screen)

---

## Remote access with Cloudflare tunnel

OpenChamber has built-in Cloudflare tunnel support for environments without Tailscale.

### Quick tunnel (ephemeral)

```bash
openchamber tunnel start --provider cloudflare --mode quick --qr
```

Scan the QR code on your phone — the tunnel is valid until you stop it.

### Managed tunnel (persistent hostname)

```bash
openchamber tunnel start \
  --provider cloudflare \
  --mode managed-remote \
  --hostname app.example.com \
  --token <token>
```

---

## Port configuration

| Service | Default port | Env var override |
|---|---|---|
| OpenChamber web UI | 3000 | `OPENCHAMBER_PORT` |
| OpenCode serve | 4095 | `OPENCODE_PORT` |

If ports conflict, set the env vars before launching:

```bash
export OPENCHAMBER_PORT=4000
export OPENCODE_PORT=4096
lac client open openchamber
```

For remote access, pass the correct port in the URL:

```bash
lac client open openchamber --remote-host http://100.x.x.x:4096
```

---

## FAQ

**Q: Do I need Tailscale AND Cloudflare?**  
A: No. Tailscale is the simpler plug-and-play option. Cloudflare is useful when you can't install Tailscale on the target device.

**Q: Can I use both?**  
A: Yes. Tailscale for your own devices, Cloudflare tunnel for sharing access with others who aren't on your tailnet.

**Q: Does this work over cellular?**  
A: Yes. Tailscale routes through their DERP relays when a direct connection isn't available. Cloudflare tunnels always go through Cloudflare's edge.

**Q: Can I use this without the lac CLI?**  
A: Yes. Set `OPENCODE_CONFIG=state/clients/opencode/opencode.json` and run `openchamber` directly, or set `OPENCODE_HOST` + `OPENCODE_SKIP_START=true` for remote mode.
