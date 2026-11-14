extends TestCase
## The arena: size, borders, obstacle layout, sampling and spawns (GDD §6).

const ARENA_SCENE: String = "res://systems/arena/arena.tscn"
## The narrowest gap between two obstacles, or an obstacle and a border, so
## nothing gets stuck: wider than a sheep (34 px) plus room to turn.
const MIN_PASSAGE: float = 96.0
const CHARACTER_RADIUS: float = 17.0

var _arena: Arena


func before_each() -> void:
	_arena = add_child_autofree((load(ARENA_SCENE) as PackedScene).instantiate())
	await get_tree().physics_frame


# --- Size and borders ------------------------------------------------------------


func test_the_arena_has_the_configured_size() -> void:
	var config: GameConfig = Services.config

	assert_eq(_arena.get_bounds(), Rect2(0.0, 0.0, config.arena_width, config.arena_height))
	assert_true(_arena.get_bounds().encloses(_arena.get_play_area()))
	assert_eq(_arena.get_play_area(), Rect2(40.0, 40.0, 3120.0, 2160.0))


func test_fences_and_the_river_enclose_the_play_area() -> void:
	var expected: Dictionary[String, Rect2] = {
		"FenceTop": Rect2(0.0, 0.0, 3200.0, 40.0),
		"FenceLeft": Rect2(0.0, 0.0, 40.0, 2200.0),
		"FenceRight": Rect2(3160.0, 0.0, 40.0, 2200.0),
		"River": Rect2(0.0, 2200.0, 3200.0, 200.0),
	}
	for border_name: String in expected:
		var border: StaticBody2D = _arena.get_node("Borders/%s" % border_name)
		var shape: RectangleShape2D = (border.get_child(0) as CollisionShape2D).shape
		var covered: Rect2 = Rect2(border.global_position - shape.size / 2.0, shape.size)
		assert_eq(covered, expected[border_name], border_name)
		assert_eq(border.collision_layer, PhysicsLayers.WORLD, border_name)
		assert_true(border.is_in_group(Groups.STATIC_SCENERY), border_name)
		assert_false(border.is_in_group(Groups.OBSTACLES), "%s is no obstacle" % border_name)


func test_a_character_cannot_leave_the_arena() -> void:
	var play_area: Rect2 = _arena.get_play_area()
	var random: SeededRandom = SeededRandom.new(3)
	var outward: Dictionary[Vector2, Rect2] = {
		Vector2.UP: Rect2(play_area.position, Vector2(play_area.size.x, 200.0)),
		Vector2.DOWN: Rect2(play_area.position.x, play_area.end.y - 200.0, play_area.size.x, 200.0),
		Vector2.LEFT: Rect2(play_area.position, Vector2(200.0, play_area.size.y)),
		Vector2.RIGHT:
		Rect2(play_area.end.x - 200.0, play_area.position.y, 200.0, play_area.size.y),
	}
	var characters: Dictionary[Vector2, CharacterBody2D] = {}
	for direction: Vector2 in outward:
		var start: Vector2 = _arena.sample_free_position(random, 40.0, outward[direction])
		characters[direction] = _character(start)
	await get_tree().physics_frame

	for _frame: int in 60:
		for direction: Vector2 in characters:
			characters[direction].velocity = direction * 600.0
			characters[direction].move_and_slide()
		await get_tree().physics_frame

	for direction: Vector2 in characters:
		var position: Vector2 = characters[direction].position
		var inner: Rect2 = play_area.grow(-(CHARACTER_RADIUS - 1.0))
		assert_true(inner.has_point(position), "pushed %s, stopped at %s" % [direction, position])


func test_the_camera_cannot_look_beyond_the_arena() -> void:
	var camera: Camera2D = autofree(Camera2D.new())

	_arena.apply_camera_limits(camera)

	assert_eq(
		Rect2i(
			camera.limit_left,
			camera.limit_top,
			camera.limit_right - camera.limit_left,
			camera.limit_bottom - camera.limit_top
		),
		Rect2i(_arena.get_bounds())
	)


# --- Obstacle layout -------------------------------------------------------------


func test_there_are_obstacles_of_every_kind() -> void:
	var kinds: Dictionary[String, int] = {}
	for obstacle: ArenaObstacle in _arena.get_obstacles():
		kinds[obstacle.scene_file_path.get_file()] = (
			kinds.get(obstacle.scene_file_path.get_file(), 0) + 1
		)

	for kind: String in ["tree.tscn", "bush.tscn", "barn.tscn", "hay_bale.tscn", "shed.tscn"]:
		assert_gt(kinds.get(kind, 0), 0, kind)
	assert_eq(_arena.get_obstacle_footprints().size(), _arena.get_obstacles().size())


func test_obstacles_leave_passages_everywhere() -> void:
	var play_area: Rect2 = _arena.get_play_area()
	var footprints: Array[PackedVector2Array] = _arena.get_obstacle_footprints()

	for i: int in footprints.size():
		var edges: float = INF
		for point: Vector2 in footprints[i]:
			edges = minf(edges, _distance_to_rect_edges(point, play_area))
			assert_true(play_area.has_point(point), "obstacle %d lies inside the play area" % i)
		assert_gte(edges, MIN_PASSAGE, "gap between obstacle %d and the border" % i)
		for j: int in range(i + 1, footprints.size()):
			assert_gte(
				_polygon_gap(footprints[i], footprints[j]),
				MIN_PASSAGE,
				"gap between obstacles %d and %d" % [i, j]
			)


