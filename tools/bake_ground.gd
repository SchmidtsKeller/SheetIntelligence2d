extends SceneTree
## Bakes the painted ground of the arena (#76) into [code]assets/arena/ground/[/code].
## Development only.
##
## [codeblock lang=text]
## godot --headless --path . --script res://tools/bake_ground.gd -- <terrain image folder>
## [/codeblock]
##
## The folder holds the five painted terrain images of the team's AI Studio
## ground page ([code]terrain_grass_turf_*.jpg[/code] and the others in
## [constant TERRAINS]). For each terrain this writes:
## [br]- [code]<name>.png[/code]: the image made seamless and scaled to
## [constant TILE_SIZE], with its gloss (the reflection map) in alpha.
## [br]- [code]<name>_normal.png[/code]: the normal map of its height, which
## is the image's brightness.
## [br]And for the arena, a texel per [constant MAP_CELL] px:
## [br]- [code]layout.png[/code]: how much path (R), gravel (G), mud (B) and
## clover (A) lies there; the rest is grass.
## [br]- [code]relief.png[/code]: the hills (R), wetness (G), cart ruts (B) and
## which of two tilings shows (A).
## [br]Run [code]godot --headless --path . --import[/code] afterwards.

const OUTPUT: String = "res://assets/arena/ground"
const TILE_SIZE: int = 512
## Width of the cross-fade that makes an image seamless.
const SEAM_BORDER: int = 72
const ARENA_SIZE: Vector2i = Vector2i(3200, 2400)
const MAP_CELL: int = 4
const SEED: int = 7604

## name, file prefix, normal strength, gloss model.
const TERRAINS: Array[Dictionary] = [
	{"name": "grass", "prefix": "terrain_grass_turf", "relief": 3.0},
	{"name": "clover", "prefix": "terrain_clover_meadow", "relief": 3.0},
	{"name": "path", "prefix": "terrain_dirt_path", "relief": 4.0},
	{"name": "gravel", "prefix": "terrain_gravel_dirt", "relief": 6.0},
	{"name": "mud", "prefix": "terrain_mud_puddle", "relief": 5.0},
]

const BARN_YARD: Vector2 = Vector2(2480, 560)
const FORD: Vector2 = Vector2(1720, 2170)
## Path half widths and the cart ruts, in px.
const PATH_INNER: float = 44.0
const PATH_OUTER: float = 84.0
const RUT_OFFSET: float = 25.0
const RUT_WIDTH: float = 6.0
## How far around a trail the distance is worked out.
const REACH: float = 150.0


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 1:
		printerr("Usage: -- <terrain image folder>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for terrain: Dictionary in TERRAINS:
		if not _bake_terrain(arguments[0], terrain):
			quit(1)
			return
	_bake_maps()
	quit(0)


# --- Terrain textures --------------------------------------------------------------


func _bake_terrain(folder: String, terrain: Dictionary) -> bool:
	var source_path: String = ""
	for file: String in DirAccess.get_files_at(folder):
		if file.begins_with(terrain.prefix) and file.ends_with(".jpg"):
			source_path = folder.path_join(file)
	var source: Image = Image.load_from_file(source_path) if source_path != "" else null
	if source == null:
		printerr("No %s*.jpg in %s." % [terrain.prefix, folder])
		return false
	source.convert(Image.FORMAT_RGB8)
	source.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_LANCZOS)
	var albedo: Image = _seamless(source)
	var height: PackedFloat32Array = _blurred_luminance(albedo)
	var mean: float = 0.0
	for value: float in height:
		mean += value
	mean /= height.size()
	var normal: Image = Image.create_empty(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGB8)
	var glossy: Image = Image.create_empty(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var slope: Vector2 = Vector2(
				_at(height, x + 1, y) - _at(height, x - 1, y),
				_at(height, x, y + 1) - _at(height, x, y - 1)
			)
			var n: Vector3 = Vector3(-slope.x, -slope.y, 0.0) * terrain.relief
			n.z = 1.0
			n = n.normalized()
			normal.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
			var color: Color = albedo.get_pixel(x, y)
			color.a = _gloss(terrain.name, _at(height, x, y), mean, slope.length())
			glossy.set_pixel(x, y, color)
	glossy.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(terrain.name + ".png")))
	normal.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(terrain.name + "_normal.png")))
	print("%s: %dx%d from %s" % [terrain.name, TILE_SIZE, TILE_SIZE, source_path.get_file()])
	return true


