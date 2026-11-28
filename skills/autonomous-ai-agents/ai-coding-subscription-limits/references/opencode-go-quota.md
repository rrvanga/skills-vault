# OpenCode Go / Zen quota & free-tier reference

Referenced by the `Go adaptive monitor` cron. (Original path had gone missing — recreated 2026-11-28.)

## Placement rules
- Free models work ONLY on `https://opencode.ai/zen/v1` — never on `zen/go/v1`.
- Fallback config lives in `fallback_providers.*` (~/.hermes/config.yaml). Change only via
  `hermes config set fallback_providers.model <m>`; provider stays `opencode-go`,
  base_url stays `https://opencode.ai/zen/v1`, key_env stays `OPENCODE_GO_API_KEY`.
- Rate tables are the `GO_RATES` dicts (4-tuple: $/1M input, output, cache-read, cache-write) in
  BOTH `~/.hermes/scripts/token_usage_report.py` and `~/.hermes/scripts/morning_context.py`.
  Keep them in sync; mark guessed prices with `# GUESS`.
- Probes: `curl` with a browser User-Agent (python urllib gets HTTP 403). Free SKUs typically answer
  `429 FreeUsageLimitError` ("Free usage limit reached") when the account-wide free quota is exhausted —
  that is account-level, not per-model.

## Free-tier preference order (monitor)
nemotron-3-ultra-free > hy3-free > nemotron-3.5-lightning-free > deepseek-v4-flash-free >
mimo-v2.5-free > laguna-s-2.1-free

## Addendum
- **2026-11-28** — Catalog churn, no action possible:
  - `free=`: `tidepool-alpha-free` removed (also gone from zen/v1); `seaglass-alpha-free` added
    (zen/v1 + free tier only, no paid sibling) → priced $0/# GUESS in both GO_RATES.
  - `paidN=`: `hungerg-free` added, but it appears ONLY on `zen/go/v1` — absent from free tier and
    zen/v1, so it cannot serve as a fallback. Priced $0/# GUESS for meter completeness.
  - zen/v1 gained media SKUs: `gpt-transcribe`, `grok-voice-transcribe-2.0`,
    `grok-imagine-video-1.5`, `grok-imagine-video-1.5-lite` (not LLM candidates, not rate-priced).
  - `fallback=ALL-DEAD` both before and after; probe of all 10 free models → 429 `FreeUsageLimitError`
    on every one (account-wide free quota exhausted). Fallback config intentionally left at the paid
    `deepseek-v4.1-flash`; `needfix=no`. No flip performed.
  - Both meter scripts re-run after edits: exit 0, no unknown-model warnings.
