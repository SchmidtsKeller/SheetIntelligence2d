extends TestCase
## The Monster sandbox: a round with the real flock, the real combat rules and
## the Monster among them, on one device.

const SANDBOX_SCENE: String = "res://entities/monster/sandbox/monster_sandbox.tscn"

var _sandbox: Node2D


func before_each() -> void:
	_sandbox = (load(SANDBOX_SCENE) as PackedScene).instantiate()
	add_child(_sandbox)
	await wait_frames(2)


func after_each() -> void:
	if is_instance_valid(_sandbox):
		_sandbox.free()
	await wait_frames(2)


func test_the_sandbox_starts_a_round_with_the_monster_in_the_flock() -> void:
	var monster: Monster = _sandbox.call(&"get_monster")
	var herder: Sheepherder = _sandbox.call(&"get_sheepherder")
	var arena: Arena = _sandbox.call(&"get_arena")
	var vision: VisionSystem = _sandbox.call(&"get_vision")

	assert_true(monster.controlled_locally, "this device plays the Monster")
	assert_false(herder.controlled_locally, "nobody plays the Sheepherder")
	assert_eq(Services.input.get_role(), GameEnums.Role.MONSTER)
	assert_eq(vision.role, GameEnums.Role.MONSTER)
	assert_eq(vision.viewer, monster.get_body())
	assert_eq(Services.swarm.get_living_count(), Services.config.flock_size)
	assert_eq(monster.get_body().get_parent(), arena.get_entities_layer(), "among the sheep")
	assert_true(monster.get_camera().is_current())
	assert_eq(Services.combat.get_eaten_count(), 0)
	assert_true(Services.combat.is_monster_killable())


func test_the_monster_eats_a_sheep_of_the_flock() -> void:
	var monster: Monster = _sandbox.call(&"get_monster")
	var arena: Arena = _sandbox.call(&"get_arena")
	var body: SheepBody = monster.get_body()
	var sheep_id: int = Services.swarm.find_nearest_living_sheep(body.global_position, 100000.0)
	var sheep: SheepBody = Services.swarm.get_sheep_body(sheep_id)
	var at: Vector2 = sheep.global_position
	assert_false(Services.combat.can_eat(), "too far away")

	body.global_position = at + Vector2(40.0, 0.0)
	assert_true(Services.combat.request_eat())

	assert_eq(body.get_state(), SheepBody.State.DEVOUR)
	assert_eq(sheep.get_state(), SheepBody.State.EATEN)
	assert_eq(Services.swarm.get_living_count(), Services.config.flock_size - 1)
	assert_eq(Services.combat.get_eaten_count(), 1)
	var decals: Array[Node] = arena.get_decals_layer().get_children()
	assert_eq(decals.size(), 1, "blood stays on the ground")
	assert_eq((decals[0] as Node2D).global_position, at)


func test_the_dummy_can_shoot_the_monster() -> void:
	var monster: Monster = _sandbox.call(&"get_monster")
	var herder: Sheepherder = _sandbox.call(&"get_sheepherder")
	# A clear line of fire, wherever the round put the two.
	monster.get_body().global_position = herder.global_position + Vector2(0.0, -120.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_true(_sandbox.call(&"shoot_at_monster"))

	assert_eq(monster.get_body().get_state(), SheepBody.State.CORPSE)
	assert_false(Services.combat.can_eat())


func test_a_new_round_starts_from_nothing() -> void:
	var first: Monster = _sandbox.call(&"get_monster")
	var first_id: int = first.entity_id
	var arena: Arena = _sandbox.call(&"get_arena")
	var body: SheepBody = first.get_body()
	var sheep_id: int = Services.swarm.find_nearest_living_sheep(body.global_position, 100000.0)
	body.global_position = Services.swarm.get_sheep_body(sheep_id).global_position
	Services.combat.request_eat()

	_sandbox.call(&"start_new_round")
	await wait_frames(2)

	var second: Monster = _sandbox.call(&"get_monster")
	assert_false(is_instance_valid(first), "the Monster of the last round is gone")
	assert_ne(second.entity_id, first_id)
	assert_true(second.controlled_locally)
	assert_true(second.get_camera().is_current())
	assert_eq(Services.swarm.get_living_count(), Services.config.flock_size)
	assert_eq(Services.combat.get_eaten_count(), 0)
	assert_eq(arena.get_decals_layer().get_child_count(), 0, "the blood of the last round is gone")


func test_the_sandbox_cleans_up() -> void:
	_sandbox.free()

	assert_eq(Services.input.get_role(), GameEnums.Role.NONE)
	assert_eq(Services.swarm.get_living_count(), 0, "the flock is gone")
	assert_false(Services.combat.can_eat(), "the round ended")
	assert_eq(Services.session.entities.get_entity_ids().size(), 0)
