---
name: pii-safe-public-publishing
description: "Publish personal content publicly with a no-PII guarantee."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [PII, Redaction, GitHub, Publishing, Security]
    related_skills: [github-repo-management, hermes-cron-operations]
---

# PII-safe public publishing

Publish personal content (skills, notes, configs) to a PUBLIC repo (or any shared destination)
while honoring a hard "no PII ever" constraint. Proven on `~/.hermes/skills` →
`<REDACTED>/skills-vault` (public, 526 files, daily auto-sync, zero PII leaks).

## Non-negotiables (in order)

1. **User decides owner + visibility BEFORE building** (personal vs org, public vs private).
   Public raises the stakes — say so explicitly.
2. **Recon first.** `find` the tree; grep for existing PII before promising anything:
   `/home/<user>` paths, emails, usernames, real-looking credentials
   (`gh[pous]_`, `sk-`, `glpat-`, `xox[baprs]-`, `AIza`, `AKIA`, long hex/base64).
   Real hits found → redaction is mandatory, not optional.
3. **Staged copy, never in place.** Copy source → staging dir → scrub there. Local stays the
   canonical source of truth; the remote is a SANITIZED MIRROR (paths/names masked — byte-exact
   and PII-free are mutually exclusive; name that trade-off to the user).
4. **Scrub list lives OUTSIDE the mirrored tree** (e.g. `~/.hermes/scripts/<name>_pii.txt`),
   one regex per line, case-insensitive. Replace hits with `<REDACTED>`. Keep config-key NAMES
   (`OPENCODE_GO_API_KEY`) — identifiers are not secrets; only values get scrubbed.
5. **Guard scan = hard abort, not a warning.** Re-run the PII scan on the STAGED copy after
   redaction. ANY remaining hit → abort commit, alert the user, NEVER push. Fail closed.
6. **Commit with a neutral identity.** Automated commits inherit global git config — a personal
   email would leak into public history. Pin repo-local (never `--global`):
   ```bash
   git config user.name "<handle>-bot"
   git config user.email "<REDACTED>"   # GitHub no-reply
   ```
7. **Verify what the PUBLIC actually sees — clone it back.** After push, fresh clone to /tmp,
   re-run the PII grep against the CONTENT dir. Expect hits ONLY in `.git/` internals (repo URL
   handle is inherent to the public choice; commit author is the neutral bot identity).
8. **Daily automation = cron script-only.** `no_agent=true`, `script=<sync>.sh`:
   stage → scrub → guard → `git add -A` → diff empty ? exit 0 with EMPTY stdout (silent tick) :
   commit + push + short summary. Non-zero exit → error alert. Run once manually after wiring,
   confirm exit 0, then grep the remote tree to confirm it matches.

## Pitfalls

- **Malformed cron expressions**: `0 9 45 * *` = "09:00 on the 45th" (invalid, rejected). Use
  `45 9 * * *` for 09:45 daily.
- **Push failure before repo exists** is the designed alert path at first run — create the
  remote (`gh repo create NAME --public --source . --remote origin --push`) and rerun.
- **Guard scans regex patterns you listed.** A NOVEL PII shape (new username, new email domain)
  passes. Say so honestly; offer private visibility as belt-and-braces; keep the scrub list
  extensible.