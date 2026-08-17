# Coding-benchmark research: finding numbers when a model has no AA / leaderboard page

Worked example: deciding whether `kimi-k2.7-code` (code specialist) or `kimi-k3`
(flagship) should hold a "code" routing alias. Reusable recipe + concrete data below.

## Recipe 1 — web search when the browser is blocked

- **Bing HTML via curl is the reliable fallback.** DuckDuckGo's `html.duckduckgo.com`
  endpoint frequently returns a 14KB bot-challenge page ("anomaly"/"challenge" strings,
  zero `result__` nodes) even with a browser User-Agent. Don't fight it — go straight to
  Bing:
  ```bash
  curl -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36" \
    "https://www.bing.com/search?q=QUERY" -o out.html
  ```
- Parse results by splitting on `<li class="b_algo">…</li>` blocks; inside each block the
  title is `<h2><a href=…>TITLE</a>`, the real destination is `<cite>…</cite>` (the
  `<a href>` is a `bing.com/ck/a` redirect wrapper), and the snippet is the first `<p>`.
- Generic one-word queries (e.g. a bare model name) return cached brand pages, not
  benchmark data — add specific terms (`SWE-bench`, `Terminal-bench`, "benchmark") and
  quote the model name.

## Recipe 2 — HF model-card README is the authoritative benchmark source

Vendor model cards embed the full benchmark tables and are curl-able without auth:

```bash
curl -s -L -A "Mozilla/5.0" \
  "https://huggingface.co/<org>/<model>/raw/main/README.md" -o card.md
```

- Org name is case-insensitive (`moonshotai` == `MoonshotAI`). A `…-Instruct` suffix 404s
  if the actual repo is `…-Code` or plain.
- Grep for `swe-bench|livecodebench|aider|bigcodebench|terminal-bench|benchmark` to see
  which *standard* benchmarks are present. Code specialists often report **only in-house**
  benchmarks (Kimi Code Bench, Program Bench, MLS-Bench, MCP-*).
- The card's footnotes list harness + effort settings — read them; "best coding model"
  claims are often measured on the vendor's own harness/bench.

## Head-to-head data (Aug 2026) — kimi-k2.7-code vs kimi-k3

Sources: `moonshotai/Kimi-K2.7-Code` and `moonshotai/Kimi-K3` HF READMEs.

**kimi-k2.7-code** — in-house benchmarks only; trails frontier models on every one:

| Benchmark | k2.7-code | GPT-5.5 | Claude Opus 4.8 |
|---|---|---|---|
| Kimi Code Bench v2 | 62.0 | 69.0 | 67.4 |
| Program Bench | 53.6 | 69.1 | 63.8 |
| MLS Bench Lite | 35.1 | 35.5 | 42.8 |

No SWE-bench Verified / LiveCodeBench / Aider / BigCodeBench / Terminal-bench anywhere.

**kimi-k3** — near/at top of frontier on standard coding benches:

| Benchmark | k3 | Claude Fable 5 | GPT-5.6 Sol |
|---|---|---|---|
| Terminal-Bench 2.1 | 88.3 | 88.0 | 88.8 |
| ProgramBench | **77.8 (#1)** | 76.8 | 77.6 |
| FrontierSWE | 81.2 | 86.6 | 71.3 |
| SWE-Marathon | **42.0 (#1)** | 35.0 | 39.0 |
| DeepSWE | 67.5 | 70.0 | 73.0 |
| AA-Briefcase (Elo) | 1548* | 1583 | 1495 |

*Model card 1548 vs Artificial Analysis 1540.8 (snapshot difference — same ballpark).

**Overlap (both cards) — k3 wins all five by 8–24 pts:** Program Bench 53.6→77.8,
MLS-Bench-Lite 35.1→48.3, Kimi Code Bench 62.0→72.9, MCP-Mark-Verified 81.1→94.5,
MCP-Atlas 76.0→84.2.

**Verdict:** kimi-k3 is the better coding model. The "code"-specialist (k2.7-code,
June 2026, forces thinking, no non-thinking mode) is a generation behind the July 2026
2.8T-param flagship and has no public standard-benchmark score at all.

## Cross-check rule

When comparing two models, prefer benchmarks **both** cards report (or a third-party
leaderboard both appear on). A benchmark only one vendor reports is marketing, not
comparison — especially when it's in-house.
