# Classification rules, heuristics & research recipes

## Domain folder rule table (worked example, 2026-08)

`(category, regex)` pairs, matched case-insensitive over real filenames. Unknowns
stay put — never guess a home for something you can't classify.

| Folder | Catching patterns |
|---|---|
| Taxes | `tax\|1099\|shoonya\|w2\|property card\|employ.*income\|income.*employ\|2025 taxes\|^employment\.` |
| Identity | `sin number\|pr card\|passport\|driv\|dlback\|dlfront\|icbc\|immigrat\|i-94\|i-20\|travel\|ircc\|visa\|documentation_[0-9]{4}` |
| Legal | `offer\|welcome\|cover letter\|resume\|professional summary\|reference\|megaport\|owl\|hr request\|senior backend\|addendum` (career side) + `p14\|deed\|spa\|insurance\|consent\|ozone\|movein\|rental\|waiver\|master lease` |
| Education | `attestation\|issbc\|ielts\|transcript\|degree` |
| Personal | `img_\|dk.jpg\|dp.jpg\|photos\|prints` |
| Study | `leetcode\|progression\|spaced_repetition\|book1\|qa\.xlsx\|intro\|sedgewick` |
| Notes | desktop `notes[12]\|summary.txt` (scope to Desktop only) |

Pitfalls baked into the rules:
- Regex needs `[ _]?` tolerance: `Offer Letter` vs `Offer_letter` (underscore).
- Same-name-different-content files are NOT duplicates — sha256 first, suffix with
  an honest tag (`(variant)`), never `(older)` without mtime proof.
- Hidden debris: `.~lock.*#` (LibreOffice locks of already-moved docs) → `gio trash`,
  never filed. `.directory` (DE metadata) → leave.

## Identifying mystery files (the funnel)

1. `file <f>` — magic type
2. `pdfinfo <f>` — Title/Author/Subject metadata often names the document
3. `pdftotext <f> - | head` — text layer present?
4. `pdfimages -list <f> | head` — embedded images ⇒ image-only scan
5. `bash scripts/identify_scans.sh <f>...` — 300 DPI render + tesseract, first
   ~300 chars/page (psm 3; retry psm 6/11 if garbled; upscale 3× if still garbage)

Real-world tells seen in the 2026-08 session (one glance at OCR text settled each):
- `4562274243`-style numbers → insurance/bank ID cards (GEICO policy numbers)
- `661505...` + "Protected when completed" → IRCC immigration forms (application #)
- `ViewFile.pdf` → government driving-record abstract
- "Sign.com Document ID … Sign ID …" → Docusign-signed docs
- "Cluster Ozone Consent / Waiver for Use of Amenities" → amenity waivers
- "Documentation_2021_22" pack = license + I-20s + I-94 (US-era immigration evidence)

## Dedupe philosophy

- Group by `(size, sha256)` across the organized folders + leftover roots; report
  groups with >1 copy; propose ONE survivor per group (canonical home wins).
- Files identical except name suffix (`-1`, `_1`, `-2`) are twins.
- Trash extras with `gio trash` (XDG = undoable), log `~/backups/trash-manifest-<date>.txt`.
- Near-dups (same family, different hash — e.g. full policy vs rental-insurance
  rider) are NOT duplicates; flag them, let the user decide.
- Honest framing: dedupe is usually tidiness, not space (10.8 MiB on 176 files).

## Popularity research recipe (which tool does "everyone" use?)

- GitHub search API (unauthenticated OK): `api.github.com/search/repositories?q=<topic>&sort=stars&order=desc&per_page=5`.
  Pipe to `python3 -c 'import json,sys;…'` — **jq may be absent** (a silent `| jq`
  failure masquerades as "API down"; check raw output first).
- Bot-walled from curl: DDG HTML (captcha), Bing (consent wall), Brave (JS shell).
  Don't fight them — go straight to authoritative pages: Arch Wiki
  (`wiki.archlinux.org/title/…`), project docs, dotfiles.github.io.
- Result hierarchy that holds: XDG Base Directory = the standard; chezmoi = most-
  starred dotfile manager (21.2k★ vs yadm 6.4k); xdg-ninja = the $HOME auditor.

## Session outcome (2026-08-21, reference state)

- ~90 Downloads items → 0; Desktop 13 → 0; home root 0 loose files; 107 files in
  8 Documents/ domain folders; paru(652M)+yay(93M) → ~/builds-archive; video → ~/Videos.
- 13 dup groups (176 files scanned) → 15 files trashed, 1 consolidated, 1 variant-renamed.
- chezmoi v2.72.0 → ~/.local/bin, 7 dotfiles, commit `85ad54f`.
- Manifests: `~/backups/org-manifest-2026-08-21.txt` (111 lines), `~/backups/trash-manifest-2026-08-21.txt`.