---
name: image-data-extraction
description: "Use when reading screenshots: OCR + pixel math, no vision."
version: 1.0.0
author: hermes-curator
license: CC-BY-4.0
metadata:
  hermes:
    tags: [ocr, screenshots, charts, tesseract, PIL, image-analysis, no-vision]
---

# Image / Screenshot Data Extraction (no vision tool needed)

## When to Use

A user attaches a screenshot or image and you must read TEXT (usage rows, dialogs,
error messages) or QUANTIFY a CHART (bar heights, axis values) — but vision
analysis is unavailable, failed to load, or the model cannot view images. The
technique recovers both from tesseract + PIL. Works on text-heavy UIs and simple
cartesian charts; NOT for interpreting photos, diagrams with complex layouts, or
charts where the series colors/paths matter (line-graph shape inference only via
brightness maps).

## Prerequisites

- `tesseract` (system package — `pacman -S tesseract` / `apt install tesseract-ocr`),
  Python `PIL` (`PIL.Image`), standard library only. `pytesseract` NOT required —
  call the CLI via subprocess.

## Method

1. **Text + coordinates (tesseract TSV)** — the key trick: coordinates, not just text.
   ```
   tesseract img.png stdout --psm 6 tsv
   ```
   TSV gives per-word `left top width height` (filter conf > 60). Anchor axis
   labels, dates, legends, and floating labels INSIDE the chart with these boxes.
   Worked calibration: y-axis labels `$4 $3 $2 $1 $0` at y=92/166/241/316/391 →
   75 px per $1; x-axis `Aug 01` at x≈100 with ~36.7 px/day → maps every bar to
   a date. Always cross-check parsed digits against known values (OCR digit errors
   are real: 49,883 vs 4,988) — exact matches on small rows validate the parse;
   mismatches on large rows reveal pricing quirks (e.g. cache-read billing).

2. **Chart bar heights (PIL, no numpy)**
   - Characterize the image first: dump per-row/per-column min-max luminance.
     Dark-mode UIs: bars/area fills are the BRIGHT pixels; gridlines are DIM
     (~40–56 lum). Threshold ABOVE the gridline band (e.g. lum > 60–70) or the
     scan anchors on gridlines in every column.
   - Per column: scan y from the baseline (axis zero line) upward; topmost pixel
     above threshold within a bright RUN (allow ≤3 px gaps for antialiasing);
     exclude single-row spikes at known gridline rows (gridline/bar-top collision).
   - Value = (baseline_y − bar_top_y) / (px per unit). px/unit from adjacent axis
     LABEL centers (labels are stable; gridline pixel rows drift a few px).
   - Cluster adjacent columns into one bar (thin bars may span only a few px).

3. **Layout sanity before clustering**: print a coarse ASCII luminance map
   (` .:+#` classes, ~100×50 grid) to "see" the layout textually. An AREA chart
   (filled line) reads as ONE giant bright region — spot that before trusting
   column clustering.

## Pitfalls

- `convert`/`magick` may be absent — upscale with PIL LANCZOS (`Image.resize(..., Image.LANCZOS)`) before OCR.
- Threshold 30 on a black bg catches faint gridlines everywhere — always measure the image's actual luminance distribution first.
- Tesseract can duplicate label values between adjacent columns; trust label CENTERS, not label counts, for axis calibration.
- Screenshot resolution matters: if OCR is garbage, upscale 3× first, retry psm 6, then psm 11 (sparse) as fallback.

## Worked example (2026-08-15, OpenCode Go dashboard)

Dark-mode SPA at https://app.opencode.ai/usage: measured daily spend from bar
pixel heights — Aug 11 $0.41, Aug 12 $0.40, Aug 13 $0.00 (the freeze day),
Aug 14 $2.40 → monthly ≈ $3.3, far below the $30/wk paid bucket → proved the
freeze was a FREE-tier weekly limit, not paid-bucket exhaustion. Full accounting
conclusion lives in the ai-coding-subscription-limits skill reference
(opencode-go-quota.md).
