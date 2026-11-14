extends Node2D
## Vision sandbox: the arena with a round's flock, the Sheepherder and a sheep
## standing in for the Monster, seen through the eyes of either player. Run
## this scene on its own (F6).
##
## As the Sheepherder: WASD, aim with the mouse, Space rings the bell, left
## click shoots. As the Monster: WASD, C grazes, F bleats, Q uses the perk. The
## perk picker sets the perk of the player whose view is shown, until the lobby
## has a perk selection; the Monster's view shows nothing of the Sheepherder's
## perk. The overlay rings every entity in green (seen) or red (hidden).

const ARENA_SCENE: PackedScene = preload("res://systems/arena/arena.tscn")
const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")
const ROUND_SEED: int = 15
## Where the Sheepherder starts: this far below the flock's spawn area.
const START_BELOW_FLOCK: float = 200.0

var _arena: Arena
var _camera: Camera2D
var _vision: VisionSystem
var _overlay: VisionDebugOverlay
var _herder: Sheepherder
var _monster: SheepBody
var _driver: SheepPlayerDriver
var _status: Label
var _picker: OptionButton
## The perk each player has, as picked here.
var _choices: Dictionary[GameEnums.Role, StringName] = {}


func _ready() -> void:
	_arena = ARENA_SCENE.instantiate()
	add_child(_arena)
	if not Services.session.is_active():
		Services.session.host()
	Services.swarm.spawn_flock(ROUND_SEED)
	_spawn_monster()
	_spawn_sheepherder()
	for role: GameEnums.Role in [GameEnums.Role.SHEEPHERDER, GameEnums.Role.MONSTER]:
		_choices[role] = Services.perks.get_selected_perk(role)
	_apply_perks()

	var blood: BloodDecalSpawner = BloodDecalSpawner.new()
	blood.decals = _arena.get_decals_layer()
	add_child(blood)
	_vision = VisionSystem.new()
	_arena.get_overlays_layer().add_child(_vision)
	_overlay = VisionDebugOverlay.new()
	_overlay.vision = _vision
	_overlay.visible = false
	_arena.get_overlays_layer().add_child(_overlay)
	_driver = SheepPlayerDriver.new()
	add_child(_driver)

	_camera = Camera2D.new()
	add_child(_camera)
	_arena.apply_camera_limits(_camera)
	_camera.make_current()
	get_viewport().size_changed.connect(_update_zoom)
	_update_zoom()
	_build_controls()
	Services.input.action_pressed.connect(_on_action_pressed)
	set_role(GameEnums.Role.SHEEPHERDER)


func _exit_tree() -> void:
	Services.input.action_pressed.disconnect(_on_action_pressed)
	Services.input.set_role(GameEnums.Role.NONE)
	Services.combat.end_round()
	Services.perks.clear_selection()
	Services.perks.unregister_character(_monster)
	Services.swarm.unregister_neighbour(_monster)
	Services.swarm.despawn_flock()


func _process(_delta: float) -> void:
	_camera.global_position = _vision.viewer.global_position
	_status.text = get_status()


## The status line. The Monster's view tells nothing about the firearm, which
## would give the Spare Bullet away.
func get_status() -> String:
	var status: String = (
		"Seeing as the %s.  %d sheep alive"
		% [GameEnums.role_name(_vision.role), Services.swarm.get_living_count()]
	)
	if _vision.role == GameEnums.Role.SHEEPHERDER:
		var combat: CombatService = Services.combat
		return status + ", bullets %d / %d" % [combat.get_ammo(), combat.get_ammo_capacity()]
	var perks: PerkService = Services.perks
	var monster: GameEnums.Role = GameEnums.Role.MONSTER
	if perks.is_perk_active(monster):
		return status + ", perk running (%d %%)" % roundi(perks.get_perk_charge(monster) * 100.0)
	if perks.get_perk_cooldown_remaining(monster) > 0.0:
		return status + ", perk again in %.1f s" % perks.get_perk_cooldown_remaining(monster)
	return status


## Sees the round as the player with [param role] and hands them the controls.
func set_role(role: GameEnums.Role) -> void:
	var as_herder: bool = role == GameEnums.Role.SHEEPHERDER
	_vision.role = role
	_vision.viewer = _herder if as_herder else _monster
	Services.input.set_role(role)
	_herder.set_physics_process(as_herder)
	_driver.body = null if as_herder else _monster
	_monster.set_move_input(Vector2.ZERO)
	_fill_picker(role)


