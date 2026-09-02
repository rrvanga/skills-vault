---
name: moa-gate
description: "Use when running the MOA gate on a PR before merge."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [GitHub, MOA, code-review, merge, PR]
    related_skills: [github-pr-workflow, github-code-review]
---

# MOA Gate — multi-agent review before merge

Gate content PRs with the multi-agent orchestration backend (**moa:default** = deepseek-v4-pro + glm-5.2 → qwen3.8-max, 3 concurrent models) before `gh pr merge --squash`. The gate cross-checks claims against primary sources and returns a verdict as the **last line of its output**.

## When to use
- Before merging any PR that must be MOA-gated (user convention: content PRs are MOA-gated)
- After the PR is pushed, `MERGEABLE`, and pre-merge fixes are in

## Prerequisites
- `gh` authenticated; feature branch pushed; PR open
- `moa:default` provider configured — **RAM-hungry** (3 concurrent models), takes minutes per run
- `hermes` CLI on PATH; repo checked out on the feature branch

## Procedure

1. **Confirm state** — branch, HEAD, PR mergeable:
   `git branch --show-current && gh pr view N --json state,mergeable,headRefName,baseRefName`
2. **Write the runner script** from `templates/moa-gate.sh` (set PR context in the prompt). NEVER inline a large diff in `-q "..."` — build a prompt file and pass it with `--query-file`; the flag guarantees quotes, `$(...)`, and backticks survive verbatim (git diffs of markdown are full of backticks).
3. **Run in background** — `terminal(background=true, notify=true)`; the gate can take 5–15 min.
4. **Health-check ~25–30 s later** — process alive; log shows `diff bytes: N` (non-zero).
5. **Parse the log** (`/tmp/moa-gate.log`) — verdict is the **LAST text line**: exactly `APPROVE` or `REQUEST_CHANGES`. Ignore `GATE_EXIT` — REQUEST_CHANGES still exits 0.
6. **Fix ONLY the listed blockers** — discretionary nits are optional; the gate typically pre-clears the merge after blockers. Use `patch`/`write_file`, then verify each fix concretely (link → `curl -L -o /dev/null -w '%{http_code}'`; EOF → `tail -c 16 file | xxd` shows `0a`).
7. **Commit conventional** (`fix(docs): ...`), push.
8. **Merge**: `gh pr merge N --squash --delete-branch`.
9. **Verify** — `gh pr view N --json state,mergedAt,mergeCommit`; then **read back the merged artifact on main** (grep the fixed string, check EOF) — never trust the MERGED flag alone. `git fetch -p origin`, delete local branch if it lingers, remove `/tmp/moa-*` artifacts.

## Pitfalls
- **Verdict ≠ exit code**: REQUEST_CHANGES exits 0. Parse the text.
- **Background it**: moa:default spawns 3 concurrent models; foreground runs blow the terminal timeout.
- `git branch -d` after `--delete-branch` may report `not found` — gh already removed it; cosmetic, move on.
- Reasoning models + tiny `max_tokens` probes return empty content — irrelevant to the gate (it runs 8K+); don't mistake it for a failure.
- Gate prompt must demand: verdict as exact last line, factual accuracy vs **primary sources** (specs, arXiv, press, vendor docs — not blogs), broken markdown/formatting, repo doc conventions; scope the review to the PR's files.
- If the gate outputs a session_id line after the verdict, the verdict line is still the last *content* line — strip the trailing `session_id: ...` when parsing.

## Verification checklist

- [ ] `diff bytes: N` logged, N > 0
- [ ] verdict line present: `APPROVE` or `REQUEST_CHANGES`
- [ ] blockers fixed and concretely verified (curl / xxd / grep)
- [ ] `state: MERGED` + `mergeCommit` oid captured
- [ ] merged file read-back on `main` confirms the fixes
- [ ] stale remote-tracking refs pruned, `/tmp/moa-*` removed