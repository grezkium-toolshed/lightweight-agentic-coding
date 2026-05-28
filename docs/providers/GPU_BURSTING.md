# GPU Bursting

Run inference on a cloud GPU while keeping the local cluster tooling.
A persistent SSH tunnel makes a remote llama-server instance appear as a local runtime.

## Architecture

```
Local machine                    Cloud GPU (RunPod / Vast / Lambda)
┌─────────────────┐             ┌───────────────────────────────┐
│  lac client      │  autossh   │  llama-server                 │
│  OpenCode        │  tunnel    │  --host 0.0.0.0               │
│  OpenChamber     │◄──────────►│  --port 8080                  │
│  localhost:8080  │             │  --model /models/model.gguf  │
└─────────────────┘             └───────────────────────────────┘
```

All local clients (OpenCode, OpenChamber) connect to `127.0.0.1:8080` as usual.

## Prerequisites

- A cloud GPU provider account (RunPod, Vast, Lambda Labs, or any SSH-accessible VM)
- `autossh` installed locally:
  ```bash
  brew install autossh         # macOS
  sudo apt install autossh     # Linux
  ```
- SSH key pair set up with the remote instance

## Provider Setup

### RunPod

1. Create a pod with any CUDA template (e.g. `runpod/pytorch:2.1.0-cuda12.1.1`)
2. Reserve a public IP or use RunPod's TCP tunnels
3. SSH into the pod with the provided key

### Vast

1. Rent an instance with SSH enabled
2. Copy the SSH command from the Vast dashboard
3. Accept the host key on first connection

### Lambda Labs

1. Launch an instance from the Lambda Dashboard
2. Use the provided SSH key and IP address

## Remote Setup (one-time)

Run the cloud setup script to install llama-server on the remote instance:

```bash
./scripts/tunnel-to-cloud.sh --setup ubuntu@<ip-address>
```

Then start llama-server on the remote:

```bash
ssh ubuntu@<ip-address>
llama-server -m /path/to/model.gguf --host 0.0.0.0 --port 8080
```

> **Model transfer:** Upload your GGUF file to the remote instance via `scp` or download directly
> from Hugging Face using `hf download`. See [AUTHENTICATION.md](AUTHENTICATION.md) for
> Hugging Face CLI setup.

## Tunnel

Start the persistent tunnel:

```bash
./scripts/tunnel-to-cloud.sh ubuntu@<ip-address> 8080 8080
```

The tunnel forwards `localhost:8080` to the remote `:8080` with auto-reconnect via autossh.
Keep this terminal open or run it in a tmux/screen session.

## Verify

In another terminal:

```bash
curl http://127.0.0.1:8080/health    # should return {"status":"ok"}
curl http://127.0.0.1:8080/v1/models # should show model slots
./bin/lac smoke                       # full smoke test
./bin/lac bench                       # benchmark the cloud GPU
```

## Usage

Once the tunnel is active, the remote GPU appears as a local runtime. All commands work normally:

```bash
./bin/lac runtime status    # shows remote via tunnel
./bin/lac client open opencode
./bin/lac client open openchamber
```

## Cost Notes

| Provider | GPU | ~Price/hr | Notes |
|---|---|---|---|
| RunPod | A6000 (48GB) | $0.44 | Spot available, community templates |
| Vast | Various | $0.20-1.50 | Wide selection, variable pricing |
| Lambda Labs | A100 (80GB) | $1.10 | On-demand, no spot |
| AWS / GCP | Various | $1-5+ | Full cloud, complex setup |

- Spot instances are 50-70% cheaper but can be preempted
- Storage (persistent volume) costs ~$0.10/GB/month
- Egress is usually free or negligible for SSH tunnel traffic

## Teardown

```bash
# Kill the tunnel with Ctrl+C or:
kill %1  # or pkill autossh

# Tear down the cloud instance via the provider dashboard
```

## Auto-Start (optional)

To make the tunnel survive reboots, create a LaunchAgent (macOS) or systemd service (Linux):

**macOS** (`~/Library/LaunchAgents/com.lac.cloud-tunnel.plist`):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.lac.cloud-tunnel</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/autossh</string>
    <string>-M</string>
    <string>0</string>
    <string>-o</string>
    <string>ServerAliveInterval=30</string>
    <string>-o</string>
    <string>ServerAliveCountMax=3</string>
    <string>-o</string>
    <string>ExitOnForwardFailure=yes</string>
    <string>-o</string>
    <string>StrictHostKeyChecking=accept-new</string>
    <string>-L</string>
    <string>8080:127.0.0.1:8080</string>
    <string>ubuntu@&lt;ip-address&gt;</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
```

**Linux** (`/etc/systemd/system/lac-cloud-tunnel.service`):
```
[Unit]
Description=Local AI Cluster Cloud GPU Tunnel
After=network.target

[Service]
ExecStart=/usr/local/bin/autossh -M 0 -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes \
  -o StrictHostKeyChecking=accept-new \
  -L 8080:127.0.0.1:8080 ubuntu@<ip-address>
Restart=always
User=ubuntu

[Install]
WantedBy=multi-user.target
```
