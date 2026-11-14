class_name SheepAppearance
extends RefCounted
## The look of one sheep: which part in which tint each layer of a
## [SheepAppearanceCatalog] shows, and the body's proportions.
##
## Integers only, so two devices compare looks exactly.

## No part, or no tint, in a layer.
const NONE: int = -1

## The seed the look was generated from.
var visual_seed: int = 0
## Per catalog slot: index of the part shown, or [constant NONE].
var part_indices: PackedInt32Array = []
## Per catalog slot: index of the part's tint, or [constant NONE].
var tint_indices: PackedInt32Array = []
## Body length relative to the drawn images, in per mille.
var length_permille: int = 1000
## Body width relative to the drawn images, in per mille.
var width_permille: int = 1000


## A text that two looks share exactly when they look the same.
func fingerprint() -> String:
	var layers: PackedStringArray = []
	for slot_index: int in part_indices.size():
		layers.append("%d.%d" % [part_indices[slot_index], tint_indices[slot_index]])
	return "%s|%dx%d" % [",".join(layers), length_permille, width_permille]


## In how many layers this look and [param other] show another part or tint.
## Proportions do not count: they vary only slightly.
func difference(other: SheepAppearance) -> int:
	var differing: int = 0
	for slot_index: int in mini(part_indices.size(), other.part_indices.size()):
		if (
			part_indices[slot_index] != other.part_indices[slot_index]
			or tint_indices[slot_index] != other.tint_indices[slot_index]
		):
			differing += 1
	return differing + absi(part_indices.size() - other.part_indices.size())
