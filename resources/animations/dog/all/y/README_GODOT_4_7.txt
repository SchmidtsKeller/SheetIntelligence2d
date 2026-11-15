Friendly Shepherd Dog (Companion) — Godot 4.7 SpriteFrames Pack
======================================================

Sheet Size: 3072 x 3072 px (384x384 per frame)
Total Frames: 60 (~36.0 MB RGBA8 VRAM)
Orientation: Sprites face -Y (up), matching standard top-down canvas orientation.

Animations included:
  - idle: 14 frames @ 10 FPS (loop=true)
  - walk: 18 frames @ 22 FPS (loop=true)
  - run: 14 frames @ 26 FPS (loop=true)
  - bark: 14 frames @ 22 FPS (loop=false)

Setup in Godot 4.7 (Hide in Sheep Clothing — Friendly Shepherd Dog Companion):
1. Copy `shepherd_dog_sheet.png` and `shepherd_dog_frames.tres` into `res://assets/`.
2. Add an `AnimatedSprite2D` node inside `FriendlyShepherdDog (Node2D / CharacterBody2D)`.
3. Assign `shepherd_dog_frames.tres` to its `Sprite Frames` property (collision disabled so it passes through sheep & Sheepherder).
4. Call `sprite.play("walk")` when pacing beside the Sheepherder, `sprite.play("run")` when catching up,
   `sprite.play("idle")` when waiting, and `sprite.play("bark")` (facing the eating Monster within 800 px hearing range).
