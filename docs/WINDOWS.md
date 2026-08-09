# Windows — experimental routes

Apple Silicon MacBooks are lac's tested and supported platform. Windows remains experimental and
test-at-your-own-risk. Local checks and an optional manually triggered GitHub workflow exercise
Python, PowerShell, packaging, parsers, and generated configuration, but they do not validate a
physical GPU, model load, runtime performance, or OpenChamber integration.

Choose the route before installing anything:

| Route | Best for | Privacy boundary | Status |
|---|---|---|---|
| WSL2 local | Local models, especially on a compatible NVIDIA GPU | Local when no cloud provider is enabled | Preferred experimental Windows route |
| OpenChamber Desktop + OpenCode Go/Zen | Immediate agentic work without maintaining a local runtime | Prompts, files, and tool context may leave the device | Experimental cloud alternative |
| Native local | Experienced users with a verified Windows `llama-server.exe` | Local when no cloud provider is enabled | Manual preview |
| Native ARM64 OpenCL | Snapdragon/Adreno experiments | Local if the user-built runtime stays local | Detection only; no NPU promise |

## WSL2 local models

Use Windows 10 version 2004/build 19041 or newer, or Windows 11. Install and update WSL using
Microsoft's instructions, confirm the distribution reports version 2 with `wsl -l -v`, and keep
the repository in the Linux filesystem, such as `~/code/lightweight-agentic-coding`, rather than
under `/mnt/c`.

1. Install Python 3.10+, `pipx`, Git, and the build prerequisites inside the WSL distribution.
   On current Ubuntu releases, prefer the distribution `pipx` package over `pip install --user`.
2. Install or build a Linux `llama-server` for the backend actually exposed to WSL. Run
   `llama-server --list-devices` before asking lac to choose a profile.
3. Install OpenCode inside WSL. OpenCode's TUI or web mode is the clearest WSL client path.
4. Clone and initialize lac inside WSL:

   ```bash
   git clone https://github.com/grezkium-toolshed/lightweight-agentic-coding.git
   cd lightweight-agentic-coding
   pipx install .
   lac init --no-cloud
   lac models sync
   lac runtime start
   lac smoke
   lac client open opencode
   ```

If WSL cannot expose a measurable accelerator budget, lac selects `4gb` with low confidence. Use
an explicit profile only when you have separately verified the usable accelerator memory.

### GPU boundaries

- **NVIDIA:** the best-understood WSL route. Install a current Windows NVIDIA driver; do not install
  a Linux display driver inside WSL. Follow NVIDIA's WSL CUDA guidance and llama.cpp's CUDA build.
- **AMD:** use WSL acceleration only when the Windows version, WSL distribution, driver, and GPU all
  appear in AMD's current compatibility matrix.
- **Intel:** parser and configuration paths exist, but lac has no physical WSL runtime evidence.
- **Snapdragon/Adreno:** do not treat WSL as an NPU path. Use the native ARM64 OpenCL experiment below.

References: [Microsoft WSL installation](https://learn.microsoft.com/en-us/windows/wsl/install),
[OpenCode on WSL](https://opencode.ai/docs/windows-wsl/),
[NVIDIA CUDA on WSL](https://docs.nvidia.com/cuda/archive/13.0.3/wsl-user-guide/index.html),
[AMD ROCm WSL compatibility](https://rocm.docs.amd.com/projects/radeon-ryzen/en/docs-7.2/docs/compatibility/compatibilityrad/wsl/wsl_compatibility.html),
and [llama.cpp build instructions](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md).

## Native OpenChamber with Go or Zen

This is the lower-friction Windows route when immediate agentic behavior matters more than local
inference. It is **not local-only**: prompts, selected files, repository context, tool results, and
other material supplied to the model can be sent to hosted services. Accounts, subscriptions,
charges, hosting regions, retention, and model availability are controlled by OpenCode and its
providers, not by lac.

Do not send confidential, personal, customer, or employer data unless you have permission and have
reviewed the selected model's current terms. Some free Zen endpoints are temporary and may permit
logging or model improvement; lac does not promise that a free model will remain available.

1. Install the Windows desktop release from
   [OpenChamber](https://github.com/openchamber/openchamber/releases).
2. Use OpenCode's built-in `/connect` flow to choose OpenCode Go or OpenCode Zen.
3. Review the live model and privacy information before selecting a model.

The existing `opencode-go` profile remains available for lac-managed OpenCode configurations.
There is no duplicate `opencode-zen` profile; Zen authentication and its changing catalog stay in
OpenCode's native connection flow. Windows Desktop integration with lac-generated configuration is
not claimed as validated until a physical acceptance run is recorded.

References: [OpenCode providers](https://opencode.ai/docs/providers),
[OpenCode Go](https://opencode.ai/docs/go/), and
[OpenCode Zen privacy and pricing](https://opencode.ai/docs/zen/).

## Native local preview

Install these prerequisites yourself before running `scripts/bootstrap.ps1`:

- Python 3.10+;
- an official llama.cpp Windows build whose `llama-server.exe` is on `PATH`;
- OpenCode on `PATH`.

Use the llama.cpp release matching the intended backend and verify it first:

```powershell
llama-server --list-devices
.\scripts\bootstrap.ps1
```

The script does not install drivers, GPU runtimes, Node.js, OpenCode, or OpenChamber. It stops before
downloading a model when a prerequisite is missing.

For Snapdragon/Adreno, llama.cpp documents a Windows 11 ARM64 OpenCL source build. This is GPU
OpenCL, not Hexagon/NPU acceleration. lac detects the class conservatively and selects `4gb`; it
does not promise that a compatible runtime is installed. See the
[llama.cpp OpenCL guide](https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/OPENCL.md).

## Diagnostics and useful evidence

Run:

```powershell
lac doctor --json
lac runtime status --json
Get-Content -Path "$env:LOCALAPPDATA\lac\state\logs\llama-server.log" -Wait -Tail 50
```

For a useful hardware report, include Windows version and architecture, whether the run was native
or WSL2, GPU and driver, `llama-server --list-devices`, selected profile and confidence, and the
results of runtime health, model listing, `lac smoke`, and stop/restart checks. Experimental reports
do not create a support guarantee.
