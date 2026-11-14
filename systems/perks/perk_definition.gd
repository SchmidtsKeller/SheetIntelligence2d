class_name PerkDefinition
extends Resource
## One perk of the game (GDD §4): what the lobby shows and what the perk does.
##
## A passive perk lists its [member modifiers]. A perk that does more names an
## [member effect] script: an active perk's effect runs when its player
## presses the perk button ([member triggered]); any other effect runs for the
## whole round, like the Shepherd Dog.

## How the perk is used, as the GDD sorts them.
enum Kind {
	## Works on its own for the whole round.
	PASSIVE,
	## Triggered by its player with the perk button.
	ACTIVE,
	## Brings a companion (#19).
	COMPANION,
}

## The id (see [PerkIds]).
@export var id: StringName
## The role whose pool the perk is in.
@export var role: GameEnums.Role = GameEnums.Role.NONE
@export var kind: Kind = Kind.PASSIVE
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
## Stat changes for the whole round, applied when the selection is locked.
@export var modifiers: Array[PerkModifier] = []
## A [PerkEffect] script: what the perk does beyond changing stats.
@export var effect: GDScript
## Whether the [member effect] starts when its player presses the perk button;
## otherwise it runs from the moment the round has the perk's character.
@export var triggered: bool = false


## Whether the perk is triggered with the perk button.
func is_triggered() -> bool:
	return effect != null and triggered
