class_name AudioCatalog
extends Resource
## The sound of every event in [AudioEvents] (GDD §7.2), one [AudioCue] each.
## The sound pass (#23) replaces the placeholder sounds here; nothing else has
## to change.

const DEFAULT_PATH: String = "res://systems/audio/audio_catalog.tres"

@export var cues: Dictionary[StringName, AudioCue] = {}


## The shipped catalog.
static func load_default() -> AudioCatalog:
	return load(DEFAULT_PATH) as AudioCatalog


## The cue of [param event_id], or [code]null[/code].
func get_cue(event_id: StringName) -> AudioCue:
	return cues.get(event_id)
