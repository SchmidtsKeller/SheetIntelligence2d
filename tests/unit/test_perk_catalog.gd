extends TestCase
## The shipped perk catalog (GDD §4): the pools of both roles and the data the
## lobby and the perk service need from each perk.

var _catalog: PerkCatalog = PerkCatalog.load_default()


func test_sheepherder_has_five_perks_and_the_monster_three() -> void:
	assert_eq(
		_catalog.pool_for(GameEnums.Role.SHEEPHERDER),
		[
			PerkIds.WIDE_FLASHLIGHT,
			PerkIds.LONG_FLASHLIGHT,
			PerkIds.FASTER_RELOAD,
			PerkIds.SHEPHERD_DOG,
			PerkIds.SPARE_BULLET,
		]
	)
	assert_eq(
		_catalog.pool_for(GameEnums.Role.MONSTER),
		[PerkIds.FASTER_CONSUMPTION, PerkIds.INVISIBILITY, PerkIds.ALLIED_BAT]
	)
	assert_eq(_catalog.pool_for(GameEnums.Role.NONE), [])


func test_perk_pools_do_not_overlap() -> void:
	for perk_id: StringName in _catalog.pool_for(GameEnums.Role.SHEEPHERDER):
		assert_true(_catalog.is_valid_for(GameEnums.Role.SHEEPHERDER, perk_id))
		assert_false(_catalog.is_valid_for(GameEnums.Role.MONSTER, perk_id))


func test_no_perk_is_never_a_valid_choice() -> void:
	assert_false(_catalog.is_valid_for(GameEnums.Role.SHEEPHERDER, PerkIds.NONE))
	assert_false(_catalog.is_valid_for(GameEnums.Role.MONSTER, PerkIds.NONE))
	assert_null(_catalog.get_perk(PerkIds.NONE))


func test_every_perk_the_code_names_is_in_the_catalog_once() -> void:
	var constants: Dictionary = (PerkIds as Script).get_script_constant_map()
	for key: String in constants:
		var perk_id: StringName = constants[key]
		if perk_id != PerkIds.NONE:
			assert_not_null(_catalog.get_perk(perk_id), "'%s' has a definition" % perk_id)
	var ids: Array[StringName] = []
	for perk: PerkDefinition in _catalog.perks:
		assert_does_not_have(ids, perk.id, "'%s' is listed once" % perk.id)
		ids.append(perk.id)


func test_every_definition_is_complete() -> void:
	var stats: Array[StringName] = StatIds.all()
	for perk: PerkDefinition in _catalog.perks:
		assert_ne(perk.role, GameEnums.Role.NONE, "'%s' has a role" % perk.id)
		assert_false(perk.display_name.is_empty(), "'%s' has a name" % perk.id)
		assert_false(perk.description.is_empty(), "'%s' has a description" % perk.id)
		for modifier: PerkModifier in perk.modifiers:
			assert_has(stats, modifier.stat, "'%s' changes a known stat" % perk.id)
			assert_has(stats, modifier.value_stat, "'%s' takes a known value" % perk.id)
		if perk.is_triggered():
			assert_is(perk.effect.new(), PerkEffect, "'%s' has a perk effect" % perk.id)


func test_only_invisibility_is_triggered_for_now() -> void:
	# The bat gets its effect with the companions (#19).
	for perk: PerkDefinition in _catalog.perks:
		assert_eq(perk.is_triggered(), perk.id == PerkIds.INVISIBILITY, String(perk.id))
	assert_eq(_catalog.get_perk(PerkIds.INVISIBILITY).kind, PerkDefinition.Kind.ACTIVE)
	assert_eq(_catalog.get_perk(PerkIds.SHEPHERD_DOG).kind, PerkDefinition.Kind.COMPANION)
	assert_eq(_catalog.get_perk(PerkIds.ALLIED_BAT).kind, PerkDefinition.Kind.COMPANION)
