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

Install XcodeGen and `create-dmg`. Configure a Developer ID certificate, Apple
notarization credentials and Sparkle's EdDSA signing key, then run:

```sh
APPLE_TEAM_ID=YOURTEAMID \
PICKOSAURUS_UPDATE_REPOSITORY=pceiley/pickosaurus \
SPARKLE_PUBLIC_ED_KEY=BASE64_PUBLIC_KEY \
scripts/release.sh 0.1.0
```

Create the Sparkle key once with the pinned package's `generate_keys` tool after
an initial build. Keep its private key in the maintainer's login Keychain and
store an encrypted backup outside the repository. The tool prints the public key
used above; exporting with `generate_keys -x /secure/path` produces the private
value for the protected `SPARKLE_PRIVATE_KEY` CI secret. Add the public value as
the protected `SPARKLE_PUBLIC_ED_KEY` secret. Never commit either private-key
material or a release-specific signing override.

Before each release build, increment the integer `CURRENT_PROJECT_VERSION` in
`project.yml`. The script sets the marketing version from its argument and keeps
this separate build number for the About window.

Notarization uses the `pickosaurus-notary` Keychain profile (`NOTARY_PROFILE` to
override), or `APPLE_ID` and `APPLE_APP_PASSWORD`. Set `SIGN_IDENTITY` if needed.
The script builds, signs and notarizes universal ZIP/DMG artifacts, then signs an
`appcast.xml` feed with Sparkle. Set `SPARKLE_RELEASE_NOTES` to embed Markdown
release notes; the hosted workflow uses the GitHub release body. The script does
not publish. Local signing reads the Sparkle private key from the Keychain; CI
passes it to `generate_appcast` over standard input so it is never written to disk.

Hosted releases require `PICKOSAURUS_RELEASES_ENABLED=true` and the Apple and
Sparkle signing secrets in the protected `release` environment. The workflow
uploads the signed appcast with the ZIP and DMG. Keep the bundle ID, Developer ID
team and Sparkle key stable; review Sparkle's key-rotation guidance before changing
either signing identity.
The Homebrew cask lives in [pceiley/homebrew-pickosaurus](https://github.com/pceiley/homebrew-pickosaurus).
After publishing a signed, notarized ZIP, update `Casks/pickosaurus.rb` in that tap
with the release version and the published ZIP's SHA-256 checksum. The source
template is `Casks/pickosaurus.rb.in` in this repository. Validate the cask and
download checksum before committing and pushing the tap update. The website's
install command is configured in `docs/site.json`.

Before releasing, test installation, Sparkle updates and rollback, link selection, Zoom,
default-browser registration, login items and icons. Include macOS 14 and Intel
hardware. Automated checks do not replace these device checks.

See [website maintenance](website-maintenance.md) for Pages and App Store preparation.
