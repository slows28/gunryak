extends SceneTree
## Captures real Godot-rendered UI frames (not mockups).
## Requires a real graphics display such as Xvfb; DO NOT use --headless.
const MAIN_SCENE = preload("res://main.tscn")
const OUT_DIR = "res://test_results/screenshots"
var game: Control

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("VISUAL_CAPTURE_FAIL: graphical display required")
        quit(1)
        return
    game = MAIN_SCENE.instantiate()
    root.add_child(game)
    await process_frame
    # Check real glyph availability: a successful PNG with tofu is not a pass.
    var font: Font = game.get("korean_font")
    if font == null or not font.has_char(0xAD70) or not font.has_char(0xB7B5):
        push_error("KOREAN_FONT_FAIL: 군략 glyphs missing from selected font")
        quit(1)
        return
    print("KOREAN_FONT_PASS: 군략 glyphs available")
    await RenderingServer.frame_post_draw
    if not _save_frame("before_battle.png"):
        quit(1)
        return

    # Simulate a deterministic 12 seconds of battle without waiting in real time.
    game.set_process(false)
    game.call("_start")
    for i in range(120):
        game.call("_process", 0.1)
    game.call("_refresh_hud")
    game.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("battle_12s.png"):
        quit(1)
        return
    for i in range(160):
        game.call("_process", 0.1)
    game.call("_refresh_hud")
    game.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("battle_28s.png"):
        quit(1)
        return
    for i in range(320):
        game.call("_process", 0.1)
    game.call("_refresh_hud")
    game.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("battle_60s.png"):
        quit(1)
        return
    print("GUNRYAK_VISUAL_CAPTURE_PASSED")
    quit(0)

func _save_frame(filename: String) -> bool:
    var png: Image = root.get_texture().get_image()
    if png == null or png.is_empty():
        push_error("VISUAL_CAPTURE_FAIL: empty framebuffer")
        return false
    if png.get_width() < 1000 or png.get_height() < 700:
        push_error("VISUAL_CAPTURE_FAIL: viewport unexpectedly small")
        return false
    var path: String = ProjectSettings.globalize_path(OUT_DIR)
    var directory_error: int = DirAccess.make_dir_recursive_absolute(path)
    if directory_error != OK:
        push_error("VISUAL_CAPTURE_FAIL: directory " + str(directory_error))
        return false
    var output: String = path.path_join(filename)
    var result: int = png.save_png(output)
    if result != OK:
        push_error("VISUAL_CAPTURE_FAIL: cannot write " + filename + " code " + str(result))
        return false
    print("GUNRYAK_SCREENSHOT_SAVED: " + output + " " + str(png.get_width()) + "x" + str(png.get_height()))
    return true
