# RustDeskTinyLegacy changes from upstream RustDesk

This file records every RustDeskTinyLegacy product change relative to the
frozen RustDesk 1.3.7 source baseline. Update it whenever a Legacy-specific
source file is added, removed or changes responsibility.

## Upstream baseline and maintenance policy

- RustDesk release: `1.3.7`
- RustDesk source commit: `1f02bc9d3ed379e970f8ae4d4497f76adfd98d1c`
- Imported repository baseline commit: `73e7c3dcd`
- Vendored `libs/hbb_common` commit: `49c6b24a7a8c39d4448e07b743007ef1a3febd43`
- Product branch: `main`
- Supported OS: Windows 7 SP1 x64 only
- License: GPL-3.0-or-later, inherited from RustDesk
- Full inventory command: `git diff --name-status 73e7c3dcd -- .`
- Per-file comparison command: `git diff 73e7c3dcd -- <path>`

RustDeskTinyLegacy is an independent, frozen repository. It does not track or
merge later RustDesk releases. The official 1.3.7 archive omitted
`libs/hbb_common`, so the locked dependency source is vendored directly rather
than retained as a Git submodule.

## Product behavior

RustDeskTinyLegacy accepts only numeric IPv4 or bracketed IPv6 addresses with
a non-zero port. It does not use RustDesk IDs, rendezvous/relay registration,
NAT probing, latency probing, account synchronization or software-update
requests. The service listens on every local IPv4 interface at the configured
direct-access port and authenticates incoming sessions with the normal
RustDesk password/session implementation.

The UI hides the local ID and RustDesk network state, retains a stable one-time
password, uses a lowercase `ip:port` input and removes discovery, autocomplete,
multi-connection help, account and server-oriented settings. The settings tab
remains available on the Win7-compatible interface.

## Functional change map

| Changed behavior compared with RustDesk 1.3.7 | Implementing source files |
| --- | --- |
| Independent `RustDeskTinyLegacy` identity | `Cargo.toml`, `libs/portable/Cargo.toml`, `src/tiny.rs`, `src/core_main.rs`, `src/flutter_ffi.rs`, `flutter/windows/runner/Runner.rc`, `flutter/windows/runner/main.cpp` |
| Numeric `ip:port`-only outgoing connections | `src/tiny.rs`, `src/client.rs`, `flutter/lib/consts.dart`, `flutter/lib/main.dart`, `flutter/lib/desktop/pages/connection_page.dart`, `flutter/lib/common/widgets/connection_page_title.dart` |
| No rendezvous, relay registration, NAT/latency probing, account synchronization or update traffic | `src/tiny.rs`, `src/rendezvous_mediator.rs`, `src/common.rs`, `src/main.rs`, `flutter/lib/models/peer_tab_model.dart`, `flutter/lib/desktop/pages/connection_page.dart`, `flutter/lib/desktop/pages/desktop_setting_page.dart` |
| Always-on direct server bound to `0.0.0.0:<configured-port>` | `src/tiny.rs`, `src/rendezvous_mediator.rs`, `src/ipc.rs`, `src/platform/windows.rs` |
| Stable one-time password changed only by explicit refresh or length change | `src/tiny.rs`, `src/ipc.rs`, `src/server/connection.rs`, `flutter/lib/models/server_model.dart`, `flutter/lib/desktop/pages/desktop_setting_page.dart` |
| Home page hides local ID/network state while retaining the password | `flutter/lib/common.dart`, `flutter/lib/desktop/pages/desktop_home_page.dart`, `flutter/lib/models/server_model.dart`, `src/lang/cn.rs`, `src/lang/en.rs` |
| Win7 title bar retains Home and Settings navigation | `flutter/lib/desktop/pages/desktop_tab_page.dart`, `flutter/lib/desktop/widgets/tabbar_widget.dart`, `flutter/lib/desktop/pages/desktop_home_page.dart` |
| Win7-compatible standalone installer, service lifecycle and silent upgrade | `rust-toolchain.toml`, `build.py`, `src/core_main.rs`, `src/platform/windows.rs`, `libs/portable/src/bin_reader.rs`, `libs/portable/src/main.rs`, `libs/portable/src/ui.rs`, `scripts/build-windows-legacy.ps1` |
| Frozen Flutter/Rust bridge for the pinned toolchain | `flutter/lib/generated_bridge.dart`, `flutter/lib/generated_bridge.freezed.dart`, `src/bridge_generated.rs`, `src/bridge_generated.io.rs`, `flutter/.gitignore` |

## Rust source files changed from the imported baseline

