extends SceneTree
## Imports a character animation pack baked by the team's AI Studio animation
## page (#74) into [code]assets/[/code]. Development only.
##
## [codeblock lang=text]
## godot --headless --path . --script res://tools/import_sprite_pack.gd -- \
##     <pack folder> <res:// output folder> <name> [--scale=0.4]
## [/codeblock]
##
## A pack is a folder with [code]assets/*_frames.tres[/code], a Godot
## [SpriteFrames] made of equal cells, and the sheet PNG next to it. The
## frames are cut out of the sheet, cropped to what all of them cover (kept
## centered, so the character's pivot stays where it was), scaled down and
## packed into [code]<name>_sheet.png[/code]; [code]<name>_frames.tres[/code]
## lists the same animations with the same frame rates and loops. Run
## [code]godot --headless --path . --import[/code] afterwards.
##
## The packs come with 384 px cells, about 40 MB of video memory per
## character, too much for a phone's browser; at the default scale of 0.4 and
## cropped, a character needs a few megabytes.

const DEFAULT_SCALE: float = 0.4
## Transparent pixels around every frame in the sheet, so that filtering never
## blends in a neighbouring frame.
const PADDING: int = 2
## Pixels kept around what the frames cover.
const MARGIN: int = 4

var _regions: Dictionary[String, Rect2i] = {}
var _animations: Array[Dictionary] = []


func _init() -> void:
	var arguments: PackedStringArray = []
	var scale: float = DEFAULT_SCALE
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--scale="):
			scale = argument.trim_prefix("--scale=").to_float()
		else:
			arguments.append(argument)
	if arguments.size() != 3 or scale <= 0.0:
		printerr("Usage: -- <pack folder> <res:// output folder> <name> [--scale=0.4]")
		quit(1)
		return
	quit(0 if _import(arguments[0], arguments[1], arguments[2], scale) else 1)


func _import(pack: String, output: String, sheet_name: String, scale: float) -> bool:
	var frames_files: PackedStringArray = DirAccess.get_files_at(pack.path_join("assets"))
	var frames_path: String = ""
	var sheet_path: String = ""
	for file: String in frames_files:
		if file.ends_with("_frames.tres"):
			frames_path = pack.path_join("assets").path_join(file)
		elif file.ends_with("_sheet.png"):
			sheet_path = pack.path_join("assets").path_join(file)
	if frames_path.is_empty() or sheet_path.is_empty():
		printerr("No *_frames.tres and *_sheet.png in %s/assets." % pack)
		return false
	if not _parse(FileAccess.get_file_as_string(frames_path)):
		printerr("Could not read the animations of %s." % frames_path)
		return false
	var source: Image = Image.load_from_file(sheet_path)
	if source == null:
		printerr("Could not load %s." % sheet_path)
		return false
	source.convert(Image.FORMAT_RGBA8)
	var frame_ids: PackedStringArray = _frame_ids()
	var crop: Rect2i = _crop(source, frame_ids)
	var cell: Vector2i = Vector2i(
		roundi(crop.size.x * scale) + 2 * PADDING, roundi(crop.size.y * scale) + 2 * PADDING
	)
	var columns: int = maxi(ceili(sqrt(frame_ids.size() * float(cell.y) / cell.x)), 1)
	var rows: int = ceili(frame_ids.size() / float(columns))
	var sheet_size: Vector2i = Vector2i(columns * cell.x, rows * cell.y)
	var sheet: Image = Image.create_empty(sheet_size.x, sheet_size.y, false, Image.FORMAT_RGBA8)
	var placed: Dictionary[String, Rect2i] = {}
	for index: int in frame_ids.size():
		var id: String = frame_ids[index]
		var frame: Image = source.get_region(
			Rect2i(_regions[id].position + crop.position, crop.size)
		)
		frame.fix_alpha_edges()
		frame.resize(cell.x - 2 * PADDING, cell.y - 2 * PADDING, Image.INTERPOLATE_LANCZOS)
		var row: int = floori(index / float(columns))
		var at: Vector2i = Vector2i(index % columns * cell.x, row * cell.y)
		at += Vector2i(PADDING, PADDING)
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), at)
		placed[id] = Rect2i(at, frame.get_size())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var png_path: String = output.path_join(sheet_name + "_sheet.png")
	if sheet.save_png(ProjectSettings.globalize_path(png_path)) != OK:
		printerr("Could not write %s." % png_path)
		return false
	var tres_path: String = output.path_join(sheet_name + "_frames.tres")
	var tres_file: String = ProjectSettings.globalize_path(tres_path)
	var file: FileAccess = FileAccess.open(tres_file, FileAccess.WRITE)
	if file == null:
		printerr("Could not write %s." % tres_path)
		return false
	file.store_string(_sprite_frames_text(png_path, frame_ids, placed))
	file.close()
	print(
		(
			"%s: %d frames of %dx%d px (cropped from %dx%d, scale %.2f), sheet %dx%d"
			% [
				sheet_name,
				frame_ids.size(),
				cell.x - 2 * PADDING,
				cell.y - 2 * PADDING,
				crop.size.x,
				crop.size.y,
				scale,
				sheet.get_width(),
				sheet.get_height(),
			]
		)
	)
	return true


