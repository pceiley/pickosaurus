# Pickosaurus privacy: technical details

This describes the source in this fork, reviewed on 15 September 2026.

## Data handled locally

Pickosaurus receives the complete HTTP(S) URL and, when macOS provides it, the
sender application's bundle identifier. It evaluates rules locally and passes
the link to your selected browser. URLs waiting for selection are held
in memory. There is no persistent link-history feature or analytics integration.

Browser and application discovery reads installed application names, bundle IDs,
paths and icons through macOS. The source-app selector uses Spotlight and standard
application directories.

The app does not read browser databases, sessions, profiles or container metadata.
It does not control other applications' menus or send simulated keystrokes. No
Full Disk Access, Accessibility or Automation permission is requested. The app is
not sandboxed; removing these features does not add a sandbox boundary.

Picker keyboard shortcuts use native menu key handling only while the picker is
open. There is no global keyboard monitor or keypress log. Browser/key
assignments are stored with settings.

Shortcut recording reads keys only in its focused settings popover; it does not
record global input. Start at login is opt-in and registers this app with macOS
Login Items using ServiceManagement. macOS owns that registration state. Disabling
the setting unregisters it; no custom LaunchAgent or helper is installed.

The picker reads the pointer position when a link arrives so it can appear nearby.
Pending links, sender identities and positions are held only in a bounded in-memory
queue until selected, dismissed or the app exits. Performance markers record stages
of routing without URLs, hosts, passcodes, application identities or keypresses.

Copy Link (⌘C) writes the original full URL, including query parameters and any
fragment, to the system clipboard only when selected. It does not open a browser.
macOS Universal Clipboard or clipboard managers may retain or share copied data
according to their settings; the app does not clear it automatically afterward.

Added application destinations store their bundle identifier, display name, saved
installation path, enabled state and optional picker key. Links are handed to the
explicitly chosen application via macOS. Zoom meeting links are converted locally
to `zoommtg` URLs; meeting IDs and passcodes are passed to Zoom and are not logged
by Pickosaurus. Other apps receive the original web URL. Those applications control
any subsequent network activity and may open a meeting, navigate, or perform other
link-specific actions.

A bounded, short-lived in-memory record of recent application handoffs helps detect
returned links and avoid automatic routing loops. It is not saved to disk.

## Storage and retention

- `~/Library/Application Support/Pickosaurus/config.json` stores rules, destinations,
  picker preference and browser availability. Debug uses `Pickosaurus Debug`.
- Settings directories use `0700`; saved config files use `0600`. The JSON is not encrypted.
- UserDefaults stores window preferences and, during an update, pending version/notes.
- Update downloads and staging files are temporary. Normal success/error paths clean
  them up; crashes or failed replacement may leave artifacts for manual cleanup.
- There is no sync service. Files may still be included in your system backups.

Quit the app and remove its settings directory and its `com.pickosaurus.app`
preference domain to reset release data. Use `com.pickosaurus.debug` for debug.
If an earlier development build was granted Full Disk Access, Accessibility or
Automation, those grants can be removed in System Settings; this build does not need them.
Uninstalling the app alone does not necessarily remove settings or macOS grants.

## Network access and other processes

Launching Pickosaurus does not make an update request. Update checks are explicitly
initiated by the user and require a configured release repository and signing team.
Debug builds disable the updater. Configured checks access `api.github.com`; chosen
installers are downloaded from `github.com` and GitHub's release asset hosts over HTTPS.
GitHub receives connection metadata and the `Pickosaurus` user agent, but no routing
rules, destination lists or routed URLs are added to update requests. Sessions are ephemeral.

Help is bundled text shown in a native, read-only AppKit text view, with selection
and Find support. It does not load web pages, execute scripts or auto-link URLs.
The static website uses local assets and has no scripts, remote fonts or analytics.
Its hosting provider can still keep normal access logs.

Your chosen browser receives full links, including query strings and fragments.
Links are sent using the macOS application-opening API.
Browser subprocesses and macOS may maintain their own logs or diagnostics. Browser
history, website tracking and crash reporting are outside Pickosaurus's control.

See [SECURITY_AUDIT.md](../SECURITY_AUDIT.md) for the reviewed scope and limitations.
