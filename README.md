# openfortivpn-gui

A native macOS SwiftUI GUI for [openfortivpn](https://github.com/adrienverge/openfortivpn), with multi-profile config, a menu-bar status item, auto-reconnect, and one-way profile import from FortiClient.

## Requirements

- macOS 14+
- `openfortivpn` installed via Homebrew (`brew install openfortivpn`)
- Swift toolchain (Xcode Command Line Tools are enough — no full Xcode required)

## Build & run

```
./Scripts/run.sh
```

This builds the executable and launches it wrapped in a minimal `.app` bundle via `open`. Use this instead of plain `swift run` — running the raw unbundled executable skips LaunchServices registration, which breaks SwiftUI `TextField` keyboard input, copy/paste, and other text-input-system-dependent interactions.

On first launch, the app asks for a one-time administrator authorization to let `openfortivpn` run as root without a password prompt on every connect (via a narrowly-scoped `/etc/sudoers.d/openfortivpn-gui` rule).
