# Extracting max performance on a VRAM-limited card

Validated 2026-08 on a GTX 1650 4 GiB dGPU running `gemma-4-26B-A4B-it` Q3_K_M
(12.7 GB / 25.23 B params MoE, ~4B active). Task: "use all the GPU / extract
max performance." All numbers are live `llama-server` measurements unless noted.

## The hardware ground truth
- 4 GiB VRAM, only ~2,989 MiB usable; model 12.7 GB → cannot fit the whole model.
- MoE single-token decode is **bandwidth/RAM-bound, not compute-bound**.

## Final numbers (honest, live)
| Config | Decode t/s | Loads in server? |
|---|---|---|
| CPU-only | 2.45 | yes |
| `--fit on` (auto offload) | ~5.05 | yes |
| **`-ngl 6` hand-tuned** | **5.29** | **yes (2,989 MiB)** ← true live max |
| Spec-dec + MTP draft (`-ngl 4`) | 5.39 | yes (tie, not a win) |
| `-ngl 8` via llama-bench | 6.57 | **NO — harness-only** |

## Method (the reusable part)
1. `--fit on` is the conservative reference, NOT the max. Find the true max by
   stepping `-ngl` up until the server **fails to load**, then back off one:
   `-ngl 6` loaded; `-ngl 8` failed with
   `graph_reserve: failed to allocate compute buffers` / `failed to allocate compute pp buffers`.
2. **llama-bench overstates what a server can do.** It offloads more whole layers
   (~6.57 t/s @ ngl 8) because it doesn't reserve VRAM for the server's compute
   graph / KV context. Always validate the claimed-max config in a real server
   (`/health` → 200) and re-measure live before reporting. A bench-only number is
   NOT achievable throughput.
3. **Layers allocate all-or-nothing.** A Q3 layer ≈ 983 MB; only ~1.2 GB is free
   beyond `--fit`, so exactly ~1 extra layer fits and the next OOMs. Offload is
   capped at layer granularity, not bytes. (This is why `-ngl 18` also OOM'd.)
4. **Speculative decoding is a wash here.** The MTP draft (Q8, ~441 MB) competes
   for the same scarce VRAM/threads; measured tied at ~5.4 vs 5.29 t/s. Flags:
   - `--model-draft <file>` — note: the short form `--md` was **rejected as
     "invalid argument: --md"** by this build even though `--help` listed it;
     the long form works.
   - draft compute threads `-td`, draft batch threads `-tbd`.
   - Must drop `-ngl` (used `-ngl 4`) to leave room for the draft + compute buffers.
   - gemma-4 prints a **benign** `Gemma4Assistant requires ctx_other to be set`
     warning while the server measures draft memory, then continues and loads —
     not a failure.
   - Spec-dec needs 100+ decoded tokens to reach steady state; a 14-token decode
     showed 3.96 t/s before ramping to 5.39.
5. Recommend spec-dec only when there is spare VRAM / a second GPU for the draft.

## llama-bench gotchas
- Threads = `-t`, **batch threads = `-th`** (`-tb` is wrong).
- NO `--fit` in llama-bench (server-only flag), and `-ngl auto` is unsupported —
  integer `-ngl` only.
- Output format: `pp64 = ` prompt-eval t/s, `tg64 = ` token-gen t/s (with ± stddev).

## Runnable config that achieves the max
```
llama-server -m gemma-4-26B-A4B-it-UD-Q3_K_M.gguf -ngl 6 -sm none \
  -c 2048 -b 2048 -ub 512 -t 12 -tb 12 -ctk q8_0 -ctv q8_0 \
  --port 8086 --host 127.0.0.1
```
- Live check: `/health` → 200; decode via `/completion` with `"timings": true` →
  `timings.predicted_per_second`.
- Quantized KV (`-ctk q8_0 -ctv q8_0`) freed VRAM for the 6th layer vs `--fit`.

## Cleanup reminder
After benchmarking, kill the server(s) started this session (verify with
`ss -tln | grep 808x` and `nvidia-smi --query-gpu=memory.used`), leave the model
+ draft files on disk. A `kill <pid>` that leaves a `<defunct>` zombie is fine —
it reaps.
