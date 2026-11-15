class_name SheepAppearanceCatalog
extends Resource
## Everything a sheep can look like (GDD §3.3).
##
## The look is data: new parts, tints and even new layers are added by editing
## the shipped catalog, without code changes. Changing the catalog changes
## which look a seed produces, which is fine because looks are never stored.

## The layers in drawing order: the first one is drawn underneath. Layers on
## the head are always drawn above layers on the body.
@export var slots: Array[SheepAppearanceSlot] = []

@export_group("Proportions")
## Shortest body relative to the drawn images, in per mille (1000 = as drawn).
@export_range(500, 1500, 1) var min_length_permille: int = 920
## Longest body, in per mille.
@export_range(500, 1500, 1) var max_length_permille: int = 1080
## Narrowest body, in per mille.
@export_range(500, 1500, 1) var min_width_permille: int = 920
## Widest body, in per mille.
@export_range(500, 1500, 1) var max_width_permille: int = 1080

@export_group("Distinctness")
## In how many layers any two sheep of one round must differ (another part, or
## the same part in another tint), so that no two of them look alike. 0 lets
## sheep look alike: the shipped flock is one painted sheep in a few shades of
## wool (#74).
@export_range(0, 10, 1) var min_difference: int = 2
