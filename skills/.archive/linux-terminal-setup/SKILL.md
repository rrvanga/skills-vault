---
name: linux-terminal-setup
description: Use when setting up or tuning Linux terminal emulators.
---

# Linux Terminal Setup & Optimization

Consolidate a scattered/misconfigured terminal stack (too many emulators, zero or conflicting configs, broken prompt icons) into one coherent, well-configured terminal. Proven on KDE Plasma/Wayland + zsh (Konsole keeper), generalizes to other DEs. Full class scope: survey → keeper selection → Nerd Fonts → themes → profiles → prompt → sudo-split uninstall → verification.

## Core principles
- **Survey before touching.** Find what's INSTALLED vs what's actually USED (shell-history hits, running processes, config mtimes). "Scattered settings" often means "no configs at all" — defaults everywhere.
- **Reversible-first.** Back up every config you'll touch into `~/terminal-setup-backup-YYYYMMDD/` before editing.
- **Sudo split.** Test `sudo -n true` first (expect SUDO_NEEDS_PASSWORD). All config work is userland in `~`; only package removal needs sudo → hand the user ONE pre-validated copy-paste command at the end.
- **Verify everything.** Every artifact gets a check: syntax, parser, registry, CLI listing.

## Workflow
1. **Survey** (commands below) → pick the keeper by DE integration:
   - KDE Plasma → **Konsole** (native, GPU-accelerated, tabs/splits/profiles built in)
   - sway/hyprland (Wayland) → foot or kitty
   - standalone/other → alacritty, wezterm, ghostty
2. **Back up** existing configs of all terminals involved.
3. **Fonts**: a Nerd Font is REQUIRED for starship/prompt icons. Install userland: download release zip → extract to `~/.local/share/fonts/` → `fc-cache -f` → verify `fc-list | grep -i`.
4. **Theme**: Catppuccin / Tokyo Night for the keeper. If a guessed raw-file URL 404s, query the repo's GitHub API tree for real paths.
5. **Profile + prompt**: write the keeper profile, create/tune `~/.config/starship.toml`, append zsh history/alias tweaks (verify with `zsh -n`).
6. **Wire system defaults** (KDE: `kwriteconfig6` — see reference).
7. **Uninstall**: dry-run `pacman -Rns --print <pkgs>` to confirm blast radius (only the targets, no orphaned deps), then give the user the exact command.
8. **Verify** per checklist.

## Survey commands (Hermes quirk: redirect output to a /tmp file, then read_file — long terminal output collapses otherwise)
- Installed: `pacman -Qq | grep -iE '^(kitty|alacritty|wezterm|foot|konsole|gnome-terminal|xfce4-terminal|tilix|terminator|rxvt-unicode|urxvt|st|xterm|ghostty|hyper|yakuake)$'`
- Usage: `ps -eo comm | grep -iE '<terminals>' | sort -u` (running now); grep terminal names in shell history (count hits); `ls -la` config dirs (mtimes)
- Env: `echo $XDG_CURRENT_DESKTOP $XDG_SESSION_TYPE $SHELL`
- Sudo: `sudo -n true` (SUDO_NEEDS_PASSWORD → plan the split)
- Uninstall blast radius: `pacman -Rns --print <pkgs>` + `pacman -Qi <pkg>` (look for "Required By: None")

## Verification checklist
- Keeper lists new profile: `konsole --list-profiles` (or equivalent)
- Font registered: `fc-list | grep -i "<family>"`
- Shell config parses: `zsh -n ~/.zshrc`
- TOML config valid: `python3 -c "import tomllib; tomllib.load(open('$HOME/.config/starship.toml','rb'))"`
- KDE defaults: `grep -A2 'Desktop Entry' ~/.config/konsolerc`; `grep -A2 'KDE' ~/.config/kiorc`

## Pitfalls
- **Broken prompt glyphs ▯ = missing Nerd Font, not a broken starship config.** Fix the font first; only then touch starship.
- GitHub raw-file URL guesses for theme repos 404 — use `https://api.github.com/repos/<org>/<repo>/git/trees/<branch>?recursive=1` and grep for the real paths.
- Konsole profile `Font=` is QFont serialization (`Family,12,-1,5,50,0,0,0,0,0`), not a plain family string.
- Don't set `Parent=<profile>` unless you confirmed that parent exists on the box (system profiles may be absent).
- Konsole HistoryMode: 0=no history, 1=fixed size (HistorySize honored), 2=unlimited (HistorySize ignored).
- Never hand the user a sudo command without dry-run verification of what it removes.
- Nerd Font release zips are ~130MB (all variants) — normal, keep them; extraction is instant.

## Support files
- `references/konsole-format.md` — Konsole profile/colorscheme file formats, kwriteconfig6 wiring, Catppuccin source paths, verified session recipe
- `templates/konsole-main.profile` — known-good Konsole profile (JetBrainsMono NF 12pt + Catppuccin Mocha)
- `templates/starship.toml` — tuned starship prompt (time/dir/git/python/cmd_duration)
