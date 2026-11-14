class_name StubPerkService
extends PerkService
## Perk-less [PerkService]: every stat has its plain [GameConfig] value.
##
## Selections are stored and validated against the role pools, but a selected
## perk has no effect, modifiers are accepted and ignored, and there are no
## active perks.

var _config: GameConfig
var _selected: Dictionary[GameEnums.Role, StringName] = {}
var _locked: bool = false
var _next_handle: int = 1


func _init(config: GameConfig = null) -> void:
	_config = config if config != null else GameConfig.new()


func get_stat(stat: StringName) -> float:
	return _config.get_number(stat)


func get_base_stat(stat: StringName) -> float:
	return _config.get_number(stat)


func add_modifier(
	_stat: StringName,
	_op: ModifierOp,
	_value: float,
	_source: StringName,
	_duration: float = -1.0,
) -> int:
	_next_handle += 1
	return _next_handle - 1


func remove_modifier(_handle: int) -> void:
	pass


func remove_modifiers_from(_source: StringName) -> void:
	pass


func get_available_perks(role: GameEnums.Role) -> Array[StringName]:
	return PerkIds.pool_for(role)


func select_perk(role: GameEnums.Role, perk_id: StringName) -> bool:
	if _locked or not PerkIds.is_valid_for(role, perk_id):
		return false
	_selected[role] = perk_id
	perk_selected.emit(role, perk_id)
	return true


func get_selected_perk(role: GameEnums.Role) -> StringName:
	return _selected.get(role, PerkIds.NONE)


func lock_selection() -> void:
	_locked = true


func is_selection_locked() -> bool:
	return _locked


func clear_selection() -> void:
	_locked = false
	_selected.clear()


func activate_perk(_role: GameEnums.Role) -> bool:
	return false


func is_perk_active(_role: GameEnums.Role) -> bool:
	return false


func get_perk_cooldown_remaining(_role: GameEnums.Role) -> float:
	return 0.0


func get_perk_charge(_role: GameEnums.Role) -> float:
	return 0.0
