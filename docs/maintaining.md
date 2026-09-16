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
The Homebrew cask lives in [pceiley/homebrew-pickosaurus](https://github.com/pceiley/homebrew-pickosaurus).
After publishing a signed, notarized ZIP, update `Casks/pickosaurus.rb` in that tap
with the release version and the published ZIP's SHA-256 checksum. The source
template is `Casks/pickosaurus.rb.in` in this repository. Validate the cask and
download checksum before committing and pushing the tap update. The website's
install command is configured in `docs/site.json`.

Before releasing, test installation, updates and rollback, link selection, Zoom,
default-browser registration, login items and icons. Include macOS 14 and Intel
hardware. Automated checks do not replace these device checks.

See [website maintenance](website-maintenance.md) for Pages and App Store preparation.
