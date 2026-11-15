class_name Arena
extends Node2D
## The playing field (GDD §6): ground, borders, obstacles, spawn areas and the
## layers everything else is placed in. The arena sits at the world origin.
##
## Its size comes from the config (borders included). The borders, wooden
## fences on three sides and a river along the bottom, are built from it, so
## they always match. Obstacles are placed by hand in the scene.
##
## Torches stand at fixed spots placed in the scene. A living Sheepherder who
## walks up to an unlit torch lights it: the host decides and announces it with
## [constant EVENT_TORCH_LIT], and both devices light it (#63).
##
## Layers, bottom to top: ground, ground details, decals, borders, entities,
## obstacles, torches, overlays.

## Candidates [method sample_free_position] tries before it gives up.
const MAX_SAMPLE_ATTEMPTS: int = 10000
## Mixed into the round seed, so spawn positions do not repeat the numbers the
## same seed gives elsewhere (e.g. the sheep's looks).
const SPAWN_SEED_SALT: int = 0x5A17_0B5E
## The host lit a torch: [code][torch index][/code].
const EVENT_TORCH_LIT: StringName = &"arena.torch_lit"

@export_group("Borders")
## Width of the fences along the top, left and right edge.
@export var fence_thickness: float = 40.0
## Width of the river along the bottom edge.
@export var river_width: float = 200.0
@export var fence_texture: Texture2D
@export var river_texture: Texture2D

@export_group("Ground")
@export var ground_texture: Texture2D
## Scattered ground details (hills, grass patches, flowers) and how many of
## each. Drawn in this order.
@export var ground_details: Dictionary[Texture2D, int] = {}
## Seed of the scattering, the same on every device.
@export var scenery_seed: int = 1

@export_group("Spawning")
## How far spawned characters stay from obstacles and borders.
@export var spawn_clearance: float = 32.0
## Least distance between the centers of two spawned sheep.
@export var sheep_spawn_spacing: float = 64.0

## Shows the debug overlay: footprints, occluders, borders and spawn areas.
var debug_overlay_visible: bool:
	get:
		return _debug_overlay.visible
	set(value):
		_debug_overlay.visible = value

## The session that carries the torch events. Defaults to
## [code]Services.session[/code].
var session: GameSession:
	get:
		if session == null:
			session = Services.session
		return session

var _footprints: Array[PackedVector2Array] = []
# A circle around each footprint, to skip far obstacles quickly.
var _footprint_centers: PackedVector2Array = []
var _footprint_radii: PackedFloat32Array = []

@onready var _ground: Node2D = $Ground
@onready var _ground_details: Node2D = $GroundDetails
@onready var _decals: Node2D = $Decals
@onready var _borders: Node2D = $Borders
@onready var _entities: Node2D = $Entities
@onready var _obstacles: Node2D = $Obstacles
@onready var _torches: Node2D = $Torches
@onready var _overlays: Node2D = $Overlays
@onready var _sheepherder_spawn: SpawnArea = $SpawnAreas/Sheepherder
@onready var _flock_spawn: SpawnArea = $SpawnAreas/Flock
@onready var _debug_overlay: ArenaDebugOverlay = $DebugOverlay


func _ready() -> void:
	add_to_group(Groups.ARENA)
	_build_ground()
	_scatter_ground_details()
	_build_borders()
	for obstacle: ArenaObstacle in get_obstacles():
		var footprint: PackedVector2Array = obstacle.get_world_footprint()
		var center: Vector2 = _centroid(footprint)
		var radius: float = 0.0
		for point: Vector2 in footprint:
			radius = maxf(radius, center.distance_to(point))
		_footprints.append(footprint)
		_footprint_centers.append(center)
		_footprint_radii.append(radius)
	_debug_overlay.arena = self
	_debug_overlay.visible = false
	var messenger: NetMessenger = session.messenger
	messenger.register_event(EVENT_TORCH_LIT, NetMessenger.SenderRule.HOST_ONLY)
	messenger.subscribe(EVENT_TORCH_LIT, _on_torch_lit)


func _exit_tree() -> void:
	session.messenger.unsubscribe(EVENT_TORCH_LIT, _on_torch_lit)


func _physics_process(_delta: float) -> void:
	if session.messenger.is_host():
		_light_torches_near_sheepherders()


# --- Geometry --------------------------------------------------------------------


