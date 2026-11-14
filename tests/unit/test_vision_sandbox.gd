extends TestCase
## The vision sandbox switches between the two players' views and cleans up.

const SANDBOX_SCENE: String = "res://systems/vision/sandbox/vision_sandbox.tscn"


func test_the_sandbox_switches_views_and_cleans_up() -> void:
	var sandbox: Node2D = (load(SANDBOX_SCENE) as PackedScene).instantiate()
	add_child(sandbox)
	await wait_frames(2)

	var vision: VisionSystem = sandbox.call(&"get_vision")
	assert_eq(vision.role, GameEnums.Role.SHEEPHERDER)
	assert_is(vision.viewer, Sheepherder)
	assert_eq(Services.swarm.get_living_count(), Services.config.flock_size)

	sandbox.call(&"set_role", GameEnums.Role.MONSTER)
	assert_eq(vision.role, GameEnums.Role.MONSTER)
	assert_is(vision.viewer, SheepBody)
	assert_eq(Services.input.get_role(), GameEnums.Role.MONSTER)

	remove_child(sandbox)
	sandbox.free()
	assert_eq(Services.input.get_role(), GameEnums.Role.NONE)
	assert_eq(Services.swarm.get_living_count(), 0, "the flock is gone")
