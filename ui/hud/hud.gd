class_name Hud
extends CanvasLayer
## The in-game HUD (GDD §8.2, #21): what the player needs during a round, for
## their role only.
##
## [codeblock lang=text]
## Both:         round timer, short messages
## Sheepherder:  bullets, reload, bell cooldown
## Monster:      evolution bar (kill and spider milestones), living sheep,
##               stamina, Graze / Bleat / Eat / Sprint / Perk with cooldowns
## [/codeblock]
##
## It only displays what the match flow, the combat service, the perk service
## and the round's characters expose, and it contains no gameplay rules. Each
## player sees the elements of the role they play right now; when the roles
## swap, the HUD follows. With the keyboard and mouse the action icons carry
## their key; on a touchscreen the touch buttons themselves show cooldowns and
## meters, and the icons are not drawn twice.

## How long a message stays.
const MESSAGE_TIME: float = 2.5
const EDGE: float = 24.0
const ICON_SIZE: Vector2 = Vector2(76.0, 76.0)
const BAR_SIZE: Vector2 = Vector2(300.0, 40.0)

## Elements and the role that sees them; NONE means both roles.
const HERDER_ELEMENTS: Array[String] = ["Bullets", "Reload", "Shoot", "Bell"]
const MONSTER_ELEMENTS: Array[String] = [
	"Evolution", "SheepCount", "Stamina", "Graze", "Bleat", "Eat", "Sprint", "Perk"
]
## The action icons, which touch buttons replace on a touchscreen.
const ACTION_ICONS: Dictionary[String, StringName] = {
	"Shoot": InputActions.SHOOT,
	"Bell": InputActions.BELL,
	"Graze": InputActions.GRAZE,
	"Bleat": InputActions.BLEAT,
	"Eat": InputActions.EAT,
	"Sprint": InputActions.SPRINT,
	"Perk": InputActions.PERK,
}

var _stage: RoundStage
var _catalog: PerkCatalog = PerkCatalog.load_default()
var _elements: Dictionary[String, Control] = {}
var _timer: GameLabel
var _message: GameLabel
var _message_left: float = 0.0
var _herder_panel: VBoxContainer
var _monster_panel: VBoxContainer
var _actions: HBoxContainer
var _role: GameEnums.Role = GameEnums.Role.NONE
var _perk_cooldown: HudReadout.CooldownTracker = HudReadout.CooldownTracker.new()
var _perk_was_cooling: bool = false


## A HUD for the round on [param stage].
func _init(stage: RoundStage = null) -> void:
	name = "Hud"
	layer = 40
	_stage = stage
	_build()


func _ready() -> void:
	var combat: CombatService = Services.combat
	combat.ammo_depleted.connect(_on_ammo_depleted)
	combat.sheepherder_kill_unlocked.connect(_on_kill_unlocked)
	combat.monster_form_changed.connect(_on_monster_form_changed)
	_refresh()


func _exit_tree() -> void:
	var combat: CombatService = Services.combat
	combat.ammo_depleted.disconnect(_on_ammo_depleted)
	combat.sheepherder_kill_unlocked.disconnect(_on_kill_unlocked)
	combat.monster_form_changed.disconnect(_on_monster_form_changed)


func _process(delta: float) -> void:
	_message_left -= delta
	_message.visible = _message_left > 0.0
	_refresh()


## The element named [param element_name] (see [constant HERDER_ELEMENTS] and
## [constant MONSTER_ELEMENTS], plus "Timer" and "Message"), or
## [code]null[/code].
func get_element(element_name: String) -> Control:
	return _elements.get(element_name)


## Whether [param element_name] is on the screen for this player now.
func shows(element_name: String) -> bool:
	var element: Control = get_element(element_name)
	return element != null and element.is_visible_in_tree()


## The role whose elements are shown.
func get_role() -> GameEnums.Role:
	return _role


## The message on the screen; empty when there is none.
func get_message() -> String:
	return _message.text if _message.visible else ""


## Shows [param text] for a moment.
func show_message(text: String) -> void:
	_message.text = text
	_message_left = MESSAGE_TIME
	_message.visible = true


# --- Reading the game ------------------------------------------------------------


func _refresh() -> void:
	_set_role(Services.session.get_local_role())
	var flow: MatchFlow = Services.match_flow
	_timer.visible = flow.is_match_running()
	_timer.text = HudReadout.format_time(flow.get_round_time_left())
	var touch: bool = Services.input.get_scheme() == InputService.Scheme.TOUCH
	_actions.visible = not touch and _role != GameEnums.Role.NONE
	match _role:
		GameEnums.Role.SHEEPHERDER:
			_refresh_herder()
		GameEnums.Role.MONSTER:
			_refresh_monster()


