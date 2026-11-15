@abstract class_name AudioService
extends Node
## Contract for sound (GDD §7.2).
##
## Gameplay code names a sound event (see [AudioEvents]) and where it happens;
## the service picks the sound and makes it distance- and direction-dependent
## relative to the listener, which is the local player's character. A sound is
## audible whether or not its source is visible: hearing is how players track
## what the fog of war hides.

## A positional event was played. For debugging and tests; gameplay must not
## depend on it.
@warning_ignore("unused_signal")
signal event_played(event_id: StringName, world_position: Vector2)

## Volume buses.
const BUS_MASTER: StringName = &"Master"
const BUS_EFFECTS: StringName = &"Effects"
const BUS_AMBIENCE: StringName = &"Ambience"
const BUS_UI: StringName = &"UI"

## Plays a one-shot event at [param world_position]. It is inaudible beyond
## the hearing range of its range class (GDD §5).
@abstract func play_event(event_id: StringName, world_position: Vector2) -> void

## Plays a sound that is not placed in the world (menus, HUD feedback).
@abstract func play_ui(event_id: StringName) -> void

## Starts a looping sound that follows [param target] (e.g. the rustle of a
## sheep moving through grass) and returns a handle for the other emitter
## methods. The emitter stops by itself when [param target] leaves the tree.
@abstract func start_emitter(event_id: StringName, target: Node2D) -> int

## Pauses or resumes an emitter without discarding it, e.g. rustle only while
## the sheep is moving.
@abstract func set_emitter_playing(handle: int, playing: bool) -> void

## Stops and discards an emitter, fading out over [param fade_seconds].
## Unknown handles are ignored.
@abstract func stop_emitter(handle: int, fade_seconds: float = 0.0) -> void

## Stops every sound and emitter, fading out over [param fade_seconds]
## (round end, leaving a scene).
@abstract func stop_all(fade_seconds: float = 0.0) -> void

## Plays [param layers] (see [constant AudioEvents.AMBIENCE]) as the
## background, on the ambience bus and not placed in the world, instead of the
## layers before. Looping layers loop; a layer of one-shots repeats at random
## times. An empty list stops the ambience. Fades over [param fade_seconds].
@abstract func set_ambience(layers: Array[StringName], fade_seconds: float = 1.0) -> void

## The layers of the ambience that plays now.
@abstract func get_ambience() -> Array[StringName]

## Sets the node sounds are heard from. [code]null[/code] removes the listener;
## positional sounds are then silent.
@abstract func set_listener(listener: Node2D) -> void

## The node sounds are heard from, or [code]null[/code].
@abstract func get_listener() -> Node2D

## How far [param event_id] carries, in pixels. [constant @GDScript.INF] for
## events that are audible on the whole map.
@abstract func get_hearing_range(event_id: StringName) -> float

## Sets the volume of [param bus] (one of the [code]BUS_*[/code] constants)
## as a linear factor from 0 to 1.
@abstract func set_bus_volume(bus: StringName, linear_volume: float) -> void

## The volume of [param bus] as a linear factor from 0 to 1.
@abstract func get_bus_volume(bus: StringName) -> float
