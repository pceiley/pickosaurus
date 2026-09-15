# Release-readiness code audit

Reviewed 15 September 2026. Scope: local source, routing and picker behavior,
settings persistence, updater, icon packaging and release workflows. Existing
uncommitted product changes were preserved. No repository was pushed or published.

## Fixed during this review

| Finding | Change | Verification |
| --- | --- | --- |
| General preferences and rule edits changed live state before saving; a failed save could silently lose edits on restart. | Settings commit only after a successful write. Errors reach the relevant window; a failed rule save keeps its draft open. | Forced write failures for preference changes, add/edit/delete/reorder, toggles and duplicates preserve settings and menu-cache revision. |
| Routing resolved the fallback even when an earlier rule or picker choice made it irrelevant. | Lazy fallback availability; resolve only the selected destination instead of enumerating all added apps. | Regression asserts no lookup for matched rules or picker fallback, one lookup for automatic fallback. |
| Each regex evaluation compiled its expression for validation and again for matching; every matcher also decoded URL components it might not need. | Reuse compiled expressions in a bounded NSCache, extract only required components, use a monotonic regex deadline. | Existing literal, regex, interrupted-regex, NOT and 1,553 conflict/matcher cases pass. |
| Rule selection allocated three filtered arrays and checked later destinations before choosing an earlier match. | One priority sort followed by short-circuit selection. | Rule ordering and application/Zoom routing checks pass. |
| A stale cancellation could still close the tracking menu after its queue ID was rejected. | Return immediately when cancellation does not match the current request. | Stale cancellation preserves the current request; queue and native tracking checks pass. |
| Download progress could enqueue excessive UI updates and arrive after the installer had advanced state. | At most one notification per percentage point; ignore late notifications outside downloading. Also verify the completed file against the existing 512 MiB limit. | Builds and existing updater safeguards pass; live GitHub/CDN downloading remains a release-environment check. |
| Hosted workflows used an older default toolchain despite the native icon requirement. | macOS 26 runner with Xcode 26.6; publication checks before release signing; explicit universal release architectures and versioned build number. | Local Xcode 26.6 optimized build contains both arm64 and x86_64. Hosted execution remains unverified. |

The regex reuse relies on Foundation's documented immutable, thread-safe
[NSRegularExpression](https://developer.apple.com/documentation/foundation/nsregularexpression).
The CI toolchain selection follows GitHub's
[macOS 26 runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md).

## Local validation

- All 13 regression executables passed, including the new persistence and lazy-lookup cases.
- Native menu smoke passed: plain C versus Command-C, browser keys, cancellation,
  and no Dock-policy change or destination launch.
- Warm menu preparation: 1,000 iterations, median and p95 0.003 ms on this Mac.
  This measures cached menu preparation only, excluding OS event delivery,
  onscreen display and browser startup. It is not a click-to-browser latency claim.
- Optimized universal Release build succeeded; both architectures are present.
- Debug rebuild, local signing and strict signature verification succeeded.
- Publication and whitespace checks passed. Release shell syntax checked.

No runtime dependency, background polling, analytics or elevated permission was added.
The picker still bypasses all automatic rules when Always show picker is enabled.

## Before calling the release ready

The remaining gates are distribution and real-system testing, not a promise of
unlimited performance or complete security:

1. Configure the owned GitHub repository and Developer ID/notarization credentials.
   The repository currently has no remote; updater identity is unconfigured by default.
2. Run hosted CI and a signed/notarized package through Gatekeeper. Test a real
   update across two signed versions, including rejection and rollback paths.
3. Test on the minimum supported macOS 14 and real Intel hardware. Cross-compilation
   checks both architectures but does not establish runtime compatibility.
4. Confirm link clicks, focus, shortcuts, default-browser registration, actual Zoom
   handoff, and logout/login from a stable installed location. Verify Finder/Dock
   light/dark icons using the installed build; compiled variants alone are not visual proof.

Settings JSON remains trusted local input: malformed/incompatible JSON currently
loads defaults, and there is no overall file-size/rule-count budget. The existing
regex deadline is per evaluation, not a global budget for arbitrarily large rule
sets. If configuration import is introduced, validate and bound inputs first.
See [the security review](../SECURITY_AUDIT.md) for the wider limitations.
