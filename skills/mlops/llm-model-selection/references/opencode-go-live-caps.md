# OpenCode Go — live caps, pricing, model map (extraction recipe)

Source: `https://opencode.ai/docs/go/#usage-limits` — the old `/zen/go` page 404s now
(moved 2026-08). The page is an Astro SSR site; the usage-limits section is plain HTML
tables, no JS needed.

## Fetch

```bash
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126 Safari/537.36"
curl -sS -L -A "$UA" -o /tmp/go_docs.html --max-time 25 "https://opencode.ai/docs/go/"
```

## Parse

The tables are `<table><thead><tr><th>Model</th><th>requests per 5 hour</th>…` and
`<tbody><tr><td>Model</td><td>req/5h</td><td>req/week</td><td>req/month</td></tr>…`.
Strip tags (`sed 's/<[^>]*>/ /g'`) to get whitespace-separated cells. A second table
carries pricing (`Model Input Output Cached Read Cached Write Usage`), a third the
model-ID→endpoint→SDK map.

## Live req/5h caps — snapshot 2026-08-14

| Model | req/5h | req/week | req/month |
|---|---|---|---|
| Grok 4.5 | 120 | 300 | 600 |
| GPT-5.6 Luna | 2,050 | 5,100 | 10,250 |
| GLM-5.3 | 220 | 540 | 1,080 |
| GLM-5.2 | 880 | 2,150 | 4,300 |
| GLM-5.1 | 880 | 2,150 | 4,300 |
| Kimi K3 | 110 | 250 | 490 |
| Kimi K2.7 Code | 1,350 | 3,380 | 6,750 |
| Kimi K2.6 | 1,150 | 2,880 | 5,750 |
| MiMo-V2.5 | 30,100 | 75,200 | 150,400 |
| MiMo-V2.5-Pro | 3,250 | 8,150 | 16,300 |
| MiniMax M3 | 3,200 | 8,000 | 16,000 |
| MiniMax M2.7 | 3,400 | 8,500 | 17,000 |
| Qwen3.8 Max | 160 | 400 | 810 |
| Qwen3.7 Max | 340 | 840 | 1,690 |
| Qwen3.7 Plus | 4,300 | 10,800 | 21,600 |
| Qwen3.6 Plus | 3,300 | 8,200 | 16,300 |
| DeepSeek V4 Pro | 3,450 | 8,550 | 17,150 |
| DeepSeek V4 Flash | 31,650 | 79,050 | 158,150 |
| Hy3 | 4,300 | 10,750 | 21,500 |

**Drift vs the dated snapshot** (`model-benchmarks-2026-08.md`): Flash was 63,300 → now
31,650; Luna 4,100 → 2,050 (the "2×" promotional boost ended). All other caps unchanged.
This is exactly why caps must be re-fetched, never trusted from memory.

## Live pricing (USD per 1M tokens — Input / Output / Cached Read / Cached Write)

| Model | In | Out | Cache Read | Cache Write |
|---|---|---|---|---|
| GPT-5.6 Luna (≤272K) | 0.20 | 1.20 | 0.02 | 0.25 |
| GLM-5.3 / 5.2 / 5.1 | 1.40 | 4.40 | 0.26 | — |
| Kimi K3 | 3.00 | 15.00 | 0.30 | — |
| Kimi K2.7 Code | 0.95 | 4.00 | 0.19 | — |
| MiMo-V2.5 | 0.14 | 0.28 | 0.0028 | — |
| MiMo-V2.5-Pro | 0.435 | 0.87 | 0.003625 | — |
| MiniMax M3 / M2.7 | 0.30 | 1.20 | 0.06 | — |
| Qwen3.8 Max | 2.00 | 6.00 | 0.25 | 2.50 |
| Qwen3.7 Max | 2.50 | 7.50 | 0.50 | 3.125 |
| DeepSeek V4 Pro | 0.435 | 0.87 | 0.003625 | — |
| DeepSeek V4 Flash | 0.14 | 0.28 | 0.0028 | — |
| Hy3 | 0.14 | 0.58 | 0.035 | — |

## Model-ID → endpoint → SDK map

| Display | id | endpoint | SDK |
|---|---|---|---|
| GPT-5.6 Luna | gpt-5.6-luna | /v1/responses | @ai-sdk/openai |
| GLM / Kimi / DeepSeek / Hy3 / MiMo | glm-*, kimi-*, deepseek-*, hy3, mimo-* | /v1/chat/completions | @ai-sdk/openai-compatible |
| MiniMax M3/M2.7/M2.5, Qwen3.x Max/Plus | minimax-*, qwen3.*-max/plus | /v1/messages | @ai-sdk/anthropic |

## Live model-ID list (authoritative)

`GET https://opencode.ai/zen/go/v1/models` with `Authorization: Bearer $OPENCODE_GO_API_KEY`
→ OpenAI-format `{object:"list", data:[{id, created, owned_by}]}`. HTTP 200, ~2 KB. Use to
cross-check which models actually exist (e.g. `kimi-k2.7-code` and `glm-5.3` are both still
listed).
