class_name SessionPerkService
extends PerkService
## The real [PerkService] (GDD §4): the stat lookup with its modifiers, the
## loadout of both players and their active perks.
##
## Host-authoritative (docs/networking.md). A player's device asks the host to
## select a perk, to trigger its active perk or to end it early; the host
## checks the request and announces the result. The selections and the lock
## are synced state, so both devices know both perks and apply the same
## modifiers: every stat has the same value on both, and the Monster's device
## draws the Sheepherder's light as wide and as long as it is. Keeping the
## Sheepherder's choice off the Monster's screen is up to what is drawn there
## (GDD §4).
##
## The perks themselves are data: a [PerkCatalog] of [PerkDefinition]s. Call
## [method setup] once the session exists.

## A device to the host: select a perk. [code][role, perk_id][/code]
const EVENT_SELECT_REQUEST: StringName = &"perks.select_request"
## A device to the host: trigger the active perk. [code][role][/code]
const EVENT_ACTIVATE_REQUEST: StringName = &"perks.activate_request"
## A device to the host: end the active perk early. [code][role][/code]
const EVENT_END_REQUEST: StringName = &"perks.end_request"
## Host to both: the active perk started. [code][role][/code]
const EVENT_STARTED: StringName = &"perks.started"
## Host to both: the active perk ended and its cooldown began.
## [code][role, cooldown][/code]
const EVENT_ENDED: StringName = &"perks.ended"
## Synced state: whether the selections are locked for the running round.
const KEY_LOCKED: StringName = &"perks.locked"
## Synced state: the perk id each role selected.
const KEY_SELECTION: Dictionary[GameEnums.Role, StringName] = {
	GameEnums.Role.SHEEPHERDER: &"perks.sheepherder",
	GameEnums.Role.MONSTER: &"perks.monster",
}

## Perks this device selects by itself for the roles it plays, from the
## [code]--perk=[/code] launch option, until the lobby has a perk selection.
var launch_perks: Array[StringName] = []

var _config: GameConfig
var _catalog: PerkCatalog
var _session: GameSession
var _modifiers: Dictionary[int, Modifier] = {}
var _next_handle: int = 1
var _characters: Dictionary[GameEnums.Role, Node2D] = {}
## The effects of the selected active perks while the selection is locked.
var _effects: Dictionary[GameEnums.Role, PerkEffect] = {}


func _init(config: GameConfig = null, catalog: PerkCatalog = null) -> void:
	_config = config if config != null else GameConfig.new()
	_catalog = catalog if catalog != null else PerkCatalog.load_default()


## Connects the service to the session whose host decides and whose synced
## state holds the selections.
func setup(session: GameSession) -> void:
	_session = session
	var messenger: NetMessenger = session.messenger
	messenger.register_event(EVENT_SELECT_REQUEST, NetMessenger.SenderRule.ANYONE)
	messenger.register_event(EVENT_ACTIVATE_REQUEST, NetMessenger.SenderRule.ANYONE)
	messenger.register_event(EVENT_END_REQUEST, NetMessenger.SenderRule.ANYONE)
	messenger.register_event(EVENT_STARTED, NetMessenger.SenderRule.HOST_ONLY)
	messenger.register_event(EVENT_ENDED, NetMessenger.SenderRule.HOST_ONLY)
	messenger.subscribe(EVENT_SELECT_REQUEST, _on_select_request)
	messenger.subscribe(EVENT_ACTIVATE_REQUEST, _on_activate_request)
	messenger.subscribe(EVENT_END_REQUEST, _on_end_request)
	messenger.subscribe(EVENT_STARTED, _on_started)
	messenger.subscribe(EVENT_ENDED, _on_ended)
	session.state.value_changed.connect(_on_state_changed)
	session.session_started.connect(_on_session_started)
	session.session_ended.connect(_on_session_ended)
	session.roles_changed.connect(_select_launch_perks)


func _process(delta: float) -> void:
	advance(delta)


## Moves timed modifiers, running perks and cooldowns forward by [param delta]
## seconds. Called every frame.
func advance(delta: float) -> void:
	for handle: int in _modifiers.keys():
		var modifier: Modifier = _modifiers[handle]
		if modifier.time_left < 0.0:
			continue
		modifier.time_left -= delta
		if modifier.time_left <= 0.0:
			remove_modifier(handle)
	for effect: PerkEffect in _effects.values():
		_advance_effect(effect, delta)


# --- Stat lookup -------------------------------------------------------------------


