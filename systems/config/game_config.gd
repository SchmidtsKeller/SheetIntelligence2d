class_name GameConfig
extends Resource
## The single source of truth for every gameplay number (GDD §5).
##
## The defaults below are the documented values from the design document; the
## shipped instance is `res://systems/config/game_config.tres`, which can be
## tuned in the editor without touching code. No gameplay code hard-codes any
## of these numbers.
##
## Gameplay code does not read the properties directly either: it asks
## [method PerkService.get_stat] with the matching [StatIds] constant, so perks
## can change the effective value. Every numeric property here is a stat.

@export_group("Match Rules")
## Length of a round in seconds. At timeout the higher score wins the round.
@export_range(10.0, 600.0, 1.0, "suffix:s") var round_duration: float = 180.0
## Rounds per match ("Best of 5"). Players swap roles after every round.
@export_range(1, 9, 2) var match_rounds: int = 5
## NPC sheep per round. The disguised Monster comes on top.
@export_range(1, 30) var flock_size: int = 10
## Sheepherder points for every NPC sheep alive at the end of the round.
@export var herder_points_per_surviving_sheep: int = 1
## Sheepherder points for every NPC sheep they shot (a penalty).
@export var herder_points_per_shot_sheep: int = -2
## Monster points for every NPC sheep it ate. Shot sheep give it nothing.
@export var monster_points_per_eaten_sheep: int = 1
## The perk selection window before a round. 0 skips it until the selection
## screen exists.
@export_range(0.0, 120.0, 0.5, "suffix:s") var round_setup_duration: float = 0.0
## The countdown between the spawn and the start of a round. Nobody can act yet.
@export_range(0.0, 30.0, 0.5, "suffix:s") var round_countdown_duration: float = 3.0
## How long the arena stays on screen after a round was decided.
@export_range(0.0, 30.0, 0.5, "suffix:s") var round_resolved_duration: float = 3.0

@export_group("Sheepherder")
## Patrol speed.
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var herder_move_speed: float = 180.0
## Bullets per round. Cannot be replenished.
@export_range(0, 10) var firearm_ammo: int = 3
## Automatic reload after each shot.
@export_range(0.0, 30.0, 0.1, "suffix:s") var firearm_reload_time: float = 4.0
## Full opening angle of the flashlight cone.
@export_range(1.0, 360.0, 1.0, "suffix:°") var flashlight_cone_angle_deg: float = 60.0
## Length of the flashlight cone. Solid obstacles block it.
@export_range(0.0, 2000.0, 1.0, "suffix:px") var flashlight_cone_length: float = 350.0
## Time between two bell rings.
@export_range(0.0, 120.0, 0.1, "suffix:s") var bell_cooldown: float = 12.0
## Sheep within this distance walk toward the Sheepherder when the bell rings.
@export_range(0.0, 4000.0, 1.0, "suffix:px") var bell_radius: float = 400.0

@export_group("Monster")
## Walking speed in sheep form; the same as the NPC sheep for seamless mimicry.
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var monster_move_speed: float = 180.0
## Speed while sprinting (1.5× base). Sheep form only.
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var monster_sprint_speed: float = 270.0
## Seconds of sprinting a full stamina meter allows.
@export_range(0.0, 60.0, 0.1, "suffix:s") var monster_sprint_stamina: float = 3.0
## Stamina regained per second while not sprinting, relative to the drain
## (0.5 means 6.0 s from empty to full).
@export_range(0.0, 10.0, 0.05, "suffix:×") var monster_sprint_refill_rate: float = 0.5
## Speed in spider form. Faster than sprinting; the spider cannot sprint.
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var spider_move_speed: float = 300.0
## Length of the eating animation. The Monster cannot move or abort meanwhile.
@export_range(0.0, 10.0, 0.05, "suffix:s") var eat_duration: float = 1.0
## Time between two attacks. Starts when the eating animation ends.
@export_range(0.0, 60.0, 0.1, "suffix:s") var eat_cooldown: float = 5.0
## Center-to-center distance to eat a sheep or kill the Sheepherder.
@export_range(0.0, 500.0, 1.0, "suffix:px") var melee_range: float = 48.0
## Sheep eaten to unlock the one-attack kill on the Sheepherder.
@export_range(0, 30) var herder_kill_threshold: int = 5
## Sheep eaten to evolve into the unkillable spider.
@export_range(0, 30) var spider_evolution_threshold: int = 10

@export_group("NPC Sheep")
## One speed for wandering and for walking to the bell.
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var sheep_move_speed: float = 180.0
## Shortest time a sheep stands still with its head lowered.
@export_range(0.0, 60.0, 0.1, "suffix:s") var sheep_graze_duration_min: float = 3.0
## Longest time a sheep stands still with its head lowered.
@export_range(0.0, 60.0, 0.1, "suffix:s") var sheep_graze_duration_max: float = 6.0

