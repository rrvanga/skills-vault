---
name: web-price-research
description: Use when researching retailer product prices.
version: 1.0.0
author: hermes-curator
license: CC-BY-4.0
metadata:
  hermes:
    tags: [pricing, shopping, retailers, pc-parts, deals, scraping]
    related_skills: [hermes-capability-setup]
---

# Web Price Research (retailers, deals, build comparisons)

## When to Use

Use whenever the task involves: checking or verifying product prices on retailer
websites, comparing prebuilt vs DIY build costs, validating a user-shared product
link or screenshot, deal-hunting on deal feeds (RSS/Reddit), or any "is this price
good?" question. Trigger words: price, deal, sale, street price, worth it, buy,
parts list, build comparison.

For shopping research: pull real street prices from retailer sites, verify user-shared
links/screenshots, and compare prebuilt vs DIY (PC parts, deals, local AI hardware).
**Never fabricate prices** — every figure must trace to a fetched page, an OCR'd
screenshot, or an explicit user claim.

## Core workflow

1. **curl-first, browser second.** Start with `curl -sL --max-time 25 -A '<Chrome UA>' <url>`.
   Many retailers serve full product listings to a plain Chrome UA. The browser
   (headless/automated) frequently gets flagged where curl still works.
2. **Verify the page is actually the right page.** Check `<title>`, breadcrumb JSON
   (`"breadcrumb":{"links":[...]`), and that product names match expectations.
   ⚠️ PITFALL: some sites (Canada Computers) return **HTTP 200 with completely unrelated
   products** when given a wrong-but-valid-looking category ID (DVI adapters for a CPU
   page, cameras for RAM). A 200 + size is NOT proof of content. Always grep names.
3. **Extract with block-splitting, not JSON mining.** Split on the product container tag
   (e.g. `<article class="product-miniature"`), then regex name + price per block.
   Generic JSON `"name"/"price"` triples usually return 0 pairs — the data lives in
   `data-*` attributes and `<h2 class="h3 product-title">` anchors.
4. **Cross-check against a second source** (Memory Express via PCPartPicker, Reddit RSS
   deal feeds, another retailer) — one clean datum from an alternative source beats
   ten from a page you couldn't fully trust.
5. **Report prices with source + date**, e.g. "CC verified 2026-08-12". Flag anything
   you could NOT verify (bot-blocked, JS-only stock states).

## Pitfalls

- **JS-only stock states**: "In Stock" flags often live in the JS layer curl can't read.
  Say so; don't guess availability.
- **Price sort params** (PrestaShop): `?order=product.price.asc` — but the asc list may
  lead with old-gen/legacy stock; filter in code for the SKU class you actually want.
- **Bot-blocked sites** (verified Aug 2026): Memory Express = Cloudflare challenge (curl
  never works; get prices via PCPartPicker's single clean datum). Best Buy Canada AND
  Costco.ca = Akamai "Access Denied" for curl (tiny ~400B page, `<TITLE>Access Denied</TITLE>`);
  Best Buy also blocks the automated browser. Amazon = 202. Canada Computers flags
  automated-browser sessions site-wide (decoy page title) but tolerates curl.
  Craigslist Vancouver: `format=json` is deprecated — returns HTML, and the HTML parse
  yields empty title/price/pid lists.
- **PCPartPicker category pages are JS-rendered**: `curl` on `/products/video-card/`
  returns ~436KB but only the filter panel (`c_fi<id>` checkboxes) — no product rows,
  prices, or product URLs in raw HTML (no `__NUXT__`/JSON blob either; grepping price
  strings returns nothing). The "tolerates curl" claim applies to SINGLE-PRODUCT pages
  (`/product/<slug>`); for category listings you need JS (browser) or another source.
- **Lenovo CA product URLs silently fall back**: a wrong/guessed product URL returns
  HTTP 200 with a GENERIC category page (`pageId='3333333333'`, title "Lenovo Laptops |
  Explore High-Performance Laptops…", ~1.2MB) — same silent-fallback trap as CC. Always
  grep `<title>` and confirm it's the product before extracting; page size proves nothing.
- **User-sent screenshots**: when the vision toolset is unavailable/disabled, OCR the
  image locally instead: `tesseract <path> stdout`. Works well on product-page
  screenshots (price, model, seller rating, EHF all come through). Never treat a
  screenshot as the current price without noting WHEN it was taken — prices swing.
- **Build valuation**: before claiming "DIY is cheaper than prebuilt", verify current
  RAM/SSD street prices. DRAM/NAND supercycles make these enormous swing factors —
  32GB DDR5 was ~$600 CAD and 1TB NVMe ~$230 CAD in Aug 2026 (vs ~$130/~$80 in 2024).
  A prebuilt can flip from "expensive convenience" to "genuinely cheaper" purely on
  memory pricing. State the date anchor for every build math.

## Support files

- `references/canada-computers.md` — CC-specific recipe: sitemap → real category IDs,
  extraction regex, working URL patterns, the silent-fallback trap.
- `references/price-watchdog-pattern.md` — reusable no_agent price-watchdog cron design:
  silent-unless-breach, never-silent-fail, token-filter traps (any vs all, 2x32GB),
  and the mandatory 3-step test sequence before trusting a silent watchdog.
- `scripts/cc_extract.py` — re-runnable CC product extraction (takes an HTML filename,
  prints name/price/URL per product block).
- `scripts/cc_snapshot.py` — one-off CC price snapshot across part classes (GPU/RAM/SSD
  cheapest-N lists). Reuses the live watchdog's `fetch()`/`extract()` via importlib —
  never re-implement the CC parser for a one-off check; the watchdog script at
  `~/.hermes/scripts/price_watch.py` is the canonical parser.

## After the research

User prefers: narrate the reasoning and teach as you go (plain language, explain
commands and terminology), plan before executing, present a clear verdict with the
trade-offs, then offer a concrete next step (watchdog cron, deeper check).
