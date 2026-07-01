# Codex via ChatGPT Subscription

This provider exposes your ChatGPT subscription (Plus / Pro / Team) as an OpenAI-compatible endpoint that OpenCode can use. It relies on a third-party OAuth helper; the OpenAI API itself does not support subscription reuse.

**Last verified:** 2026-04-18 — cross-check the helper repo before each beta cut.

## Upstream helper

https://github.com/numman-ali/opencode-openai-codex-auth

The helper runs a local auth flow that produces a short-lived OAuth token against ChatGPT's session, then exposes an OpenAI-compatible local endpoint (or injects credentials into your shell). Read the upstream README for current setup — it changes as OpenAI's auth surface evolves.

## Environment variable

| Provider | Env var |
|----------|---------|
| Codex auth | `OPENAI_API_KEY` |

This provider reuses the standard OpenAI env var because the helper presents itself as an OpenAI-compatible server. If you also use a raw OpenAI API key elsewhere, pick one or the other per shell — do not mix.

## When this is a good fit

- You already pay for a ChatGPT subscription and do not want a second bill for API usage.
- You mostly use GPT-5 / GPT-5 Codex and do not need the broader OpenRouter catalog.
- You are comfortable running and trusting a third-party OAuth helper against your ChatGPT session.

## Caveats

- **Third-party trust:** you are running an unofficial OAuth helper. Read its code and recent commits before use.
- **Session fragility:** ChatGPT's auth surface is not a stable API. Expect the helper to break occasionally.
- **Rate limits follow the subscription,** not API tiers. Heavy agentic use can hit subscription-level throttling.
- **Unsupported by OpenAI.** Do not expect help from OpenAI support if this path breaks.

## Refresh guidance

Before each beta cut:
1. Check the helper repo for open issues about broken auth.
2. Confirm the helper's install steps still match ours.
3. Bump `last_verified_at` in `catalog/providers.json` for `codex-auth`.

## See Also

- [Provider authentication overview](AUTHENTICATION.md)
- [Claude Code onboarding](../use-cases/ONBOARDING_CLAUDE_CODE.md)
