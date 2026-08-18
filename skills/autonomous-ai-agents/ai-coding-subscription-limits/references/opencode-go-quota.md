# OpenCode Go subscription — quotas & usage tracking (verified 2026-08-11)

Provider: opencode-go, base URL `https://opencode.ai/zen/go/v1`, key `OPENCODE_GO_API_KEY` in `~/.hermes/.env`. Default model deepseek-v4-flash.

## Subscription pricing (verified from repo docs 2026-08-11)

- **$5 for the first month, then $10/month** (flat). User pays $10/mo — NOT free; treat "zero cost" as wrong.
- Canonical source: `packages/web/src/content/docs/go.mdx` in the anomalycha/opencode repo (raw.githubusercontent fetch works; the rendered `opencode.ai/docs/go` page is a JS SPA that curl can't parse — fetch the .mdx raw instead). Full tree listing via `api.github.com/repos/anomalyco/opencode/git/trees/dev?recursive=1` to find doc paths.
- **Free-model fallback**: "If you reach the usage limit, you can continue using the free models" — a subset of models keeps working at $0 after the quota buckets are exhausted rather than blocking. This is the likely source of "$0 for go" claims — it's the fallback tier, not the subscription price.
- "With Go, you pay $10/month and we aim to give you 6x that in usage" — the $60/mo bucket ≈ 6× the subscription.

## Per-model rates & included monthly usage (from go.mdx table, 2026-08-11)

| Model | Input $/1M | Output $/1M | Cache-read $/1M | Cached-write $/1M | Included $/mo |
|---|---|---|---|---|---|
| Grok 4.5 | $2.00 | $6.00 | $0.30 | - | $15 |
| GPT 5.6 Luna (≤272K) | $0.20 | $1.20 | $0.02 | $0.25 | $15 |
| GPT 5.6 Luna (>272K) | $0.40 | $1.80 | $0.04 | $0.50 | $15 |
| GLM-5.2 / GLM-5.1 | $1.40 | $4.40 | $0.26 | - | $60 |
| Kimi K3 | $3.00 | $15.00 | $0.30 | - | $15 |
| Kimi K2.7 Code / K2.6 | $0.95 | $4.00 | $0.19 | - | $60 |
| MiMo V2.5 | $0.14 | $0.28 | $0.0028 | - | $60 |
| MiMo V2.5 Pro | $0.435 | $0.87 | $0.003625 | - | $15 |
| MiniMax M3/M2.7/M2.5 | $0.30 | $1.20 | $0.06 | - | $60 |
| Qwen3.8 Max | $2.00 | $6.00 | $0.25 | $2.50 | $15 |
| Qwen3.7 Max | $2.50 | $7.50 | $0.50 | $3.125 | $60 |
| Qwen3.7 Plus (≤256K) | $0.40 | $1.60 | $0.04 | $0.50 | $60 |
| Qwen3.7 Plus (>256K) | $1.20 | $4.80 | $0.12 | $1.50 | $60 |
| Qwen3.6 Plus (≤256K) | $0.50 | $3.00 | $0.05 | $0.625 | $60 |
| Qwen3.6 Plus (>256K) | $2.00 | $6.00 | $0.20 | $2.50 | $60 |
| DeepSeek V4 Pro | $0.435 | $0.87 | $0.003625 | - | $15 |
| DeepSeek V4 Flash | $0.14 | $0.28 | $0.0028 | - | $60 |
| Hy3 | $0.14 | $0.58 | $0.035 | - | $60 |

Key: "included $/mo" (the doc's **Usage** col) = dollar value of usage your $10/mo covers before the monthly cap. Most models get the full **6x multiplier** ($10 → $60); the $15 models (GPT 5.6 Luna, Qwen3.8 Max, Qwen3.7 Max, Kimi K3, MiMo V2.5 Pro, DeepSeek V4 Pro) only get **1.5x** ($10 → $15) — 4x less usage. **Do NOT read the "Cached Write" col as a usage multiplier** (it's the $/1M cache-write price; "-" = not charged). The "usage multiplier" is the $15-vs-$60 gap, not a per-token column. Effective request counts (per $12/5h bucket, from doc): DeepSeek V4 Pro 3,450 vs V4 Flash 31,650 — Flash yields ~9x more requests (≈ 4x included-usage × 3.1x token-price). Rate table in the doc may lag console reality — the doc says limits/pricing "may change as we learn from early usage".

## Limits (dollar-based buckets, enforced server-side)

- $12 / 5 hours
- $30 / 1 week
- $60 / 1 month

Enforced via `accountRateLimit` (visible in `strings` of `~/.opencode/bin/opencode`, "Go limit reached" dialog). No public quota API — dashboard-only. `opencode stats` is local-only session stats (SQLite), NOT quota.

## Ground truth: Hermes state.db

`~/.hermes/state.db` (SQLite) records every API call in `session_model_usage` (cols incl. `last_seen`, `api_call_count`, token counts). Query read-only: `python3 -c "import sqlite3; ...uri=file:...?mode=ro"` or `sqlite3 file:...?mode=ro`.

- `estimated_cost` = $0.0000 for Go (cost table lacks Go pricing) → token→$ math is manual.
- Filters: traffic to `opencode.ai/zen/go/*`; window = MIN/MAX `last_seen`.
- Note: calls landing in state.db later (rescue sessions) shift numbers slightly; re-run to refresh.

## Token→$ rates (per 1M tokens, from opencode.ai/docs/go pricing table)

| Model | Input | Output | Cache-read |
|---|---|---|---|
| deepseek-v4-flash | $0.14 | $0.28 | $0.0028 |
| pro / glm tiers | higher; see report script comment block | | |

Cached tokens ≈ 50× cheaper than fresh input — why cache-read-heavy usage stays cheap.

## Report scripts (both patched 2026-08-11 — keep in sync if rates change)

- `~/.hermes/scripts/token_usage_report.py` — 07:30 cron (no_agent, verbatim). Has `go_quota(since)` + `-- OpenCode Go quota --` section: 5h/7d/30d usage vs $12/$30/$60 caps, plus Go rates comment block.
- `~/.hermes/scripts/morning_context.py` — 07:00 brief context feed. One Go-quota summary line after totals.

## Pitfalls learned

- `errors.log` limit hits (526 found) traced to the OLD LiteLLM path `localhost:4000` → Google Vertex free tier, NOT Go. Zero Go limit errors since direct opencode-go routing. Don't attribute old-log hits to the current provider.
- CLI binary at `~/.opencode/bin/opencode` (not on PATH); credential store `~/.local/share/opencode/auth.json` — never print key values.
- `api.opencode.ai` is the real API host; `opencode.ai/api/*` → 404. No usage/quota endpoint exists.

## 2026-08-15 addendum (post $30 top-up incident — read this)

- Root causes of the freeze: (1) `fallback_model` was commented out in config.yaml — NO auto-failover existed (nothing to switch to on 429); (2) token_usage_report.py `GO_RATES` covered only 4 of ~21 models → anything else silently priced at flash rate; (3) script `DEFAULT_MODEL` was stale (`deepseek-v4-pro`) vs config (`deepseek-v4-flash`).
- FIXED in token_usage_report.py: full rate table incl. `glm-5.3` (GLM tier — ASSUMED, not in go.mdx), unknown-model self-warning line, bucket alarms at 50% (⚠️) / 80% (🔴), DEFAULT_MODEL=deepseek-v4-flash.
- CORRECT config key is **`fallback_providers.*`** (`provider`/`model`/`base_url`/`key_env`) — the `fallback_model:` block in config.yaml template is OUTDATED. Use `hermes config set fallback_providers.X Y` and `hermes config unset fallback_providers.X`.
- Current fallback (set 2026-08-17, verified via `hermes config get`): **opencode-go / hy3-free / `https://opencode.ai/zen/v1` / OPENCODE_GO_API_KEY** — a FREE-tier model on the same key, so a $30/wk dollar-bucket exhaustion now auto-switches to the free tier instead of freezing. (Previously nemotron-3-ultra-free, swapped 2026-08-17 when the adaptive monitor found it unhealthy; before that glm-5.2 on zen/go/v1 — same paid bucket, useless for bucket exhaustion.)
- METER vs SERVER lesson: state.db math said ~13% of the 7d bucket while the server enforced the cap. No quota API exists — when Go shows "limit reached", TRUST THE SERVER DIALOG over local math and switch model/provider immediately.
- Only LLM credential on this machine: OPENCODE_GO_API_KEY. `HERMES_CUSTOM_LOCALHOST_11434/4000_API_KEY` env entries are vestigial — nothing listens on those ports.
- REAL usage data: the Go dashboard lives at `https://app.opencode.ai/usage` (SPA; no API endpoint — /v1/usage etc. all "Not Found"; web-dashboard data is client-side, not scrapable). Verified 2026-08-15: real monthly spend ≈ $3.3 (Aug 11 $0.41, 12 $0.40, 13 $0.00 = freeze day, 14 $2.40). The original freeze was almost certainly the FREE-TIER weekly limit, not the paid $30/wk bucket — the meter was modeling the wrong plan tier. After upgrading to paid, state.db math (fixed table) now matches the dashboard within ~20%.
- **FREE MODELS WORK — corrected 2026-08-15** (earlier "not reachable" conclusion was WRONG — I tested only the paid endpoint zen/go/v1, where free models are intentionally "not supported", and generalized from one down upstream). Free models respond on **`https://opencode.ai/zen/v1/chat/completions`** with the SAME `OPENCODE_GO_API_KEY`, **unprefixed** IDs. Verified 200 OK: `hy3-free`, `nemotron-3-ultra-free`, `nemotron-3.5-lightning-free`. Currently down (503 "Endpoint is unavailable"): `deepseek-v4-flash-free`, `mimo-v2.5-free`, `laguna-s-2.1-free`. Free-tier usage is tracked separately and does NOT consume the paid $12/$30/$60 buckets — THE escape hatch for dollar-bucket exhaustion. `zen/v1/models` lists the full opencode catalog (claude-*, gemini-*) on this key.
- Burst guard added 2026-08-15: cron `go_bucket_watchdog.py` every 2h (08:00-22:00, no_agent, silent) — alerts only when 5h bucket ≥ 50% or 7d ≥ 60%. The 07:30 report can't see mid-day bursts; this closes that gap.
- **2026-08-18 addendum**: adaptive monitor detected `nemotron-3-ultra-free` healthy again (preference-order leader recovered) → fallback switched back from `hy3-free` to `nemotron-3-ultra-free` via `hermes config set fallback_providers.model nemotron-3-ultra-free` (verified: provider opencode-go, base_url zen/v1, key_env OPENCODE_GO_API_KEY). Catalogs unchanged (paid26/zen61/free6 identical), no GO_RATES pricing needed.
- **ADAPTIVE MONITOR added 2026-08-15**: cron `81a8bc241220` "Go adaptive monitor" (2-hourly, `monitor_script=adaptive_monitor.py`, agent fires ONLY when output hash changes). It pings the free-tier fallbacks in preference order (nemotron-3-ultra-free > hy3-free > nemotron-3.5-lightning-free > deepseek-v4-flash-free > mimo-v2.5-free > laguna-s-2.1-free) and fingerprints BOTH catalogs (`zen/v1/models` + `zen/go/v1/models`). On change the agent self-heals: re-wires `fallback_providers.model`, prices new paid models into both GO_RATES tables (sibling analogy + `# GUESS`), evaluates new `-free` models, updates this reference. Stable lines: `fallback=`, `free=`, `paidN=`, `zenN=`; `fetch=FAIL` is a STABLE failure string (no false fires). Test hooks: `ADAPT_ZEN_URL`/`ADAPT_GO_URL`/`ADAPT_CHAT_URL` env overrides. CRITICAL pitfall: python urllib gets HTTP 403 from opencode.ai's edge unless it sends a browser User-Agent (curl is fine) — the script hardcodes one.
