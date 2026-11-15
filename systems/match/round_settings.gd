class_name RoundSettings
extends RefCounted
## The numbers one round is played by (GDD §5, Match Rules).
##
## The [MatchFlow] fills them in at the start of a round, from the stats with
## the round's perks applied, and hands them to the [RoundRules]. Plain data,
## so the rules need nothing but this to decide a round.

## Length of the round in seconds.
var round_duration: float = 0.0
## NPC sheep at the start of the round.
var flock_size: int = 0
## Sheep the Monster must have eaten before it can kill the Sheepherder.
var herder_kill_threshold: int = 0
## Sheepherder points per NPC sheep alive at the end of the round.
var herder_points_per_surviving_sheep: int = 0
## Sheepherder points per NPC sheep they shot (a penalty).
var herder_points_per_shot_sheep: int = 0
## Monster points per NPC sheep it ate alive.
var monster_points_per_eaten_sheep: int = 0


## The settings of a round without perks: the configured values.
static func from_config(config: GameConfig) -> RoundSettings:
	var settings: RoundSettings = RoundSettings.new()
	settings.round_duration = config.round_duration
	settings.flock_size = config.flock_size
	settings.herder_kill_threshold = config.herder_kill_threshold
	settings.herder_points_per_surviving_sheep = config.herder_points_per_surviving_sheep
	settings.herder_points_per_shot_sheep = config.herder_points_per_shot_sheep
	settings.monster_points_per_eaten_sheep = config.monster_points_per_eaten_sheep
	return settings