func _set_role(role: GameEnums.Role) -> void:
	if role == _role:
		return
	_role = role
	var herder: bool = role == GameEnums.Role.SHEEPHERDER
	var monster: bool = role == GameEnums.Role.MONSTER
	_herder_panel.visible = herder
	_monster_panel.visible = monster
	for element_name: String in HERDER_ELEMENTS:
		_elements[element_name].visible = herder
	for element_name: String in MONSTER_ELEMENTS:
		_elements[element_name].visible = monster
	_perk_was_cooling = false


func _refresh_herder() -> void:
	var combat: CombatService = Services.combat
	var bullets: HudGauge = _elements["Bullets"]
	bullets.pips = HudReadout.bullets(combat.get_ammo(), combat.get_ammo_capacity())
	bullets.caption = "%d / %d bullets" % [combat.get_ammo(), combat.get_ammo_capacity()]
	var reload: HudGauge = _elements["Reload"]
	if combat.is_ammo_depleted():
		reload.value = 0.0
		reload.caption = "Out of bullets"
	elif combat.is_reloading():
		reload.value = combat.get_reload_progress()
		reload.caption = "Reloading"
	else:
		reload.value = 1.0
		reload.caption = "Ready to fire"
	var reload_left: float = 1.0 - combat.get_reload_progress() if combat.is_reloading() else 0.0
	_show_action("Shoot", reload_left, 0.0, false, combat.can_shoot())
	var herder: Sheepherder = _stage.get_sheepherder() if _stage != null else null
	var bell_left: float = herder.get_bell_cooldown_remaining() if herder != null else 0.0
	var bell_total: float = Services.perks.get_stat(StatIds.BELL_COOLDOWN)
	var bell_ratio: float = HudReadout.cooldown_ratio(bell_left, bell_total)
	_show_action("Bell", bell_ratio, 0.0, false, bell_ratio <= 0.0)


func _refresh_monster() -> void:
	var combat: CombatService = Services.combat
	var perks: PerkService = Services.perks
	var eaten: int = combat.get_eaten_count()
	var kill_at: int = perks.get_stat_int(StatIds.HERDER_KILL_THRESHOLD)
	var spider_at: int = perks.get_stat_int(StatIds.SPIDER_EVOLUTION_THRESHOLD)
	var living: int = Services.swarm.get_living_count()
	var left: int = HudReadout.sheep_left_to_eat(
		living, combat.get_shot_sheep_count(), eaten, combat.get_eaten_alive_count()
	)
	var reachable: bool = HudReadout.spider_reachable(eaten, left, spider_at)
	var evolution: HudGauge = _elements["Evolution"]
	evolution.value = HudReadout.evolution_progress(eaten, spider_at)
	evolution.marks = [HudReadout.milestone_position(kill_at, spider_at), 1.0]
	evolution.active = combat.can_kill_sheepherder()
	evolution.available = reachable or eaten >= spider_at
	evolution.caption = HudReadout.evolution_text(eaten, kill_at, spider_at, reachable)
	(_elements["SheepCount"] as Label).text = "%d sheep alive" % living

	var monster: Monster = _stage.get_monster() if _stage != null else null
	var spider: bool = combat.get_monster_form() == GameEnums.MonsterForm.SPIDER
	var body: SheepBody = monster.get_body() if monster != null else null
	var stamina: HudGauge = _elements["Stamina"]
	stamina.value = monster.get_stamina_ratio() if monster != null else 0.0
	stamina.active = monster != null and monster.is_sprinting()
	stamina.available = not spider
	stamina.caption = "Stamina"
	_show_action("Sprint", 0.0, stamina.value, stamina.active, not spider)
	var grazing: bool = body != null and body.is_grazing()
	_show_action("Graze", 0.0, 0.0, grazing, not spider)
	_show_action("Bleat", 0.0, 0.0, false, not spider)
	var eat_ratio: float = HudReadout.cooldown_ratio(
		combat.get_eat_cooldown_remaining(), perks.get_stat(StatIds.EAT_COOLDOWN)
	)
	_show_action("Eat", eat_ratio, 0.0, combat.is_eating(), combat.can_eat())
	_refresh_perk(GameEnums.Role.MONSTER)


