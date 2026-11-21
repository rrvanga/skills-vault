---
name: canada-personal-finance-planning
description: Audit/review the user's CA/BC finance-plan docs.
---

# Canada/BC Personal-Finance Plan — Review & Maintenance

<REDACTED>'s CA/BC finances are run from a small set of interlocking markdown/CSV/xlsx docs across two trees, plus kanban/cron artifacts. This skill maps them and defines the audit procedure for coverage and review questions ("did you take X into account?"). Always plan first and get approval before editing any plan doc (design-first); audits are read-only.

## Doc tree

- Vault entry (start here): `~/obsidian-vault/Research/` — `Canada-BC-Master-Financial-Plan-2026.md` (summary + index), `Couple-Finance-Framework-2026.md`, `Couple-Finance-Tracker-2026.md`, `Canada-BC-Personal-Finance-Tax-Reference-2026.md`.
- REAL detail lives in `~/Documents/Personal/`: `bc-financial-action-plan.md` is the master action plan the vault file summarizes; also `financial-foundation.md`, `bc-cost-of-living-budget.md`, `canadian-investment-retirement-plan.md`, `debt-emergency-strategy.md`, `bc-goal-tracker.csv` (rolling, goal status), `spending-tracker-template.csv`.
- Couple-finance workbook: `~/Documents/Finance/Couple-Budget-Tracker-2026.xlsx` (4 sheets) + its tracker spec JSON.
- Delivered reports: kanban board task runs (root task "Finances with wife", child research/decision/tracker tasks; `task_runs.summary` holds the final-report text that went to the user's chat) and `~/.hermes/cron/output/<job>/` markdown handoffs. Cron-driven review cadence; report only on abnormal.
- The vault summary file is an entry point that can lag the master; the master action plan is source of truth for numbers and named institutions.

## Coverage-challenge procedure ('did you take X into account?')

1. Grep X case-insensitively across BOTH trees: `grep -rin "X" ~/obsidian-vault/Research ~/Documents/Personal`. A single-tree search gives a false negative — the vault summary may name something the master doesn't or vice-versa. Also search the other plan/strategy docs, not just the plan the user seems to be quoting.
2. Check what was actually DELIVERED, not just what is on disk: grep kanban `task_runs.summary` and the gateway log. Challenges usually react to a delivered report, which may abbreviate institutions (e.g. "EQ/WS style") or omit names the source docs carry.
3. Classify every hit as **named-as-candidate** ("X/Questrade", "EQ Bank / X Cash / Tangerine") vs **made-the-default** (no "or"). Listing an institution among options does NOT mean the plan committed to it; state plainly whether X was a candidate or the pick. Candidates-vs-commitment is exactly the distinction these questions probe.
4. Before claiming an exclusion was deliberate, verify the CURRENT numbers on the product's live page — rates/fees change and the doc's bar may be why X lost. Note the page's own "as of" date when disclosed. Never assert a rate/limit from memory in a finance answer.
5. Check adjacent steps for missed consideration: an institution named as the brokerage is often also the natural FX/conversion venue. If the plan routes USD→CAD via a third party (Wise / Norbert's gambit) while naming a brokerage with its own no-FX-fee product, flag that gap explicitly.
6. Answer with exact citations (file + quoted line), then offer a concrete patch for approval. Do not edit docs in the same turn — the user approves diffs first.

## Statement-based spending analysis (the 8-statement workflow)

When the user says they 'already gave you statements', they arrived as Telegram attachments and live in `~/.var/app/org.telegram.desktop/data/TelegramDesktop/tdata/temp_data/` (filenames like `2026-06-29.pdf`, `Jul 31, 2026 - Aug 31, 2026.pdf`, `July_2026.pdf`) — and Hermes also keeps copies in `~/.hermes/cache/documents/` as `doc_<hash>_<name>.pdf`. Hermes' doc cache may be missing the newest one (e.g. the June card dump failed at 08:45). Rebuild from the Telegram temp_data copies with pdftotext -layout: TD card statements parse as `JUN 9 JUN 10 <desc> $59.46` with negatives as `-$250.00`; Wealthsimple as date/desc/amount lines with `–$` prefixes.

- Rent verification pattern: TD chequing debits `DOWNTOWN SUITES RLS` 2,250 monthly (Jun 1 / Jul 2 / Aug 4); a concurrent WS `Withdrawal: Home expense –2,250` can LOOK like a second rent payment but is an internal transfer — it arrives in TD as `WS Investments INV +2,250` the same day. Always cross-check internal transfers across accounts before double-counting.
- Reconcile every statement to its closing balance before quoting totals: TD bank closing balances from the last row with a balance; card statements via `prev + purchases − payments = new`; WS via running balance math.
- $2,850 rent in `bc-cost-of-living-budget.md` is a placeholder — the real rent is $2,250 (verified in statements). Never re-derive the placeholder as fact.

### Pipeline archive (as of 2026-09-06)

User chose **"Not yet — just save the pipeline for later"**: full parse/reconcile/render pipeline archived (cold; no cron, no budget wiring) at `~/Documents/Finance/statements/` — `pdfs/` (8 canonical PDFs), `scripts/` (`rebuild.py` → `rebuild.json`, `analyze.py` → `final.json`, `render_png.py` → `spending-summary.png`), `scripts/dumps/` (text dumps + `parsed.json` the parsers consume), `output/` (last verified run), `README.md` (run sequence + parsing facts). Scripts hardcode `/tmp/stmts/` paths — reactivate by copying back to `/tmp/stmts/` or updating paths. Dependencies: pymupdf, pdftotext -layout, matplotlib Agg. If asked to wire a monthly budget/ritual, approve design first (user is design-first; cron does not exist for this yet).

## Pitfalls

- Auditing only the vault summary for a coverage question misses the real plan — the master action plan in `~/Documents/Personal/` holds the defaults and exclusions; grep both trees before concluding.
- "Wealthsimple/Questrade" style option lists are not "took Wealthsimple into account" to this user: candidates are not commitment. Answer the candidacy question head-on.
- Delivered reports (kanban summaries, cron handoffs) may name fewer institutions than source docs; verify the delivery text when the user challenges a delivered statement.
- Asserting a rate/fee from memory is how false "deliberate exclusion" claims are made; fetch the live product page and note data recency.
- Quote doc lines with PII masked as the docs store them; never expand redacted names in replies.
- Finance answers that change a number must cite where the new figure came from and when it was fetched, so the user can re-verify.
- Per-year kanban cards ("Prepare and file 20XX Canadian tax return") can be deleted mid-run by board cleanup when the GATHER verdict says no filing obligation — `hermes kanban complete` then fails with "unknown id or terminal state". Do NOT resurrect the card or force a completion; the durable close-out is: (1) re-verify the year's slips vs the Prepared memo, (2) annotate `~/Documents/Taxes/submission-record.md` + `README.md` archive change log, (3) report. Never fabricate a CRA confirmation number for a year that needs no return.