## The whole arena, borders included.
func get_bounds() -> Rect2:
	var size: Vector2 = Vector2(
		Services.perks.get_stat(StatIds.ARENA_WIDTH), Services.perks.get_stat(StatIds.ARENA_HEIGHT)
	)
	return Rect2(global_position, size)


## Where characters can be: the arena without its borders.
func get_play_area() -> Rect2:
	var bounds: Rect2 = get_bounds()
	return Rect2(
		bounds.position + Vector2(fence_thickness, fence_thickness),
		bounds.size - Vector2(2.0 * fence_thickness, fence_thickness + river_width)
	)


## Every obstacle of the arena.
func get_obstacles() -> Array[ArenaObstacle]:
	var obstacles: Array[ArenaObstacle] = []
	for child: Node in _obstacles.get_children():
		if child is ArenaObstacle:
			obstacles.append(child)
	return obstacles


## The footprints of all obstacles in world coordinates, e.g. for steering AI
## around them. Together with [method get_play_area] this is all that blocks
## movement.
func get_obstacle_footprints() -> Array[PackedVector2Array]:
	return _footprints.duplicate()


## Whether a character with [param clearance] around its center fits at
## [param point]: inside the play area and at least that far from every obstacle.
func is_free(point: Vector2, clearance: float) -> bool:
	if not get_play_area().grow(-clearance).has_point(point):
		return false
	for index: int in _footprints.size():
		if point.distance_to(_footprint_centers[index]) >= _footprint_radii[index] + clearance:
			continue
		var footprint: PackedVector2Array = _footprints[index]
		if Geometry2D.is_point_in_polygon(point, footprint):
			return false
		if _distance_to_outline(point, footprint) < clearance:
			return false
	return true


## A free position (see [method is_free]) inside [param area], at least
## [param min_distance] away from every point in [param keep_away]. The same
## [param random] state gives the same position. Fails loudly and returns the
## center of [param area] if there is none.
func sample_free_position(
	random: SeededRandom,
	clearance: float,
	area: Rect2,
	keep_away: Array[Vector2] = [],
	min_distance: float = 0.0
) -> Vector2:
	var region: Rect2 = area.intersection(get_play_area().grow(-clearance))
	if region.has_area():
		for _attempt: int in MAX_SAMPLE_ATTEMPTS:
			var candidate: Vector2 = Vector2(
				random.next_int_range(ceili(region.position.x), floori(region.end.x)),
				random.next_int_range(ceili(region.position.y), floori(region.end.y))
			)
			if is_free(candidate, clearance) and _keeps_away(candidate, keep_away, min_distance):
				return candidate
	push_error("Arena: no free position in %s." % area)
	return area.get_center()


## Where everybody starts the round of [param round_seed]: the Sheepherder in
## its spawn area, [param sheep_count] sheep-like entities spread over the
## flock's spawn area. The same seed gives the same layout.
func get_spawn_layout(round_seed: int, sheep_count: int) -> ArenaSpawnLayout:
	var random: SeededRandom = SeededRandom.new(round_seed ^ SPAWN_SEED_SALT)
	var layout: ArenaSpawnLayout = ArenaSpawnLayout.new()
	layout.sheepherder_position = sample_free_position(
		random, spawn_clearance, _sheepherder_spawn.get_area()
	)
	for _i: int in sheep_count:
		layout.sheep_positions.append(
			sample_free_position(
				random,
				spawn_clearance,
				_flock_spawn.get_area(),
				layout.sheep_positions,
				sheep_spawn_spacing
			)
		)
	return layout


## Keeps [param camera] from showing anything beyond the arena.
func apply_camera_limits(camera: Camera2D) -> void:
	var bounds: Rect2 = get_bounds()
	camera.limit_left = floori(bounds.position.x)
	camera.limit_top = floori(bounds.position.y)
	camera.limit_right = ceili(bounds.end.x)
	camera.limit_bottom = ceili(bounds.end.y)


# --- Layers ----------------------------------------------------------------------


## Where characters, sheep and companions go.
func get_entities_layer() -> Node2D:
	return _entities


## Where marks on the ground go, e.g. blood.
func get_decals_layer() -> Node2D:
	return _decals


## Where effects above everything go, e.g. the darkness.
func get_overlays_layer() -> Node2D:
	return _overlays


## The spawn area of the Sheepherder.
func get_sheepherder_spawn_area() -> Rect2:
	return _sheepherder_spawn.get_area()


