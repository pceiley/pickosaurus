<p align="center"><img src="branding/pickosaurus.png" width="160" alt="Pickosaurus dinosaur logo"></p>
<h1 align="center">Pickosaurus</h1>
<p align="center">Your links. Your browser. Your choice.</p>

A native macOS menu bar app that opens a quick picker beside your pointer whenever
you click a web link. Choose a browser or application, press its shortcut, or copy
the link. Optional rules send familiar links straight to their destination.

Requires macOS 14 or later. Version **0.1.0** is currently a source build; public
downloads, signing and an update repository have not been configured.

## Features

- Safari, Chrome, Firefox, Edge, Brave, Vivaldi, Zen and Dia, plus added applications.
- Native picker with large destination icons, cached menu items, and plain-key shortcuts.
- **Copy Link** or **⌘C**; plain **C** still selects Chrome when assigned.
- Automatic rules using domains, paths, URL text, regex and source applications.
- AND, OR and NOT conditions, conflict warnings and a tester that never opens links.
- Browser/application availability controls, fallback selection.
- Direct shortcut recording with a **Disable Shortcut** action.
- Opt-in **Start at login** to keep the picker ready.
- No Full Disk Access, Accessibility or Automation permission requests.

## Build and run

Install Xcode 26 or later and XcodeGen using your preferred package manager. On a nix-darwin
managed machine, add `pkgs.xcodegen` to your existing package configuration.
No Swift package dependencies are required.

On macOS 26, the app icon supports system-selected default, dark and tinted
appearances through Icon Composer. Earlier macOS versions use a conventional
icon. The menu bar dinosaur remains a monochrome template icon.

```sh
xcodegen generate
scripts/build-debug.sh
```

The script builds and locally signs
`build/debug-preview/Products/Pickosaurus Debug.app` and creates
`build/debug-preview/Pickosaurus-Debug.zip`. It uses an Apple Development identity
when available, otherwise an ad-hoc signature. Override with
`DEBUG_SIGNING_IDENTITY` or choose another output directory with `DEBUG_BUILD_DIR`.

You can also open `Pickosaurus.xcodeproj` in Xcode. The generated project is ignored;
`project.yml` is the source of truth. Debug builds use `com.pickosaurus.debug` and
separate settings. Release builds use `com.pickosaurus.app`. Automated checks build
`Pickosaurus Checks` with `com.pickosaurus.checks` and no URL-handler registration,
so test runs cannot compete with your default browser.

1. Open `build/debug-preview/Products/Pickosaurus Debug.app`.
2. Choose **Set as Default Browser…** from its menu and confirm the macOS prompt.
   You can also select it in **System Settings → Desktop & Dock → Default web browser**.
3. Choose destinations in **Settings → Browsers** and **Applications**.
4. Click a web link from another application.

New installs have **Settings → General → Link handling → Always show picker** enabled. Turn it
off to use automatic routing. Each browser decides which current/default profile
receives the link; Pickosaurus does not read browser data or select named profiles.

This unreleased version uses a simplified settings format. Old development
settings are not migrated; incompatible settings load the new defaults.

## Fast, every-link picker

Click a destination, press its displayed key, or use arrow keys and Return.
**Copy Link** copies the original full URL and advances any queued links without
opening an application. Escape or a click outside dismisses the current link.

The native menu appears beside the pointer when macOS delivers the URL, fits to
that display and uses native scrolling. macOS does not supply the original click
coordinates. Keyboard-triggered links also use the current pointer location.
Menu items and icons are cached until settings or installed-browser discovery change.
The picker does not create a SwiftUI window, activate the app or toggle its Dock icon.

Distinct incoming links queue in order (up to 100). Duplicate pending/in-flight
links are suppressed, and stale selections cannot open a newer link. Launch
failures return to the picker so you can retry.

## Shortcuts and startup

