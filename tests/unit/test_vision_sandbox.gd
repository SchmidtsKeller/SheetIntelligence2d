extends TestCase
## The vision sandbox switches between the two players' views, gives them
## perks and cleans up.

const SANDBOX_SCENE: String = "res://systems/vision/sandbox/vision_sandbox.tscn"

var _sandbox: Node2D


func before_each() -> void:
	_sandbox = (load(SANDBOX_SCENE) as PackedScene).instantiate()
	add_child(_sandbox)
	await wait_frames(2)


func after_each() -> void:
	if is_instance_valid(_sandbox):
		_sandbox.free()


func test_the_sandbox_switches_views_and_cleans_up() -> void:
	var vision: VisionSystem = _sandbox.call(&"get_vision")
	assert_eq(vision.role, GameEnums.Role.SHEEPHERDER)
	assert_is(vision.viewer, Sheepherder)
	assert_eq(Services.swarm.get_living_count(), Services.config.flock_size)

	_sandbox.call(&"set_role", GameEnums.Role.MONSTER)
	assert_eq(vision.role, GameEnums.Role.MONSTER)
	assert_is(vision.viewer, SheepBody)
	assert_eq(Services.input.get_role(), GameEnums.Role.MONSTER)

	_sandbox.call(&"pick_perk", GameEnums.Role.MONSTER, PerkIds.FASTER_CONSUMPTION)
	remove_child(_sandbox)
	_sandbox.free()
	assert_eq(Services.input.get_role(), GameEnums.Role.NONE)
	assert_eq(Services.swarm.get_living_count(), 0, "the flock is gone")
	assert_false(Services.perks.is_selection_locked(), "and so are the perks")
	assert_eq(Services.perks.get_stat(StatIds.EAT_DURATION), Services.config.eat_duration)


func test_the_monsters_view_tells_nothing_of_the_sheepherders_perk() -> void:
	_sandbox.call(&"pick_perk", GameEnums.Role.SHEEPHERDER, PerkIds.SPARE_BULLET)
	assert_true(String(_sandbox.call(&"get_status")).contains("bullets 4 / 4"))
	assert_eq(
		_picker_ids(),
		[PerkIds.NONE] + Services.perks.get_available_perks(GameEnums.Role.SHEEPHERDER)
	)
	assert_eq(_picked(), PerkIds.SPARE_BULLET)

	_sandbox.call(&"set_role", GameEnums.Role.MONSTER)

	assert_false(String(_sandbox.call(&"get_status")).contains("bullets"))
	assert_eq(
		_picker_ids(), [PerkIds.NONE] + Services.perks.get_available_perks(GameEnums.Role.MONSTER)
	)
	assert_eq(_picked(), PerkIds.NONE, "the Monster's own choice")


func test_the_monster_turns_invisible_with_the_perk_button() -> void:
	var vision: VisionSystem = _sandbox.call(&"get_vision")
	var monster: SheepBody = _sandbox.call(&"get_monster")
	_sandbox.call(&"set_role", GameEnums.Role.MONSTER)
	_sandbox.call(&"pick_perk", GameEnums.Role.MONSTER, PerkIds.INVISIBILITY)

	Services.input.action_pressed.emit(InputActions.PERK)

	assert_true(Services.perks.is_perk_active(GameEnums.Role.MONSTER))
	assert_true(String(_sandbox.call(&"get_status")).contains("perk running"))
	assert_true(vision.can_see(VisionTarget.of(monster)), "its own player sees it")
	_sandbox.call(&"set_role", GameEnums.Role.SHEEPHERDER)
	assert_false(vision.can_see(VisionTarget.of(monster)), "the Sheepherder does not")


func _picker_ids() -> Array[StringName]:
	var picker: OptionButton = _sandbox.call(&"get_picker")
	var ids: Array[StringName] = []
	for index: int in picker.item_count:
		ids.append(picker.get_item_metadata(index))
	return ids


func _picked() -> StringName:
	var picker: OptionButton = _sandbox.call(&"get_picker")
	return picker.get_item_metadata(picker.selected)
