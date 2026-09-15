# Website maintenance

Edit `docs/index.html` and `docs/styles.css`. Preview locally:

```sh
python3 scripts/build-site.py
python3 scripts/check-site.py
python3 -m http.server 8000 --directory build/site
```

Push to `main` to deploy through GitHub Pages. Only `build/site` is published.
Set the published Homebrew command and optional contact email in `docs/site.json`.

The privacy policy comes from `Pickosaurus/Resources/privacy.txt`. Keep `PRIVACY.md`
identical; it also ships offline in About. Retain the disclosures about destinations,
clipboard services, backups, GitHub updates/hosting and support messages.

Before App Store submission, prepare a sandboxed build without the standalone
updater, link the live privacy policy in the app and App Store Connect, and review
Apple's current privacy-label and manifest requirements for the submitted binary.
