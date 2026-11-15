extends TestCase
## The firearm: the host decides every shot and both devices agree (GDD §3.1).

const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")

var _pair: SessionPair
var _host: SessionCombatService
var _guest: SessionCombatService
var _swarm: SandboxSwarmService
var _sheepherder: Node2D
var _audio: StubAudioService
var _original_audio: Node


func before_each() -> void:
	_audio = StubAudioService.new(Services.config)
	_original_audio = Services.replace(AudioService, _audio)
	_pair = SessionPair.create(self)
	_pair.connect_both()
	_swarm = autofree(SandboxSwarmService.new())
	_host = _combat(_pair.host)
	_guest = _combat(_pair.guest)
	_sheepherder = add_child_autofree(Node2D.new())
	_host.begin_round(_sheepherder, null)
	_guest.begin_round(_sheepherder, null)


func after_each() -> void:
	Services.replace(AudioService, _original_audio)
	_audio.free()


# --- Magazine and reload ---------------------------------------------------------


func test_a_round_starts_with_a_full_magazine() -> void:
	for combat: SessionCombatService in [_host, _guest]:
		assert_eq(combat.get_ammo(), 3)
		assert_eq(combat.get_ammo_capacity(), 3)
		assert_true(combat.can_shoot())
		assert_false(combat.is_reloading())
		assert_eq(combat.get_reload_progress(), 1.0)
		assert_false(combat.is_ammo_depleted())
		assert_true(combat.is_monster_killable())


func test_the_host_decides_a_guest_shot_and_both_devices_agree() -> void:
	watch_signals(_host)
	watch_signals(_guest)

	assert_true(_guest.request_shot(Vector2.ZERO, Vector2.RIGHT))

	var expected: Array = [
		Vector2.ZERO,
		Vector2(SessionCombatService.MAX_SHOT_DISTANCE, 0.0),
		CombatService.ShotResult.MISSED
	]
	for combat: SessionCombatService in [_host, _guest]:
		assert_signal_emitted_with(combat, &"shot_fired", expected)
		assert_signal_emitted_with(combat, &"reload_started", [4.0])
		assert_eq(combat.get_ammo(), 2)
		assert_true(combat.is_reloading())
		assert_false(combat.can_shoot())
	assert_eq(_events(AudioEvents.GUNSHOT).size(), 2, "the gunshot is heard on both devices")


func test_the_firearm_reloads_after_each_shot() -> void:
	watch_signals(_host)
	_host.request_shot(Vector2.ZERO, Vector2.RIGHT)

	_host.advance(3.9)
	assert_true(_host.is_reloading())
	assert_almost_eq(_host.get_reload_progress(), 3.9 / 4.0)
	assert_false(_host.request_shot(Vector2.ZERO, Vector2.RIGHT), "no shot while reloading")

	_host.advance(0.2)
	assert_false(_host.is_reloading())
	assert_true(_host.can_shoot())
	assert_signal_emit_count(_host, &"reload_finished", 1)
	assert_eq(_events(AudioEvents.RELOAD_CLICK), [], "the Sheepherder plays the click (#10)")


func test_the_last_bullet_empties_the_firearm_for_good() -> void:
	watch_signals(_host)
	watch_signals(_guest)

	for _shot: int in 3:
		assert_true(_host.request_shot(Vector2.ZERO, Vector2.RIGHT))
		_host.advance(5.0)
		_guest.advance(5.0)

	for combat: SessionCombatService in [_host, _guest]:
		assert_eq(combat.get_ammo(), 0)
		assert_true(combat.is_ammo_depleted())
		assert_false(combat.is_reloading(), "no reload after the last bullet")
		assert_false(combat.can_shoot())
		assert_false(combat.is_monster_killable())
		assert_signal_emit_count(combat, &"ammo_depleted", 1)
		assert_signal_emit_count(combat, &"reload_started", 2)
	assert_false(_host.request_shot(Vector2.ZERO, Vector2.RIGHT))


func test_the_magazine_follows_the_ammo_stat() -> void:
	var config: GameConfig = GameConfig.new()
	config.firearm_ammo = config.perk_spare_bullet_ammo
	var perks: StubPerkService = StubPerkService.new(config)
	var original_perks: Node = Services.replace(PerkService, perks)

	_host.begin_round(_sheepherder, null)

	assert_eq(_host.get_ammo_capacity(), 4)
	Services.replace(PerkService, original_perks)
	perks.free()


func test_no_shot_outside_a_round() -> void:
	var fresh: SessionCombatService = _combat(_pair.host)

	assert_false(fresh.request_shot(Vector2.ZERO, Vector2.RIGHT), "before the round")
	_host.end_round()
	assert_false(_host.request_shot(Vector2.ZERO, Vector2.RIGHT), "after the round")


