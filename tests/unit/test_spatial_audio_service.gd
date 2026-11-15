extends TestCase
## The audio service: sounds play where they happen and are heard from the
## listener, as far as their hearing range (GDD §5, §7.2, #10).

const SETTINGS_PATH: String = "user://test_audio_settings.cfg"
const LOOPING: Array[StringName] = [
	AudioEvents.GRASS_MOVE,
	AudioEvents.GRASS_RUN,
	AudioEvents.GRAZE,
	AudioEvents.HERDER_STEP,
	AudioEvents.SPIDER_MOVE,
	AudioEvents.BAT_WINGS,
	AudioEvents.TORCH_BURN,
	AudioEvents.AMBIENCE_WIND,
	AudioEvents.AMBIENCE_CRICKETS,
]
const SCREEN_WIDTH: float = 1600.0

var _config: GameConfig
var _catalog: AudioCatalog
var _audio: SpatialAudioService
var _listener: Node2D
var _bus_volumes: Dictionary[StringName, float] = {}


func before_each() -> void:
	for bus: StringName in SpatialAudioService.BUSES:
		_bus_volumes[bus] = AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(bus))
	_config = GameConfig.new()
	_catalog = _catalog_of_tones()
	_audio = _new_service()
	_listener = add_child_autofree(Node2D.new())


func after_each() -> void:
	for bus: StringName in _bus_volumes:
		AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus), _bus_volumes[bus])
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


# --- The shipped sounds ------------------------------------------------------------


func test_every_event_has_a_sound() -> void:
	var catalog: AudioCatalog = AudioCatalog.load_default()

	for event_id: StringName in _every_event():
		var cue: AudioCue = catalog.get_cue(event_id)
		if assert_not_null(cue, "'%s' has a cue" % event_id):
			assert_false(cue.streams.is_empty(), "'%s' has a sound" % event_id)
			for stream: AudioStream in cue.streams:
				assert_not_null(stream, "'%s' has no empty variation" % event_id)
	assert_eq(catalog.cues.size(), _every_event().size(), "and nothing else")


func test_each_kind_of_sound_plays_on_its_bus() -> void:
	var catalog: AudioCatalog = AudioCatalog.load_default()
	var buses: Dictionary[StringName, Array] = {
		AudioService.BUS_EFFECTS: AudioEvents.ALL,
		AudioService.BUS_UI: AudioEvents.CUES,
		AudioService.BUS_AMBIENCE: AudioEvents.AMBIENCE,
	}

	for bus: StringName in buses:
		for event_id: StringName in buses[bus]:
			assert_eq(catalog.get_cue(event_id).bus, bus, "'%s'" % event_id)


func test_the_bell_and_the_gunshot_duck_the_ambience() -> void:
	var catalog: AudioCatalog = AudioCatalog.load_default()

	for event_id: StringName in _every_event():
		var ducks: bool = event_id in [AudioEvents.BELL, AudioEvents.GUNSHOT]
		assert_eq(catalog.get_cue(event_id).duck_ambience, ducks, "'%s'" % event_id)


func test_looping_sounds_loop() -> void:
	var catalog: AudioCatalog = AudioCatalog.load_default()

	for event_id: StringName in LOOPING:
		var stream: AudioStream = catalog.get_cue(event_id).streams[0]
		assert_true(_loops(stream), "'%s' loops" % event_id)
	for event_id: StringName in _every_event():
		if not LOOPING.has(event_id):
			for stream: AudioStream in catalog.get_cue(event_id).streams:
				assert_false(_loops(stream), "'%s' plays once" % event_id)
	var owl: AudioCue = catalog.get_cue(AudioEvents.AMBIENCE_OWL)
	assert_gt(owl.repeat_interval.x, 0.0, "the owl calls now and then")
	assert_gte(owl.repeat_interval.y, owl.repeat_interval.x)


func test_the_bus_layout_has_every_bus_of_the_contract() -> void:
	for bus: StringName in SpatialAudioService.BUSES:
		assert_gte(AudioServer.get_bus_index(bus), 0, "bus '%s'" % bus)


# --- How far a sound carries -------------------------------------------------------


