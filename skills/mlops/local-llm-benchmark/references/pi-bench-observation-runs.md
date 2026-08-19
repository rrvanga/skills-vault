# pi observation-run learnings (local GGUF agent bench — second pass)

New findings from a delegated observation run of Gemma 4 E2B Q4_0 as a `pi`
coding agent. Complements `pi-harness-gotchas.md`; these are the ones that cost
real cycles when missed.

## A. llama-server SERVES THE LOADED MODEL REGARDLESS of the requested `model` id

Single-model llama-server ignores the `model` id sent in a request; every
request is served by the ONE loaded GGUF. Confirmed:
- The bench box had only `gemma4-e2b-Q4_0.gguf` loaded (`ss` shows one
  llama-server; `grep load_model` shows only gemma4).
- But pi's session `model_change` recorded **`qwen3-4b-q4km.gguf`** (the FIRST
  entry in `models.json`, not the `default`), and pi's per-message `api.model`
  said the same.
- A probe curl stating `"model":"qwen3-4b-q4km.gguf"` still returned
  `"model":"gemma4-e2b-Q4_0.gguf"` in the response.

**Rule:** the `model` field in `~/.pi/agent/sessions/*.jsonl` is NOT proof of
what ran. pi may record a wrong/stale id while the server silently serves the
loaded model anyway. Before attributing a verdict to a model, confirm what the
server actually loaded:
```bash
ss -tlnp | grep 8080
grep -iE "load_model: loading" /tmp/<server>.log | tail
curl -s :8080/v1/models | grep '"id"'
```
Here the observation was still valid for gemma4-e2b-Q4_0 (the only model the
server could serve) despite pi's qwen3 annotation.

## B. `-p` can EXIT 0 with EMPTY stdout in FOREGROUND, not just background

Gotcha #2 covered background/redirect runs. This run it happened in a plain
foreground `timeout 240 pi --provider local-gpu --approve -p "<task>"`
captured with subprocess `capture_output=True`: **EXIT 0, STDOUT empty,
STDERR empty, in 11.3s wall**. The agent had finished its full loop; output
lived only in the session JSONL. So:
- Empty stdout is never proof of failure, even in foreground.
- A short wall time (11s) is not proof of a no-op — with a slow model a full
  write→write→bash loop can be that quick.
- Always recover the artifact on disk + the JSONL trail.

## C. Trust-but-verify the GROUND TRUTH, not just the agent's claim

The benchmark brief quoted "correct entropy ≈2.276 bits" for `"aabbbcdddde"`.
That number is WRONG. Independent computation (counts a2/b3/c1/d4/e1, n=11):
```python
import math
s='aabbbcdddde'; n=len(s)
from collections import Counter
c=Counter(s)
H=-sum((k/n)*math.log2(k/n) for k in c.values())  # 2.1180782093497093
```
Both pi's program and direct Python agreed on **2.118**, so the model actually
routed to the correct truth despite the brief's misleading number.
**Rule:** never grade against a supplied "correct answer" verbatim — recompute
ground truth yourself and grade the agent's program logic against YOUR value.
Do not penalize a model for deviating from an erroneous number in the brief.

## D. Agent can DESTRUCTIVELY OVERWRITE the task's INPUT data file

Failure mode observed on the dups task: pi was asked to READ `nums.json` and
print duplicates. Instead of reading, it issued a `write` toolCall that
OVERWROTE `nums.json` with a fabricated array `[1,2,2,3,4,4,4,5,6,6]`, then ran
and reported success with `2,4,6` — self-consistent, but WRONG for the real
input `[4,1,3,2,4,5,1,9,6,2]` (true dupes 1,2,4). The dups.py code logic was
correct all along; the mismatch was data mutation.

This is a genuine agent-CONTROL bug, distinct from "bad code": the agent edits
problem data instead of reading it, so an internally-consistent test loop can
mask it. When a task's answer comes back wrong:
1. diff / restore the INPUT files the agent should only have read,
2. re-run the agent's program against the ORIGINAL data,
3. only then conclude "bad code" vs "agent clobbered the input."

## E. Tool-sequence forensics built from assistant toolCall + toolResult messages

`grep` on `"toolName"` alone over-counts (each toolCall produces a
matching `toolResult`). To get the true ordered sequence reliably, parse the
JSONL pythonically: walk `type=="message"` records; collect `content[]`
entries whose `type=="toolCall"` → `name`; treat `role=="toolResult"` →
`toolName` as the matching result. Count distinct tools for the loop evidence
(e.g. task1 `["write","bash","write","bash"]`, task2 `["write","write","bash"]`).
