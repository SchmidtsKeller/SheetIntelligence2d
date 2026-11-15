extends TestCase
## The Monster's night vision (#90): a look over the world, shown on this
## device only while its player is the Monster, below the HUD, the touch
## controls and the banners.

# Aliases for enum types, so they are named like types.
# gdlint: ignore=constant-name
const Role = GameEnums.Role

const ROUND_SCENE: String = "res://ui/screens/round_screen.tscn"

var _flow: MatchFlow
var _session: GameSession
var _screen: Node2D
var _time: float = 0.0
var _player: StubInputService
var _original_input: Node


func before_each() -> void:
	_session = Services.session
	_flow = Services.match_flow
	if _session.is_active():
		_session.leave()
	var scene_flow: SceneFlowController = add_child_autofree(SceneFlowController.new())
	scene_flow.scene_changer = func(_path: String) -> Error: return OK
	_session.scene_flow = scene_flow
	_time = 50.0
	_flow.clock = func() -> float: return _time
	RoundStage.bots_enabled = false
	_player = StubInputService.new()
	_original_input = Services.replace(InputService, _player)


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	_session.leave()
	_session.scene_flow = null
	_flow.clock = MatchFlow.system_clock
	_flow.first_host_role = Role.NONE
	RoundStage.bots_enabled = true
	Services.replace(InputService, _original_input)
	_player.free()
	await wait_frames(2)


# --- Who has it ------------------------------------------------------------------


func test_only_the_monster_sees_through_night_vision() -> void:
	var vision: VisionSystem = add_child_autofree(VisionSystem.new())

	assert_false(vision.get_night_vision().visible, "without a role")
	vision.role = Role.SHEEPHERDER
	assert_false(vision.get_night_vision().visible, "the Sheepherder")
	assert_true(_darkness(vision).visible, "the Sheepherder keeps their darkness")
	vision.role = Role.MONSTER
	assert_true(vision.get_night_vision().visible, "the Monster")
	assert_false(_darkness(vision).visible, "the Monster has no darkness")


func test_in_a_round_the_monster_has_night_vision() -> void:
	await _play_as(Role.MONSTER)

	assert_true(_night_vision().visible)


func test_in_a_round_the_sheepherder_has_none() -> void:
	await _play_as(Role.SHEEPHERDER)

	assert_false(_night_vision().visible)


func test_it_follows_when_the_roles_swap() -> void:
	await _play_as(Role.MONSTER)

	_session.assign_roles(Role.SHEEPHERDER)
	await wait_frames(1)
	assert_false(_night_vision().visible, "now the Sheepherder")

	_session.assign_roles(Role.MONSTER)
	await wait_frames(1)
	assert_true(_night_vision().visible, "the Monster again")


# --- What it covers --------------------------------------------------------------


func test_the_hud_touch_controls_and_banners_stay_unfiltered() -> void:
	await _play_as(Role.MONSTER)
	var night_vision: NightVision = _night_vision()
	var overlay: CanvasLayer = _screen.get_node(^"Overlay")
	var touch: TouchControls = TouchControls.new()

	assert_gt(_hud().layer, night_vision.layer, "the HUD is drawn above it")
	assert_gt(overlay.layer, night_vision.layer, "the status and the banners too")
	assert_gt(touch.layer, night_vision.layer, "the touch controls too")
	touch.free()


func test_touches_go_through_it() -> void:
	await _play_as(Role.MONSTER)

	var filter: ColorRect = _night_vision().get_node(^"Filter")
	assert_eq(filter.mouse_filter, Control.MOUSE_FILTER_IGNORE)


# --- Spider form -----------------------------------------------------------------


func test_the_spider_sees_it_a_little_stronger() -> void:
	await _play_as(Role.MONSTER)
	var night_vision: NightVision = _night_vision()
	assert_almost_eq(night_vision.get_strength(), night_vision.intensity, 0.001, "as a sheep")

	Services.combat.monster_form_changed.emit(GameEnums.MonsterForm.SPIDER)
	await wait_frames(2)
	assert_true(night_vision.spider)
	assert_gt(night_vision.get_strength(), night_vision.intensity, "it grows stronger")

	var frames: int = 0
	while not is_equal_approx(night_vision.get_strength(), night_vision.spider_intensity):
		await wait_frames(1)
		frames += 1
		if frames > 600:
			break
	assert_almost_eq(night_vision.get_strength(), night_vision.spider_intensity, 0.001)
	assert_gt(night_vision.spider_intensity, night_vision.intensity)


# --- Helpers ---------------------------------------------------------------------


func _play_as(role: Role) -> void:
	_flow.first_host_role = role
	_screen = (load(ROUND_SCENE) as PackedScene).instantiate()
	add_child(_screen)
	await wait_frames(3)


func _night_vision() -> NightVision:
	var stage: RoundStage = _screen.call(&"get_stage")
	return stage.get_vision().get_night_vision()


func _hud() -> Hud:
	return _screen.call(&"get_hud")


func _darkness(vision: VisionSystem) -> CanvasModulate:
	return vision.get_node(^"Darkness")