func test_each_range_class_carries_as_far_as_the_design_document_says() -> void:
	assert_eq(_audio.get_hearing_range(AudioEvents.GRASS_MOVE), 400.0, "quiet")
	assert_eq(_audio.get_hearing_range(AudioEvents.BLEAT), 800.0, "loud")
	assert_eq(_audio.get_hearing_range(AudioEvents.BELL), INF, "whole map")


func test_whole_map_sounds_still_fade_with_distance() -> void:
	assert_eq(AudioMix.fade_distance(_config, AudioEvents.GRASS_MOVE), 400.0)
	assert_eq(AudioMix.fade_distance(_config, AudioEvents.BELL), 8000.0)
	var corner_to_corner: float = Vector2(_config.arena_width, _config.arena_height).length()
	var far: Vector2 = _ears(Vector2(corner_to_corner, 0.0), AudioEvents.BELL)
	assert_gt(far.x + far.y, 0.4, "a bell across the whole arena is still clearly heard")


func test_a_sound_fades_to_silence_at_the_end_of_its_range() -> void:
	var near: Vector2 = _ears(Vector2(0.0, 100.0), AudioEvents.GRASS_MOVE)
	var half: Vector2 = _ears(Vector2(0.0, 200.0), AudioEvents.GRASS_MOVE)

	assert_eq(_ears(Vector2.ZERO, AudioEvents.GRASS_MOVE), Vector2(0.5, 0.5), "full, centred")
	assert_almost_eq(half.x + half.y, 0.5, 0.0001, "half as loud halfway")
	assert_gt(near.x + near.y, half.x + half.y)
	assert_eq(_ears(Vector2(0.0, 400.0), AudioEvents.GRASS_MOVE), Vector2.ZERO, "silent at 400 px")
	assert_eq(_ears(Vector2(0.0, 401.0), AudioEvents.GRASS_MOVE), Vector2.ZERO)
	assert_gt(_sum(_ears(Vector2(0.0, 401.0), AudioEvents.BLEAT)), 0.0, "a bleat carries further")
	assert_eq(_ears(Vector2(0.0, 800.0), AudioEvents.BLEAT), Vector2.ZERO)


func test_a_steeper_cue_fades_sooner() -> void:
	var even: float = _sum(AudioMix.ear_gains(Vector2(200.0, 0.0), 400.0, 1.0, 1.0, SCREEN_WIDTH))
	var steep: float = _sum(AudioMix.ear_gains(Vector2(200.0, 0.0), 400.0, 2.0, 1.0, SCREEN_WIDTH))

	assert_almost_eq(steep, even * even, 0.0001)


func test_a_sound_to_the_right_is_louder_in_the_right_ear() -> void:
	var right: Vector2 = _ears(Vector2(300.0, 0.0), AudioEvents.BLEAT)
	var left: Vector2 = _ears(Vector2(-300.0, 0.0), AudioEvents.BLEAT)
	var above: Vector2 = _ears(Vector2(0.0, -300.0), AudioEvents.BLEAT)

	assert_gt(right.y, right.x)
	assert_almost_eq(left.x, right.y, 0.0001, "mirrored")
	assert_almost_eq(left.y, right.x, 0.0001)
	assert_almost_eq(above.x, above.y, 0.0001, "straight above is centred")
	assert_almost_eq(_sum(right), _sum(above), 0.0001, "panning keeps the volume")


func test_panning_follows_the_share_of_the_screen() -> void:
	var edge: Vector2 = AudioMix.ear_gains(Vector2(800.0, 0.0), 8000.0, 1.0, 3.0, SCREEN_WIDTH)
	var level: float = 1.0 - 800.0 / 8000.0

	# At the edge of a screen 1600 px wide: 0.5 + 0.5 * 3 * 0.5 * 0.5.
	assert_almost_eq(edge.y / level, 0.875, 0.0001)
	assert_almost_eq(edge.x / level, 0.125, 0.0001)
	var beyond: Vector2 = AudioMix.ear_gains(Vector2(5000.0, 0.0), 8000.0, 1.0, 3.0, SCREEN_WIDTH)
	assert_almost_eq(beyond.x, 0.0, 0.0001, "never more than fully to one side")


