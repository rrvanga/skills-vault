# GitHub trend landscape — Aug 2026 research session

Queries and findings from the session that produced the "llmfit" recommendation.
Numbers are snapshots; re-run the saturation check before re-using them as current.

## Trend data queries used

```bash
# NEW repos (created last ~45d, 100+ stars)
gh api -X GET search/repositories -f q='created:>2026-06-30 stars:>100' \
  -f sort=stars -f order=desc -f per_page=50

# ACTIVE hot repos (pushed last ~30d, 1000+ stars)
gh api -X GET search/repositories -f q='pushed:>2026-07-15 stars:>1000' \
  -f sort=stars -f order=desc -f per_page=50
```

## What was hot (themes)

1. **Agent skills / agent harnesses** — dominant but saturated.
   `obra/superpowers` 272k, `mattpocock/skills` 217k, `anthropics/skills` 169k,
   `NousResearch/hermes-agent` 230k, `affaan-m/ECC` 240k. New single-skill repos
   were flooding in (skill-recorder, zine skills, watermarks-remover, etc.).
2. **Local / on-device LLM inference** — exploding demand, thin curated supply.
   `ollama/ollama` 178k, `open-webui` 148k, `kimi-k3-in-c` (K3 on CPU in 8GB),
   `turbo-fieldfare` (Gemma 4 in 2GB RAM) trending this week.
3. **Free/curated resource lists** — always high-star (`public-apis` 458k,
   `free-programming-books` 394k, `awesome-selfhosted` 312k), but each niche is
   either taken or has a low ceiling.

## Saturation check results (the key table)

| niche query | total_count | top repo / stars | verdict |
|---|---|---|---|
| `awesome agent skills` | 761 | Shubhamsaboo/awesome-llm-apps 132k | crowded |
| `awesome claude skills` | 633 | ComposioHQ 72k | crowded |
| `awesome local llm` | **47** | rafska/awesome-local-llm 2.5k | **open lane** |
| `awesome on-device ai` | 24 | jego-lee 181 | tiny / open |
| `awesome hermes` | 56 | 0xNyk/awesome-hermes-agent 5.3k | small but owned |
| `hermes skills` | 4,506 | cc-switch 127k (misc) | noisy |
| `agent skills` | **102,440** | obra/superpowers 272k | saturated |
| `local llm benchmark` | 1,057 | Andyyyy64/whichllm **6.2k** | demand proof, thin supply |

## Decision

Chose **"local LLM on a budget"** (→ `llmfit`) over agent-skills (saturated,
celebrity-owned) and Hermes plugin pack (niche-sized). Rationale:
- `whichllm` at 6.2k stars is proof of demand for "what runs on MY hardware".
- The curated/awesome version of that niche has only 47 repos → open lane.
- Matches the user's live situation (buying a local-AI Linux box, comparing
  5060 Ti 16GB / 5070 Ti / 3060 12GB, tracking DRAM/NAND prices).

## Display-quirk workaround (machine-specific)

Long terminal/read_file output collapses to `1 lines`. Write parse results to a
`/tmp` file, then `read_file` that file with a low `limit` (5–40). Do the
aggregation (filtering, sorting, dedupe) in the Python parser, not in context.
