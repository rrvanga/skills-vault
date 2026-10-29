# LiteLLM model pricing map (machine-readable LLM pricing + limits)

One-curl source for per-token pricing, context windows, capability flags, and some
rate limits across **~2,700 models** — no fragile per-provider scraping. Backs the
`llmcost` repo (`~/dev/llmcost`). Use it whenever price or context-window is the
selection axis (vs. benchmark quality, which the other sources cover).

## Source

`https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json`

- Community-maintained, updated frequently. LiteLLM is the widely-used LLM router;
  its cost map is the de-facto standard for pricing metadata.
- Plain JSON, one object per model, plus a `sample_spec` key documenting the schema.
- Covers OpenAI, Anthropic, Gemini, DeepSeek, AWS Bedrock, Azure, and hundreds of
  resellers/aggregators (fireworks_ai, deepinfra, together, etc.).

## Key fields (per model entry)

| field | meaning |
|---|---|
| `input_cost_per_token` / `output_cost_per_token` | USD per token (float). ×1e6 = per-Mtok. |
| `max_input_tokens` / `max_output_tokens` | context window / max output. |
| `litellm_provider` | provider tag (`deepseek`, `openai`, `anthropic`, ...). |
| `mode` | `chat`, `embedding`, `image_generation`, `realtime`, etc. |
| `supports_vision` / `supports_function_calling` / `supports_reasoning` / `supports_prompt_caching` / `supports_web_search` | capability bools. |
| `tpm` / `rpm` | tokens/min / requests/min rate limits (only some models). |

## Gotchas

- **Provider tags are not unique** — the same model id appears under many providers
  (e.g. `deepseek-v4-flash` under `deepseek`, `azure_ai`, `dashscope`, `fireworks_ai`,
  ...) at different prices. Always filter/compare by `litellm_provider`, and expect
  provider-prefixed ids too (`azure_ai/deepseek-v4-flash`).
- Some entries carry `None` costs (free/gateway models) — normalize defensively.
- For a deterministic daily-diff pipeline, sort by `(provider, model)` and strip any
  `generated_at` field before comparing (see the daily-commit watchdog recipe in the
  hermes-cron-operations skill).

## Normalization snippet (Python)

```python
import json, urllib.request
u = "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json"
d = json.load(urllib.request.urlopen(u))
for name, e in d.items():
    if name == "sample_spec" or not isinstance(e, dict):
        continue
    ic = e.get("input_cost_per_token")
    oc = e.get("output_cost_per_token")
    in_mtok  = round(ic * 1e6, 4) if isinstance(ic, (int, float)) else None
    out_mtok = round(oc * 1e6, 4) if isinstance(oc, (int, float)) else None
    # also: e["litellm_provider"], e.get("max_input_tokens"),
    #       e.get("max_output_tokens"), e.get("mode"), supports_* flags, tpm, rpm
```
