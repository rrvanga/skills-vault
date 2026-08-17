# Canada Computers — curl scraping recipe (verified 2026-08-12)

CC serves full category listings to a plain Chrome UA via curl. The automated
browser is bot-flagged site-wide (decoy page title) — **curl is the only working
path**. HTTP 200 with a big file is NOT proof of a correct page; verify product
names match expectations.

## Step 1 — get REAL category IDs from the sitemap

Guessed/wrong IDs return HTTP 200 with **unrelated products** (DVI adapters for a
CPU page, cameras for RAM, monitors for SSDs, batteries for cases). Never guess:

```bash
curl -sL --max-time 25 -A 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/126.0 Safari/537.36' \
  'https://www.canadacomputers.com/en/sitemap' -o /tmp/cc_sitemap.html
grep -oE 'href="https://www.canadacomputers.com/en/[0-9]+/[a-z0-9-]+"' /tmp/cc_sitemap.html | sort -u
```

Verified category IDs (Aug 2026):
- Graphics cards: `914/graphics-cards`
- AMD desktop CPUs: `957/amd-desktop-processors`
- Intel desktop CPUs: `960/intel-desktop-processors`
- Motherboards: `53/motherboards` (also `54/amd-motherboards`, `67/intel-motherboards`)
- Desktop memory: `1022/desktop-memory`
- Internal SSDs: `1291/desktop-laptop-internal-ssds`
- Power supplies: `1345/power-supplies`
- Computer cases: `861/computer-cases`
- CPU air coolers: `928/cpu-air-coolers`
- AIO liquid coolers: `930/aio-cpu-liquid-coolers`

## Step 2 — fetch + extract

```bash
curl -sL --max-time 25 -A '<same Chrome UA>' 'https://www.canadacomputers.com/en/<ID>/<slug>' \
  -o /tmp/cc_cat.html -w 'HTTP %{http_code} %{size_download}B\n'
```

Product markup (PrestaShop-style, ~12 products/page):
- Block container: `<article class="product-miniature js-product-miniature"` — NOTE the
  extra `js-product-miniature` class and that the tag spans multiple lines. Use the
  tolerant lookahead `(?=<article class="product-miniature\b)` when splitting; the
  exact-string lookahead `product-miniature"` matches NOTHING and silently yields 0
  products (verified 2026-08-12, CC markup changed).
- Name: `<h2 class="h3 product-title mb-0_5"><a href="...">NAME</a>`
- Price: `data-price="$X.XX"` attribute (WITH the `$` — regex must include it)
- Product URL: the `<a href>` in the thumbnail block

Working regexes (see `scripts/cc_extract.py`):
- Split: `(?=<article class="product-miniature")`
- Name: `<h2 class="h3 product-title[^"]*"[^>]*><a[^>]*>(.*?)</a>` (re.S)
- Price: `data-price="\$([\d,]+\.?\d*)"`

## Step 3 — useful query params

- Price ascending: `?order=product.price.asc` (leads with old-gen junk — filter by
  SKU class in code, e.g. keep only 32GB DDR5 6000+ for a modern build)
- Hidden SKU reach: category URL + `?q=GPU-GeForce+RTX+3060` style filters expose
  SKUs invisible to the site's own search pages (this is how the sold-out
  RTX 3060 12GB $429.99 was found)

## Prebuilt desktop hunting (verified 2026-08-13)

- **VRAM naming trap**: ARMOURY desktop titles like "GeForce RTX 5060 Ti 16GB RAM"
  — the "16GB" is SYSTEM RAM, not GPU VRAM. Never trust the listing title for
  GPU VRAM on prebuilts; read the spec table.
- Spec table extraction: product pages use `<td ... data-text="VALUE">` rows —
  grab all `data-text` values; the GPU row reads `GeForce RTX 5060 Ti` followed
  by the VRAM (`8GB`/`16GB`). Verified: ALL Canada Computers 5060 Ti prebuilts
  (ARMOURY A-397/A-077/I-358, MSI Codex Z2) ship the **8GB** card — the 16GB
  exists only as a standalone card.
- Product pages have NO `data-price` attribute (category listings only). Price:
  first `$X,XXX.XX` match in raw HTML is the product price (subsequent matches
  are financing/promo numbers).
- Cheapest-750W-Gold rotation: stock pages change weekly; the 750W Gold units
  vanish from page 1 — re-filter PSU categories per hunt (e.g. 2026-08-13:
  DeepCool PQ850G 850W Gold $129.99 was the value pick).

## Step 4 — limitations

- **Stock states are JS-only** — "In Stock" flags don't appear in curl HTML. Report
  availability as unverified.
- JSON-LD `"name"/"price"` triple mining returns 0 pairs on category pages.
- Dead paths: `/en/video-cards/...`, `/en/graphics-cards` (non-numeric) → 404 or
  login wall. Old numeric IDs (785=cpus? no — 785 was NOT cpus) silently serve
  wrong content; always confirm via product names or breadcrumb.

## Sample verified prices (Aug 2026, for calibration)

- RTX 5070 Ti 16GB: $1,349.99 MemEx (PCPartPicker datum) vs $1,669.99–1,709.99 CC
- Ryzen 7 9700X: $449.99 · Core Ultra 7 265KF: $419.99 · 9600X: $284.99
- MSI B850 GAMING PLUS WIFI: $234.99 · GIGABYTE B650 EAGLE AX: $249.99
- 32GB DDR5 6000: $569.99 (Lexar CL36) – $689.99 (TeamGroup CL30) — DRAM supercycle
- Kingston NV3 1TB: $229.99 · WD SN850X 1TB: $299.99
- MSI MAG A750GL 750W Gold ATX 3.0: $129.99 · Corsair RM850e: $144.99
- DeepCool CG330 3F case: $59.99 · PCCOOLER RT620 dual-tower cooler: $49.99

## Peer retailer access (Aug 2026)

- Memory Express: Cloudflare challenge, curl never works → get prices via
  PCPartPicker's cached single datum
- Best Buy Canada: Akamai "Access Denied" for curl AND automated browser → use
  user screenshots + OCR, or note the price as unverifiable
- Amazon: HTTP 202 bot-check; ebay.ca bot-check; reddit search.json returns HTML shell
- Craigslist Vancouver: `format=json` deprecated → HTML; title/price/pid classes
  parse empty; HTML pages are throttled
- Kijiji: needs explicit region location code or it redirects to wrong region
