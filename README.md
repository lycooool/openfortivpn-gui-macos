# openfortivpn-gui

[English](README.md) | [繁體中文](README.zh-TW.md)

A native macOS SwiftUI GUI for [openfortivpn](https://github.com/adrienverge/openfortivpn), with multi-profile config, a menu-bar status item, auto-reconnect, and one-way profile import from FortiClient.

The UI is localized in English and Traditional Chinese, and follows your Mac's system language automatically (**System Settings → General → Language & Region**).

> **Requires `openfortivpn` to already be installed** (e.g. via Homebrew: `brew install openfortivpn`). This app is a GUI wrapper around it, not a replacement — it will not work without the `openfortivpn` binary present on your Mac.

## Requirements

- macOS 14+
- `openfortivpn` installed via Homebrew (`brew install openfortivpn`)
- Swift toolchain (Xcode Command Line Tools are enough — no full Xcode required)

## Install (regular use)

```
./Scripts/install.sh
```

This builds a release binary and installs it as `/Applications/openfortivpn-gui.app` (with icon), then launches it. After this, it behaves like a normal Mac app — open it from Launchpad/Spotlight/Dock, no need to re-run any script. `/Applications` is group-writable by the `admin` group on a stock Mac, so this doesn't need `sudo` for a normal admin account. Re-run `install.sh` any time to rebuild and reinstall the latest code.

On first launch, the app asks for a one-time administrator authorization to let `openfortivpn` run as root without a password prompt on every connect (via a narrowly-scoped `/etc/sudoers.d/openfortivpn-gui` rule).

The app is not code-signed or notarized, so Gatekeeper will likely block the first launch — see [Security](#security) below for how to allow it.

## Build & run (development)

```
./Scripts/run.sh
```

This builds a debug binary and launches it wrapped in a minimal `.app` bundle via `open`, without installing anything — useful when iterating on the code. Use this (or `install.sh`) instead of plain `swift run` — running the raw unbundled executable skips LaunchServices registration, which breaks SwiftUI `TextField` keyboard input, copy/paste, and other text-input-system-dependent interactions.

## Security

- This app has **not undergone any independent security review or audit**.
- It is **not code-signed or notarized** — macOS Gatekeeper will likely warn you the first time you run it ("cannot be opened because the developer cannot be verified"). To allow it: **System Settings → Privacy & Security**, scroll down to the blocked-app notice, click **Open Anyway**, then confirm again in the dialog that appears.
- It requests administrator authorization once to install a sudoers rule granting passwordless root access to run `openfortivpn` (scoped to that one binary, not general root access — see `Sources/openfortivpn-gui/Services/PrivilegeService.swift` for exactly what gets written).
- Passwords are stored in the macOS Keychain, never on disk in plaintext.
- If you're security-conscious, please read the source before granting access — it's small enough to review in one sitting. Use at your own risk.

## License

[MIT](LICENSE)
