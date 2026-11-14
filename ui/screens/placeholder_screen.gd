extends Control
## A placeholder for a screen of the scene flow.
##
## Shows which screen this is and one button per screen the flow allows next,
## so the whole flow can be walked through before the real screens exist. The
## tasks that build the real lobby, round and results replace these scenes.

## Heading shown on the screen.
@export var title: String = "Screen"
## One line saying what will be here.
@export_multiline var description: String = ""


func _ready() -> void:
	var layout: VBoxContainer = VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	layout.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layout.grow_vertical = Control.GROW_DIRECTION_BOTH
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override(&"separation", 16)
	add_child(layout)

	var heading: Label = Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override(&"font_size", 48)
	layout.add_child(heading)

	if not description.is_empty():
		var body: Label = Label.new()
		body.text = description
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layout.add_child(body)

	for screen: SceneFlowController.Screen in SceneFlow.get_next_screens():
		var button: Button = Button.new()
		button.text = "Go to %s" % SceneFlowController.screen_name(screen)
		button.custom_minimum_size = Vector2(240.0, 56.0)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(SceneFlow.go_to.bind(screen))
		layout.add_child(button)
