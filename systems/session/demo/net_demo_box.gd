class_name NetDemoBox
extends Node2D
## A placeholder entity for the network demo: a coloured square that its
## owner moves and the other device sees.

const KIND: StringName = &"demo_box"
const SIZE: float = 48.0

var _color: Color = Color.WHITE


## Factory for [method NetEntityRegistry.register_kind].
static func build(_entity_id: int, _owner_id: int, data: Dictionary) -> Node:
	var box: NetDemoBox = NetDemoBox.new()
	box.position = Vector2(data.get("x", 0.0), data.get("y", 0.0))
	box._color = Color(data.get("color", "white"))
	box.add_child(NetTransform2D.new())
	return box


func _draw() -> void:
	draw_rect(Rect2(-SIZE / 2.0, -SIZE / 2.0, SIZE, SIZE), _color)
	# A nose, so rotation is visible.
	draw_line(Vector2.ZERO, Vector2(SIZE / 2.0, 0.0), Color.BLACK, 4.0)
