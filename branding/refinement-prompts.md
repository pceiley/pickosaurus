# Icon refinement record

15 September 2026. Built-in image generation was used for two raster edit attempts.
Neither candidate shipped: the first introduced a checkerboard; the second removed
that background but retained fringe pixels. The final master is manually authored
SVG geometry in [Dinosaur.svg](../Pickosaurus/AppIcon.icon/Assets/Dinosaur.svg),
based on the supplied design and inspected through native Icon Composer renders.

## First edit prompt

Use case: background-extraction. Edit this existing Pickosaurus dinosaur icon foreground, preserving its exact character, composition, pose, big eye, smile, finger touching nostril, teal spines, green palette, cream belly and three cream accent marks. Production cleanup only: remove ALL white/yellow/neon green fringe, stray pixels and rough edges outside the intended silhouette, including around the accent marks and bottom. Produce smooth crisp antialiased alpha edges with fully transparent surroundings, not a checkerboard or solid background. Keep the existing broad shapes and shading; slightly clarify the eye, smile and finger separation for readability when reduced to 32px. Do not redesign, add outlines, shadows, text, background, border, or extra objects. Same square composition with a little clear padding; smooth intentional bottom contour. Output a high-resolution transparent PNG, ideally 2048x2048.

## Transparency correction prompt

Remove the entire gray checkerboard background from this image. Output the dinosaur and three cream accent marks ONLY on an actually transparent PNG alpha channel. All gray squares and background pattern must be removed, including the gap between neck and hand. Preserve the dinosaur exactly unchanged, including clean contours, color and dimensions. No simulated transparency, no checkerboard, no solid background. Transparent background.
