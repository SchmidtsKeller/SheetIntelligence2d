extends TestCase
## The Monster's attack and evolution: the host decides every attack and both
## devices agree (GDD §2.1, §2.2, §3.2).

const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")
const MONSTER_AT: Vector2 = Vector2(500.0, 500.0)
const EAT_SHEEP: CombatService.EatTarget = CombatService.EatTarget.SHEEP
const EAT_BODY: CombatService.EatTarget = CombatService.EatTarget.SHEEP_BODY
const EAT_HERDER: CombatService.EatTarget = CombatService.EatTarget.SHEEPHERDER

var _pair: SessionPair
var _host: SessionCombatService
var _guest: SessionCombatService
var _swarm: SandboxSwarmService
var _sheepherder: Node2D
var _monster: Node2D
var _audio: StubAudioService
var _original_audio: Node
var _last_sheep: SheepBody


func before_each() -> void:
	_audio = StubAudioService.new(Services.config)
	_original_audio = Services.replace(AudioService, _audio)
	_pair = SessionPair.create(self)
	_pair.connect_both()
	_swarm = autofree(SandboxSwarmService.new())
	_host = _combat(_pair.host)
	_guest = _combat(_pair.guest)
	_sheepherder = add_child_autofree(Node2D.new())
	_sheepherder.position = Vector2(-2000.0, 0.0)
	_monster = _sheep_like(MONSTER_AT)
	_host.begin_round(_sheepherder, _monster)
	_guest.begin_round(_sheepherder, _monster)


func after_each() -> void:
	Services.replace(AudioService, _original_audio)
	_audio.free()


# --- Range -----------------------------------------------------------------------


func test_a_round_starts_with_a_hungry_sheep() -> void:
	for combat: SessionCombatService in [_host, _guest]:
		assert_eq(combat.get_eaten_count(), 0)
		assert_eq(combat.get_eaten_alive_count(), 0)
		assert_eq(combat.get_monster_form(), GameEnums.MonsterForm.SHEEP)
		assert_false(combat.is_eating())
		assert_eq(combat.get_eat_cooldown_remaining(), 0.0)
		assert_false(combat.can_kill_sheepherder())
		assert_false(combat.can_eat(), "nothing is in range")
		assert_false(combat.request_eat())


func test_a_sheep_can_be_eaten_from_48_pixels() -> void:
	assert_eq(Services.config.melee_range, 48.0)
	var sheep: SheepBody = _sheep(MONSTER_AT + Vector2(48.5, 0.0))

	assert_false(_host.can_eat(), "just out of reach")
	assert_false(_host.request_eat())

	sheep.position = MONSTER_AT + Vector2(48.0, 0.0)
	assert_true(_host.can_eat(), "center to center")


func test_the_nearest_sheep_is_eaten() -> void:
	var far: SheepBody = _sheep(MONSTER_AT + Vector2(45.0, 0.0))
	var near: SheepBody = _sheep(MONSTER_AT + Vector2(0.0, 36.0))

	_host.request_eat()

	assert_true(far.is_alive())
	assert_eq(near.get_state(), SheepBody.State.EATEN)


# --- One attack ------------------------------------------------------------------


func test_the_host_decides_a_guest_attack_and_both_devices_agree() -> void:
	var at: Vector2 = MONSTER_AT + Vector2(40.0, 0.0)
	var sheep: SheepBody = _sheep(at)
	watch_signals(_host)
	watch_signals(_guest)

	assert_true(_guest.request_eat())

	assert_eq(sheep.get_state(), SheepBody.State.EATEN)
	for combat: SessionCombatService in [_host, _guest]:
		assert_signal_emitted_with(combat, &"eat_started", [EAT_SHEEP, 0, 1.0])
		assert_signal_emitted_with(combat, &"sheep_killed", [0, GameEnums.DeathCause.EATEN, at])
		assert_signal_emitted_with(combat, &"blood_spilled", [at])
		assert_signal_emitted_with(combat, &"eaten_count_changed", [1])
		assert_true(combat.is_eating())
		assert_eq(combat.get_eaten_count(), 1)
		assert_eq(combat.get_eaten_alive_count(), 1)
	assert_eq(_events(AudioEvents.EAT), [MONSTER_AT, MONSTER_AT], "heard on both devices")