# --- One-shots ---------------------------------------------------------------------


func test_an_event_plays_where_it_happens_as_its_cue_says() -> void:
	_audio.set_listener(_listener)
	watch_signals(_audio)

	_audio.play_event(AudioEvents.BLEAT, Vector2(300.0, -40.0))

	var players: Array[Node] = _audio.get_one_shot_players()
	assert_eq(players.size(), 1)
	var player: AudioStreamPlayer2D = players[0] as AudioStreamPlayer2D
	var cue: AudioCue = _catalog.get_cue(AudioEvents.BLEAT)
	assert_eq(player.global_position, Vector2(300.0, -40.0))
	assert_has(cue.streams, player.stream)
	assert_eq(player.bus, cue.bus)
	assert_eq(player.volume_db, cue.volume_db)
	assert_eq(player.max_distance, 800.0)
	assert_eq(player.attenuation, cue.attenuation)
	assert_eq(player.panning_strength, _config.audio_panning_strength)
	assert_true(player.playing)
	assert_signal_emitted_with(_audio, &"event_played", [AudioEvents.BLEAT, Vector2(300.0, -40.0)])


func test_variations_and_pitch_vary_within_the_cue() -> void:
	_audio.set_listener(_listener)
	var cue: AudioCue = _catalog.get_cue(AudioEvents.BLEAT)
	var streams: Array[AudioStream] = []
	var pitches: Array[float] = []

	for _i: int in 40:
		_audio.play_event(AudioEvents.BLEAT, Vector2.ZERO)
		var player: AudioStreamPlayer2D = _audio.get_one_shot_players()[-1]
		if not streams.has(player.stream):
			streams.append(player.stream)
		pitches.append(player.pitch_scale)

	assert_eq(streams.size(), cue.streams.size(), "every variation is played")
	assert_gte(pitches.min(), 1.0 - cue.pitch_variation)
	assert_lte(pitches.max(), 1.0 + cue.pitch_variation)
	assert_ne(pitches.min(), pitches.max())


func test_a_one_shot_is_gone_once_it_has_played() -> void:
	_audio.set_listener(_listener)

	_audio.play_event(AudioEvents.GUNSHOT, Vector2.ZERO)
	await wait_seconds(0.5)

	assert_eq(_audio.get_one_shot_players().size(), 0)


func test_without_a_listener_nothing_is_heard_but_the_event_is_told() -> void:
	watch_signals(_audio)

	_audio.play_event(AudioEvents.BELL, Vector2(10.0, 0.0))

	assert_eq(_audio.get_one_shot_players().size(), 0, "nothing plays")
	assert_signal_emitted_with(_audio, &"event_played", [AudioEvents.BELL, Vector2(10.0, 0.0)])


func test_removing_the_listener_silences_the_sounds_in_the_world() -> void:
	_audio.set_listener(_listener)
	_audio.play_event(AudioEvents.BELL, Vector2.ZERO)

	_audio.set_listener(null)
	await wait_frames(1)

	assert_eq(_audio.get_one_shot_players().size(), 0)


func test_an_event_without_a_cue_plays_nothing() -> void:
	_audio.set_listener(_listener)

	_audio.play_event(&"no_such_event", Vector2.ZERO)

	assert_eq(_audio.get_one_shot_players().size(), 0)


# --- Listener ----------------------------------------------------------------------


func test_the_ear_follows_the_listener_but_never_turns() -> void:
	var ear: AudioListener2D = _audio.get_node(^"Ear")
	_listener.position = Vector2(120.0, 80.0)
	_listener.rotation = 1.2

	_audio.set_listener(_listener)
	assert_true(ear.is_current())
	_listener.position = Vector2(500.0, -20.0)
	await wait_frames(2)

	assert_eq(ear.global_position, Vector2(500.0, -20.0))
	assert_eq(ear.global_rotation, 0.0, "left and right stay those of the screen")
	assert_eq(_audio.get_listener(), _listener)
	_audio.set_listener(null)
	assert_false(ear.is_current())
	assert_null(_audio.get_listener())


# --- Emitters ----------------------------------------------------------------------


