class_name SpatialAudioService
extends AudioService
## [AudioService] that plays the sounds of the [AudioCatalog] where they happen,
## heard from the local player's character (GDD §7.2).
##
## - Every positional sound is an [AudioStreamPlayer2D] under this node
##   ([AudioMix]): it fades to silence at the end of its event's hearing range
##   and pans by where it is across the screen, whether or not its source can
##   be seen.
## - The ear is an [AudioListener2D] of its own that follows the listener but
##   never turns, so left and right are those of the screen. Without a
##   listener nothing positional plays.
## - Looping sounds of the listener's own character play
##   [member GameConfig.audio_own_sound_volume_db] quieter on this device.
## - Bus volumes are kept in [member settings_path]. In the Web build every
##   sound is muted while the page is hidden.

const DEFAULT_SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "audio"
const BUSES: Array[StringName] = [BUS_MASTER, BUS_EFFECTS, BUS_AMBIENCE, BUS_UI]
## After the frame's entities moved and were shown.
const FOLLOW_PRIORITY: int = 1000
const SILENT_DB: float = -80.0


## A looping sound that follows a node.
class Emitter:
	var target: Node2D
	var cue: AudioCue
	## Null when the event has no sound.
	var player: AudioStreamPlayer2D
	var playing: bool = false
	## Whether it can be heard: playing, and there is a listener. While it
	## cannot, its player is stopped rather than paused: Godot loses a pause
	## that comes in the frame a sound starts, and a paused stream and a paused
	## sample answer [member AudioStreamPlayer2D.playing] differently.
	var audible: bool = false


## Where the bus volumes are kept; empty keeps them for this run only.
var settings_path: String = DEFAULT_SETTINGS_PATH
## The playback type of sounds started from now on. The default is the
## project's: Sample in the Web build, Stream elsewhere.
var playback_type: AudioServer.PlaybackType = AudioServer.PLAYBACK_TYPE_DEFAULT

var _config: GameConfig
var _catalog: AudioCatalog
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _listener: Node2D
var _ear: AudioListener2D = AudioListener2D.new()
var _emitters: Dictionary[int, Emitter] = {}
var _next_handle: int = 1
var _one_shots: Node = Node.new()
var _document: JavaScriptObject
## Kept, or JavaScript can no longer call it.
var _visibility_callback: JavaScriptObject


func _init(config: GameConfig = null, catalog: AudioCatalog = null) -> void:
	_config = config if config != null else GameConfig.new()
	_catalog = catalog if catalog != null else AudioCatalog.load_default()
	process_priority = FOLLOW_PRIORITY
	_ear.name = "Ear"
	add_child(_ear)
	_one_shots.name = "OneShots"
	add_child(_one_shots)


func _ready() -> void:
	_load_bus_volumes()
	_watch_page_visibility()


func _process(_delta: float) -> void:
	var listener: Node2D = get_listener()
	if listener != null:
		_ear.global_position = listener.global_position
	for emitter: Emitter in _emitters.values():
		if emitter.player != null and is_instance_valid(emitter.target):
			emitter.player.global_position = emitter.target.global_position


func play_event(event_id: StringName, world_position: Vector2) -> void:
	event_played.emit(event_id, world_position)
	var cue: AudioCue = _catalog.get_cue(event_id)
	if cue == null or cue.streams.is_empty() or get_listener() == null:
		return
	var player: AudioStreamPlayer2D = _new_player(event_id, cue)
	player.stream = cue.streams[_random.randi_range(0, cue.streams.size() - 1)]
	if cue.pitch_variation > 0.0:
		player.pitch_scale = 1.0 + _random.randf_range(-cue.pitch_variation, cue.pitch_variation)
	player.position = world_position
	player.finished.connect(player.queue_free)
	_one_shots.add_child(player)
	player.play()


func play_ui(event_id: StringName) -> void:
	var cue: AudioCue = _catalog.get_cue(event_id)
	if cue == null or cue.streams.is_empty():
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = cue.streams[_random.randi_range(0, cue.streams.size() - 1)]
	player.bus = cue.bus
	player.volume_db = cue.volume_db
	player.playback_type = playback_type
	player.finished.connect(player.queue_free)
	_one_shots.add_child(player)
	player.play()


func start_emitter(event_id: StringName, target: Node2D) -> int:
	var handle: int = _next_handle
	_next_handle += 1
	var emitter: Emitter = Emitter.new()
	emitter.target = target
	emitter.cue = _catalog.get_cue(event_id)
	if emitter.cue != null and not emitter.cue.streams.is_empty():
		emitter.player = _new_player(event_id, emitter.cue)
		emitter.player.stream = emitter.cue.streams[0]
		emitter.player.position = target.global_position
		add_child(emitter.player)
	_emitters[handle] = emitter
	# One connection per target: Godot tells connections apart by the method,
	# not by what is bound to it.
	if not target.tree_exiting.is_connected(_on_target_exiting):
		target.tree_exiting.connect(_on_target_exiting.bind(target))
	_apply_volume(emitter)
	return handle


func set_emitter_playing(handle: int, playing: bool) -> void:
	var emitter: Emitter = _emitters.get(handle)
	if emitter == null:
		return
	emitter.playing = playing
	_update_emitter(emitter)


