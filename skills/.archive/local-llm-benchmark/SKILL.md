---
name: local-llm-benchmark
description: Benchmark local GGUF models on a VRAM-limited box.
version: 1.0.0
author: Hermes
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [local-llm, GGUF, benchmark, llama-server, pi-agent, tool-use, VRAM]
---

# Local LLM Benchmark Harness

Use when benchmarking small local GGUFs on a VRAM/RAM-limited box to pick a default model — especially comparing agentic tool-use ability, not just inference speed.

## When to use

- User asks "which local model should I run / can I run model X on my GPU"
- Fitting a model into a hard VRAM budget (~4GB target here) with KV cache
- Comparing multiple candidate models (quant/arch variants) as harness agents
- Re-benchmarking when new quant schemes (colibri, QAT, UD-*) or new model variants appear

## Benchmark methodology (validated on 4GB card, llama-server)

The full loop is: **HF fit-check → download (resume-safe) → server swap → engine t/s → pi agent tool-use test → JSONL forensics → verdict.**

1. **Fit check before download.** Query the HF tree API (`https://huggingface.co/api/models/<repo>/tree/main?recursive=true`) and confirm the quant's byte size fits the VRAM budget *plus* KV cache. Reject if the smallest quant is still too big — then search for a smaller sibling (e.g. pivot from an E4B to an E2B, or from Q4 to Q3/Q4_0).
2. **Download to /tmp (tmpfs)** with resume/retry flags against CDN drops:
   `curl -sL --retry 5 --retry-all-errors --retry-delay 3 -o model.gguf <resolve-url>`
   - Exit 23 = disk full (tmpfs) → free stale files first (`df -h /tmp`).
   - Exit 92 = HTTP mid-stream drop → the retry flags fix it.
   - unsloth/vendor GGUF repos usually publish NO SHA256SUMS → verification is load-time header validation + `/v1/models` name check.
3. **Server swap:** kill any prior llama-server still bound to the port (see stale-port gotcha below), then start:
   `llama-server -m model.gguf -ngl 99 --host 127.0.0.1 --port 8080 -c 8192`
   Confirm via `curl :8080/v1/models` that the NEW model name is live.
4. **Engine numbers** from the server log: `grep -E "prompt eval|eval time|decode"` → decode t/s (generation tokens), prefill t/s, wall time.
5. **Agent tool-use test:** use the **direct OpenAI-loop harness** (`references/openai-toolcall-harness.md`) against the planted-bug harness (invoice.py returns `rate*hours`, skipping overtime math; correct total `$113,537.50`). A model is an *agent* only if it closes read→edit→bash and the on-disk fix verifies (`python3 invoice.py` returns the correct total). The pi CLI was removed from this box (2026-08); pi-harness-gotchas.md is kept as historical record only.
6. **JSONL forensics:** read the session transcript — count read/edit/write calls, detect retry loops on already-applied patches, note whether bash verification ran. This is where you distinguish "real agent" from "narrates but can't use tools" (zero tool calls → disqualified).
7. **Verdict** = aligned winner (complete + honest + fast), not just fastest. A fix that's retried-without-verify is clumsier than one that's clean.

## Engine-speed notes (Gemma/Qwen 4B-class on 4GB)

- Decode t/s ranking seen: Gemma 4 E2B (36) > Gemma 3 4B (32) > Qwen3-4B (31.7) > Qwen3.8 (25.7) > Qwen3.5 (24.9).
- **MoE active-weights prefill**: Gemma 4 E2B prefill 285–300 t/s vs Qwen builds' 42–118 t/s — a 4×+ speculative-token speedup. Don't judge MoE on decode alone.

## Vendor-patched arch builds (Hybrid / probe / edge variants)

A GGUF failing with `unknown model architecture: 'gemma-4-e2b-it-hybrid'` is NOT broken — it needs the vendor's llama.cpp patch series. See `references/vendor-patched-builds.md` for the full find-patch-clone-apply-build workflow (verified: patches applied cleanly to pinned tag, arch confirmed in gguf-py constants.py). Key gotchas: the patch path in the HF README 404s — the real patches live in the vendor's GitHub org; the vendor PIN tag may be older than your build; verify with a real server load, not `--dry-run`.

## Stale server port gotcha

After a model swap a previous `llama-server` often stays bound to :8080; the new server exits silently and `/v1/models` reports the OLD model. Always: `ss -tlnp | grep 8080` → kill the PID → relaunch → confirm the new model name.

## Data / state

- Models + llama.cpp build live in `~/models/` and `~/.local/llama-b10488/` (server binary: `~/.local/llama-b10488/llama-server`).
- Standalone local model = Gemma 12B Q4_K_M on :8080 (`-ngl 20 -ctk/ctv q8_0`, ~3.4GB VRAM); watchdog boots the same GGUF on :8081 on demand.
- Benchmark scratch notes live at `/tmp/gemma-bench.md`.
- The pi harness is gone; the current tool-use harness is the direct OpenAI-loop one (`references/openai-toolcall-harness.md`).

## References
- **[vendor-patched-builds.md](references/vendor-patched-builds.md)** — running GGUFs whose arch isn't in upstream llama.cpp (find the vendor's patch repo, clone pinned tag, git am, build server)