## Gives the player with [param role] the perk [param perk_id]
## ([constant PerkIds.NONE] for none) and starts the round again with it.
func pick_perk(role: GameEnums.Role, perk_id: StringName) -> void:
	_choices[role] = perk_id
	_apply_perks()
	_fill_picker(_vision.role)


## The vision system of the sandbox.
func get_vision() -> VisionSystem:
	return _vision


## The perk picker, which offers the perks of the player whose view is shown.
func get_picker() -> OptionButton:
	return _picker


## The sheep standing in for the Monster.
func get_monster() -> SheepBody:
	return _monster


func _apply_perks() -> void:
	var perks: PerkService = Services.perks
	perks.clear_selection()
	for role: GameEnums.Role in _choices:
		if _choices[role] != PerkIds.NONE:
			perks.select_perk(role, _choices[role])
	perks.lock_selection()
	# The magazine size is read when a round begins.
	Services.combat.begin_round(_herder, _monster)


func _fill_picker(role: GameEnums.Role) -> void:
	_picker.clear()
	_picker.add_item("No perk")
	_picker.set_item_metadata(0, PerkIds.NONE)
	for perk_id: StringName in Services.perks.get_available_perks(role):
		_picker.add_item(String(perk_id).capitalize())
		_picker.set_item_metadata(_picker.item_count - 1, perk_id)
		if perk_id == _choices.get(role, PerkIds.NONE):
			_picker.select(_picker.item_count - 1)


func _on_perk_picked(index: int) -> void:
	# The picker already shows the choice.
	_choices[_vision.role] = _picker.get_item_metadata(index)
	_apply_perks()


func _on_action_pressed(action: StringName) -> void:
	if action == InputActions.PERK and _vision.role == GameEnums.Role.MONSTER:
		Services.perks.use_perk(GameEnums.Role.MONSTER)


func _spawn_monster() -> void:
	var slot_count: int = Services.perks.get_stat_int(StatIds.FLOCK_SIZE) + 1
	var slot: int = RoundCast.monster_slot(ROUND_SEED, slot_count)
	_monster = SHEEP_SCENE.instantiate()
	_monster.set_visual_seed(RoundCast.visual_seeds(ROUND_SEED, slot_count)[slot])
	_monster.position = _arena.get_spawn_layout(ROUND_SEED, slot_count).sheep_positions[slot]
	_arena.get_entities_layer().add_child(_monster)
	Services.swarm.register_neighbour(_monster)
	Services.perks.register_character(GameEnums.Role.MONSTER, _monster)


func _spawn_sheepherder() -> void:
	var flock: Rect2 = _arena.get_flock_spawn_area()
	var start: Vector2 = Vector2(flock.get_center().x, flock.end.y + START_BELOW_FLOCK)
	var local_id: int = Services.session.messenger.get_local_id()
	_herder = Sheepherder.build(-1, local_id, {"x": start.x, "y": start.y})
	_arena.get_entities_layer().add_child(_herder)


func _build_controls() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var row: HBoxContainer = HBoxContainer.new()
	row.position = Vector2(12.0, 12.0)
	row.add_theme_constant_override(&"separation", 8)
	layer.add_child(row)
	_add_button(row, "Sheepherder", set_role.bind(GameEnums.Role.SHEEPHERDER))
	_add_button(row, "Monster", set_role.bind(GameEnums.Role.MONSTER))
	_add_button(row, "Overlay", func() -> void: _overlay.visible = not _overlay.visible)
	_picker = OptionButton.new()
	_picker.focus_mode = Control.FOCUS_NONE
	_picker.item_selected.connect(_on_perk_picked)
	row.add_child(_picker)
	_status = Label.new()
	row.add_child(_status)


func _add_button(row: HBoxContainer, text: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	row.add_child(button)


## Gameplay zoom: as much world as a player may see.
func _update_zoom() -> void:
	var zoom: float = ViewRules.camera_zoom(
		get_viewport_rect().size, Services.config.get_view_max_world_size()
	)
	_camera.zoom = Vector2(zoom, zoom)
