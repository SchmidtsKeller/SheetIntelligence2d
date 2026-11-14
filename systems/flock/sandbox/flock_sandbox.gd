extends Node2D
## Flock sandbox: the arena with a round's flock, for watching and tuning how
## the sheep behave. Run this scene on its own (F6).
##
## It runs as an offline session: this device is the host and simulates the
## flock. Click anywhere to ring the bell there. One more sheep stands in the
## flock without a mind of its own, as the Monster would: the others treat it
## as one of them. With the input service of the game it can be steered like
## the Monster (WASD, C to graze, F to bleat).

const ARENA_SCENE: PackedScene = preload("res://systems/arena/arena.tscn")
const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")
const SPEEDS: Array[float] = [1.0, 4.0, 0.25]

var _arena: Arena
var _camera: Camera2D
var _swarm: SwarmService
var _overlay: FlockDebugOverlay
var _round_seed: int = 1
var _speed_index: int = 0
var _extra_sheep: SheepBody
var _status: Label
var _normal_physics_ticks: int = Engine.physics_ticks_per_second
var _normal_physics_steps: int = Engine.max_physics_steps_per_frame


func _ready() -> void:
	_arena = ARENA_SCENE.instantiate()
	add_child(_arena)
	_camera = Camera2D.new()
	add_child(_camera)
	_arena.apply_camera_limits(_camera)
	get_viewport().size_changed.connect(_show_whole_arena)
	_show_whole_arena()

	_swarm = Services.swarm
	_overlay = FlockDebugOverlay.new()
	_overlay.swarm = _swarm as FlockSwarmService
	_arena.get_overlays_layer().add_child(_overlay)
	_build_controls()

	if not Services.session.is_active():
		Services.session.host()
	Services.input.set_role(GameEnums.Role.MONSTER)
	_spawn_round()


func _exit_tree() -> void:
	_set_speed(1.0)
	Services.input.set_role(GameEnums.Role.NONE)
	_swarm.despawn_flock()
	if is_instance_valid(_extra_sheep):
		_swarm.unregister_neighbour(_extra_sheep)


func _process(_delta: float) -> void:
	var walking: int = 0
	var grazing: int = 0
	var called: int = 0
	var flock: FlockSwarmService = _swarm as FlockSwarmService
	for sheep_id: int in _swarm.get_living_sheep_ids():
		var agent: FlockAgent = flock.get_agent(sheep_id) if flock != null else null
		if agent == null:
			continue
		walking += int(agent.activity == FlockAgent.Activity.WALK)
		grazing += int(agent.activity == FlockAgent.Activity.GRAZE)
		called += int(agent.activity == FlockAgent.Activity.BELL)
	_status.text = (
		"Seed %d | %d sheep alive | %d walking, %d grazing, %d following the bell | speed ×%s"
		% [_round_seed, _swarm.get_living_count(), walking, grazing, called, SPEEDS[_speed_index]]
	)


func _unhandled_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var radius: float = Services.perks.get_stat(StatIds.BELL_RADIUS)
		_swarm.ring_bell(get_global_mouse_position(), radius)


func _spawn_round() -> void:
	_swarm.spawn_flock(_round_seed)
	# The eleventh sheep takes the slot the flock left free, as the Monster will.
	var slot_count: int = Services.perks.get_stat_int(StatIds.FLOCK_SIZE) + 1
	var slot: int = RoundCast.monster_slot(_round_seed, slot_count)
	if is_instance_valid(_extra_sheep):
		_swarm.unregister_neighbour(_extra_sheep)
		_extra_sheep.queue_free()
	_extra_sheep = SHEEP_SCENE.instantiate()
	_extra_sheep.set_visual_seed(RoundCast.visual_seeds(_round_seed, slot_count)[slot])
	_extra_sheep.position = _arena.get_spawn_layout(_round_seed, slot_count).sheep_positions[slot]
	_arena.get_entities_layer().add_child(_extra_sheep)
	var driver: SheepPlayerDriver = SheepPlayerDriver.new()
	driver.body = _extra_sheep
	_extra_sheep.add_child(driver)
	_swarm.register_neighbour(_extra_sheep)


func _show_whole_arena() -> void:
	var bounds: Rect2 = _arena.get_bounds()
	var view: Vector2 = get_viewport_rect().size
	_camera.position = bounds.get_center()
	_camera.zoom = Vector2.ONE * minf(view.x / bounds.size.x, view.y / bounds.size.y)


func _build_controls() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var row: HBoxContainer = HBoxContainer.new()
	row.position = Vector2(12.0, 12.0)
	row.add_theme_constant_override(&"separation", 8)
	layer.add_child(row)
	_add_button(row, "New flock", _new_flock)
	_add_button(row, "Overlay", _toggle_overlay)
	_add_button(row, "Speed", _next_speed)
	_add_button(row, "Kill one", _kill_one)
	_status = Label.new()
	row.add_child(_status)
	var hint: Label = Label.new()
	hint.text = "Click on the field to ring the bell there."
	hint.position = Vector2(12.0, 52.0)
	layer.add_child(hint)


func _add_button(row: HBoxContainer, text: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	row.add_child(button)


func _new_flock() -> void:
	_round_seed += 1
	_spawn_round()


func _toggle_overlay() -> void:
	_overlay.visible = not _overlay.visible


func _next_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	_set_speed(SPEEDS[_speed_index])


## Time lapse runs more physics steps instead of longer ones, so the sheep
## behave exactly as at normal speed.
func _set_speed(factor: float) -> void:
	var steps: float = maxf(factor, 1.0)
	Engine.time_scale = factor
	Engine.physics_ticks_per_second = roundi(_normal_physics_ticks * steps)
	Engine.max_physics_steps_per_frame = roundi(_normal_physics_steps * steps)


func _kill_one() -> void:
	var living: Array[int] = _swarm.get_living_sheep_ids()
	if not living.is_empty():
		_swarm.kill_sheep(living[0], GameEnums.DeathCause.SHOT)