## How much the surface reflects at a spot of [param brightness] (the
## reflection map): wet, dark and flat mud most, stone tops in the gravel a
## little, grass and clover hardly.
func _gloss(terrain_name: String, brightness: float, mean: float, slope: float) -> float:
	match terrain_name:
		"mud":
			var pool: float = clampf((mean - brightness) * 4.0 + 0.5, 0.0, 1.0)
			return clampf(0.35 + 0.6 * pool - slope * 6.0, 0.15, 1.0)
		"gravel":
			return clampf(0.12 + 0.6 * smoothstep(mean, mean + 0.15, brightness), 0.0, 1.0)
		"path":
			return clampf(0.1 + (mean - brightness) * 0.6, 0.04, 0.3)
		_:
			return clampf(0.03 + brightness * 0.08, 0.0, 0.12)


## The image cross-faded at its borders with a copy shifted by half, whose
## own borders meet without a seam (as the ground page does it).
func _seamless(image: Image) -> Image:
	var size: int = image.get_width()
	var half: int = size / 2
	var result: Image = image.duplicate()
	for y: int in size:
		for x: int in size:
			var edge: int = mini(mini(x, size - 1 - x), mini(y, size - 1 - y))
			var keep: float = smoothstep(0.0, float(SEAM_BORDER), float(edge))
			if keep >= 1.0:
				continue
			var shifted: Color = image.get_pixel((x + half) % size, (y + half) % size)
			result.set_pixel(x, y, shifted.lerp(image.get_pixel(x, y), keep))
	return result


## Brightness of every pixel, smoothed over its neighbours, wrapping around.
func _blurred_luminance(image: Image) -> PackedFloat32Array:
	var size: int = image.get_width()
	var luminance: PackedFloat32Array = []
	luminance.resize(size * size)
	for y: int in size:
		for x: int in size:
			var c: Color = image.get_pixel(x, y)
			luminance[y * size + x] = 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
	var blurred: PackedFloat32Array = []
	blurred.resize(size * size)
	for y: int in size:
		for x: int in size:
			var sum: float = 0.0
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					sum += _at(luminance, x + dx, y + dy)
			blurred[y * size + x] = sum / 9.0
	return blurred


func _at(values: PackedFloat32Array, x: int, y: int) -> float:
	return values[posmod(y, TILE_SIZE) * TILE_SIZE + posmod(x, TILE_SIZE)]


# --- Arena maps --------------------------------------------------------------------


func _bake_maps() -> void:
	var size: Vector2i = ARENA_SIZE / MAP_CELL
	var distance: PackedFloat32Array = _trail_distance(size)
	var hills: FastNoiseLite = _noise(SEED, 0.0012, 4)
	var moisture: FastNoiseLite = _noise(SEED + 1, 0.0035, 3)
	var patches: FastNoiseLite = _noise(SEED + 2, 0.0028, 3)
	var edges: FastNoiseLite = _noise(SEED + 3, 0.02, 2)
	var pools: FastNoiseLite = _noise(SEED + 4, 0.012, 2)
	var tiling: FastNoiseLite = _noise(SEED + 5, 0.0025, 2)
	var layout: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var relief: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y: int in size.y:
		for x: int in size.x:
			var at: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) * MAP_CELL
			var d: float = distance[y * size.x + x]
			var warped: float = d + edges.get_noise_2dv(at) * 24.0
			var path: float = 1.0 - smoothstep(PATH_INNER, PATH_OUTER, warped)
			var rut: float = exp(-pow((absf(d) - RUT_OFFSET) / RUT_WIDTH, 2.0)) * path
			var height: float = 0.5 + 0.5 * hills.get_noise_2dv(at)
			height *= 1.0 - 0.6 * smoothstep(1950.0, 2200.0, at.y)
			height = lerpf(height, 0.45, path * 0.5)
			var wet: float = 0.5 + 0.5 * moisture.get_noise_2dv(at)
			var patch: float = patches.get_noise_2dv(at)
			var shoulder: float = (
				smoothstep(55.0, 75.0, warped) * (1.0 - smoothstep(95.0, 135.0, warped))
			)
			var yard: float = 1.0 - smoothstep(170.0, 330.0, at.distance_to(BARN_YARD))
			var gravel: float = clampf(
				shoulder * smoothstep(0.0, 0.25, patch) + yard * (0.6 + 0.4 * patch), 0.0, 1.0
			)
			gravel *= 1.0 - path * 0.75
			var mud: float = smoothstep(0.56, 0.74, wet) * (1.0 - smoothstep(0.36, 0.56, height))
			mud += 1.0 - smoothstep(110.0, 260.0, at.distance_to(FORD))
			mud += smoothstep(2060.0, 2190.0, at.y) * smoothstep(0.4, 0.6, wet)
			mud += rut * smoothstep(0.55, 0.7, wet)
			mud = clampf(mud, 0.0, 1.0) * (1.0 - yard)
			var clover: float = smoothstep(0.25, 0.5, patch) * (1.0 - path)
			clover *= (1.0 - mud) * (1.0 - gravel)
			var total: float = path + gravel + mud + clover
			if total > 1.0:
				path /= total
				gravel /= total
				mud /= total
				clover /= total
			var puddle: float = smoothstep(0.35, 0.8, 0.5 + 0.5 * pools.get_noise_2dv(at))
			var water: float = clampf(mud * (0.3 + 0.7 * puddle) + rut * 0.35 * wet, 0.0, 1.0)
			var variant: float = smoothstep(-0.25, 0.25, tiling.get_noise_2dv(at))
			layout.set_pixel(x, y, Color(path, gravel, mud, clover))
			relief.set_pixel(x, y, Color(height, water, rut, variant))
	layout.save_png(ProjectSettings.globalize_path(OUTPUT.path_join("layout.png")))
	relief.save_png(ProjectSettings.globalize_path(OUTPUT.path_join("relief.png")))
	print("layout and relief: %dx%d, a texel per %d px" % [size.x, size.y, MAP_CELL])


