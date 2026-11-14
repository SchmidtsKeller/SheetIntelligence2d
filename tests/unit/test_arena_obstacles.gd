extends TestCase
## Every obstacle type is built on the same base: a footprint that blocks
## movement, sight and light, and the static-scenery tag (GDD §6).

const OBSTACLE_SCENES: PackedStringArray = [
	"res://entities/obstacles/tree.tscn",
	"res://entities/obstacles/bush.tscn",
	"res://entities/obstacles/barn.tscn",
	"res://entities/obstacles/hay_bale.tscn",
	"res://entities/obstacles/shed.tscn",
]
const CHARACTER_RADIUS: float = 17.0


func test_every_type_shares_the_obstacle_base() -> void:
	for path: String in OBSTACLE_SCENES:
		var obstacle: ArenaObstacle = _spawn(path, Vector2.ZERO) as ArenaObstacle
		if not assert_not_null(obstacle, "%s is an ArenaObstacle" % path):
			continue
		assert_eq(obstacle.collision_layer, PhysicsLayers.WORLD, path)
		assert_eq(obstacle.collision_mask, 0, path)
		assert_true(obstacle.is_in_group(Groups.OBSTACLES), path)
		assert_true(obstacle.is_in_group(Groups.STATIC_SCENERY), path)
		assert_not_null((obstacle.get_node(^"Art") as Sprite2D).texture, "%s has art" % path)
		assert_true(_is_convex(obstacle.get_footprint()), "%s footprint is convex" % path)
		var occluder: LightOccluder2D = obstacle.get_occluder()
		if assert_not_null(occluder, "%s occludes light" % path):
			assert_eq(occluder.occluder.polygon, obstacle.get_footprint(), path)
			assert_eq(occluder.occluder.cull_mode, OccluderPolygon2D.CULL_COUNTER_CLOCKWISE)
			assert_false(Geometry2D.is_polygon_clockwise(occluder.occluder.polygon), path)


func test_a_footprint_drawn_the_other_way_round_casts_the_same_shadow() -> void:
	var obstacle: ArenaObstacle = (load(OBSTACLE_SCENES[2]) as PackedScene).instantiate()
	var footprint: CollisionPolygon2D = obstacle.get_node(^"Footprint")
	var reversed: PackedVector2Array = footprint.polygon.duplicate()
	reversed.reverse()
	footprint.polygon = reversed
	add_child_autofree(obstacle)

	var outline: PackedVector2Array = obstacle.get_occluder().occluder.polygon
	assert_false(Geometry2D.is_polygon_clockwise(outline), "turned to the shared winding")
	assert_eq(outline.size(), reversed.size())
	for point: Vector2 in reversed:
		assert_has(outline, point)


func test_the_world_footprint_follows_the_obstacle() -> void:
	var obstacle: ArenaObstacle = _spawn(OBSTACLE_SCENES[0], Vector2(100.0, 50.0))

	assert_eq(obstacle.get_world_footprint()[0], obstacle.get_footprint()[0] + Vector2(100.0, 50.0))


func test_a_character_cannot_walk_through_any_obstacle() -> void:
	var obstacles: Array[ArenaObstacle] = []
	for index: int in OBSTACLE_SCENES.size():
		obstacles.append(_spawn(OBSTACLE_SCENES[index], Vector2(index * 600.0, 0.0)))
	var characters: Array[CharacterBody2D] = []
	for obstacle: ArenaObstacle in obstacles:
		characters.append(_character(obstacle.position + Vector2(-220.0, 7.0)))
	await get_tree().physics_frame

	for _frame: int in 60:
		for character: CharacterBody2D in characters:
			character.velocity = Vector2.RIGHT * 400.0
			character.move_and_slide()
		await get_tree().physics_frame

	for index: int in obstacles.size():
		var footprint: PackedVector2Array = obstacles[index].get_world_footprint()
		var position: Vector2 = characters[index].position
		assert_false(Geometry2D.is_point_in_polygon(position, footprint), OBSTACLE_SCENES[index])
		assert_gte(_distance_to_outline(position, footprint), CHARACTER_RADIUS - 1.0)
		assert_gt(position.x, obstacles[index].position.x - 220.0, "it did move")


func _spawn(path: String, at: Vector2) -> Node2D:
	var obstacle: Node2D = (load(path) as PackedScene).instantiate()
	obstacle.position = at
	add_child_autofree(obstacle)
	return obstacle


## A stand-in character: a circle that collides with the world.
func _character(at: Vector2) -> CharacterBody2D:
	var character: CharacterBody2D = CharacterBody2D.new()
	character.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	character.collision_layer = 0
	character.collision_mask = PhysicsLayers.WORLD
	character.position = at
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = CHARACTER_RADIUS
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	character.add_child(collision)
	add_child_autofree(character)
	return character


static func _is_convex(polygon: PackedVector2Array) -> bool:
	var turn_sign: float = 0.0
	for index: int in polygon.size():
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % polygon.size()]
		var c: Vector2 = polygon[(index + 2) % polygon.size()]
		var turn: float = (b - a).cross(c - b)
		if is_zero_approx(turn):
			continue
		if turn_sign != 0.0 and signf(turn) != turn_sign:
			return false
		turn_sign = signf(turn)
	return polygon.size() >= 3


static func _distance_to_outline(point: Vector2, polygon: PackedVector2Array) -> float:
	var nearest: float = INF
	for index: int in polygon.size():
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
			point, polygon[index], polygon[(index + 1) % polygon.size()]
		)
		nearest = minf(nearest, point.distance_to(closest))
	return nearest
