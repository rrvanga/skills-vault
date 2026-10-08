---
name: content-repo-curation
description: Use when curating TIL/blog/docs repos to the editorial bar.
version: 1.0.0
author: hermes
license: MIT
metadata:
  hermes:
    tags: [curation, til, editorial, repo-hygiene, content]
    related_skills: [github-repo-management, pii-safe-public-publishing]
---

# Content Repo Curation

Audit a repo of articles (TIL entries, blog posts, docs, knowledge base) so it contains only
human-readable, genuinely useful pieces that fit the repo's own editorial standard. This user's
`~/dev/til` (public `github.com/<REDACTED>/til`) grows via a daily cron entry — curation recurs.

## When to Use
- "Clean up / curate my TIL (or blog, docs, articles) repo" — anything asking to keep only
  genuinely useful, human-readable entries.
- Periodic spring cleaning of `~/dev/til` (a daily cron grows it); pruning work-diary or
  redundant entries, especially before a public push.
- Any audit where the verdict must be argued from an editorial standard, not taste.

## Workflow

1. **Find the editorial bar first.** Read `template.md` and `README.md` before touching any
   article. The bar here: problem -> what I tried -> what worked -> takeaway; ONE genuinely
   new thing; no filler; self-contained. A title alone never decides a cut.
2. **Read EVERY entry fully.** Judge on content, never titles. Keep a running scorecard
   (verdict + one-line reason per entry) — it becomes the final report.
3. **Classify with the lesson-vs-diary rubric:**
   - KEEP — transferable lesson, self-contained, prose-first, concrete commands as illustration.
   - REVISE — close but messy: rewrite the opening lesson-first, strip saga framing (PR numbers,
     repo-internal paths, incident chronology a stranger can't follow).
   - REMOVE (work-diary) — reads as session notes, not an article: config-inspection transcripts
     (sed/grep dumps of live config), PR-review post-mortems, internal audit logs with private
     paths, timestamped backup names. Also remove REDUNDANCY: two entries from the same incident
     with the same lesson family -> keep the tighter one.
4. **Public-repo hygiene is part of the bar.** If the repo is public, any entry carrying PR
   numbers, private repo paths, live config values, or usernames fails "human-readable article"
   — it is internal mail, not content. (Related: pii-safe-public-publishing.)
5. **Execute.** `git rm` the cuts (history keeps them — reversible), patch the index
   (README entries table): delete rows AND sweep the blank lines they leave behind. Commit with
   a message naming the count change, e.g. "til: curate to lesson-first articles (12->9)".
6. **Verify — never trust collapsed output.** This env's terminal/read_file results often
   collapse to "1 lines output". Verify with execute_code printing to stdout: count files,
   count index rows, grep removed slugs (want none), `git status` porcelain (want clean).
   Report only programmatically-confirmed numbers.
7. **Report + offer.** Verdict table (kept list w/ why; removed list w/ why), note cuts are
   git-recoverable (`git checkout <parent-sha> -- til/<file>`), and ask before pushing to a
   public remote — this user's content changes are normally MOA-gated.

## Pitfalls
- Deleting a markdown table row via patch leaves an empty line behind — sweep it or the table breaks.
- Don't auto-push: the repo is public and content PRs are gated — commit locally, offer push/PR.
- Revising a kept article: preserve technical facts and voice; only re-frame the opening to lead
  with the lesson and drop the incident's PR/saga context.
- Offer the one-line restore for every cut; deletes are recoverable, so cuts should be decisive.

## References
- `references/til-repo-audit-2026-08.md` — concrete rubric application: the 12-entry audit,
  which entries were removed and why, restore commands, verification used.