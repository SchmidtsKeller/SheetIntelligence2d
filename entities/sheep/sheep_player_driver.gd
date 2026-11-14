class_name SheepPlayerDriver
extends Node
## Steers a [SheepBody] with the local player's input: movement, holding
## graze, pressing bleat. This is how the Monster player moves its disguise.
##
## The driver is not part of the sheep's scene, so a player-steered sheep is
## built exactly like one steered by the flock AI (GDD §3.2).

## The sheep to steer.
@export var body: SheepBody


func _ready() -> void:
	# Run before the sheep, so input reaches it in the same physics step.
	process_physics_priority = -1
	Services.input.action_pressed.connect(_on_action_pressed)
	Services.input.action_released.connect(_on_action_released)


func _physics_process(_delta: float) -> void:
	if is_instance_valid(body):
		body.set_move_input(Services.input.get_move_vector())


func _on_action_pressed(action: StringName) -> void:
	if not is_instance_valid(body):
		return
	match action:
		InputActions.GRAZE:
			body.set_grazing(true)
		InputActions.BLEAT:
			body.bleat()


func _on_action_released(action: StringName) -> void:
	if is_instance_valid(body) and action == InputActions.GRAZE:
		body.set_grazing(false)
