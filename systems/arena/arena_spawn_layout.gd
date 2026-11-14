class_name ArenaSpawnLayout
extends RefCounted
## Where everybody starts a round (see [method Arena.get_spawn_layout]).

## Start of the Sheepherder.
var sheepherder_position: Vector2 = Vector2.ZERO
## Starts of the sheep-like entities: the NPC sheep and the Monster. All are
## drawn alike, so the round setup can give the Monster any of them.
var sheep_positions: Array[Vector2] = []
