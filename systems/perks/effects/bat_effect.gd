class_name BatEffect
extends PerkEffect
## The Allied Bat perk (GDD §4.2), triggered with the perk button: the host
## sends an [AlliedBat] from the map edge nearest the Sheepherder.
##
## The perk runs from the button press until the bat leaves the Sheepherder;
## then the cooldown begins. The Monster sends it only in its sheep form, and
## only while there is a Sheepherder to harass.


func setup() -> void:
	AlliedBat.register(session)


func can_start() -> bool:
	if not is_instance_valid(character):
		return false
	var body: SheepBody = character as SheepBody
	return (
		body != null
		and body.is_alive()
		and Services.combat.get_monster_form() == GameEnums.MonsterForm.SHEEP
		and perks.get_character(GameEnums.Role.SHEEPHERDER) != null
	)


func start() -> void:
	var herder: Node2D = perks.get_character(GameEnums.Role.SHEEPHERDER)
	if not session.is_host() or herder == null:
		return
	var bounds: Rect2 = Rect2(herder.global_position, Vector2.ZERO)
	var arena: Arena = herder.get_tree().get_first_node_in_group(Groups.ARENA) as Arena
	if arena != null:
		bounds = arena.get_bounds()
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.randomize()
	var at: Vector2 = AlliedBat.entry_point(bounds, herder.global_position, random)
	session.entities.spawn(AlliedBat.KIND, session.messenger.get_local_id(), {"x": at.x, "y": at.y})


## When the harassment is over, the bat flies away by itself. If the perk ends
## before that, with the round, the bat goes at once.
func stop() -> void:
	var bat: AlliedBat = _find_bat()
	if bat == null or not session.is_host():
		return
	var harassing: bool = bat.get_phase() == AlliedBat.Phase.HARASS and bat.get_harass_left() > 0.0
	if bat.get_phase() == AlliedBat.Phase.APPROACH or harassing:
		session.entities.despawn(bat.entity_id)


## Full while the bat flies in, then what is left of the harassment.
func advance(_delta: float) -> float:
	var bat: AlliedBat = _find_bat()
	if bat == null:
		return 0.0
	match bat.get_phase():
		AlliedBat.Phase.APPROACH:
			return 1.0
		AlliedBat.Phase.HARASS:
			var duration: float = perks.get_stat(StatIds.BAT_DISRUPTION_DURATION)
			return bat.get_harass_left() / duration if duration > 0.0 else 0.0
		_:
			return 0.0


func get_cooldown() -> float:
	return perks.get_stat(StatIds.BAT_COOLDOWN)


## The newest bat: an older one may still be flying away.
func _find_bat() -> AlliedBat:
	var newest: AlliedBat = null
	for entity_id: int in session.entities.get_entity_ids():
		var bat: AlliedBat = session.entities.get_entity(entity_id) as AlliedBat
		if bat != null and (newest == null or bat.entity_id > newest.entity_id):
			newest = bat
	return newest
