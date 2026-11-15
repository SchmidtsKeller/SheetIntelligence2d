NPC Sheep — Godot 4.7 SpriteFrames Pack
======================================================

Sheet Size: 3840 x 3456 px (384x384 per frame)
Total Frames: 86 (~50.6 MB RGBA8 VRAM)
Orientation: Sprites face +X (right), matching Godot 2D rotation = 0 rad (look_at ready).

Animations included:
  - idle: 14 frames @ 10 FPS (loop=true)
  - graze: 20 frames @ 12 FPS (loop=true)
  - walk: 18 frames @ 20 FPS (loop=true)
  - sprint: 14 frames @ 24 FPS (loop=true)
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
