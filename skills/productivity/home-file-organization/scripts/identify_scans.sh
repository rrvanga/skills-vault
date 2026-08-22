#!/bin/bash
# identify_scans.sh — identify image-only PDFs by OCR-ing the first chars of each page.
# Usage: bash identify_scans.sh file1.pdf [file2.pdf ...]
# Needs: poppler-utils (pdftoppm/pdfinfo/pdftotext/pdfimages), tesseract (eng).
# Tips: psm 6/11 if page text is garbled; upscale renders 3x for faint scans.
WORK=$(mktemp -d /tmp/scanid.XXXXXX) || exit 1
trap 'rm -rf "$WORK"' EXIT
for f in "$@"; do
  [ -f "$f" ] || { echo "skip (not a file): $f"; continue; }
  echo "========== $f ($(stat -c %s "$f") bytes)"
  pdfinfo "$f" 2>/dev/null | grep -E '^(Title|Author|Subject|CreationDate|Pages)' | sed 's/^/  /'
  echo "  text layer: $(pdftotext "$f" - 2>/dev/null | tr -d '[:space:]' | wc -c) chars"
  base=$(basename "$f" | tr -cd '[:alnum:]')
  pdftoppm -r 300 -png "$f" "$WORK/$base" 2>/dev/null
  n=0
  for p in "$WORK/$base"*.png; do
    [ -e "$p" ] || continue
    n=$((n + 1))
    echo "--- page $n:"
    tesseract "$p" stdout --psm 3 2>/dev/null | tr -s '\n ' ' ' | head -c 300
    echo
  done
done