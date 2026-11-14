extends Node2D
## Sheepherder sandbox: walk (WASD), aim (mouse), ring the bell (Space) and
## shoot (left mouse button) in the arena, among a round's sheep that stand
## still. Run this scene on its own (F6).

const ARENA_SCENE: PackedScene = preload("res://systems/arena/arena.tscn")
const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")
const CATALOG: SheepAppearanceCatalog = preload(
	"res://entities/sheep/appearance/sheep_appearance_catalog.tres"
)
const ROUND_SEED: int = 14
## Where the Sheepherder starts: this far below the flock's spawn area.
const START_BELOW_FLOCK: float = 160.0
const BLOOD_COLOR: Color = Color(0.45, 0.05, 0.05, 0.85)

var _arena: Arena
var _herder: Sheepherder
var _swarm: SandboxSwarmService
var _previous_swarm: Node
var _status: Label


func _ready() -> void:
	_arena = ARENA_SCENE.instantiate()
	add_child(_arena)
	_swarm = SandboxSwarmService.new()
	_previous_swarm = Services.replace(SwarmService, _swarm)
	_spawn_sheep()
	_spawn_sheepherder()
	Services.input.set_role(GameEnums.Role.SHEEPHERDER)
	Services.combat.begin_round(_herder, null)
	Services.combat.blood_spilled.connect(_on_blood_spilled)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(12.0, 12.0)
	layer.add_child(_status)


func _exit_tree() -> void:
	Services.combat.blood_spilled.disconnect(_on_blood_spilled)
	Services.combat.end_round()
	Services.input.set_role(GameEnums.Role.NONE)
	Services.replace(SwarmService, _previous_swarm)
	_swarm.free()


func _process(_delta: float) -> void:
	var combat: CombatService = Services.combat
	var reload: String = (
		" (reloading %d %%)" % roundi(combat.get_reload_progress() * 100.0)
		if combat.is_reloading()
		else ""
	)
	_status.text = (
		"Bullets %d / %d%s   Bell %s   Sheep alive %d   (WASD, mouse, Space, left click)"
		% [
			combat.get_ammo(),
			combat.get_ammo_capacity(),
			reload,
			(
				"ready"
				if _herder.can_ring_bell()
				else "%.1f s" % _herder.get_bell_cooldown_remaining()
			),
			_swarm.get_living_count(),
		]
	)


## The Sheepherder of the sandbox.
func get_sheepherder() -> Sheepherder:
	return _herder


## The flock of the sandbox.
func get_swarm() -> SandboxSwarmService:
	return _swarm


func _spawn_sheep() -> void:
	var count: int = Services.perks.get_stat_int(StatIds.FLOCK_SIZE) + 1
	var layout: ArenaSpawnLayout = _arena.get_spawn_layout(ROUND_SEED, count)
	var seeds: PackedInt64Array = SheepAppearanceGenerator.generate_round_seeds(
		ROUND_SEED, count, CATALOG
	)
	for index: int in count:
		var sheep: SheepBody = SHEEP_SCENE.instantiate()
		sheep.set_visual_seed(seeds[index])
		sheep.position = layout.sheep_positions[index]
		_arena.get_entities_layer().add_child(sheep)
		_swarm.add_sheep(sheep)


func _spawn_sheepherder() -> void:
	var flock: Rect2 = _arena.get_flock_spawn_area()
	var start: Vector2 = Vector2(flock.get_center().x, flock.end.y + START_BELOW_FLOCK)
	var local_id: int = Services.session.messenger.get_local_id()
	_herder = Sheepherder.build(-1, local_id, {"x": start.x, "y": start.y})
	_arena.get_entities_layer().add_child(_herder)
	_arena.apply_camera_limits(_herder.get_camera())


func _on_blood_spilled(at: Vector2) -> void:
	var splat: Polygon2D = Polygon2D.new()
	var points: PackedVector2Array = []
	for index: int in 10:
		var radius: float = 9.0 if index % 2 == 0 else 6.0
		points.append(Vector2.from_angle(TAU * index / 10.0) * radius)
	splat.polygon = points
	splat.color = BLOOD_COLOR
	splat.position = at
	_arena.get_decals_layer().add_child(splat)
