class_name NetTransform2D
extends Node
## Replicates the 2D position and rotation of its parent.
##
## Add it as a child of an entity that is spawned through the
## [NetEntityRegistry]. On the device that owns the entity, the parent is
## moved by the game and this node reports its transform for the snapshots.
## On the other device, this node moves the parent, smoothly, a little in the
## past (see [InterpolationBuffer]).
##
## [b]Uniform presentation.[/b] An entity that is simulated on this device
## would look smoother than one that arrives over the network, and that
## difference would give the Monster away among the NPC sheep. Entities that
## must be indistinguishable therefore set [member delayed_visual]: their
## visible part is then drawn through the same buffer and the same delay on
## the owning device as on the other one.

## Optional. The visible part of the entity. When set, the owning device
## draws it from the interpolation buffer instead of the live transform.
## Leave it empty for the character the local player controls: its picture
## must follow the input without delay.
@export var delayed_visual: Node2D

var _buffer: InterpolationBuffer = InterpolationBuffer.new()
var _is_authority: bool = true
var _target: Node2D


func _ready() -> void:
	_target = get_parent() as Node2D
	if _target == null:
		push_error("NetTransform2D must be the child of a Node2D.")


## Called by the registry when the entity is spawned.
func configure(is_authority: bool, max_extrapolation: float) -> void:
	_is_authority = is_authority
	_buffer.clear()
	_buffer.max_extrapolation = max_extrapolation
	if _target == null:
		_target = get_parent() as Node2D
	if delayed_visual != null:
		# The visual gets its transform from the buffer, not from its parent.
		delayed_visual.top_level = _is_authority
		if _is_authority and _target != null and _target.is_inside_tree():
			delayed_visual.global_transform = _target.global_transform


func is_authority() -> bool:
	return _is_authority


## Owning device: reads the parent's transform at [param time] for a snapshot.
func capture(time: float) -> Array:
	var position: Vector2 = _target.global_position
	var rotation: float = _target.global_rotation
	if delayed_visual != null:
		_buffer.push(time, position, rotation)
	return [position.x, position.y, rotation]


## Other device: takes what [method capture] produced on the owning device,
## from a snapshot sent at [param time].
func receive(time: float, state: Array) -> void:
	if not _is_authority:
		_buffer.push(time, Vector2(state[0], state[1]), state[2])


## Shows the entity as it was at [param render_time]. Called every frame.
func present(render_time: float) -> void:
	if _buffer.is_empty():
		return
	var shown: Node2D = delayed_visual if _is_authority else _target
	if shown == null:
		return
	shown.global_position = _buffer.sample_position(render_time)
	shown.global_rotation = _buffer.sample_rotation(render_time)
