@abstract class_name StatIds
extends RefCounted
## Names of all gameplay stats (GDD §5).
##
## A stat id is the name of the [GameConfig] property that holds its base
## value. Gameplay code reads the [b]effective[/b] value through
## [method PerkService.get_stat], so perks and temporary effects can change it
## without the reader knowing. A test keeps this list and [GameConfig] in sync.

# --- Match rules -------------------------------------------------------------
const ROUND_DURATION: StringName = &"round_duration"
const MATCH_ROUNDS: StringName = &"match_rounds"
const FLOCK_SIZE: StringName = &"flock_size"
const HERDER_POINTS_PER_SURVIVING_SHEEP: StringName = &"herder_points_per_surviving_sheep"
const HERDER_POINTS_PER_SHOT_SHEEP: StringName = &"herder_points_per_shot_sheep"
const MONSTER_POINTS_PER_EATEN_SHEEP: StringName = &"monster_points_per_eaten_sheep"
const ROUND_SETUP_DURATION: StringName = &"round_setup_duration"
const ROUND_COUNTDOWN_DURATION: StringName = &"round_countdown_duration"
const ROUND_RESOLVED_DURATION: StringName = &"round_resolved_duration"

# --- Sheepherder -------------------------------------------------------------
const HERDER_MOVE_SPEED: StringName = &"herder_move_speed"
const FIREARM_AMMO: StringName = &"firearm_ammo"
const FIREARM_RELOAD_TIME: StringName = &"firearm_reload_time"
const FLASHLIGHT_CONE_ANGLE_DEG: StringName = &"flashlight_cone_angle_deg"
const FLASHLIGHT_CONE_LENGTH: StringName = &"flashlight_cone_length"
const BELL_COOLDOWN: StringName = &"bell_cooldown"
const BELL_RADIUS: StringName = &"bell_radius"

# --- Monster -----------------------------------------------------------------
const MONSTER_MOVE_SPEED: StringName = &"monster_move_speed"
const MONSTER_SPRINT_SPEED: StringName = &"monster_sprint_speed"
const MONSTER_SPRINT_STAMINA: StringName = &"monster_sprint_stamina"
const MONSTER_SPRINT_REFILL_RATE: StringName = &"monster_sprint_refill_rate"
const SPIDER_MOVE_SPEED: StringName = &"spider_move_speed"
const EAT_DURATION: StringName = &"eat_duration"
const EAT_COOLDOWN: StringName = &"eat_cooldown"
const MELEE_RANGE: StringName = &"melee_range"
const HERDER_KILL_THRESHOLD: StringName = &"herder_kill_threshold"
const SPIDER_EVOLUTION_THRESHOLD: StringName = &"spider_evolution_threshold"

# --- NPC sheep ---------------------------------------------------------------
const SHEEP_MOVE_SPEED: StringName = &"sheep_move_speed"
const SHEEP_GRAZE_DURATION_MIN: StringName = &"sheep_graze_duration_min"
const SHEEP_GRAZE_DURATION_MAX: StringName = &"sheep_graze_duration_max"