func get_stat(stat: StringName) -> float:
	var value: float = _config.get_number(stat)
	var added: float = 0.0
	var factor: float = 1.0
	for modifier: Modifier in _modifiers.values():
		if modifier.stat != stat:
			continue
		match modifier.op:
			ModifierOp.OVERRIDE:
				value = modifier.value
			ModifierOp.ADD:
				added += modifier.value
			ModifierOp.MULTIPLY:
				factor *= modifier.value
	return (value + added) * factor


func get_base_stat(stat: StringName) -> float:
	return _config.get_number(stat)


func add_modifier(
	stat: StringName,
	op: ModifierOp,
	value: float,
	source: StringName,
	duration: float = -1.0,
) -> int:
	var modifier: Modifier = Modifier.new()
	modifier.stat = stat
	modifier.op = op
	modifier.value = value
	modifier.source = source
	modifier.time_left = duration if duration > 0.0 else -1.0
	var handle: int = _next_handle
	_next_handle += 1
	_modifiers[handle] = modifier
	stat_changed.emit(stat)
	return handle


func remove_modifier(handle: int) -> void:
	if not _modifiers.has(handle):
		return
	var stat: StringName = _modifiers[handle].stat
	_modifiers.erase(handle)
	stat_changed.emit(stat)


func remove_modifiers_from(source: StringName) -> void:
	for handle: int in _modifiers.keys():
		if _modifiers[handle].source == source:
			remove_modifier(handle)


# --- Loadout -----------------------------------------------------------------------


func get_available_perks(role: GameEnums.Role) -> Array[StringName]:
	return _catalog.pool_for(role)


func select_perk(role: GameEnums.Role, perk_id: StringName) -> bool:
	if is_selection_locked() or not _catalog.is_valid_for(role, perk_id):
		return false
	if not _plays(role):
		return false
	return _session.messenger.send_to_host(EVENT_SELECT_REQUEST, [role, String(perk_id)])


func get_selected_perk(role: GameEnums.Role) -> StringName:
	if not KEY_SELECTION.has(role):
		return PerkIds.NONE
	return StringName(_session.state.get_value(KEY_SELECTION[role], String(PerkIds.NONE)))


func lock_selection() -> void:
	if not _session.messenger.is_host():
		return
	_session.state.set_value(KEY_LOCKED, true)


func is_selection_locked() -> bool:
	return _session.state.get_value(KEY_LOCKED, false)


func clear_selection() -> void:
	if not _session.messenger.is_host():
		return
	# The selections first: unlocking lets the launch perks be selected again.
	for role: GameEnums.Role in KEY_SELECTION:
		_session.state.set_value(KEY_SELECTION[role], String(PerkIds.NONE))
	_session.state.set_value(KEY_LOCKED, false)


# --- Active perks ------------------------------------------------------------------


func activate_perk(role: GameEnums.Role) -> bool:
	if not _plays(role) or not _may_start(role):
		return false
	return _session.messenger.send_to_host(EVENT_ACTIVATE_REQUEST, [role])


func end_perk(role: GameEnums.Role) -> bool:
	if not _plays(role) or not _may_end(role):
		return false
	return _session.messenger.send_to_host(EVENT_END_REQUEST, [role])


func is_perk_active(role: GameEnums.Role) -> bool:
	var effect: PerkEffect = _effects.get(role)
	return effect != null and effect.running


func get_perk_cooldown_remaining(role: GameEnums.Role) -> float:
	var effect: PerkEffect = _effects.get(role)
	return effect.cooldown_left if effect != null else 0.0


func get_perk_charge(role: GameEnums.Role) -> float:
	var effect: PerkEffect = _effects.get(role)
	return effect.charge if effect != null and effect.running else 0.0


func register_character(role: GameEnums.Role, character: Node2D) -> void:
	_characters[role] = character


func unregister_character(character: Node2D) -> void:
	for role: GameEnums.Role in _characters.keys():
		if _characters[role] == character:
			_characters.erase(role)


func _may_start(role: GameEnums.Role) -> bool:
	var effect: PerkEffect = _effects.get(role)
	if effect == null or effect.running or effect.cooldown_left > 0.0:
		return false
	effect.character = _get_character(role)
	return effect.can_start()


func _may_end(role: GameEnums.Role) -> bool:
	var effect: PerkEffect = _effects.get(role)
	return effect != null and effect.running and effect.can_end_early()


func _advance_effect(effect: PerkEffect, delta: float) -> void:
	if effect.running:
		effect.charge = effect.advance(delta)
		if effect.charge <= 0.0 and _session.messenger.is_host():
			_announce_end(effect)
		return
	if effect.cooldown_left <= 0.0:
		return
	effect.cooldown_left = maxf(effect.cooldown_left - delta, 0.0)
	if effect.cooldown_left == 0.0:
		active_perk_state_changed.emit(effect.role)


