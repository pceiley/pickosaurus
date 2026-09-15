# Licensing and artwork review

Reviewed 14 September 2026. This is a repository and asset review, not a legal
opinion or a guarantee against infringement. Copyright, trademark and jurisdiction
questions can require advice from a qualified lawyer before public distribution.

## Software

The upstream project is credited and linked in the [README](README.md). Its MIT
licence permits modification and redistribution provided the copyright and
permission notice are retained. The original 2026 Mert IZCI notice and full MIT
text remain in [LICENSE.md](LICENSE.md), with a separate notice for Pickosaurus
contributions. The same text ships in [the app](Pickosaurus/Resources/LICENSE.txt).
Git history starts with a standalone Pickosaurus root commit. The retained notices
and README credit document its upstream origin. New contributions remain MIT licensed.

The reviewed project declares no third-party Swift package dependencies. AppKit,
SwiftUI, ServiceManagement, other Apple frameworks are system libraries;
no copies of those libraries or vendor browser executables are bundled. XcodeGen
and packaging tools run during development and are not part of the application.
This review cannot establish the provenance of every line inherited from upstream.

Reference: [OSI's MIT licence text](https://opensource.org/license/mit).

## Icons and names

| Material | Provenance and treatment |
| --- | --- |
| Colour dinosaur, app icons, website icons, installer background | The maintainer confirmed on 14 September 2026 that the logo was generated with ChatGPT for this fork. The original is retained in `branding/reference/pickosaurus-original.png`; current colour exports use the vector refinement described below. Distributed under MIT to the extent the maintainer holds applicable rights. |
| Monochrome dinosaur menu icon | Generated for this fork from the supplied dinosaur, then converted into a transparent stencil. Its provenance follows the supplied reference. Prompts and processing are documented in [branding](branding/README.md). |
| Themed app icon foreground | Original vector paths manually authored from the supplied colour artwork on 15 September 2026, replacing the generated raster cutout. No third-party vector artwork was imported. Icon Composer supplies background and appearance treatments. The foreground follows the original artwork's MIT rights treatment; processing is documented in [branding](branding/README.md). |
| Browser/application icons | Loaded from installed apps through macOS at runtime to identify destinations. They are not copied into the repository or app resources. No ownership or endorsement claim is made. |
| Generic interface symbols | SF Symbols requested from Apple frameworks on macOS; no standalone symbol assets are redistributed. These are governed by Apple's terms, not the repository's MIT grant. |

Three inherited fallback browser SVGs and their inaccurate MIT attribution were
removed. Simple Icons actually publishes under CC0 and expressly distinguishes
that licence from third-party brand rights. Missing applications now use a generic
system globe. The standalone repository starts with the current source; inherited
Git history and vendor artwork are not included. These removals do not constitute
a trademark search or a guarantee against third-party claims.

References: [Simple Icons licence](https://github.com/simple-icons/simple-icons/blob/develop/LICENSE.md),
[brand-rights disclaimer](https://github.com/simple-icons/simple-icons/blob/develop/DISCLAIMER.md),
[Apple developer terms](https://developer.apple.com/support/terms/).

The MIT licence does not give recipients rights to third-party marks or material
the contributor does not own. Browser/app names identify compatibility only.
Pickosaurus has not undergone a trademark-register search or a worldwide name
clearance; do not claim that the name or AI-assisted artwork is legally exclusive.

## Generated artwork

OpenAI's [image-generation guidance](https://openai.com/academy/image-generation/)
states that attribution for generated images is optional. The short ChatGPT note
in the README records provenance; it is not an additional attribution licence
condition. Under the [Terms of Use](https://openai.com/policies/row-terms-of-use/),
output belongs to the user as between the user and OpenAI, to the extent permitted
by applicable law. Users remain responsible for their inputs and third-party
rights. The terms also prohibit presenting AI output as human-generated.

This is not a guarantee that generated artwork is copyrightable, unique or free
of third-party rights. The original prompts and any reference inputs were not
independently audited in this review.

## Before publication

Keep the MIT licence and
bundled notices in source and binary distributions. The publication checker verifies
notice consistency and scans candidate files for common credential patterns; it
does not replace legal review or an exhaustive secret scan.
