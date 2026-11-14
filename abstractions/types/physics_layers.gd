@abstract
class_name PhysicsLayers
extends RefCounted
## The named 2D physics layers (`project.godot`, `layer_names/2d_physics`).
##
## Constants are bit masks ready for `collision_layer` / `collision_mask`.
## A test keeps the names here and in the project settings in sync.

## Solid world: obstacles and arena borders. Blocks movement.
const WORLD: int = 1 << 0
## The Sheepherder's body.
const SHEEPHERDER: int = 1 << 1
## Bodies of sheep-like entities: NPC sheep and the disguised Monster alike.
const SHEEP: int = 1 << 2
## Companion bodies (Shepherd Dog, Allied Bat).
const COMPANIONS: int = 1 << 3
## Hit areas for firearm rays and melee attacks.
const HITBOX: int = 1 << 4

## Layer number (1-based, as shown in the editor) → name in the project settings.
const NAMES: Dictionary[int, String] = {
	1: "world",
	2: "sheepherder",
	3: "sheep",
	4: "companions",
	5: "hitbox",
}


## The project setting that stores the name of layer [param number] (1-based).
static func setting_path(number: int) -> String:
	return "layer_names/2d_physics/layer_%d" % number
