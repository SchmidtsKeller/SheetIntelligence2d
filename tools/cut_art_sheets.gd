extends SceneTree
## Cuts the painted asset sheets in resources/art_sources/ into one PNG per
## piece (#83, #96).
##
## [codeblock lang=text]
## godot --headless --path . --script res://tools/cut_art_sheets.gd
## [/codeblock]
##
## Each sheet is a collage on a flat charcoal background with a label under
## every piece. A piece is cut along the rectangle given below (found on the
## sheet, labels left out), its background is made transparent with a soft
## edge, and the result is trimmed to what is left. Tiles keep their
## background: they fill the rectangle. Run it again after editing a sheet;
## then re-import the project.

const SOURCES: String = "res://resources/art_sources/"

# How a piece's background is made transparent.
## Not at all: a tile fills its rectangle.
const NONE: int = 0
## Where it reaches the edge of the rectangle: dark paint inside the piece
## looks like the background but belongs to it.
const EDGE: int = 1
## Everywhere: for thin frames whose inside is background.
const ALL: int = 2

## Per sheet: [code]name -> [x, y, width, height, key, erase, scale][/code];
## [code]scale[/code] is optional and shrinks the cut piece (1.0 keeps it).
## [code]key[/code] says how the background goes ([constant NONE],
## [constant EDGE] or [constant ALL]);
## [code]erase[/code] is a list of rectangles (relative to the piece) cleared
## first, for labels that sit inside a piece's rectangle.
const SHEETS: Dictionary = {
	"uiElements.webp":
	{
		"folder": "res://assets/ui/painted/",
		"pieces":
		{
			"ui_board": [31, 140, 151, 151, EDGE, []],
			"ui_button_normal": [209, 191, 146, 50, EDGE, []],
			"ui_button_hover": [364, 191, 148, 50, EDGE, []],
			"ui_button_pressed": [524, 191, 146, 49, EDGE, []],
			"ui_button_disabled": [690, 191, 146, 50, EDGE, []],
			"ui_button_focus": [847, 191, 146, 49, ALL, []],
			"ui_choice_button_normal": [31, 328, 189, 66, EDGE, []],
			"ui_choice_button_hover": [235, 328, 189, 66, EDGE, []],
			"ui_choice_button_pressed": [437, 326, 192, 68, EDGE, []],
			"ui_choice_button_disabled": [640, 328, 191, 66, EDGE, []],
			"ui_choice_button_focus": [840, 328, 155, 59, ALL, []],
			"touch_joystick_base": [384, 440, 117, 100, EDGE, []],
			"touch_joystick_tip": [550, 452, 61, 73, EDGE, []],
			"touch_button_base_normal": [664, 440, 92, 92, EDGE, []],
			"touch_button_base_pressed": [784, 440, 92, 92, EDGE, []],
			"touch_button_base_active": [896, 436, 106, 92, EDGE, []],
		},
	},
	"board_large.png":
	{
		"folder": "res://assets/ui/painted/",
		"pieces":
		{
			"ui_board_large": [10, 9, 332, 396, EDGE, [], 0.75],
		},
	},
	"hud_bars.png":
	{
		"folder": "res://assets/ui/painted/",
		"pieces":
		{
			"hud_bar_empty": [14, 6, 364, 94, EDGE, [], 0.4],
			"hud_bar_fill_gold": [18, 117, 363, 91, EDGE, [], 0.4],
			"hud_bar_fill_olive": [18, 219, 360, 87, EDGE, [], 0.4],
		},
	},
	"hud_icons.png":
	{
		"folder": "res://assets/ui/painted/",
		"pieces":
		{
			"icon_bullets": [562, 2, 113, 111, EDGE, []],
			"icon_shoot": [689, 1, 110, 112, EDGE, []],
			"icon_bell": [564, 151, 108, 109, EDGE, []],
			"icon_graze": [690, 151, 109, 109, EDGE, []],
			"icon_bleat": [456, 293, 98, 100, EDGE, []],
			"icon_eat": [578, 295, 98, 98, EDGE, []],
			"icon_print": [699, 295, 98, 98, EDGE, []],
		},
	},
	"MapElements.webp":
	{
		"folder": "res://assets/arena/painted/",
		"pieces":
		{
			"ground_grass_tile": [28, 62, 152, 152, NONE, []],
			"ground_grass_patch_01": [204, 72, 138, 138, EDGE, []],
			"fence_straight": [372, 156, 163, 60, EDGE, []],
			"fence_corner": [370, 73, 253, 142, EDGE, [[56, 45, 114, 26], [0, 83, 170, 59]]],
			"tree_01": [646, 53, 176, 178, EDGE, []],
			"tree_02": [826, 51, 183, 180, EDGE, []],
			"bush_01": [30, 248, 168, 124, EDGE, []],
			"barn_01": [228, 243, 242, 128, EDGE, []],
			"shed_01": [505, 246, 162, 124, EDGE, []],
			"hay_bale_01": [720, 257, 129, 109, EDGE, []],
			"ground_hill_01": [15, 403, 214, 137, EDGE, []],
			"ground_flowers_01": [262, 428, 100, 80, EDGE, []],
			"river_water_tile": [413, 404, 134, 134, NONE, []],
			"river_bank_straight": [571, 403, 135, 135, NONE, []],
			"river_bank_corner": [730, 402, 135, 137, NONE, []],
			"torch_01": [883, 386, 125, 131, EDGE, []],
		},
	},
}

