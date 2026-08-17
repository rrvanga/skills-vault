# OpenCode Go lineup — benchmark snapshot (2026-08-14)

Source: Artificial Analysis detail pages + OpenCode Go `/go` page. **Values drift fast —
re-fetch before citing.** Keep this as a dated anchor, not a live truth.

## Composite intelligence (AA Intelligence Index, ~0–100)

| Model | IQ |
|---|---|
| Kimi K3 | 59.7 |
| Qwen3.8 Max | 58.1 |
| DeepSeek V4 Pro | 53.2 |
| GLM-5.2 | 52.6 |
| GPT-5.6 Luna | 52.3 |
| MiniMax-M3 | 45.4 |

## Coding (AA-Briefcase Elo)

| Model | Elo |
|---|---|
| Kimi K3 | 1540.8 |
| Qwen3.8 Max | 1420.1 |
| GLM-5.2 | 1251.9 |
| MiniMax-M3 | 1106.7 |
| DeepSeek V4 Pro | (no AA data) |
| GPT-5.6 Luna | (no AA data) |

## Speed & time-per-task

| Model | output tok/s | time/task (s) |
|---|---|---|
| GPT-5.6 Luna | 155.3 | 2.12 |
| GLM-5.2 | 107.4 | 6.06 |
| MiniMax-M3 | 82.8 | 5.10 |
| DeepSeek V4 Pro | 78.4 | 7.15 |
| Qwen3.8 Max | 47.1 | ~10.6 answer / 42.4 reasoning |
| Kimi K3 | 39.1 | ~12.8 answer / 51.2 reasoning |

## Cost per intelligence task (USD)

GPT-5.6 Luna 0.047 · MiniMax-M3 0.14 · DeepSeek V4 Pro 0.25 · GLM-5.2 0.32 ·
Kimi K3 0.84 · Qwen3.8 Max 1.13

## MoE size (active / total params, billions)

MiniMax-M3 23/405 · GLM-5.2 40/713 · DeepSeek V4 Pro 49/1551 · Kimi K3 104/2696

## OpenCode Go per-model req/5h caps (promotional "2×" — changeable)

| Model | req/5h |
|---|---|
| DeepSeek V4 Flash | 63,300 |
| GPT-5.6 Luna | 4,100 |
| DeepSeek V4 Pro | 3,450 |
| MiniMax-M3 | 3,200 |
| GLM-5.2 | 880 |
| Qwen3.8 Max | 160 |
| Kimi K3 | 110 |

## Individual benchmark breakdowns (AA, extracted 2026-08-14)

