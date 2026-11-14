class_name StubCombatService
extends CombatService
## Peaceful [CombatService]: nothing can be shot or eaten.
##
## Every request is refused. The state queries answer for a fresh round (full
## magazine, nothing eaten, sheep form), so UI built against the contract has
## sensible values to show.

var _config: GameConfig
var _round_active: bool = false
var _eat_blockers: Array[StringName] = []


func _init(config: GameConfig = null) -> void:
	_config = config if config != null else GameConfig.new()


func begin_round(_sheepherder: Node2D, _monster: Node2D) -> void:
	_round_active = true
	_eat_blockers.clear()
	ammo_changed.emit(get_ammo(), get_ammo_capacity())
	eaten_count_changed.emit(0)


func end_round() -> void:
	_round_active = false


## Whether a round was begun and not ended yet, for tests.
func is_round_active() -> bool:
	return _round_active


func request_shot(_origin: Vector2, _direction: Vector2) -> bool:
	return false


func can_shoot() -> bool:
	return false


func get_ammo() -> int:
	return _config.firearm_ammo


func get_ammo_capacity() -> int:
	return _config.firearm_ammo


func is_reloading() -> bool:
	return false


func get_reload_progress() -> float:
	return 1.0


func is_ammo_depleted() -> bool:
	return false


func get_shot_sheep_count() -> int:
	return 0


func request_eat() -> bool:
	return false


func can_eat() -> bool:
	return false


func is_eating() -> bool:
	return false


func get_eat_cooldown_remaining() -> float:
	return 0.0


func add_eat_blocker(source: StringName) -> void:
	if not _eat_blockers.has(source):
		_eat_blockers.append(source)


func remove_eat_blocker(source: StringName) -> void:
	_eat_blockers.erase(source)


func get_eaten_count() -> int:
	return 0


func get_eaten_alive_count() -> int:
	return 0


func get_monster_form() -> GameEnums.MonsterForm:
	return GameEnums.MonsterForm.SHEEP


func can_kill_sheepherder() -> bool:
	return false


func is_monster_killable() -> bool:
	return true
