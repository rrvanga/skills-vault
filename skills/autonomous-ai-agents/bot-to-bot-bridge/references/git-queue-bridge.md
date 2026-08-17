# Git-Queue Bridge — Deployed Instance & Working Client

Session reference (2026-08-15): bridge between @<REDACTED>_hermes_bot (host:
<REDACTED>, Arch) and @<REDACTED> (Kaush's host). Repo:
`philocalist/bot-bridge` (private, org admin via `gh` as <REDACTED>).

## Deployed layout

```
~/.hermes/bridge-repo/          # clone on this host
  README.md                     # protocol spec (schema, security, ordering)
  bridge.py                     # client, same file both bots use
  outbox/slowpoke/              # <REDACTED> writes here; dvipru polls
  outbox/dvipru/                # dvipru writes here; <REDACTED> polls
  .seen_id                      # last-processed id (incremental recv)
```

Cron: `bot-bridge-watch` — monitor_script `~/.hermes/scripts/bridge_poll.sh`
(runs `BRIDGE_NAME=<REDACTED> python3 bridge.py recv`), every 2m, stdout
hash-gated (agent only wakes when a new message appears). Toolsets restricted to
terminal+file to keep wake-ups cheap.

## Working client (bridge.py)

```python
#!/usr/bin/env python3
"""bot-bridge — git-queue message client. Usage:
  bridge.py send <to> <kind> "<body>"
  bridge.py recv                 # pull + print new msgs from peer dir
  bridge.py ping <to>            # send ping, poll for pong
  bridge.py sync                 # pull, print ALL messages
Set BRIDGE_NAME=<bot> (<REDACTED> | dvipru)."""
import json, os, subprocess, sys, time
from datetime import datetime, timezone

REPO = os.path.expanduser("~/.hermes/bridge-repo")
STATE = os.path.join(REPO, ".seen_id")
MY_NAME = os.environ.get("BRIDGE_NAME", "<REDACTED>")
OUTBOX = {"<REDACTED>": "slowpoke", "dvipru": "dvipru"}
MY_DIR = OUTBOX.get(MY_NAME, MY_NAME)
PEER = "dvipru" if MY_NAME == "<REDACTED>" else "<REDACTED>"

def git(*args):
    r = subprocess.run(["git", "-C", REPO, *args], capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {r.stderr.strip()}")
    return r.stdout.strip()

def next_id():
    ids = []
    for root, _, files in os.walk(os.path.join(REPO, "outbox")):
        for fn in files:
            if fn.endswith(".json"):
                try: ids.append(int(fn.split("-")[-1].split(".")[0]))
                except ValueError: pass
    return max(ids) + 1 if ids else 1

def last_seen():
    try:
        with open(STATE) as f: return int(f.read().strip())
    except (OSError, ValueError): return 0

def set_last_seen(i):
    with open(STATE, "w") as f: f.write(str(i))

def send(to, kind, body):
    git("pull", "--rebase", "--quiet")
    i = next_id()
    msg = {"id": i, "from": MY_NAME, "to": to,
           "ts": datetime.now(timezone.utc).astimezone().isoformat(),
           "kind": kind, "body": body}
    outdir = os.path.join(REPO, "outbox", MY_DIR)
    os.makedirs(outdir, exist_ok=True)
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%f")
    path = os.path.join(outdir, f"{ts}-{i:04d}.json")
    with open(path, "w") as f: json.dump(msg, f, indent=2)
    git("add", "outbox", ".seen_id" if os.path.exists(STATE) else "README.md")
    git("commit", "--quiet", "-m", f"bridge {i:04d} -> {to}")
    git("push", "--quiet")
    print(f"sent #{i:04d} {kind} -> {to} (outbox/{MY_DIR})")

def recv(print_all=False):
    git("pull", "--rebase", "--quiet")
    seen = 0 if print_all else last_seen()
    msgs = []
    peer_dir = os.path.join(REPO, "outbox", OUTBOX.get(PEER, PEER))
    if not os.path.isdir(peer_dir):
        print("(peer outbox dir not present yet)"); return msgs
    for fn in sorted(os.listdir(peer_dir)):
        if not fn.endswith(".json"): continue
        with open(os.path.join(peer_dir, fn)) as f: m = json.load(f)
        if m["id"] <= seen: continue
        msgs.append(m)
        print(f"[#{m['id']:04d}] {m['from']} ({m['kind']}) -> {m['to']}: {m['body']}")
    if msgs: set_last_seen(max(m["id"] for m in msgs))
    return msgs

def ping(to, timeout=60):
    send(to, "ping", "ping")
    deadline = time.time() + timeout
    while time.time() < deadline:
        for m in recv():
            if m["kind"] == "ping" and m["from"] == to:
                print(f"pong from {to}: {m['body']}"); return True
        time.sleep(5)
    print("no pong within timeout"); return False

if __name__ == "__main__":
    if len(sys.argv) < 2: print(__doc__); sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "send" and len(sys.argv) == 5: send(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "recv": recv()
    elif cmd == "sync": recv(print_all=True)
    elif cmd == "ping" and len(sys.argv) == 3: ping(sys.argv[2])
    else: print(__doc__); sys.exit(1)
```

## Pitfalls confirmed in the wild

1. **Empty dirs not tracked by git** — `outbox/` disappeared on clone until a
   `.gitkeep` was committed; first run threw `FileNotFoundError`.
2. **Filename format = id counter contract**. Legacy flat names (`0001_name.json`)
   made `next_id()` (which splits on `-` then `.`) silently restart at 1, cloning
   an existing id. Renamed to `20260815T194805-0001.json` shape; verified ids 1,2,3
   monotonic afterwards.
3. **Peer proposed a second repo** (`philocalist/bridge`) after `bot-bridge`
   existed — resolution: adopt the peer's better structure (per-bot outbox dirs)
   into the existing repo instead of creating a duplicate.
4. **Send direction bug**: first cut wrote to the RECIPIENT's outbox dir; in the
   outbox model each bot writes ONLY to its own dir and polls the peer's. The
   `print` also showed the wrong dir — patch both together.
5. **git pull --rebase + push**: concurrent commits are safe because each bot
   writes to a distinct path; still rebase-pull before commit to keep history
   linear.

## Next steps (as of session end)

- Generate deploy key for Dvipru's host (scoped read/write to `bot-bridge` only).
- Dvipru's operator: clone repo, `BRIDGE_NAME=dvipru bridge.py recv` to see
  messages #0001-#0003, reply with a ping.
