# Contributing

Pickosaurus targets macOS 14 or later and uses Swift, AppKit and SwiftUI. Install
Xcode 26 or later and XcodeGen. On nix-darwin, add `pkgs.xcodegen` to your system configuration.
There are no Swift package dependencies. Python 3 runs the publication checks.

`project.yml` is the project source; XcodeGen output and build products are ignored.
Use `scripts/build-debug.sh` for a locally signed debug app with its own settings
and permission identity. Keep credentials, signing overrides and user data out of
commits. Do not test with real meeting passcodes or confidential URLs in fixtures.

Before opening a change:

```sh
python3 scripts/check-publication.py
scripts/test.sh
git diff --check
```

The tests use temporary settings and do not launch browsers or register login
items. The optional `PICKOSAURUS_MENU_SMOKE=1` test displays native menus and
exercises AppKit dispatch without visiting a URL. Changes to permissions, startup
or browser launching also need a manual check on a development build.

Preserve copyright and licence notices. Submit only contributions you have the
right to distribute under the repository's MIT licence, and document the source
and terms of any artwork or other third-party material. Avoid bundling vendor
logos; use installed application icons or generic system symbols instead.

For a suspected security issue, use GitHub's private vulnerability reporting if
the repository has enabled it. Do not post credentials, private URLs or exploits
against other people's systems in a public issue. See `SECURITY_AUDIT.md` for the
current review scope and limitations.
