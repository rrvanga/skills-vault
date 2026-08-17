---
name: ai-coding-subscription-limits
description: Use when researching AI coding subscription limits/quotas.
version: 1.0.0
author: hermes
license: MIT
metadata:
  hermes:
    tags: [billing, quotas, copilot, opencode, limits, cost-optimization]
    related_skills: [opencode, claude-code, codex, hermes-config-optimization]
---

# AI Coding Subscription Limits & Cost Optimization

## When to Use

Trigger when the user asks about usage limits, quota consumption, plan allowances, per-token pricing, or workflows to stay under budget for AI coding subscriptions — GitHub Copilot (Business/Enterprise/Pro), OpenCode Go, Claude Code, Codex. Classic phrasings: "how much quota did we use?", "did we hit the limit?", "what can we do within our plan?", "optimal workflows within usage limits".

Task class: "how much quota did we use", "what are the limits", "which plan keeps us under budget", "optimal workflows within limits" for AI coding subscriptions — GitHub Copilot Business/Enterprise, OpenCode Go, Claude Code, Codex CLI.

## Core workflow

1. **Always fetch live official docs — never trust memory.** Pricing/limit structures change (GitHub moved from "premium requests" to "AI credits" in 2026; OpenCode Go uses dollar-bucketed limits). Good Copilot doc roots:
   - `https://docs.github.com/en/copilot/concepts/billing/usage-based-billing-for-organizations-and-enterprises` (allowances)
   - `https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing` (per-token tables)
   - `.../copilot/concepts/billing/budgets-for-usage-based-billing`, `.../copilot/concepts/models/utility-models`, `.../copilot/concepts/agents/copilot-cli/about-copilot-cli`
2. **Parse docs pages with python, not grep** (they're nav-heavy; plain text extraction returns sidebar noise):
   - Strip `<script>/<style>` with regex, unescape, split lines; find body start via marker ("In this article" or article title after ~line 400)
   - Pricing tables: `re.findall(r'<table[^>]*>(.*?)</table>', raw, re.S)` then parse `<tr>`/`<td>` cells — line-based text flattening turns tables into a 4-line stub, so table regex is required
   - Find sibling page links with `grep -oE 'href="/en/copilot/[^"]+"'` — doc URLs 404 easily when guessed; always discover, don't assume
3. **Convert tokens → money → credits.** Formula: `(fresh_in_M × pin) + (cached_M × 0.1 × pin) + (out_M × pout)` = dollars; ×100 for credits at 1 credit = $0.01. **Watch the ×100** — a first pass that labels dollars as credits undershoots 100×; sanity-check against a known scenario.
4. **Use realistic session token volumes** or the math misleads: quick chat ≈ 30K in / 5K out; focused agent task ≈ 100K / 20K; multi-file agent session ≈ 400K fresh + 1.5M cached + 60K out (cached input ≈ 10× cheaper than fresh — the main cost lever).
5. **Answer with routing guidance, not just numbers**: which features are free (Copilot completions/next-edit = unlimited), per-model tier cost spread, caching leverage, long-context penalty (≈2× input past threshold), budget controls.

## Pitfalls
- Copilot pools credits org-wide (e.g. 1,900/user/mo for Business) — NOT per-user; one power user drains everyone. User-level budgets hard-stop (a $0 budget blocks immediately); no automatic fallback to cheaper models.
- "Additional usage" overage billing is **enabled by default** past the pool — flag it plus the admin toggle ("AI credits paid usage" policy).
- Promo windows exist (3,000 credits June 1–Sept 1, 2026, then 1,900) — always check the promo dates; model on post-promo numbers.
- Copilot code review billing is opaque: auto-selected model (undisclosed) + GitHub Actions minutes; gate it to important PRs.
- OpenCode Go (`opencode.ai/zen/go/v1`): **$5 first month, then $10/month flat** (NOT free — user pays $10/mo); dollar buckets $12/5h, $30/wk, $60/mo; **free-model fallback after the cap** ("continue using the free models" — likely source of "$0 for go" claims); no public quota API; ground truth is Hermes `state.db` (read-only SQLite), `estimated_cost=$0.0000` for Go so token→$ math is manual. See references/opencode-go-quota.md (full per-model rate table).

## References
- `references/github-copilot-billing.md` — full 2026 Copilot AI-credits system: plan allowances, complete model pricing tables (OpenAI/Anthropic/Google/others), budget hierarchy, CLI cost levers, client version minimums.
- `references/opencode-go-quota.md` — OpenCode Go limits, state.db query pattern, per-model rates, report scripts.