## The spawn area of the flock and the Monster.
func get_flock_spawn_area() -> Rect2:
	return _flock_spawn.get_area()


# --- Torches --------------------------------------------------------------------


## The arena's torches, in a fixed order that both devices share.
func get_torches() -> Array[Torch]:
	var torches: Array[Torch] = []
	for child: Node in _torches.get_children():
		if child is Torch:
			torches.append(child)
	return torches


## Host: announces every unlit torch that a living Sheepherder stands next to.
func _light_torches_near_sheepherders() -> void:
	var ignite_range: float = Services.perks.get_stat(StatIds.TORCH_IGNITE_RANGE)
	var torches: Array[Torch] = get_torches()
	for node: Node in get_tree().get_nodes_in_group(Groups.SHEEPHERDER):
		var herder: Sheepherder = node as Sheepherder
		if herder == null or not herder.is_alive() or not herder.is_inside_tree():
			continue
		for index: int in torches.size():
			var torch: Torch = torches[index]
			if torch.is_lit():
				continue
			if torch.global_position.distance_to(herder.global_position) <= ignite_range:
				session.messenger.broadcast(EVENT_TORCH_LIT, [index])


## Both devices: the host lit a torch.
func _on_torch_lit(payload: Array, _sender_id: int) -> void:
	var torches: Array[Torch] = get_torches()
	var index: int = payload[0]
	if index >= 0 and index < torches.size():
		torches[index].light()


# --- Building --------------------------------------------------------------------


func _build_ground() -> void:
	var bounds: Rect2 = get_bounds()
	var ground: Sprite2D = _tiled_sprite("Grass", ground_texture, bounds.size)
	ground.position = bounds.size / 2.0
	ground.add_to_group(Groups.STATIC_SCENERY)
	_ground.add_child(ground)


func _scatter_ground_details() -> void:
	var random: SeededRandom = SeededRandom.new(scenery_seed)
	var area: Rect2 = Rect2(Vector2.ZERO, get_bounds().size)
	for texture: Texture2D in ground_details:
		for _i: int in ground_details[texture]:
			var detail: Sprite2D = Sprite2D.new()
			detail.texture = texture
			detail.position = Vector2(
				random.next_int_range(0, floori(area.size.x)),
				random.next_int_range(0, floori(area.size.y))
			)
			detail.rotation = deg_to_rad(random.next_int(360))
			detail.add_to_group(Groups.STATIC_SCENERY)
			_ground_details.add_child(detail)


func _build_borders() -> void:
	var size: Vector2 = get_bounds().size
	var fenced_height: float = size.y - river_width
	_add_border("FenceTop", Rect2(0.0, 0.0, size.x, fence_thickness), fence_texture, false)
	_add_border("FenceLeft", Rect2(0.0, 0.0, fence_thickness, fenced_height), fence_texture, true)
	_add_border(
		"FenceRight",
		Rect2(size.x - fence_thickness, 0.0, fence_thickness, fenced_height),
		fence_texture,
		true
	)
	_add_border("River", Rect2(0.0, fenced_height, size.x, river_width), river_texture, false)


## A solid strip covering [param rect]. Borders are not obstacles: a bullet
## that reaches one has left the map.
func _add_border(border_name: String, rect: Rect2, texture: Texture2D, upright: bool) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = border_name
	body.position = rect.get_center()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.add_to_group(Groups.STATIC_SCENERY)
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	# Tiles run along the strip; upright strips use the texture turned by 90°.
	var length: Vector2 = Vector2(rect.size.y, rect.size.x) if upright else rect.size
	var art: Sprite2D = _tiled_sprite("Art", texture, length)
	art.rotation = PI / 2.0 if upright else 0.0
	body.add_child(art)
	_borders.add_child(body)


func _tiled_sprite(sprite_name: String, texture: Texture2D, size: Vector2) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, size)
	return sprite


static func _distance_to_outline(point: Vector2, polygon: PackedVector2Array) -> float:
	var nearest: float = INF
	for index: int in polygon.size():
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % polygon.size()]
		nearest = minf(
			nearest, point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b))
		)
	return nearest


static func _centroid(polygon: PackedVector2Array) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for point: Vector2 in polygon:
		sum += point
	return sum / maxf(polygon.size(), 1.0)


static func _keeps_away(point: Vector2, others: Array[Vector2], min_distance: float) -> bool:
	for other: Vector2 in others:
		if point.distance_to(other) < min_distance:
			return false
	return true
