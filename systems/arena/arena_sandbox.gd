extends Node2D
## Arena sandbox: the whole arena with a round's spawn layout, sheep that
## wander into obstacles and borders, and the debug overlay. Run this scene on
## its own (F6).

const ARENA_SCENE: PackedScene = preload("res://systems/arena/arena.tscn")
const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")
const CATALOG: SheepAppearanceCatalog = preload(
	"res://entities/sheep/appearance/sheep_appearance_catalog.tres"
)
## How often wandering sheep pick a new direction, in seconds.
const WANDER_INTERVAL: float = 1.5

var _arena: Arena
var _camera: Camera2D
var _round_seed: int = 1
var _sheep: Array[SheepBody] = []
var _sheepherder: Polygon2D
var _wandering: bool = false
var _wander_time: float = 0.0
var _wander_random: SeededRandom = SeededRandom.new(7)
var _status: Label


func _ready() -> void:
	_arena = ARENA_SCENE.instantiate()
	add_child(_arena)
	_camera = Camera2D.new()
	add_child(_camera)
	_arena.apply_camera_limits(_camera)
	_build_controls()
	get_viewport().size_changed.connect(_show_whole_arena)
	_show_whole_arena()
	_spawn_round()


func _physics_process(delta: float) -> void:
	if not _wandering:
		return
	_wander_time -= delta
	if _wander_time > 0.0:
		return
	_wander_time = WANDER_INTERVAL
	for sheep: SheepBody in _sheep:
		sheep.set_move_input(Vector2.from_angle(deg_to_rad(_wander_random.next_int(360))))


## The arena shown.
func get_arena() -> Arena:
	return _arena


## The sheep of the current round.
func get_sheep() -> Array[SheepBody]:
	return _sheep


func _spawn_round() -> void:
	for sheep: SheepBody in _sheep:
		sheep.queue_free()
	_sheep.clear()
	if _sheepherder != null:
		_sheepherder.queue_free()
	var count: int = Services.perks.get_stat_int(StatIds.FLOCK_SIZE) + 1
	var layout: ArenaSpawnLayout = _arena.get_spawn_layout(_round_seed, count)
	var seeds: PackedInt64Array = SheepAppearanceGenerator.generate_round_seeds(
		_round_seed, count, CATALOG
	)
	for index: int in count:
		var sheep: SheepBody = SHEEP_SCENE.instantiate()
		sheep.set_visual_seed(seeds[index])
		sheep.position = layout.sheep_positions[index]
		_arena.get_entities_layer().add_child(sheep)
		_sheep.append(sheep)
	_sheepherder = _make_sheepherder_marker()
	_sheepherder.position = layout.sheepherder_position
	_arena.get_entities_layer().add_child(_sheepherder)
	_status.text = "Round seed %d" % _round_seed


## Stand-in for the Sheepherder until #14 exists.
func _make_sheepherder_marker() -> Polygon2D:
	var marker: Polygon2D = Polygon2D.new()
	var points: PackedVector2Array = []
	for index: int in 16:
		points.append(Vector2.from_angle(TAU * index / 16.0) * 18.0)
	marker.polygon = points
	marker.color = Color(0.3, 0.6, 1.0)
	return marker


func _build_controls() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var bar: HFlowContainer = HFlowContainer.new()
	bar.position = Vector2(12.0, 12.0)
	bar.size = Vector2(1200.0, 40.0)
	layer.add_child(bar)
	_add_button(bar, "New round", _on_new_round)
	_add_button(bar, "Wander", _on_wander)
	_add_button(bar, "Debug overlay", _on_debug_overlay)
	_add_button(bar, "Whole arena", _show_whole_arena)
	_add_button(bar, "Gameplay zoom", _show_gameplay_zoom)
	_status = Label.new()
	bar.add_child(_status)


func _add_button(bar: Container, text: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(action)
	bar.add_child(button)


func _on_new_round() -> void:
	_round_seed = randi()
	_spawn_round()


func _on_wander() -> void:
	_wandering = not _wandering
	_wander_time = 0.0
	if not _wandering:
		for sheep: SheepBody in _sheep:
			sheep.set_move_input(Vector2.ZERO)


func _on_debug_overlay() -> void:
	_arena.debug_overlay_visible = not _arena.debug_overlay_visible


func _show_whole_arena() -> void:
	var bounds: Rect2 = _arena.get_bounds()
	var viewport: Vector2 = get_viewport_rect().size
	var zoom: float = minf(viewport.x / bounds.size.x, viewport.y / bounds.size.y)
	_camera.zoom = Vector2(zoom, zoom)
	_camera.position = bounds.get_center()


func _show_gameplay_zoom() -> void:
	var zoom: float = ViewRules.camera_zoom(
		get_viewport_rect().size, Services.config.get_view_max_world_size()
	)
	_camera.zoom = Vector2(zoom, zoom)
	_camera.position = _arena.get_flock_spawn_area().get_center()
