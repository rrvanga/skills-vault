---
name: research-synthesis
description: Use when digesting research or expanding a research doc/PR.
version: 1.1.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [research, synthesis, digests, trends, attribution]
    related_skills: [content-repo-curation, github-trend-research, web-data-extraction]
---

# Research Synthesis

Turn multi-source research (web extracts, subagent reports, benchmarks) into a human-readable
deliverable: a digest answer, a doc section, or a live PR update. This user reads syntheses
for the RESEARCH, never for the agent's process.

## When to Use

- "What did you learn" / "summarize the research" — digest requests on completed research.
- Expanding or updating a research/trends doc with new findings (incl. mid-PR additions).
- Answering "why doesn't the doc cover X" — scope-and-evidence framing, primary-source check.

## Digest discipline (user preference — non-negotiable)

- "What did you learn" / "summarize the research" = digest the RESEARCH into plain language.
  NEVER narrate the agent's own process, tool calls, or "learnings from doing the work".
  The user rejected exactly that once: a 3-layer answer about how the agent worked was
  wrong shape; the accepted form was a plain translation of the findings themselves.
- Working pattern: re-read the committed artifact (doc/report) first, then deliver a
  plain-language translation that tracks the artifact's structure and content exactly.
- Signal over noise: synthesize from multiple high-quality sources; ignore generic fluff.
- Framing for "why doesn't the doc cover X": answer in two halves — SCOPE (why the gap
  exists in the artifact's structure/selection) and EVIDENCE (what the primary source
  actually ships). Live-extract the source before answering; never hand-wave.

## The people layer — one required research axis

- Engineering-trend docs drawn only from vendor/engineering sources (Anthropic, LangChain,
  OpenAI, FinOps, OTel) map the STACK, not the ECOSYSTEM. "Trending skills / who's teaching
  this" lives in a NEVER-POLLED layer: creators/educators (aihero.dev, totaltypescript.com).
- Before answering a "trending skills" class question, web_extract the educator's own site
  and report what they're actually shipping (skill catalog, courses, cohort stats).
- Meta-trend heuristic: when enterprise patterns condense into installable skills + cohort
  courses, that's a leading adoption-chasm signal — the discipline crystallized enough to teach.
- Structural observation: one-command-install, AGENTS.md-driven skills (e.g. AI Hero's 25)
  are the same model as this machine's SKILL.md vault — the pattern is industry-validated.

## Attribution & verification

- Publisher self-reported figures (learner counts, org counts) go into the doc WITH live
  source attribution and a `[unverified]` marker per doc convention — never as verified facts.
- Spot-verify every load-bearing stat from a primary source before committing it.
- Quote only programmatically-confirmed counts (re-read script stdout).

## Folding new findings into an open docs PR

- Same branch, new commit (no second PR). Stage ONLY the doc; never `.review/` or notes.
- Refresh the PR body to match: swap/extend numbered items + reading recs, then
  `gh pr edit <N> --body-file <file>` (never inline).
- Verify pickup via API before the review gate: `gh pr view <N> --json state,commits,files,body`
  — confirm commit count, changed-file list, and body text.
- Run the MOA/review gate on the FULL diff AFTER the last fold-in commit, then
  `gh pr merge --squash` only on user go-ahead.

## References
- `references/ai-hero-skills-landscape.md` — concrete evidence bank from the 2026-09-01
  educator-layer research: AI Hero figures, curriculum-to-pattern mapping, source URLs.