@export_group("Flock")
## Shortest and longest time a sheep may take for one walk before it gives up.
@export_range(0.0, 30.0, 0.1, "suffix:s") var flock_walk_time_min: float = 1.5
@export_range(0.0, 30.0, 0.1, "suffix:s") var flock_walk_time_max: float = 4.0
## Shortest and longest time a sheep stands between two walks.
@export_range(0.0, 30.0, 0.1, "suffix:s") var flock_pause_time_min: float = 0.8
@export_range(0.0, 30.0, 0.1, "suffix:s") var flock_pause_time_max: float = 2.5
## How likely a sheep grazes after a walk instead of just standing.
@export_range(0.0, 1.0, 0.01) var flock_graze_chance: float = 0.45
## Shortest and longest time between two bleats of one sheep.
@export_range(0.0, 120.0, 0.5, "suffix:s") var flock_bleat_interval_min: float = 8.0
@export_range(0.0, 120.0, 0.5, "suffix:s") var flock_bleat_interval_max: float = 25.0
## How far a sheep walks in one go, at least and at most.
@export_range(0.0, 1000.0, 1.0, "suffix:px") var flock_wander_distance_min: float = 80.0
@export_range(0.0, 1000.0, 1.0, "suffix:px") var flock_wander_distance_max: float = 240.0
## Walking sheep steer away from others that are closer than this.
@export_range(0.0, 500.0, 1.0, "suffix:px") var flock_separation_radius: float = 72.0
## A sheep farther than this from the middle of the flock heads back.
@export_range(0.0, 2000.0, 1.0, "suffix:px") var flock_cohesion_radius: float = 280.0
## How much a sheep that starts to walk leans toward where the others walk.
@export_range(0.0, 2.0, 0.05) var flock_alignment_weight: float = 0.35
## How strongly walking sheep keep apart from each other, compared to the pull
## of where they want to go (1).
@export_range(0.0, 10.0, 0.05) var flock_separation_weight: float = 1.6
## How strongly a sheep that starts to walk is drawn back to the flock.
@export_range(0.0, 10.0, 0.05) var flock_cohesion_weight: float = 2.5
## How strongly walking sheep keep clear of obstacles.
@export_range(0.0, 10.0, 0.05) var flock_obstacle_weight: float = 2.2
## How strongly walking sheep keep clear of the borders.
@export_range(0.0, 10.0, 0.05) var flock_border_weight: float = 2.2
## Walking sheep steer away from obstacles closer than this.
@export_range(0.0, 500.0, 1.0, "suffix:px") var flock_obstacle_margin: float = 60.0
## Walking sheep steer away from the borders when closer than this.
@export_range(0.0, 500.0, 1.0, "suffix:px") var flock_border_margin: float = 70.0
## The room a sheep needs around its center where it wants to walk to.
@export_range(0.0, 200.0, 1.0, "suffix:px") var flock_body_clearance: float = 28.0
## Sheep that follow the bell stop this far from where it rang.
@export_range(0.0, 1000.0, 1.0, "suffix:px") var bell_stop_distance: float = 110.0
## How long sheep follow the bell before they return to normal behaviour.
@export_range(0.0, 60.0, 0.1, "suffix:s") var bell_follow_time: float = 6.0

@export_group("Sheep Motion")
## How fast a sheep speeds up to its walking speed and slows down again. Not
## from the GDD: NPC sheep and the Monster's sheep share it, so both move alike.
@export_range(0.0, 10000.0, 10.0, "suffix:px/s²") var sheep_acceleration: float = 900.0
## How fast a sheep turns toward the direction it wants to walk.
@export_range(0.0, 3600.0, 10.0, "suffix:°/s") var sheep_turn_rate_deg: float = 540.0

@export_group("Lighting")
## Beyond the end of the flashlight cone its light fades out over this share
## of the cone's length (0.6: a 350 px cone fades out by 560 px). Perks and the
## bat change it along with the length.
@export_range(0.0, 3.0, 0.05, "suffix:×") var flashlight_fade_length_share: float = 0.6
## Beside the cone its light fades out over this angle on each side.
@export_range(0.0, 90.0, 0.5, "suffix:°") var flashlight_fade_angle_deg: float = 12.0
## A lit torch fully lights everything this close to it ...
@export_range(0.0, 2000.0, 1.0, "suffix:px") var torch_light_radius: float = 200.0
## ... and its light fades out over this distance beyond.
@export_range(0.0, 2000.0, 1.0, "suffix:px") var torch_fade_length: float = 120.0
## A living Sheepherder this close to an unlit torch lights it.
@export_range(0.0, 500.0, 1.0, "suffix:px") var torch_ignite_range: float = 60.0

