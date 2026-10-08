# Sandboxing an agentic CLI (bubblewrap) — class-level pattern

Running a coding agent (`pi`, and by extension Claude Code / Codex / any
agent that can exec bash) with the user's real permissions is dangerous: it can
silently WRITE any file the user can, including destructive edits to inputs it
should only read. This came directly from a real failure: the local E2B agent,
asked to READ `nums.json` and print duplicates, instead OVERWROTE `nums.json`
with a fabricated array. Good code, destructive behavior.

The fix is OS-level containment, not convention. `bubblewrap` (`bwrap`, on
Arch `/usr/bin/bwrap`) gives a private mount namespace where paths outside the
workspace do not resolve writable — they physically cannot be modified.

## The recipe (as `scripts/pilm` — copy & adapt)

The wrapper binds the WHOLE FS read-only (`--ro-bind / /`), then re-binds a
small set of paths writable on top:

| Path | Writable? | Why |
|---|---|---|
| `~` (whole FS) | NO (`--ro-bind / /`) | default: read-only everywhere |
| `~/sandbox-lm` | YES (`--bind`) | the workspace the agent creates files in |
| `~/.pi` | YES (`--bind`) | pi's own config + session JSONL (it must write these) |
| `/tmp` | private tmpfs (`--tmpfs`) | scratch is fresh each run; real /tmp untouchable |
| `/dev /proc /sys` | dev-bind / bind | runtime necessities |
| network | open (no `--unshare-net`) | agent needs to reach the llama-server on :8080 |

Key flags: `--die-with-parent` (sandbox dies if the wrapper dies), and the
`--unshare-{pid,ipc,uts}` for good measure. Run via `-- /usr/bin/env node
<cli.js> "$@"` so all of pi's CLI args pass through.

## Verified containment (actually tested, not assumed)

With `--ro-bind / /` + the above writable exceptions:
- write to workspace → **succeeds**
- write to `~/.hermes/models.json` → **Read-only file system** (blocked)
- write to `~/.ssh/evil` → **Read-only file system** (blocked)
- write to real `/tmp` → invisible; lands on a private tmpfs that dies with the namespace

Test before trusting a new sandbox config with a shell probe like:
```bash
bwrap --die-with-parent --ro-bind / / \
  --bind "$HOME/sandbox-lm" "$HOME/sandbox-lm" \
  --bind "$HOME/.pi" "$HOME/.pi" --tmpfs /tmp \
  --dev /dev --proc /proc --dev-bind /sys /sys /bin/sh -c \
  'echo hi > ~/sandbox-lm/ok.txt && echo WRITABLE; \
   echo x > ~/.hermes/x 2>&1 || echo BLOCKED_ON_HERMES'
```

## Security posture — what this does and does NOT stop

- **Stops (fully):** destructive *writes* anywhere outside the workspace —
  the exact clobber-input failure mode. This is the highest-severity agent
  risk and the reason to sandbox.
- **Does NOT stop:** *reads*. The whole FS is mounted read-only but still
  READABLE, so an agent could exfiltrate file contents (e.g. `.ssh` private
  keys, `.hermes/.env` secrets) even though it can't modify them. If the agent
  will see repos/sensitive dirs, this residual read exposure matters and you
  should tighten to explicit `--ro-bind` of only trusted dirs (`/usr`, `/bin`,
  `/lib`, `/lib64`, node's package dir, the model's config) instead of `/`.
- **Rank hinting:** keep the agent's cwd inside the sandbox (`--chdir` the
  workspace). Model paths are resolved inside the namespace, so give pi a
  relative target file inside the workspace and run the wrapper from there.

## Operational notes

- Check `which bwrap unshare` first; on Arch both ship by default.
- The sandbox still needs network to reach the model server — do NOT add
  `--unshare-net` or the agent can't talk to `:8080`.
- `~/.pi` writable is required but it is pi's OWN state, not user data — an
  acceptable, narrow exception. Never make a broad user dir (e.g. `~/.hermes`,
  `~/Documents`, a git checkout with secrets) writable.
