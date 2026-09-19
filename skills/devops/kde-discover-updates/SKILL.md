---
name: kde-discover-updates
description: Use when KDE Discover can't load update backends on Arch.
---

# KDE Discover update backends (Arch)

## Symptom
Discover stuck on "Waiting for updates"; journal (warning level) shows:
```
plasma-discover: error loading "packagekit-backend" "Cannot load library /usr/lib/qt6/plugins/discover/packagekit-backend.so: libpackagekitqt6.so.2: cannot open shared object file"
plasma-discover: error loading "fwupd-backend" "... libfwupd.so.3: cannot open shared object file"
```

## Root cause
Discover's update backends ship INSIDE `discover` (plugins owned by discover), but their backing libraries come from separate packages that a partial autoremove/orphan sweep can strip:
- `libpackagekitqt6.so.2` <- package `packagekit-qt6`
- `libfwupd.so.3` <- package `fwupd`
- PackageKit daemon + alpm backend <- package `packagekit`

Confirm removal was accidental BEFORE reinstalling: `pacman -Qi discover` — packagekit is only an OptionalDep and discover is "Explicitly installed", so the packages were removed from under it.

## Fix
```
sudo pacman -S --needed --noconfirm packagekit packagekit-qt6 fwupd
```

## Verify (don't skip)
- `ldd` both plugins: only `libDiscoverCommon.so => not found` may remain — that is a FALSE POSITIVE (lives in /usr/lib/plasma-discover, resolved inside the real process; the flatpak-backend links the same lib and loads fine).
- `systemctl is-active packagekit` -> `active`
- `pkgcli list-updates` -> exit 0 with a real update list. PackageKit 1.3+ RENAMED `pkcon` -> `pkgcli`; the command is `list-updates`, NOT `get-updates` (that returns "Unknown command").
- `fwupdmgr --version` -> daemon responds.
- Discover loads plugins at process start: a stale running instance will NOT recover; relaunch it.

## Machine gotcha (<REDACTED> box)
Interactive sudo needs a password; only `/usr/bin/pacman` is NOPASSWD in sudoers. Never ask for a password in chat — use the pacman rule for package ops; other privileged steps will prompt.

## Related
- A big `pacman -Syu` backlog (kernel/plasma/discover updates) is a separate decision — don't fold it into a scoped fix.
