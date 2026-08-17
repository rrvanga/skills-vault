#!/usr/bin/env python3
"""Extract product name/price/URL from a Canada Computers category page.

Usage: python3 cc_extract.py <saved_category_page.html> [--filter KEYWORD]

Reads a CC category page saved via curl and prints name, price, URL per product
block. Works on PrestaShop-style markup: <article class="product-miniature">.

Example:
  curl -sL -A 'Mozilla/5.0' 'https://www.canadacomputers.com/en/1022/desktop-memory' -o cc_ram.html
  python3 cc_extract.py cc_ram.html --filter '32GB DDR5 6000'
"""
import re
import sys


def extract(fn):
    raw = open(fn, encoding="utf-8", errors="ignore").read()
    # Tolerant lookahead: CC renders 'product-miniature js-product-miniature'
    # (extra class after the base) and the <article> tag spans multiple lines.
    blocks = re.split(r'(?=<article class="product-miniature\b)', raw)
    out = []
    for b in blocks[1:]:
        tm = re.search(r'<h2 class="h3 product-title[^"]*"[^>]*><a[^>]*>(.*?)</a>', b, re.S)
        name = re.sub(r"\s+", " ", tm.group(1)).strip() if tm else "?"
        pm = re.search(r'data-price="\$([\d,]+\.?\d*)"', b)
        price = pm.group(1) if pm else "?"
        url = re.search(r'href="(https://www.canadacomputers.com/en/[^"]+)"', b)
        out.append((name, price, url.group(1) if url else ""))
    return out


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    fn = sys.argv[1]
    flt = None
    if "--filter" in sys.argv:
        flt = sys.argv[sys.argv.index("--filter") + 1].lower()
    res = extract(fn)
    print(f"=== {len(res)} items ===")
    for name, price, url in res:
        if flt and flt not in name.lower():
            continue
        print(f"  ${price}  {name[:85]}")
        if url:
            print(f"      {url}")


if __name__ == "__main__":
    main()
