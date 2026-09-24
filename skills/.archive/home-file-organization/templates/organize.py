#!/usr/bin/env python3
"""Generic home-directory organizer: explicit rule table, dry-run, manifest rollback.

Copy and adapt RULES + SRC_DIRS to the machine. Usage:
    python3 organize.py            # dry-run: print mapping, touch nothing
    python3 organize.py --apply    # move + append from<TAB>to lines to MANIFEST

Guarantees: unknowns stay put; collisions SKIP (never overwrite); every move logged.
"""
import os, re, shutil, sys
from collections import defaultdict
from datetime import date

HOME = os.path.expanduser("~")
DOCS = os.path.join(HOME, "Documents")
MANIFEST = os.path.join(HOME, "backups", f"org-manifest-{date.today().isoformat()}.txt")

# (target folder name, regex) — matched case-insensitively over the filename
RULES = [
    ("Taxes",   re.compile(r"tax|1099|shoonya|w2|property card|employ.*income|^employment\.", re.I)),
    ("Identity",re.compile(r"sin number|pr card|passport|driv|dlback|icbc|immigrat|i-94|travel|ircc|visa", re.I)),
    ("Legal",   re.compile(r"p14|deed|spa|insurance|consent|ozone|movein|rental|waiver|geico", re.I)),
    ("Career",  re.compile(r"offer[ _]?letter|cover letter|resume|professional summary|reference|megaport|hr request", re.I)),
    ("Study",   re.compile(r"leetcode|book1|qa\.xlsx|intro|sedgewick", re.I)),
    ("Personal",re.compile(r"img_|dp\.jpg|photos|prints", re.I)),
    ("Notes",   re.compile(r"^notes[12]$|^summary\.txt$", re.I)),
]
SKIP_RE = re.compile(r"^\.~lock.*#$|~$")          # LibreOffice lock droppings
KEEP = {"learn"}                                    # dirs never touched
SRC_DIRS = ["Downloads", "Desktop", "Documents"]    # relative to HOME

def main():
    apply = "--apply" in sys.argv
    plan, unmatched = defaultdict(list), []
    for sdir in SRC_DIRS:
        base = os.path.join(HOME, sdir)
        if not os.path.isdir(base):
            continue
        for entry in sorted(os.listdir(base)):
            if entry in KEEP or SKIP_RE.search(entry):
                continue
            full = os.path.join(base, entry)
            if not os.path.isfile(full):
                continue
            hit = next((cat for cat, rx in RULES if rx.search(entry)), None)
            if hit:
                plan[hit].append((full, os.path.join(DOCS, hit, entry)))
            else:
                unmatched.append(full)

    for cat in sorted(plan):
        print(f"  {cat}: {len(plan[cat])}")
    print(f"  UNMATCHED (stay put): {len(unmatched)}")

    if not apply:
        print("dry-run — pass --apply to execute")
        return

    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    with open(MANIFEST, "a", encoding="utf-8") as mf:
        mf.write(f"## {date.today().isoformat()} {SRC_DIRS}\n")
        moved = 0
        for cat in sorted(plan):
            os.makedirs(os.path.join(DOCS, cat), exist_ok=True)
            for src, dst in plan[cat]:
                if os.path.exists(dst):
                    print(f"  SKIP (exists): {dst}")
                    continue
                shutil.move(src, dst)
                mf.write(f"{os.path.relpath(src, HOME)}\t{os.path.relpath(dst, HOME)}\n")
                moved += 1
        print(f"moved {moved}; manifest: {MANIFEST}")

if __name__ == "__main__":
    main()