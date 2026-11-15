class_name PerkPicker
extends VBoxContainer
## The perk choice before a round (GDD §4, #20): one button per perk in the
## pool of the role this device's player plays next, and one for no perk.
##
## Each button shows the perk's name, its type (passive, active, companion)
## and what it does. Only one can be chosen; the choice goes to the
## [PerkService], which replicates it. The picker never shows the other
## role's perks or choice: the Monster's device knows nothing of the
## Sheepherder's perk on screen (GDD §8.1). Once the player is ready, the
## choice is locked.

const NO_PERK_NAME: String = "No perk"
const NO_PERK_TEXT: String = "Play the round as it is."
const KIND_NAMES: Dictionary[PerkDefinition.Kind, String] = {
	PerkDefinition.Kind.PASSIVE: "Passive",
	PerkDefinition.Kind.ACTIVE: "Active",
	PerkDefinition.Kind.COMPANION: "Companion",
}
const BUTTON_SIZE: Vector2 = Vector2(460.0, 64.0)

var _catalog: PerkCatalog = PerkCatalog.load_default()
var _role: GameEnums.Role = GameEnums.Role.NONE
var _title: Label
var _buttons: Dictionary[StringName, Button] = {}
var _group: ButtonGroup = ButtonGroup.new()


func _init() -> void:
	name = "PerkPicker"
	add_theme_constant_override(&"separation", 8)
	_title = Label.new()
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)


func _ready() -> void:
	Services.perks.perk_selected.connect(_on_perk_selected)
	Services.session.roles_changed.connect(refresh)
	Services.match_flow.ready_changed.connect(refresh)
	refresh()


func _exit_tree() -> void:
	Services.perks.perk_selected.disconnect(_on_perk_selected)
	Services.session.roles_changed.disconnect(refresh)
	Services.match_flow.ready_changed.disconnect(refresh)


## The perks to choose from, in order, with [constant PerkIds.NONE] last.
func get_choices() -> Array[StringName]:
	var choices: Array[StringName] = []
	choices.assign(_buttons.keys())
	return choices


## The perk chosen for the next round; [constant PerkIds.NONE] for none.
func get_selected() -> StringName:
	return Services.perks.get_selected_perk(_role)


## Whether the choice can still be changed.
func is_open() -> bool:
	return (
		_role != GameEnums.Role.NONE
		and not Services.perks.is_selection_locked()
		and not Services.match_flow.is_locally_ready()
	)


## Chooses [param perk_id] for this device's player. Returns whether it was
## sent.
func choose(perk_id: StringName) -> bool:
	if not is_open():
		return false
	return Services.perks.select_perk(_role, perk_id)


## The button of [param perk_id], or [code]null[/code].
func get_button(perk_id: StringName) -> Button:
	return _buttons.get(perk_id)


## Builds the buttons anew when the role changed, and shows the choice.
func refresh() -> void:
	var role: GameEnums.Role = Services.session.get_local_role()
	if role != _role:
		_role = role
		_rebuild()
	var selected: StringName = get_selected()
	var open: bool = is_open()
	for perk_id: StringName in _buttons:
		var button: Button = _buttons[perk_id]
		button.set_pressed_no_signal(perk_id == selected)
		button.disabled = not open
	_title.text = (
		"Your perk as the %s" % GameEnums.role_name(_role) if _role != GameEnums.Role.NONE else ""
	)


func _rebuild() -> void:
	for perk_id: StringName in _buttons:
		_buttons[perk_id].queue_free()
	_buttons.clear()
	if _role == GameEnums.Role.NONE:
		return
	for perk_id: StringName in _catalog.pool_for(_role):
		var perk: PerkDefinition = _catalog.get_perk(perk_id)
		_add_choice(
			perk_id, "%s · %s\n%s" % [perk.display_name, KIND_NAMES[perk.kind], perk.description]
		)
	_add_choice(PerkIds.NONE, "%s\n%s" % [NO_PERK_NAME, NO_PERK_TEXT])


func _add_choice(perk_id: StringName, text: String) -> void:
	var button: Button = Button.new()
	button.name = "Perk_%s" % (perk_id if perk_id != PerkIds.NONE else &"none")
	button.text = text
	button.toggle_mode = true
	button.button_group = _group
	button.custom_minimum_size = BUTTON_SIZE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(choose.bind(perk_id))
	add_child(button)
	_buttons[perk_id] = button


func _on_perk_selected(role: GameEnums.Role, _perk_id: StringName) -> void:
	if role == _role:
		refresh()
