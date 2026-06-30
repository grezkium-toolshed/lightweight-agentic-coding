# Third-Party Notices

This public-beta notice tracks third-party material that lac bundles, adapts,
invokes, or downloads. It is informational and does not replace upstream
license files, model cards, acceptable-use policies, or vendor terms. Before a
public release adds or updates externally sourced material, maintainers must
verify the upstream source and refresh this file, `catalog/assets.json`, and
`docs/security/TRUST_MODEL.md`.

## Bundled or adapted assets

These assets are tracked in `catalog/assets.json` and mirrored into package
data when they are part of the offline OpenCode bundle.

| Catalog source_ref | Upstream | lac usage | Terms note |
| --- | --- | --- | --- |
| `open-design` | [nexu-io/open-design](https://github.com/nexu-io/open-design) | Optional/community design skills, craft rulebooks, and design-system references under `.opencode/` and `src/lac/data/opencode/`. | Upstream repository license is Apache-2.0. These assets remain optional/community/not-reviewed unless the catalog records a narrower review. |
| `gsd-build/get-shit-done` | [gsd-build/get-shit-done](https://github.com/gsd-build/get-shit-done) | Adapted `skill:gsd` workflow skill. | Upstream repository license is MIT. lac carries this as a trimmed-and-reviewed adapted skill. |
| `merill/msgraph` | [merill/msgraph](https://github.com/merill/msgraph) | Optional Microsoft Graph skill for endpoint searches and authenticated tenant API workflows. | Upstream repository license is MIT. Authenticated API use must also follow Microsoft Graph, tenant, and credential-handling requirements. |

## Referenced runtimes and model sources

These projects are not vendored into the repository as model/runtime binaries.
lac invokes or documents them so users can install, build, or download them in
their own environment.

| Source | lac usage | Terms note |
| --- | --- | --- |
| [llama.cpp](https://github.com/ggml-org/llama.cpp) | Default local runtime via `llama-server`. | Users install or provide the runtime/model files; follow upstream license and model terms. |
| [OpenCode](https://opencode.ai) | Agentic coding client and project config target. | Users install or run OpenCode separately; follow upstream terms. |
| [oMLX](https://github.com/danielzgtg/omlx) | Optional macOS MLX runtime path. | Optional runtime; follow upstream license and model terms. |
| [Unsloth](https://unsloth.ai) | Model quantization and tuning source used by recommended profiles. | Model downloads are user-managed and may carry separate model terms. |
| [antirez/ds4](https://github.com/antirez/ds4) | Optional DwarfStar runtime selected by the `128gb-ds4-flash` profile. | Upstream repository license is MIT. Users build/install `ds4-server`; lac only invokes it when configured. |
| [antirez/deepseek-v4-gguf](https://huggingface.co/antirez/deepseek-v4-gguf) | `lac models sync 128gb-ds4-flash` download mapping for the conservative `q2-imatrix` GGUF. | The Hugging Face repository reports MIT for the quantized files, but users must also review any base-model terms before production use. |

## Maintenance rule

When adding externally sourced skills, agents, craft rules, design systems,
runtimes, or model download mappings:

1. Add or update the relevant `catalog/assets.json` entry when the content is
   bundled or exposed as a lac asset.
2. Record trust/support status in `docs/security/TRUST_MODEL.md` and
   `docs/security/THIRD_PARTY_AGENT_INTAKE.md`.
3. Add the upstream source and license/terms note here.
4. Keep claims conservative unless direct upstream evidence is linked or
   committed with the release evidence.
