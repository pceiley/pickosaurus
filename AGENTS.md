# Working on Pickosaurus

## Product priorities

Keep Pickosaurus simple, fast, efficient, secure and private. It is a lightweight
macOS link picker, not a browser or browser-management suite. Prefer small native
solutions and fewer dependencies, settings and background tasks.

## Performance

- Protect cold startup, click-to-picker display and selection-to-application handoff.
  Always showing the picker is the primary use case and the default experience.
- Keep the picker close to the pointer and ready to use. Reuse cached menus and
  icons; avoid discovery, file I/O, network requests or expensive work per link.
- Preserve native menu tracking and keyboard behavior. Do not replace native rows
  with custom rendering merely for appearance without evidence that display speed
  and responsiveness are preserved.
- Do not ship a known performance regression for cosmetic polish. If the impact
  is uncertain, measure it or retain the existing implementation and report the
  uncertainty. Do not promise zero overhead based on intuition.
- Menu-preparation benchmarks exclude OS delivery, onscreen rendering and browser
  startup. Never present them as end-to-end latency measurements. Check cold and
  warm behavior when changing startup or the picker lifecycle.
- Preserve reliability under rapid links, cancellation, unavailable destinations
  and launch failures. Performance work must not weaken validation or safeguards.

## Privacy and permissions

- No analytics, telemetry, tracking, app-provided crash uploads or browsing-history
  collection. Do not log full URLs, query strings, meeting passcodes or routing data.
- Keep rules and preferences local. Do not add Full Disk Access, Accessibility,
  Automation, administrator privileges or browser-profile/database access.
- Keep the updater, with explicit manual checks and signature/identity validation.
  Networking for updates must stay separate from link handling.
- Retain accurate privacy disclosures for GitHub updates/hosting, selected apps,
  clipboard services and support requests. Do not claim that no network activity
  ever occurs. Never commit credentials or signing material.

## Interface and documentation

- Use “picker” consistently. Aim for restrained, sharp, native macOS styling.
- Show detected browsers; keep enablement and direct shortcut recording together.
  Shortcuts must be removable. Preserve Copy Link and optional start at login.
- Make routing behavior clear: always showing the picker bypasses rules; otherwise
  the fallback is either the picker or one destination.
- Keep the README and website brief and useful: speed, efficiency, setup, privacy
  and credits. Say “all major browsers” rather than maintaining marketing lists.
  Keep the website link in the README and installation claims accurate.
- Do not add lengthy audit reports to the repository unless requested. Keep
  necessary security reporting instructions and privacy disclosures concise.
- Preserve upstream MIT notices and Browserino/Browserosaurus inspiration credits.
  Use installed application icons; do not bundle third-party browser logos.

## Local work and validation

- The maintainer uses nix-darwin. Identify missing tools and suggest Nix packages;
  do not install them locally with Homebrew. Hosted CI may use Homebrew.
- `project.yml` is the project source. Do not commit generated Xcode projects,
  build products, local signing overrides or private release notes.
- Follow [CONTRIBUTING.md](CONTRIBUTING.md) for checks. Use the native menu smoke
  test for interaction changes and distinguish automated checks from manual tests.
- Keep debug and test identities separate from the release app. Tests must not
  change the user's default browser, login items, real settings or open real links.
- Avoid speculative compatibility layers for unreleased settings. Once a format
  has shipped, assess migration needs before changing it.
- Preserve unrelated local changes. Use [maintainer notes](docs/maintaining.md)
  for signing and release procedures rather than duplicating them here.