func test_eating_locks_for_one_second_then_cools_down_for_five() -> void:
	_sheep(MONSTER_AT + Vector2(36.0, 0.0))
	_sheep(MONSTER_AT + Vector2(-40.0, 0.0))
	watch_signals(_host)
	_host.request_eat()

	_host.advance(0.9)
	assert_true(_host.is_eating())
	assert_false(_host.request_eat(), "no second attack while eating")
	assert_signal_not_emitted(_host, &"eat_finished")

	_host.advance(0.2)
	assert_false(_host.is_eating())
	assert_signal_emitted_with(_host, &"eat_finished", [EAT_SHEEP, 0, 5.0])
	assert_almost_eq(_host.get_eat_cooldown_remaining(), 4.9, 0.001, "starts when eating ends")
	assert_false(_host.can_eat(), "cooling down")

	_host.advance(4.8)
	assert_false(_host.request_eat())

	_host.advance(0.2)
	assert_eq(_host.get_eat_cooldown_remaining(), 0.0)
	assert_true(_host.request_eat())
	assert_eq(_host.get_eaten_count(), 2)


func test_the_eating_time_follows_the_stat() -> void:
	var config: GameConfig = GameConfig.new()
	config.eat_duration = config.perk_faster_consumption_duration
	var perks: StubPerkService = StubPerkService.new(config)
	var original_perks: Node = Services.replace(PerkService, perks)
	_sheep(MONSTER_AT + Vector2(40.0, 0.0))
	watch_signals(_guest)

	_host.request_eat()

	assert_signal_emitted_with(_guest, &"eat_started", [EAT_SHEEP, 0, 0.5])
	Services.replace(PerkService, original_perks)
	perks.free()


func test_a_blocker_forbids_eating() -> void:
	_sheep(MONSTER_AT + Vector2(40.0, 0.0))
	_host.add_eat_blocker(&"invisible")

	assert_false(_host.can_eat())
	assert_true(_guest.request_eat(), "the guest asks")
	assert_eq(_host.get_eaten_count(), 0, "and the host says no")

	_host.remove_eat_blocker(&"invisible")
	assert_true(_host.request_eat())


func test_no_attack_outside_a_round() -> void:
	_sheep(MONSTER_AT + Vector2(40.0, 0.0))
	var fresh: SessionCombatService = _combat(_pair.host)

	assert_false(fresh.request_eat(), "before the round")
	_host.end_round()
	assert_false(_host.request_eat(), "after the round")


func test_only_the_host_announces_attacks() -> void:
	expect_error("only the host may send")

	var sent: bool = _pair.guest.messenger.broadcast(
		SessionCombatService.EVENT_EAT, [EAT_SHEEP, 0, Vector2.ZERO, Vector2.ZERO, 1.0, 5.0]
	)

	assert_false(sent)
	assert_eq(_host.get_eaten_count(), 0)
	assert_eq(_guest.get_eaten_count(), 0)


func test_a_monster_on_the_other_device_may_be_a_step_behind() -> void:
	# The guest sees the sheep a moment in the past (0.1 s, 18 px at sheep
	# speed). The host allows for that; for its own Monster it does not.
	_sheep(MONSTER_AT + Vector2(60.0, 0.0))
	var request: Array = [MONSTER_AT]

	_pair.host.messenger.send_to_host(SessionCombatService.EVENT_EAT_REQUEST, request)
	assert_eq(_host.get_eaten_count(), 0, "out of reach for a Monster on the host")

	_pair.guest.messenger.send_to_host(SessionCombatService.EVENT_EAT_REQUEST, request)
	assert_eq(_host.get_eaten_count(), 1)


func test_the_allowance_ends_where_a_sheep_cannot_have_come_from() -> void:
	_sheep(MONSTER_AT + Vector2(70.0, 0.0))

	_pair.guest.messenger.send_to_host(SessionCombatService.EVENT_EAT_REQUEST, [MONSTER_AT])

	assert_eq(_host.get_eaten_count(), 0)


# --- Counting: eaten against shot ------------------------------------------------


func test_a_shot_sheep_does_not_count() -> void:
	_sheep(Vector2(200.0, 0.0))
	await get_tree().physics_frame

	_host.request_shot(Vector2.ZERO, Vector2.RIGHT)

	assert_eq(_host.get_shot_sheep_count(), 1)
	assert_eq(_host.get_eaten_count(), 0)
	assert_eq(_guest.get_eaten_count(), 0)


func test_the_body_of_a_shot_sheep_can_be_eaten() -> void:
	var sheep: SheepBody = _sheep(MONSTER_AT + Vector2(40.0, 0.0))
	_swarm.kill_sheep(0, GameEnums.DeathCause.SHOT)
	watch_signals(_host)
	watch_signals(_guest)

	assert_true(_host.can_eat())
	_guest.request_eat()

	assert_eq(sheep.get_state(), SheepBody.State.EATEN, "the body is gone")
	for combat: SessionCombatService in [_host, _guest]:
		assert_signal_emitted_with(combat, &"eat_started", [EAT_BODY, 0, 1.0])
		assert_signal_not_emitted(combat, &"sheep_killed", "it was dead already")
		assert_signal_not_emitted(combat, &"blood_spilled", "its blood is there since the shot")
		assert_eq(combat.get_eaten_count(), 1, "it counts toward the evolution")
		assert_eq(combat.get_eaten_alive_count(), 0, "but gives no points")


