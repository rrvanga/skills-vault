---
name: career-materials-review
description: Use when reviewing <REDACTED>'s cover letters/resumes.
---

# Career Materials Review

<REDACTED>'s active job-search materials live in `~/Documents/Career` (cover letters as `cover letter - <company>.docx`, resumes as `<REDACTED>*.pdf/.odt/.pptx`). The recurring ask: find all cover letters + the latest resume, analyze patterns, and produce an output folder with exactly 3 docs — (1) tips & tricks, (2) best cover letter, (3) latest resume.

## Procedure

1. **Inventory first — `stat`, never a single glob search.** Build the corpus with `stat -c '%y | %n' cover*.docx cover*.pdf <REDACTED>*.pdf <REDACTED>*.odt <REDACTED>*.pptx Resume-<REDACTED>*.pdf` sorted by time in the source folder. The `search_files` glob is case-sensitive (`*resume*` returned 1 of 12 real resume files) — it is a finder, not a census. `stat` output is the source of truth; record mtimes for recency decisions.
2. **Dedupe before counting.** Expected twins: one letter as .docx + .pdf (same content); the same company under two filenames (earnin vs earn in); a letter copied to another company but never re-tailored (data visor = verbatim EarnIn copy). Count unique letters, not files, and report the dedup explicitly.
3. **Exclude filename false-positives.** `*cover letter*` also matches non-application letters (e.g. `icbc cover letter.pdf` = an insurance dispute letter in Documents/Identity). Note the exclusion; do not analyze it.
4. **Extract text read-only, zero installs.** docx/odt/pptx are ZIP archives — read with stdlib `zipfile` + `xml.etree.ElementTree`; PDF text layers with `pdftotext`. Write one `.txt` per doc to `~/.hermes/cache/scratch/<task>/text/` using underscore-normalized filenames. Full recipe: references/extract-office-text.md. Never write back into the zip — read-only extraction only (see the docx skill's unzip-sed warning).
5. **Analyze patterns, quantified.** Compute structural stats in one execute_code pass (lengths, headers, RE lines, section headings, openings/closings), then read every letter in full. Track: skeleton consistency; recurring achieved metrics (<REDACTED>'s canonical set — $30B+ annual sales, 85M+ users, 99.9% availability, 90% infra cost reduction, $5M/yr licensing savings, 50+ microservices, 8+ teams, 12 developers, MS GPA 4.0 / MBA 3.9); JD-mirroring section headings; per-company tailoring (product/team names e.g. Live Pay, Dentrix Ascend, NYFIX Matching); the local-commitment close ("Vancouver resident, hybrid/on-site"); closing CTA.
6. **Pick the best cover letter on evidence.** Rank by: JD tailoring, product/team specificity, quantified density, structure, freedom from formatting errors. In this corpus the April batch (Broadridge, RBC Staff, Henry Schein) beat the March and June letters; the metrics-free Veeva note ranked last.
7. **Lock the latest resume with two clocks.** Newest by mtime AND by content date. A newer-by-mtime file can be a red herring (`One slider Resume.pptx` = one-page consulting deck with a vendor copyright footer; the canonical resume is the newest PDF). Sanity-check variants with `difflib` similarity — near-duplicate scores (~0.93) mean "same content, older copy". Verify the resume header/contact block matches the cover letters.
8. **Package exactly 3 docs** into `<source>/cover-letter-analysis/`:
   - `1-cover-letter-tips-and-tricks.md` — authored analysis: patterns observed (strengths AND pitfalls, with concrete examples), general online advice, a pre-send checklist, best-letter ranking + runner-ups.
   - `2-best-cover-letter-<Company>.docx` — byte-identical `cp` of the original.
   - `3-latest-resume-<Name>-<YYYY-MM-DD>.pdf` — byte-identical `cp` of the original.
9. **Verify then report.** `sha256sum` both copies against originals (must match byte-for-byte), `ls -la` the folder, confirm originals were never modified (read/cp only). Report: what works / pitfalls flagged (with exact examples) / verdict; offer a follow-up render (PDF/DOCX/visual) without auto-doing it.
10. **Reword for an external audience (aspirant edition) when asked.** If the user says the docs will be sent to someone else (job aspirant, mentee), produce `<source>/cover-letter-analysis/aspirant-edition/` with 3 reworded, fully anonymized docs: (1) generic tips & tricks, (2) a fill-in cover-letter template with per-block annotations (why each element works), (3) a resume template/format guide (XYZ bullet formula, section order). Strip the name, phone, email, LinkedIn, employer names, product/team names, and every canonical metric as a *claim* — <REDACTED>'s numbers may survive only as illustrative examples inside the bullet-formula explanation, never as the aspirant's achievements. Grep the folder for PII and artifact patterns before delivering.
11. **Render the .md set to PDF on request.** No installs: python `markdown` (extensions `tables`, `fenced_code`, `sane_lists`) → HTML wrapper with print CSS → `chromium --headless=new --disable-gpu --no-sandbox --no-pdf-header-footer --print-to-pdf=out.pdf file://<abs-path>.html`. Verify with `pdfinfo` (page count) + `pdftotext` non-empty text layer (copy/ATS-safe). Chromium's `Invalid mime.cache` stderr lines are harmless noise, not failures.

## User conventions

- Read-only analysis of originals; the only new artifact is the output folder; original-derived docs are copies, never edits.
- Quantify everything — metrics, similarity scores, rankings; numbers, not vibes.
- Findings as: what works / pitfalls (exact quoted examples) / verdict; then offer, don't perform, the nice-to-have render.
- The tips doc stays Markdown unless he asks for another format; the two original-derived docs keep their native format.
- Docs destined to be forwarded (aspirant edition, etc.) must be fully anonymized AND must NOT call out the human errors found in <REDACTED>'s letters — reword defects into generic advice ('a classic slip', 'commonly missed detail'), never real-example stories or artifact-level callouts, and never corpus provenance ('17 letters, one candidate').
- PDF conversion of the markdown docs, when asked, uses the headless-Chromium pipeline (step 11) — no package installs, letter-size output, text layer verified.

## Pitfalls

- Corner-count the corpus with `stat`, not `search_files` alone — its globs are case-sensitive and silently undercount mixed-case filenames.
- Count unique letters after dedup — a docx+pdf pair is ONE letter; same content filed under two company names is a copy-paste-across-applications red flag.
- Check the BODY's company name, not just the filename — "letter to company A filed as company B" is a universal-rejection error and the #1 fixable finding in a review.
- Latest file ≠ latest resume — verify content: full career history, generated date, no third-party branding (one-slider decks with vendor footers are consulting collateral, not the canonical resume).
- Extraction globs must match the names you wrote: if you normalized spaces to underscores when writing `.txt` files, glob with underscores; on 0 matches, `ls` the text dir before rewriting the glob.
- Keep extraction runs memory-safe: loop per file and write each `.txt` as you go (a single 5-minute execute_code timeout kills one big batch); re-verify with an `ls` before analysis.
- Never carry corpus provenance or diagnosed errors into docs that will be forwarded — a reference like '17 real cover letters (one candidate)' or an artifact callout (`<REDACTED>`, `" . "`, `Sincerely,Name` 'appeared in several letters') lets a reader infer whose letters they are; the aspirant edition must read as universal guidance.
- PII-scrub before delivering anything the user says he'll send onward — name, phone, email, LinkedIn, employer names, and product names are all identifiers; `grep -inE '<all of them>' <folder>` and confirm zero hits before sending.
