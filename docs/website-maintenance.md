# Website and privacy maintenance

The landing page is `docs/index.html`; `docs/privacy.html` is its policy template.
The policy text has one source in `Pickosaurus/Resources/privacy.txt`, shown offline
from About and inserted into the website build. Keep the opening policy in
`PRIVACY.md` identical; the site checker enforces that consistency. Longer technical
notes remain in [privacy-details.md](privacy-details.md).

## Publishing

1. Set `docs/site.json`: `repository` is optional on GitHub Actions (the workflow
   uses its own repository); `homebrew_command` must be the real, published cask
   command; `privacy_contact` may be a dedicated public email. Empty contact uses
   the project's GitHub issues page. A private email is preferable before release.
2. Update the README's Homebrew section when the tap is published. The current
   checkout has an unpublished cask template, so the site does not invent a working command.
3. Push to the intended repository and select GitHub Actions as the Pages source.
   Run the Publish website workflow if needed. Only the generated HTML/CSS/images
   are deployed, not source code, maintainer notes or build products.
4. Confirm the deployed `/privacy.html` URL and contact link work without signing in.
   Use that stable HTTPS URL in App Store Connect. A custom domain is optional.

The workflow follows [GitHub's Pages guidance](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
and pins the official actions. Preview locally with a repository argument to
`scripts/build-site.py`, then serve `build/site` using Python's HTTP server.

## Disclosures to retain

- The app sends no analytics, routed links, rules, application choices or diagnostic
  reports to the developer. Do not expand this into a promise that no other party
  ever processes data: selected browsers/apps receive links, and clipboard tools
  or backups may retain them.
- Configured standalone update checks contact GitHub. Requests expose IP addresses
  and normal HTTP metadata; the app does not attach routing data. GitHub Pages
  also records visitor IP addresses for security. See [GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages)
  and [GitHub's privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).
- Homebrew has its own optional analytics, separate from the application; users can
  opt out with `brew analytics off`. See [Homebrew's documentation](https://docs.brew.sh/Analytics).
- Support requests contain whatever the sender supplies. Public issues are public.
  If adding an email/support service, document actual handling and retention; do
  not promise that voluntarily submitted messages are never received or stored.

## Before a Mac App Store submission

This wording anticipates distribution through a store without claiming an existing
listing or approval. The current binary is a standalone build, not App Store ready.

- Provide a working policy URL in App Store Connect and link to that URL from the
  app once its final address is known; keep the offline About policy available.
- Use a dedicated sandboxed App Store distribution and remove the standalone
  updater from it. Apple requires sandboxing and App Store updates for Mac App
  Store apps. See [guidelines 2.4.5 and 5.1.1](https://developer.apple.com/app-store/review/guidelines/).
- Complete privacy answers for the actual submitted binary and its services.
  On-device processing is distinct from Apple's definition of collection, but
  assess off-device requests and retained provider metadata before declaring
  “Data Not Collected.” This policy is not an App Store privacy-label certification.
  See [Apple's privacy definitions](https://developer.apple.com/app-store/app-privacy-details/).
- Review required-reason API declarations and the privacy manifest for the final
  build, including preferences and timing APIs; verify the current Apple requirements
  at submission. Store-supplied diagnostics and analytics are governed by Apple and
  user settings, not an analytics SDK bundled by Pickosaurus.

Update the effective date and all policy copies if actual behavior changes.
