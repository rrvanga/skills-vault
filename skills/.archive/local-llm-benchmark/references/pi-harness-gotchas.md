# pi Harness Operational Gotchas (local LLM agent tool-use bench)

Verified while benchmarking Gemma 4 E2B variants (plain + Cactus hybrid) as harness agents.
All of these cost real cycles when missed — read before running a `pi` agent test.

## 1. Non-interactive mode: you MUST pass `-p` / `--print`

Without `-p`, `pi` drops into its interactive TUI. A long bug-fix prompt in a
redirected or background context then HANGS (waiting on the TUI) and produces
**0 bytes of stdout**.

```bash
pi --provider local-gpu --model <model-id> --approve -p "There is a bug in ... fix it ..."
```

`--approve` (-a) trusts project-local files so the tool loop can run un-attended.

## 2. Background runs swallow stdout to 0 bytes even when the agent loop ran fine

Running `pi` in a background shell with `> out.log` often yields an EMPTY log
even though the model executed a full read→edit→bash loop correctly. **The
session JSONL is the authoritative record, not stdout.**

Find it under:
```bash
ls -lat ~/.pi/agent/sessions/<session-dir>/*.jsonl
```
A real multi-tool-trail session is ~10–20 KB; a trivial single reply is ~1.5 KB.

## 3. The definitive fix check is the on-disk FILE, not pi's printed answer

Never trust empty stdout as "it failed." Verify the actual artifact:
```bash
cd /tmp/pi-bench && python3 invoice.py entries.json   # -> total: $113537.50 == SUCCESS
```
An empty stdout + a correctly-fixed file is SUCCESS, not failure.

## 4. Verify tool trails from the JSONL, matching the RIGHT session

Each JSONL has a `model_change` header + user message. A stale run (e.g. a
previous "say CONFIRMED" smoke test) may sit in the SAME `--tmp-pi-bench--`
folder. Match the session **timestamp / id** to your run, and grep the tool calls:
```bash
for f in ~/.pi/agent/sessions/--tmp-pi-bench--/*.jsonl; do
  echo "--- $(basename $f) ---"; grep -o '"toolName":"[a-z]*"' "$f" | sort | uniq -c
done
```
Read count `read`/`edit`/`bash`/`write`. A clean pass = read → edit success
("Successfully replaced 1 block(s)") → bash (ran script, correct total).
A weak pass gets stuck re-applying a stale edit: `Could not find the exact text in ...`

## 5. pi won't auto-discover a served model — register it first

`pi --provider local-gpu --list-models` only shows models registered in
`~/.pi/agent/models.json` under the `local-gpu` provider (baseUrl
`http://127.0.0.1:8080/v1`). Add your candidate with a `model_change`-capable
entry (id/name, copy shape of an existing entry) before `--model <id>` works:
```bash
# patch ~/.pi/agent/models.json providers.local-gpu.models[] to add {"id": "<gguf-name>", "name": "..."}
```

## 6. Run the agent test at least twice

The SAME model on the same task can close the loop cleanly one run and hit the
`Could not find the exact text` edit-match wall the next (observed on both plain
and hybrid E2B). Judge average robustness across 2+ runs, not one clean pass.

## 7. Engine numbers: measure under agent load, not isolated completions

A bare `chat/completions` short call reports optimistic decode (e.g. ~15 t/s).
Under a real multi-turn tool-use session (long system prompt + growing tool
results) the same engine drops to ~8 t/s. Pull the real figure from the
llama-server log during the pi run:
```bash
grep "print_timing" /tmp/<server>.log | grep -oE "tg = +[0-9.]+ t/s" | tail
```
Also note: a vendor-PINNED llama.cpp build (older tag, e.g. b10076) can be
2–4× slower decode than a current-release build (b10488) on the same family —
that's a BUILD penalty, not a model-quality verdict.
