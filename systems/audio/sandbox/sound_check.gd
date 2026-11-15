extends Node2D
## Sound check (#10): one sound source around the listener in the middle, to
## hear whether sounds come from the right side and fade out at the end of
## their range, in both playback types of the Web build.
##
## Run it with F6, or open the Web build with [code]?sound-check[/code] in the
## address. The buttons choose the sound, how it moves, how far away it
## circles and (Web build) the playback type; a click or tap places the
## source, P plays a one-shot sound at once. The read-out says how far away
## the source is and how loud it should be in each ear.
##
## The address can set it up as well, for scripted measurements
## (docs/audio.md): [code]sound=<event id>[/code] or [code]tone-quiet[/code],
## [code]tone-loud[/code], [code]tone-whole[/code], [code]tone-burst[/code];
## [code]motion=orbit|sweep|still[/code]; [code]mode=sample|stream[/code];
## [code]repeat=0[/code] plays one-shots only on P; and
## [code]probe=<x>:<y>,<x>:<y>,…[/code] stands the source at each position in
## turn for [code]dwell[/code] seconds and announces each step in
## [code]window.soundCheckStep[/code].

enum Motion { ORBIT, SWEEP, STILL }

const LOOPING: Array[StringName] = [
	AudioEvents.GRASS_MOVE, AudioEvents.GRASS_RUN, AudioEvents.GRAZE, AudioEvents.HERDER_STEP
]
const TONES: Dictionary[String, StringName] = {
	"tone-quiet": AudioEvents.GRASS_MOVE,
	"tone-loud": AudioEvents.BLEAT,
	"tone-whole": AudioEvents.BELL,
	"tone-burst": AudioEvents.GUNSHOT,
}
const ORBIT_RADII: Array[float] = [150.0, 300.0, 500.0, 700.0, 900.0]
const ORBIT_PERIOD: float = 8.0
const SWEEP_WIDTH: float = 1000.0
const REPEAT_INTERVAL: float = 2.0
const TONE_RATE: int = 44100
## 100 samples per period, so that the looping tone has no seam.
const TONE_FREQUENCY: int = 441
const COLOURS: Dictionary[GameEnums.HearingRange, Color] = {
	GameEnums.HearingRange.QUIET: Color(0.55, 0.8, 0.45),
	GameEnums.HearingRange.LOUD: Color(0.95, 0.75, 0.3),
	GameEnums.HearingRange.WHOLE_MAP: Color(0.9, 0.4, 0.35),
}

var _config: GameConfig
var _catalog: AudioCatalog
## The game's sounds and the test tones, each heard through its own service.
var _sounds: SpatialAudioService
var _tones: SpatialAudioService
var _keys: Array[String] = []
var _key_index: int = 0
var _motion: Motion = Motion.ORBIT
var _radius_index: int = 1
var _sample: bool = OS.has_feature("web")
var _repeat: bool = true
var _time: float = 0.0
var _repeat_left: float = 0.0
var _emitter: int = 0
var _emitter_service: SpatialAudioService
var _probe: Array[Vector2] = []
var _probe_index: int = -1
var _dwell: float = 0.8
var _dwell_left: float = 0.0

var _listener: Node2D = Node2D.new()
var _source: Node2D = Node2D.new()
var _camera: Camera2D = Camera2D.new()
var _readout: Label = Label.new()
var _sound_button: Button = Button.new()
var _motion_button: Button = Button.new()
var _radius_button: Button = Button.new()
var _mode_button: Button = Button.new()
var _volume: HSlider = HSlider.new()


func _ready() -> void:
	_config = Services.config
	_catalog = AudioCatalog.load_default()
	_sounds = _new_service(_catalog)
	_tones = _new_service(_tone_catalog())
	for event_id: StringName in AudioEvents.ALL:
		_keys.append(String(event_id))
	_keys.append_array(TONES.keys())
	add_child(_listener)
	add_child(_source)
	add_child(_camera)
	_camera.make_current()
	get_viewport().size_changed.connect(_update_zoom)
	_update_zoom()
	_build_ui()
	_read_address()
	_restart_sound()


