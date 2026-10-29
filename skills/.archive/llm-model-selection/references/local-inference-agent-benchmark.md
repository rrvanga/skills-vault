# Local inference: serving to an agent CLI + benchmarking (validated recipe)

Operational layer of local-model work: pick the quant (see
`local-inference-vram-sizing.md`), then serve it, wire an agent, measure it.
Validated 2026-08-18 end-to-end on a 2019 i7-9750H / GTX 1650 Mobile 4GB /
24GB RAM laptop (Vulkan build, Qwen3-4B-Instruct Q4_K_M 2.5GB) — same wiring
shape the B70 eGPU build uses (llama-server → OpenAI-compatible :8080 → pi).

## 1. Serve (llama-server, OpenAI-compatible)

```bash
llama-server -m <model>.gguf -ngl 99 --host 127.0.0.1 --port 8080 -c 8192
```

- `-ngl 99` = full GPU offload. A 2.5GB Q4-4B model fits a 4GB card with KV headroom.
- **No CUDA toolkit (`nvcc` absent)? Use the prebuilt Vulkan build** —
  `llama-bNNNNN-bin-ubuntu-vulkan-x64.tar.gz` from GitHub releases works on
  NVIDIA/AMD/Intel without any install. Skip building CUDA from source on old
  Turing cards; gains are marginal for a 4GB class.
- Health: `curl http://127.0.0.1:8080/health` → `{"status":"ok"}`.
- Model ID at `/v1/models` = the **GGUF filename** (e.g. `qwen3-4b-q4km.gguf`).
  Use that exact ID in client configs.
- Check the log lines (`slot print_timing`) — server exposes its own
  authoritative counters: `prompt eval time` (prefill t/s) and `eval time`
  (decode t/s), e.g. `eval time = 7875.92 ms / 250 tokens = 31.62 t/s`.
  Use these instead of wall-clock (wall includes client overhead + TTFT).

## 2. PITFALL: Qwen3-family default thinking ON → empty `content`

On a plain `/v1/chat/completions` call, Qwen3 models default to **thinking
enabled**: the whole `max_tokens` budget gets burned in `reasoning_content`
and the response comes back with **empty `content`** and
`finish_reason: "length"`. Looks like a refusal/hang; it's a budget burn.

- Diagnose: response `message` has a huge `reasoning_content` and empty `content`.
- Fix at server level (applies to all requests — right choice for agent use):
  `llama-server --chat-template-kwargs '{"enable_thinking": false}'`
- Per-request alternative: send `"chat_template_kwargs": {"enable_thinking": false}`
  in the body.
- **Measured: 2.5× agent-loop speedup** — same pi bug-fix task, 64.2s →
  25.5s, and the no-thinking output was *cleaner*. Default it off for coding
  agents; re-enable only when visible reasoning is wanted.

## 3. Wire the `pi` agent CLI

`pi` = `@earendil-works/pi-coding-agent` (npm, 93K★). Uses local OpenAI-compatible
endpoints via a provider config at `~/.pi/agent/models.json`. Works alongside
`opencode`; the jeffgrover b70 repo ships a proven multi-model version
(`configs/pi-models.json`).

Install (user-writable prefix needed): `npm config set prefix ~/.local && npm
install -g @earendil-works/pi-coding-agent`

Single-model config (full known-good template: `templates/pi-models.json`):

```json
{ "providers": { "local-gpu": {
  "baseUrl": "http://127.0.0.1:8080/v1",
  "api": "openai-completions",
  "apiKey": "sk-local",
  "compat": { "supportsDeveloperRole": false, "supportsReasoningEffort": false },
  "models": [{
    "id": "qwen3-4b-q4km.gguf",
    "name": "Qwen3-4B-Instruct Q4_K_M (local)",
    "reasoning": true,
    "input": ["text"],
    "compat": { "supportsDeveloperRole": true, "supportsReasoningEffort": false },
    "contextWindow": 8192,
    "maxTokens": 4096
  }] } } }
```

- `apiKey` is arbitrary (`sk-local`) — llama-server doesn't check it; pi requires the field.
- `contextWindow`/`maxTokens` must match server `-c`.
- Run: `pi --provider local-gpu --model qwen3-4b-q4km.gguf --print "<task>"`

## 4. Benchmark an agent loop (not just raw tokens)

1. Raw engine numbers: read server `print_timing` counters (step 1) — ground truth.
   (`llama-bench` may fail to create a context on dual-Vulkan-device machines;
   don't burn time — use the server counters instead.)
2. Agent numbers: `time timeout 240 pi --provider … --print "<task>"` and derive
   t/s from `usage` in the response.
3. **Verify the agent actually did the work — never trust the self-report:**
   - re-run the produced artifact yourself (`python3 invoice.py entries.json`)
   - confirm tool calls fired: inspect the session JSONL at
     `~/.pi/agent/sessions/<project>/<timestamp>.jsonl` — grep for `"read"`,
     `"edit"`, `"bash"`, `"write"` tool keys.
4. A/B configs: restart server per config, restore the fixture to identical
   pre-task state, `rm -rf ~/.pi/agent/sessions/<proj>/`, rerun.

## Measured reference (GTX 1650 4GB, Qwen3-4B Q4_K_M, Vulkan)

- Decode ~31.7 t/s steady (27–33 across runs); prefill ~42 t/s cold, ~118 t/s cached.
- 512-token response ≈ 16.6s wall; full pi bug-fix loop 25.5s (thinking off).
- 4B-class Q4 on a 4GB Turing card = usable small-agent box; 7B+ dips below
  ~10 t/s without better GPU. This validates the software layer of the B70
  plan — the card swap just scales t/s (reference box: 35B-class at 81.6 t/s).

## Model sourcing note

Some org GGUF repos (e.g. `Qwen/Qwen3-4B-Instruct-GGUF`) 401 unauthenticated on
the tree API. Fallback that worked: search `/api/models?search=<model>-gguf`,
probe `resolve/main/<file>` HEAD codes, and pull from community quant repos
(e.g. `llmware/qwen3-4b-instruct-gguf`, 2.5GB `Qwen3-4B-Q4_K_M.gguf`).