func stop_emitter(handle: int, fade_seconds: float = 0.0) -> void:
	var emitter: Emitter = _emitters.get(handle)
	if emitter == null:
		return
	_emitters.erase(handle)
	_release_target(emitter.target)
	if emitter.player != null:
		_fade_out(emitter.player, fade_seconds)


func stop_all(fade_seconds: float = 0.0) -> void:
	for handle: int in _emitters.keys():
		stop_emitter(handle, fade_seconds)
	for player: Node in _one_shots.get_children():
		_fade_out(player, fade_seconds)


func set_listener(listener: Node2D) -> void:
	_listener = listener
	if listener != null:
		_ear.global_position = listener.global_position
		_ear.make_current()
	else:
		_ear.clear_current()
		# Without a listener Godot would hear from the middle of the screen.
		for player: Node in _one_shots.get_children():
			if player is AudioStreamPlayer2D:
				player.queue_free()
	for emitter: Emitter in _emitters.values():
		_apply_volume(emitter)
		_update_emitter(emitter)


func get_listener() -> Node2D:
	return _listener if is_instance_valid(_listener) else null


func get_hearing_range(event_id: StringName) -> float:
	return AudioMix.hearing_range(_config, event_id)


func set_bus_volume(bus: StringName, linear_volume: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		push_error("SpatialAudioService: there is no bus '%s'." % bus)
		return
	AudioServer.set_bus_volume_linear(index, clampf(linear_volume, 0.0, 1.0))
	_save_bus_volumes()


func get_bus_volume(bus: StringName) -> float:
	var index: int = AudioServer.get_bus_index(bus)
	return AudioServer.get_bus_volume_linear(index) if index >= 0 else 1.0


## The number of emitters that were started and not stopped.
func get_emitter_count() -> int:
	return _emitters.size()


## The player of the emitter [param handle], or [code]null[/code]. For tests
## and the sound check.
func get_emitter_player(handle: int) -> AudioStreamPlayer2D:
	var emitter: Emitter = _emitters.get(handle)
	return emitter.player if emitter != null else null


## The one-shots that are playing now. For tests and the sound check.
func get_one_shot_players() -> Array[Node]:
	return _one_shots.get_children()


func _new_player(event_id: StringName, cue: AudioCue) -> AudioStreamPlayer2D:
	var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	player.name = String(event_id)
	player.playback_type = playback_type
	AudioMix.configure(player, _config, event_id, cue)
	return player


func _on_target_exiting(target: Node2D) -> void:
	for handle: int in _emitters.keys():
		if _emitters[handle].target == target:
			stop_emitter(handle)


## Lets go of [param target] once none of its emitters is left.
func _release_target(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	for emitter: Emitter in _emitters.values():
		if emitter.target == target:
			return
	if target.tree_exiting.is_connected(_on_target_exiting):
		target.tree_exiting.disconnect(_on_target_exiting)


func _is_own(emitter: Emitter) -> bool:
	var listener: Node2D = get_listener()
	if listener == null or not is_instance_valid(emitter.target):
		return false
	return emitter.target == listener or listener.is_ancestor_of(emitter.target)


func _apply_volume(emitter: Emitter) -> void:
	if emitter.player == null:
		return
	var own: float = _config.audio_own_sound_volume_db if _is_own(emitter) else 0.0
	emitter.player.volume_db = emitter.cue.volume_db + own


func _update_emitter(emitter: Emitter) -> void:
	var player: AudioStreamPlayer2D = emitter.player
	if player == null:
		return
	var audible: bool = emitter.playing and get_listener() != null
	if audible == emitter.audible:
		return
	emitter.audible = audible
	if not audible:
		player.stop()
		return
	# Always from the start: in the Web build every loop of a sample begins
	# again where the sample was started (docs/audio.md).
	player.play()


func _fade_out(player: Node, fade_seconds: float) -> void:
	if fade_seconds <= 0.0 or not player.is_inside_tree():
		player.queue_free()
		return
	var tween: Tween = player.create_tween()
	tween.tween_property(player, ^"volume_db", SILENT_DB, fade_seconds)
	tween.tween_callback(player.queue_free)


func _load_bus_volumes() -> void:
	if settings_path.is_empty():
		return
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(settings_path) != OK:
		return
	for bus: StringName in BUSES:
		var index: int = AudioServer.get_bus_index(bus)
		if index >= 0 and settings.has_section_key(SETTINGS_SECTION, bus):
			var volume: float = settings.get_value(SETTINGS_SECTION, bus)
			AudioServer.set_bus_volume_linear(index, clampf(volume, 0.0, 1.0))


func _save_bus_volumes() -> void:
	if settings_path.is_empty():
		return
	var settings: ConfigFile = ConfigFile.new()
	settings.load(settings_path)
	for bus: StringName in BUSES:
		settings.set_value(SETTINGS_SECTION, bus, get_bus_volume(bus))
	var error: Error = settings.save(settings_path)
	if error != OK:
		push_warning("SpatialAudioService: could not save the volumes (%s)." % error_string(error))


func _watch_page_visibility() -> void:
	if not OS.has_feature("web"):
		return
	_document = JavaScriptBridge.get_interface("document")
	if _document == null:
		return
	_visibility_callback = JavaScriptBridge.create_callback(_on_page_visibility_changed)
	_document.call(&"addEventListener", "visibilitychange", _visibility_callback)
	_on_page_visibility_changed([])


func _on_page_visibility_changed(_arguments: Array) -> void:
	var hidden: bool = _document.hidden
	AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS_MASTER), hidden)
