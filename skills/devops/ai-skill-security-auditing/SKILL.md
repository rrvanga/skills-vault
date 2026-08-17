---
name: ai-skill-security-auditing
description: Use when auditing AI-agent skill libraries for security.
---

# AI Skill Library Security Auditing

Audit an AI agent's skill library (e.g. `~/.hermes/skills/`) for malicious or risky
content — prompt injection, data exfiltration, privilege escalation, supply-chain /
rug-pull risk, excessive agency. Uses NVIDIA **SkillSpector** (Python CLI, 69 patterns
across 17 categories). Produces a verdict humans can trust, not just a wall of findings.

## When to use

- User asks to vet/scan the skill library (e.g. "check my skills for malware",
  "audit skills", "scan my skill library").
- A new skill is added from a third-party source and you want a security gate.
- Periodic hygiene scan of the whole library.

## Install

```bash
uv tool install git+https://github.com/NVIDIA/skillspector.git   # or `--from ... @<commit>` to pin
env -u PYTHONPATH ~/.local/bin/skillspector --version
```

Reversible: `uv tool uninstall skillspector`. No system-wide changes.

## CRITICAL environment quirk (this machine)

`skillspector` **crashes on startup with `pydantic_core` failing to import** unless
launched with `env -u PYTHONPATH`. Root cause: this box's `PYTHONPATH` points at the
Hermes source venv's **Python 3.11** site-packages, which shadows the uv tool's own
**3.12** `pydantic_core` build → compiled-extension ABI mismatch (the `.so` is
`cpython-311`, the interpreter is 3.12). Do NOT edit shell config or remove PYTHONPATH
(the `hermes` CLI needs it to run from source) — strip it **per-process**:

```bash
env -u PYTHONPATH ~/.local/bin/skillspector scan "$HOME/.hermes/skills/" \
  --no-llm --format json --output /tmp/skills_scan.json
```

Apply the same `env -u PYTHONPATH` prefix to ANY Python CLI installed via `uv tool`
(pydantic-style tools hit the identical ABI crash).

## Scan workflow

1. **Static scan first** (`--no-llm`): no API key, fast, deterministic. JSON output to
   `/tmp` (reports are hundreds of KB — never dump into chat).
2. **Summarize** with the bundled script (`scripts/summarize_scan.py`), which writes its
   rollup to a file (long terminal output collapses to `1 lines` on this box + Python
   file access is blocked — always `write_file` the script, redirect output to `/tmp`,
   read it back with `read_file`).
3. **Verify before reporting**: read the actual flagged source lines with `read_file`.
   Static scanners keyword-match; most HIGH flags are false positives (see playbook).
4. Report honestly: counts by severity/category, the verified-benign classes, and the
   short list of genuinely actionable items.

## Report schema (JSON)

Top-level keys include `issues[]`; a whole-directory scan registers as ONE target
(`name: "unknown"`) with per-file locations — don't be confused by that. Issue fields:

`id` (rule id, e.g. `AST4`, `RP1`, `PE3` — NOT `rule_id`), `category`, `pattern`,
`severity` (LOW/MEDIUM/HIGH), `confidence` (0–1), `location{file, start_line, end_line}`,
`finding` (matched code line), `explanation`, `remediation`, `code_snippet`,
`intent` (null in `--no-llm` mode), `tags` (may be empty).

With `--no-llm` the top-level overall `score` may be `None` — judge from per-issue
severity counts, and never claim semantic/intent verdicts the static pass didn't make.

## Interpretation playbook (observed false-positive classes — verify, don't parrot)

- **Data Exfiltration on `dict(os.environ)` / `os.environ.copy()`** → pytest subprocess
  isolation and child-CLI env passthrough. Benign.
- **Privilege Escalation "Credential Access" on `.env` / "access tokens" / `/etc/passwd`**
  → documentation mentions or the skill's actual purpose (e.g. github-auth handling
  credential files). Benign at conf < 0.7; check conf=0.9 hits by reading the line.
- **Dangerous Code Execution on `subprocess.run(...)`** → safe when args are a LIST with
  no `shell=True`. Benign.
- **Rogue Agent / Excessive Agency on argparse `--help` strings** (e.g. "Overwrite
  existing files", "return prompt_id", "without waiting") → keyword matches. Benign.
- **Hidden Instructions on HTML `<!-- comments -->` in templates** → author hints, not
  injected prompts. Benign.
- **YARA `mcp_tool_poisoning_metadata` on frontmatter `metadata:` key / `description:`
  line** → metadata keywords. Benign.
- **External Script Fetching (SC2)** → read the line: could be localhost health-check
  curls (benign) or a real `curl … | bash` of a vendor installer (note it; vendor-
  official paths are low risk but pin/review-able).
- **Genuinely actionable class**: **MCP Rug Pull (RP1)** — unpinned installs
  (`uvx`/`uv tool run`/`pip`/`npx`/docker without `==version` or tag) in skill
  instructions. That's the supply-chain recommendation to surface.
- **Noise sources**: `.hub/index-cache/*.json` (multi-MB third-party index cache —
  RP1 hits there are data, not your config), all `tests/` files.

## Remediation options (offer, don't auto-build)

- Pin unpinned install commands in skill docs (`uvx --from pkg==x.y.z …`).
- LLM semantic pass: `skillspector scan … --llm` re-scores intent (needs a provider
  key; costs tokens — scope to top files only).
- Baseline/suppression so future scans show only deltas: README documents a
  `baseline` feature — check `skillspector --help` for exact command names.
- Recurring cron hygiene scan once findings are baselined.

## Support files

- `scripts/summarize_scan.py` — rollup summarizer (severity/category counts, HIGH
  non-test findings list, per-file counts). Run: `env -u PYTHONPATH python3
  <skill>/scripts/summarize_scan.py /tmp/skills_scan.json /tmp/rollup.txt`, then
  `read_file /tmp/rollup.txt`.
- `references/first-scan-findings.md` — baseline results + verified-benign line refs
  from the 2026-08-16 full-library scan (skillspector 2.9.5, commit 27fd962).