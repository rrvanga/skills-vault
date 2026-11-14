# GitHub Copilot — AI Credits system (verified from live docs, 2026-08-11)

The old "premium requests" model is gone. All Copilot usage now bills in **GitHub AI Credits**: 1 credit = $0.01 USD. Tokens (input / cached input / output) are priced per model, converted to credits.

## Plan allowances (per user/month, pooled at billing entity)

| Plan | Credits/user/mo | Promo (Jun 1 – Sep 1 2026) | Seat price |
|---|---|---|---|
| Copilot Business | 1,900 | 3,000 | $19 |
| Copilot Enterprise | 3,900 | 7,000 | $39 |

- Pool resets to full at 00:00:00 UTC on the 1st of each month. **No carryover.**
- Adding seats mid-cycle grows the pool immediately; removing seats shrinks it next cycle.
- Individual plans (Free/Pro/Pro+/Max) have their own allowances — see "Usage-based billing for individuals" doc.

## Billed vs free

- **Billed in credits:** Chat, Copilot CLI, cloud agent, Copilot Spaces, Spark, third-party coding agents.
- **FREE & unlimited on paid plans:** code completions + next-edit suggestions.
- **Utility models (free, not billable, not selectable, per-user rate-limited):** GPT-4o mini, GPT-4o, GPT-4.1, GPT-5.4 nano — power commit messages, session titles, background features.

## Overage & budgets

- "Additional usage" (metered overage past the pool) is **enabled by default**; admin must disable the "AI credits paid usage" policy for a hard stop.
- Budget controls (all work together):
  - **User-level budget** — hard stop; caps a user across pool + metered; $0 blocks immediately. Precedence: individual > cost-center > universal.
  - **Cost-center budget** — caps metered charges for a group AFTER pool exhaustion; doesn't limit pool draws. Separate from "included usage controls" (cap a cost center's pool draw).
  - **Enterprise spending limit / org-level budget** — cap total metered charges.
- Budgets in USD: $10 budget = 1,000 credits.
- **No automatic fallback to cheaper models** when a budget exhausts — usage just blocks.
- Pool = shared org resource: one power user can drain it. Costs: Business license = 1,900 credits toward a cost center's included-usage cap; Enterprise = 3,900.

## Model pricing (per 1M tokens, USD)

Credits = price × 100. "cached" = cached input; long-context tiers double input price past the threshold; GPT-5.6 Sol/Terra/Luna and all Claude models add a **cache-write** cost.

### OpenAI
| Model | Tier | Input | Cached | Cache write | Output |
|---|---|---|---|---|---|
| GPT-5.6 Luna | Lightweight | $0.20 | $0.02 | $0.25 | $1.20 |
| GPT-5.4 nano | Lightweight | $0.20 | $0.02 | – | $1.25 |
| GPT-5 mini | Lightweight | $0.25 | $0.025 | – | $2.00 |
| GPT-5.4 mini | Lightweight | $0.75 | $0.075 | – | $4.50 |
| GPT-5.3-Codex | Powerful | $1.75 | $0.175 | – | $14.00 |
| GPT-5.6 Terra | Versatile | $2.00 | $0.20 | $2.50 | $12.00 |
| GPT-5.4 | Versatile | $2.50 | $0.25 | – | $15.00 |
| GPT-5.6 Sol | Powerful | $5.00 | $0.50 | $6.25 | $30.00 |
| GPT-5.5 | Powerful | $5.00 | $0.50 | – | $30.00 |

### Anthropic
| Model | Tier | Input | Cached | Cache write | Output |
|---|---|---|---|---|---|
| Claude Haiku 4.5 | Versatile | $1.00 | $0.10 | $1.25 | $5.00 |
| Claude Sonnet 51 | Versatile | $2.00 | $0.20 | $2.50 | $10.00 |
| Claude Sonnet 4 / 4.5 / 4.6 | Versatile | $3.00 | $0.30 | $3.75 | $15.00 |
| Claude Opus 4.5 / 4.6 / 4.7 / 4.8 / 5 | Powerful | $5.00 | $0.50 | $6.25 | $25.00 |
| Opus 4.8 fast mode, Claude Fable 5 | Powerful | $10.00 | $1.00 | $12.50 | $50.00 |

### Google & others
| Model | Tier | Input | Cached | Output |
|---|---|---|---|---|
| Gemini 3.1 Pro (preview) | Powerful | $2.00 | $0.20 | $12.00 (long ctx >200K: 4.00/0.40/18.00) |
| Gemini 3.6 Flash | Versatile | $1.50 | $0.15 | $7.50 |
| Gemini 3.5 Flash | Lightweight | $1.50 | $0.15 | $9.00 |
| Raptor mini | Versatile | $0.25 | $0.025 | $2.00 |
| MAI-Code-1.1-Flash | Lightweight | $0.20 | $0.02 | $1.20 |
| MAI-Code-1-Flash | Lightweight | $0.75 | $0.075 | $4.50 |

## Copilot code review — hidden cost

- Model is **auto-selected and not disclosed** → per-token cost varies.
- Billed **twice**: AI credits (tokens) + GitHub Actions minutes (agentic infra). Actions minutes attribute to the repo/enterprise/cost center; credits charge the requester or PR author's seat.
- Track via Actions metrics filtered by `copilot-pull-request-reviewer` workflow.

## Copilot CLI cost levers

- `/model` or `--model` to switch models; credits consumed per interaction based on model + tokens.
- **Context size & reasoning level** are configurable on extended-capability models: larger context window or higher reasoning = more tokens = more credits. GitHub's own advice: **default context + default reasoning, upgrade only for complex tasks.**
- Auto-compresses conversation history at 95% of the token limit (background, doesn't interrupt).
- **BYO provider:** `COPILOT_PROVIDER_BASE_URL`, `COPILOT_PROVIDER_TYPE` (`openai`|`azure`|`anthropic`), `COPILOT_PROVIDER_API_KEY`, `COPILOT_MODEL` — works with Ollama/vLLM (openai type), local = zero credits. Model must support tool calling + streaming; ≥128K context recommended.
- Approval control: `--allow-tool` / `--deny-tool`, `/allow-all`, `/yolo`; sandboxing via local/cloud sandboxes.

## Client version minimums (for correct pricing/usage display)

VS Code ≥1.120 · VS 2022 17.14.33 · VS 2026 18.6.0 · SSMS 22.6 · JetBrains plugin ≥1.9.1 · Eclipse 0.18.0 · Xcode 0.50.0 · Copilot CLI ≥1.0.48

## Doc URLs (fetched 2026-08-11, all HTTP 200)

- Plans: `/en/copilot/about-github-copilot/plans-for-github-copilot`
- Org billing: `/en/copilot/concepts/billing/usage-based-billing-for-organizations-and-enterprises`
- Pricing: `/en/copilot/reference/copilot-billing/models-and-pricing`
- Budgets: `/en/copilot/concepts/billing/budgets-for-usage-based-billing`
- Utility models: `/en/copilot/concepts/models/utility-models`
- CLI: `/en/copilot/concepts/agents/copilot-cli/about-copilot-cli`
