class_name PerkCatalog
extends Resource
## Every perk of the game (GDD §4), one [PerkDefinition] each. A new perk is a
## new definition listed here; nothing else has to change.

const DEFAULT_PATH: String = "res://systems/perks/perk_catalog.tres"

@export var perks: Array[PerkDefinition] = []


## The shipped catalog.
static func load_default() -> PerkCatalog:
	return load(DEFAULT_PATH) as PerkCatalog


## The definition of [param perk_id], or [code]null[/code].
func get_perk(perk_id: StringName) -> PerkDefinition:
	for perk: PerkDefinition in perks:
		if perk.id == perk_id:
			return perk
	return null


## The perks a player with [param role] may choose from, in catalog order.
func pool_for(role: GameEnums.Role) -> Array[StringName]:
	var pool: Array[StringName] = []
	for perk: PerkDefinition in perks:
		if perk.role == role and role != GameEnums.Role.NONE:
			pool.append(perk.id)
	return pool


## Whether [param perk_id] is in the pool of [param role].
func is_valid_for(role: GameEnums.Role, perk_id: StringName) -> bool:
	return pool_for(role).has(perk_id)
