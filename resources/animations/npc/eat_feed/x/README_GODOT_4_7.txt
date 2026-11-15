NPC Sheep — Godot 4.7 SpriteFrames Pack
======================================================

Sheet Size: 1920 x 1536 px (384x384 per frame)
Total Frames: 20 (~11.3 MB RGBA8 VRAM)
Orientation: Sprites face +X (right), matching Godot 2D rotation = 0 rad (look_at ready).

Animations included:
  - eat_feed: 20 frames @ 20 FPS (loop=false)

Setup in Godot 4.7 (Hide in Sheep Clothing — NPC Flock & Disguised Monster):
1. Copy `npc_sheep_sheet.png` and `npc_sheep_frames.tres` into `res://assets/`.
2. Add an `AnimatedSprite2D` node inside `NPCSheep (CharacterBody2D)` and `MonsterSheep`.
3. Assign `npc_sheep_frames.tres` to its `Sprite Frames` property.
4. For Strict Fog of War (visible only inside the Sheepherder flashlight cone):
   Assign a `CanvasItemMaterial` with `light_mode = LIGHT_MODE_ONLY` (`Light Only`)
   to the `AnimatedSprite2D` for dynamic flock entities.
5. Call `sprite.play("walk")` at 180 px/s, `sprite.play("graze")` when nibbling grass,
   `sprite.play("idle")` when standing, `sprite.play("sprint")` during Monster 270 px/s dash,
   and `sprite.play("eat_feed")` (1.0s non-looping) when the disguised Monster splits open like a cone from the front and lunges forward to consume prey.
