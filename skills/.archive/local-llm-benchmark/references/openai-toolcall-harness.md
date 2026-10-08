# Driving a low-VRAM MoE quant through an OpenAI-compatible tool-calling loop

Session-derived debugging ladder (26B A4B Q3_K_M on a 4GB Vulkan box, llama-server :8080,
`/v1/chat/completions`). The exact sequence that turned a wrong "model can't do agents"
verdict into a closed, verified read→edit→bash loop. Read this before writing a fresh
tool-calling harness against a local quant.

## Symptoms observed (in order), and what each actually meant

1. **Uniform 2-tool-call ceiling, `finish=length`, at every budget (256/512/1024/2048).**
   With a bare task prompt, the model read the file, made one partial step, then burned the
   per-response budget on verbose narration and truncated before editing. Mis-read as a
   capability limit. REAL CAUSE: the loop coupled fix-*recall* (reproducing byte-exact
   `old_text`) into the *agent loop*, and the big quant is bad at recall → its failure mode
   is prose + truncation, not a refusal to use tools.
2. **Terser system prompt ("tool-first, no narration") helped a little** — forced a bash call
   but still no edit. Confirms the model CAN reach tools; the wall is the edit step.
3. **Supplying the exact edit (old_text + new_text) in the task** → model immediately did
   `edit_file` then `bash`, on-disk verified `$113,537.50`. THE DECOUPLING IS THE FIX.
4. **HTTP 400 `"Cannot have 2 or more assistant messages at the end of the list"`** right
   after a *successful* tool trail — the harness's own message-log format bug crashed the
   run before self-evaluation. The model had already done the work.
5. **`max_tokens=256` → 0 tool calls, `finish=length`.** Real per-response budget floor for
   tool-calling on this quant. 512 and 1024 both close the loop with `finish=stop`.

## Two durable rules

### 1. Decouple recall from the agent loop when benchmarking tool-use ability
An `edit_file` tool that needs byte-exact `old_text` makes a small/MoE quant either
re-apply stale matches (`Could not find the exact text`) or give up into prose. To
measure *agentic closure* (read→edit→bash), put the exact edit in the task. To measure
*independent reasoning*, leave it out — but never conflate the two. A model that closes
the loop with the edit supplied is agent-capable; it just can't recall source verbatim.

### 2. Normalize the message log — llama.cpp is strict about assistant↔tool alternation
llama.cpp's chat endpoint rejects any request whose last two messages are both
`assistant`. When a response carries `tool_calls` and the loop appends an assistant then
the tool replies, then the NEXT response is a bare final assistant message, the history
can end `assistant, assistant`. Coalesce every run of adjacent assistant messages before
each request (merge content, keep tool_calls) using a `normalize(msgs)` helper. Also
**capture the full HTTP error body** (`r.text[:300]`) — a bare "HTTP 400" is useless for
distinguishing a format bug from a real model failure.

## Harness loop skeleton (minimal correct version)

- per-request `max_tokens`: use ≥512 (256 is below the tool-call floor on this class).
- temperature 0.0 for reproducibility.
- on truncation (`finish=length`) WITH tool_calls → do NOT stop; append the tool replies and
  keep looping (a "length" is only terminal when it produced NO tool call).
- after every run, verify the on-disk artifact, never the model's printed claim.
- single-slot server: run budgets SEQUENTIALLY. Two concurrent harnesses cause llama.cpp
  task preemption/cancellation (`stop: cancel task`) that corrupts both.

## Engine reality on 4GB Vulkan under agent load
Idle decode ~5.7 t/s; under long-context multi-turn tool use drops to **~1.2–2.6 t/s**
(1024-token responses take 4–8 min). Budget wall-time accordingly; a successful closed
loop here was 327–550 completion tokens across 2–3 tool calls, finish=stop.
