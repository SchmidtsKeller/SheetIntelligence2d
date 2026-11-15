The Shepherd — Godot 4.7 SpriteFrames Pack
======================================================

Sheet Size: 3072 x 3072 px (384x384 per frame)
Total Frames: 62 (~36.0 MB RGBA8 VRAM)
Orientation: Sprites face -Y (up), matching standard top-down canvas orientation.

Animations included:
  - idle: 14 frames @ 10 FPS (loop=true)
  - walk: 18 frames @ 20 FPS (loop=true)
  - run: 14 frames @ 24 FPS (loop=true)
  - fire: 16 frames @ 22 FPS (loop=false)

Setup in Godot 4.7 (Hide in Sheep Clothing — The Sheepherder):
1. Copy `shepherd_sheet.png` and `shepherd_frames.tres` into `res://assets/`.
2. Add an `AnimatedSprite2D` node inside `Sheepherder (CharacterBody2D)`.
3. Assign `shepherd_frames.tres` to its `Sprite Frames` property.
4. Attach a `PointLight2D` flashlight cone (60° normal, 90° with Wide Flashlight perk)
   anchored at the rifle barrel bezel so it sweeps with `look_at(get_global_mouse_position())`.
5. Call `sprite.play("walk")` at 180 px/s, `sprite.play("run")` when running,
   `sprite.play("idle")` when stationary, and `sprite.play("fire")` (non-looping) on rifle discharge.