## The active perk of [param role]: its charge, its cooldown and a message
## when it is ready again.
func _refresh_perk(role: GameEnums.Role) -> void:
	var perks: PerkService = Services.perks
	var definition: PerkDefinition = _catalog.get_perk(perks.get_selected_perk(role))
	var icon: HudGauge = _elements["Perk"]
	var has_active_perk: bool = definition != null and definition.is_triggered()
	icon.visible = has_active_perk
	if not has_active_perk:
		Services.input.show_action_state(InputActions.PERK, 0.0, 0.0, false)
		return
	icon.caption = definition.display_name
	var cooldown: float = _perk_cooldown.ratio(perks.get_perk_cooldown_remaining(role))
	var running: bool = perks.is_perk_active(role)
	_show_action("Perk", cooldown, perks.get_perk_charge(role), running, cooldown <= 0.0)
	if _perk_was_cooling and cooldown <= 0.0:
		show_message("%s is ready" % definition.display_name)
	_perk_was_cooling = cooldown > 0.0


## Shows the state of an action on its icon and on its touch button.
func _show_action(
	element_name: String, cooldown: float, meter: float, active: bool, available: bool
) -> void:
	var icon: HudGauge = _elements[element_name]
	icon.cooldown = cooldown
	icon.value = meter
	icon.active = active
	icon.available = available
	Services.input.show_action_state(ACTION_ICONS[element_name], cooldown, meter, active)


# --- Messages --------------------------------------------------------------------


func _on_ammo_depleted() -> void:
	if _role == GameEnums.Role.SHEEPHERDER:
		show_message("Out of bullets")


func _on_kill_unlocked() -> void:
	if _role == GameEnums.Role.MONSTER:
		show_message("You can kill the Sheepherder now")


func _on_monster_form_changed(form: GameEnums.MonsterForm) -> void:
	if _role == GameEnums.Role.MONSTER and form == GameEnums.MonsterForm.SPIDER:
		show_message("You are the spider: nothing can stop you now")


# --- Layout ----------------------------------------------------------------------


func _build() -> void:
	var root: Control = Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.apply(root)
	add_child(root)

	_timer = GameLabel.create(GameTheme.HUD_TIMER, "", "Timer")
	_timer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_timer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_timer.position.y = EDGE
	root.add_child(_timer)
	_elements["Timer"] = _timer

	_message = GameLabel.create(GameTheme.HUD_MESSAGE, "", "Message")
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.position.y = EDGE + 56.0
	_message.visible = false
	root.add_child(_message)
	_elements["Message"] = _message

	# The role's state sits in the top left, away from the touch controls in
	# the bottom corners and from the character in the middle.
	_herder_panel = _panel(root, "SheepherderPanel")
	_add(_herder_panel, HudGauge.new("Bullets", HudGauge.Style.PIPS, Vector2(BAR_SIZE.x, 46.0)))
	_add(_herder_panel, HudGauge.new("Reload", HudGauge.Style.BAR, BAR_SIZE))
	_monster_panel = _panel(root, "MonsterPanel")
	_add(_monster_panel, HudGauge.new("Evolution", HudGauge.Style.BAR, BAR_SIZE))
	var sheep_count: GameLabel = GameLabel.create(GameTheme.HUD_TEXT, "", "SheepCount")
	sheep_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_add(_monster_panel, sheep_count)
	_add(_monster_panel, HudGauge.new("Stamina", HudGauge.Style.BAR, BAR_SIZE))

	# Keyboard and mouse: the actions in a row at the bottom, with their keys.
	_actions = HBoxContainer.new()
	_actions.name = "Actions"
	_actions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_actions.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_actions.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_actions.position.y -= EDGE
	_actions.add_theme_constant_override(&"separation", 12)
	_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_actions)
	for element_name: String in ACTION_ICONS:
		var icon: HudGauge = HudGauge.new(element_name, HudGauge.Style.ICON, ICON_SIZE)
		icon.caption = element_name
		icon.hint = Services.input.get_action_hint(ACTION_ICONS[element_name])
		_add(_actions, icon)


func _panel(root: Control, panel_name: String) -> VBoxContainer:
	var panel: VBoxContainer = VBoxContainer.new()
	panel.name = panel_name
	panel.position = Vector2(EDGE, EDGE)
	panel.add_theme_constant_override(&"separation", 10)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	root.add_child(panel)
	return panel


func _add(parent: Control, element: Control) -> void:
	element.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(element)
	_elements[element.name] = element
