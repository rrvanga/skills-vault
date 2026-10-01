---
name: web-data-extraction
description: Use when scraping live site data via API or SSR payload.
version: 1.0.0
author: hermes-agent
license: MIT
metadata:
  hermes:
    tags: [web-scraping, api-discovery, nextjs, ssr, curl]
    related_skills: [dogfood]
---

# Web Data Extraction

Extract live structured data from a website when the data isn't in the initial static HTML (SPAs, Next.js apps that hydrate client-side).

## When to Use

- You need live, up-to-date numbers from a site (leaderboards, rankings, prices, stats) and the static page or a downloaded HTML snapshot doesn't contain them.
- The data loads dynamically via an API or client-side hydration and you must find the real source.
- The obvious JSON API returns 403/auth-wall and you need an alternative route to the same data.

## Core strategy ladder (try in order, stop when you have real data)

1. **Find the data endpoint first.** Grep the page HTML (and any JS chunk URLs it references) for hints:
   - URL-like strings: `grep -oE 'https?://[^"'\'' ]*' page.html`
   - keywords: `api`, `elo`, `.json`, `fetch`, `leaderboard`, `endpoint`, `snapshot`
   - Next.js apps list their chunks in the HTML; download the chunks and grep them for the API **base host** (e.g. `grep -oE '[A-Za-z0-9.-]+api[A-Za-z0-9.-]*'`) — the frontend often points at a different host than the public site (e.g. `arena-api-stable.vercel.app`).

2. **Try the API directly** with `curl`, always with a browser User-Agent and JSON accept header:
   ```bash
   curl -s -w "%{http_code}" -A "Mozilla/5.0 ... Chrome/126.0 Safari/537.36" \
     -H "Accept: application/json" -H "Origin: <site-origin>" -H "Referer: <site-url>" \
     "<endpoint>"
   ```
   Capture the HTTP code AND the body head so you can report exactly what happened.

3. **If the JSON API returns 403 (Vercel firewall / auth wall): STOP reverse-engineering auth.** It is usually a hard wall — do NOT spend many iterations trying to extract a client token, decrypt a `ddforward` param, or guess headers. Do a bounded attempt (one or two endpoint variants), then pivot.

4. **Pivot to the server-rendered page.** Next.js embeds initial data in the returned HTML as a React Server Components payload inside `self.__next_f.push([1,"…"])`. Fetch the actual category/route page with `curl` + browser UA and parse the embedded JSON:
   - The RSC payload is JSON **double-escaped** (`\"` in the raw HTML).
   - Parse either by unescaping then `json.loads`, or with a regex over the raw escaped text, e.g. `\{\\"rank\\":(\d+),\\"modelKey\\":\\"([^"\\]+)\\",\\"modelDisplayName\\":\\"([^"\\]+)\\",\\"rating\\":([0-9.]+)`.
   - Confirm you got the right page by checking it still contains the expected internal IDs (the server-rendered page is the same data the browser would hydrate).

## Pitfalls

- **URL slugs ≠ internal data IDs.** A human URL segment may be hyphenated while the internal resource ID uses underscores (or vice versa). If a marker isn't found in the HTML, grep for the internal ID family (`…/leaderboards/<id>` or `text-*-style_control`) and read the real slug rather than guessing it from the URL.
- **403 is not a bug in your script.** Report it as `BLOCKED` with the exact endpoint + status + body, then move to the SSR-page route. Never fabricate numbers to fill a table.
- **Honest reporting is mandatory.** Final answer states: endpoints tried, HTTP codes, and either the real JSON/data obtained OR a clear "data unavailable / BLOCKED" statement.
- **Model/entity naming may differ from what a requester typed.** Before reporting, dump all unique names matching the relevant prefix and map requested → actual name (e.g. `kimi-k3` may only exist as `kimi-k3-max`). Flag non-exact matches instead of silently substituting.
- **Rounded vs precise:** leaderboards usually display rounded ratings; if you round, say so.

## Retail price scraping (Amazon.ca / Best Buy CA)

E-commerce research follows a different ladder than SSR/API discovery:

1. **Mobile endpoints often expose HTML the desktop site walls off.** Amazon.ca's `/gp/aw/s` (search) and `/gp/aw/d/<ASIN>` (detail) pages server-render for mobile UAs with no captcha, where desktop crawls get blocked.
2. **Never trust search-card prices** — Amazon cards show '?' placeholders. The ONLY authoritative number is the BuyBox price in the detail page's `twister-plus-buying-options-price-data` JSON blob. Always: collect ASINs from search, then read prices from detail pages.
3. **If a retailer's HTML is bot-blocked, probe for a JSON API variant** (Best Buy CA: `/api/v2/json/search?query=…` + Chrome UA + JSON accept works where the HTML 403s/Akamai-blocks).
4. **Bullet-level proof bar for claims** ("does this product have feature X?"): page-wide raw mention counts are noise — cross-sell carousels leak other products' specs. The feature must appear in the product's OWN spec bullets: `<span class="a-list-item">` regex on desktop layouts, tag-strip + `html.unescape` + context-grep fallback on mobile layouts.
5. **Architecture beats sweeps:** before hunting a SKU variant (e.g. a barebone), check whether the hardware makes it structurally possible — soldered LPDDR5 means a no-RAM variant cannot exist, no matter what listings appear.
6. **Prove the page parsed before trusting an empty result:** a healthy-looking 200 with large body can still fail a too-strict filter — count `data-asin` / result nodes, then loosen (collect all `B0…` ASINs, filter at the detail stage).

Full recipes, headers, and pitfalls: `references/retail-price-scraping.md`.

## References
- `references/lmarena-leaderboard.md` — worked example: LMArena text-arena category Elo (endpoints, real slug map, regex, naming quirks).
- `references/retail-price-scraping.md` — Amazon.ca mobile endpoint + BuyBox + Best Buy CA JSON recipes, bullet-level proof bar, barebone-possibility check.
- If BOTH the API and SSR routes are bot-walled (e.g. Cloudflare 403 like Memory Express), the next rung is a real engine: headless playwright-core + system chromium — see `hermes-capability-setup` → "Unattended / at-boot browser".