func test_an_emitter_follows_its_target_and_plays_while_switched_on() -> void:
	_audio.set_listener(_listener)
	var sheep: Node2D = add_child_autofree(Node2D.new())
	var handle: int = _audio.start_emitter(AudioEvents.GRASS_MOVE, sheep)
	var player: AudioStreamPlayer2D = _audio.get_emitter_player(handle)

	assert_false(player.playing, "silent until switched on")
	_audio.set_emitter_playing(handle, true)
	assert_true(player.playing)
	sheep.position = Vector2(-90.0, 30.0)
	await wait_frames(2)
	assert_eq(player.global_position, Vector2(-90.0, 30.0))
	assert_eq(player.max_distance, 400.0)
	await wait_seconds(0.1)

	_audio.set_emitter_playing(handle, false)
	assert_false(player.playing, "switched off, it stops")
	_audio.set_emitter_playing(handle, true)
	assert_true(player.playing, "and starts again")
	assert_eq(player.get_playback_position(), 0.0, "from the beginning")


func test_switching_an_emitter_off_in_the_frame_it_started_holds() -> void:
	_audio.set_listener(_listener)
	var sheep: Node2D = add_child_autofree(Node2D.new())
	var handle: int = _audio.start_emitter(AudioEvents.GRASS_MOVE, sheep)
	var player: AudioStreamPlayer2D = _audio.get_emitter_player(handle)

	_audio.set_emitter_playing(handle, true)
	_audio.set_emitter_playing(handle, false)
	await wait_frames(3)

	assert_false(player.playing)


func test_emitters_stop_when_their_target_leaves() -> void:
	var sheep: Node2D = Node2D.new()
	add_child(sheep)
	var rustle: int = _audio.start_emitter(AudioEvents.GRASS_MOVE, sheep)
	var munching: int = _audio.start_emitter(AudioEvents.GRAZE, sheep)
	var players: Array[AudioStreamPlayer2D] = [
		_audio.get_emitter_player(rustle), _audio.get_emitter_player(munching)
	]

	remove_child(sheep)

	assert_eq(_audio.get_emitter_count(), 0)
	for player: AudioStreamPlayer2D in players:
		assert_true(player.is_queued_for_deletion())
	assert_false(sheep.tree_exiting.is_connected(_audio._on_target_exiting), "let go of")
	sheep.free()


func test_stopping_an_emitter_can_fade_it_out() -> void:
	_audio.set_listener(_listener)
	var sheep: Node2D = add_child_autofree(Node2D.new())
	var handle: int = _audio.start_emitter(AudioEvents.GRASS_MOVE, sheep)
	var player: AudioStreamPlayer2D = _audio.get_emitter_player(handle)
	_audio.set_emitter_playing(handle, true)

	_audio.stop_emitter(handle, 0.2)
	assert_eq(_audio.get_emitter_count(), 0)
	assert_true(is_instance_valid(player), "still fading")
	await wait_seconds(0.4)

	assert_false(is_instance_valid(player))
	_audio.stop_emitter(handle)
	_audio.stop_emitter(12345)


func test_stop_all_ends_every_sound() -> void:
	_audio.set_listener(_listener)
	var sheep: Node2D = add_child_autofree(Node2D.new())
	_audio.set_emitter_playing(_audio.start_emitter(AudioEvents.GRASS_MOVE, sheep), true)
	_audio.play_event(AudioEvents.BELL, Vector2.ZERO)

	_audio.stop_all()
	await wait_frames(1)

	assert_eq(_audio.get_emitter_count(), 0)
	assert_eq(_audio.get_one_shot_players().size(), 0)


func test_emitters_are_silent_without_a_listener() -> void:
	var sheep: Node2D = add_child_autofree(Node2D.new())
	var handle: int = _audio.start_emitter(AudioEvents.GRASS_MOVE, sheep)
	var player: AudioStreamPlayer2D = _audio.get_emitter_player(handle)

	_audio.set_emitter_playing(handle, true)
	assert_false(player.playing)
	_audio.set_listener(_listener)
	assert_true(player.playing)
	_audio.set_listener(null)
	assert_false(player.playing)


