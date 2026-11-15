class_name SheepNetSync
extends NetTransform2D
## Replicates a [SheepBody]: where it is, where it faces, and whether it grazes.
##
## The owning device simulates the sheep and sends its state in the snapshots.
## The other device puts the body there. On [b]both[/b] devices the sheep is
## then shown from the same interpolation buffer, a moment in the past: its
## picture, its walk animation and its grazing all come from that one delayed
## state. A sheep this device simulates therefore looks no more current than
## one that arrives over the network, which is what keeps the Monster hidden
## in the flock (docs/networking.md, uniform presentation).
##
## Grazing and running (faster than a sheep can, see [method SheepBody.is_running])
## travel with the transform rather than as events, so they are shown at the
## matching moment and recover by themselves after lost packets.

const FLAG_GRAZING: int = 1
const FLAG_RUNNING: int = 2

## Shows the sheep live instead of delayed on the device that simulates it.
## Only for the sheep the local player steers: its picture has to follow the
## input, and its player knows who they are anyway.
var live_on_owner: bool = false

var _body: SheepBody
var _shown_position: Vector2 = Vector2.ZERO
var _shown_time: float = -1.0


func configure(is_authority: bool, max_extrapolation: float) -> void:
	super(is_authority, max_extrapolation)
	_body = get_parent() as SheepBody
	if _body == null:
		push_error("SheepNetSync must be the child of a SheepBody.")
		return
	_body.simulated = is_authority
	_body.presented_externally = not (is_authority and live_on_owner)
	_shown_time = -1.0


func capture(time: float) -> Array:
	var position: Vector2 = _body.global_position
	var heading: float = _body.get_heading()
	var flags: int = FLAG_GRAZING if _body.is_grazing() else 0
	if _body.is_running():
		flags |= FLAG_RUNNING
	_buffer.push(time, position, heading, flags)
	return [position.x, position.y, heading, flags]


func receive(time: float, state: Array) -> void:
	if not _is_authority:
		_buffer.push(time, Vector2(state[0], state[1]), state[2], state[3])


func present(render_time: float) -> void:
	if _body == null or _buffer.is_empty():
		return
	var position: Vector2 = _buffer.sample_position(render_time)
	# The walk animation follows the speed of what is shown.
	var speed: float = 0.0
	if _shown_time >= 0.0 and render_time > _shown_time:
		speed = position.distance_to(_shown_position) / (render_time - _shown_time)
	_shown_position = position
	_shown_time = render_time
	if not _is_authority:
		# The body follows too: it is what other characters bump into and what
		# line-of-sight checks see on this device.
		_body.global_position = position
	if _body.presented_externally:
		var flags: int = _buffer.sample_flags(render_time)
		var grazing: bool = flags & FLAG_GRAZING != 0
		var running: bool = flags & FLAG_RUNNING != 0
		_body.present(position, _buffer.sample_rotation(render_time), speed, grazing, running)