Default keys: **F** Firefox, **C** Chrome, **S** Safari, **E** Edge, **B** Brave,
**V** Vivaldi, **D** Dia and **Z** Zen. Uppercase and lowercase both work.

In **Settings → Browsers → Installed browsers**, click a browser and press a letter
A–Z or number 0–9. **Disable Shortcut** or Delete removes it; Escape cancels.
Only detected browsers appear, with the shortcut and enabled toggle together in
one row. Keys saved for undetected browsers are freed when editing assignments.
Applications use the same recorder. Keys belong to one destination and are handled
only while the picker is open. There is no global keyboard monitor.

Enable **Settings → General → Startup → Start at login** after placing the signed
app in a permanent location. This uses macOS Login Items with no custom helper or
LaunchAgent. macOS may require approval in Login Items; the toggle reflects its
actual state. Debug and release are separate apps, so enable only your chosen build.

## Applications and Zoom

In **Settings → Applications**, search for an app or use **Browse…**, then add it.
Available, enabled apps appear after browsers in the picker. Assign an optional
picker key or choose **Open in → Application** in a rule.

Add Zoom and choose it for a standard invitation such as
`https://us02web.zoom.us/j/12345678901?pwd=…`. **Create Zoom meeting rule** adds an
automatic rule; turn off **Always show picker** and review rule ordering to use it.

Numeric `/j/` invitations on `zoom.us`, `zoom.com` and their subdomains are converted
locally to Zoom's desktop join scheme, preserving meeting IDs and passcodes.
Registration, sign-in and personal-room links remain browser destinations. Unsupported
Zoom links disable its picker row and skip automatic Zoom rules. No meeting lookup
or URL-expansion request is made.

Other apps receive the original HTTP(S) URL through macOS. Link support depends on
the destination app. Bundle identity is checked, and returned links with the same
sender identity trigger the picker to avoid automatic loops. Disabled or removed
apps cannot receive links; their rules remain available if the app is added again.

## Routing

With **Always show picker** off, rules run in priority order. The first enabled
matching rule with an enabled destination wins. **Any** matches one or more
conditions; **All** requires every condition. **NOT** negates one condition.

**When no rule matches** is a single choice: **Show picker**, or an enabled
browser/application. General settings and the menu bar edit the same choice.
An unavailable default opens the picker instead of silently switching browsers.
A missing browser targeted by a matching rule reports a launch failure.
Source conditions use bundle identifiers; an unknown sender matches neither a
positive nor a negated source condition.

The bundled [matching guide](Pickosaurus/Resources/rule-matching-help.txt) and
[FAQ](Pickosaurus/Resources/faq.txt) provide examples. **Test Rule** previews routing
without visiting a site or changing settings.

## Homebrew

The cask template is in `Casks/pickosaurus.rb.in`. This checkout does not yet
contain a published tap or verified installation command. Until the tap and signed
release are published, use the source build above. Once available, the exact
`brew install --cask owner/tap/pickosaurus` command will be listed here and on the site.

## Website

The landing page and short privacy policy are static HTML/CSS with local images,
no JavaScript, analytics, external fonts or site-added cookies. The policy also
ships offline in **About → Privacy policy**.

Build the website with `python3 scripts/build-site.py --repository owner/repository`,
then run `python3 scripts/check-site.py`. Output is in `build/site`; serve it locally
with `python3 -m http.server 8000 --directory build/site`.
Set the real Homebrew command and optional privacy email in `docs/site.json`.
The Pages workflow takes the repository address from GitHub automatically. Enable
**Settings → Pages → Source → GitHub Actions** after pushing to the public repository.
See [website and App Store preparation](docs/website-maintenance.md).

## Privacy

Routing is local. No analytics, account, persistent browsing-history log or global
input monitoring is included. The app reads installed application metadata; it does not read browser databases, sessions or profiles,
control browser menus, or request Full Disk Access, Accessibility or Automation.
The app is not sandboxed. Your selected browser or app controls subsequent network
activity. Copy Link writes the full URL to the system clipboard on request.

