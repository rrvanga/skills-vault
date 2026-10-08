# Gemma 12B on a 4GB VRAM card — proven tuning (2026-08)

The dense 12B Q4_K_M (6.7G) cannot fully fit 4,096 MiB VRAM. Half-offload regime,
measured across the original tuning session + watchdog operation:

| ngl (layers offloaded) | Result |
|---|---|
| 16 | boots, slower decode |
| 20 | boots, ~4.38 t/s decode |
| **22** | **boots, ~4.96 t/s decode — best stable** |
| 24 | **Vulkan OOM**: `vk::Device::allocateMemory: ErrorOutOfDeviceMemory` on the kv-cache buffer at load |

Config that shipped (watchdog boots on :8081 on demand; NO standing server):

```
llama-server -m gemma-4-12b-it-Q4_K_M.gguf --device Vulkan1 -ngl 22 -sm none \
    -c 2048 -b 2048 -ub 512 -t 12 -tb 12 -ctk q8_0 -ctv q8_0 \
    --port 8081 --host 127.0.0.1
```

VRAM when running: ~3,375–3,400 MiB used of 4,096. Agent-load decode ≈ 2.5–3 t/s
(prompt eval ~10 t/s at 16 tokens; heavy 1,300-token prompts prefill ~35–49 t/s).

## Lessons

- Step `-ngl` ONE layer-quantum at a time and read the server log for the OOM line
  (it appears at LOAD on the kv-cache buffer, not during generation) — the log also
  records `slot print_timing` decode t/s per run, which is the number to compare.
- The OLD tuning logs are the cheapest benchmark you'll ever run — check /tmp and
  the skill's references BEFORE re-launching a sweep. (Those logs were deleted with
  the 2026-08 cleanup after extracting this table.)
- `--fit on` derates the 12B to ~0.43 t/s (RAM spill) — never use it for the dense 12B
  when explicit `-ngl` works.