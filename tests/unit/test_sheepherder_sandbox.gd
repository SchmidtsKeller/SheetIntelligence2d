extends TestCase
## The Sheepherder sandbox starts a round and leaves the services as it found
## them.

const SANDBOX_SCENE: String = "res://entities/sheepherder/sandbox/sheepherder_sandbox.tscn"


func test_the_sandbox_starts_a_round_and_cleans_up() -> void:
	var original_swarm: SwarmService = Services.swarm
	var sandbox: Node2D = (load(SANDBOX_SCENE) as PackedScene).instantiate()
	add_child(sandbox)
	await wait_frames(2)

	var herder: Sheepherder = sandbox.call(&"get_sheepherder")
	var swarm: SandboxSwarmService = sandbox.call(&"get_swarm")
	assert_true(herder.controlled_locally)
	assert_eq(Services.swarm, swarm)
	assert_eq(swarm.get_living_count(), Services.config.flock_size + 1)
	assert_eq(Services.combat.get_ammo(), Services.combat.get_ammo_capacity())
	assert_eq(Services.input.get_role(), GameEnums.Role.SHEEPHERDER)

	remove_child(sandbox)
	sandbox.free()

	assert_eq(Services.swarm, original_swarm)
	assert_eq(Services.input.get_role(), GameEnums.Role.NONE)
	assert_false(Services.combat.can_shoot(), "the round ended")
