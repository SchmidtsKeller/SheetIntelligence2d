extends TestCase
## The arena sandbox shows a round's spawn layout.

const SANDBOX_SCENE: String = "res://systems/arena/arena_sandbox.tscn"


func test_the_sandbox_spawns_a_round_on_free_ground() -> void:
	var sandbox: Node2D = add_child_autofree((load(SANDBOX_SCENE) as PackedScene).instantiate())
	await wait_frames(2)

	var arena: Arena = sandbox.call(&"get_arena")
	var sheep: Array[SheepBody] = sandbox.call(&"get_sheep")
	assert_eq(sheep.size(), Services.config.flock_size + 1)
	for body: SheepBody in sheep:
		assert_true(arena.is_free(body.position, arena.spawn_clearance), "%s" % body.position)
		assert_eq(body.get_parent(), arena.get_entities_layer())
