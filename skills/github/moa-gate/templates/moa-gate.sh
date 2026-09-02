#!/usr/bin/env bash
# MOA gate runner — generalized template.
# Usage: edit the CHANGELOG context, then: bash moa-gate.sh
# Requires: hermes CLI, moa:default provider configured, repo cloned, gh authed.
# Background launch: terminal(background=true, notify=true), then health-check ~30s later.

set -u
REPO_DIR="${1:-/home/<REDACTED>/dev/agent-lab}"   # adjust
PR_NUMBER="${2:-0}"                                  # adjust
WORKDIR=/tmp
LOG="$WORKDIR/moa-gate.log"

cd "$REPO_DIR" || { echo "repo not found: $REPO_DIR" >&2; exit 1; }

# Materialize the diff against the base branch
git fetch origin -q
DIFF_FILE="$WORKDIR/moa-diff.txt"
git diff origin/main...HEAD > "$DIFF_FILE" || { echo "diff failed" >&2; exit 1; }

# Build the gate prompt
PROMPT_FILE="$WORKDIR/moa-prompt.txt"
cat > "$PROMPT_FILE" <<'EOF'
You are the MOA gate reviewer for PR #PR_NUMBER (<REDACTED>/agent-lab). Review this diff for:
- factual accuracy of every claim (cross-check against primary sources: specs, arXiv, vendor docs, official press — NOT blogs)
- broken markdown, dead or malformed links, formatting errors
- consistency with existing docs conventions

Then list any blocking problems, each with the file and exact fix. Output your verdict as the LAST line, exactly: APPROVE or REQUEST_CHANGES

DIFF:
EOF
# Append the diff AFTER the heredoc so backticks/quotes are never shell-interpreted
cat "$DIFF_FILE" >> "$PROMPT_FILE"
echo >> "$PROMPT_FILE"

echo "diff bytes: $(wc -c < "$DIFF_FILE")"
echo "prompt bytes: $(wc -c < "$PROMPT_FILE")"
echo "launching MOA gate (background? no - run this script via terminal background=true)..."

# The gate itself: hermes chat -Q supports --query-file (nothing shell-interpreted)
hermes chat -Q --query-file "$PROMPT_FILE" -m moa:default 2>&1 | tee "$LOG"
GATE_EXIT=$?
echo "GATE_EXIT=$GATE_EXIT" | tee -a "$LOG"
echo "--- verdict (last content line) ---"
grep -E '^(APPROVE|REQUEST_CHANGES)$' "$LOG" | tail -1
exit $GATE_EXIT