## Colour distance to the background below which a pixel is background, and
## above which it is fully part of the piece.
const KEY_LOW: float = 0.05
const KEY_HIGH: float = 0.16


func _init() -> void:
	var made: int = 0
	for sheet_name: String in SHEETS:
		var sheet: Dictionary = SHEETS[sheet_name]
		var image: Image = Image.load_from_file(
			ProjectSettings.globalize_path(SOURCES + sheet_name)
		)
		if image == null:
			push_error("cut_art_sheets: cannot read %s" % sheet_name)
			quit(1)
			return
		image.convert(Image.FORMAT_RGBA8)
		var background: Color = image.get_pixel(image.get_width() - 3, image.get_height() - 3)
		var folder: String = sheet["folder"]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		var pieces: Dictionary = sheet["pieces"]
		for piece_name: String in pieces:
			var spec: Array = pieces[piece_name]
			var piece: Image = image.get_region(Rect2i(spec[0], spec[1], spec[2], spec[3]))
			for erase: Array in spec[5]:
				piece.fill_rect(Rect2i(erase[0], erase[1], erase[2], erase[3]), background)
			if spec[4] != NONE:
				piece = _key_out(piece, background, spec[4] == ALL)
			if spec.size() > 6 and not is_equal_approx(spec[6], 1.0):
				var scaled: Vector2i = Vector2i(
					roundi(piece.get_width() * spec[6]), roundi(piece.get_height() * spec[6])
				)
				piece.resize(scaled.x, scaled.y, Image.INTERPOLATE_LANCZOS)
			var path: String = folder + piece_name + ".png"
			piece.save_png(ProjectSettings.globalize_path(path))
			print("%s  %dx%d" % [path, piece.get_width(), piece.get_height()])
			made += 1
	print("%d pieces cut" % made)
	quit()


## [param piece] with its background transparent, trimmed to what is left.
## Only background that reaches the edge of the rectangle is removed, unless
## [param everywhere] is set.
static func _key_out(piece: Image, background: Color, everywhere: bool) -> Image:
	var result: Image = piece.duplicate()
	var width: int = result.get_width()
	var height: int = result.get_height()
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(width * height)
	var open: Array[Vector2i] = []
	for x: int in width:
		open.append(Vector2i(x, 0))
		open.append(Vector2i(x, height - 1))
	for y: int in height:
		open.append(Vector2i(0, y))
		open.append(Vector2i(width - 1, y))
		if everywhere:
			for x: int in width:
				open.append(Vector2i(x, y))
	while not open.is_empty():
		var at: Vector2i = open.pop_back()
		if at.x < 0 or at.y < 0 or at.x >= width or at.y >= height:
			continue
		var index: int = at.y * width + at.x
		if seen[index] == 1:
			continue
		seen[index] = 1
		var colour: Color = result.get_pixelv(at)
		var distance: float = _distance(colour, background)
		if distance >= KEY_HIGH:
			continue
		colour.a = minf(colour.a, smoothstep(KEY_LOW, KEY_HIGH, distance))
		result.set_pixelv(at, colour)
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			open.append(at + step)
	var used: Rect2i = result.get_used_rect()
	return result.get_region(used) if used.has_area() else result


static func _distance(colour: Color, background: Color) -> float:
	return (
		absf(colour.r - background.r)
		+ absf(colour.g - background.g)
		+ absf(colour.b - background.b)
	)