@export_group("Arena")
## Width of the arena, borders included.
@export_range(800.0, 20000.0, 1.0, "suffix:px") var arena_width: float = 3200.0
## Height of the arena, borders included.
@export_range(800.0, 20000.0, 1.0, "suffix:px") var arena_height: float = 2400.0

@export_group("Perks")
## Cone angle with the Wide Flashlight perk (+50 % lit area).
@export_range(1.0, 360.0, 1.0, "suffix:°") var perk_wide_flashlight_angle_deg: float = 90.0
## Cone length with the Long Flashlight perk (+50 % lit area).
@export_range(0.0, 2000.0, 1.0, "suffix:px") var perk_long_flashlight_length: float = 429.0
## Reload time with the Faster Weapon Reload perk.
@export_range(0.0, 30.0, 0.1, "suffix:s") var perk_faster_reload_time: float = 2.0
## Bullets per round with the Spare Bullet perk.
@export_range(0, 10) var perk_spare_bullet_ammo: int = 4
## Eating animation length with the Faster Consumption perk.
@export_range(0.0, 10.0, 0.05, "suffix:s") var perk_faster_consumption_duration: float = 0.5
## Longest time the Monster can stay invisible.
@export_range(0.0, 60.0, 0.1, "suffix:s") var invisibility_max_duration: float = 5.0
## Drain of the invisibility meter while standing still.
@export_range(0.0, 10.0, 0.1, "suffix:×") var invisibility_drain_still: float = 1.0
## Drain of the invisibility meter while moving.
@export_range(0.0, 10.0, 0.1, "suffix:×") var invisibility_drain_moving: float = 3.0
## Cooldown of the invisibility perk. It starts when the invisibility ends.
@export_range(0.0, 300.0, 0.5, "suffix:s") var invisibility_cooldown: float = 30.0
## How long the Allied Bat disrupts the flashlight.
@export_range(0.0, 60.0, 0.1, "suffix:s") var bat_disruption_duration: float = 10.0
## Fraction by which the bat shrinks both the cone's length and its angle
## (about 42 % each, which cuts the lit area by 80 %).
@export_range(0.0, 1.0, 0.01) var bat_cone_shrink: float = 0.42
## Cooldown of the Allied Bat perk. It starts when the bat leaves.
@export_range(0.0, 300.0, 0.5, "suffix:s") var bat_cooldown: float = 30.0

@export_group("Companions")
## Not from the GDD: how fast the Shepherd Dog runs. Faster than the
## Sheepherder, so it keeps up.
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var dog_move_speed: float = 260.0
## The dog stays at least this far from the Sheepherder ...
@export_range(0.0, 500.0, 1.0, "suffix:px") var dog_follow_distance_min: float = 50.0
## ... and at most this far, while it can.
@export_range(0.0, 1000.0, 1.0, "suffix:px") var dog_follow_distance_max: float = 130.0
## Not from the GDD: how fast the Allied Bat flies to the Sheepherder and away.
@export_range(0.0, 2000.0, 1.0, "suffix:px/s") var bat_flight_speed: float = 420.0
## How far from the Sheepherder the bat circles while it harasses them.
@export_range(0.0, 500.0, 1.0, "suffix:px") var bat_orbit_radius: float = 70.0

@export_group("Audio")
## Hearing range of quiet sounds (sheep moving through grass).
@export_range(0.0, 4000.0, 1.0, "suffix:px") var hearing_range_quiet: float = 400.0
## Hearing range of loud sounds (bleating, Monster eating, dog barking).
@export_range(0.0, 4000.0, 1.0, "suffix:px") var hearing_range_loud: float = 800.0
## Not from the GDD: how far whole-map sounds (bell, gunshot) carry before
## they would fade out. Twice the arena's diagonal, so they are heard
## everywhere and still sound further away the further they are.
@export_range(0.0, 20000.0, 1.0, "suffix:px") var audio_whole_map_distance: float = 8000.0
## How strongly stereo panning follows the direction of a sound, as a factor
## on the project's 2D panning strength.
@export_range(0.0, 10.0, 0.05) var audio_panning_strength: float = 3.0
## Volume of a player's own looping sounds (footsteps, rustle, grazing) on
## their own device, so they don't cover the sounds nearby.
@export_range(-40.0, 0.0, 0.5, "suffix:dB") var audio_own_sound_volume_db: float = -10.0

