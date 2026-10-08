# AI Hero Skills-Landscape Evidence Bank (2026-09-01)

Evidence gathered while answering "why don't the docs cover trending skills like Matt Pocock"
and folding a "Skills & Learning Landscape" section into `docs/AI_ENGINEERING_TRENDS.md`
(agent-lab PR #18, commit `d3768d3`). All figures below are publisher self-reported —
mark `[unverified]` when quoting into docs, per doc convention.

## Sources (live web_extract 2026-09-01)
- totaltypescript.com + mattpocock.com (17,025 chars)
- aihero.dev (6,575 chars)

## Figure: Matt Pocock / AI Hero
- Pocock: full-time AI-engineering educator; built AI Hero after Total TypeScript (Total
  TypeScript = industry-standard TS course). Ex-XState core team, ex-Vercel developer advocate.
- Self-reported scale: **113,800+ developers learning**, **8,500+ cohort-trained**, **25 free
  installable skills**.
- AI Hero curriculum mirrors the doc's findings:
  - `/to-spec` → `/to-tickets` → `/implement` → `/code-review` = idea→ship agent loop
    (orchestrator-worker + evaluator, packaged as named skills).
  - `/grill-with-docs`, `/research`, `/wayfinder` = prompt-chaining/routing as skills.
  - AGENTS.md guide, plan-mode intro, TDD-with-Claude skills, "never run `/init`" = the same
    verification gates the doc recommends.
  - "AFK agents" (Ralph Wiggum) = bounded autonomy = the doc's #1 reliability rule.
- Waitlist cohort course ("AI Coding for Real Engineers"): context gathering, planning,
  steering, feedback loops, AFK agents, human-in-the-loop review.

## Meta-trend framing (used in the fold-in)
- Enterprise patterns commoditized into installable skills + cohort courses = the discipline
  crystallizing enough to be taught = leading adoption-chasm signal.
- Pocock's one-command-install, AGENTS.md-driven skills are structurally identical to this
  machine's SKILL.md vault model — industry validation of the pattern.
- The gap was real: the trends doc's 4 briefing directives were technical (agentic patterns,
  MCP, orchestration, production reliability) and drew only from the vendor/engineering layer;
  "who's teaching this" lives in the never-polled creator/educator layer.

## Numbers quoted in the fold-in section (all [unverified])
- 113,800+ developers learning
- 8,500+ trained in cohorts
- 25 free installable skills