# skills-vault

Public, **PII-scrubbed** mirror of my personal Hermes Agent skill library.

- Source of truth: local `~/.hermes/skills/` (private)
- This repo: sanitized snapshot, synced daily by a cron job
- All usernames, email addresses, home paths, and credential values are replaced with `<REDACTED>` before anything is committed; a pre-push guard aborts if any PII remains
- Config-key names (e.g. `OPENCODE_GO_API_KEY`) appear as identifiers only — never values

## Layout
`skills/` — category/skill-name/SKILL.md plus references/scripts/templates per skill