| Source file | RustDeskTinyLegacy modification |
| --- | --- |
| `Cargo.toml` | Adds the `rustdesk-tiny` feature and Legacy Windows version-resource identity. |
| `rust-toolchain.toml` | Pins Rust 1.75 and `x86_64-pc-windows-msvc`. |
| `src/lib.rs` | Exposes the Tiny policy module behind the feature. |
| `src/tiny.rs` | Owns branding, hard settings, persistent one-time-password policy, always-enabled direct access, strict address parsing, Tiny command validation and tests. |
| `src/core_main.rs` | Initializes Legacy before Windows bootstrap and implements validated interactive/silent install and update commands with reliable exit codes. |
| `src/client.rs` | Rejects outgoing targets that are not numeric IPv4/IPv6 plus a non-zero port. |
| `src/rendezvous_mediator.rs` | Replaces rendezvous/relay operation with a self-managing direct listener on `0.0.0.0:<configured-port>` and feeds accepted streams into the shared 1.3.7 server implementation. The listener owns its full lifecycle: it retries binding every second while the configured port is unavailable and rebuilds itself when the configured port changes, so listener changes take effect without any external orchestration (no service or process restart, no dependency on p2premote). |
| `src/server/connection.rs` | Prevents successful session teardown from rotating the Tiny password. |
| `src/common.rs` | Disables NAT, rendezvous latency and update checks in Tiny builds. |
| `src/main.rs` | Skips startup NAT and rendezvous checks. |
| `src/flutter_ffi.rs` | Applies Legacy identity and Tiny policy before exposing state to Flutter. |
| `src/ipc.rs` | Adds validated listener IPC and routes explicit password refresh through persistent Tiny state. |
| `src/platform/windows.rs` | Manages the independent Windows service, propagates listener state, keeps restarts idempotent and prevents silent upgrades from launching GUI/tray processes. |
| `src/lang/cn.rs`, `src/lang/en.rs` | Add the Tiny incoming-password explanation. |

## Flutter source files changed from the imported baseline

| Source file | RustDeskTinyLegacy modification |
| --- | --- |
| `flutter/lib/common.dart` | Caches the process-wide Tiny-mode flag. |
| `flutter/lib/consts.dart`, `flutter/lib/main.dart` | Make boot arguments available to the direct connection page. |
| `flutter/lib/common/widgets/connection_page_title.dart` | Allows Tiny to remove the multi-mode help tooltip. |
| `flutter/lib/desktop/pages/connection_page.dart` | Uses and validates `ip:port`; suppresses network status, peer queries and autocomplete. |
| `flutter/lib/desktop/pages/desktop_home_page.dart` | Hides the local ID, preserves the one-time password, shows the Tiny explanation and uses the title-bar settings entry. |
| `flutter/lib/desktop/pages/desktop_setting_page.dart` | Hides account/network/ID/plugin settings while leaving direct-access port and local security settings available. |
| `flutter/lib/models/server_model.dart` | Makes periodic password synchronization read-only and keeps the Tiny password visible independently of `stop-service`. |
| `flutter/lib/models/peer_tab_model.dart` | Disables discovery for the direct-only product. |
| `flutter/lib/desktop/pages/desktop_tab_page.dart` | Keeps Settings available even when the 1.3.7 executable mode is incoming-only. |
| `flutter/lib/desktop/widgets/tabbar_widget.dart` | Keeps the Tiny title bar and settings tab visible on Windows 7. |
| `flutter/lib/generated_bridge.dart`, `flutter/lib/generated_bridge.freezed.dart`, `src/bridge_generated.rs`, `src/bridge_generated.io.rs` | Freeze generated bridge sources for the pinned Flutter/Dart toolchain. |
| `flutter/windows/runner/Runner.rc`, `flutter/windows/runner/main.cpp` | Apply Legacy identity to version resources and the fallback application name. |

## Installer and build files changed from the imported baseline

| File | RustDeskTinyLegacy modification |
| --- | --- |
| `build.py` | Adds `--rustdesk-tiny` and forwards the Cargo feature. |
| `libs/portable/Cargo.toml` | Gives the self-extracting installer an independent Legacy identity. |
| `libs/portable/src/bin_reader.rs` | Propagates directory, decompression and payload-write failures instead of continuing with an incomplete extraction. |
| `libs/portable/src/main.rs` | Uses an independent extraction directory, handles locked caches, keeps the parent alive for interactive installation and propagates silent-operation exit codes. |
| `libs/portable/src/ui.rs` | Displays setup errors when the outer installer cannot unpack or launch the embedded client. |
| `scripts/build-windows-legacy.ps1` | Validates the pinned toolchain, installs the Win7 Flutter engine, builds the renamed application and emits the installer plus SHA-256. |
| `.github/workflows/rustdesk-tiny-legacy.yml` | Windows-only GitHub Actions build of the installer, mirroring the RustDeskTiny pipeline (pinned Flutter 3.24.5, Rust 1.75, bridge generator 1.80.1 and vcpkg binary cache). |
| `.gitignore`, `flutter/.gitignore` | Exclude build output while retaining frozen generated bridge sources. |

Build artifacts under `target`, `flutter/build`, `.dart_tool` and `dist` are not
source and must not be committed. Dependency downloads may use
`http://10.10.100.191:7890` only as a fallback.

## Windows 7 release acceptance checklist

1. Build and test with Rust 1.75, Flutter 3.24.5, the RustDesk Win7 engine and
   `x86_64-pc-windows-msvc`.
2. Verify interactive install, uninstall, service start/stop, custom install
   directory, silent install and silent upgrade on Windows 7 SP1 x64.
3. Confirm executable, service, shortcuts, registry, config and extraction
   paths do not reuse either RustDesk or RustDeskTiny identity.
4. Confirm the service listens on `0.0.0.0:<configured-port>` and accepts an
   authenticated direct connection from another host.
5. Confirm IPv4 and bracketed IPv6 targets connect, while IDs, domains,
   wildcards, missing ports and zero ports are rejected.
6. Confirm focus, typing, polling, failed authentication and completed sessions
   do not rotate the password; explicit refresh and length changes do.
7. Confirm the idle application produces no outbound rendezvous, relay, NAT,
   latency, account or update traffic and no unrelated UDP endpoint.
8. Record the installer SHA-256, update this inventory and do not commit build
   products or dependency caches.
