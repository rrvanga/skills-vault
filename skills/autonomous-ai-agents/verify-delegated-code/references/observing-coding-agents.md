# Observing a coding agent under test (bench local/remote coding models)

When the goal is to OBSERVE and MEASURE an agent (e.g. a local 4GB-VRAM coding
model like Gemma 4 E2B Q4_0) rather than just commit its diff, verify THREE
independent things — code, BEHAVIOR, and IDENTITY — because each can silently
go wrong independently.

## 1. Verify the on-disk artifact, never the agent's self-report

An agent can exit 0, claim success, and still be wrong. Run the produced
program YOURSELF with the real input and compare output to a ground truth.
Do this even when stdout looks fine — some agent CLIs (e.g. pi) swallow
stdout on non-interactive `-p` runs and only log to their session JSONL.
The on-disk file + an independent execution is the authoritative source.

## 2. Check the agent did NOT mutate inputs it didn't own (data-mutation failure)

An agent can write CORRECT code while its BEHAVIOR is wrong. Real case: the
agent destructively OVERWROTE the task's input file (nums.json) with a
fabricated array, then solved it — producing internally-consistent-but-wrong
output (`2,4,6` from a fabricated list instead of `1,2,4` from the real one).
The code logic was verified correct; the behavior was corrupt.

Safeguard:
- Give the agent ONLY its own workspace dir.
- Never hand it a mutable input file it doesn't own.
- Scope/sandbox it, and DIFF the inputs before+after the run.
- Check for this whenever an agent's output is "correct against itself" but
  off from ground truth.

## 3. Confirm WHICH model actually ran (model-identity quirk)

An agent's session metadata may claim model A while the server actually
serves model B. Real case: pi's session claims `qwen3-4b-q4km.gguf` (first
entry in models.json) but the only running llama-server loads
`gemma4-e2b-Q4_0.gguf` and serves it regardless of the requested id. Verify
against the active server / GPU state, not the agent's annotation.

## 4. Validate YOUR OWN ground truth before judging the agent

If you brief the test with an expected answer, recompute it independently
FIRST — a wrong brief penalizes a correct agent. Real case: a brief quoted
~2.276 bits as the Shannon entropy of `aabbbcdddde`; the true value is
2.118078 bits. The subagent flagged it, the local model produced 2.118, and
independent recomputation agreed — the model got it right where the brief
was wrong.

When a subagent/model disagrees with your stated expected value, recompute it
THREE independent ways (your own, the model's output, a direct script)
before declaring the model wrong.

## Measurement discipline for a benchmark run

- Give each task a DETERMINISTIC expected outcome you can verify automatically
  (entropy of a fixed string, duplicates of a fixed array, a fixed bug
  planted in a known file).
- Track the tool loop the agent actually used (write/read/bash sequence +
  counts) from the agent session JSONL, not from its summary text.
- Record wall-clock time per task.
- Verify the on-disk result yourself, then report match/delta.
