Giant Scary Monster (GSM) — Godot 4.7 SpriteFrames Pack
======================================================

Sheet Size: 3840 x 3840 px (384x384 per frame)
Total Frames: 92 (~56.3 MB RGBA8 VRAM)
Orientation: Sprites face -Y (up), matching standard top-down canvas orientation.

Animations included:
  - idle: 16 frames @ 12 FPS (loop=true)
  - stalk: 20 frames @ 14 FPS (loop=true)
  - walk: 22 frames @ 25 FPS (loop=true)
  - eat_lunge: 14 frames @ 24 FPS (loop=false)
  - eat_feed: 20 frames @ 20 FPS (loop=false)

Setup in Godot 4.7 (Hide in Sheep Clothing):
1. Copy `gsm_spider_sheet.png` and `gsm_spider_frames.tres` into `res://assets/`.
2. Add an `AnimatedSprite2D` node inside `MonsterSpider (CharacterBody2D)`.
3. Assign `gsm_spider_frames.tres` to its `Sprite Frames` property.
4. For Strict Fog of War (visible only inside the Sheepherder flashlight cone):
   Assign a `CanvasItemMaterial` with `light_mode = LIGHT_MODE_ONLY` (`Light Only`)
   to the `AnimatedSprite2D` (only on the Sheepherder local view / both clients if FoW applies).
5. Call `sprite.play("walk")` when moving at 300 px/s, `sprite.play("idle")` when still,
   `sprite.play("eat_lunge")` for quick strike scramble, and `sprite.play("eat_feed")` (1.0s non-looping) when splitting open from the front and lunging forward to consume prey.
