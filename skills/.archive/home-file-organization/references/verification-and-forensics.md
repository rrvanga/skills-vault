# Verification & forensics (post-move hardening, learned 2026-08-21)

The organize/dedupe pass ran clean, then the *cleanup of the cleanup* produced the
session's real lessons. These harden step 4 ("verify on disk") of the main workflow.

## Counts: never narrate what you didn't re-read

A script's own summary print (`Downloads now: 8 items`) is NOT evidence.
- Re-read the actual output of the run, or re-list with your own `ls -1A`,
  before asserting numbers in a report.
- Failure mode seen: a phantom "7 lock files in Downloads" was asserted from an
  unread script printout, then chased through four forensic theories (trash
  content grep, trash filename grep, stray trashinfo find, XDG override check —
  all clean, all beside the point). The real stragglers (2 lock files) were
  sitting on the Desktop the whole time and were found in one `find`.
- Rule: when a claim is in doubt, run a physical `find` FIRST. Physical search
  beats deriving from memory, every time.
- If you misstated a count in a report/manifest, correct the record explicitly —
  the user values the correction over the face-saving silence.

## Shell gotcha: standalone `find` + `set -e`

`find /usr/share /usr/local/share "$HOME/.local/share" -name '*.desktop'` exits 1
when any listed dir is missing (`/usr/local/share/applications` is absent on
Arch) — under `set -euo pipefail` the whole script dies with ZERO output, which
looks like a different bug entirely (empty output, exit 1).
- Fix A: append `|| true` to the find line.
- Fix B: keep the find inside `< <( … )` process substitution — bash's errexit
  ignores the exit status of process substitutions (this is why the original
  script survived and the rewrite didn't).
- Trace with `bash -x script 2>&1 | tail` to find the dying line fast.

## Whole-folder moves carry strays

A folder pulled in by name (e.g. `2025 taxes/`) can contain documents of another
class (Canada Offer Letter, Welcome Letter rode into Taxes/). Expect one or two
strays per named folder; catch them at the dedupe/review pass and relocate,
logging both the move and the correction.

## Stranded `.~lock.*#` debris — sweep the SOURCE dirs after moving

LibreOffice lock files stay where the originals were. After originals move
(Desktop/Downloads → Documents), the locks remain: that's debris, not files.
- Sweep all source dirs for `.~lock*` after the move pass.
- Trash them (`gio trash`), log them, NEVER count them as files, never move them.
- `.directory` on a Desktop = DE metadata, legitimately stays.

## Trash forensics (auditing `gio trash`)

- Trashinfo filenames mirror original basenames (`<name>.trashinfo`);
  `~/.local/share/Trash/info/` and `files/` **counts must match** (36/36 here).
- `Path=` lines inside `.trashinfo` are **URI-encoded**: `~`→`%7E`, `#`→`%23`,
  space→`%20`. Grepping the content for `~lock` finds nothing — grep the plain
  substring instead.
- `XDG_DATA_HOME` (or `XDG_CACHE_HOME`) overrides redirect trash elsewhere:
  check `echo $XDG_DATA_HOME` before assuming the standard location.
- If trash is clean and originals are gone FROM where they should be, the files
  are elsewhere: `find` them on disk. Stop theorizing once the physical search
  is an option.

## One-off tool provenance ("is it yours?")

To attribute an unknown script/file: grep shell history for the name (run vs
edit lines differ), grep the agent's own config/cron/scripts for references,
stat mtime, list sibling files modified same-day. Often the honest answer is
"used by you, origin unknown" — say that.