# --- Flock -------------------------------------------------------------------
const FLOCK_WALK_TIME_MIN: StringName = &"flock_walk_time_min"
const FLOCK_WALK_TIME_MAX: StringName = &"flock_walk_time_max"
const FLOCK_PAUSE_TIME_MIN: StringName = &"flock_pause_time_min"
const FLOCK_PAUSE_TIME_MAX: StringName = &"flock_pause_time_max"
const FLOCK_GRAZE_CHANCE: StringName = &"flock_graze_chance"
const FLOCK_BLEAT_INTERVAL_MIN: StringName = &"flock_bleat_interval_min"
const FLOCK_BLEAT_INTERVAL_MAX: StringName = &"flock_bleat_interval_max"
const FLOCK_WANDER_DISTANCE_MIN: StringName = &"flock_wander_distance_min"
const FLOCK_WANDER_DISTANCE_MAX: StringName = &"flock_wander_distance_max"
const FLOCK_SEPARATION_RADIUS: StringName = &"flock_separation_radius"
const FLOCK_COHESION_RADIUS: StringName = &"flock_cohesion_radius"
const FLOCK_ALIGNMENT_WEIGHT: StringName = &"flock_alignment_weight"
const FLOCK_SEPARATION_WEIGHT: StringName = &"flock_separation_weight"
const FLOCK_COHESION_WEIGHT: StringName = &"flock_cohesion_weight"
const FLOCK_OBSTACLE_WEIGHT: StringName = &"flock_obstacle_weight"
const FLOCK_BORDER_WEIGHT: StringName = &"flock_border_weight"
const FLOCK_OBSTACLE_MARGIN: StringName = &"flock_obstacle_margin"
const FLOCK_BORDER_MARGIN: StringName = &"flock_border_margin"
const FLOCK_BODY_CLEARANCE: StringName = &"flock_body_clearance"
const BELL_STOP_DISTANCE: StringName = &"bell_stop_distance"
const BELL_FOLLOW_TIME: StringName = &"bell_follow_time"

# --- Sheep motion ------------------------------------------------------------
const SHEEP_ACCELERATION: StringName = &"sheep_acceleration"
const SHEEP_TURN_RATE_DEG: StringName = &"sheep_turn_rate_deg"

# --- Arena -------------------------------------------------------------------
const ARENA_WIDTH: StringName = &"arena_width"
const ARENA_HEIGHT: StringName = &"arena_height"

# --- Perks -------------------------------------------------------------------
const PERK_WIDE_FLASHLIGHT_ANGLE_DEG: StringName = &"perk_wide_flashlight_angle_deg"
const PERK_LONG_FLASHLIGHT_LENGTH: StringName = &"perk_long_flashlight_length"
const PERK_FASTER_RELOAD_TIME: StringName = &"perk_faster_reload_time"
const PERK_SPARE_BULLET_AMMO: StringName = &"perk_spare_bullet_ammo"
const PERK_FASTER_CONSUMPTION_DURATION: StringName = &"perk_faster_consumption_duration"
const INVISIBILITY_MAX_DURATION: StringName = &"invisibility_max_duration"
const INVISIBILITY_DRAIN_STILL: StringName = &"invisibility_drain_still"
const INVISIBILITY_DRAIN_MOVING: StringName = &"invisibility_drain_moving"
const INVISIBILITY_COOLDOWN: StringName = &"invisibility_cooldown"
const BAT_DISRUPTION_DURATION: StringName = &"bat_disruption_duration"
const BAT_CONE_SHRINK: StringName = &"bat_cone_shrink"
const BAT_COOLDOWN: StringName = &"bat_cooldown"

# --- Audio -------------------------------------------------------------------
const HEARING_RANGE_QUIET: StringName = &"hearing_range_quiet"
const HEARING_RANGE_LOUD: StringName = &"hearing_range_loud"

# --- Network -----------------------------------------------------------------
const NET_TICK_RATE: StringName = &"net_tick_rate"
const NET_INTERPOLATION_DELAY: StringName = &"net_interpolation_delay"
const NET_MAX_EXTRAPOLATION: StringName = &"net_max_extrapolation"
const NET_CONNECT_TIMEOUT: StringName = &"net_connect_timeout"
const NET_CLOCK_SYNC_INTERVAL: StringName = &"net_clock_sync_interval"

# --- View --------------------------------------------------------------------
const VIEW_MAX_WORLD_WIDTH: StringName = &"view_max_world_width"
const VIEW_MAX_WORLD_HEIGHT: StringName = &"view_max_world_height"


## All stat ids, read from this script's constants.
static func all() -> Array[StringName]:
	var ids: Array[StringName] = []
	var constants: Dictionary = (StatIds as Script).get_script_constant_map()
	for key: String in constants:
		if constants[key] is StringName:
			ids.append(constants[key])
	return ids
