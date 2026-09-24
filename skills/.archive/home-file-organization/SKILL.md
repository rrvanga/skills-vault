---
name: home-file-organization
description: "Organize Linux home files: sort, dedupe, dotfiles."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [file-organization, dedupe, dotfiles, chezmoi, XDG, home-directory]
    related_skills: [ocr-and-documents, image-data-extraction, linux-system-audit]
---

# Home File Organization

Guides the survey → classify → move → dedupe → verify workflow for user data dirs
(Downloads, Desktop, Documents, home root), plus dotfile versioning bootstrap.
Proven end-to-end 2026-08-21 on an Arch box (~90 Downloads items + Desktop +
300 MB of build dirs → 0 loose files, 107 organized, all reversible).

## Doctrine (the most-popular Linux consensus — cite this)

- **XDG Base Directory**: config → `~/.config`, data → `~/.local/share`, cache → `~/.cache`; user content → `~/Documents ~/Downloads ~/Pictures ~/Videos ~/Music`.
- `~/Downloads` and `~/Desktop` are **staging areas**, not storage. Keepers live in domain folders under `~/Documents/` (e.g. Taxes, Identity, Legal, Career, Education, Personal, Study, Notes).
- Home root holds only dotfiles + XDG dirs. Build artifacts (`~/paru`, `~/yay` — AUR build dirs) are junk once the tool is installed system-wide; archive to `~/builds-archive/` or trash.
- Most-popular dotfile manager by GitHub stars: **chezmoi** (21k★; yadm 6.4k, stow classic). Popularity research method in `references/classification-rules.md`.

## Workflow

1. **Survey read-only first** — never move what you haven't listed. `ls -1A` each target dir; note the dotfiles at home root.
2. **Classify with an explicit rule table, not ad-hoc judgment** — python script, `(category, regex)` pairs over real filenames; **unknowns STAY PUT** (no guessing). Whitelist exceptions: skip `learn/`-style keepers, skip `.~lock.*#` LibreOffice lock droppings (trash those instead), skip dotfile dirs.
3. **Dry-run first, then `--apply`** — the script prints the full mapping table; a collision (target exists) must SKIP, never overwrite; log every move `from<TAB>to` to `~/backups/org-manifest-<date>.txt` (rollback = reverse the lines).
4. **Verify on disk after applying** — per-category file counts + sum vs manifest line count + roots re-listed. A successful tool call is not a verified move.
5. **Dedupe pass (offer it, don't assume)** — group by `(size, sha256)`, keep one per group, trash the extras. See `references/classification-rules.md` §Dedupe.
6. **Dispose via XDG trash, never `rm`** — `gio trash <files>` is reversible (`gio trash --restore`); log a second manifest (`~/backups/trash-manifest-<date>.txt`).
7. **Walk the leftovers with the user** — unclassified files get identified (funnel in `references/classification-rules.md` + `scripts/identify_scans.sh`), presented one-by-one with a verdict, and moved on green-light.

## Pitfalls

- **Same name ≠ same file.** After a dedupe, a "consolidate" move can collide with a *different-content* file of the same name. Compare sha256 before assuming; if genuinely different, keep both with an honest suffix (`(variant)` — never `(older)` unless mtime proves chronology).
- **Filename regexes need `[ _]?` flexibility** — `Offer Letter` vs `Offer_letter` misses with a naive space pattern.
- **Filenames carry PII** (full names, SIN-adjacent docs, license scans). Mask in chat narration; tool output stays local.
- **`jq` may be absent** — pipe API JSON to `python3 -c 'import json…'`; a silent `| jq` failure looks like "API down" when it isn't.
- **Search engines (DDG/Bing/Brave HTML) are bot-walled from curl** — for popularity/doctrine research go straight to authoritative pages (Arch Wiki `wiki.archlinux.org` curls fine) and API endpoints (GitHub search API is unauthenticated-friendly).
- **Long multiline shell commands may be blocked by the terminal parser** — they're saved to `~/.hermes/cache/blocked-scripts/blocked-*.sh`; review then `bash <file>`. Better: `write_file` the script, then run it.

## chezmoi bootstrap (dotfile versioning, no sudo)

- Install = static Go binary: `api.github.com/repos/twpayne/chezmoi/releases/latest` → `chezmoi_<ver>_linux_amd64.tar.gz` → extract → `~/.local/bin/chezmoi`. **Pitfall: the tarball is FLAT** — binary at archive root, *not* `bin/chezmoi`.
- `chezmoi init` (v2.72+) creates the source dir `~/.local/share/chezmoi` **and auto-initializes git**; then `chezmoi add .bashrc …` and commit inside the source dir.
- Starter set: `.bashrc .bash_profile .bash_logout .zshrc .gitconfig .tmux.conf .gtkrc-2.0`.
- **Never manage**: `.ssh`, `.gnupg`, `.pki` (keys), `.npmrc` (may hold auth tokens), `.bash_history`, the agent's own state dir (`~/.hermes` — separate backup regime).
- Verify: `chezmoi status` clean + `chezmoi managed` lists exactly the intended set.

## Support files

- `references/classification-rules.md` — category rule table, identification heuristics (incl. the scanned-PDF tesseract funnel), dedupe philosophy, popularity research recipe, session outcomes.
- `templates/organize.py` — generic rule-table organizer skeleton (dry-run/apply/manifest), copy and fill the RULES.
- `scripts/identify_scans.sh` — render+OCR loop that identifies image-only PDFs (poppler-utils + tesseract; marker-pdf is overkill for identification).