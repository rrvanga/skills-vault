#!/usr/bin/env python3
"""Fresh Canada Computers price snapshot for build/part research (read-only GETs).

Reuses the price watchdog's battle-tested fetch()/extract() (CC PrestaShop markup)
via importlib — never re-implement the parser for a one-off check. Widens the net
beyond the watchdog's alert thresholds to report the cheapest N items per part class,
plus any extra interest patterns (e.g. a second GPU tier).

Usage:
    python3 cc_snapshot.py                     # default watchlist + GPU/RAM/SSD classes
    python3 cc_snapshot.py "5070 ti" "5060 ti" # extra tokens appended to each class

Exit code is always 0 unless a fetch fails (non-zero + stderr message, mirroring the
watchdog's never-silent-fail contract).
"""
import importlib.util
import sys
from datetime import date

WATCHDOG_PATH = "/home/<REDACTED>/.hermes/scripts/price_watch.py"

PAGES = [
    ("https://www.canadacomputers.com/en/914/graphics-cards", "GPU"),
    ("https://www.canadacomputers.com/en/1022/desktop-memory", "RAM"),
    ("https://www.canadacomputers.com/en/1291/desktop-laptop-internal-ssds", "SSD"),
]

# (label, tokens-ALL, max rows to show). Tokens must ALL appear (case-insensitive).
INTEREST = [
    ("RTX 5070 Ti", ("5070 ti",), 8),
    ("RTX 5060 Ti 16GB", ("5060 ti", "16gb"), 6),
    ("32GB DDR5 (2x16)", ("2x16gb", "ddr5"), 6),
    ("1TB NVMe", ("1tb", "nvme"), 5),
]


def main():
    spec = importlib.util.spec_from_file_location("price_watch", WATCHDOG_PATH)
    pw = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pw)

    extra = [t.lower() for t in sys.argv[1:]]
    print(f"Canada Computers snapshot — {date.today().isoformat()} (verified today)\n")

    for url, label in PAGES:
        try:
            raw = pw.fetch(url)
        except Exception as e:
            print(f"[{label}] FETCH FAILED: {e}")
            sys.exit(1)
        if len(raw) < 50_000:
            # 200-but-wrong-content trap (silent-fallback / bad category ID).
            print(f"[{label}] suspiciously small page ({len(raw)}B) — possible wrong-content trap")
            sys.exit(1)
        items = pw.extract(raw)
        print(f"=== {label} ({len(items)} products on page) ===")
        for want, tokens, cap in INTEREST:
            seen, rows = set(), []
            for name, price, purl in items:
                nl = name.lower()
                if not all(t in nl for t in tokens + tuple(extra)):
                    continue
                if purl in seen:
                    continue
                seen.add(purl)
                rows.append((price, name, purl))
            if not rows:
                continue
            rows.sort()
            print(f"  -- {want} (cheapest {min(cap, len(rows))}):")
            for price, name, purl in rows[:cap]:
                print(f"     ${price:,.2f}  {name}")
                print(f"        {purl}")
        print()


if __name__ == "__main__":
    main()
