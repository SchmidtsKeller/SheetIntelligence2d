extends TestCase
## `project.godot` declares the input actions, physics layers, groups and
## settings the code relies on.


func test_every_input_action_is_declared() -> void:
	for action: StringName in InputActions.ALL:
		assert_true(InputMap.has_action(action), "input action '%s' exists" % action)


func test_pseudo_actions_are_not_real_input_actions() -> void:
	assert_false(InputMap.has_action(InputActions.MOVE))
	assert_false(InputMap.has_action(InputActions.AIM))


func test_movement_and_abilities_have_desktop_bindings() -> void:
	var bound: Array[StringName] = []
	bound.append_array(InputActions.MOVEMENT)
	bound.append_array(InputActions.SHEEPHERDER_ACTIONS)
	bound.append_array(InputActions.MONSTER_ACTIONS)

	for action: StringName in bound:
		assert_gt(InputMap.action_get_events(action).size(), 0, "'%s' has a default binding" % action)


func test_no_key_is_bound_to_two_actions() -> void:
	var owner_of_key: Dictionary[int, StringName] = {}

	for action: StringName in InputActions.ALL:
		for event: InputEvent in InputMap.action_get_events(action):
			var key_event: InputEventKey = event as InputEventKey
			if key_event == null:
				continue
			var key: int = key_event.physical_keycode
			assert_false(owner_of_key.has(key), "key %s is bound to '%s' and '%s'" % [
				OS.get_keycode_string(key), owner_of_key.get(key, &""), action,
			])
			owner_of_key[key] = action


func test_action_lists_are_consistent() -> void:
	var listed: Array[StringName] = []
	listed.append_array(InputActions.MOVEMENT)
	listed.append_array(InputActions.AIMING)
	listed.append_array(InputActions.SHEEPHERDER_ACTIONS)
	listed.append_array(InputActions.MONSTER_ACTIONS)

	assert_eq(listed.size(), InputActions.ALL.size())
	for action: StringName in listed:
		assert_has(InputActions.ALL, action)
	for action: StringName in InputActions.HOLD_ACTIONS:
		assert_has(InputActions.MONSTER_ACTIONS, action)


func test_physics_layers_are_named() -> void:
	for number: int in PhysicsLayers.NAMES:
		assert_eq(
			ProjectSettings.get_setting(PhysicsLayers.setting_path(number), ""),
			PhysicsLayers.NAMES[number],
			"name of 2D physics layer %d" % number,
		)


func test_physics_layer_constants_match_their_layer_numbers() -> void:
	assert_eq(PhysicsLayers.WORLD, 1 << 0)
	assert_eq(PhysicsLayers.SHEEPHERDER, 1 << 1)
	assert_eq(PhysicsLayers.SHEEP, 1 << 2)
	assert_eq(PhysicsLayers.COMPANIONS, 1 << 3)
	assert_eq(PhysicsLayers.HITBOX, 1 << 4)
	assert_eq(PhysicsLayers.NAMES.size(), 5)


func test_groups_are_declared_as_global_groups() -> void:
	for group: StringName in Groups.ALL:
		assert_true(ProjectSettings.has_setting(Groups.setting_path(group)), "global group '%s' exists" % group)


func test_project_is_set_up_for_a_2d_web_game() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"), "gl_compatibility")
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1280)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 720)
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand")
	assert_eq(ProjectSettings.get_setting("physics/2d/default_gravity"), 0.0, "top-down: no gravity")


func test_untyped_code_is_a_compile_error() -> void:
	assert_eq(ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration"), 2)


func test_main_scene_is_the_boot_screen() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")

	assert_eq(ResourceUID.ensure_path(main_scene), "res://ui/screens/boot_screen.tscn")
	assert_true(ResourceLoader.exists(main_scene))


func test_autoloads_are_running() -> void:
	assert_is(get_node_or_null(^"/root/Services"), ServiceRegistry)
	assert_is(get_node_or_null(^"/root/SceneFlow"), SceneFlowController)
