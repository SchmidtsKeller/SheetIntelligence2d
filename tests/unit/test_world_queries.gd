extends TestCase
## Line of sight and raycasts: obstacles and borders block, sheep do not.

## An obstacle covering x 150..250, y -50..50.
var _obstacle: StaticBody2D
## A border covering x 600..640, y -500..500.
var _border: StaticBody2D


func before_each() -> void:
	_obstacle = _body(Rect2(150.0, -50.0, 100.0, 100.0), PhysicsLayers.WORLD)
	_obstacle.add_to_group(Groups.OBSTACLES)
	_border = _body(Rect2(600.0, -500.0, 40.0, 1000.0), PhysicsLayers.WORLD)
	_body(Rect2(350.0, -50.0, 50.0, 100.0), PhysicsLayers.SHEEP)
	await get_tree().physics_frame


func test_nothing_in_between_means_sight() -> void:
	assert_true(
		WorldQueries.has_line_of_sight(_world(), Vector2(0.0, 100.0), Vector2(500.0, 100.0))
	)


func test_an_obstacle_blocks_sight() -> void:
	assert_false(WorldQueries.has_line_of_sight(_world(), Vector2.ZERO, Vector2(500.0, 0.0)))
	assert_false(WorldQueries.has_line_of_sight(_world(), Vector2(500.0, 0.0), Vector2.ZERO))


func test_a_line_grazing_an_edge() -> void:
	var world: World2D = _world()

	assert_true(
		WorldQueries.has_line_of_sight(world, Vector2(0.0, 51.0), Vector2(500.0, 51.0)),
		"1 px outside the edge"
	)
	assert_false(
		WorldQueries.has_line_of_sight(world, Vector2(0.0, 49.0), Vector2(500.0, 49.0)),
		"1 px inside the edge"
	)


func test_sheep_do_not_block_sight() -> void:
	assert_true(WorldQueries.has_line_of_sight(_world(), Vector2(300.0, 0.0), Vector2(500.0, 0.0)))


func test_a_ray_reports_the_first_hit() -> void:
	var hit: WorldHit = WorldQueries.raycast(_world(), Vector2.ZERO, Vector2.RIGHT, 1000.0)

	if not assert_not_null(hit):
		return
	assert_almost_eq(hit.position, Vector2(150.0, 0.0), 0.5)
	assert_almost_eq(hit.normal, Vector2.LEFT, 0.001)
	assert_eq(hit.collider, _obstacle)
	assert_true(hit.is_obstacle())


func test_a_ray_stops_at_its_maximum_distance() -> void:
	assert_null(WorldQueries.raycast(_world(), Vector2.ZERO, Vector2.RIGHT, 100.0))


func test_a_border_is_not_an_obstacle() -> void:
	var hit: WorldHit = WorldQueries.raycast(_world(), Vector2(300.0, 100.0), Vector2.RIGHT, 1000.0)

	if assert_not_null(hit):
		assert_eq(hit.collider, _border)
		assert_false(hit.is_obstacle(), "a bullet that reaches a border has left the map")


func _world() -> World2D:
	return get_viewport().world_2d


func _body(rect: Rect2, layer: int) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child_autofree(body)
	return body
