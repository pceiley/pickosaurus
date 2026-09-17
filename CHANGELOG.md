# Changelog

## 0.2.1 — 2026-09-17

- Fixed the release executable's runtime search path so the embedded Sparkle
  framework loads when Pickosaurus starts.
- Added build and release checks for embedded-framework loading.

## 0.2.0 — 2026-09-17

- Replaced the custom updater with Sparkle 2.10.0 and pinned the package version.
- Kept update checks explicitly manual, with automatic checks, downloads and
  system profiling disabled.
- Added signed appcast and archive verification, release-feed generation and
  complete bundled Sparkle licence notices.
- Deferred app-window foreground activation until menu dismissal completes so
  settings, help and update windows reliably receive focus.

## 0.1.0 — 2026-09-15

First Pickosaurus source release, with a standalone root commit and retained upstream MIT notices.

- Dinosaur branding and a transparent monochrome menu bar icon.
- Native picker beside the pointer, larger destination icons, cached menu items,
  keyboard selection and safe queuing of multiple links.
- Copy Link with Command-C, available even when no browser is enabled.
- Direct shortcut recording for browsers and applications, with conflict detection
  and an explicit disable action.
- Optional start at login through macOS Login Items.
- Custom application destinations, including supported Zoom meeting invitations.
- Browser/application selection, ordered routing rules and a read-only rule tester.
- Picker enabled by default; automatic routing needs no additional privacy permissions.
- Removed profile/space discovery, browser UI automation, permission onboarding, SQLite
  linking and unreleased settings migration.
- Isolated debug builds, local-first privacy defaults and security hardening.
- Native, searchable text help without WebKit; standard application icons only.
- Browserino-inspired destination-first picker with stronger labels, larger icons,
  a compact hostname footer and native keyboard navigation.
- Browserino and Browserosaurus inspiration credits in the app, README and website.
- Licensing/asset review, publication checks and CI configuration.

See [the README](README.md) for installation and
[licence and artwork notes](LICENSING.md) for third-party notices.
