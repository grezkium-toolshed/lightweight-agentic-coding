# Third-Party Notices

This notice tracks third-party material that lac bundles, adapts, invokes, downloads, or
points users to. It is informational and does not replace upstream license files, model
cards, acceptable-use policies, or vendor terms. When adding or updating externally sourced
material, update the relevant `catalog/assets.json` entry and this file together.

## Bundled assets

Shipped inside the package (or, where noted, fetched on first use). First-party agents and
skills authored for this repository are covered by the repository's own MIT `LICENSE`.

| Catalog source_ref | Upstream | lac usage | Terms note |
| --- | --- | --- | --- |
| `lightweight-agentic-coding` | This repository | First-party OpenCode agents and workflow skills (`documentation-generator`, `docx-/pptx-/xlsx-/pdf-workflow`, `research-synthesizer`, and the review agents). | Covered by this repository's MIT `LICENSE`. |
| `gsd-build/get-shit-done@bdcaab2c752d9a33a1a1ca9acf3a3c81fb991815` | [gsd-build/get-shit-done](https://github.com/gsd-build/get-shit-done) | Adapted `skill:gsd` workflow skill. | Upstream license is MIT. This is a lac-authored, trimmed adaptation; the source revision is recorded in the skill and catalog. |
| `merill/msgraph@v1.0.19` | [merill/msgraph](https://github.com/merill/msgraph) | Optional Microsoft Graph skill; **fetched on demand** via `lac skill install msgraph`, not bundled in the wheel. | Upstream license is MIT. The installer pins release `v1.0.19` and enforces SHA-256 `363926d4d3f49a7f19cb6f50589e6646267e89a4f72764b5fc043db36a5a6764`. Authenticated API use must also follow Microsoft Graph, tenant, and credential-handling terms. |

## Optional, opt-in content (not redistributed)

lac does **not** bundle the Open Design skill/design-system catalog. Users add it themselves
via the upstream installer (`curl -fsSL https://open-design.ai/install.sh | sh -s opencode`, or
`od mcp install opencode`). It is credited here because lac documents and recommends it.

| Upstream | lac usage | Terms note |
| --- | --- | --- |
| [nexu-io/open-design](https://github.com/nexu-io/open-design) | Documented opt-in source of design skills, craft rulebooks, and brand design-system references. | Upstream repository is Apache-2.0, but the catalog itself re-bundles material from other projects (see below). Review each asset's own terms before use; these are community, not-reviewed by lac. |
| [Refero Design / refero_skill](https://github.com/referodesign/refero_skill) | Source that Open Design's craft rulebooks are adapted from. | Upstream license is MIT (© Refero Design). Reaches users only through the opt-in Open Design install. |
| Anthropic Agent Skills; [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) | Some Open Design catalog entries originate from these projects. | Carry their own (in places proprietary or separately licensed) terms. lac does not redistribute them; review upstream terms if you install the Open Design catalog. |

## Referenced runtimes, clients, and model sources

Not vendored as binaries. lac invokes or documents these so users can install, build, or
download them in their own environment.

| Source | lac usage | Terms note |
| --- | --- | --- |
| [llama.cpp](https://github.com/ggml-org/llama.cpp) | Default local runtime via `llama-server`. | Users install or provide the runtime/model files; follow upstream license and model terms. |
| [OpenCode](https://opencode.ai) | Agentic coding client and project config target. | Users install or run OpenCode separately; follow upstream terms. |
| [OpenChamber](https://github.com/openchamber/openchamber) | Optional web/PWA/desktop client that `lac client open openchamber` launches. | Users install OpenChamber separately; follow upstream terms. |
| [oMLX](https://github.com/danielzgtg/omlx) | Optional macOS MLX runtime path. | Optional runtime; follow upstream license and model terms. |
| [antirez/ds4](https://github.com/antirez/ds4) | Optional DwarfStar runtime selected by the `128gb-ds4-flash` profile. | Upstream license is MIT. Users build/install `ds4-server`; lac only invokes it when configured. |
| [Unsloth](https://unsloth.ai) | Model quantizations used by the recommended Qwen/Gemma profiles. | Model downloads are user-managed and may carry separate model terms. |
| [Qwen](https://github.com/QwenLM/Qwen) / [Gemma](https://ai.google.dev/gemma) | Model families downloaded by `lac models sync` for local profiles. | User-downloaded; subject to each family's model license and acceptable-use policy. |
| [antirez/deepseek-v4-gguf](https://huggingface.co/antirez/deepseek-v4-gguf) | `lac models sync 128gb-ds4-flash` download mapping for the conservative imatrix GGUF. | The Hugging Face repository reports MIT for the quantized files; also review base-model terms before production use. |
| [vava-nessa/free-coding-models](https://github.com/vava-nessa/free-coding-models) | `docs/free-coding-models.json` is a snapshot of this upstream free-model index (`lac catalog sync-free`). | Snapshot of upstream data; see the upstream repository for its license and refresh cadence. |
| [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) | Optional OpenCode plugin (`@dietrichgebert/ponytail`) added to generated OpenCode configs: laziness ruleset injected into every turn, `/ponytail lite\|full\|ultra\|off` commands, and review/audit/debt skills. | Upstream license is MIT. Fetched from npm by OpenCode on first use (requires network); not vendored in the wheel. Disable per-session with `PONYTAIL_DEFAULT_MODE=off`. |
| [Opencode-DCP/opencode-dynamic-context-pruning](https://github.com/Opencode-DCP/opencode-dynamic-context-pruning) | `@tarquinen/opencode-dcp@3.1.14` is referenced by generated OpenCode configs for dynamic context pruning. | npm metadata reports AGPL-3.0-or-later. Fetched by OpenCode on first use (requires network); not vendored in the wheel. |

## Maintenance rule

When adding externally sourced skills, agents, runtimes, or model download mappings:

1. Update the relevant `catalog/assets.json` entry when the content is a bundled lac asset.
2. Add the upstream source and its actual license/terms here — do not assume a blanket license across a mixed catalog.
3. If the content re-bundles other projects, credit them too and keep claims conservative.
