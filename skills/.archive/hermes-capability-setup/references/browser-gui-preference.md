# GUI vs headless Chromium for browser automation — user preference (2026-08-24)

## The preference

<REDACTED> wants **GUI (visible) Chromium** used for browser automation whenever a desktop
session is reachable — he can watch it navigate, log in, fill forms. Fall back to
headless only when no display exists.

Reasoning accepted: headless has real limits — login walls/CAPTCHAs, DRM video,
native dialogs (file pickers, payment popups), WebRTC, bot detection. A visible
browser handles these better, and the user can interact (2FA, CAPTCHAs) when needed.

## Detection

The agent's own env usually has NO `DISPLAY`/`WAYLAND_DISPLAY`/`XAUTHORITY` — the
gateway runs outside the graphical session. Discover the session:

```bash
ls /tmp/.X11-unix/                  # Xwayland :1, Xorg :0 sockets
ls /run/user/1000/xauth_*           # auth token (e.g. /run/user/1000/xauth_CKYnyq)
xauth -f /run/user/1000/xauth_CKYnyq list   # confirms which display the token authorizes
```

This machine (Arch, KDE Plasma on Wayland): Xwayland `:1`, Xorg `:0`, token
authorizes `:1`.

## Launch recipe (GUI)

Kill the headless instance FIRST — only one process can hold port 9222:

```bash
export DISPLAY=:1
export XAUTHORITY=/run/user/1000/xauth_CKYnyq
/usr/bin/chromium --no-first-run --no-default-browser-check \
  --remote-debugging-port=9222 \
  --user-data-dir=$HOME/.config/chromium \
  --window-size=1280,900 about:blank
```

Same binary + standard profile as headless, just drop `--headless=new` and add the
display. The harness (browser-harness) recognizes the standard profile dir.

## Verification — endpoint, not window tools

xdotool/wmctrl window listing was UNRELIABLE for confirming the window landed on
Xwayland (empty results while the browser was fine). Source of truth:

1. `curl -s http://127.0.0.1:9222/json/version` → expect `"Browser": "Chrome/151..."` + webSocketDebuggerUrl
2. browser_exec drive-through: navigate a real page, read back the title.

If the endpoint is live but the user reports no visible window, suspect off-screen
rendering — do not assume harness failure.

## Pitfall recap (from the same debugging session)

- google-chrome binary (`/opt/google/chrome/chrome`) + `~/.config/google-chrome`
  profile REFUSES `--remote-debugging-port` headless (default-dir rule, Chrome 136+).
- chromium binary + `~/.config/chromium` profile binds fine (non-default-dir bypass).
- Consent tick persists as `devtools.remote_debugging.user-enabled: true` in
  `~/.config/google-chrome/Local State` (interactive path only).
- Harness-spawned Chrome is ephemeral — launch your own tracked background process
  first, verify port, then call browser_exec.
