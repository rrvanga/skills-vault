# Retail price scraping — Amazon.ca + Best Buy CA (proven 2026-08)

Worked recipes from the "cheapest OCuLink mini PC" research (Canada, CAD-only). Verified repeatedly; rebuild from these instead of re-deriving.

## Amazon.ca mobile endpoints (no captcha, server-rendered)

Always send BOTH headers:
- iPhone UA: `Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1`
- `Accept-Language: en-CA,en;q=0.9`

Endpoints:
- Search: `https://www.amazon.ca/gp/aw/s?k=<urlencoded query>` — collect `data-asin` tokens with `re.findall(r'data-asin="(B0[A-Z0-9]{8})"', html)`. Titles/prices on the card are UNRELIABLE ('?' placeholders) — never quote them.
- Detail/BuyBox: `https://www.amazon.ca/gp/aw/d/<ASIN>` — parse price from the `twister-plus-buying-options-price-data` JSON blob (regex for the ASIN's `displayPrice`), not from visible HTML.

## Amazon.ca pitfalls (all hit live)

- **Too-strict title filter ⇒ `ASINs: []` even on a healthy page.** A 200 with a 1.3 MB body and 53 `data-asin` tokens is fine — the filter ate everything. Fix: collect ALL `B0…` ASINs raw, then disambiguate on the detail pages (title + bullets), not on search.
- **Prove the parse before debugging your logic:** count `data-asin` occurrences AND `s-result-item` nodes AND check for captcha markers; an empty ASIN list with a healthy page means the filter is wrong, not the fetch.
- **Bullet regex differs by layout.** Desktop detail pages wrap spec bullets in `<span class="a-list-item">\s*([^<]{15,240})`. The MOBILE detail layout (`/gp/aw/d/` with iPhone UA) may return ZERO matches from that regex despite a perfect fetch. Fallback that works:
  ```python
  import html, re
  text = html.unescape(re.sub(r'<[^>]+>', ' ', page))
  for m in re.findall(r'.{80}(Oculink|USB4|M\.2).{140}', text, re.I):
      print(m)
  ```
  Count matches and print the surrounding text so you can judge whether a mention is a real spec bullet or cross-sell noise.
- **Reviewer comments carry engineering caveats** spec sheets omit (e.g. "Does OCuLink steal one of the NVMe slots? Nobody knows"). Mine the reviews text when a product's lane-sharing behavior is undocumented; report the caveat honestly.
- **Cross-check a second source when one exists:** K16 was $879.00 buybox on Amazon.ca vs $877.00 on Best Buy CA (sku 19860520) — both quoted, both CAD, both live. Two confirmations beat one.

## Best Buy CA JSON API

Plain HTML is Akamai-blocked; the JSON API is not:
```bash
curl -s -A "<Chrome UA>" -H "Accept: application/json" \
  "https://www.bestbuy.ca/api/v2/json/search?query=<q>&pageSize=10"
```
Gives sku, product name, regular/sale price. Verified Vulcan sources: Amazon.ca buybox + Best Buy CA JSON only.

## Proof bar for "does product X have feature Y?"

- Page-wide raw mention counts are NOISE (cross-sell carousels leak other products' specs into the HTML — an `oculink` grep across a page can hit 8–14 hits from unrelated listings).
- The deciding bar: the feature appears in the product's OWN spec bullets (desktop `a-list-item` spans or the tag-strip fallback above), with the meaty context text quoted.
- Marketing copy is not proof; bullet-level grep is the bar.

## Structural SKU check (barebones / no-RAM variants)

Before spending sweeps hunting for a variant: is it possible in hardware?
- LPDDR5 soldered (not SO-DIMM socketed) ⇒ a "barebone"/no-RAM SKU cannot exist — all listings will ship RAM. The K16 line is soldered; the K12 (socketed DDR5 SO-DIMM) is strippable. Reason from the architecture first, then verify listings.
- When comparing barebone + parts vs a complete machine, match the RAM tier (a 32GB soldered machine compares against a 32GB SO-DIMM kit price, not 16GB).