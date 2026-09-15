# Maintainer notes

## Checks

```sh
scripts/test.sh
scripts/build-debug.sh
python3 scripts/check-publication.py
git diff --check
```

Keep MIT notices and [artwork credits](../LICENSING.md). Build products, signing
overrides and private `RELEASE.md` notes must remain untracked.

## Releases

Install XcodeGen and `create-dmg`. Configure a Developer ID certificate and Apple
notarization credentials, then run:

```sh
APPLE_TEAM_ID=YOURTEAMID PICKOSAURUS_UPDATE_REPOSITORY=pceiley/pickosaurus scripts/release.sh 0.1.0
```

Notarization uses the `pickosaurus-notary` Keychain profile (`NOTARY_PROFILE` to
override), or `APPLE_ID` and `APPLE_APP_PASSWORD`. Set `SIGN_IDENTITY` if needed.
The script builds, signs and notarizes universal ZIP/DMG artifacts; it does not publish.

Hosted releases require `PICKOSAURUS_RELEASES_ENABLED=true` and signing secrets
in the protected `release` environment. Keep the bundle ID and signing team stable.
Publish the Homebrew cask from `Casks/pickosaurus.rb.in` only after a signed release
exists, then update the README and `docs/site.json` with its install command.

Before releasing, test installation, updates and rollback, link selection, Zoom,
default-browser registration, login items and icons. Include macOS 14 and Intel
hardware. Automated checks do not replace these device checks.

See [website maintenance](website-maintenance.md) for Pages and App Store preparation.
