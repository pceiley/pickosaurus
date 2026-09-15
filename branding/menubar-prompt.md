# Menu bar icon generation

Tool: built-in image generation, using `pickosaurus.png` as the edit target.
Final asset: `pickosaurus-menubar.png`.

## Design prompt

Use case: style-transfer. Edit target: supplied Pickosaurus dinosaur logo. Asset type: monochrome macOS menu bar template icon, square transparent PNG. Convert this specific smiling dinosaur picking its nose into a simple, bold black single-ink pictogram with TRUE TRANSPARENT background. Keep the recognizable right-facing large snout, head spikes, friendly eye, smile, and finger at its nostril. Show just the dinosaur head/short neck and raised finger; remove the rounded square teal background completely, remove surrounding accent marks and body spots. Use solid black forms and thick economical black strokes with transparent negative-space cutouts for the eye, nostrils and separation of hand from head. All visible pixels black, anti-aliased transparency only; NO opaque white areas, NO gray fills, NO colors, NO gradients, NO shadows, NO checkerboard baked into image, NO border, NO text. Simplify aggressively to read at 18–20 pixels tall, with ample negative spaces; avoid tiny lines. Center the dinosaur with only a small 5% transparent margin, no cropping of spikes, snout or hand. This is an icon asset alone, not a UI screenshot or mockup.

## Transparency refinement prompt

Use case: background-extraction. Edit this monochrome dinosaur icon. Keep its black dinosaur shapes exactly unchanged. REMOVE the entire gray-and-white checkerboard everywhere, including inside the eye, neck, nostrils and around the hand. Replace those areas with ACTUAL transparent alpha pixels. The output MUST be an RGBA PNG with a real alpha channel, not an RGB image depicting transparency. All non-dinosaur pixels alpha=0, black dinosaur alpha=255 except antialiased edges. No checkerboard, no solid backdrop, no white fill, no mockup. This is a production macOS menu bar template image.

## Local finishing

Both generated outputs contained an opaque checkerboard. With user approval, local
CoreGraphics processing extracted the black stencil: each pixel's alpha is
`clamp((160 - max(red, green, blue)) / 100, 0, 1)`, and RGB is set to black.
The final PNG stores genuine transparency, including all interior cutouts.
`scripts/generate-branding.sh` resizes this finished master; it does not rerun image generation.
