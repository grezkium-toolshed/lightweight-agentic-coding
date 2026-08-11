# README visuals

- `lac-local-ai-hero.png` is an original AI-generated illustration created for this repository on
  2026-08-11. It is illustrative and is not a product screenshot.
- `openchamber-local-session.png` combines a cropped capture of an actual local OpenChamber session
  using lac's `qwen3.5-4b-q4` model with the sanitized v0.3 acceptance evidence recorded in
  `RELEASE_CHECKLIST.md`. The prompt and response are synthetic; no cloud provider or customer data
  was used.
- `qwen4b-realtime.gif` records a fresh isolated OpenChamber session using lac's
  `qwen3.5-4b-q4` model. It samples the actual elapsed run once per second, displays the recorded
  elapsed time, plays the showcase at 3× speed, and holds the completed response briefly for
  readability. The measured response took 25.2 seconds. The prompt is synthetic and no cloud
  provider or customer data was used.
- `openchamber-ds4-run.png` combines an actual DeepSeek V4 Flash response in OpenChamber with data
  from the same isolated ds4/Metal run: 256K context, 95.25 GiB planned memory, 18,764 prompt tokens,
  approximately 250 tok/s prefill, 23.8 tok/s decode, and 1m52s end-to-end. The model ran through
  the `128gb-ds4-flash` profile on a 128 GB M4 Max MacBook Pro with no cloud provider active.

The operational visuals omit account, username, project-sidebar, path, URL, and session identifiers.
