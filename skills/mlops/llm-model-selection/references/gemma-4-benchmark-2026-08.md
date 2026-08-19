# Gemma 3 / Gemma 4 as local harness agents (GTX 1650 4GB) — 2026-08-18

Continuation of `local-inference-agent-benchmark.md`: the same planted-bug pi loop,
now run across Qwen3 / Qwen3.5 / Qwen3.8 / Gemma 3 / Gemma 4 E2B on the 4GB Vulkan box.
All session JSONL + on-disk verifications recorded. Purpose: which small model actually
**acts** as a harness agent (real read→edit→bash loop) vs narrates a fix it never makes.

## Verdict table (5 candidates, identical planted-bug invoice task)

| Model (quant) | Fits 4GB? | Tool loop under pi | Fix verified on disk | Decode t/s | Read→edit→bash complete? |
|---|---|---|---|---|---|
| **Qwen3-4B** Q4_K_M | ✅ 2.5GB | ✅ read→edit→bash | ✅ $113,537.50 | 31.7 / 25.5s | **Winner** |
| **Qwen3.5-4B** Q4_K_M | ✅ | ✅ read×2→edit→bash | ✅ $113,537.50 | 24.9 / 35.7s | Verified backup |
| **Gemma 4 E2B** Q3_K_M | ✅ 2.42GB | ✅ read×3→edit×4→write | ✅ $113,537.50 | **36.09** / 75.8s | Works, least robust |
| Gemma 3 4B Q4_K_M | ✅ 2.4GB | ❌ **zero** tool calls | ❌ untouched | 32.05 | Fails (narrates) |
| Qwen3.8-4B Q4_K_M | ✅ | ❌ zero tool calls | ❌ untouched | 25.7 | Fails (loop never initiates) |

Correct total = $113,537.50 (45h×$45 + 20h×$320 + 60h weekly with 20h OT at 1.5× = $105,000).
Buggy total = $98,425.00 (no OT, wrong by $15,112.50) — eyeball check.

## The three distinct tool-failure failure modes (do not conflate)

1. **Loop never initiates** (Qwen3.8-4B): tool-capable but won't self-start the agentic loop
   from a plain task prompt under the harness. Disambiguate with a raw-API probe → emits a
   perfect function call. Generation-specific; the older Qwen3/3.5 gens *do* self-initiate.
2. **Tool-incapable even with explicit schema** (Gemma 3 4B): given
   `tools:[{function:{...}}]` + `tool_choice:"auto"` it ignores the schema, narrates a
   hallucinated answer, `finish_reason:"length"`. No native tool tokens in vocab.
3. **Works but untidy loop** (Gemma 4 E2B): lands a real correct edit (visible diff), then
   keeps re-applying the *stale* patch ("exact text not found" ×3), then a full-file `write`
   hits the output-token limit, and never reaches `bash` verify. The fix IS on disk — but it
   cost 75.8s vs Qwen3's 25.5s and skipped verification.

**Tool-protocol signal:** check for the model's native tool tokens at load — Gemma 4's vocab
has `<|tool_response>` (llama-server logs `control-looking token '<|tool_response>'`), a strong
sign it was trained to emit structured tool calls. Gemma 3 lacks them.

## Raw-API tool-capability probe (works for any model)

```bash
curl -s http://127.0.0.1:8080/v1/chat/completions -H "Content-Type: application/json" -d '{
  "model": "<gGUF-id>",
  "messages": [{"role":"user","content":"What is the weather in Paris? Use the tool."}],
  "tools":[{"type":"function","function":{"name":"get_weather","description":"weather lookup",
    "parameters":{"type":"object","properties":{"city":{"type":"string"}}}}}],
  "tool_choice":"auto"}'
```
Clean function call → tool-capable (failure is loop-initiation/harness-side).
Hallucinated narrative, no call → incapable even when handed the schema.

## Gemma 4 sizing: "E4B"/"E2B" = active params, NOT total size

- **Gemma 4 E4B-it**: ~8B-total class + vision tower. Q4_K_M = **4.98GB**, smallest quant
  UD-IQ2_M = 3.55GB. **Does NOT fit a 4GB card** with KV cache headroom. B70-class target.
  (The session first re-downloaded E4B before the tree API caught this — check sizes FIRST.)
- **Gemma 4 E2B-it**: ~4.6B-total (BF16 = 9.31GB; "E2B" = 2B *active*). Q3_K_M = **2.54GB**
  fits. This is the true 4B-class Gemma 4 peer of Qwen3-4B.
- **Colibri quants**: NONE exist for any Gemma (scheme covers only GLM-5.2 / Qwen3.6-A3B as of
  2026-08). So no low-bit squeeze path for the Gemma flagships on a 4GB card.
- unsloth Gemma GGUF repos publish **no SHA256SUMS** (404 on both names) — integrity fallback =
  llama-server GGUF header validation at load + `/v1/models` embedded-name check
  ("the load *is* the verification").

## Operational pitfalls (bit repeatedly this session)

- **tmpfs /tmp fills fast** stacking several multi-GB GGUFs. `df -h /tmp` before each download;
  `du -s /tmp/*.gguf | sort -nr` to find the biggest; delete redundant/re-downloadable files.
- **curl exit codes**: 23 = write error (disk full, partial file), 92 = HTTP error mid-download.
  Both leave a truncated GGUF whose `sha256sum` never prints. Retry with
  `curl -sL --retry 5 --retry-all-errors --retry-delay 3` and confirm hash + size after.
  Do NOT background-launch a fresh download while an old one still holds a temp fd to the same
  path — you can end up with two writers to one file (seen: cached 2.6GB "deleted" file
  resurrecting). Kill the old curl first, then re-download to a clean path.
- **`curl -sI` (HEAD) on HF LFS returns `content-length: <tiny>`** — HEAD does not follow the
  LFS redirect, so the size is meaningless. Use the tree API for real sizes.
- **Model-family names are misleading for size** — always size the actual quant via the tree
  API (`/api/models/<repo>/tree/main`) before downloading to a VRAM-bound card.
- Server swap: kill old llama-server (accept brief :8080 downtime), start new model, retry-loop
  `/health` → 200, then confirm `/v1/models` shows the intended id (= header-validation fallback).
- `--chat-template-kwargs '{"enable_thinking":false}'` now logs a deprecation warning —
  use `--reasoning off`. The kwargs form still worked for exact comparability.
- A model re-applying an already-landed edit in a "exact text not found" loop is a **robustness
  signal, not a hard failure** — score by the on-disk result, then consider a larger
  `maxTokens`/different edit strategy for the less tidy models.

## Effective recommendation (Aug 2026)

On a 4GB card the verified general-harness pick is **Qwen3-4B-Instruct (thinking off)** — the
only candidate that cleanly and honestly completes read→edit→bash. **Gemma 4 E2B** is the
fastest-decoding capable runner-up (36 t/s, 285–300 t/s prefill from MoE active-weights) —
worth it when raw speed matters and the harness tolerates its untidy re-apply-then-stop cycle.
Gemma 3 4B and Qwen3.8-4B are disqualified as harness agents.
The B70 upgrade is what unlocks the Gemma 4 (and Qwen3.8) 27B/31B flagships the card can't hold.
