# Optimization Guide

## Default Runtime

Use llama.cpp (`llama-server`) with profile presets.

## Practical Tuning

- Reduce `ctx-size` first when memory pressure appears.
- Lower `batch-size` and `ubatch-size` before reducing model tier.
- Use lower profile IDs for weaker hardware.
- For 128GB profiles, keep default limits to preserve <=115GB effective usage.

## Verification

Run:

```bash
./scripts/doctor.sh
```

PowerShell:

```powershell
./scripts/doctor.ps1
```
