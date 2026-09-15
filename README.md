<p align="center"><img src="branding/pickosaurus.png" width="160" alt="Pickosaurus dinosaur logo"></p>
<h1 align="center">Pickosaurus</h1>
<p align="center">A fast, lightweight link picker for macOS.</p>
<p align="center"><a href="https://pceiley.github.io/pickosaurus/">Website</a> · <a href="https://pceiley.github.io/pickosaurus/privacy.html">Privacy</a></p>

Choose where your links open. Pickosaurus displays a picker beside your pointer,
so you can click a destination, press a shortcut or copy the link.

## Features

- **Built for speed and efficiency.** Native macOS menus, cached icons and optional start at login.
- **Your choice.** Supports all major browsers and added applications, including Zoom meeting links.
- **Quick controls.** Assign a key to each destination, or copy a link with ⌘C.
- **Optional rules.** Automatically route links by domain, path or source application.
- **Private.** No data collection, analytics or tracking. No elevated permissions required.

## Build and run

Requires macOS 14+, Xcode 26+ and XcodeGen. No Swift package dependencies.

```sh
git clone https://github.com/pceiley/pickosaurus.git
cd pickosaurus
scripts/build-debug.sh
open "build/debug-preview/Products/Pickosaurus Debug.app"
```

Choose **Set as Default Browser…** from the menu bar, then click a link in another
app. Use **Settings** to choose destinations, assign shortcuts and enable
**Start at login**. Turn off **Always show picker** to use routing rules.

### Homebrew

Coming later. For now, build from source. A Mac App Store version is also planned.

## Privacy

Links and settings stay on your Mac until you send a link to a destination or copy
it. Optional manual updates contact GitHub; this website uses GitHub Pages.
See the [privacy policy](PRIVACY.md) for details.

## Credits and license

Inspired by [Browserino](https://github.com/AlexStrNik/Browserino) and
[Browserosaurus](https://github.com/will-stone/browserosaurus).
Based on [Browser Picker (browser-picker)](https://github.com/mertizci/browser-picker)
by Mert IZCI, with the original [MIT licence](LICENSE.md) and notices retained.

Dinosaur artwork generated with ChatGPT and refined for Pickosaurus.
[Artwork and third-party notices](LICENSING.md).

For development, see [Contributing](CONTRIBUTING.md) and
[maintainer notes](docs/maintaining.md). Usage examples are in the app's Help menu.
