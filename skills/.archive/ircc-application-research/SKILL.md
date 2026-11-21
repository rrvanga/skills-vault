---
name: ircc-application-research
description: Use when researching IRCC application requirements/docs.
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Immigration, Canada, IRCC, Documents, Research, Government]
    related_skills: [ocr-and-documents, pdf, obsidian, canada-personal-finance-planning]
---

# IRCC Application Research → Verified Document Checklist

<REDACTED> is a Canadian PR; IRCC work recurs (spousal sponsorship, open work permit, PR card, later citizenship). The deliverable of this class of task is an item-by-item, checkable document checklist built from IRCC's OWN live pages and the official checklist PDF (IMM 55xx) — never from memory, never from third-party sites.

## When to Use

- The user asks what documents/forms/fees are needed for any IRCC application (spousal or common-law sponsorship, family class, OWP, PR card renewal, citizenship, visitor/super visa).
- The user is mid-application and asks whether an item is required, where to get it, or whether an old/newer version applies.
- Any IRCC question involving a fee amount, processing time, country-specific document rule, police certificate, medical exam, or biometrics.
- Do NOT use for CRA/tax matters (see `canada-personal-finance-planning`) or for generic PDF extraction technique (see `ocr-and-documents`).

## Always-on rules

- **No requirement, form number, fee, or processing time from memory.** Fetch: (a) the official checklist PDF, (b) the application kit page for that stream, (c) the numbered guide (Guide 5289 for spousal), (d) the fees page, (e) the processing-times page. Cite the URL beside each claim. If a number could not be verified, say so and omit it — a wrong fee/date is worse than a gap.
- **Lock the scenario before fetching.** The checklist branches hard on: relationship type, where the couple actually lives (inland Spouse/Common-Law Partner in Canada class vs Family Class from abroad), dependants, sponsor status, applicant's country of citizenship, applicant's current status in Canada, and province (Quebec runs its own undertaking process and skips the sponsor income section). Ask ALL of these in ONE clarify call up front; researching first and asking later throws the whole pass away.
- **Plan first, then act.** State the plan and the source list, then fetch (user is design-first and wants zero-accident, end-to-end delivery).
- **Copy, not original:** IRCC says do not submit originals unless explicitly stated — documents are not returned. Anything not already English/French needs a certified translation plus a certified copy of the original (or a translator's affidavit).
- **Mask PII** in everything written down: record document names and requirements, never the couple's names, passport numbers, or UCI.

## Procedure

### 1. Scenario lock
Decide inland vs Family Class, dependants (yes/no), applicant citizenship, applicant status, province. Only then open the kit.

### 2. Official checklist PDF — the authoritative spine
- Get the current PDF from the live kit page's own link. IRCC republishes with new date-stamped DAM paths, so a URL remembered from a previous session can be stale; the DAM pattern looks like `https://www.canada.ca/content/dam/ircc/documents/pdf/english/kits/forms/imm5533/<MM-DD-YYYY>/imm5533e.pdf`.
- `pdftotext -layout imm5533e.pdf imm5533e.txt`, then condense with `scripts/ircc_forms_extract.py` (drops the per-page footers — `Save Reset Form  Print Form`, `Page N of M`, `IMM 5533 (09-2022) E` — collapses blank lines, keeps original line numbers as grep anchors; ~45 KB / ~700 lines becomes ~386 usable lines).
- Read the condensed text in ONE or two passes, jumping with `--index` (structural headings), `--part A/B/C`, or `--grep <Country>`. Do not page the same PDF through many small reads: each pass re-spends context, and by the last one the earlier findings have been compacted away, so the checklist has to be re-derived.

### 3. Kit page fieldflow — forms list + country-specific requirements
- Kit page for family class: `https://ircc.canada.ca/english/information/applications/spouse.asp`. It is a dynamic "fieldflow": the results block is built by JS only after the reveal button is clicked, so setting dropdown values alone yields an unchanged page (looks like a failed fetch, is not).
- Resolve every select by the TEXT of its option, not by index and not by the hard-coded `wb-auto-NNN` id — those ids are regenerated per render. Then click the control whose label matches `Get checklist and forms`, wait ~6 s, read `document.body.innerText`, write it to a file, and grep the file for `Country specific requirements`. Working pattern is in `references/spousal-sponsorship-inland.md`.
- Three selections drive the family-class result: relationship ("My spouse (and dependent children, if this applies)"), country of residence (Canada), and the separate "Country or territory:" select that produces the document instructions for the country that ISSUED the documents. Country lists hold 200+ entries — match by option text.
- **Country-specific document rules exist only here.** The country-specific-requirements hub page is a pointer, not the content; the per-country instructions (late-registered birth certificates, divorce paperwork, etc.) appear in the generated block on this kit page.

### 4. Fees and processing time
- Fees page (`https://ircc.canada.ca/english/information/fees/fees.asp`): quote the amounts read in THIS session. Structure to convey: one single receipt covers sponsorship fee + application fee + biometric fee; the Right of Permanent Residence Fee is recommended upfront (paying later does not return the application but can lengthen processing); the biometric fee is due at submission; an open work permit carries its own separate fee; Quebec fees are separate and must not be sent to IRCC.
- Processing-time widget renders a number only when EVERY required select is filled (application/class, who is being sponsored, where in Canada you will live, and the "have you already applied?" Yes/No). A partial selection returns `Error 1: … This field is required.` — that is a missing field, not a broken page: find the remaining required select by its option set (the one whose options are Yes/No), set it, re-trigger, then read the block after `Get processing time`.

### 5. Assemble and persist as you go
- Write the checklist to a file section by section as the research lands (vault `~/obsidian-vault/Research/` or `~/Documents/Identity|Legal/`) BEFORE doing more reading. A tool-call cap or a mid-assembly compaction otherwise loses the finished parts and the reply goes out with holes.
- Deliverable format: Part A forms → sponsor documents → applicant/sponsored-person documents → country-specific → biometrics/medical/photo → practical notes. One line per item with the exact form number and name; explicitly mark items that do NOT apply to this scenario together with the reason (e.g. "IMM 1283 not needed: only if the sponsored spouse has a dependent child who has their own dependent child"); flag unverified items as "confirm on the live page" rather than guessing.
- Offer the vault/printable version — user prefers visual, structured artifacts and Obsidian notes.

## Pitfalls

- Setting select values without clicking the reveal button produces a page that looks identical to the previous one; the results block never exists until the click.
- Hard-coded select ids (`wb-auto-NNN`) and positional indexes break between renders — always match option text.
- Reading the same large PDF in many ~100-line passes ends with the early passes compacted out of context; condense once with the script and grep the sections you need.
- The processing-time widget silently withholds the number until all required fields are set; do not report "no processing time available" — fill the last required select.
- Sponsor income proof is not optional paperwork: employer letter (period, salary, regular hours/week) or self-employment financials, PLUS most recent CRA Notice of Assessment (line 15000) or Option C/Proof of Income; if neither exists for the latest tax year, a written explanation plus financial evidence is required. Quebec residents skip this section entirely.
- Incomplete submissions are rejected outright, not just delayed — say so plainly, and tell the user the portal blocks submission until the upload list is complete.

## Supporting files

- `scripts/ircc_forms_extract.py` — condense a `pdftotext -layout` dump of an IRCC form/checklist into line-numbered, footer-free text (`--index`, `--part`, `--grep`).
- `references/spousal-sponsorship-inland.md` — verified spousal/spouse-partner stream detail: form list, sponsor doc set, India country-specific rules, inland class + OWP notes, and the exact kit-page JS recipe.
