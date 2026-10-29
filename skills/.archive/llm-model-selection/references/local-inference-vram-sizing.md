# Local-inference hardware sizing (VRAM fit + bandwidth math)

Dated snapshot: 2026-08-17. Used when a user asks "can I run this locally" / buys a GPU
for local LLMs / compares local-vs-cloud routing. The model-selection question is not
only *which* model — it's *which quant fits which card*.

## Quant-fit table (live GGUF sizes from HF, Qwen-30B-A3B class)

| Quant | Size | Fits 16GB? | Fits 32GB? |
|---|---|---|---|
| Q4_K_M | 18.6 GB | ❌ | ✅ |
| Q4_K_S | 17.5 GB | ❌ | ✅ |
| Q3_K_M | 14.7 GB | ✅ (tight) | ✅ |
| Q3_K_XL | 13.8 GB | ✅ comfortable | ✅ |

Rule of thumb: 16GB cards run 30B-class MoE only at Q3 (lossy); 14B-class at Q4+ is
comfortable. 32GB runs 27B dense at Q6/Q8 (near-lossless) — that's why VRAM capacity,
not bandwidth, is the buying decision for "run a real agent model locally".

Fetch live sizes deterministically:
`curl -s "https://huggingface.co/api/models/unsloth/<Model>-GGUF/tree/main?recursive=true"`
then sum `size` for the quant file you care about.

## Bandwidth math (decode is bandwidth-bound)

| Card | VRAM | Bandwidth | Verdict |
|---|---|---|---|
| RTX 5070 Ti | 16GB | 896 GB/s | fastest decode, small capacity |
| RTX 3090 (used) | 24GB | 936 GB/s | capacity + speed, no warranty |
| Intel Arc Pro B70 | 32GB | 608 GB/s | capacity king, ~30-50% slower decode than 3090 for SAME model |

- Same model+quant: higher bandwidth ⇨ higher tok/s. B70 wins on capacity only.
- Multi-GPU server load: 4×B70 = 369 t/s vs 4×3090 = 348 t/s with better TTFT
  (11.4s vs 18.7s) per Level1Techs — B70s stack well (dual-slot blower, 230W TDP).
- MoE (e.g. 30B-A3B, ~3B active/step) keeps prefill fast on small VRAM — the
  16GB-era sweet spot; use prompt-processing (prefill) numbers too, not just decode.

## Reference stack (proven on Linux, 2026-08)

`jeffgrover/b70-setup` GitHub repo — production box: Minisforum Venus mini-PC (AMD,
32GB RAM, 64GB swap) + **Arc Pro B70 over USB4 eGPU**, llama.cpp SYCL/Level-Zero,
fronted by llama-swap → OpenAI-compatible endpoint at `127.0.0.1:8080/v1`, consumed by
`opencode`/`pi`. Measured: Agents-A1 (35B agent-tuned) 81.6 t/s sustained with native
tool calls; Qwen3.6-35B-A3B UD-Q4_K_S 55 t/s (220 prefill); Gemma-4 E4B 76.5 t/s.

Implications:
- USB4 (40 Gbps) eGPU is plenty for inference — weights stay GPU-resident; only KV/
  activations cross the link. Enables mini-PC + eGPU as a quiet 24/7 gateway with
  on-demand local inference, without buying a gaming desktop.
- Any OpenAI-compatible agent (Hermes included) can route to local by swapping the
  baseURL to the local endpoint — proven wiring pattern (see deepseek-harness skill:
  custom `openai-completions` provider + `agent-default-model`).
- Hybrid routing: local 35B-class at ~55-80 t/s handles routine autonomy (summaries,
  kanban, cron); frontier (deepseek-v4-pro, kimi-k3) stays cloud-only — those are not
  embeddable locally, period.

## Buying notes

- B70 street: ~$949 US (Apr 2026 launch); Newegg CA $1,399.99 (ASRock) / $1,499.99
  (Intel) as of 2026-08-17. NOT a gaming card (Pro blower, workstation drivers) —
  if the box must game, that's a separate GPU decision.
- Software: llama.cpp SYCL/Level-Zero + vLLM proven; CUDA remains the frictionless
  default. Intel-first = early-adopter friction.