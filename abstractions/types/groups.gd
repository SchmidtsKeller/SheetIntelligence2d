@abstract class_name Groups
extends RefCounted
## Node groups used across systems (declared as global groups in `project.godot`).
##
## Systems find each other's nodes through these groups instead of node paths
## or concrete classes. NPC sheep and the Monster share every group they are
## in, so group membership can never tell them apart.

## The Sheepherder character.
const SHEEPHERDER: StringName = &"sheepherder"
## NPC sheep and the Monster (in either form).
const SHEEP_LIKE: StringName = &"sheep_like"
## Shepherd Dog and Allied Bat.
const COMPANIONS: StringName = &"companions"
## Everything the vision system may hide: characters, sheep, companions.
const DYNAMIC_ENTITIES: StringName = &"dynamic_entities"
## Solid props that block movement and line of sight.
const OBSTACLES: StringName = &"obstacles"
## Static map elements that stay faintly visible in darkness (GDD §3.1).
const STATIC_SCENERY: StringName = &"static_scenery"

## The arena of the running round. There is at most one.
const ARENA: StringName = &"arena"

const ALL: Array[StringName] = [
	ARENA,
	SHEEPHERDER,
	SHEEP_LIKE,
	COMPANIONS,
	DYNAMIC_ENTITIES,
	OBSTACLES,
	STATIC_SCENERY,
]


## The project setting that declares [param group] as a global group.
static func setting_path(group: StringName) -> String:
	return "global_group/%s" % group
