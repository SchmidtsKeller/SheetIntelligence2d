class_name AudioCue
extends Resource
## How one sound event sounds: its variations, its bus, its volume and how it
## fades with distance. How far it carries is its hearing-range class in
## [AudioEvents].

## The variations; each one-shot picks one at random. A looping sound (an
## emitter) uses the first, which must have its loop enabled on import.
@export var streams: Array[AudioStream] = []
## The bus it plays on, one of the [code]AudioService.BUS_*[/code] constants.
@export var bus: StringName = &"Effects"
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var volume_db: float = 0.0
## Each one-shot plays at a random pitch within this share above or below 1.
@export_range(0.0, 0.5, 0.01) var pitch_variation: float = 0.0
## Exponent of the fade with distance: 1 fades the volume evenly to zero at
## the end of the hearing range, more fades it sooner.
@export_range(0.1, 4.0, 0.05) var attenuation: float = 1.0
