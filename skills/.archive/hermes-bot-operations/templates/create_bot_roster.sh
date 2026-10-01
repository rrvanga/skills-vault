#!/usr/bin/env bash
# create_bot_roster.sh — known-good Hermes bot-roster creator (verified 2026-08-29).
# COPY AND MODIFY: replace BOTS array with your roster; adjust skill mapping per bot.
# Behavior: fresh profile per bot (--no-skills), role description (kanban routing),
# curated skill symlinks from the master library, log written to ~/.hermes/cache/terminal-output/.
# Run: bash create_bot_roster.sh   (no sudo; only touches ~/.hermes/profiles/)

set -u
LOG="$HOME/.hermes/cache/terminal-output/sleuth-create.log"
mkdir -p "$(dirname "$LOG")" "$HOME/.hermes/cache/terminal-output"
: > "$LOG"

# Each entry: "botname|Role description for kanban routing"
BOTS=(
  "sentinel|Ops & automation caretaker: machine vitals, cron-fleet health, kanban/bridge/backups, State Doc"
  "researcher|Market, price & fact intel: price tracking, hardware comparisons, tax ref, papers"
  "scribe|Content & knowledge: repos, PRs, Obsidian KB, Decisions Journal, skills authoring"
  "postmaster|Comms & inbox: email triage, briefings, bot-bridge messaging"
  "archivist|Media & file housekeeping: card ingestion, by-type org, Documents sorting, trash discipline"
)

# Curated skill mapping per bot: name|space-delimited skill names (as they appear under ~/.hermes/skills/<category>/)
SKILLS=(
  "sentinel|hermes-agent hermes-cron-operations hermes-kanban-operations hermes-gateway-access-control hermes-session-forensics linux-system-audit laptop-battery-charge-limits plan spike"
  "researcher|web-data-extraction image-data-extraction ocr-and-documents github-trend-research llm-wiki maps"
  "scribe|github-pr-workflow github-issue-to-pr github-code-review pii-safe-public-publishing obsidian hermes-agent-skill-authoring docx xlsx pdf"
  "postmaster|email-inbox-triage bot-to-bot-bridge gif-search youtube-content"
  "archivist|media-card-ingestion home-file-organization image-data-extraction ocr-and-documents diagram-rendering"
)

link_skill() { # bot category skill
  local bot="$1" cat="$2" skill="$3"
  local src="$HOME/.hermes/skills/$cat/$skill"
  local dst="$HOME/.hermes/profiles/$bot/skills/$cat/$skill"
  if [ -d "$src" ] || [ -f "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
    echo "linked  $bot <- $cat/$skill" >> "$LOG"
  else
    echo "MISSING SOURCE $cat/$skill for $bot" >> "$LOG"
  fi
}

for entry in "${BOTS[@]}"; do
  bot="${entry%%|*}"; desc="${entry#*|}"
  echo "== creating $bot" >> "$LOG"
  hermes profile create "$bot" --no-skills --description "$desc" >> "$LOG" 2>&1

  # resolve that bot's skill list
  for s in "${SKILLS[@]}"; do
    if [ "${s%%|*}" = "$bot" ]; then
      for skill in ${s#*|}; do
        # try category order: autonomous-ai-agents, devops, github, media, note-taking, productivity, research, software-development
        found=0
        for cat in autonomous-ai-agents devops github media note-taking productivity research software-development; do
          if [ -e "$HOME/.hermes/skills/$cat/$skill" ]; then
            link_skill "$bot" "$cat" "$skill"; found=1; break
          fi
        done
        [ "$found" -eq 0 ] && echo "MISSING SOURCE $skill (no category match) for $bot" >> "$LOG"
      done
      break
    fi
  done
done

echo "== done. Log: $LOG"