The Shepherd — Godot 4.7 SpriteFrames Pack
======================================================

Sheet Size: 1920 x 1536 px (384x384 per frame)
Total Frames: 18 (~11.3 MB RGBA8 VRAM)
Orientation: Sprites face +X (right), matching Godot 2D rotation = 0 rad (look_at ready).

Animations included:
  - walk: 18 frames @ 20 FPS (loop=true)

Setup in Godot 4.7 (Hide in Sheep Clothing — The Sheepherder):
1. Copy `shepherd_sheet.png` and `shepherd_frames.tres` into `res://assets/`.
2. Add an `AnimatedSprite2D` node inside `Sheepherder (CharacterBody2D)`.
3. Assign `shepherd_frames.tres` to its `Sprite Frames` property.
4. Attach a `PointLight2D` flashlight cone (60° normal, 90° with Wide Flashlight perk)
   anchored at the rifle barrel bezel so it sweeps with `look_at(get_global_mouse_position())`.
5. Call `sprite.play("walk")` at 180 px/s, `sprite.play("run")` when running,
   `sprite.play("idle")` when stationary, and `sprite.play("fire")` (non-looping) on rifle discharge.