## Distance from every texel's center to the nearest trail, in px; far away
## texels get [constant REACH].
func _trail_distance(size: Vector2i) -> PackedFloat32Array:
	var distance: PackedFloat32Array = []
	distance.resize(size.x * size.y)
	distance.fill(REACH)
	for trail: PackedVector2Array in _trails():
		var points: PackedVector2Array = _spline(trail)
		for index: int in points.size() - 1:
			var a: Vector2 = points[index]
			var b: Vector2 = points[index + 1]
			var area: Rect2 = Rect2(a, Vector2.ZERO).expand(b).grow(REACH)
			var from: Vector2i = Vector2i((area.position / MAP_CELL).floor()).max(Vector2i.ZERO)
			var to: Vector2i = Vector2i((area.end / MAP_CELL).ceil()).min(size)
			for y: int in range(from.y, to.y):
				for x: int in range(from.x, to.x):
					var at: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) * MAP_CELL
					var d: float = at.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b))
					var cell: int = y * size.x + x
					if d < distance[cell]:
						distance[cell] = d
	return distance


## The trail through its control points as a Catmull-Rom curve, a point every
## 16 px or so.
func _spline(controls: PackedVector2Array) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for index: int in controls.size() - 1:
		var p0: Vector2 = controls[maxi(index - 1, 0)]
		var p1: Vector2 = controls[index]
		var p2: Vector2 = controls[index + 1]
		var p3: Vector2 = controls[mini(index + 2, controls.size() - 1)]
		var steps: int = maxi(ceili(p1.distance_to(p2) / 16.0), 1)
		for step: int in steps:
			var t: float = float(step) / steps
			points.append(
				(
					0.5
					* (
						2.0 * p1
						+ (p2 - p0) * t
						+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
						+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t
					)
				)
			)
	points.append(controls[controls.size() - 1])
	return points


## The trails, as control points in arena pixels: from the barn down to the
## ford at the river, and the cart track from the west gate to where it meets
## the trail. They pass between the obstacles of arena.tscn.
func _trails() -> Array[PackedVector2Array]:
	return [
		PackedVector2Array(
			[
				Vector2(2560, 600),
				Vector2(2420, 860),
				Vector2(2120, 1040),
				Vector2(1760, 1220),
				Vector2(1560, 1420),
				Vector2(1590, 1700),
				Vector2(1690, 1980),
				Vector2(1720, 2300),
			]
		),
		PackedVector2Array(
			[
				Vector2(-60, 960),
				Vector2(300, 965),
				Vector2(640, 1050),
				Vector2(950, 1120),
				Vector2(1300, 1180),
				Vector2(1760, 1220),
			]
		),
	]


func _noise(noise_seed: int, frequency: float, octaves: int) -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	return noise
