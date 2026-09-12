# RustDeskTinyLegacy maintenance inventory

RustDeskTinyLegacy is a frozen Windows 7 SP1 x64 product. It is an independent
repository and does not track or merge later RustDesk releases.

## Source and build baseline

- RustDesk release: `1.3.7`
- RustDesk source commit: `1f02bc9d3ed379e970f8ae4d4497f76adfd98d1c`
- Vendored `libs/hbb_common` commit: `49c6b24a7a8c39d4448e07b743007ef1a3febd43`
- Rust: `1.75.0`, target `x86_64-pc-windows-msvc`
- Flutter: `3.24.5`
- Flutter engine: RustDesk's custom Windows x64 engine from
  `https://github.com/rustdesk/engine/releases/download/main/windows-x64-release.zip`
- Supported OS: Windows 7 SP1 x64 only
- License: GPL-3.0-or-later, inherited from RustDesk

The official source archive omitted `libs/hbb_common`; its locked source is
vendored into this repository. No Git submodule or upstream remote is required.

## Product identity

- Application, Windows service and configuration identity: `RustDeskTinyLegacy`
- Installed executable: `RustDeskTinyLegacy.exe`
- Default directory: `C:\Program Files\RustDeskTinyLegacy`
- Installer: `RustDeskTinyLegacy-install.exe`
- Portable extraction directory: `%LOCALAPPDATA%\rustdesktinylegacy`

This identity is deliberately separate from `RustDesk` and `RustDeskTiny`.

## Rust source changes

| File | Legacy modification |
| --- | --- |
| `Cargo.toml` | Adds the `rustdesk-tiny` feature and Legacy Windows version-resource identity. |
| `rust-toolchain.toml` | Pins Rust 1.75 and the Win7-compatible x64 MSVC target. |
| `src/tiny.rs` | Owns Legacy branding, persistent one-time-password policy, permanently enabled direct IP access with an editable port, strict numeric `ip:port` parsing, direct-only command validation, listener configuration and tests. |
| `src/lib.rs` | Exposes the Tiny policy module behind the feature. |
| `src/core_main.rs` | Initializes Legacy before Windows bootstrap, validates Tiny commands, and provides strict silent install/update arguments and exit codes. |
| `src/client.rs` | Rejects outgoing targets that are not numeric IPv4/IPv6 plus a non-zero port. |
| `src/rendezvous_mediator.rs` | Replaces rendezvous/relay registration with a direct TCP listener on `0.0.0.0:21118` by default, matching RustDesk 1.3.7 and feeding its shared server/password implementation. |
| `src/common.rs` | Disables NAT, rendezvous latency and software-update checks in Tiny builds. |
| `src/main.rs` | Skips startup NAT and rendezvous checks. |
| `src/flutter_ffi.rs` | Applies Legacy identity and hard settings before exposing state to Flutter. |
| `src/ipc.rs` | Adds the feature-gated validated listener message. |
| `src/server/connection.rs` | Prevents successful session teardown from rotating the Tiny one-time password. |
| `src/platform/windows.rs` | Passes listener state to the desktop-session server, keeps service restarts idempotent and prevents silent upgrades from launching GUI/tray processes. |
| `libs/portable/src/main.rs` | Uses an independent extraction directory, falls back to a per-run directory when an active old GUI locks the cache, reports extraction/launch failures, keeps the parent alive for interactive installation, and waits for silent operations while returning their exit code. |
| `libs/portable/src/bin_reader.rs` | Propagates directory creation, decompression and payload write failures instead of silently continuing with an incomplete extraction. |
| `libs/portable/src/ui.rs` | Displays a visible setup error when the outer self-extractor cannot unpack or launch the embedded client. |
| `libs/portable/Cargo.toml` | Gives the installer an independent Legacy description and Windows version-resource identity. |
| `src/lang/cn.rs`, `src/lang/en.rs` | Add the Tiny-specific incoming-password explanation. |

## Flutter source changes

| File | Legacy modification |
| --- | --- |
| `flutter/lib/common.dart` | Caches Tiny mode for consistent UI gating. |
| `flutter/lib/consts.dart`, `flutter/lib/main.dart` | Make boot arguments available to the connection page. |
| `flutter/lib/common/widgets/connection_page_title.dart` | Allows Tiny to remove the multi-mode help tooltip. |
| `flutter/lib/desktop/pages/connection_page.dart` | Uses and validates `ip:port`, suppresses network status, peer queries and autocomplete in Tiny mode. |
| `flutter/lib/desktop/pages/desktop_home_page.dart` | Hides the local ID, preserves the one-time password and shows a password-specific explanation; Tiny uses the title-bar settings tab instead of the outgoing-only floating gear. |
| `flutter/lib/desktop/pages/desktop_setting_page.dart` | Hides account/network/ID/plugin settings and rotates a temporary password only after an explicit length change. |
| `flutter/lib/models/server_model.dart` | Makes periodic password synchronization read-only so focus and polling cannot rotate the password, and keeps the Tiny password visible independently of the upstream stop-service flag. |
| `flutter/lib/models/peer_tab_model.dart` | Disables discovery for the direct-only product. |
| `flutter/lib/desktop/pages/desktop_tab_page.dart` | Keeps the settings entry available in Tiny mode even when the 1.3.7 executable mode is incoming-only. |
| `flutter/lib/desktop/widgets/tabbar_widget.dart` | Keeps the Tiny title bar and its settings tab visible on the Win7-compatible UI. |
| `flutter/lib/generated_bridge.dart`, `flutter/lib/generated_bridge.freezed.dart`, `src/bridge_generated.rs`, `src/bridge_generated.io.rs` | Frozen generated bridge sources for the pinned Flutter/Dart toolchain. |
| `flutter/windows/runner/Runner.rc`, `flutter/windows/runner/main.cpp` | Apply Legacy identity to Windows version resources and the runner fallback application name. |

## Build and release changes

| File | Legacy modification |
| --- | --- |
| `build.py` | Adds `--rustdesk-tiny` and forwards the Cargo feature. |
| `scripts/build-windows-legacy.ps1` | Creates an isolated Flutter 3.24.5 SDK, installs the RustDesk Win7 engine, builds and packages the independently named executable and installer, and prints SHA-256. |
| `.gitignore`, `flutter/.gitignore` | Exclude build output while retaining the frozen bridge sources required by the pinned toolchain. |

Build artifacts under `target`, `flutter/build`, `.dart_tool` and `dist` are not
source and must not be committed. The build script may use
`http://10.10.100.191:7890` only as a download fallback.

## Release acceptance checklist

1. Run the Rust unit tests and Flutter analyzer with the pinned toolchain.
2. Build `dist\RustDeskTinyLegacy-install.exe` and record its SHA-256.
3. On Windows 7 SP1 x64, test install, uninstall, service start/stop, custom
   install directory, silent install and silent update over a prior build.
4. Confirm the installed path, executable, service, shortcuts, registry and
   config do not reuse the RustDesk or RustDeskTiny identity.
5. Confirm IPv4 and bracketed IPv6 targets connect, while IDs, domains,
   wildcards, missing ports and zero ports are rejected.
6. Confirm focusing and editing `ip:port` does not rotate the one-time password.
7. Confirm an idle GUI performs no rendezvous, relay, NAT, account or update
   network request.
