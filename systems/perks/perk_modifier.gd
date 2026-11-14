class_name PerkModifier
extends Resource
## One change a perk makes to a stat for the whole round, e.g. Wide Flashlight
## sets the cone angle to 90°.
##
## The value is not written here: it is the configured value of another stat,
## so every number stays in [GameConfig] (GDD §5).

## The stat the perk changes (see [StatIds]).
@export var stat: StringName
@export var op: PerkService.ModifierOp = PerkService.ModifierOp.OVERRIDE
## The stat whose configured value is used, e.g.
## [constant StatIds.PERK_WIDE_FLASHLIGHT_ANGLE_DEG].
@export var value_stat: StringName
