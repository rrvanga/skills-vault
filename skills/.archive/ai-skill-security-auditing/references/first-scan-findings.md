# Baseline: full-library scan of `~/.hermes/skills/` (2026-08-16)

Tool: SkillSpector **2.9.5**, commit `27fd962`, `uv tool install`, static `--no-llm`.
Report: 446,410-byte JSON at `/tmp/skills_scan.json` (whole library scanned as one
target `name: "unknown"`; every file issues-indexed individually).

## Totals

- **284 issues**: 86 HIGH / 184 MEDIUM / 14 LOW
- By category: Data Exfiltration 75 · Privilege Escalation 72 · MCP Rug Pull 50 ·
  Dangerous Code Execution 24 · Rogue Agent 24 · Excessive Agency 19 · Supply Chain 6 ·
  Prompt Injection 3 · Tool Misuse 3 · Agent Snooping 2 · Data Flow 1 · Anti-Refusal 1 ·
  Memory Poisoning 1 · Output Handling 1 · System Prompt Leakage 1 · YARA Match 1

## Verdict

**Zero true-positive malicious findings.** All 284 are keyword/pattern matches on
benign context. The only real hardening class is supply-chain hygiene (unpinned
installs, below).

## Verified-benign classes (file:line evidence)

| Flag | Location | Actual content |
|---|---|---|
| SC2 External Script Fetching conf=0.9 | `autonomous-ai-agents/computer-use/SKILL.md:300` | troubleshooting row *describing* blocked `curl \| bash` pattern |
| SC2 | `creative/comfyui/scripts/comfyui_setup.sh:235,258` | localhost health-check `curl 127.0.0.1:$PORT/system_stats` |
| SC2 conf=0.9 | `mlops/huggingface-hub/SKILL.md:18` | **real** `curl -LsSf https://hf.co/cli/install.sh \| bash -s` — official vendor installer (low risk; pin/review if desired) |
| SC2 | `productivity/airtable/SKILL.md:197` | example `-H "Authorization: Bearer ***"` (redacted placeholder) |
| P2 Hidden Instructions conf=0.7 | `creative/popular-web-designs/SKILL.md:58` | `<!-- Paste the Google Fonts link … -->` author hint comment |
| TM1 Tool Parameter Abuse | `social-media/xurl/SKILL.md:292` | example `xurl -X DELETE /2/tweets/1234567890` |
| YR4 YARA mcp poisoning | `research/research-paper-writing/SKILL.md:4` | frontmatter `description:` line (keyword "metadata") |
| RA1 Self-Modification + P6 conf=0.85 | `creative/comfyui/scripts/run_workflow.py:594,596` | argparse help strings ("Overwrite existing files", "return prompt_id") |
| AR3 Anti-Refusal conf=0.24 | `research/research-paper-writing/references/autoreason-methodology.md:208` | phrase "without constraints" in a methodology doc |
| MP3 Memory Poisoning conf=0.24 | `autonomous-ai-agents/hermes-agent/references/cli-reference.md:126` | docs mention of `hermes memory reset` |
| OH1 conf=0.24 | `mlops/evaluation/evaluating-llms-harness/references/custom-tasks.md:362` | "Execute generated code" phrase in benchmark docs |
| E2 Env Harvesting conf=0.6 (×9) | `productivity/*/tests/test_*.py` (docx, pdf, powerpoint, xlsx) | `dict(os.environ, LC_ALL="C", …)` pytest subprocess isolation |
| E2 | `productivity/google-workspace/scripts/google_api.py:90`, `gws_bridge.py:103` | `os.environ.copy()` child-`gws`-CLI env passthrough |
| AE / PE3 `.env` / "access tokens" (×40+) | github/github-auth, hermes-agent SKILL.md:70, verify-delegated-code SKILL.md:73 | documentation of credential handling; github-auth scripts `gh-env.sh:31`, `git-credential-token.py:46` actively manage creds (that's their job) |
| AST4 subprocess conf=0.7 (×24) | comfyui scripts, google-workspace scripts | all list-form args, no `shell=True` — safe pattern |

## Noise sources

- `.hub/index-cache/hermes-index.json` — 41.5 MB third-party index cache flagged RP1
  (docker refs inside third-party listings); data, not ours to fix.
- All `tests/` files — test-harness patterns.

## Actionable (supply-chain hygiene — unpinned installs, RP1)

- `creative/comfyui/SKILL.md` lines 8, 377-379, 605 — `uvx`/`uv tool run` without
  `==version`; also `references/official-cli.md:12`, `scripts/auto_fix_deps.py:46`,
  `scripts/comfyui_setup.sh:151,158,171`, `scripts/health_check.py:39`.
- `autonomous-ai-agents/hermes-agent/references/native-mcp.md:18,25,27,199,219` —
  `pip install` / `npx` without pins; line 210 `npx` without version suffix.
- `mlops/huggingface-hub/SKILL.md:18` — official HF installer via `curl | bash`
  (vendor-standard; optional to pin).

Fix shape: `uvx --from pkg==x.y.z …`, `pip install pkg==x.y.z`, `npx pkg@x.y.z`.

## Environment gotchas hit during the run (now solved)

1. **PYTHONPATH ABI crash** — skillspector exit 2 `pydantic_core` import fail; fix
   `env -u PYTHONPATH …` (full story in SKILL.md). Verified working invocation.
2. **`jq` not installed** — use the Python summarizer, not jq.
3. **Terminal output collapses to `1 lines`** — summarizer writes to `/tmp`, read back
   via `read_file`.
4. Summarizer bug to avoid: `collections.defaultdict` has no `.most_common()` — sort
   with `sorted(d.items(), key=lambda kv: -sum(kv[1].values()))`.