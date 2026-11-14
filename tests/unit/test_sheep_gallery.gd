extends TestCase
## The sheep gallery shows the sheep of one round.

const GALLERY_SCENE: String = "res://entities/sheep/gallery/sheep_gallery.tscn"


func test_the_gallery_shows_one_round_of_distinct_sheep() -> void:
	var gallery: Node2D = add_child_autofree((load(GALLERY_SCENE) as PackedScene).instantiate())
	await wait_frames(2)

	var sheep: Array[SheepBody] = gallery.call(&"get_sheep")
	assert_eq(sheep.size(), Services.config.flock_size + 1)
	var fingerprints: Dictionary[String, bool] = {}
	for body: SheepBody in sheep:
		fingerprints[body.get_appearance().fingerprint()] = true
	assert_eq(fingerprints.size(), sheep.size(), "every sheep looks different")
