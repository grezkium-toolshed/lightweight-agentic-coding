# Local AI Cluster Rules

- Keep llama.cpp as the default local runtime.
- Treat Qwen 3.6 MoE as the baseline local model family for general agentic work.
- Use Qwen 3.6 MTP (27B Q4, 35B-A3B Q6) as the fast coding and architect model instead of coder-next.
- Prefer a small curated set of agents and skills over large prompt catalogs.
- Distinguish clearly between local-first, free-cloud fallback, and hosted-model workflows.
- Keep docs executable from a fresh clone.
