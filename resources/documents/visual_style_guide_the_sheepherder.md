# Visual Style Guide: The Sheepherder

This document outlines the strict visual and aesthetic constraints for generating and rendering the **Sheepherder** character sprite for the game *Hide in Sheep Clothing*. It serves as a comprehensive prompt-generation and rendering checklist.

## 1. Core Aesthetic & Art Style
*   **Medium:** Traditional Atmospheric Realism Painting. The sprite must look like a physical oil or heavy acrylic painting on canvas.
*   **Canvas Texture:** A subtle physical canvas or wood panel texture should be perceivable beneath the paint.
*   **Execution:** Visible, textured brushstrokes. Use impasto (thickly applied paint) for highlights, and thin, dark washes for shadowed areas. 
*   **Proportions:** Characters and equipment must remain strictly realistic and anatomically correct.
*   **Lighting (Chiaroscuro & Tenebrism):** Extreme contrast between light and shadow. Shadows are heavy and deep (pitch-black or dark umber). Forms should melt softly into the surrounding darkness, with hard edges only existing where light sharply hits an object.
*   **Color Palette:** Muted, desaturated, and earthy. Dominated by raw umber, burnt sienna, muddy browns, olive greens, and charcoal blacks. Highlights should be pale, sickly yellows or harsh, cold whites. Avoid vibrant or pure hues. 

## 2. Camera Angle & Perspective (CRITICAL)
*   **Zenithal Top-Down:** Strict 90-degree orthographic overhead view, looking directly down at the subject.
*   **Orientation:** The character must be facing directly toward the **top edge** of the image.
*   **Visibility:** Only the top of the character's hat, shoulders, back, and the uppermost surfaces of their weapon/arms are visible.
*   **No Angles:** Zero camera tilt, zero horizon, and absolutely no side-profiles of the body or weapon.

## 3. Character Attire & Design
*   **Hat:** A wide-brimmed leather hat (outback, fedora, or slouch style). The brim obscures the head and neck entirely from the top-down perspective.
*   **Coat:** A thick, dark brown leather duster. It should look weathered, worn, and potentially mud-spattered or patched, fitting the grim survival horror tone.
*   **Silhouette:** The heavy coat and wide hat create a grounded, imposing silhouette against the ground plane.

## 4. Weaponry & Posture
*   **Weapon:** A wooden-stock, single-shot rifle with a cylindrical flashlight securely bound to the end of the barrel.
*   **Aiming Stance:** The Sheepherder is actively aiming forward (straight up towards the top edge of the canvas).
*   **Anatomical Positioning:** The stock of the rifle is placed firmly against the **right shoulder**. 
*   **Offset Framing:** Because the rifle is shouldered on the right, the weapon is **not centrally aligned** on the sprite. The barrel and flashlight visibly run parallel along the right side of the character's center axis. The left arm reaches across the body to support the rifle's barrel.

## 5. Technical Sprite Specifications
*   **Background:** Solid, flat, pure magenta (`#FF00FF`). One uniform color with zero gradient and zero texture.
*   **No Drop Shadows:** The character must not cast any shadows onto the magenta background (to allow for clean transparency masking in the game engine).
*   **Centering & Margins:** The subject is generally centered within the canvas, though the asymmetrical weapon pose will naturally shift the visual weight slightly to the right. The character must be fully visible with a small margin at the edges.
*   **No Text:** Do not render any text, hex codes, or watermarks anywhere in the image.

## 6. Positive Prompt Keywords (Mandatory Inclusions)
When prompting an AI generator, always include these specific phrases:
*   `Strict 90-degree zenithal camera angle, seen directly from above, orthographic overhead view`
*   `Facing the top edge of the image`
*   `Traditional oil painting on canvas`
*   `Realistic proportions and anatomy`
*   `Visible, textured brushstrokes`
*   `Heavy chiaroscuro, tenebrism`
*   `Grim, macabre, atmospheric survival horror`
*   `Harsh directional lighting against pitch-black shadows`
*   `Muted, earthy color palette, darkwood tones`
*   `Solid flat pure magenta background, one uniform colour with no gradient, no texture, and no shadow`
*   `Do not render any text`

## 7. Negative Constraints (Strictly Avoid)
Always include these in the negative prompt or strictly enforce them to prevent style drift:
*   NO 3/4 view, NO isometric perspective, NO angled camera, NO horizon lines, NO tilt-shift
*   NO digital smoothing, airbrushing, or pristine digital blending
*   NO 3D rendering, CGI, Octane Render, or Unreal Engine aesthetics
*   NO cell-shading, comic book outlines, or ink lines 
*   NO anime, manga, cartoon, or stylized caricatures
*   NO flat vectors or flat colors
*   NO bright, saturated, or cheerful colors
*   NO modern sci-fi or polished fantasy elements
*   NO photographic hyper-realism (it must look like a *painting*, not a photograph)
*   NO text, NO watermarks, NO hex codes printed on the background