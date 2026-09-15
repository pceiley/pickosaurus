# Pickosaurus artwork

[Dinosaur.svg](../Pickosaurus/AppIcon.icon/Assets/Dinosaur.svg) is the editable
vector master for the app mascot. It contains paths, ellipses and gradients, with
no embedded bitmap or external resources. It was manually redrawn from the supplied
ChatGPT-generated design on 15 September 2026, preserving the pose and palette
while simplifying shading and replacing noisy cutout edges with clean curves.
The original is retained as [a reference](reference/pickosaurus-original.png).
`pickosaurus.png` is the standard appearance export for website and legacy assets.
`pickosaurus-menubar.png` is the separate black dinosaur stencil with a transparent
background, used only for the menu bar. macOS renders it as a template image so its
color follows the menu bar appearance. The asset catalog includes 20 px and 40 px
versions for standard and Retina displays.

Run `scripts/generate-branding.sh` to regenerate the sizes and installer background.
This requires Xcode 26 with Icon Composer. It exports the vector app icon before
resizing website/legacy assets; the menu stencil retains its separate master.

The native macOS 26 app icon is [AppIcon.icon](../Pickosaurus/AppIcon.icon/icon.json),
an Icon Composer document with a separate transparent dinosaur foreground,
a teal default background and Apple's system dark background. macOS supplies
tinted rendering. Xcode compiles this document alongside the legacy asset catalog;
no runtime theme observer or additional permission is needed. Open the `.icon`
document in Icon Composer to edit it. The branding script does not overwrite it.

Icon Composer uses the vector foreground at 80% scale. Its default, dark and tinted
renders were checked at 32 px; the silhouette, eye and finger remain distinguishable.
At 16 px the fine facial details necessarily soften. The separate menu bar stencil
serves the smallest monochrome presentation.

Built-in image generation was tried for raster edge cleanup, but both candidates
retained background/alpha artefacts and were not shipped. See the
[refinement prompts](refinement-prompts.md). The vector master replaces that raster
foreground and can be exported at larger resolutions without upscaling a bitmap.

The menu bar stencil was created with the built-in image generation tool, then
converted locally to black RGB with real alpha transparency after the generated
image incorrectly included a checkerboard. See [the generation prompts](menubar-prompt.md).

The maintainer confirmed on 14 September 2026 that the original colour artwork was
generated with ChatGPT. This note records its origin; OpenAI does not require an
attribution credit for generated images, per its [image guidance](https://openai.com/academy/image-generation/).
The artwork is distributed with the project under MIT to the extent the maintainer
holds applicable rights. Generation is not proof of copyright protection, exclusive
ownership or trademark clearance. See [the licensing review](../LICENSING.md).
Vendor browser logos are not bundled.

The finger, palm and forearm were refined together to keep the fingertip aligned
with the nostril without a backward bend. The cream forearm marking was removed
so the hand no longer appears to hold an unidentified object.