func _get_character(role: GameEnums.Role) -> Node2D:
	var character: Variant = _characters.get(role)
	return character as Node2D if is_instance_valid(character) else null


# --- Host: deciding requests -------------------------------------------------------


func _on_select_request(payload: Array, sender_id: int) -> void:
	var role: GameEnums.Role = payload[0]
	var perk_id: StringName = StringName(payload[1])
	if not _session.messenger.is_host() or is_selection_locked():
		return
	if not _catalog.is_valid_for(role, perk_id) or not _may_act_for(role, sender_id):
		return
	_session.state.set_value(KEY_SELECTION[role], String(perk_id))


func _on_activate_request(payload: Array, sender_id: int) -> void:
	var role: GameEnums.Role = payload[0]
	if not _session.messenger.is_host() or not _may_act_for(role, sender_id):
		return
	if _may_start(role):
		_session.messenger.broadcast(EVENT_STARTED, [role])


func _on_end_request(payload: Array, sender_id: int) -> void:
	var role: GameEnums.Role = payload[0]
	if not _session.messenger.is_host() or not _may_act_for(role, sender_id):
		return
	if _may_end(role):
		_announce_end(_effects[role])


func _announce_end(effect: PerkEffect) -> void:
	_session.messenger.broadcast(EVENT_ENDED, [effect.role, effect.get_cooldown()])


## A device acts for the role its player plays. A device on its own plays both.
func _may_act_for(role: GameEnums.Role, sender_id: int) -> bool:
	return not _session.has_remote_player() or _session.get_role_of(sender_id) == role


## Whether this device plays [param role].
func _plays(role: GameEnums.Role) -> bool:
	return _may_act_for(role, _session.messenger.get_local_id())


# --- Both devices: what the host decided -------------------------------------------


func _on_started(payload: Array, _sender_id: int) -> void:
	var role: GameEnums.Role = payload[0]
	var effect: PerkEffect = _effects.get(role)
	if effect == null or effect.running:
		return
	effect.character = _get_character(role)
	effect.running = true
	effect.charge = 1.0
	effect.start()
	active_perk_state_changed.emit(role)


func _on_ended(payload: Array, _sender_id: int) -> void:
	var role: GameEnums.Role = payload[0]
	var effect: PerkEffect = _effects.get(role)
	if effect == null or not effect.running:
		return
	effect.running = false
	effect.charge = 0.0
	effect.cooldown_left = payload[1]
	effect.stop()
	active_perk_state_changed.emit(role)


func _on_state_changed(key: StringName, value: Variant) -> void:
	if key == KEY_LOCKED:
		if value:
			_apply_selection()
		else:
			_reset()
			_select_launch_perks()
		return
	for role: GameEnums.Role in KEY_SELECTION:
		if KEY_SELECTION[role] == key:
			perk_selected.emit(role, StringName(value))


## Gives both selected perks their effect for the round, on both devices.
func _apply_selection() -> void:
	_reset()
	for role: GameEnums.Role in KEY_SELECTION:
		var perk: PerkDefinition = _catalog.get_perk(get_selected_perk(role))
		if perk == null:
			continue
		for modifier: PerkModifier in perk.modifiers:
			add_modifier(modifier.stat, modifier.op, get_base_stat(modifier.value_stat), perk.id)
		if perk.is_triggered():
			var effect: PerkEffect = perk.effect.new() as PerkEffect
			effect.role = role
			effect.perks = self
			_effects[role] = effect


## Takes back every effect and modifier on this device.
func _reset() -> void:
	for role: GameEnums.Role in _effects.keys():
		var effect: PerkEffect = _effects[role]
		_effects.erase(role)
		if effect.running:
			effect.running = false
			effect.stop()
		active_perk_state_changed.emit(role)
	for handle: int in _modifiers.keys():
		remove_modifier(handle)


func _select_launch_perks() -> void:
	if _session == null or is_selection_locked():
		return
	for perk_id: StringName in launch_perks:
		for role: GameEnums.Role in KEY_SELECTION:
			if get_selected_perk(role) == PerkIds.NONE:
				select_perk(role, perk_id)


func _on_session_started() -> void:
	_reset()
	_select_launch_perks()


func _on_session_ended(_reason: NetworkService.DisconnectReason, _message: String) -> void:
	_reset()


## One change to a stat.
class Modifier:
	extends RefCounted

	var stat: StringName
	var op: PerkService.ModifierOp
	var value: float
	var source: StringName
	## Seconds until it removes itself; negative while it stays until removed.
	var time_left: float
