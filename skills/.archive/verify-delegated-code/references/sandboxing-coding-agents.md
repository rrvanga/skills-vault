# Sandboxing a CLI coding agent (filesystem confinement + read-only inputs)

The machine-level fix for an autonomous agent that can read/write/run shell
with your full permissions is filesystem confinement with **bubblewrap**
(`bwrap`, user+mount namespace, NO root needed). Validated on Arch against a
pi-style agent (Node CLI) driving a local llama-server on 127.0.0.1:8080.

## Why containment, not just precautions

A small local coding model, pointed at a real input file, will (deterministically):
read nothing → hallucinate data → OVERWRITE the real file with its invention →
report the invented answer with full confidence. In a real project dir this
silently destroys source/config. The sandbox doesn't stop that inner behavior,
but it confines the blast radius to the workspace AND (with read-only inputs)
removes the escape hatch so the model reads real data.

## Whole-FS read-only recipe (protects the machine)

```
bwrap --die-with-parent --ro-bind / / \
  --bind "$WORKSPACE" "$WORKSPACE" \        # rw: ONLY place the agent creates files
  --bind "$HOME/.pi" "$HOME/.pi" \          # rw: agent's own config + session state
  --tmpfs /tmp \                            # private empty scratch — dies with ns
  --dev /dev --proc /proc --dev-bind /sys /sys \
  --chdir "$WORKSPACE" \
  --unshare-pid --unshare-ipc --unshare-uts \
  -- /usr/bin/env node /path/to/cli.js "$@"
```

- `--ro-bind / /` makes the whole tree read-only; writable dirs are re-bound on
  top in later `--bind` flags.
- Keep the network namespace — do NOT `--unshare-net` — so the agent still
  reaches the model server (which runs OUTSIDE the namespace on :8080).
- The agent needs its own config dir writable (e.g. `~/.pi` for sessions/models).
  Everything under home stays read-only unless explicitly re-bound.
- `--die-with-parent` ensures the namespace dies if the wrapper watcher dies.

## Read-only INPUT mount (protects the task — the important part)

The sandbox protects the machine but NOT the task: the writable workspace lets
the agent clobber its own input. Mount the input READ-ONLY so it literally
cannot overwrite:

```
BIN=$(basename "$INPUT_DIR")
bwrap ... \
  --ro-bind "$INPUT_DIR" "$INPUT_DIR" \          # see but not modify
  --ro-bind "$INPUT_DIR" "$WORKSPACE/$BIN" \     # also visible at workspace path
  ...
```

**Verified behavior change:** with the input writable, the model hallucinated a
whole new dataset and overwrote the file; with the input mounted read-only it
was FORCED to read the real file and reported it back word-for-word (md5
unchanged). Read-only input doesn't just prevent damage — it changes the model's
honesty by removing the "invent the data" path.

## Verify containment every run

- md5sum the guard dirs (`~/.ssh`, `~/.hermes/state.db`) and the input file
  before/after; expect byte-identical.
- A changed mtime on a busy hub dir like `~/.hermes` is usually ambient crons /
  gateway heartbeat / bridge FETCH_HEAD — check WHICH files changed, don't
  assume the agent wrote there (it can't; they're read-only in the namespace).
- Always run the produced program yourself with the real input and compare to
  ground truth (on-disk verification, never the agent's summary).

## Residual / known limits

- **Read exposure is NOT closed**: `--ro-bind / /` lets the agent READ anything
  (e.g. `~/.ssh` key contents, `~/.hermes/.env` secrets) even though it can't
  modify it. If the agent will touch a secret-bearing repo, tighten to explicit
  `--ro-bind` of only trusted dirs instead of the whole tree.
- The writable *output* dir is implicitly trusted to create files — scope it
  small and clean it between runs.

## Reference wrapper (Arch, this box)

`~/.local/bin/pilm` is a working sandboxed wrapper for the pi agent → local
Gemma E2B Q4_0 :8080. Whole FS ro except `~/sandbox-lm` (workspace) + `~/.pi`;
`pilm -i <dir>` mounts an input dir read-only; `pilm -w <dir>` overrides the
workspace. Run as `pilm -i <input> -w <work> -p "<task>"`.
