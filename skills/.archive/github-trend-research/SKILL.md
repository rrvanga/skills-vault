---
name: github-trend-research
description: Find hot GitHub niches; check saturation before proposing.
version: 1.0.0
author: hermes-curator
license: MIT
metadata:
  hermes:
    tags: [github, research, ideation, trends, saturation]
    related_skills: [web-data-extraction, web-price-research]
---

# GitHub Trend Research

Research what's actually hot on GitHub and find open lanes for a new project. The
goal is a *decisive* recommendation backed by numbers, not vibes.

## When to use
- User wants a new project idea that maximizes GitHub visibility / star potential
- User asks "is this niche already crowded?" before committing to a repo
- "What's trending on GitHub right now" questions

## Workflow

1. **Pull trend data from two angles in parallel** (both hit `gh api search/repositories`):
   - NEW repos: recently created but already collecting stars → signals the *next* wave
   - ACTIVE hot repos: recently pushed AND big star count → signals sustained demand
   - Optional third source: scrape the GitHub trending page (curl + verify it's real HTML, not a bot-flag decoy)
2. **Parse JSON to a compact table with Python** (repo name, stars, language, description, topics, last-push date). Do NOT dump raw JSON into context.
3. **Identify themes**, then **saturation-check every candidate niche** before recommending (see below).
4. **Deliver ONE concrete, decisive recommendation** — name + one-liner + why it wins the user's goals.

## Commands

```bash
# NEW repos: created in last 45 days, already 100+ stars
gh api -X GET search/repositories \
  -f q='created:>2026-06-30 stars:>100' \
  -f sort=stars -f order=desc -f per_page=50

# ACTIVE hot repos: pushed in last 30 days, 1000+ stars
gh api -X GET search/repositories \
  -f q='pushed:>2026-07-15 stars:>1000' \
  -f sort=stars -f order=desc -f per_page=50
```

Save payloads to `/tmp/<dir>/`, then parse with a small Python script that prints
`stars | lang | pushed | full_name` plus description and topics.

## Saturation heuristic (the core of the method)

For each candidate niche, run `gh api search/repositories -f q='<niche>'` and read:

- `total_count` — how many repos match. **< ~100 = open lane.** **> ~100k = crowded.**
- **top repo's star count** — if the #1 result is a solo tool with <10k stars, there's room. If it's a celebrity/mega-org repo, you're a small fish.

**Proven-demand + thin-supply = best bet.** Proof of demand = an existing repo with
meaningful stars answering the same question. Thin supply = low `total_count` for the
curated/awesome-list version of that niche. Where they intersect is the open lane.

## Pitfalls

- **Verify scraped HTML is real** before trusting it: grep for actual repo `href="/owner/name"` patterns and a sane `<title>`; check for bot/Cloudflare markers. A 200 + big byte count can still be a decoy page.
- **This machine's display quirk**: long terminal/`read_file` output collapses to `1 lines`. Write parse results to a `/tmp` file, then `read_file` it (with a low limit). Do the aggregation in code, not in context.
- **Don't end in an option menu.** After research, give the user ONE concrete recommendation. This user answers "all" / "just give me an idea" when presented a long clarify list — they want a decisive pick they can react to, not another round of choices.

## Verification
- Confirm every claim is from live API data, not recollection.
- Confirm the saturation numbers (`total_count` + top-repo stars) for the niche you recommend before presenting it.

## References
- `references/2026-08-trend-landscape.md` — the specific queries and niche findings from the research session (agent-skills saturation, local-LLM open lane, etc.)
