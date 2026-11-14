extends TestCase
## Every GDScript file in the project compiles.
##
## Scripts are loaded here, inside the running project, because that is the
## only place where they see the autoloads. A script that does not compile
## makes the engine report an error, which fails the test.

const SKIPPED_DIRECTORIES: PackedStringArray = ["build"]


func test_every_script_compiles() -> void:
	var paths: PackedStringArray = _find_scripts("res://")

	assert_gt(paths.size(), 30, "the search found the project's scripts")
	for path: String in paths:
		var script: GDScript = load(path) as GDScript
		if assert_not_null(script, "%s loads" % path):
			assert_true(script.can_instantiate() or script.is_abstract(), "%s is valid" % path)


func _find_scripts(directory: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return paths
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			paths.append(directory.path_join(file))
	for sub_directory: String in dir.get_directories():
		if not SKIPPED_DIRECTORIES.has(sub_directory):
			paths.append_array(_find_scripts(directory.path_join(sub_directory)))
	return paths
