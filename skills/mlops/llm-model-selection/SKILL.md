---
name: llm-model-selection
description: Use when choosing or re-tuning which LLM a task should use.
version: 1.0.0
author: hermes-curator
license: CC-BY-4.0
metadata:
  hermes:
    tags: [llm, models, benchmarks, model-selection, routing, opencode-go]
    related_skills: [hermes-config-optimization, evaluating-llms-harness]
---

# LLM Model Selection (task routing + quota-aware re-selection)

## When to Use

Choosing which model to use for a task, re-evaluating default/cron model choices,
or researching model capabilities to justify a routing decision. Trigger words:
"which model", "model selection", "task-specific model", "re-adjust model",
"best model for X".

## The two-axis framework

This user wants model selection re-adjusted **continuously**, never set-and-forget:
1. **Quota-aware** — measure live dollar quota (state.db) + per-model req/5h caps;
   re-pick when a model nears its limit.
2. **Task-aware** — route each task class to the model that actually wins its
   benchmark, not vibes or legacy aliases.

The agent researches + recommends; the HUMAN applies config changes. Do NOT silently
auto-mutate config (user chose the leanest automation: enhance the 07:30 report with a
per-model check + one-line recommendation, no new cron job).

## Research sources (in order of usefulness)

1. **OpenCode Go usage-limits page** (`https://opencode.ai/docs/go/#usage-limits`) —
   the provider's per-model **req/5h / week / month limits** + pricing + model-ID→endpoint
   map, in plain HTML `<table>` (`<tr><td>Model</td><td>req/5h</td>…`). The old `/zen/go`
   page 404s now (moved 2026-08). Caps are promotional ("2×") and changeable — re-fetch,
   don't trust memory: when the boost ended, Flash fell 63,300→31,650 and Luna 4,100→2,050.
   Live model-ID list also at API `/models` (`opencode.ai/zen/go/v1/models`). Recipe +
   live table in `references/opencode-go-live-caps.md`.
2. **Artificial Analysis** (artificialanalysis.ai) — composite Intelligence Index,
   **AA-Briefcase Elo (coding)**, output speed, time-per-task, cost-per-task, MoE size,
   AND the per-benchmark breakdowns (GPQA Diamond, HLE, SciCode, τ³-Banking,
   Terminal-Bench, MMMU-Pro, LiveCodeBench, AIME, GDPval) embedded in the page's RSC
   flight payload — NOT client-fetched. Best task-specific signal. Deterministic recipes
   (JSON-LD + flight-payload) in `references/artificial-analysis-extraction.md`.
3. **LMArena** (arena.ai) — model registry (provider/publicName/displayName/
   capabilities) + category Elo (Coding, WebDev, Creative Writing). Registry is in the
   HTML; the Elo itself is client-fetched (harder to curl).
4. **Hugging Face model-card READMEs** — the vendor's own benchmark tables, fetched
   deterministically via the `/raw/main/README.md` endpoint (e.g.
   `https://huggingface.co/moonshotai/Kimi-K3/raw/main/README.md`; lowercase org works).
   This is the *only* public benchmark source for models that have no AA page and no
   third-party leaderboard entry (code specialists like kimi-k2.7-code). Compare two
   models by their **overlapping** benchmarks (both cards report ProgramBench / MLS-Bench
   / MCP-Atlas), never by a benchmark only one reports. See
   `references/coding-benchmark-research.md`.

## Routing heuristics

- **Default / general**: the balanced workhorse = highest IQ per unit of quota+latency.
  (Aug 2026: DeepSeek V4 Pro — IQ 53.2, 7.15s, 3450 req/5h — beat the flash-candidates.)
- **Hard coding / deep reasoning**: highest composite IQ + coding Elo, but RATION it
  (low req/5h, slow). (Aug 2026: Kimi K3 — IQ 59.7, Briefcase 1540.8 — but 110 req/5h,
  51s reasoning.)
- **High-volume / cron / summarization**: the cheap fast near-unlimited model.
  (DeepSeek V4 Flash, ~31.6k req/5h.)
- **Fast bulk drafting**: fastest + cheapest. (GPT-5.6 Luna: 155 tok/s, $0.047/task,
  2050 req/5h.)
- **Always** cross-check the benchmark winner against its req/5h cap + latency + cost —
  the raw "smartest" model is often the worst choice for interactive/high-volume work.

## Pitfalls

- **"Smart Model" auto-routing does not exist in OpenCode Go.** Config lookalikes are
  Hermes's own `smart_model_routing.enabled: false` and the MoA preset (both
  underperform — MoA aggregator `qwen3.8-max` is 26.9s / 160 req/5h). Keep disabled.
- **Per-model request BURN is not measurable live.** Only dollar quota (state.db) and
  static caps (/go page) are known. Practical re-selection trigger = dollar-quota burn
  rate; caps decide which fallback to pick.
- **AA detail-page slugs are hyphenated** (`/models/glm-5-2`, `/models/qwen3-8-max`,
  `/models/gpt-5-6-luna`); undashed slugs 404 (235KB page). Real detail pages ~3.3MB.
- **Dedicated code models + flash variants have no AA page** (kimi-k2.7-code,
  deepseek-v4-flash, grok-4.5) — and code specialists often have **no third-party
  leaderboard entry either**. kimi-k2.7-code appears only on its own HF model card, which
  reports *in-house* benchmarks only (no SWE-bench / LiveCodeBench / Aider /
  Terminal-bench anywhere) and trails GPT-5.5 / Claude Opus 4.8 on every one of them.
  Get its signal from the HF card and compare *overlapping* benchmarks against the rival:
  kimi-k3 beats kimi-k2.7-code on every shared bench by 8–24 pts (ProgramBench 77.8 vs
  53.6, MLS-Bench-Lite 48.3 vs 35.1, MCP-Mark-Verified 94.5 vs 81.1) — so the newer
  flagship, not the older "code" specialist, wins the coding route. See
  `references/coding-benchmark-research.md`.
- **The AA models index embeds ALL models' composite indices** — the first
  `intelligenceIndex` match is usually the top-ranked model (e.g. Claude Opus), not your
  model. Always filter rows by `detailsUrl`.

## Support files

- `references/artificial-analysis-extraction.md` — deterministic curl + JSON-LD recipe,
  metric keys, hyphenated-slug rule, reusable script shape.
- `references/model-benchmarks-2026-08.md` — dated snapshot of the OpenCode Go lineup
  (composite IQ, coding Elo, speed, latency, cost, size, req/5h) + routing conclusion.
- `references/opencode-go-live-caps.md` — live req/5h·week·month caps + pricing +
  model-ID→endpoint map + extraction recipe (source moved to `/docs/go/` 2026-08).
- `references/coding-benchmark-research.md` — HF model-card README recipe, web-search
  workaround (Bing HTML via curl when DuckDuckGo HTML bot-blocks), and the concrete
  kimi-k2.7-code vs kimi-k3 coding-benchmark head-to-head with verdict.