func test_the_own_characters_sounds_are_quieter_on_this_device() -> void:
	var own_part: Node2D = Node2D.new()
	_listener.add_child(own_part)
	var other: Node2D = add_child_autofree(Node2D.new())
	var cue: AudioCue = _catalog.get_cue(AudioEvents.GRASS_MOVE)
	var own: int = _audio.start_emitter(AudioEvents.GRASS_MOVE, own_part)
	var own_body: int = _audio.start_emitter(AudioEvents.HERDER_STEP, _listener)
	var others: int = _audio.start_emitter(AudioEvents.GRASS_MOVE, other)

	_audio.set_listener(_listener)

	var quieter: float = cue.volume_db + _config.audio_own_sound_volume_db
	assert_eq(_audio.get_emitter_player(own).volume_db, quieter, "a part of the own character")
	assert_eq(
		_audio.get_emitter_player(own_body).volume_db,
		_catalog.get_cue(AudioEvents.HERDER_STEP).volume_db + _config.audio_own_sound_volume_db
	)
	assert_eq(_audio.get_emitter_player(others).volume_db, cue.volume_db, "others sound as usual")
	_audio.set_listener(other)
	assert_eq(_audio.get_emitter_player(own).volume_db, cue.volume_db)
	assert_eq(_audio.get_emitter_player(others).volume_db, quieter)


# --- Ambience ----------------------------------------------------------------------


func test_the_ambience_plays_its_layers_until_it_is_stopped() -> void:
	var layers: Array[StringName] = [AudioEvents.AMBIENCE_WIND, AudioEvents.AMBIENCE_CRICKETS]
	var node: Node = _audio.get_node(^"Ambience")

	_audio.set_ambience(layers, 0.0)

	assert_eq(_audio.get_ambience(), layers)
	assert_eq(node.get_child_count(), 2)
	for player: AudioStreamPlayer in node.get_children():
		assert_true(player.playing)
		assert_eq(player.bus, AudioService.BUS_AMBIENCE)
	_audio.set_ambience([], 0.0)
	await wait_frames(1)
	assert_eq(_audio.get_ambience(), [] as Array[StringName])
	assert_eq(node.get_child_count(), 0)


func test_the_ambience_fades_in() -> void:
	_audio.set_process(false)
	var cue: AudioCue = _catalog.get_cue(AudioEvents.AMBIENCE_WIND)

	_audio.set_ambience([AudioEvents.AMBIENCE_WIND], 1.0)
	var wind: AudioStreamPlayer = _audio.get_node(^"Ambience").get_child(0)

	assert_lt(wind.volume_db, cue.volume_db - 60.0, "silent at first")
	_audio._process(0.5)
	assert_almost_eq(wind.volume_db, cue.volume_db + linear_to_db(0.5), 0.1, "halfway")
	_audio._process(0.6)
	assert_almost_eq(wind.volume_db, cue.volume_db, 0.1, "all there")


func test_a_layer_of_one_shots_plays_now_and_then() -> void:
	_audio.set_process(false)

	_audio.set_ambience([AudioEvents.AMBIENCE_OWL], 0.0)
	var owl: AudioStreamPlayer = _audio.get_node(^"Ambience").get_child(0)

	assert_false(owl.playing, "not at once")
	_audio._process(0.31)
	assert_true(owl.playing, "within its interval")


func test_a_crucial_cue_ducks_the_ambience_for_a_moment() -> void:
	_catalog.get_cue(AudioEvents.BELL).duck_ambience = true
	_audio.set_process(false)
	_audio.set_listener(_listener)
	_audio.set_ambience([AudioEvents.AMBIENCE_WIND], 0.0)
	var wind: AudioStreamPlayer = _audio.get_node(^"Ambience").get_child(0)
	var normal: float = _catalog.get_cue(AudioEvents.AMBIENCE_WIND).volume_db
	var duck: float = _config.audio_ambience_duck_db
	var time: float = _config.audio_ambience_duck_time

	_audio.play_event(AudioEvents.BLEAT, Vector2.ZERO)
	_audio._process(0.0)
	assert_almost_eq(wind.volume_db, normal, 0.1, "a bleat does not duck it")
	_audio.play_event(AudioEvents.BELL, Vector2.ZERO)
	_audio._process(0.0)
	assert_almost_eq(wind.volume_db, normal + duck, 0.1, "the bell does")
	_audio._process(time / 2.0)
	assert_almost_eq(wind.volume_db, normal + duck / 2.0, 0.1, "coming back")
	_audio._process(time)
	assert_almost_eq(wind.volume_db, normal, 0.1, "back")


