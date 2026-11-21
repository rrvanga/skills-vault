#!/usr/bin/env python3
"""Condense a `pdftotext -layout` dump of an IRCC form / checklist PDF.

IRCC form PDFs stamp a footer on every page ("Save Reset Form  Print Form",
"Page N of M", "IMM 5533 (09-2022) E") and pad with blank lines. Dropping both
turns a ~45 KB dump into ~12 KB of usable text while keeping the original line
numbers valid as grep anchors for follow-up reads.

Usage:
    pdftotext -layout imm5533e.pdf imm5533e.txt
    python3 ircc_forms_extract.py imm5533e.txt                 # condensed + numbered
    python3 ircc_forms_extract.py imm5533e.txt --index         # structural headings only
    python3 ircc_forms_extract.py imm5533e.txt --part A        # one PART section
    python3 ircc_forms_extract.py imm5533e.txt --grep India    # matches + 2 lines context

Exit codes: 0 ok, 2 missing/empty input.
"""

from __future__ import annotations

import argparse
import re
import sys

FOOTER = re.compile(
    r"(Save\s+Reset Form|Print Form"
    r"|^\s*Page\s+\d+\s+of\s+\d+\s*$"
    r"|IMM\s*\d{4}\s*\(\d{2}-\d{4}\)\s*E?)"
)
HEADING = re.compile(
    r"^\s*(PART\s+[A-Z]\b.*"
    r"|SUPPORTING DOCUMENTS.*"
    r"|DOCUMENT CHECKLIST.*"
    r"|SECTION\s+\d+.*"
    r"|Important Reminders.*"
    r"|Table of Contents.*"
    r"|[A-Z][A-Z0-9 /&()'’.,-]{12,}\s*)$"
)
PART = re.compile(r"^\s*PART\s+([A-Z])\b")


def load(path: str) -> list[tuple[int, str]]:
    """Return (original_line_number, text) for every kept line."""
    kept: list[tuple[int, str]] = []
    with open(path, errors="ignore") as fh:
        for n, line in enumerate(fh.read().split("\n"), 1):
            if not line.strip():
                continue
            if FOOTER.search(line):
                continue
            kept.append((n, line.rstrip()))
    return kept


def select_rows(kept, args) -> list[tuple[int, str]]:
    if args.index:
        return [(n, l) for n, l in kept if HEADING.match(l)]

    if args.grep:
        pat = re.compile(re.escape(args.grep), re.I)
        seen: set[int] = set()
        rows: list[tuple[int, str]] = []
        for i, (_, line) in enumerate(kept):
            if not pat.search(line):
                continue
            for n, l in kept[max(0, i - 2): i + 3]:
                if n not in seen:
                    seen.add(n)
                    rows.append((n, l))
        return rows

    if args.part:
        want = args.part.strip().upper()[:1]
        rows, on = [], False
        for n, l in kept:
            m = PART.match(l)
            if m:
                on = m.group(1) == want
            if on:
                rows.append((n, l))
        return rows

    return kept


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("txt", help="pdftotext -layout output file")
    ap.add_argument("--index", action="store_true", help="structural headings only")
    ap.add_argument("--grep", metavar="TERM", help="matches with 2 lines of context")
    ap.add_argument("--part", metavar="LETTER", help="one PART section, e.g. A")
    args = ap.parse_args(argv)

    kept = load(args.txt)
    if not kept:
        print(f"{args.txt}: no usable text (missing or empty?)", file=sys.stderr)
        return 2

    rows = select_rows(kept, args)
    print(f"# {args.txt}: {len(kept)} kept lines, {len(rows)} printed")
    for n, l in rows:
        print(f"{n}|{l}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
