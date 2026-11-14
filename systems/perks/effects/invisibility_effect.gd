class_name InvisibilityEffect
extends PerkEffect
## The Monster's Temporary Invisibility (GDD §4.2).
##
## While it runs, the Monster's sheep is seen by nobody but its own player, who
## sees it faded. It cannot eat, and the NPC sheep no longer count it as one of
## the flock. It can still be heard, it is still solid, and bullets still hit
## it. The meter drains slowly while the Monster stands and fast while it
## walks; its player may end it early, which loses the rest. The cooldown
## starts when it ends. Not in spider form, and not while eating.

var _left: float = 0.0


func can_start() -> bool:
	if not is_instance_valid(character):
		return false
	var body: SheepBody = character as SheepBody
	var combat: CombatService = Services.combat
	return (
		body != null
		and body.is_alive()
		and combat.get_monster_form() == GameEnums.MonsterForm.SHEEP
		and not combat.is_eating()
	)


func can_end_early() -> bool:
	return true


func start() -> void:
	_left = perks.get_stat(StatIds.INVISIBILITY_MAX_DURATION)
	Services.combat.add_eat_blocker(PerkIds.INVISIBILITY)
	if not is_instance_valid(character):
		return
	_set_cloaked(true)
	Services.swarm.unregister_neighbour(character)


func stop() -> void:
	Services.combat.remove_eat_blocker(PerkIds.INVISIBILITY)
	if not is_instance_valid(character):
		return
	_set_cloaked(false)
	if character.is_inside_tree():
		Services.swarm.register_neighbour(character)


func advance(delta: float) -> float:
	if not is_instance_valid(character):
		return 0.0
	var body: SheepBody = character as SheepBody
	if body == null or not body.is_alive():
		return 0.0
	# Walking as it is shown on this device, which is the same on both.
	var moving: bool = body.get_state() == SheepBody.State.WALK
	var drain: float = perks.get_stat(
		StatIds.INVISIBILITY_DRAIN_MOVING if moving else StatIds.INVISIBILITY_DRAIN_STILL
	)
	_left = maxf(_left - drain * delta, 0.0)
	var capacity: float = perks.get_stat(StatIds.INVISIBILITY_MAX_DURATION)
	return _left / capacity if capacity > 0.0 else 0.0


func get_cooldown() -> float:
	return perks.get_stat(StatIds.INVISIBILITY_COOLDOWN)


func _set_cloaked(cloaked: bool) -> void:
	var target: VisionTarget = VisionTarget.of(character)
	if target != null:
		target.cloaked = cloaked