@export_group("Network")
## State snapshots each device sends per second.
@export_range(1, 60) var net_tick_rate: int = 20
## How far in the past replicated entities are shown, so that late packets
## still arrive in time for smooth motion.
@export_range(0.0, 1.0, 0.01, "suffix:s") var net_interpolation_delay: float = 0.1
## How long an entity keeps its last course when no packet arrives.
@export_range(0.0, 1.0, 0.01, "suffix:s") var net_max_extrapolation: float = 0.1
## A joining device gives up after this time.
@export_range(1.0, 60.0, 0.5, "suffix:s") var net_connect_timeout: float = 10.0
## How often the guest compares its clock with the host's, for the round timer.
@export_range(0.1, 10.0, 0.1, "suffix:s") var net_clock_sync_interval: float = 0.5

@export_group("Bots")
## The computer opponent of an offline match. Not from the GDD; see #57.
## Shortest and longest rest of the bot Monster after an attack before it
## hunts again (the cooldown runs meanwhile).
@export_range(0.0, 120.0, 0.5, "suffix:s") var bot_monster_rest_min: float = 3.0
@export_range(0.0, 120.0, 0.5, "suffix:s") var bot_monster_rest_max: float = 8.0
## How far the bot Monster walks to a sheep it hunts.
@export_range(0.0, 2000.0, 1.0, "suffix:px") var bot_monster_hunt_range: float = 450.0
## It hunts only where the Sheepherder is at least this far from it and the prey.
@export_range(0.0, 2000.0, 1.0, "suffix:px") var bot_monster_safe_distance: float = 250.0
## A hunt that takes longer is given up.
@export_range(0.0, 60.0, 0.5, "suffix:s") var bot_monster_hunt_time: float = 10.0
## Once it may kill the Sheepherder, it goes for them from this close.
@export_range(0.0, 2000.0, 1.0, "suffix:px") var bot_monster_attack_range: float = 220.0
## The bot Sheepherder shoots this long after it decided to.
@export_range(0.0, 5.0, 0.05, "suffix:s") var bot_herder_reaction_time: float = 0.6
## Largest error of the bot Sheepherder's aim.
@export_range(0.0, 45.0, 0.5, "suffix:°") var bot_herder_aim_error_deg: float = 2.5
## Suspicion at which the bot Sheepherder shoots. Seeing a sheep eat is 2.
@export_range(0.1, 10.0, 0.05) var bot_herder_shoot_suspicion: float = 1.0
## Suspicion gained per second of watching a sheep run faster than the flock.
@export_range(0.0, 10.0, 0.05) var bot_herder_sprint_suspicion: float = 0.5
## Suspicion of the sheep the bot Sheepherder finds next to where it heard
## eating.
@export_range(0.0, 10.0, 0.05) var bot_herder_blood_suspicion: float = 0.6
## How close to the eating sound a sheep has to be to fall under suspicion.
@export_range(0.0, 1000.0, 1.0, "suffix:px") var bot_herder_blood_radius: float = 140.0
## Suspicion lost per second.
@export_range(0.0, 1.0, 0.005, "suffix:/s") var bot_herder_suspicion_decay: float = 0.02
## The distance the bot Sheepherder keeps from the middle of the flock.
@export_range(0.0, 2000.0, 1.0, "suffix:px") var bot_herder_flock_distance: float = 240.0
## Time between two sweeps of its light to another sheep.
@export_range(0.1, 30.0, 0.1, "suffix:s") var bot_herder_sweep_interval: float = 1.4
## Time between two rings of its bell, when it may ring.
@export_range(1.0, 300.0, 1.0, "suffix:s") var bot_herder_bell_interval: float = 25.0

@export_group("View")
## The widest stretch of world a player may ever see. Not from the GDD: this
## is the view-fairness rule, see [ViewRules] and the README.
@export_range(100.0, 8000.0, 1.0, "suffix:px") var view_max_world_width: float = 1600.0
## The tallest stretch of world a player may ever see.
@export_range(100.0, 8000.0, 1.0, "suffix:px") var view_max_world_height: float = 900.0


## The value of [param stat] as a float. Fails loudly for a name that is not
## a numeric property of this config.
func get_number(stat: StringName) -> float:
	var value: Variant = get(stat)
	if value is float or value is int:
		return float(value)
	push_error("GameConfig has no numeric value named '%s'." % stat)
	return 0.0


## Whether [param stat] names a numeric property of this config.
func has_number(stat: StringName) -> bool:
	var value: Variant = get(stat)
	return value is float or value is int


## The names of all numeric gameplay values, in declaration order.
func get_number_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for property: Dictionary in get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0 or usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		var type: int = property["type"]
		if type == TYPE_FLOAT or type == TYPE_INT:
			names.append(StringName(property["name"]))
	return names


## The largest world area a player may see at once.
func get_view_max_world_size() -> Vector2:
	return Vector2(view_max_world_width, view_max_world_height)