func test_only_the_host_announces_shots() -> void:
	expect_error("only the host may send")

	var sent: bool = _pair.guest.messenger.broadcast(
		SessionCombatService.EVENT_SHOT, [Vector2.ZERO, Vector2.ONE, 0, -1, 0, 4.0]
	)

	assert_false(sent)
	assert_eq(_host.get_ammo(), 3)
	assert_eq(_guest.get_ammo(), 3)


# --- Where a bullet ends ---------------------------------------------------------


func test_a_bullet_kills_the_first_sheep_on_its_way() -> void:
	var first: SheepBody = _sheep(Vector2(200.0, 0.0))
	var second: SheepBody = _sheep(Vector2(300.0, 0.0))
	watch_signals(_host)
	watch_signals(_guest)
	await get_tree().physics_frame

	_guest.request_shot(Vector2.ZERO, Vector2.RIGHT)

	for combat: SessionCombatService in [_host, _guest]:
		var shot: Array = get_signal_arguments(combat, &"shot_fired")
		assert_eq(shot[2], CombatService.ShotResult.HIT_SHEEP)
		assert_lt((shot[1] as Vector2).x, 200.0, "the bullet stops at the first sheep's edge")
		assert_signal_emitted_with(combat, &"sheep_killed", [0, GameEnums.DeathCause.SHOT, shot[1]])
		assert_signal_emitted_with(combat, &"blood_spilled", [shot[1]])
		assert_eq(combat.get_shot_sheep_count(), 1)
	assert_eq(first.get_state(), SheepBody.State.CORPSE)
	assert_true(second.is_alive())


func test_a_body_on_the_ground_does_not_stop_a_bullet() -> void:
	_sheep(Vector2(200.0, 0.0))
	_sheep(Vector2(300.0, 0.0))
	_swarm.kill_sheep(0, GameEnums.DeathCause.SHOT)
	watch_signals(_host)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_host.request_shot(Vector2.ZERO, Vector2.RIGHT)

	assert_signal_emitted_with(
		_host,
		&"sheep_killed",
		[1, GameEnums.DeathCause.SHOT, get_signal_arguments(_host, &"shot_fired")[1]]
	)


func test_a_bullet_hits_the_monster() -> void:
	var monster: Node2D = _sheep_like(Vector2(200.0, 0.0))
	_host.begin_round(_sheepherder, monster)
	_guest.begin_round(_sheepherder, monster)
	watch_signals(_host)
	watch_signals(_guest)
	await get_tree().physics_frame

	_guest.request_shot(Vector2.ZERO, Vector2.RIGHT)

	for combat: SessionCombatService in [_host, _guest]:
		var shot: Array = get_signal_arguments(combat, &"shot_fired")
		assert_eq(shot[2], CombatService.ShotResult.HIT_MONSTER)
		assert_signal_emitted_with(combat, &"monster_shot", [shot[1]])
		assert_signal_not_emitted(combat, &"sheep_killed")


func test_an_obstacle_stops_the_bullet() -> void:
	var obstacle: StaticBody2D = _wall(Rect2(100.0, -50.0, 50.0, 100.0))
	obstacle.add_to_group(Groups.OBSTACLES)
	var sheep: SheepBody = _sheep(Vector2(300.0, 0.0))
	watch_signals(_host)
	await get_tree().physics_frame

	_host.request_shot(Vector2.ZERO, Vector2.RIGHT)

	var shot: Array = get_signal_arguments(_host, &"shot_fired")
	assert_eq(shot[2], CombatService.ShotResult.HIT_OBSTACLE)
	assert_almost_eq(shot[1], Vector2(100.0, 0.0), 0.5)
	assert_true(sheep.is_alive())
	assert_eq(_host.get_ammo(), 2, "a bullet in a tree is still gone")


func test_a_bullet_that_reaches_a_border_has_left_the_map() -> void:
	_wall(Rect2(500.0, -500.0, 40.0, 1000.0))
	watch_signals(_host)
	await get_tree().physics_frame

	_host.request_shot(Vector2.ZERO, Vector2.RIGHT)

	var shot: Array = get_signal_arguments(_host, &"shot_fired")
	assert_eq(shot[2], CombatService.ShotResult.MISSED)
	assert_almost_eq(shot[1], Vector2(500.0, 0.0), 0.5)


# --- Helpers ---------------------------------------------------------------------


func _combat(session: GameSession) -> SessionCombatService:
	var combat: SessionCombatService = SessionCombatService.new()
	combat.session = session
	combat.swarm = _swarm
	add_child_autofree(combat)
	return combat


func _sheep(at: Vector2) -> SheepBody:
	var sheep: SheepBody = SHEEP_SCENE.instantiate()
	sheep.position = at
	add_child_autofree(sheep)
	_swarm.add_sheep(sheep)
	return sheep


## A minimal sheep-like target: a hit area in the sheep-like group.
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


func _wall(rect: Rect2) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child_autofree(body)
	return body


func _events(event_id: StringName) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for entry: Dictionary in _audio.played:
		if entry["event"] == event_id:
			positions.append(entry["position"])
	return positions
