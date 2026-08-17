---
name: diagram-rendering
description: Use when rendering diagrams/posters to PNG (HTML+Chromium).
version: 1.0.0
author: Nous Research
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [diagram, png, chromium, pillow, rendering, chart, poster]
    category: productivity
    related_skills: [pdf]
---

# Diagram & Poster Rendering (HTML → Chromium → Pillow)

Render visual deliverables — architecture diagrams, posters, charts, dashboards — to a PNG on a machine with **no** dot/graphviz/matplotlib/ImageMagick/wkhtmltoimage. Plain HTML+CSS rendered headlessly to PNG, then verified and cropped programmatically with Pillow. Confirmed working on Arch with `chromium`, `rsvg-convert`, and Pillow.

## When to use
- "add a visual / diagram / poster / chart / dashboard" request.
- Need a versionable PNG asset for a repo, doc, or chat.
- You can't see images, so you need *programmatic* proof the render is correct.

## Pipeline
1. **Content-first.** Collect real facts/config before drawing — the diagram must be grounded, not illustrative. Pull live state (config, DB, job list, processes) at render time so the image stays current.
2. **Write HTML.** ~1380px content width inside a 1400px viewport; light bg `#eef1f6`, white cards, one accent per section; real `<table>` for tabular data; fixed widths; `box-sizing:border-box`; system font stack.
3. **Render oversized, then crop.** Always render at a taller viewport than the content, then strip trailing dead space (see `scripts/render_and_verify.py`):
   ```
   chromium --headless=new --disable-gpu --no-sandbox --disable-dev-shm-usage \
     --hide-scrollbars --window-size=1400,3400 --screenshot=out.png file:///abs/path.html
   ```
4. **Verify blind.** Pillow checks ARE your eyes (you cannot view the image): dimensions sane (>100px), downsampled color census ≥ ~20 distinct colors (not blank), crop trailing uniform-background rows.

## Pitfalls
- **Blind rendering** — never assume the image is right; run the Pillow checks every time.
- **Clipping** — content taller than the viewport silently clips; render oversized and crop, never render exactly.
- **Determinism → commit-on-change.** Do NOT embed timestamps/dates in the rendered HTML/PNG. A timestamp changes every run, so a `git diff --quiet` change-detector commits daily with a mere date bump. Keep the render byte-identical for identical state; let git history record *when*. (Same lesson as the llmcost no-change-day bug.)
- **PII masking (hard rule, user-corrected).** All generated visuals must mask PII: no real names, usernames, emails, hostnames, IPs, chat/user IDs, API-key names/values, token values, or `/home/<user>` paths. Use generic labels ("identity redacted"). Run a targeted grep on the generated HTML for name/email/`/home/`/key patterns before committing.
- **Large HTML payloads** — one huge write can time out; write fragment files and assemble them into one file before rendering.
- **`img.load()` nullable stub** — add `assert px is not None` so Pyright stays clean.

## Keep-it-updated pattern (auto-refresh)
For a diagram that must stay current with live state:
1. Generator script reads live state and renders **deterministically** (no timestamps).
2. A `no_agent` cron runs a thin wrapper (real logic stays in-repo under `~/.hermes/scripts/` → `<repo>/scripts/`): render → `git diff --quiet` on the assets → commit+push **only on change** → silent (exit 0, empty stdout) otherwise. Empty stdout = the cron stays silent (watchdog pattern).

## Support files
- `scripts/render_and_verify.py` — minimal reusable HTML→PNG renderer + blind verify/crop (copy and adapt).
