# Local agent loops: generation A/B + hallucinated tool-execution (case study)

Tight follow-up to `local-inference-agent-benchmark.md` — the cross-generation A/B
run against the SAME pi + llama-server harness on 2026-08-18. Read the benchmark
reference first for the serve/wire/measure baseline.

## A/B result: Qwen3-4B vs Qwen3.8-4B (identical harness, thinking off)

| | Qwen3-4B (Q4_K_M) | Qwen3.8-4B (Q4_K_M) |
|---|---|---|
| Decode (server counters) | 31.7 t/s | 25.7 t/s (−19%) |
| Tool calls in session JSONL | read + edit + bash (3 events) | **zero** |
| File actually fixed on disk | ✅ verified | ❌ untouched |
| Reported total | $113,537.50 ✅ | $98,425.00 ❌ (= buggy baseline) |
| Agent-loop wall time | 25.5s | 31.8s |

**Verdict: newer ≠ better for local agentic use.** The newer generation was
slower AND failed the agent loop entirely while confidently narrating success.

## The hallucinated agent loop (Qwen3.8-4B case)

On the bug-fix task the model:
- narrated the file's contents as if it had read them (it had not),
- *invented* bash output (`total: $98425.00`) and reported it as "the fixed
  script",
- described in detail a fix that was never written; the file on disk stayed
  byte-identical to the buggy fixture.
- Session JSONL (`~/.pi/agent/sessions/<proj>/*.jsonl`) contained only
  `message` events — no read/edit/bash/write events at all.

### Detection tells (check ALL, cheap, ~30s)
1. Reported number == buggy baseline number → fix never landed.
2. Session JSONL has zero tool-key events (`"read"`, `"edit"`, `"bash"`,
   `"write"`) → the whole "fix" was narrated.
3. Artifact byte-identical to fixture (diff it).

### Capability vs loop-initiation isolation
The model CAN emit tool calls: hit `/v1/chat/completions` directly with a
`tools:` payload + an explicit "use the tool" instruction — Qwen3.8 emitted a
perfect function call in ~3s. So the failure is in *initiating* the agentic
loop under the harness (template/prompt behavior), not raw tool capability.
Implication: raw-benchmark + capability-probe results do NOT predict agent-loop
performance — always run the full agent task.

## Fair A/B procedure (hard-won)

1. Same harness, same prompt, same server flags; ONLY the model differs.
2. Restore the fixture to the buggy state with `write_file` (NOT `git checkout`
   — silently no-ops outside a git repo; NOT `cp` — you'll copy the *fixed*
   version as `.bak` on the second run).
3. Confirm the bug is live (script reproduces the buggy total) BEFORE the rerun.
4. `rm -rf ~/.pi/agent/sessions/<proj>/` so the JSONL you read is the new run.
5. Restart the server per model with `--chat-template-kwargs
   '{"enable_thinking": false}'` and confirm `/v1/models` shows the right ID.

## Generation naming trap (user-facing)

Qwen3, Qwen3.5, Qwen3.8 are distinct generations. A user asking "did you try
Qwen 3.8" may be catching YOU a generation behind. Before benchmarking a
family, enumerate the current lineup:
`curl "https://huggingface.co/api/models?search=qwen3.8"` (also try
`qwen3.5`, `qwen%203.8`). As of 2026-08: Qwen3.8 flagship = 27B (official +
unsloth GGUF); 3.8-4B exists only as a community GGUF
(`empero-ai/Qwen3.8-4B-GGUF`), not an official release. Name the generation you
actually tested in every report to avoid implying the current one.

## GGUF mirror download hygiene

Community quant mirrors bypass HF auth-gating (official QQ GGUF repos 401
unauthenticated). For a mirror repo:
1. List sizes: `curl -s "https://huggingface.co/api/models/<repo>/tree/main"`.
2. Download: `curl -sL --fail <repo>/resolve/main/<file>.gguf -o <file>` —
   `-L` is mandatory; without it a plain fetch returns "Temporary Redirect"
   text instead of the binary.
3. **Verify SHA256 against the repo's SHA256SUMS** before loading a multi-GB
   mirror binary: fetch sums with `curl -sL` (bare `-s` returns a redirect
   body), then `sha256sum <file>` vs the listed digest. Verified example:
   `empero-ai/Qwen3.8-4B-GGUF` Q4_K_M `dec96e8c…` matched.