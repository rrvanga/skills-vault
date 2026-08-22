# Throughput measurement discipline (llama.cpp, 4GB-box proven 2026-08-21)

Two measurement mistakes produced one false "13% faster" claim and one wrong "2.67 t/s"
number for the same model. The lessons, so a future sweep doesn't repeat them:

## Rules

1. **Use `/v1/chat/completions`, never raw `/completion`, for t/s on instruction-tuned
   models.** The raw endpoint skips the chat template: gemma-4-12b-it emitted degenerate
   `<|channel|>thought <channel|>` rambling and stopped after ~14 tokens — a 14-token
   "run" is not a throughput measurement at all.
2. **Sample ≥128 tokens (256 better).** First-token latency dominates runs under ~50
   tokens. A 31-token sample read "4.96 t/s" and was pure noise; honest 128/256-token
   runs put ngl 20 and ngl 22 at functional parity (4.38–4.44 t/s) for Gemma 12B Q4_K_M.
3. **Cross-check wall clock against the server's own timing.** `slot print_timing`
   (n_gen/tg) in the server log is the authoritative decode number; agreement between
   wall-clock t/s and `tg` over a full run means the number is real.
4. **Distrust your own earlier numbers that disagree with a warm full-length run.**
   Cold-start and short-sample artifacts look like configuration wins. Re-measure before
   reporting a config change as an improvement — and correct the record when a later
   measurement contradicts an earlier claim.

## Correction on record

`references/gemma-12b-on-4gb-vram.md` once listed ngl 22 as "~4.96 t/s — best stable".
Proper measurement (2026-08-21): ngl 20 = 4.38–4.40 t/s, ngl 22 = 4.40–4.44 t/s —
functional parity. ngl 22 stays as the shipped config because it boots cleanly as the
max-safe step below the ngl-24 Vulkan OOM (kv-cache buffer at load), NOT because it is
faster. Treat the table's ngl-22 row as "max safe", not "fastest".