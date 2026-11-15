extends TestCase
## Blood generated in code (#91): the same position gives the same mark on
## both devices, different positions give different marks, and no image is
## loaded for it.

const DECAL_PATH: String = "res://entities/evidence/blood_decal.tscn"
const DECAL_SCENE: PackedScene = preload(DECAL_PATH)
const IMAGE_EXTENSIONS: Array[String] = ["png", "svg", "jpg", "jpeg", "webp", "bmp", "tga"]

# --- The shape -------------------------------------------------------------------


func test_the_same_position_gives_the_same_mark() -> void:
	var at: Vector2 = Vector2(1234.0, 567.0)

	assert_true(BloodShape.for_position(at).equals(BloodShape.for_position(at)))
	assert_true(
		BloodShape.for_position(at).equals(BloodShape.for_position(at + Vector2(0.3, -0.2))),
		"whole pixels only, so tiny differences between the devices do not matter"
	)


func test_different_positions_give_different_marks() -> void:
	var marks: Array[BloodShape] = []
	for x: int in range(100, 3100, 600):
		for y: int in range(100, 2400, 460):
			marks.append(BloodShape.for_position(Vector2(x, y)))
	marks.append(BloodShape.for_position(Vector2(101.0, 100.0)))

	for first: int in marks.size():
		for second: int in range(first + 1, marks.size()):
			assert_false(marks[first].equals(marks[second]), "marks %d and %d" % [first, second])


func test_a_mark_is_a_pool_with_droplets_and_splatter() -> void:
	for x: int in range(0, 3200, 400):
		var shape: BloodShape = BloodShape.for_position(Vector2(x, x * 0.7))
		var pool: int = 0
		var droplets: int = 0
		var streaks: int = 0
		for index: int in shape.size():
			var segment: Vector4 = shape.segments[index]
			var a: Vector2 = Vector2(segment.x, segment.y)
			var b: Vector2 = Vector2(segment.z, segment.w)
			if a != b:
				streaks += 1
			elif a.length() < BloodShape.CORE_RADIUS_MAX:
				pool += 1
			else:
				droplets += 1
		assert_gte(pool, BloodShape.LOBES_MIN, "lobes of the pool")
		assert_gte(droplets, BloodShape.DROPLETS_MIN)
		assert_gte(streaks, BloodShape.STREAKS_MIN + 1, "the pool's flow and the splatter")
		assert_lte(shape.size(), BloodShape.MAX_ELEMENTS)
		assert_between(shape.extent, 16.0, 40.0, "about the size of the old decal")


func test_droplets_are_thinner_than_the_pool() -> void:
	var shape: BloodShape = BloodShape.for_position(Vector2(800.0, 300.0))
	var center: Vector4 = shape.params[0]
	var last: Vector4 = shape.params[shape.size() - 1]

	assert_eq(center.z, 1.0, "the pool is thickest")
	assert_lt(last.z, 1.0)


# --- The decal -------------------------------------------------------------------


func test_the_spawner_gives_each_decal_the_mark_of_its_position() -> void:
	var decals: Node2D = add_child_autofree(Node2D.new())
	var spawner: BloodDecalSpawner = BloodDecalSpawner.new()
	spawner.decals = decals
	add_child_autofree(spawner)

	spawner.spill(Vector2(400.0, 900.0))
	spawner.spill(Vector2(1700.0, 250.0))

	var first: BloodDecal = decals.get_child(0)
	var second: BloodDecal = decals.get_child(1)
	assert_true(first.shape.equals(BloodShape.for_position(Vector2(400.0, 900.0))))
	assert_false(first.shape.equals(second.shape))
	assert_almost_eq(first.rotation, first.shape.rotation, 0.0001)


func test_a_decal_without_a_shape_takes_the_one_of_its_position() -> void:
	var decal: BloodDecal = DECAL_SCENE.instantiate()
	decal.position = Vector2(640.0, 480.0)
	add_child_autofree(decal)

	assert_true(decal.shape.equals(BloodShape.for_position(Vector2(640.0, 480.0))))


func test_the_shader_gets_the_shape() -> void:
	var decal: BloodDecal = DECAL_SCENE.instantiate()
	decal.shape = BloodShape.for_position(Vector2(90.0, 70.0))
	add_child_autofree(decal)

	var blood: ShaderMaterial = decal.material as ShaderMaterial
	assert_not_null(blood)
	if blood == null:
		return
	assert_eq(blood.get_shader_parameter(&"element_count"), decal.shape.size())
	var segments: PackedVector4Array = blood.get_shader_parameter(&"segments")
	assert_eq(segments.size(), BloodShape.MAX_ELEMENTS, "the shader's arrays are full length")
	assert_eq(segments[0], decal.shape.segments[0])
	assert_eq(blood.get_shader_parameter(&"noise_offset"), decal.shape.noise_offset)


func test_no_image_is_loaded_for_blood() -> void:
	for dependency: String in ResourceLoader.get_dependencies(DECAL_PATH):
		for path: String in dependency.split("::", false):
			assert_does_not_have(IMAGE_EXTENSIONS, path.get_extension().to_lower(), path)
	var decal: Node = DECAL_SCENE.instantiate()
	add_child_autofree(decal)
	for node: Node in _with_descendants(decal):
		assert_false(node is Sprite2D or node is TextureRect, "%s draws an image" % node.name)
	assert_false(
		FileAccess.file_exists("res://assets/evidence/placeholder/blood.svg"),
		"the placeholder is gone"
	)


func test_blood_is_a_ground_mark() -> void:
	var decal: Node = DECAL_SCENE.instantiate()
	add_child_autofree(decal)

	var target: VisionTarget = VisionTarget.of(decal)
	assert_not_null(target)
	if target != null:
		assert_eq(target.kind, VisionTarget.Kind.GROUND_MARK)
	assert_true(decal.is_in_group(Groups.DYNAMIC_ENTITIES))


# --- Helpers ---------------------------------------------------------------------


func assert_between(value: float, low: float, high: float, message: String = "") -> void:
	assert_gte(value, low, message)
	assert_lte(value, high, message)


func _with_descendants(node: Node) -> Array[Node]:
	var nodes: Array[Node] = [node]
	for child: Node in node.get_children():
		nodes.append_array(_with_descendants(child))
	return nodes
