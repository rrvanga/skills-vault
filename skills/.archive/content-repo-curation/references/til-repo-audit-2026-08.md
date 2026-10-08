# til repo audit — 2026-08 (12 → 9 entries)

Repo: `~/dev/til` (public `github.com/<REDACTED>/til`). Editorial bar lives in `template.md`:
problem -> what I tried -> what worked -> takeaway; ONE genuinely new thing; no filler.
README rule: "one genuinely new thing, written the day I learned it, no filler."

## Method as applied
All 12 entries read in FULL before any verdict. Verdicts on content, never titles.
Three questions per entry: human-readable prose (not a transcript)? durable & transferable
lesson? filler/redundant with another entry? Public-repo bar: an entry that reads like an
internal work diary (PR numbers, private repo paths, backup listings, live config dumps)
fails for a stranger reader.

## Removed (3) — work-diary entries, via `git rm`
- `2026-08-18-no-orchestrator-in-context-routing.md` — config-inspection TRANSCRIPT: sed/grep
  dumps of a live config; "lesson" is a design stance, nothing a reader can apply.
- `2026-08-21-config-key-written-but-never-read.md` — internal audit log: PR #13, hermes_cli
  paths, timestamped backup names. Audit note, not an article.
- `2026-08-24-verify-generated-doc-claims-against-source.md` — same PR #14 / MOA-gate incident
  AND same verify-against-source lesson family as 08-28; redundant — kept the tighter 08-28.

Restore any with: `git -C ~/dev/til checkout 45638a1 -- til/<file>` (parent of the curation commit).

## Kept (9), one-line why
- 08-14 benchmarking-local-llms-without-a-gpu — transferable reframe: split estimate/harness/source-data layers so hardware never blocks the build.
- 08-16 agent-to-agent-communication — Telegram silently drops bot-to-bot; git-queue pattern + A2A.
- 08-16 silent-thermal-watchdog-linux — sysfs/hwmon technique: match zones by type, test-override trick.
- 08-17 electron-chrome-sandbox-4755 — stat-gated sudo for TTY-less systemd units.
- 08-19 cdn-blocks-html-but-not-json-api — transferable scraping lesson with mock + live proof.
- 08-20 fail-closed-when-nothing-to-scan — gate exit codes so "nothing to scan" fails loudly.
- 08-26 scheduled-commit-lands-on-checked-out-branch — cron commits to whatever branch is checked out.
- 08-27 oem-only-cpu-sku-three-spec-databases — research method: 3 agreeing sources, real dead ends.
- 08-28 one-capture-not-a-format-change — strongest of the verification cluster, after light revise.

## Kept-with-revision
- 08-28: opening rewritten lesson-first; PR #14 / agent-lab framing removed (saga -> lesson).
- 08-20: tags backticked to match template exactly.

## Verification used
Delete rows + sweep leftover blank lines in README table; count programmatically
(`ls til/` = 9, `grep -c '^| 2026-' README.md` = 9, grep removed slugs = 0, `git status` clean).