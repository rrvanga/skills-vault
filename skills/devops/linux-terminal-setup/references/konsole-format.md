# Konsole configuration reference (KDE Plasma)

Verified 2026-08 on KDE Plasma/Wayland, Konsole v26.04.3, Arch Linux. Recipe that worked end-to-end.

## File locations
- User profiles: `~/.local/share/konsole/*.profile`
- User color schemes: `~/.local/share/konsole/*.colorscheme`
- System schemes/profiles (read-only reference): `/usr/share/konsole/`
- Settings: `~/.config/konsolerc` (default profile lives here); `~/.config/kiorc` (system terminal)

## Profile format — `[General]` keys (verified working)
```
[General]
Name=Main
Font=JetBrainsMono Nerd Font,12,-1,5,50,0,0,0,0,0
ColorScheme=Catppuccin-Mocha
HistoryMode=2
HistorySize=10000
AntiAliasFonts=true
BoldIntense=true
LineSpacing=1
```
- `Font=` is QFont serialization: `Family,PointSize,Weight(-1=normal),<italic/hint flags>,Stretch,...` — copy the pattern, never a plain family string.
- `ColorScheme=` references the colorscheme filename without extension.
- HistoryMode: `0`=no history, `1`=fixed size (HistorySize honored), `2`=unlimited (HistorySize ignored).
- Omit `Parent=` unless the referenced system profile is confirmed present (system profiles can be absent on minimal installs — standalone profiles inherit built-in defaults fine).

## Color scheme format
- Sections: `[Background]`, `[Foreground]`, `[Color0]`–`[Color7]`, each with `Color=R,G,B` ints plus `...Faint` / `...Intense` variants.
- `[General]` section of the scheme: `Opacity` (0–100 int), `Blur=true|false` (frosted-glass translucency — works on KWin Wayland), `Description=`, `ColorRandomization=false`, `Wallpaper=`.
- Tuning recipe: `Opacity=97` + `Blur=true` for subtle frosted glass.

## KDE wiring (kwriteconfig6)
```
kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile "Main.profile"
kwriteconfig6 --file kiorc --group KDE --key TerminalApplication "konsole"
```
Verify: `grep -A2 'Desktop Entry' ~/.config/konsolerc`, `grep -A2 'KDE' ~/.config/kiorc`.

## Verification
- `konsole --list-profiles` — shows profiles Konsole actually sees (must list the new one)
- Restart/relaunch Konsole to apply; new tab picks up the default profile

## Catppuccin source
- Repo: `github.com/catppuccin/konsole` — themes at `themes/catppuccin-<flavor>.colorscheme` (mocha / latte / frappe / macchiato)
- Direct raw URL: `https://raw.githubusercontent.com/catppuccin/konsole/main/themes/catppuccin-mocha.colorscheme`
- If a guessed path 404s, get real paths via the git trees API:
  `curl -sL "https://api.github.com/repos/catppuccin/konsole/git/trees/main?recursive=1" | grep -oE '"path": "[^"]*colorsch[^"]*"'`
- Mocha signature colors: bg `30,30,46` (#1e1e2e), blue `137,180,250`, fg `205,214,244` — good sanity check that the download is the real scheme.

## Nerd Font install (userland, no sudo)
```
mkdir -p ~/.local/share/fonts
curl -sL --max-time 120 -o /tmp/jbmono.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip -o /tmp/jbmono.zip -d ~/.local/share/fonts/
fc-cache -f
fc-list | grep -i "JetBrainsMono Nerd Font"
```
- Zip is ~130MB (all variants: regular/Mono/Propo/NL) — expected, keep them.
- The GUI name to reference in profiles is the fc-list family: `JetBrainsMono Nerd Font`.

## Starship
- Config: `~/.config/starship.toml`; validate with `python3 -c "import tomllib; tomllib.load(open('$HOME/.config/starship.toml','rb'))"`.
- Template: `templates/starship.toml` in this skill.

## zsh additions that pair with the setup
```
setopt SHARE_HISTORY INC_APPEND_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE
setopt AUTO_CD
alias ls='ls --color=auto' ll='ls -lah --color=auto' la='ls -A --color=auto' grep='grep --color=auto'
```
Verify: `zsh -n ~/.zshrc`.
