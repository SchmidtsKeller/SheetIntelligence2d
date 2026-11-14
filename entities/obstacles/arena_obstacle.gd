class_name ArenaObstacle
extends StaticBody2D
## A solid prop of the arena: tree, thick bush, barn, wooden structure or hay
## bale (GDD §6). Every obstacle type is a scene with this script.
##
## Its footprint, the [CollisionPolygon2D] named [code]Footprint[/code], is the
## one shape that blocks movement, sight and the flashlight's light: the light
## occluder is built from it. Obstacles stay faintly visible in darkness
## (GDD §3.1). Keep footprints convex, so nothing can get stuck in a corner.


func _ready() -> void:
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	add_to_group(Groups.OBSTACLES)
	add_to_group(Groups.STATIC_SCENERY)
	var shape: OccluderPolygon2D = OccluderPolygon2D.new()
	shape.polygon = get_footprint()
	var occluder: LightOccluder2D = LightOccluder2D.new()
	occluder.name = "Occluder"
	occluder.occluder = shape
	add_child(occluder)


## The footprint in this obstacle's own coordinates.
func get_footprint() -> PackedVector2Array:
	return (get_node(^"Footprint") as CollisionPolygon2D).polygon


## The footprint in world coordinates.
func get_world_footprint() -> PackedVector2Array:
	return (get_node(^"Footprint") as CollisionPolygon2D).global_transform * get_footprint()


## The light occluder built from the footprint.
func get_occluder() -> LightOccluder2D:
	return get_node_or_null(^"Occluder") as LightOccluder2D
