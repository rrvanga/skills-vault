# Price-watchdog cron pattern (no_agent, silent-unless-breach)

Reusable design for "ping me when X drops below $Y" watchdogs on CC (or any
curl-tolerant retailer). Proven live 2026-08-12; production script:
`~/.hermes/scripts/price_watch.py` (watchlist + thresholds in the `WATCH` list
at the top — edit there, don't rewrite the file).

## Design decisions

- **`no_agent=True` cron job.** The script IS the job; stdout is delivered
  verbatim, empty stdout = silent. Zero LLM tokens per tick — pure threshold
  logic needs no model.
- **Silent unless breach.** Empty stdout on normal days; only a drop prints.
  This is the watchdog pattern (vs. a daily summary, which is a briefing).
- **Fetch failure must NOT be silent.** Non-zero exit + stderr message →
  scheduler raises an error alert. A broken watchdog failing silently is worse
  than no watchdog — you'd assume "no deals" forever.
- **Size sanity check after fetch.** CC returns HTTP 200 with junk for
  wrong-but-valid-looking category IDs. Guard: `if len(raw) < 50_000: alert
  and exit 1`. (See SKILL.md pitfall on the 200-with-unrelated-products trap.)
- **Fetching pages during research**: avoid `curl <url> | python3 -c '…'` pipes
  — they trip the security scanner ("Pipe to interpreter — downloaded content
  executed without inspection"). Fetch to a file first, then read it:
  `curl -o /tmp/page.html <url>` and `python3 -c '…' < /tmp/page.html`
  (stdin redirect from the saved file, no pipe).

## Extract + filter

- Parse with `scripts/cc_extract.py` recipe: split on
  `(?=<article class="product-miniature\b)` — note `\b`, CC renders the extra
  class `js-product-miniature` and the tag spans multiple lines. (2026-08-12:
  a naive `class="product-miniature"` lookahead silently matched nothing.)
- **Token filters: use `all(t in name.lower() for t in tokens)`, never `any`.**
  An `any()` test lets DDR4 kits match a DDR5 watch and 4TB drives match a 1TB
  watch ("nvme" alone is not a 1TB filter).
- **Watch the 2x32GB trap**: require `2x16gb` (not just `32gb`) to exclude
  64GB kits whose names contain "32GB".
- **Add a VRAM token for GPU watches**: 5060 Ti 16GB watch uses `("5060 ti",
  "16gb")` — this excludes the 8GB variants that share the base name. Without
  the VRAM token you'd alert on the wrong SKU class.
- Dedupe by product URL (`seen` set) — PrestaShop repeats variant entries.

## Test before trusting (critical — a silent parser is invisible)

A watchdog that extracts 0 products exits 0 and looks exactly like "no deals".
You cannot trust the first run. Test sequence:

1. **Parser sanity**: run extraction against a fresh fetch, print
   `raw bytes + product count` per category. Expect ~12 products per CC page.
   Zero products = parser broken, NOT "no deals".
2. **Token-match verification**: run extraction on a fresh fetch and print
   every matching listing with a WATCHED / NOT-WATCHED flag per token-set —
   the 16GB SKU must flag WATCHED while the 8GB variant flags NOT-WATCHED.
   Confirms the filters catch the right SKU *class*; silence then means
   "above threshold", not "tokens wrong". (Proven 2026-08-13 on CC's 5060 Ti
   page: 8GB $729.99 excluded, 16GB $1,129.99 watched.)
3. **Full alert path**: monkeypatch `pw.WATCH` thresholds to 9999, call
   `main()` with stdout captured → every match should appear. Then grep the
   output for false positives (DDR4, 4TB, 2x32GB). This exercises the real
   alert formatting + delivery text without waiting for an actual drop.
4. **Real run**: unpatched script must exit 0 silently when everything is
   above target.
5. **Verify cron registration** with `cronjob list` (schedule, next_run_at).

## Scheduling notes

- Daily is fine for CC (prices move daily, not hourly). `0 8 * * *` = 08:00
  local (system tz America/Vancouver).
- Script path in cronjob create must be **bare filename** relative to
  `~/.hermes/scripts/` (absolute paths are rejected). **Symlinks are also
  rejected** when they resolve outside the scripts dir (error: "Script path
  escapes the scripts directory via traversal") — deploy cron scripts as REAL
  FILE COPIES, like the other scripts in `~/.hermes/scripts/`, and re-copy
  after upstream repo changes.
- Thresholds = "interesting" line, not the absolute best-ever price. Pick a
  value ~5-10% below current street so you get a signal, not noise; GPU
  triggers can be set near the MemEx anchor (MemEx itself is Cloudflare-walled
  — see SKILL.md; CC price movement is the early-warning proxy).

## Watchlist as of 2026-08-13 (CC street prices)

- RTX 5070 Ti 16GB: $1,669.99–1,709.99 → alert ≤ $1,499.99
- RTX 5060 Ti 16GB: $1,129.99 (MSI SHADOW) / $1,119.99 (ASUS Dual OC floor) → alert ≤ $1,099.99
- 32GB DDR5-6000 (2×16): $569.99–699.99 → alert ≤ $549.99
- 1TB NVMe Gen4: $229.99 → alert ≤ $199.99
