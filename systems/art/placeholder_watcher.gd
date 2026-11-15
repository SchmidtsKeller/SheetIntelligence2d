extends Node
## Tags every [Sprite2D] in the world whose texture is placeholder art (#69):
## the scenery, the characters, the companions, blood. It watches the scene
## tree, so nothing has to be tagged by hand, and a sprite that gets a real
## texture is no longer tagged anew. Registered as the autoload
## [code]PlaceholderWatcher[/code].

const WATCHED: StringName = &"placeholder_watched"


func _enter_tree() -> void:
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var sprite: Sprite2D = node as Sprite2D
	if sprite == null:
		return
	if not sprite.has_meta(WATCHED):
		sprite.set_meta(WATCHED, true)
		sprite.texture_changed.connect(_check.bind(sprite.get_instance_id()))
	# The entity around it finishes setting up first: it may tag itself. By id,
	# because the sprite may be gone by then.
	_check.call_deferred(sprite.get_instance_id())


func _check(sprite_id: int) -> void:
	var sprite: Sprite2D = instance_from_id(sprite_id) as Sprite2D
	if sprite == null or not sprite.is_inside_tree():
		return
	if not PlaceholderArt.is_placeholder(sprite.texture) or PlaceholderTag.is_covered(sprite):
		return
	PlaceholderTag.attach(sprite, sprite.get_rect())