## Reads the cells and animations of a SpriteFrames text resource.
func _parse(text: String) -> bool:
	var region_pattern: RegEx = RegEx.create_from_string(
		'\\[sub_resource type="AtlasTexture" id="([^"]+)"\\][^\\[]*?region = Rect2\\('
		+ "([0-9.]+), ([0-9.]+), ([0-9.]+), ([0-9.]+)\\)"
	)
	for found: RegExMatch in region_pattern.search_all(text):
		_regions[found.get_string(1)] = Rect2i(
			found.get_string(2).to_int(),
			found.get_string(3).to_int(),
			found.get_string(4).to_int(),
			found.get_string(5).to_int()
		)
	var animation_pattern: RegEx = RegEx.create_from_string(
		'"frames": \\[([^\\]]*)\\],\\s*"loop": (true|false),\\s*"name": &"([^"]+)",'
		+ '\\s*"speed": ([0-9.]+)'
	)
	var frame_pattern: RegEx = RegEx.create_from_string(
		'"duration": ([0-9.]+), "texture": SubResource\\("([^"]+)"\\)'
	)
	for found: RegExMatch in animation_pattern.search_all(text):
		var frames: Array[Dictionary] = []
		for frame: RegExMatch in frame_pattern.search_all(found.get_string(1)):
			frames.append({"id": frame.get_string(2), "duration": frame.get_string(1).to_float()})
		_animations.append(
			{
				"name": found.get_string(3),
				"loop": found.get_string(2) == "true",
				"speed": found.get_string(4).to_float(),
				"frames": frames,
			}
		)
	return not _regions.is_empty() and not _animations.is_empty()


## Every cell used by an animation, in the order they first appear.
func _frame_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for animation: Dictionary in _animations:
		for frame: Dictionary in animation.frames:
			if not ids.has(frame.id):
				ids.append(frame.id)
	return ids


## The part of a cell that any frame draws into, plus [constant MARGIN], grown
## to be centered in the cell.
func _crop(source: Image, frame_ids: PackedStringArray) -> Rect2i:
	var cell_size: Vector2i = _regions[frame_ids[0]].size
	var used: Rect2i = Rect2i()
	for id: String in frame_ids:
		var frame_used: Rect2i = source.get_region(_regions[id]).get_used_rect()
		if frame_used.has_area():
			used = frame_used if not used.has_area() else used.merge(frame_used)
	var center: Vector2i = cell_size / 2
	var half: Vector2i = Vector2i(
		maxi(center.x - used.position.x, used.end.x - center.x),
		maxi(center.y - used.position.y, used.end.y - center.y)
	)
	half = (half + Vector2i(MARGIN, MARGIN)).min(center)
	return Rect2i(center - half, half * 2)


func _sprite_frames_text(
	png_path: String, frame_ids: PackedStringArray, placed: Dictionary[String, Rect2i]
) -> String:
	var lines: PackedStringArray = [
		'[gd_resource type="SpriteFrames" format=3]',
		"",
		'[ext_resource type="Texture2D" path="%s" id="1_sheet"]' % png_path,
		"",
	]
	for id: String in frame_ids:
		var region: Rect2i = placed[id]
		lines.append('[sub_resource type="AtlasTexture" id="%s"]' % id)
		lines.append('atlas = ExtResource("1_sheet")')
		lines.append(
			(
				"region = Rect2(%d, %d, %d, %d)"
				% [region.position.x, region.position.y, region.size.x, region.size.y]
			)
		)
		lines.append("")
	lines.append("[resource]")
	var animations: PackedStringArray = []
	for animation: Dictionary in _animations:
		var frames: PackedStringArray = []
		for frame: Dictionary in animation.frames:
			frames.append(
				(
					'{"duration": %s, "texture": SubResource("%s")}'
					% [_number(frame.duration), frame.id]
				)
			)
		animations.append(
			(
				'{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
				% [
					", ".join(frames),
					"true" if animation.loop else "false",
					animation.name,
					_number(animation.speed),
				]
			)
		)
	lines.append("animations = [%s]" % ", ".join(animations))
	lines.append("")
	return "\n".join(lines)


func _number(value: float) -> String:
	return "%.1f" % value if is_equal_approx(value, roundf(value)) else str(value)
