class_name SpiderVisual
extends Node2D
## The look of the Monster's spider form (GDD §3.2): the painted spider of the
## animation pack (#74). It lurks while standing, stalks when slow, runs when
## fast and lunges again and again while it eats.
##
## It is drawn facing +x, like the sheep it replaces (see
## [method SheepBody.set_visual_override]). Only the body's state and shown
## speed decide what it does, so it looks the same on both devices.

const FRAMES: SpriteFrames = preload("res://assets/monster/spider_frames.tres")
const ANIMATION_IDLE: StringName = &"idle"
const ANIMATION_STALK: StringName = &"stalk"
const ANIMATION_WALK: StringName = &"walk"
const ANIMATION_EAT: StringName = &"eat_lunge"

## How far the spider reaches from its center, for the vision system.
const RADIUS: float = 80.0
## Size of the frames in the world: the legs span about twice [constant RADIUS].
const FRAME_SCALE: float = 1.05
## Below this share of the spider speed it stalks rather than runs.
const STALK_BELOW: float = 0.6
## The speeds the stalk and walk frames are drawn for, as shares of the spider
## speed.
const STALK_FRAMES_SPEED: float = 0.4
const WALK_FRAMES_SPEED: float = 1.0
## The walk frames never play slower than this.
const MIN_SPEED_SCALE: float = 0.4

## The body whose state decides what the spider is shown doing.
var body: SheepBody

var _sprite: AnimatedSprite2D


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = FRAMES
	_sprite.scale = Vector2(FRAME_SCALE, FRAME_SCALE)
	add_child(_sprite)
	_sprite.play(ANIMATION_IDLE)


func _process(_delta: float) -> void:
	if not is_instance_valid(body):
		return
	if not body.is_alive():
		_sprite.pause()
		return
	var animation: StringName = ANIMATION_IDLE
	var speed_scale: float = 1.0
	match body.get_state():
		SheepBody.State.WALK:
			var top: float = Services.perks.get_stat(StatIds.SPIDER_MOVE_SPEED)
			var relative: float = body.get_shown_speed() / top if top > 0.0 else 1.0
			animation = ANIMATION_STALK if relative < STALK_BELOW else ANIMATION_WALK
			var drawn_for: float = (
				STALK_FRAMES_SPEED if animation == ANIMATION_STALK else WALK_FRAMES_SPEED
			)
			speed_scale = maxf(relative / drawn_for, MIN_SPEED_SCALE)
		SheepBody.State.DEVOUR:
			animation = ANIMATION_EAT
	_sprite.speed_scale = speed_scale
	if _sprite.animation != animation or not _sprite.is_playing():
		_sprite.play(animation)


## The animation shown, for tests and the self-check.
func get_animation() -> StringName:
	return _sprite.animation if _sprite != null else &""
