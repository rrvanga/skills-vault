# Search-engine fallback ladder (curl-only, no browser)

When the browser harness is unavailable or a target engine blocks curl, this is the
tested order of attack (validated 2026-08-17 while researching "B70 Pro").

## 1. DuckDuckGo Lite — primary (works)

```
curl -s "https://lite.duckduckgo.com/lite/?q=<urlencoded query>" \
  -H "User-Agent: Lynx/2.8.9" -o /tmp/ddg.html
```

- Plain HTML, no JS, bot-tolerant with the Lynx UA. Engines that passed: this one.
- Result anchors look like:
  `<a rel="nofollow" href="//duckduckgo.com/l/?uddg=<urlencoded>&rut=..." class='result-link'>Title</a>`
  so parse ANY `<a>` whose href contains `uddg=`, then URL-decode the `uddg=` param
  to get the real URL. Do NOT rely on attribute order (rel/href/class vary).
- Query sensitivity: `"B70 Pro" mini PC specs` returned 1 result; a near-identical
  query returned 0 (rate-limit or tokenization). Re-issue a differently-phrased query
  once before concluding "no results".
- The full-HTML endpoint (`html.duckduckgo.com/html/?q=`) can return empty for the
  same query that lite answers — prefer lite.

## 2. Brave — works but markup is svelte-rendered, fiddly

```
curl -s "https://search.brave.com/search?q=<q>" -H "Mozilla/5.0 ... Chrome/126.0 ..." -o /tmp/brave.html
```

- Returns a real results page (~100KB), but anchor-title pairs are NOT in simple
  `<a href title>` form. The useful bit is the `snippet-title` div carrying a
  `title="..."` attribute with the display title; real URLs hide in raw hrefs —
  `grep -oE 'https?://[^"]*(newegg|amazon|...)[^"]*'` can surface them.
- Use when DDG lite gives nothing; expect a messier parse.

## 3. Known blockers (don't burn iterations)

- **Bing** (`bing.com/search?q=`) — 0 results parsed with Chrome UA; markup is
  hydration-heavy. Not worth the fight.
- **Mojeek** — serves a CAPTCHA page (`<title>Captcha</title>`).
- **Reddit search API** (`reddit.com/search.json`) — non-JSON response (blocked).
- **Amazon.ca** `s?k=` — 1.3KB stub, no results.

## 4. Retail lookup — verify the real domain first

Squatters park lookalike domains; always confirm before trusting a URL:
- `memexpress.com` → GoDaddy parked "for sale" page. The real store is
  `memoryexpress.com`, which is Cloudflare-gated (`403 Just a moment...`).
- `newegg.ca/p/pl?d=<query>` works with a Chrome UA (item titles in
  `class="item-title"`, prices in `class="price-current"`).

## Pattern summary

Lite DDG (Lynx UA) → Brave → targeted retail/API direct. When a source captchas or
blocks, say BLOCKED with the exact engine + response and move on — never fake results.