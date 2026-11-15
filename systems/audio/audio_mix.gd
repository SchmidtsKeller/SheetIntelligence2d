@abstract class_name AudioMix
extends RefCounted
## How far a sound carries and how loud it is in each ear.
##
## Playback is Godot's [AudioStreamPlayer2D]: its volume falls from full at the
## listener to zero at [member AudioStreamPlayer2D.max_distance], shaped by
## [member AudioStreamPlayer2D.attenuation], and it pans by where the sound is
## across the screen. [method ear_gains] states that formula (Godot 4.7,
## [code]scene/2d/audio_stream_player_2d.cpp[/code]), so that tests and the
## sound check can say what a listener should hear.

const GLOBAL_PANNING_SETTING: String = "audio/general/2d_panning_strength"


## How far [param event_id] carries, in pixels; [constant @GDScript.INF] for
## events that are audible on the whole map (GDD §5).
static func hearing_range(config: GameConfig, event_id: StringName) -> float:
	match AudioEvents.range_class_of(event_id):
		GameEnums.HearingRange.WHOLE_MAP:
			return INF
		GameEnums.HearingRange.LOUD:
			return config.hearing_range_loud
		_:
			return config.hearing_range_quiet


## Where [param event_id] fades to silence: the end of its hearing range, or
## for whole-map events [member GameConfig.audio_whole_map_distance].
static func fade_distance(config: GameConfig, event_id: StringName) -> float:
	var hearing: float = hearing_range(config, event_id)
	return config.audio_whole_map_distance if is_inf(hearing) else hearing


## Sets up [param player] to play [param cue] for [param event_id].
static func configure(
	player: AudioStreamPlayer2D, config: GameConfig, event_id: StringName, cue: AudioCue
) -> void:
	player.bus = cue.bus
	player.volume_db = cue.volume_db
	player.max_distance = fade_distance(config, event_id)
	player.attenuation = cue.attenuation
	player.panning_strength = config.audio_panning_strength


## The volume in the left ear ([code]x[/code]) and the right ear
## ([code]y[/code]), each 0 to 1, of a sound [param offset] away from the
## listener. [param visible_world_width] is how much of the world the screen
## shows across: panning goes by the share of the screen, as in Godot.
static func ear_gains(
	offset: Vector2,
	distance: float,
	attenuation: float,
	panning_strength: float,
	visible_world_width: float
) -> Vector2:
	var length: float = offset.length()
	if distance <= 0.0 or length >= distance or visible_world_width <= 0.0:
		return Vector2.ZERO
	var level: float = pow(1.0 - length / distance, attenuation)
	var global: float = ProjectSettings.get_setting(GLOBAL_PANNING_SETTING, 0.5)
	var pan: float = clampf(offset.x / visible_world_width, -1.0, 1.0)
	pan = clampf(pan * panning_strength * global * 0.5 + 0.5, 0.0, 1.0)
	return Vector2(1.0 - pan, pan) * level