func test_a_living_sheep_and_a_body_are_equally_near_targets() -> void:
	_sheep(MONSTER_AT + Vector2(45.0, 0.0))
	var body: SheepBody = _sheep(MONSTER_AT + Vector2(0.0, 36.0))
	_swarm.kill_sheep(1, GameEnums.DeathCause.SHOT)

	_host.request_eat()

	assert_eq(body.get_state(), SheepBody.State.EATEN, "the nearer one, alive or not")


func test_an_eaten_sheep_cannot_be_eaten_again() -> void:
	_sheep(MONSTER_AT + Vector2(40.0, 0.0))
	_eat_what_is_near()

	assert_false(_host.can_eat())
	assert_eq(_host.get_eaten_count(), 1)


# --- Phase 1: the kill on the Sheepherder ----------------------------------------


func test_before_five_sheep_the_attack_does_nothing_to_the_sheepherder() -> void:
	_eat_sheep(4)
	_sheepherder.position = MONSTER_AT + Vector2(40.0, 0.0)
	watch_signals(_host)

	assert_false(_host.can_kill_sheepherder())
	assert_false(_host.can_eat())
	assert_false(_host.request_eat())
	assert_signal_not_emitted(_host, &"sheepherder_killed")


func test_the_fifth_sheep_unlocks_the_kill() -> void:
	watch_signals(_host)
	watch_signals(_guest)

	_eat_sheep(4)
	assert_signal_not_emitted(_host, &"sheepherder_kill_unlocked")

	_eat_sheep(2)
	for combat: SessionCombatService in [_host, _guest]:
		assert_signal_emit_count(combat, &"sheepherder_kill_unlocked", 1)
		assert_true(combat.can_kill_sheepherder())


func test_one_attack_kills_the_sheepherder() -> void:
	_eat_sheep(5)
	var at: Vector2 = MONSTER_AT + Vector2(0.0, 48.0)
	_sheepherder.position = at
	watch_signals(_host)
	watch_signals(_guest)

	assert_true(_guest.request_eat())

	for combat: SessionCombatService in [_host, _guest]:
		assert_signal_emitted_with(combat, &"eat_started", [EAT_HERDER, -1, 1.0])
		assert_signal_emitted_with(combat, &"sheepherder_killed", [at])
		assert_true(combat.is_eating(), "the eating animation still plays")
		assert_false(combat.can_shoot(), "the Sheepherder cannot shoot back")
		assert_false(combat.request_shot(at, Vector2.UP))
		assert_eq(combat.get_eaten_count(), 5, "the Sheepherder is no sheep")


func test_the_sheepherder_is_taken_before_a_sheep() -> void:
	_eat_sheep(5)
	var sheep: SheepBody = _sheep(MONSTER_AT + Vector2(36.0, 0.0))
	_sheepherder.position = MONSTER_AT + Vector2(0.0, 45.0)
	watch_signals(_host)

	_host.request_eat()

	assert_signal_emitted(_host, &"sheepherder_killed")
	assert_true(sheep.is_alive())


func test_a_dead_sheepherder_is_not_attacked_again() -> void:
	_eat_sheep(5)
	_sheepherder.position = MONSTER_AT + Vector2(0.0, 45.0)
	_eat_what_is_near()
	watch_signals(_host)

	assert_false(_host.can_eat())
	assert_signal_not_emitted(_host, &"sheepherder_killed")


func test_the_sheepherder_out_of_reach_is_safe() -> void:
	_eat_sheep(5)
	_sheepherder.position = MONSTER_AT + Vector2(0.0, 49.0)

	assert_false(_host.can_eat())


# --- Phase 2: the spider ---------------------------------------------------------