func test_stop_all_ends_the_ambience_too() -> void:
	_audio.set_ambience(AudioEvents.AMBIENCE, 0.0)

	_audio.stop_all()

	assert_eq(_audio.get_ambience(), [] as Array[StringName])


# --- Volumes -----------------------------------------------------------------------


func test_bus_volumes_are_kept_for_the_next_start() -> void:
	var first: SpatialAudioService = _new_service(SETTINGS_PATH)

	first.set_bus_volume(AudioService.BUS_EFFECTS, 0.25)
	first.set_bus_volume(AudioService.BUS_UI, 7.0)

	assert_almost_eq(first.get_bus_volume(AudioService.BUS_EFFECTS), 0.25, 0.001)
	assert_almost_eq(first.get_bus_volume(AudioService.BUS_UI), 1.0, 0.001, "clamped to 0..1")
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(AudioService.BUS_EFFECTS), 1.0)
	var second: SpatialAudioService = _new_service(SETTINGS_PATH)
	assert_almost_eq(second.get_bus_volume(AudioService.BUS_EFFECTS), 0.25, 0.001)


func test_an_unknown_bus_is_refused() -> void:
	expect_error("there is no bus")

	_audio.set_bus_volume(&"NoSuchBus", 0.5)

	assert_eq(_audio.get_bus_volume(&"NoSuchBus"), 1.0)


# --- Helpers -----------------------------------------------------------------------


func _new_service(settings_path: String = "") -> SpatialAudioService:
	var service: SpatialAudioService = SpatialAudioService.new(_config, _catalog)
	service.settings_path = settings_path
	return add_child_autofree(service)


func _ears(offset: Vector2, event_id: StringName) -> Vector2:
	return AudioMix.ear_gains(
		offset,
		AudioMix.fade_distance(_config, event_id),
		1.0,
		_config.audio_panning_strength,
		SCREEN_WIDTH
	)


func _sum(gains: Vector2) -> float:
	return gains.x + gains.y


static func _loops(stream: AudioStream) -> bool:
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	if stream is AudioStreamOggVorbis:
		return (stream as AudioStreamOggVorbis).loop
	return false


## A cue for every event: two short tones for one-shots, a looping tone for the
## looping sounds.
static func _every_event() -> Array[StringName]:
	var events: Array[StringName] = AudioEvents.ALL.duplicate()
	events.append_array(AudioEvents.CUES)
	events.append_array(AudioEvents.AMBIENCE)
	return events


static func _catalog_of_tones() -> AudioCatalog:
	var catalog: AudioCatalog = AudioCatalog.new()
	for event_id: StringName in _every_event():
		var cue: AudioCue = AudioCue.new()
		if LOOPING.has(event_id):
			cue.streams = [_tone(440.0, 0.5, true)]
			cue.volume_db = -3.0
		else:
			cue.streams = [_tone(440.0, 0.05, false), _tone(660.0, 0.05, false)]
			cue.pitch_variation = 0.1
			cue.attenuation = 1.5
		if AudioEvents.CUES.has(event_id):
			cue.bus = AudioService.BUS_UI
		elif AudioEvents.AMBIENCE.has(event_id):
			cue.bus = AudioService.BUS_AMBIENCE
		catalog.cues[event_id] = cue
	catalog.cues[AudioEvents.AMBIENCE_OWL].repeat_interval = Vector2(0.2, 0.3)
	return catalog


static func _tone(frequency: float, seconds: float, loop: bool) -> AudioStreamWAV:
	var rate: int = 22050
	var frames: int = int(seconds * rate)
	var data: PackedByteArray = PackedByteArray()
	data.resize(frames * 2)
	for i: int in frames:
		data.encode_s16(i * 2, int(sin(TAU * frequency * i / rate) * 8000.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = frames
	return stream
