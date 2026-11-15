class_name SheepAppearancePart
extends Resource
## One option for a layer of a sheep's look, e.g. a wool pattern or a collar.

## Name for logs, tests and the gallery.
@export var id: StringName
## The image, drawn centered on its slot's anchor plus [member offset].
@export var texture: Texture2D
## An animated image instead of [member texture]: it plays what the sheep is
## doing (see [constant SheepBody.FRAMES_IDLE] and the others). A slot with
## one such part shows all its parts animated.
@export var frames: SpriteFrames
## Position of the image relative to its anchor, in pixels. The sheep faces +x.
@export var offset: Vector2 = Vector2.ZERO
## Size of the image relative to its pixels, for images drawn larger than the
## sheep is shown.
@export var scale: Vector2 = Vector2.ONE
## Colors the image can be tinted with; the generator picks one per sheep.
## Leave empty to draw the image as it is.
@export var tints: Array[Color] = []
