# Artificial Analysis — deterministic extraction recipe

Pull per-model benchmark metrics from `artificialanalysis.ai` without JS, via the
embedded JSON-LD blocks. Verified working Aug 2026.

## Fetch

```bash
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126 Safari/537.36"
curl -sL -A "$UA" --max-time 25 -o /tmp/aa_<slug>.html \
  "https://artificialanalysis.ai/models/<slug>"
```

- Real model detail page: **~3.2–3.3 MB**.
- 404 / wrong slug: **~235 KB** and contains `"not found"`. Page size is the cheap tell.

## Slugs are hyphenated (dot names → hyphenated URLs)

| model name | slug |
|---|---|
| deepseek-v4-pro | `/models/deepseek-v4-pro` |
| glm-5.2 | `/models/glm-5-2` |
| qwen3.8-max | `/models/qwen3-8-max` |
| gpt-5.6-luna | `/models/gpt-5-6-luna` |
| kimi-k3 | `/models/kimi-k3` |
| minimax-m3 | `/models/minimax-m3` |

Discover correct slugs from the models index page (`/models`): regex
`"detailsUrl":"([^"]+)"`.

## Extract via JSON-LD

The page embeds many `<script type="application/ld+json">` blocks. Each is a schema.org
`Dataset`: `name` = metric, `data[]` = rows of `{label, <metric>, detailsUrl}`. Filter
rows by `detailsUrl == "/models/<slug>"` to get THAT model's value for every metric.

### Metric keys (by dataset `name`)

- `Artificial Analysis Intelligence Index` → `intelligenceIndex` (composite, ~0–100)
- `AA-Briefcase Elo` → `aaBriefcaseElo` (CODING Elo, ~1100–1600; list of PropertyValue mid/lower/upper)
- `AA-Omniscience Index` → `omniscienceIndex` (reasoning / hallucination; scale opaque — treat with care)
- `Speed` / `Output Speed` → `medianOutputSpeed` / `outputSpeed` (tok/s)
- `Time per Intelligence Index Task` → `timePerTask` (sec, lower=better)
- `End-to-End Response Time` → `answerTime`, `reasoningTime` (sec)
- `Cost per Task` → `costPerIntelligenceIndexTask`
- `Model Size: Total and Active Parameters` → `activeParams`, `passiveParams` (MoE, billions)
- `Pricing: Cache Hit, Input, and Output` → list of PropertyValue `{cacheHitPrice, inputPrice, outputPrice}`

### Reusable script shape

```python
import sys, re, json
slug = sys.argv[1]
url = "/models/" + slug
t = sys.stdin.read()
for b in re.findall(r'<script[^>]*application/ld\+json[^>]*>([\s\S]*?)</script>', t):
    try:
        d = json.loads(b)
    except Exception:
        continue
    name = d.get("name", "?")
    for row in (d.get("data") or []):
        if not isinstance(row, dict) or row.get("detailsUrl") != url:
            continue
        for k, v in row.items():
            if k not in ("label", "detailsUrl"):
                print(f"{name}::{k} = {v}")
```

Run: `python3 aa_model.py <slug> < aa_<slug>.html`

## Per-benchmark breakdowns (RSC flight payload)

The JSON-LD blocks carry only composite metrics (Intelligence Index, Briefcase Elo,
speed, cost, params). The **individual benchmark scores** (GPQA Diamond, HLE, SciCode,
τ³-Banking, Terminal-Bench, LCR, IFBench, CritPt, Apex Agents, MMMU-Pro, LiveCodeBench,
AIME 2025, GDPval-AA v2, IT-Bench SRE, Analyst Agent) are ALSO in the HTML — embedded in
the Next.js **React Server Components flight payload** (`self.__next_f.push([...])`).

The target model's full record is the `currentModel` object (it is the one that carries
an `intelligenceIndex` key). Parse every `push([...])` array, decode the `d:` /
`<hex>:`-prefixed JSON strings, recursively walk the tree for dicts with a `slug` key,
then keep the object where `slug == target` AND `intelligenceIndex` is present. There
are ~3 slug-matching objects per page (full record, a `{slug,name}` stub, and a
`{slug,name,creator}` stub) — the `intelligenceIndex` guard selects the full one. The
page also embeds ~608 OTHER models' records, so always filter by slug.

```python
import re, json
def walk(o, out):
    if isinstance(o, dict):
        if isinstance(o.get('slug'), str): out.append(o)
        for v in o.values(): walk(v, out)
    elif isinstance(o, list):
        for v in o: walk(v, out)

def get_models(html):
    found = []
    for m in re.finditer(r'self\.__next_f\.push\(', html):
        try:
            arr, _ = json.JSONDecoder().raw_decode(html[m.end():])
        except Exception:
            continue
        for item in arr:
            if not isinstance(item, str): continue
            if item.startswith('d:'):
                body = item[2:]
            elif re.match(r'^[0-9a-f]:', item):
                body = item[2:]
            else:
                continue
            try: walk(json.loads(body), found)
            except Exception: pass
    return found
```

### Benchmark field names (per-model object)

`intelligenceIndex`, `agenticIndex`, `omniscience` (+ `omniscienceBreakdown.accuracy` /
`.hallucinationRate`), `gdpval` (GDPval-AA v2), `itBenchSre`, `tau2` + `tauBanking`
(τ³-Banking), `terminalbenchV21` / `terminalbenchHard`, `scicode`, `lcr` (long-context
reasoning), `ifbench`, `hle` (Humanity's Last Exam), `gpqa` (GPQA Diamond), `critpt`,
`apexAgents`, `mmmuPro`, `livecodebench`, `aime25` (AIME 2025), `analystAgent`.

Scale notes: fractions are 0–1 (GPQA ~0.93); `intelligenceIndex`/`agenticIndex` are
0–100; `gdpval` is a raw score (e.g. ~1590); `omniscience` is an opaque combined index
whose value can be negative or >1 across models — report it as-is, don't normalize.

## Gotchas

- **The models index page embeds ALL models' composite indices.** The first
  `intelligenceIndex` match in a detail page is usually a top-ranked OTHER model
  (e.g. Claude Opus 5 ≈ 63.05). Always filter by `detailsUrl`, never take the first hit.
- **No `__NEXT_DATA__`, but the per-benchmark breakdowns ARE in the HTML** — embedded in
  the Next.js RSC flight payload, not client-fetched (see next section). The only
  benchmarks genuinely absent (no field at all) are **SWE-bench Verified, MMLU, and
  GSM8K**. `livecodebench` and `aime25` fields exist but are `null` for the Aug-2026
  lineup — not yet published on AA.
- **LMArena (arena.ai) Elo is also client-fetched.** Its HTML carries only the model
  registry (`provider`, `publicName`, `displayName`, `capabilities`). Category tabs
  (Coding, WebDev, Creative Writing) exist but their scores load via XHR.
- Some models have **no AA page at all** (dedicated code models, flash variants) — see
  the SKILL.md pitfalls.
