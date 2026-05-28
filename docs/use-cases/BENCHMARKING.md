# Benchmarking

Benchmark per-model performance with `lac bench`.

## Quick start

```bash
# Benchmark all model slots in the active preset
lac bench

# Benchmark a specific model slot
lac bench --model qwen3.6-27b-q4

# Sweep MTP draft token counts
lac bench --model qwen3.6-27b-mtp-q4 --draft-n 6

# Custom prompt
lac bench --model qwen3.6-35b-a3b-q8 --prompt "Explain quantum computing in 3 sentences"

# JSON output for scripting
lac bench --json
```

## Metrics

| Metric | Description |
|---|---|
| `tokens_per_second` | Generation throughput after the first token |
| `ttft_seconds` | Time to first token (latency before generation starts) |
| `elapsed_seconds` | Total wall-clock time including TTFT |
| `prompt_tokens` | Input tokens processed |
| `completion_tokens` | Output tokens generated |

## Requirements

The runtime must be running (`lac runtime start`). Cloud profiles are not supported — bench requires a local llama-server or oMLX instance.
