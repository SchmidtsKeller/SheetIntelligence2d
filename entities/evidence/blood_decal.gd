class_name BloodDecal
extends Node2D
## Blood on the ground (#91): a pool with droplets and splatter, dark and wet,
## that glints in the flashlight and torchlight. Drawn by
## [code]blood.gdshader[/code] from a [BloodShape]; no image is loaded.
##
## Its [VisionTarget] makes it a ground mark: the Sheepherder sees it only in
## the light, the Monster sees all of the ground.

const BLOOD_SHADER: Shader = preload("res://entities/evidence/blood.gdshader")

## The mark's shape. Without one, the decal takes the shape of its position
## when it enters the tree.
var shape: BloodShape:
	set(value):
		shape = value
		_apply_shape()


func _ready() -> void:
	if shape == null:
		shape = BloodShape.for_position(position)


func _draw() -> void:
	if shape != null:
		var half: Vector2 = Vector2(shape.extent, shape.extent)
		draw_rect(Rect2(-half, half * 2.0), Color.WHITE)


func _apply_shape() -> void:
	if shape == null:
		material = null
		queue_redraw()
		return
	rotation = shape.rotation
	var blood: ShaderMaterial = ShaderMaterial.new()
	blood.shader = BLOOD_SHADER
	# The shader's arrays hold BloodShape.MAX_ELEMENTS; unused ones stay zero.
	var segments: PackedVector4Array = shape.segments.duplicate()
	var params: PackedVector4Array = shape.params.duplicate()
	segments.resize(BloodShape.MAX_ELEMENTS)
	params.resize(BloodShape.MAX_ELEMENTS)
	blood.set_shader_parameter(&"segments", segments)
	blood.set_shader_parameter(&"params", params)
	blood.set_shader_parameter(&"element_count", shape.size())
	blood.set_shader_parameter(&"noise_offset", shape.noise_offset)
	material = blood
	queue_redraw()
