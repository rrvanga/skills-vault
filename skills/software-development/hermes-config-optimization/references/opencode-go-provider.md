# OpenCode Go Provider — Endpoint Specifics

OpenCode Go (`https://opencode.ai/zen/go/v1`) is an OpenAI-compatible subscription endpoint (~$10/mo flat, responses carry `"cost": "0"`). Session-verified facts:

## Connection

- **Base URL:** `https://opencode.ai/zen/go/v1` (OpenAI chat-completions shape). The plain `https://opencode.ai/v1` path 403s.
- **Auth:** `Authorization: Bearer <key>`. Key lives in `~/.hermes/.env` as `OPENCODE_GO_API_KEY` (plus optional `OPENCODE_GO_BASE_URL`).
- **Cloudflare pitfall:** a bare `urllib` request gets `HTTP 403 Forbidden, error code 1010` (Cloudflare browser-signature block). Fix: send a browser `User-Agent` header (e.g. `Mozilla/5.0 ... Chrome/126`). With a browser UA the same request succeeds.
- **Model list:** `GET /v1/models` returns IDs like `deepseek-v4-pro`, `deepseek-v4-flash`, `qwen3.8-max`, `qwen3.7-plus`, `kimi-k2.7-code`, `kimi-k3`, `glm-5.2`, `minimax-m3`, `gpt-5.6-luna`, `grok-4.5`, `hy3`, `mimo-v2.5-pro`.
- **Reasoning models:** responses include `message.reasoning_content` and `usage.completion_tokens_details.reasoning_tokens` — reasoning consumes completion budget, so keep `max_tokens` generous (512 was too small; 2048 works).

## Hermes wiring (direct, no proxy)

```yaml
model:
  default: deepseek-v4-flash        # plain ID — no "openai/" prefix when direct
  provider: custom
  base_url: https://opencode.ai/zen/go/v1
  api_key: ${OPENCODE_GO_API_KEY}
  api_mode: chat_completions
  context_length: 131072            # hot-reloads; compression.* also hot-reloads
  max_tokens: 2048
```

Model name must be the bare ID (`deepseek-v4-flash`), not the LiteLLM-style `openai/deepseek-v4-flash` — the proxy prefix is only valid through LiteLLM.

**Preferred wiring (2026-08):** skip the hand-rolled `custom` block above —
`hermes config set model.provider opencode-go` selects the official profile
(`plugins/model-providers/opencode-zen/__init__.py` registers BOTH `opencode-zen`
= `https://opencode.ai/zen/v1` + `OPENCODE_ZEN_API_KEY` + aux `gemini-3-flash`, and
`opencode-go` = `/zen/go/v1` + `OPENCODE_GO_API_KEY` + aux `glm-5`). Same endpoint
and key, but you inherit `default_aux_model=glm-5` (cheap compression/titles) and
per-model reasoning controls. Config `model.base_url`/`model.api_key` become inert
once a profile is set. Full mechanics: `references/model-routing.md`.

## LiteLLM proxy vs direct (why "park the proxy")

- Hermes was pointed at `http://localhost:4000/v1` (LiteLLM). LiteLLM's `router_settings` with a `model_list` of `agent-main`/`agent-fast`/`agent-coding` aliases plus `order:` fallbacks.
- **Rate-limit trap:** LiteLLM fell back to free-tier Gemini/Groq deployments when the paid path errored, and the free tiers 429'd hard (Gemini free tier: 250k input tokens/min per model; "Please retry in 54s"). The gateway then retried 3× and reported `RateLimitError` for `model=agent-main` — which reads like the primary is broken when actually the fallback is.
- **Fix used:** bypass LiteLLM entirely; point Hermes `model.*` straight at the subscription endpoint. One moving part, no fallback cascade.
- If LiteLLM must stay: give each alias a primary + fallback with `order:`, set `router_settings.routing_strategy: usage-based-routing-v2`, `cooldown_time: 30`, and don't list free-tier models you can't afford to burn.

## LiteLLM config hygiene (if revisited)

- `litellm_settings.drop_params: true` stops forwarding params providers don't understand.
- `num_retries: 2`, `request_timeout: 120` reasonable.
- Config lives at `~/litellm/config.yaml` (the process runs as root with `--config /app/config.yaml` in a container — the host copy is the editable one).
- Model aliases with same `model_name` + different `order:` = failover chain; `usage-based-routing-v2` + cooldown keeps 429'd deployments out of rotation.
