class_name FlockDebugOverlay
extends Node2D
## Draws what the flock is thinking: per sheep its phase, where it is
## steering and where it wants to go, and the reach of the last bell.
##
## Only the host has something to show; the guest's sheep have no minds.

const PHASE_COLORS: Dictionary[GameEnums.SheepPhase, Color] = {
	GameEnums.SheepPhase.WANDER: Color.WHITE,
	GameEnums.SheepPhase.GRAZE: Color.LIME_GREEN,
	GameEnums.SheepPhase.BLEAT: Color.YELLOW,
	GameEnums.SheepPhase.BELL: Color.ORANGE,
}
const ACTIVITY_NAMES: Dictionary[FlockAgent.Activity, String] = {
	FlockAgent.Activity.PAUSE: "pause",
	FlockAgent.Activity.WALK: "walk",
	FlockAgent.Activity.GRAZE: "graze",
	FlockAgent.Activity.BELL: "bell",
}
const STEERING_LENGTH: float = 60.0
const FONT_SIZE: int = 14

## The flock to show.
var swarm: FlockSwarmService


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if swarm == null:
		return
	var bell: Dictionary = swarm.get_last_bell()
	if bell["radius"] > 0.0:
		draw_arc(bell["origin"], bell["radius"], 0.0, TAU, 96, Color(1.0, 0.6, 0.0, 0.6), 3.0)
		draw_circle(bell["origin"], 8.0, Color.ORANGE)
	var font: Font = ThemeDB.fallback_font
	for sheep_id: int in swarm.get_living_sheep_ids():
		var agent: FlockAgent = swarm.get_agent(sheep_id)
		if agent == null:
			continue
		var position: Vector2 = (swarm.get_sheep_body(sheep_id) as Node2D).global_position
		var color: Color = PHASE_COLORS[agent.get_phase()]
		if agent.activity == FlockAgent.Activity.WALK or agent.activity == FlockAgent.Activity.BELL:
			draw_dashed_line(position, agent.target, Color(color, 0.5), 2.0, 10.0)
			draw_circle(agent.target, 5.0, color)
		if not agent.steering.is_zero_approx():
			draw_line(position, position + agent.steering * STEERING_LENGTH, Color.CYAN, 3.0)
		var text: String = (
			"%d %s %.1f" % [sheep_id, ACTIVITY_NAMES[agent.activity], agent.time_left]
		)
		draw_string(
			font,
			position + Vector2(-30.0, -38.0),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			FONT_SIZE,
			color
		)
