class_name SheepAppearanceSlot
extends Resource
## One layer of a sheep's look (wool, pattern, head, marking, accessory) and
## the parts it can show.

## What a layer is attached to. The head moves on its own when the sheep
## grazes or bleats, so everything worn on the head belongs to [constant HEAD].
enum Anchor {
	BODY,
	HEAD,
}

## Name of the layer, also the name of its sprite in the sheep scene.
@export var id: StringName
@export var anchor: Anchor = Anchor.BODY
## Chance that a sheep shows nothing in this layer. 0 means every sheep has one
## of the parts.
@export_range(0, 100, 1, "suffix:%") var empty_chance_percent: int = 0
@export var parts: Array[SheepAppearancePart] = []