func _exit_tree() -> void:
	_sounds.stop_all()
	_tones.stop_all()


func _process(delta: float) -> void:
	_time += delta
	_move_source(delta)
	if not _is_looping() and _repeat:
		_repeat_left -= delta
		if _repeat_left <= 0.0:
			_repeat_left = REPEAT_INTERVAL
			_play_once()
	_readout.text = _describe()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_P:
		_play_once()
		get_viewport().set_input_as_handled()
	# A tap arrives as a click as well.
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed:
		_motion = Motion.STILL
		_probe.clear()
		_source.global_position = get_global_mouse_position()
		_update_buttons()


func _draw() -> void:
	draw_rect(Rect2(-1600.0, -1200.0, 3200.0, 2400.0), Color(0.08, 0.1, 0.08))
	for step: int in range(-1600, 1601, 200):
		draw_line(Vector2(step, -1200.0), Vector2(step, 1200.0), Color(1, 1, 1, 0.05))
		draw_line(Vector2(-1600.0, step), Vector2(1600.0, step), Color(1, 1, 1, 0.05))
	var quiet: Color = COLOURS[GameEnums.HearingRange.QUIET]
	var loud: Color = COLOURS[GameEnums.HearingRange.LOUD]
	draw_arc(Vector2.ZERO, _config.hearing_range_quiet, 0.0, TAU, 96, quiet, 3.0)
	draw_arc(Vector2.ZERO, _config.hearing_range_loud, 0.0, TAU, 128, loud, 3.0)
	draw_circle(Vector2.ZERO, 18.0, Color(0.85, 0.85, 0.9))
	draw_line(Vector2(-30.0, 0.0), Vector2(-14.0, 0.0), Color.BLACK, 4.0)
	draw_line(Vector2(14.0, 0.0), Vector2(30.0, 0.0), Color.BLACK, 4.0)
	draw_circle(_source.position, 14.0, COLOURS[_range_class()])


# --- Sound ---------------------------------------------------------------------------


func _new_service(catalog: AudioCatalog) -> SpatialAudioService:
	var service: SpatialAudioService = SpatialAudioService.new(_config, catalog)
	service.settings_path = ""
	add_child(service)
	return service


## The event whose hearing range and cue the current sound uses.
func _event_id() -> StringName:
	var key: String = _keys[_key_index]
	return TONES.get(key, StringName(key))


func _service() -> SpatialAudioService:
	return _tones if TONES.has(_keys[_key_index]) else _sounds


func _is_looping() -> bool:
	var key: String = _keys[_key_index]
	return LOOPING.has(_event_id()) or (TONES.has(key) and key != "tone-burst")


func _range_class() -> GameEnums.HearingRange:
	return AudioEvents.range_class_of(_event_id())


func _restart_sound() -> void:
	if _emitter_service != null:
		_emitter_service.stop_emitter(_emitter)
		_emitter_service = null
	var playback: AudioServer.PlaybackType = (
		AudioServer.PLAYBACK_TYPE_SAMPLE if _sample else AudioServer.PLAYBACK_TYPE_STREAM
	)
	for service: SpatialAudioService in [_sounds, _tones]:
		service.stop_all()
		service.playback_type = playback
		service.set_listener(null)
	var service: SpatialAudioService = _service()
	service.set_listener(_listener)
	if _is_looping():
		_emitter_service = service
		_emitter = service.start_emitter(_event_id(), _source)
		service.set_emitter_playing(_emitter, true)
	_repeat_left = 0.0
	_update_buttons()


func _play_once() -> void:
	if not _is_looping():
		_service().play_event(_event_id(), _source.global_position)


