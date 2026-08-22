# enabled_toolsets: valid names and when to trim

Authoritative toolset names from the Hermes docs (verified 2026-08): `web`, `search`,
`terminal`, `file`, `browser`, `vision`, `image_gen`, `skills`, `tts`, `todo`, `memory`,
`session_search`, `cronjob`, `code_execution`, `delegation`, `clarify`, `homeassistant`,
`messaging`, `spotify`, `discord`, `discord_admin`, `debugging`, `safe`.

## Trim rule (from the 2026-08 cron efficiency pass)

- Trim ONLY jobs with provably minimal needs. Example: a daily-reminders agent job whose
  only tool action is removing itself needs `["cronjob"]` — nothing else.
- A til/notebook writer needs `["file", "terminal"]` (file writes + git push).
- A config re-wiring monitor needs `["terminal", "file"]`.
- LEAVE autonomous engineering loops (daily-engineering-loop, autonomy-window) on their
  full toolset set: a job without its tools is a broken job. When in doubt, don't trim.
- Verify the update by reading the returned job object: the new `enabled_toolsets` list
  must be present; then confirm via `cronjob list` before trusting the save.