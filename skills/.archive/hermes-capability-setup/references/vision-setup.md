# Vision capability on this machine — investigation notes (Aug 2026)

Investigation for "what tools do you need for vision". Verified by reading
`~/.hermes/hermes-agent/` source, not by live test (no vision backend active).

## Current state

- `vision` toolset EXISTS (`tools/vision_tools.py`, ~2,200 lines) but is in
  `agent.disabled_toolsets` in `~/.hermes/config.yaml`.
- `auxiliary.vision.provider: auto`, `model: ''` — no override.
- `image_input_mode: auto` (default in `config_defaults.py` line 273).
- `.env` has ONLY the opencode-go key. No OPENROUTER_API_KEY, no
  `~/.hermes/auth.json` (Nous), no ANTHROPIC_API_KEY.
- Consequence: vision auto-chain has no viable backend today → "no vision"
  is an environment state, not a missing feature.

## Vision auto-detection chain (`agent/auxiliary_client.py` docstring, lines 21-27)

1. Selected main provider IF it is a supported vision backend
2. OpenRouter (needs OPENROUTER_API_KEY)
3. Nous Portal (`~/.hermes/auth.json`)
4. Native Anthropic (needs ANTHROPIC_API_KEY)
5. Custom endpoint (`config.yaml model.base_url` + OPENAI_API_KEY) —
   local vision models: Qwen-VL, LLaVA, Pixtral
6. None

Text-task chain differs: adds Codex OAuth and direct API-key providers
(z.ai, Kimi, MiniMax) — see same docstring lines 7-15.

## Provider capability guards

- `_PROVIDERS_WITHOUT_VISION = {"kimi-coding", "kimi-coding-cn"}` — Kimi
  coding plan endpoint has no image_in capability; vision only on
  api.moonshot.ai (pay-as-you-go).
- `_PROVIDER_VISION_MODELS = {"xiaomi": "mimo-v2.5", "zai": "glm-5v-turbo"}`
  — providers whose vision model differs from chat model.
- `_main_model_supports_vision()` returns True when capability is UNKNOWN
  (uncatalogued provider) — the call is attempted anyway. DeepSeek family is
  explicitly called text-only in a comment; opencode-go (aggregator) is
  uncatalogued → must be live-tested with a real image.

## Image handling in vision_tools.py (built-in, no setup needed)

- SSRF guard via `tools/url_safety.py` (sync + async), 50MB download cap,
  streaming download w/ atomic replace, retryable-error classification.
- Provider-supported inline media: jpeg/png/gif/webp only. SVG rasterized
  via cairosvg → svglib+reportlab → rsvg-convert → inkscape (best-effort);
  BMP/TIFF/etc re-encoded to PNG via Pillow. Unsupported media type would
  permanently wedge conversation history (baked into immutable messages).
- CPU-bound encode/resize offloaded to a dedicated ThreadPoolExecutor sized
  to host core count (`auxiliary.vision.max_concurrency` or
  HERMES_VISION_MAX_CONCURRENCY) — protects the event loop from encode storms
  (prod incident June 2026: dashboard flapped UNHEALTHY).

## Enablement paths (cost-ranked)

1. **Zero-cost (test first):** enable toolset (`vision` out of
   disabled_toolsets), then live-test whether opencode-go accepts image
   input — e.g. `qwen3.8-max` (Qwen family is often multimodal). If the
   endpoint accepts `image_url` blocks, vision works on the subscription.
2. **Local AI desktop (planned purchase):** run Qwen-VL/LLaVA/Pixtral via
   custom endpoint (`auxiliary.vision.provider` + model.base_url) on the new
   GPU box — matches user's local-AI desktop plan.
3. **Paid API fallback:** add OPENROUTER_API_KEY (or Anthropic key) —
   currently absent.

## Config edit notes

- `hermes config set` handles scalars only; nested dicts (aux vision
  overrides) need direct config.yaml edit via python3 (patch tool guard
  refuses config.yaml).
- `hermes config get auxiliary` shows raw stored strings; `moa list` /
  effective resolution shows parsed values — same raw-vs-effective split
  applies to aux vision overrides.
