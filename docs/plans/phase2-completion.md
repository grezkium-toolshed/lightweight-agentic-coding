# Phase 2 Completion Plan: Extract init.py and render.py

## Current State

`cli.py`: 1197 lines. Already extracted: context, profiles, config, runtime, providers, packs, scenarios, clients, models, catalog.

## What Remains to Extract

### `src/lac/init.py` (~275 lines)

**Source range:** lines 397-711 in `cli.py`

**Extracted content:**
- `CLOUD_PROVIDER_HINTS` constant
- `_prompt_yes_no`, `_prompt_choice`, `_prompt_multiselect`
- `_parse_cloud_arg`, `_validate_cloud_ids`
- `_provider_id_from_model`, `_profile_provider_ids`
- `_init_recommendation`, `_status_item`, `_init_required_provider_ids`
- `_init_prerequisites`, `_init_readiness`, `_init_status`, `_next_steps`
- `init_wizard`
- `_render_init_section`, `render_init_text`

**Dependencies:** `load_json`, `command_exists`, `_host_install_platform`, `_install_hint` from cli.py; `profile_apply`, `family_alternatives`, `recommend_profile`, `FAMILY_DESCRIPTIONS` from profiles; `selected_local_runtime` from runtime

### `src/lac/render.py` (~160 lines)

**Source range:** lines 713-874 in `cli.py`

**Extracted content:**
- `render_pack_list`, `render_pack_show`
- `render_skill_status`, `render_skill_verify`
- `render_scenario_list`, `render_scenario_show`
- `render_provider_list`, `_catalog_model_short_id`, `render_provider_models`
- `render_provider_status`, `_render_verify_row`, `render_provider_verify_single`, `render_provider_verify_all`
- `render_doctor_text`, `render_smoke_text`

**Dependencies:** None (pure text output functions)

## What Stays in `cli.py` (~600 lines)

- Utilities: `load_json`, `write_json`, `command_exists`, `log_info`, `utc_now`, `_host_install_platform`, `_install_hint`, `_strip_global_json_flag`
- Orchestration: `doctor`, `smoke`, `device_setup`, `verify_free_models`, `run_models_sync`
- Dispatch: `emit`, `build_parser`, `main`

## Result

| File | Before | After |
|------|--------|-------|
| `cli.py` | 1197 | ~600 |
| `init.py` | — | ~275 |
| `render.py` | — | ~160 |

## Verification

- [ ] `lac --version` works
- [ ] `lac init --yes --profile 24gb --no-cloud` works (uses init.py)
- [ ] `lac doctor` works (uses render.py via emit)
- [ ] `lac pack list` works (uses render.py)
- [ ] `lac provider verify openrouter --json` works
- [ ] All CI checks pass