func test_the_tenth_sheep_makes_the_spider() -> void:
	watch_signals(_host)
	watch_signals(_guest)
	_eat_sheep(9)
	_sheep(MONSTER_AT + Vector2(40.0, 0.0))

	_host.request_eat()
	assert_eq(_host.get_monster_form(), GameEnums.MonsterForm.SHEEP, "it is still eating")
	assert_signal_not_emitted(_host, &"monster_form_changed")

	_advance_both(1.0)
	for combat: SessionCombatService in [_host, _guest]:
		assert_signal_emitted_with(combat, &"monster_form_changed", [GameEnums.MonsterForm.SPIDER])
		assert_signal_emit_count(combat, &"monster_form_changed", 1)
		assert_eq(combat.get_monster_form(), GameEnums.MonsterForm.SPIDER)
		assert_false(combat.is_monster_killable())
	assert_eq(_events(AudioEvents.SPIDER_SCREECH), [MONSTER_AT, MONSTER_AT])


func test_eaten_bodies_lead_to_the_spider_too() -> void:
	_eat_sheep(8)
	for offset: float in [40.0, -40.0]:
		_sheep(MONSTER_AT + Vector2(offset, 0.0))
		_swarm.kill_sheep(_swarm.get_sheep_id(_last_sheep), GameEnums.DeathCause.SHOT)
		_eat_what_is_near()

	assert_eq(_host.get_eaten_count(), 10)
	assert_eq(_host.get_eaten_alive_count(), 8)
	assert_eq(_host.get_monster_form(), GameEnums.MonsterForm.SPIDER)


func test_bullets_do_nothing_to_the_spider() -> void:
	_eat_sheep(10)
	await get_tree().physics_frame
	watch_signals(_host)
	watch_signals(_guest)

	_host.request_shot(MONSTER_AT - Vector2(300.0, 0.0), Vector2.RIGHT)

	for combat: SessionCombatService in [_host, _guest]:
		var shot: Array = get_signal_arguments(combat, &"shot_fired")
		assert_eq(shot[2], CombatService.ShotResult.HIT_SPIDER)
		assert_signal_not_emitted(combat, &"monster_shot")
		assert_eq(combat.get_ammo(), 2, "the bullet is gone all the same")
	_advance_both(Services.config.eat_cooldown)
	_sheepherder.position = MONSTER_AT + Vector2(0.0, 40.0)
	assert_true(_host.can_eat(), "and the spider hunts on")


func test_the_spider_keeps_the_eating_rules() -> void:
	_eat_sheep(10)
	_sheepherder.position = MONSTER_AT + Vector2(0.0, 40.0)
	watch_signals(_host)

	assert_true(_host.request_eat())

	assert_signal_emitted_with(_host, &"eat_started", [EAT_HERDER, -1, 1.0])


# --- The firearm against the Monster ---------------------------------------------


func test_a_shot_monster_eats_no_more() -> void:
	_sheep(MONSTER_AT + Vector2(0.0, 40.0))
	await get_tree().physics_frame
	watch_signals(_guest)

	_host.request_shot(MONSTER_AT - Vector2(300.0, 0.0), Vector2.RIGHT)

	assert_signal_emitted(_guest, &"monster_shot")
	for combat: SessionCombatService in [_host, _guest]:
		assert_false(combat.can_eat())
		assert_false(combat.request_eat())


func test_a_shot_ends_the_meal() -> void:
	_sheep(MONSTER_AT + Vector2(0.0, 40.0))
	await get_tree().physics_frame
	_host.request_eat()
	watch_signals(_host)

	_host.request_shot(MONSTER_AT - Vector2(300.0, 0.0), Vector2.RIGHT)
	_advance_both(2.0)

	assert_false(_host.is_eating())
	assert_signal_not_emitted(_host, &"eat_finished")


func test_an_empty_firearm_protects_the_monster_but_does_not_arm_it() -> void:
	for shot: int in 3:
		_host.request_shot(Vector2.ZERO, Vector2.UP)
		_advance_both(Services.config.firearm_reload_time)
	_sheepherder.position = MONSTER_AT + Vector2(0.0, 40.0)

	for combat: SessionCombatService in [_host, _guest]:
		assert_true(combat.is_ammo_depleted())
		assert_false(combat.is_monster_killable())
		assert_false(combat.can_kill_sheepherder(), "that still takes five sheep")
		assert_false(combat.can_eat())


# --- Unleashed (#108) ------------------------------------------------------------


func test_an_unleashed_monster_is_the_spider_and_may_kill_at_once() -> void:
	watch_signals(_host)
	watch_signals(_guest)

	_host.unleash_monster()

	for combat: SessionCombatService in [_host, _guest]:
		assert_eq(combat.get_eaten_count(), 0)
		assert_eq(combat.get_monster_form(), GameEnums.MonsterForm.SPIDER)
		assert_true(combat.can_kill_sheepherder())
		assert_false(combat.is_monster_killable())
		assert_signal_emit_count(combat, &"sheepherder_kill_unlocked", 1)
		assert_signal_emitted_with(combat, &"monster_form_changed", [GameEnums.MonsterForm.SPIDER])
	assert_eq(_events(AudioEvents.SPIDER_SCREECH), [MONSTER_AT, MONSTER_AT])
	_sheepherder.position = MONSTER_AT + Vector2(0.0, 40.0)
	assert_true(_host.request_eat())
	assert_signal_emitted_with(_host, &"eat_started", [EAT_HERDER, -1, 1.0])


