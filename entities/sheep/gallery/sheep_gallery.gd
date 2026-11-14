extends Node2D
## Sheep gallery: the sheep of one round side by side at gameplay zoom, to
## check their looks and animations. Run this scene on its own (F6).
##
## Everything here only uses the public [SheepBody] methods, like the flock AI
## and the Monster player will.

const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")
const CATALOG: SheepAppearanceCatalog = preload(
	"res://entities/sheep/appearance/sheep_appearance_catalog.tres"
)
const COLUMNS: int = 4
const SPACING: Vector2 = Vector2(170.0, 150.0)
const GRASS: Color = Color("4f6b3a")
const NIGHT: Color = Color(0.07, 0.08, 0.11)
## How fast walking sheep go round in their circles, in radians per second.
const CIRCLE_RATE: float = 2.0

var _round_seed: int = 1
var _sheep: Array[SheepBody] = []
var _walking: bool = false
var _time: float = 0.0

var _herd: Node2D
var _labels: Node2D
var _camera: Camera2D
var _night: CanvasModulate
var _flashlight: PointLight2D
var _status: Label


func _ready() -> void:
	_herd = Node2D.new()
	_herd.name = "Herd"
	add_child(_herd)
	_labels = Node2D.new()
	_labels.name = "Labels"
	add_child(_labels)
	_camera = Camera2D.new()
	add_child(_camera)
	_build_night()
	_build_controls()
	get_viewport().size_changed.connect(_update_zoom)
	_update_zoom()
	_spawn_round()


func _draw() -> void:
	draw_rect(Rect2(-2000.0, -2000.0, 4000.0, 4000.0), GRASS)


func _process(_delta: float) -> void:
	_flashlight.global_position = get_global_mouse_position()


func _physics_process(delta: float) -> void:
	if not _walking:
		return
	_time += delta
	for index: int in _sheep.size():
		_sheep[index].set_move_input(Vector2.from_angle(_time * CIRCLE_RATE + index) * 0.5)


## The sheep currently shown.
func get_sheep() -> Array[SheepBody]:
	return _sheep


func _spawn_round() -> void:
	for node: Node in _herd.get_children() + _labels.get_children():
		node.queue_free()
	_sheep.clear()
	_walking = false
	var count: int = Services.perks.get_stat_int(StatIds.FLOCK_SIZE) + 1
	var seeds: PackedInt64Array = SheepAppearanceGenerator.generate_round_seeds(
		_round_seed, count, CATALOG
	)
	var rows: int = ceili(float(count) / COLUMNS)
	var origin: Vector2 = -Vector2(COLUMNS - 1, rows - 1) * SPACING / 2.0
	for index: int in count:
		var cell: Vector2 = (
			origin + Vector2(index % COLUMNS, floori(index / float(COLUMNS))) * SPACING
		)
		var sheep: SheepBody = SHEEP_SCENE.instantiate()
		sheep.set_visual_seed(seeds[index])
		sheep.position = cell
		_herd.add_child(sheep)
		_sheep.append(sheep)
		var label: Label = Label.new()
		label.text = "%d · seed %d" % [index + 1, seeds[index]]
		label.add_theme_font_size_override(&"font_size", 12)
		label.position = cell + Vector2(-50.0, 34.0)
		_labels.add_child(label)
	_status.text = "Round seed %d" % _round_seed


func _build_night() -> void:
	_night = CanvasModulate.new()
	_night.color = NIGHT
	_night.visible = false
	add_child(_night)
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var light_texture: GradientTexture2D = GradientTexture2D.new()
	light_texture.gradient = gradient
	light_texture.fill = GradientTexture2D.FILL_RADIAL
	light_texture.fill_from = Vector2(0.5, 0.5)
	light_texture.fill_to = Vector2(1.0, 0.5)
	light_texture.width = 512
	light_texture.height = 512
	_flashlight = PointLight2D.new()
	_flashlight.texture = light_texture
	_flashlight.color = Color(1.0, 0.92, 0.75)
	_flashlight.energy = 1.4
	_flashlight.enabled = false
	add_child(_flashlight)


func _build_controls() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var bar: HFlowContainer = HFlowContainer.new()
	bar.position = Vector2(12.0, 12.0)
	bar.size = Vector2(1200.0, 40.0)
	layer.add_child(bar)
	_add_button(bar, "New round", _on_new_round)
	_add_button(bar, "Reset", _spawn_round)
	_add_button(bar, "Walk", _on_walk)
	_add_button(bar, "Stop", _on_stop)
	_add_button(bar, "Graze", _on_graze)
	_add_button(bar, "Bleat", _on_bleat)
	_add_button(bar, "Shoot", _on_kill.bind(GameEnums.DeathCause.SHOT))
	_add_button(bar, "Eat", _on_kill.bind(GameEnums.DeathCause.EATEN))
	_add_button(bar, "Darkness", _on_darkness)
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


func _on_walk() -> void:
	_walking = true
	for sheep: SheepBody in _sheep:
		sheep.set_grazing(false)


func _on_stop() -> void:
	_walking = false
	for sheep: SheepBody in _sheep:
		sheep.set_move_input(Vector2.ZERO)


func _on_graze() -> void:
	for sheep: SheepBody in _sheep:
		sheep.set_grazing(not sheep.is_grazing())


func _on_bleat() -> void:
	for sheep: SheepBody in _sheep:
		sheep.bleat()


func _on_kill(cause: GameEnums.DeathCause) -> void:
	for sheep: SheepBody in _sheep:
		sheep.kill(cause)


func _on_darkness() -> void:
	_night.visible = not _night.visible
	_flashlight.enabled = _night.visible


## Gameplay zoom: the camera shows as much world as a player would see.
func _update_zoom() -> void:
	var zoom: float = ViewRules.camera_zoom(
		get_viewport_rect().size, Services.config.get_view_max_world_size()
	)
	_camera.zoom = Vector2(zoom, zoom)
