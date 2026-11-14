@abstract
class_name SwarmService
extends Node
## Contract for the NPC flock (GDD §3.3).
##
## Owns the 10 NPC sheep of a round: spawning, the swarm simulation, behaviour
## phases, the reaction to the bell and death bookkeeping. The host simulates,
## the guest mirrors (GDD §9.4).
##
## Sheep are addressed by a stable id that is the same on both devices. The
## Monster is not part of the flock, but it registers as a neighbour so the
## NPC sheep treat it like one of their own.

## A sheep with the given visual seed entered the round.
@warning_ignore("unused_signal")
signal sheep_spawned(sheep_id: int, visual_seed: int)

## A sheep died and left the simulation.
@warning_ignore("unused_signal")
signal sheep_died(sheep_id: int, cause: GameEnums.DeathCause, position: Vector2)

## The number of living NPC sheep changed.
@warning_ignore("unused_signal")
signal living_count_changed(living: int)

## A sheep entered another behaviour phase.
@warning_ignore("unused_signal")
signal sheep_phase_changed(sheep_id: int, phase: GameEnums.SheepPhase)

## The bell was rung; sheep inside the radius now walk toward [param origin].
@warning_ignore("unused_signal")
signal bell_rung(origin: Vector2, radius: float)


## Spawns the flock for a round. Positions and visual seeds are derived from
## [param round_seed], so both devices get the same sheep.
@abstract
func spawn_flock(round_seed: int) -> void


## Removes all sheep, living or dead, at the end of a round.
@abstract
func despawn_flock() -> void


## Rings the bell at [param origin]: living sheep within [param radius] walk
## toward it, then return to normal behaviour (GDD §3.1). Other sheep are
## not affected.
@abstract
func ring_bell(origin: Vector2, radius: float) -> void


## Kills a sheep. Returns [code]false[/code] if it does not exist or is
## already dead. Only the host decides this; see [CombatService].
@abstract
func kill_sheep(sheep_id: int, cause: GameEnums.DeathCause) -> bool


## The number of NPC sheep still alive.
@abstract
func get_living_count() -> int


## The ids of all living NPC sheep.
@abstract
func get_living_sheep_ids() -> Array[int]


## Whether the sheep with [param sheep_id] exists and is alive.
@abstract
func is_sheep_alive(sheep_id: int) -> bool


## The body of a sheep, or [code]null[/code] if the id is unknown.
@abstract
func get_sheep_body(sheep_id: int) -> Node2D


## The id of the sheep that [param body] belongs to, or -1 if [param body] is
## not an NPC sheep of this flock (e.g. the Monster).
@abstract
func get_sheep_id(body: Node2D) -> int


## The living sheep closest to [param position] within [param max_distance]
## (center to center), or -1 if there is none.
@abstract
func find_nearest_living_sheep(position: Vector2, max_distance: float) -> int


## Makes [param body] a flock neighbour: NPC sheep steer around and along with
## it exactly as with each other. Used for the Monster's sheep, so the flock
## creates no behavioural tell.
@abstract
func register_neighbour(body: Node2D) -> void


## Removes a neighbour registered with [method register_neighbour].
@abstract
func unregister_neighbour(body: Node2D) -> void
