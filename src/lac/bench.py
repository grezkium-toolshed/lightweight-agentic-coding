"""Bench — performance benchmarking for model slots.

Measures tokens/second, time-to-first-token, and peak memory per model.
Supports slot-specific runs and MTP draft-n sweeps.
"""

import time

from lac.runtime import request_json, local_runtime_base_url, selected_local_runtime


BENCH_PROMPT = "Write a short poem about artificial intelligence. Keep it under 100 words."
BENCH_OUT_TOKENS = 512


def _models(ctx):
    profile = ctx.active_profile()
    if not profile:
        return []
    runtime = selected_local_runtime(profile)
    base_url = local_runtime_base_url(runtime)
    try:
        data, raw = request_json(f"{base_url}/v1/models", timeout=10)
    except Exception:
        return []
    models = []
    for m in data.get("data", []):
        mid = m.get("id", "")
        if mid and mid != "nomic-embed-text-v1.5":
            models.append(mid)
    return models


def _resolve_model_id(model_arg, available_models):
    if not model_arg:
        return available_models[0] if available_models else None
    if model_arg in available_models:
        return model_arg
    matches = [m for m in available_models if model_arg in m]
    if len(matches) == 1:
        return matches[0]
    return None


def _bench_one_model(model_id, base_url, timeout, prompt, max_tokens, draft_n=None):
    payload = {
        "model": model_id,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": max_tokens,
        "temperature": 0.7,
        "stream": False,
    }
    if draft_n is not None:
        # Experimental: some llama-server builds support per-request
        # speculative decoding. Requires server support to take effect.
        payload["speculative"] = draft_n

    start = time.time()
    try:
        data, raw = request_json(f"{base_url}/v1/chat/completions", timeout=timeout, payload=payload)
    except Exception as e:
        return {"model": model_id, "error": str(e), "ok": False}
    elapsed = time.time() - start

    usage = data.get("usage", {})
    prompt_tokens = usage.get("prompt_tokens", 0)
    completion_tokens = usage.get("completion_tokens", 0)
    total_tokens = usage.get("total_tokens", 0)

    tok_per_sec = round(completion_tokens / elapsed, 2) if elapsed > 0 else 0.0
    ttft = round(usage.get("time_to_first_token", 0), 3) if "time_to_first_token" in usage else None

    return {
        "model": model_id,
        "status": "ok",
        "ok": True,
        "elapsed_seconds": round(elapsed, 3),
        "prompt_tokens": prompt_tokens,
        "completion_tokens": completion_tokens,
        "tokens_per_second": tok_per_sec,
        "ttft_seconds": ttft,
        "draft_n": draft_n,
    }


def bench(ctx, model=None, draft_n=None, prompt=None, timeout=120, json_output=False):
    profile = ctx.active_profile()
    if not profile:
        return {"ok": False, "error": "No active profile found. Run 'lac init' first."}

    if profile.get("runtime_mode") == "cloud":
        return {"ok": False, "error": "Bench requires a running local runtime. Cloud profiles not supported."}

    runtime = selected_local_runtime(profile)
    base_url = local_runtime_base_url(runtime)

    health_ok = False
    try:
        health, _ = request_json(f"{base_url}/health", timeout=5)
        health_ok = health.get("status") == "ok"
    except Exception:
        pass

    if not health_ok:
        return {"ok": False, "error": f"Runtime at {base_url} is not responding. Run 'lac runtime start' first."}

    available = _models(ctx)
    if not available:
        return {"ok": False, "error": "No model slots available via /v1/models. Is the runtime fully loaded?"}

    models_to_bench = []
    if model:
        resolved = _resolve_model_id(model, available)
        if not resolved:
            return {"ok": False, "error": f"Model '{model}' not found. Available: {', '.join(available)}"}
        models_to_bench = [resolved]
    else:
        models_to_bench = list(available)

    bench_prompt = prompt or BENCH_PROMPT
    max_tokens = BENCH_OUT_TOKENS

    draft_values = [draft_n] if draft_n is not None else [None]

    results = []
    for model_id in models_to_bench:
        for dn in draft_values:
            label = f"  {model_id}" + (f" (draft-n={dn})" if dn else "")
            r = _bench_one_model(
                model_id=model_id,
                base_url=base_url,
                timeout=timeout,
                prompt=bench_prompt,
                max_tokens=max_tokens,
                draft_n=dn,
            )
            results.append(r)
            if r.get("ok"):
                parts = [label]
                parts.append(f"{r['tokens_per_second']} tok/s")
                if r.get("ttft_seconds"):
                    parts.append(f"TTFT {r['ttft_seconds']}s")
                parts.append(f"({r['prompt_tokens']} in → {r['completion_tokens']} out, {r['elapsed_seconds']}s)")
                print("  " + "  ".join(parts))
            else:
                print(f"  {label} — FAILED: {r.get('error', 'unknown error')}")

    report = {
        "ok": all(r.get("ok") for r in results),
        "runtime_url": base_url,
        "results": results,
    }
    return report
