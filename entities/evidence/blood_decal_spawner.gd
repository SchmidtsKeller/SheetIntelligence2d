class_name BloodDecalSpawner
extends Node
## Leaves blood on the ground wherever the combat service reports some
## (GDD §3.1, §3.2). It stays for the rest of the round. The Sheepherder sees
## it only in the light; the Monster sees all of the ground.

const DECAL_SCENE: PackedScene = preload("res://entities/evidence/blood_decal.tscn")

## Where the decals go, e.g. [method Arena.get_decals_layer].
var decals: Node2D


func _ready() -> void:
	Services.combat.blood_spilled.connect(spill)


func _exit_tree() -> void:
	if Services.combat.blood_spilled.is_connected(spill):
		Services.combat.blood_spilled.disconnect(spill)


## Puts a blood decal at [param at]. Its rotation follows from the position, so
## both devices show the same mark.
func spill(at: Vector2) -> void:
	if decals == null:
		push_error("BloodDecalSpawner: no parent for the decals is set.")
		return
	var decal: Node2D = DECAL_SCENE.instantiate()
	decal.position = at
	var random: SeededRandom = SeededRandom.new(roundi(at.x) * 7919 + roundi(at.y))
	decal.rotation = deg_to_rad(random.next_int(360))
	decals.add_child(decal)