func test_only_the_host_unleashes_the_monster() -> void:
	_guest.unleash_monster()

	for combat: SessionCombatService in [_host, _guest]:
		assert_eq(combat.get_monster_form(), GameEnums.MonsterForm.SHEEP)
		assert_false(combat.can_kill_sheepherder())


func test_unleashed_during_a_meal_the_spider_comes_after_it() -> void:
	_sheep(MONSTER_AT + Vector2(40.0, 0.0))
	_host.request_eat()

	_host.unleash_monster()

	assert_eq(_host.get_monster_form(), GameEnums.MonsterForm.SHEEP, "it is still eating")
	assert_true(_host.can_kill_sheepherder())
	_advance_both(Services.config.eat_duration)
	for combat: SessionCombatService in [_host, _guest]:
		assert_eq(combat.get_monster_form(), GameEnums.MonsterForm.SPIDER)


func test_an_unleashed_monster_with_the_kill_unlocked_unlocks_it_only_once() -> void:
	_eat_sheep(5)
	watch_signals(_host)

	_host.unleash_monster()
	_host.unleash_monster()

	assert_signal_not_emitted(_host, &"sheepherder_kill_unlocked")
	assert_signal_emit_count(_host, &"monster_form_changed", 1)


func test_a_shot_monster_is_not_unleashed() -> void:
	await get_tree().physics_frame
	_host.request_shot(MONSTER_AT - Vector2(300.0, 0.0), Vector2.RIGHT)

	_host.unleash_monster()

	assert_eq(_host.get_monster_form(), GameEnums.MonsterForm.SHEEP)
	assert_false(_host.can_kill_sheepherder())


# --- Rounds ----------------------------------------------------------------------


func test_a_new_round_starts_from_nothing() -> void:
	_eat_sheep(10)
	watch_signals(_host)

	_host.unleash_monster()
	_host.begin_round(_sheepherder, _monster)

	assert_signal_emitted_with(_host, &"monster_form_changed", [GameEnums.MonsterForm.SHEEP])
	assert_signal_emitted_with(_host, &"eaten_count_changed", [0])
	assert_eq(_host.get_eaten_count(), 0)
	assert_eq(_host.get_eaten_alive_count(), 0)
	assert_eq(_host.get_eat_cooldown_remaining(), 0.0)
	assert_false(_host.can_kill_sheepherder())
	assert_true(_host.is_monster_killable())


# --- Helpers ---------------------------------------------------------------------


func _combat(session: GameSession) -> SessionCombatService:
	var combat: SessionCombatService = SessionCombatService.new()
	combat.session = session
	combat.swarm = _swarm
	add_child_autofree(combat)
	# Time moves only when a test says so.
	combat.set_process(false)
	return combat


func _sheep(at: Vector2) -> SheepBody:
	_last_sheep = SHEEP_SCENE.instantiate()
	_last_sheep.position = at
	add_child_autofree(_last_sheep)
	_swarm.add_sheep(_last_sheep)
	return _last_sheep


## Lets the Monster eat [param count] sheep, one after the other, each with
## its animation and cooldown.
func _eat_sheep(count: int) -> void:
	for index: int in count:
		_sheep(MONSTER_AT + Vector2(40.0, 0.0))
		_eat_what_is_near()


func _eat_what_is_near() -> void:
	assert_true(_host.request_eat(), "there is something to eat")
	_advance_both(Services.config.eat_duration + Services.config.eat_cooldown)


func _advance_both(seconds: float) -> void:
	_host.advance(seconds)
	_guest.advance(seconds)


## A minimal Monster: a hit area in the sheep-like group.
func _sheep_like(at: Vector2) -> Node2D:
	var target: Node2D = Node2D.new()
	target.position = at
	target.add_to_group(Groups.SHEEP_LIKE)
	var area: Area2D = Area2D.new()
	area.collision_layer = PhysicsLayers.HITBOX
	area.collision_mask = 0
	area.monitoring = false
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 16.0
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	area.add_child(collision)
	target.add_child(area)
	add_child_autofree(target)
	return target


func _events(event_id: StringName) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for entry: Dictionary in _audio.played:
		if entry["event"] == event_id:
			positions.append(entry["position"])
	return positions