Fractions are 0–1 (GPQA ~0.93); GDPval is a raw score; indices are 0–100; Omniscience
is an opaque combined index (can be negative / >1 — compare within-row, don't normalize).

| Model | GPQA Diamond | HLE | SciCode | τ³-Banking | Terminal-Bench v2.1 | Terminal-Bench Hard | LCR | IFBench | CritPt | Apex Agents | MMMU-Pro | GDPval-AA v2 | IT-Bench SRE | Analyst Agent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Kimi K3 | 0.935 | 0.469 | 0.587 | 0.460 | 0.850 | — | 0.827 | — | 0.234 | 0.413 | 0.805 | 1682.29 | 0.477 | 0.388 |
| DeepSeek V4 Pro | 0.928 | 0.410 | 0.492 | 0.396 | 0.787 | — | 0.753 | — | 0.180 | — | — | 1590.01 | — | — |
| Qwen3.8 Max | 0.927 | 0.430 | 0.529 | 0.513 | 0.813 | — | 0.743 | — | 0.200 | — | 0.823 | 1736.97 | — | — |
| MiniMax-M3 | 0.929 | 0.390 | 0.454 | 0.153 | 0.652 | 0.424 | 0.803 | 0.829 | 0.037 | — | 0.786 | 1387.97 | — | 0.100 |
| GLM-5.2 | 0.895 | 0.411 | 0.505 | 0.346 | 0.779 | 0.508 | 0.767 | 0.733 | 0.209 | 0.337 | — | 1506.11 | 0.427 | — |
| GPT-5.6 Luna | 0.911 | 0.395 | 0.525 | 0.311 | 0.809 | — | 0.783 | — | 0.206 | 0.358 | 0.786 | 1580.73 | 0.403 | — |

Also embedded per model (not in table above): `agenticIndex` (Qwen3.8 Max 58.40 > Kimi K3
54.26 > DeepSeek V4 Pro 49.56 > GPT-5.6 Luna 46.90 > GLM-5.2 45.67 > MiniMax-M3 36.12)
and `omniscience` (Kimi K3 19.70, GLM-5.2 4.43, Qwen3.8 Max 3.40, MiniMax-M3 1.35,
DeepSeek V4 Pro 0.83, GPT-5.6 Luna −10.28). `tau2` (older τ²) only GLM-5.2 0.991 and
MiniMax-M3 0.889. **LiveCodeBench and AIME 2025 fields exist but are null for all six**;
SWE-bench Verified, MMLU, and GSM8K have no field on AA pages at all.

## LMArena category Elo (style-control leaderboard, live 2026-08-14)

Human-preference Elo (rank in parens). Sourced from server-rendered category pages — the
raw JSON API (`arena-api-stable.vercel.app`, both `/api/v1` and `/api/v2`) is 403-gated by
a Vercel firewall. Fetch `https://arena.ai/leaderboard/text/{slug}` with a browser UA and
parse the embedded RSC payload (rank + rating per model). Slugs use underscores, unlike the
URL hyphen: `text-overall-style_control`, `text-coding-style_control`,
`text-math-style_control`, `text-creative_writing-style_control`,
`text-hard_prompts-style_control`.

| Model | Overall | Coding | Math | Creative Writing | Hard Prompts |
|---|---|---|---|---|---|
| qwen3.8-max | 1491 (#8) | 1529 (#13) | 1513 (#6) | 1479 (#9) | 1516 (#8) |
| kimi-k3-max | 1489 (#12) | 1544 (#6) | 1493 (#13) | 1456 (#25) | 1516 (#7) |
| glm-5.2-max | 1471 (#33) | 1506 (#51) | 1474 (#33) | 1449 (#32) | 1488 (#38) |
| grok-4.5 | 1469 (#36) | 1520 (#26) | 1479 (#25) | 1445 (#40) | 1493 (#31) |
| deepseek-v4-pro | 1458 (#51) | 1502 (#58) | 1445 (#63) | 1445 (#39) | 1481 (#49) |
| gpt-5.6-luna-xhigh | 1450 (#62) | 1499 (#60) | 1485 (#20) | 1413 (#74) | 1471 (#66) |
| minimax-m3 | 1444 (#72) | 1497 (#65) | 1440 (#72) | 1408 (#78) | 1464 (#70) |
| deepseek-v4-flash | 1435 (#85) | 1483 (#84) | 1425 (#96) | 1408 (#80) | 1459 (#81) |

`kimi-k2.7-code` is **not on the leaderboard** (closest entries: `kimi-k2.6`,
`kimi-k3-max`) — further evidence it's second-class.

## Routing conclusion (Aug 2026)

- **Default / general:** DeepSeek V4 Pro — best IQ-per-quota+latency balance (3450 req/5h).
- **Cron / high-volume:** DeepSeek V4 Flash — 63k req/5h, effectively unlimited.
- **Hard coding / deep reasoning (rare, high-value):** Kimi K3 — best IQ + coding Elo
  (AA-Briefcase 1540.8, LMArena Coding #6, HF Terminal-Bench 88.3), but 110 req/5h +
  ~51s reasoning, so ration it.
- **Best all-round quality (math / creative writing / agentic):** Qwen3.8 Max — LMArena
  Overall #8, Math #6, Creative Writing #9, top AA agenticIndex (58.4), but 160 req/5h,
  so ration it too.
- **Fast bulk drafting:** GPT-5.6 Luna — fastest (155 tok/s) + cheapest ($0.047/task),
  but weak creative writing (LMArena #74) — use for volume, not prose quality.
- **`code` alias (confirmed 2026-08-14):** point to `kimi-k3`, not `kimi-k2.7-code`.
  k2.7-code reports only in-house benchmarks (ProgramBench 53.6 vs K3's 77.8 #1;
  MLS-Bench-Lite 35.1 vs 48.3; MCP-Mark-Verified 81.1 vs 94.5), has no AA page and no
  LMArena entry. See coding-benchmark-research.md.