func test_spawn_areas_are_open_ground() -> void:
	var play_area: Rect2 = _arena.get_play_area()

	for area: Rect2 in [_arena.get_sheepherder_spawn_area(), _arena.get_flock_spawn_area()]:
		assert_true(play_area.encloses(area), "%s lies inside the play area" % area)
		var corners: PackedVector2Array = [
			area.position,
			Vector2(area.end.x, area.position.y),
			area.end,
			Vector2(area.position.x, area.end.y)
		]
		for footprint: PackedVector2Array in _arena.get_obstacle_footprints():
			assert_true(
				Geometry2D.intersect_polygons(corners, footprint).is_empty(),
				"no obstacle in %s" % area
			)


# --- Sampling and spawns ---------------------------------------------------------


func test_sampled_positions_are_never_blocked() -> void:
	var random: SeededRandom = SeededRandom.new(11)
	var bounds: Rect2 = _arena.get_bounds()
	var footprints: Array[PackedVector2Array] = _arena.get_obstacle_footprints()

	for _i: int in 10000:
		var point: Vector2 = _arena.sample_free_position(random, 20.0, bounds)
		if not _arena.get_play_area().has_point(point):
			fail_test("%s lies outside the play area" % point)
			return
		for footprint: PackedVector2Array in footprints:
			if Geometry2D.is_point_in_polygon(point, footprint):
				fail_test("%s lies inside an obstacle" % point)
				return
	pass_test()


func test_sampling_keeps_away_from_given_points() -> void:
	var random: SeededRandom = SeededRandom.new(5)
	var area: Rect2 = _arena.get_flock_spawn_area()
	var taken: Array[Vector2] = []

	for _i: int in 20:
		taken.append(_arena.sample_free_position(random, 20.0, area, taken, 50.0))

	for i: int in taken.size():
		assert_true(area.has_point(taken[i]))
		for j: int in range(i + 1, taken.size()):
			assert_gte(taken[i].distance_to(taken[j]), 50.0)


func test_sampling_is_deterministic() -> void:
	var first: Vector2 = _arena.sample_free_position(SeededRandom.new(9), 20.0, _arena.get_bounds())
	var second: Vector2 = _arena.sample_free_position(
		SeededRandom.new(9), 20.0, _arena.get_bounds()
	)

	assert_eq(first, second)


func test_a_round_spawns_everybody_in_their_areas() -> void:
	var count: int = Services.config.flock_size + 1

	var layout: ArenaSpawnLayout = _arena.get_spawn_layout(2024, count)

	assert_true(_arena.get_sheepherder_spawn_area().has_point(layout.sheepherder_position))
	assert_true(_arena.is_free(layout.sheepherder_position, _arena.spawn_clearance))
	assert_eq(layout.sheep_positions.size(), count)
	for i: int in count:
		var position: Vector2 = layout.sheep_positions[i]
		assert_true(_arena.get_flock_spawn_area().has_point(position), "sheep %d" % i)
		assert_true(_arena.is_free(position, _arena.spawn_clearance), "sheep %d" % i)
		for j: int in range(i + 1, count):
			assert_gte(position.distance_to(layout.sheep_positions[j]), _arena.sheep_spawn_spacing)


func test_the_same_round_seed_gives_the_same_spawns() -> void:
	var first: ArenaSpawnLayout = _arena.get_spawn_layout(77, 11)
	var second: ArenaSpawnLayout = _arena.get_spawn_layout(77, 11)
	var other: ArenaSpawnLayout = _arena.get_spawn_layout(78, 11)

	assert_eq(first.sheepherder_position, second.sheepherder_position)
	assert_eq(first.sheep_positions, second.sheep_positions)
	assert_ne(first.sheep_positions, other.sheep_positions)


# --- Layers and debug ------------------------------------------------------------


func test_layers_are_in_drawing_order() -> void:
	var names: PackedStringArray = []
	for child: Node in _arena.get_children():
		names.append(child.name)

	var order: PackedStringArray = [
		"Ground", "GroundDetails", "Decals", "Borders", "Entities", "Obstacles", "Overlays"
	]
	var last: int = -1
	for layer: String in order:
		assert_gt(names.find(layer), last, "%s comes after the layers below it" % layer)
		last = names.find(layer)
	assert_true(_arena.get_entities_layer().y_sort_enabled)
	assert_eq(_arena.get_decals_layer().name, &"Decals")
	assert_eq(_arena.get_overlays_layer().name, &"Overlays")


func test_ground_details_are_static_scenery() -> void:
	var details: Array[Node] = _arena.get_node(^"GroundDetails").get_children()

	var expected: int = 0
	for count: int in _arena.ground_details.values():
		expected += count
	assert_eq(details.size(), expected)
	for detail: Node in details:
		assert_true(detail.is_in_group(Groups.STATIC_SCENERY))


func test_the_debug_overlay_can_be_toggled() -> void:
	var overlay: CanvasItem = _arena.get_node(^"DebugOverlay")

	assert_false(_arena.debug_overlay_visible)
	_arena.debug_overlay_visible = true
	assert_true(overlay.visible)
	_arena.debug_overlay_visible = false
	assert_false(overlay.visible)


# --- Helpers ---------------------------------------------------------------------


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


static func _distance_to_rect_edges(point: Vector2, rect: Rect2) -> float:
	return minf(
		minf(point.x - rect.position.x, rect.end.x - point.x),
		minf(point.y - rect.position.y, rect.end.y - point.y)
	)


## The gap between two convex polygons that do not overlap.
static func _polygon_gap(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if not Geometry2D.intersect_polygons(a, b).is_empty():
		return 0.0
	return minf(_vertex_gap(a, b), _vertex_gap(b, a))


static func _vertex_gap(points: PackedVector2Array, polygon: PackedVector2Array) -> float:
	var nearest: float = INF
	for point: Vector2 in points:
		for index: int in polygon.size():
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
				point, polygon[index], polygon[(index + 1) % polygon.size()]
			)
			nearest = minf(nearest, point.distance_to(closest))
	return nearest
