class_name FlockSettings
extends RefCounted
## The flock's tunables, read once per round through the stat lookup, so the
## simulation does not ask for two dozen stats every frame.
##
## Every value lives in [GameConfig]; see there for what each one means.

var walk_time_min: float = 1.5
var walk_time_max: float = 4.0
var pause_time_min: float = 0.8
var pause_time_max: float = 2.5
var graze_chance: float = 0.45
var graze_time_min: float = 3.0
var graze_time_max: float = 6.0
var bleat_interval_min: float = 8.0
var bleat_interval_max: float = 25.0
var wander_distance_min: float = 80.0
var wander_distance_max: float = 240.0
var separation_radius: float = 72.0
var cohesion_radius: float = 280.0
var alignment_weight: float = 0.35
var obstacle_margin: float = 60.0
var border_margin: float = 70.0
var bell_stop_distance: float = 110.0
var bell_follow_time: float = 6.0
## Half the width of a sheep: the room it needs around its center.
var body_clearance: float = 28.0


## Reads every value from [param perks].
static func from_stats(perks: PerkService) -> FlockSettings:
	var settings: FlockSettings = FlockSettings.new()
	settings.walk_time_min = perks.get_stat(StatIds.FLOCK_WALK_TIME_MIN)
	settings.walk_time_max = perks.get_stat(StatIds.FLOCK_WALK_TIME_MAX)
	settings.pause_time_min = perks.get_stat(StatIds.FLOCK_PAUSE_TIME_MIN)
	settings.pause_time_max = perks.get_stat(StatIds.FLOCK_PAUSE_TIME_MAX)
	settings.graze_chance = perks.get_stat(StatIds.FLOCK_GRAZE_CHANCE)
	settings.graze_time_min = perks.get_stat(StatIds.SHEEP_GRAZE_DURATION_MIN)
	settings.graze_time_max = perks.get_stat(StatIds.SHEEP_GRAZE_DURATION_MAX)
	settings.bleat_interval_min = perks.get_stat(StatIds.FLOCK_BLEAT_INTERVAL_MIN)
	settings.bleat_interval_max = perks.get_stat(StatIds.FLOCK_BLEAT_INTERVAL_MAX)
	settings.wander_distance_min = perks.get_stat(StatIds.FLOCK_WANDER_DISTANCE_MIN)
	settings.wander_distance_max = perks.get_stat(StatIds.FLOCK_WANDER_DISTANCE_MAX)
	settings.separation_radius = perks.get_stat(StatIds.FLOCK_SEPARATION_RADIUS)
	settings.cohesion_radius = perks.get_stat(StatIds.FLOCK_COHESION_RADIUS)
	settings.alignment_weight = perks.get_stat(StatIds.FLOCK_ALIGNMENT_WEIGHT)
	settings.obstacle_margin = perks.get_stat(StatIds.FLOCK_OBSTACLE_MARGIN)
	settings.border_margin = perks.get_stat(StatIds.FLOCK_BORDER_MARGIN)
	settings.bell_stop_distance = perks.get_stat(StatIds.BELL_STOP_DISTANCE)
	settings.bell_follow_time = perks.get_stat(StatIds.BELL_FOLLOW_TIME)
	settings.body_clearance = perks.get_stat(StatIds.FLOCK_BODY_CLEARANCE)
	return settings