## The game's sounds as they are, a steady tone for the tone keys of the
## looping kind, and a short tone burst for the gunshot.
static func _tone_catalog() -> AudioCatalog:
	var catalog: AudioCatalog = AudioCatalog.new()
	for event_id: StringName in AudioEvents.ALL:
		var cue: AudioCue = AudioCue.new()
		var burst: bool = event_id == AudioEvents.GUNSHOT
		cue.streams = [_tone(0.25 if burst else 1.0, not burst)]
		catalog.cues[event_id] = cue
	return catalog


static func _tone(seconds: float, loop: bool) -> AudioStreamWAV:
	var frames: int = roundi(seconds * TONE_FREQUENCY) * roundi(float(TONE_RATE) / TONE_FREQUENCY)
	var data: PackedByteArray = PackedByteArray()
	data.resize(frames * 2)
	for i: int in frames:
		var phase: float = TAU * float(TONE_FREQUENCY) * i / TONE_RATE
		data.encode_s16(i * 2, roundi(sin(phase) * 16000.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = TONE_RATE
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = frames
	return stream


# --- Source --------------------------------------------------------------------------


func _move_source(delta: float) -> void:
	if not _probe.is_empty():
		_dwell_left -= delta
		if _dwell_left <= 0.0 and _probe_index < _probe.size() - 1:
			_probe_index += 1
			_dwell_left = _dwell
			_source.position = _probe[_probe_index]
			_announce_step()
		return
	match _motion:
		Motion.ORBIT:
			var angle: float = _time / ORBIT_PERIOD * TAU
			_source.position = Vector2.from_angle(angle) * ORBIT_RADII[_radius_index]
		Motion.SWEEP:
			_source.position = Vector2(sin(_time / ORBIT_PERIOD * TAU) * SWEEP_WIDTH, 0.0)


func _update_zoom() -> void:
	var zoom: float = ViewRules.camera_zoom(
		get_viewport_rect().size, _config.get_view_max_world_size()
	)
	_camera.zoom = Vector2(zoom, zoom)


func _expected_gains() -> Vector2:
	var cue_attenuation: float = 1.0
	var cue: AudioCue = _catalog.get_cue(_event_id())
	if _service() == _sounds and cue != null:
		cue_attenuation = cue.attenuation
	return AudioMix.ear_gains(
		_source.position,
		AudioMix.fade_distance(_config, _event_id()),
		cue_attenuation,
		_config.audio_panning_strength,
		get_viewport_rect().size.x / _camera.zoom.x
	)


func _announce_step() -> void:
	if not OS.has_feature("web"):
		return
	var gains: Vector2 = _expected_gains()
	var step: Dictionary = {
		"index": _probe_index,
		"x": _source.position.x,
		"y": _source.position.y,
		"left": gains.x,
		"right": gains.y,
	}
	JavaScriptBridge.eval(
		(
			"window.soundCheckStep = Object.assign(%s, {time: performance.now()});"
			% JSON.stringify(step)
		)
	)


# --- Address -------------------------------------------------------------------------


func _read_address() -> void:
	if not OS.has_feature("web"):
		return
	var query: String = str(JavaScriptBridge.eval("location.search"))
	for pair: String in query.trim_prefix("?").split("&", false):
		var name: String = pair.get_slice("=", 0)
		var value: String = pair.get_slice("=", 1).uri_decode() if pair.contains("=") else ""
		match name:
			"sound":
				_key_index = maxi(_keys.find(value), 0)
			"motion":
				_motion = Motion.get(value.to_upper(), Motion.ORBIT)
			"mode":
				_sample = value != "stream"
			"repeat":
				_repeat = value != "0"
			"dwell":
				_dwell = maxf(value.to_float(), 0.1)
			"probe":
				for point: String in value.split(",", false):
					var x: float = point.get_slice(":", 0).to_float()
					_probe.append(Vector2(x, point.get_slice(":", 1).to_float()))
	if not _probe.is_empty():
		_motion = Motion.STILL


# --- Interface -----------------------------------------------------------------------


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var panel: VBoxContainer = VBoxContainer.new()
	panel.position = Vector2(16.0, 16.0)
	panel.add_theme_constant_override(&"separation", 10)
	layer.add_child(panel)
	_readout.add_theme_font_size_override(&"font_size", 20)
	panel.add_child(_readout)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	panel.add_child(row)
	for button: Button in [_sound_button, _motion_button, _radius_button, _mode_button]:
		button.custom_minimum_size = Vector2(200.0, 56.0)
		button.add_theme_font_size_override(&"font_size", 20)
		row.add_child(button)
	_sound_button.pressed.connect(_next_sound)
	_motion_button.pressed.connect(_next_motion)
	_radius_button.pressed.connect(_next_radius)
	_mode_button.pressed.connect(_toggle_mode)
	_mode_button.disabled = not OS.has_feature("web")
	_volume.custom_minimum_size = Vector2(420.0, 40.0)
	_volume.max_value = 1.0
	_volume.step = 0.05
	_volume.value = Services.audio.get_bus_volume(AudioService.BUS_MASTER)
	_volume.value_changed.connect(
		func(value: float) -> void: Services.audio.set_bus_volume(AudioService.BUS_MASTER, value)
	)
	panel.add_child(_volume)
	_sound_button.grab_focus.call_deferred()


func _update_buttons() -> void:
	_sound_button.text = "Sound: %s" % _keys[_key_index]
	_motion_button.text = "Motion: %s" % String(Motion.keys()[_motion]).to_lower()
	_radius_button.text = "Orbit: %d px" % ORBIT_RADII[_radius_index]
	_radius_button.disabled = _motion != Motion.ORBIT
	_mode_button.text = "Playback: %s" % ("Sample" if _sample else "Stream")


func _next_sound() -> void:
	_key_index = (_key_index + 1) % _keys.size()
	_restart_sound()


func _next_motion() -> void:
	_probe.clear()
	_motion = ((_motion + 1) % Motion.size()) as Motion
	_update_buttons()


func _next_radius() -> void:
	_radius_index = (_radius_index + 1) % ORBIT_RADII.size()
	_update_buttons()


func _toggle_mode() -> void:
	_sample = not _sample
	_restart_sound()


func _describe() -> String:
	var distance: float = AudioMix.fade_distance(_config, _event_id())
	var range_names: Dictionary[GameEnums.HearingRange, String] = {
		GameEnums.HearingRange.QUIET: "quiet",
		GameEnums.HearingRange.LOUD: "loud",
		GameEnums.HearingRange.WHOLE_MAP: "whole map",
	}
	var gains: Vector2 = _expected_gains()
	var offset: Vector2 = _source.position
	var lines: PackedStringArray = [
		(
			"Sound check · playback %s · output latency %d ms · %d Hz"
			% [
				"Sample" if _sample else "Stream",
				roundi(AudioServer.get_output_latency() * 1000.0),
				roundi(AudioServer.get_mix_rate()),
			]
		),
		(
			"%s: %s, silent from %d px%s"
			% [
				_keys[_key_index],
				range_names[_range_class()],
				roundi(distance),
				"" if _is_looping() else (" · every %d s, P plays it now" % REPEAT_INTERVAL),
			]
		),
		(
			"Source %d px %s, %d px %s · %d px away"
			% [
				absi(roundi(offset.x)),
				"right" if offset.x >= 0.0 else "left",
				absi(roundi(offset.y)),
				"down" if offset.y >= 0.0 else "up",
				roundi(offset.length()),
			]
		),
		(
			"Should be: left ear %d %%, right ear %d %%"
			% [roundi(gains.x * 100.0), roundi(gains.y * 100.0)]
		),
		"Master volume %d %% (kept for the next visit)" % roundi(_volume.value * 100.0),
	]
	return "\n".join(lines)
