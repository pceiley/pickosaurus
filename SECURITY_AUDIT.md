# Pickosaurus security and privacy audit

**Review date:** 15 September 2026
**Scope:** the current Pickosaurus source, including the standalone history reset.
**Method:** source/configuration review, local regression checks and macOS builds.
This is a scoped engineering review, not a guarantee that all vulnerabilities have
been eliminated.

## Removed capabilities

Browser profile/session/database readers, Safari/Dia/Zen UI automation, AppleScript
execution, permission probing/polling, permission onboarding and the Apple Events
sending entitlement have been removed. The app no longer links SQLite or decodes
browser session files. Browser launches use `NSWorkspace.open` with the original
HTTP(S) URL. Rules still match locally, including source-app identity provided by
incoming macOS URL events. No Full Disk Access, Accessibility, Automation or global
keyboard permission is requested. Start at login uses macOS Login Items with user
opt-in; no custom helper or LaunchAgent is installed.

Unreleased profile-specific settings and migration code were removed. Incompatible
old development settings load defaults. No previous user settings are modified by
the regression checks.

## Reviewed boundaries and protections

| Area | Protection and scope |
| --- | --- |
| Incoming URLs | HTTP(S), host validation and 32 KiB limit before routing/launch. No local-document handler. |
| Routing | Ordered rules, enabled destinations, AND/OR/NOT. Regex progress deadline fails closed, including under NOT. Unknown source identities never satisfy source conditions. |
| Picker | Bounded 100-link in-memory queue, duplicate suppression, request-ID checks and cached native menu. No global input monitor or URL logging. |
| Clipboard | Explicit Copy Link/Command-C copies the original URL after menu tracking. Tests use a private named pasteboard. |
| Destinations | Installed application bundle identity checks, self-routing prevention, fixed Zoom conversion with host/parameter validation. No user-defined shell commands. |
| Returned links | Bounded, expiring application handoff tracker avoids loops when the returning sender can be identified. |
| Local settings | Atomic writes in an owner-only `0700` directory; config mode `0600`. Failed edits report errors and preserve live settings. |
| Help and website | Native, read-only text help with no WebKit or active links; static website uses local assets with no analytics. |
| Updates | Manual only; disabled in debug and unconfigured builds. Repository HTTPS allowlist, redirect restrictions, response/size checks and signature validation. Trust comes from the configured release identity. |
| Installation | Verified copy prepared on the destination volume; rename backup and rollback on replacement failure. Positional shell arguments protect paths. No administrator escalation; unwritable installations fail. |
| Release pipeline | Pinned checkout, no persisted checkout credentials, opt-in workflow, no cross-repository tap publishing. Packaging and Gatekeeper failures stop release. |
| Branding/licensing | Original MIT notice preserved in source and app, upstream credit in README, runtime vendor icons instead of bundled copies. See LICENSING.md. |

No third-party Swift packages or analytics SDKs are declared. The app uses Apple
system frameworks. XcodeGen, packaging utilities and GitHub Actions are development
and distribution dependencies.

## Remaining limitations

- The app is not sandboxed. Removing elevated-permission features reduces capability
  but does not establish a sandbox boundary. macOS permissions previously granted to
  a development build should be removed manually if no longer desired.
- Local JSON and rule patterns are trusted user input with no overall
  file-size budget. Large input can consume resources. Settings are unencrypted and
  can appear in backups.
- Browsers control the selected profile and network behavior. Generic application
  web-link support varies. Helper processes or unknown senders can limit loop detection.
- Clipboard managers and Universal Clipboard can retain/share copied URLs according
  to their settings. macOS and destination applications may produce their own logs.
- Update rollback covers a failed replacement rename, not power loss, process death,
  same-user tampering or a failed rollback. Staging artifacts may need manual cleanup.
- Real signed/notarized releases, GitHub/CDN integration, full install/relaunch,
  logout/login and third-party application behavior require release-environment/manual
  testing. No network penetration test or exhaustive credential/legal audit was performed.
- Public repository, Developer ID and notarization configuration remain unset.

## Verification

The [release-readiness code audit](docs/release-audit.md) records the 15 September
performance/persistence fixes, universal build verification and remaining release gates.

Thirteen standalone executables cover browser/application routing, availability,
picker queue/cache/clipboard/shortcuts, rule editing/conflicts/testing, source
identity, login-item state, window behavior, URL safety and update safeguards.
Conflict checks compare 1,553 matching URL/source cases against the real matcher.
Tests use temporary fixtures, never launch destination browsers or join meetings,
and do not register this machine for login.

The publication checker verifies source inclusion, MIT notice consistency, local
links/assets and common secret patterns. It also rejects permission APIs,
automation entitlements and browser-data readers in the app source. This is a
regression guard, not proof that arbitrary future code cannot access private data.

Run `scripts/test.sh` and `python3 scripts/check-publication.py`. For native menu
tracking, use `PICKOSAURUS_MENU_SMOKE=1 scripts/test.sh`. No hosted CI run or public
release is claimed by this local review.

Local verification passed: all thirteen check executables, native menu dispatch,
debug build and strict signature verification, and publication checks. The signed
debug app has an empty entitlement dictionary and no direct SQLite dependency.
