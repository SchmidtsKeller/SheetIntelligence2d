extends TestCase
## The Web export preset keeps the decisions documented in docs/web-build.md.

const PRESET_PATH: String = "res://export_presets.cfg"
const PRESET: String = "preset.0"
const OPTIONS: String = "preset.0.options"

var _presets: ConfigFile


func before_each() -> void:
	_presets = ConfigFile.new()
	_presets.load(PRESET_PATH)


func test_there_is_a_web_preset() -> void:
	assert_eq(_presets.get_value(PRESET, "name", ""), "Web")
	assert_eq(_presets.get_value(PRESET, "platform", ""), "Web")
	assert_eq(_presets.get_value(PRESET, "export_path", ""), "build/web/index.html")


func test_build_runs_without_thread_support() -> void:
	# GitHub Pages cannot send the cross-origin isolation headers threads need.
	assert_eq(_presets.get_value(OPTIONS, "variant/thread_support", true), false)
	assert_eq(_presets.get_value(OPTIONS, "progressive_web_app/enabled", true), false)


func test_canvas_fills_the_browser_window() -> void:
	assert_eq(_presets.get_value(OPTIONS, "html/canvas_resize_policy", -1), 2, "2 = adaptive")
	assert_eq(_presets.get_value(OPTIONS, "html/focus_canvas_on_start", false), true)


func test_textures_work_on_desktop_and_mobile_browsers() -> void:
	assert_eq(_presets.get_value(OPTIONS, "vram_texture_compression/for_desktop", false), true)
	assert_eq(_presets.get_value(OPTIONS, "vram_texture_compression/for_mobile", false), true)
	assert_eq(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc", false), true)


func test_tests_and_tools_are_not_shipped() -> void:
	var excluded: String = _presets.get_value(PRESET, "exclude_filter", "")

	for folder: String in ["tests/*", "tools/*", "web/*", "docs/*"]:
		assert_has(excluded, folder)


func test_head_include_loads_the_page_files_that_ship_with_the_game() -> void:
	var head_include: String = _presets.get_value(OPTIONS, "html/head_include", "")

	assert_has(head_include, "href=\"page.css\"")
	assert_has(head_include, "src=\"page.js\"")
	assert_false(head_include.contains("http"), "nothing is loaded from another server")
	assert_true(FileAccess.file_exists("res://web/page.css"))
	assert_true(FileAccess.file_exists("res://web/page.js"))