Settings are stored in `~/Library/Application Support/Pickosaurus/config.json`
(debug: `Pickosaurus Debug`), with directory mode `0700` and file mode `0600`.
Rules and preferences are local and unencrypted. UserDefaults holds window and
update preferences. See [PRIVACY.md](PRIVACY.md) and [the audit](SECURITY_AUDIT.md).

Updates are manual, disabled in debug and unconfigured builds, and require the
configured signing identity. The installer only writes where the current user
already has permission; it does not request administrator access.

## Verification

```sh
scripts/test.sh
python3 scripts/check-publication.py
```

The checks build the app and exercise routing, availability, shortcuts, queueing,
clipboard behavior, settings, URL validation, update safeguards and window state.
They use temporary fixtures without launching browsers or changing your settings.
For a real native menu tracking check, run `PICKOSAURUS_MENU_SMOKE=1 scripts/test.sh`.
This briefly shows test menus without launching destinations.

Tests report cached menu preparation separately from OS delivery, display and
browser startup. Instruments' Points of Interest records routing stages without
URL or sender data. A launch-completed marker means the macOS operation returned,
not that a web page finished loading.

Regenerate artwork sizes and the installer background with `scripts/generate-branding.sh`.

## Releases

Release tooling requires your own Developer ID certificate, Apple notarization
credentials, XcodeGen, and `create-dmg` (`pkgs.create-dmg` with nix-darwin).
Set `APPLE_TEAM_ID` and `PICKOSAURUS_UPDATE_REPOSITORY=owner/repository`, then run
`scripts/release.sh 0.1.0`. Set `SIGN_IDENTITY` if multiple certificates are installed.
Notarization uses `APPLE_ID` and `APPLE_APP_PASSWORD`, or the Keychain profile
`pickosaurus-notary` (override with `NOTARY_PROFILE`).

The script embeds the configured repository and team, verifies the app identity,
notarizes and staples the app and DMG, and requires a successful Gatekeeper check.
It builds ZIP and DMG artifacts locally; it does not publish them. Keep the same
bundle ID and team for subsequent releases. Verify signed releases with:

```sh
APPLE_TEAM_ID=YOURTEAMID scripts/test-release-identity.sh /path/to/Pickosaurus.app
```

The GitHub release workflow is gated by the repository variable
`PICKOSAURUS_RELEASES_ENABLED=true`. Configure the `release` environment and its
signing/notarization secrets before enabling it. The workflow uploads only to its
own repository; it does not modify a separate package tap. `Casks/pickosaurus.rb.in`
is an unpublished template: fill its repository, version and SHA-256 placeholders
only after a real release exists.

## Credits and license

Pickosaurus is inspired by **[Browserino](https://github.com/AlexStrNik/Browserino)**
and **[Browserosaurus](https://github.com/will-stone/browserosaurus)**, especially
their quick, focused approach to choosing where a link opens.

Pickosaurus is a fork of **[Browser Picker (browser-picker)](https://github.com/mertizci/browser-picker)**
by **Mert IZCI**. Thank you for the original application and its browser/profile
routing functionality. The original MIT copyright and permission notice are
preserved in [LICENSE.md](LICENSE.md) and bundled with the app.

The Pickosaurus dinosaur artwork was generated with ChatGPT and supplied by the
maintainer for this fork. Browser/application icons
come from installed apps at runtime; missing apps use generic system symbols.
Vendor logos are not bundled. See [the licensing review](LICENSING.md) and
[bundled notices](Pickosaurus/Resources/NOTICES.txt) for the asset inventory and limits.
The upstream project name appears here solely for attribution. The repository
starts with a standalone Pickosaurus root commit; the original MIT notices remain
in source and binary distributions.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development checks and
[maintainer notes](docs/maintaining.md) for the first commit/push and release setup.
