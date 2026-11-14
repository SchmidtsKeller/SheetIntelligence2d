class_name RoundStage
extends Node2D
## The world of one round: the arena with the flock, the Sheepherder and the
## Monster, what the local player sees of it and the blood on the ground.
##
## The stage does what the [MatchFlow] says. When the flow reaches
## [constant MatchFlow.Phase.SPAWN], the host spawns the round's cast from the
## round seed; on both devices the round begins for the combat service as soon
## as both characters are there, and this device's player gets the controls
## and the eyes of their role. A stage lives for one round: the round screen
## brings a new one, with a fresh arena, every time.

const ARENA_SCENE: PackedScene = preload("res://systems/arena/arena.tscn")
## The owner of a character that nobody plays (offline): no device steers it.
const NOBODY: int = -1

var _arena: Arena
var _vision: VisionSystem
var _session: GameSession
var _flow: MatchFlow
var _herder: Sheepherder
var _monster: Monster


func _ready() -> void:
	_arena = ARENA_SCENE.instantiate()
	add_child(_arena)
	var blood: BloodDecalSpawner = BloodDecalSpawner.new()
	blood.decals = _arena.get_decals_layer()
	add_child(blood)
	_vision = VisionSystem.new()
	_arena.get_overlays_layer().add_child(_vision)

	_session = Services.session
	_flow = Services.match_flow
	Monster.register(_session)
	_session.entities.register_kind(
		Sheepherder.KIND, Sheepherder.build, Monster.find_entities_layer.bind(_session)
	)
	_session.entities.entity_spawned.connect(_on_entity_spawned)
	_session.roles_changed.connect(_apply_role)
	_flow.phase_changed.connect(_on_phase_changed)


func _exit_tree() -> void:
	_session.entities.entity_spawned.disconnect(_on_entity_spawned)
	_session.roles_changed.disconnect(_apply_role)
	_flow.phase_changed.disconnect(_on_phase_changed)
	Services.input.set_role(GameEnums.Role.NONE)
	Services.combat.end_round()
	_despawn_round()


func get_arena() -> Arena:
	return _arena


func get_vision() -> VisionSystem:
	return _vision


## The Sheepherder of the round; [code]null[/code] before it is spawned.
func get_sheepherder() -> Sheepherder:
	return _herder if is_instance_valid(_herder) else null


## The Monster of the round; [code]null[/code] before it is spawned.
func get_monster() -> Monster:
	return _monster if is_instance_valid(_monster) else null


## Whether the round's cast is there and the round has begun for the combat
## service.
func is_cast_ready() -> bool:
	return get_sheepherder() != null and get_monster() != null


func _on_phase_changed(phase: MatchFlow.Phase) -> void:
	if phase == MatchFlow.Phase.SPAWN and _session.is_active() and _session.is_host():
		_spawn_round()


## Host: the flock, the Monster in the slot the flock leaves free for it, and
## the Sheepherder in their corner, all placed by the round seed. Each
## character belongs to the device of its player.
func _spawn_round() -> void:
	_despawn_round()
	var round_seed: int = _flow.get_round_seed()
	Services.swarm.spawn_flock(round_seed)
	var local_id: int = _session.get_local_peer_id()
	var other_id: int = _session.get_remote_peer_id() if _session.has_remote_player() else NOBODY
	var local_is_monster: bool = _session.get_local_role() == GameEnums.Role.MONSTER
	var slot_count: int = Services.perks.get_stat_int(StatIds.FLOCK_SIZE) + 1
	var start: Vector2 = _arena.get_spawn_layout(round_seed, slot_count).sheepherder_position
	_session.entities.spawn(
		Sheepherder.KIND, other_id if local_is_monster else local_id, {"x": start.x, "y": start.y}
	)
	_session.entities.spawn(
		Monster.KIND,
		local_id if local_is_monster else other_id,
		Monster.spawn_data(round_seed, _arena)
	)


func _despawn_round() -> void:
	if not _session.is_active() or not _session.is_host():
		return
	Services.swarm.despawn_flock()
	if is_instance_valid(_monster):
		_session.entities.despawn(_monster.entity_id)
	if is_instance_valid(_herder):
		_session.entities.despawn(_herder.entity_id)


## Both devices: the round begins when its two characters are there, with a
## full magazine, no cooldowns and clean ground.
func _on_entity_spawned(_entity_id: int, entity: Node) -> void:
	if entity is Sheepherder:
		_herder = entity
		_monster = null
	elif Monster.of(entity) != null:
		_monster = Monster.of(entity)
	else:
		return
	if _herder == null or _monster == null:
		return
	for decal: Node in _arena.get_decals_layer().get_children():
		decal.queue_free()
	_arena.apply_camera_limits(_herder.get_camera())
	Services.combat.begin_round(_herder, _monster.get_body())
	_apply_role()


## Hands the controls and the eyes of its role to this device's player.
func _apply_role() -> void:
	var role: GameEnums.Role = _session.get_local_role()
	Services.input.set_role(role)
	_vision.role = role
	if role == GameEnums.Role.SHEEPHERDER:
		_vision.viewer = get_sheepherder()
	else:
		_vision.viewer = _monster.get_body() if get_monster() != null else null
