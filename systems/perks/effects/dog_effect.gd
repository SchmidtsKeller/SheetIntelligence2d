class_name DogEffect
extends PerkEffect
## The Friendly Shepherd Dog perk (GDD §4.1): for the whole round, a
## [ShepherdDog] keeps the Sheepherder company.
##
## Not triggered: it starts once the round has the Sheepherder. The host spawns
## the dog next to them and removes it when the round or the Sheepherder ends;
## the other device gets the dog through the session.

var _dog_id: int = -1


func setup() -> void:
	ShepherdDog.register(session)


func start() -> void:
	if session.is_host():
		# Starting is part of handling the lock (or the Sheepherder's spawn) on
		# the host, which reaches the other device only after this returns; the
		# dog must not get there first, before its kind is known there.
		_spawn.call_deferred()


func _spawn() -> void:
	if not running or _dog_id >= 0 or not is_instance_valid(character):
		return
	var at: Vector2 = character.global_position
	at.x -= perks.get_stat(StatIds.DOG_FOLLOW_DISTANCE_MIN)
	_dog_id = session.entities.spawn(
		ShepherdDog.KIND, session.messenger.get_local_id(), {"x": at.x, "y": at.y}
	)


func stop() -> void:
	if _dog_id >= 0 and session.is_host():
		session.entities.despawn(_dog_id)
	_dog_id = -1


func advance(_delta: float) -> float:
	return 1.0


func get_cooldown() -> float:
	return 0.0
