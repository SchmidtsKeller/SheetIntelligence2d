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
