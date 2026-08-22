# b10488 Vulkan quirks on the 1650 + iGPU (verified 2026-08-21)

Build: `~/.local/llama-b10488` (llama-cli/server). All entries verified by live
runs on this box (i7-9750H 6c/12t, GTX 1650 4 GiB, Intel UHD 630). **Re-verify
on any newer build — quirks migrate as fixes land.**

## Quirk table

| Config / flag | Behavior on b10488 | Verdict |
|---|---|---|
| `-ub` omitted (default) | inflates compute-graph buffers → `failed to allocate compute pp buffers` OOM on the 4 GiB card | always pass explicit `-ub 512` |
| `-fa on` | **HANGS** at generation (spins forever, ignores TERM — needs `kill -9`) | do not use until re-tested on a newer build |
| `-tb 12` | fine single-GPU; silently **crashes multi-device boots** (~1.5 s in) | single-device only |
| `--device Vulkan0,Vulkan1` (iGPU first) | segfault at Vulkan device init | never — dGPU first |
| `--device Vulkan1,Vulkan0 -ngl 48 -sm layer` | boots; **1.7 t/s** generation | not worth it (below) |
| `--device Vulkan0 -ngl 48` (iGPU-only) | boots; all 48 layers fit (17.7 GiB shared heap); **1.5 t/s** | capacity-only, slow |
| `--device Vulkan1 -ngl 22 -ub 512 -ctk/ctv q8_0` | **4.3–4.5 t/s — the exact optimum** | production config |

## Why dual-GPU loses on this box

Generation is serial through ALL layers per token → the slowest device bounds
total throughput. Measured: iGPU-only 1.5, dual 1.7 (the 1650's fast layers add
~0.2 t/s on top of the slowest leg), single-1650 4.5. The iGPU's only real niche
is CAPACITY: its 17.7 GiB shared heap fits the whole model where the 1650's 4 GiB
caps offload at 22/48 layers — relevant if a future goal is running a much bigger
model, not a faster one.

## Memory budget math (4 GiB heap, knife-edge)

Weights 3.4 GiB (ngl 22) + q8 KV + ub-512 compute buffers ≈ 3.6 GiB total,
~100 MiB slack. ngl 23/24 and ub 1024 each exceed it → `allocateMemory:
ErrorOutOfDeviceMemory` at load. Layers allocate all-or-nothing (~155 MiB per
Q4 12B layer). `nvidia-smi` used/free is the ground truth; a failed alloc with
"plenty free" means a foreign process holds the card.

## One-shot measurement harness (validated parity with server baseline)

```bash
timeout -k 5 290 ~/.local/llama-b10488/llama-cli -m ~/models/gemma-4-12b-it-Q4_K_M.gguf \
  --device Vulkan1 -ngl 22 -sm none -c 2048 -b 2048 -ub 512 -t 12 --temp 0 \
  -n 128 -p "Write a short essay about the city of Vancouver." --no-display-prompt \
  > /tmp/run.log 2>&1
grep -oE '\[ Prompt: [^]]+\]' /tmp/run.log
```

- Generation t/s from llama-cli matches the server baseline (4.3 vs 4.5) — no
  server round-trip needed for engine-speed comparisons.
- llama-cli runs server-mode: after the run it enters a REPL and, with stdin
  closed, echoes prompts forever — cap with `timeout -k 5` (TERM→KILL), never
  with `head` (SIGPIPE is ignored). Orphans hold VRAM and poison later runs;
  reclaim with `kill -9`, find with `pgrep -x llama-cli` (not `-f` — that
  matches your own eval'd command text).
- background-launched llama-server dies mid-init on this box; foreground
  (piped to `tee` was the reliable shape) survives. If the client and server
  are launched as two tool calls in one turn, they run SEQUENTIALLY — the
  client starts after the server's leash dies. Do measurement in ONE call.