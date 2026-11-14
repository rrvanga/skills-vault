# OpenCode Go — 2026-08-16 quota-verification rerun (balance question)

Re-ran the full "is there a balance/quota endpoint now?" probe. **Still no public quota API.** Details worth keeping:

## Endpoint probe results (real Bearer key, `Accept: application/json`)

| Endpoint | HTTP code | Body |
|---|---|---|
| `api.opencode.ai/usage` | 200 | `Not Found` |
| `api.opencode.ai/v1/usage` | 200 | `Not Found` |
| `api.opencode.ai/v1/balance` | 200 | `Not Found` |
| `api.opencode.ai/billing` | 200 | `Not Found` |
| `api.opencode.ai/account/usage` | 200 | `Not Found` |
| `app.opencode.ai/api/usage` | 200 | `Not Found` |

**KEY LESSON: opencode.ai's edge serves catch-all HTTP 200 with a `Not Found` body for unknown paths.** Status-code-only probing is actively misleading — every probe "succeeded". Always print the response body / check content-type before concluding an endpoint exists.

- `~/.opencode/bin/opencode --help` and `opencode stats --help`: no account/balance/quota subcommand exists. CLI is session-local stats only — never a balance source.

## Meter↔report cross-check pattern (works)

1. Compute 5h/7d/30d dollar math from `state.db` (`session_model_usage` + the report script's `GO_RATES` table).
2. Compare against the morning report's `go_quota()` section (cron output file).
- Verified 2026-08-16: agreed to the cent ($4.598/7d = 15.3% both). Small drift (~0.1%) = post-report traffic; large drift = rate table or script drifted.
- Dataset shape observed: ~908 API calls/24h, 122 distinct `session_model_usage` rows, window Aug 11→16 (7d window same rows as 30d → no rows before Aug 11; re-check if old rows appear).

## Verified balance (2026-08-16, meter)

- $12/5h: $0.13 used → **~$11.87 left**
- $30/7d: $4.60 used (15.3%) → **~$25.40 left** ← the real limiter, ~15% used mid-week
- $60/30d: $4.60 used (7.7%) → **~$55.40 left**
- Burn rate ≈ $4.60/wk → on pace for ~2/3 of the weekly bucket; no throttling in sight.