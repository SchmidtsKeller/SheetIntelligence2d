NPC Sheep — Godot 4.7 SpriteFrames Pack
======================================================

Sheet Size: 1536 x 1536 px (384x384 per frame)
Total Frames: 14 (~9.0 MB RGBA8 VRAM)
Orientation: Sprites face -Y (up), matching standard top-down canvas orientation.

Animations included:
  - idle: 14 frames @ 10 FPS (loop=true)

Setup in Godot 4.7 (Hide in Sheep Clothing — NPC Flock & Disguised Monster):
1. Copy `npc_sheep_sheet.png` and `npc_sheep_frames.tres` into `res://assets/`.
2. Add an `AnimatedSprite2D` node inside `NPCSheep (CharacterBody2D)` and `MonsterSheep`.
3. Assign `npc_sheep_frames.tres` to its `Sprite Frames` property.
4. For Strict Fog of War (visible only inside the Sheepherder flashlight cone):
   Assign a `CanvasItemMaterial` with `light_mode = LIGHT_MODE_ONLY` (`Light Only`)
   to the `AnimatedSprite2D` for dynamic flock entities.
5. Call `sprite.play("walk")` at 180 px/s, `sprite.play("graze")` when nibbling grass,
   `sprite.play("idle")` when standing, and `sprite.play("sprint")` during Monster 270 px/s dash.
