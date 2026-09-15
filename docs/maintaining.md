# Maintaining and publishing Pickosaurus

## Repository history

This repository starts with a standalone Pickosaurus root commit. Upstream credit
and MIT notices remain in the README and source/binary licences. Do not remove those
notices when modifying or redistributing the app.

Before committing changes:

```sh
python3 scripts/check-publication.py
scripts/test.sh
scripts/build-debug.sh
git diff --check
git status --short
```

Review [licensing](../LICENSING.md), [privacy](../PRIVACY.md) and
[security](../SECURITY_AUDIT.md). Build products, generated Xcode projects, local
signing overrides and credentials are ignored. Do not add the private `RELEASE.md`.

Add an `origin` only after choosing the destination owner/repository. Review what
will be public before pushing `main`. Build and test scripts never create commits,
repositories or pushes.

## CI and releases

The workflows select macOS 26 and Xcode 26.6 for Icon Composer support.
See the [local release-readiness audit](release-audit.md) for validation and outstanding gates.

The Checks workflow builds/tests pull requests and pushes to `main` without signing
secrets. Homebrew is used only on GitHub's hosted runner; local nix-darwin setup
remains managed by Nix. The Release workflow is disabled until the repository
variable `PICKOSAURUS_RELEASES_ENABLED` is set to `true` and a protected `release`
environment has the required signing/notarization credentials. See the README for
the exact variables and local release commands.

Enable GitHub private vulnerability reporting and review branch protections after
creating the repository. Do not configure updater repository/team identity until
you control a stable signed distribution. Never commit signing credentials.

## Manual pre-release checks

Run the locally signed app from a stable location. Check actual link clicks near
each display edge, picker keys and mouse selection, recorder focus/cancellation,
Zoom links, and browser startup. Enable/disable Start at login and check macOS Login
Items, including a real logout/login cycle. Automated tests use an injected service
and deliberately do not modify the current user's login items or join meetings.

Automated checks use a separate `com.pickosaurus.checks` app without registered URL
schemes. Never give test bundles the debug or release browser identity: macOS can
otherwise select a test artifact as the installed copy of the default browser.
