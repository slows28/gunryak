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
    if game.unit_list.item_count != 6:
        push_error("VISUAL_CAPTURE_FAIL: six independent commanders not present")
        quit(1)
        return
    # Check real glyph availability: a successful PNG with tofu is not a pass.
    var font: Font = game.get("korean_font")
    if font == null or not font.has_char(0xAD70) or not font.has_char(0xB7B5):
        push_error("KOREAN_FONT_FAIL: 군략 glyphs missing from selected font")
        quit(1)
        return
    print("KOREAN_FONT_PASS: 군략 glyphs available")
    await RenderingServer.frame_post_draw
    if not _save_frame("title.png"):
        quit(1)
        return
    game.call("_begin_campaign")
    await process_frame
    await RenderingServer.frame_post_draw
    if game.strategy_view.slot_choice.item_count != 6:
        push_error("VISUAL_CAPTURE_FAIL: campaign slots missing")
        quit(1)
        return
    if not _save_frame("campaign_map.png"):
        quit(1)
        return
    game.call("_leave_title")
    await process_frame
    await RenderingServer.frame_post_draw
    if not game.order_view.visible:
        push_error("VISUAL_CAPTURE_FAIL: dedicated planning map missing")
        quit(1)
        return
    if not _save_frame("before_battle.png"):
        quit(1)
        return

    # Simulate a deterministic 48 operation seconds of battle without waiting in real time.
    game.set_process(false)
    game.sim.issue_map_order(1,"전열 엄호",Vector2(790,900),0)
    game.order_view.call("_select",1)
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("paper_orders.png"):
        quit(1)
        return
    game.call("_start")
    game.game_speed=4.0
    var dust_captured: bool = false
    for i in range(120):
        game.call("_process", 0.1)
        if not dust_captured and game.sim.dust_effects.size() >= 4:
            var puff: Dictionary = game.sim.dust_effects.back()
            if int(puff["side"]) == 0:
                game.camera_center = puff["pos"]
                game.camera_zoom = 1.65
                game.call("_clamp_camera")
                game.map_layer.queue_redraw()
                await process_frame
                await RenderingServer.frame_post_draw
                if not _save_frame("march_dust.png"):
                    quit(1)
                    return
                dust_captured = true
                game.call("_reset_camera")
    game.call("_refresh_hud")
    game.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("battle_48s.png"):
        quit(1)
        return
    for i in range(160):
        game.call("_process", 0.1)
    game.call("_refresh_hud")
    game.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("battle_112s.png"):
        quit(1)
        return
    game.call("_focus_selected")
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("battle_focus.png"):
        quit(1)
        return
    # Same simulation tick, same camera: compare quiet and detailed presentation.
    var frozen_time: float = game.sim.battle_time
    game.call("_toggle_map_detail")
    await process_frame
    await RenderingServer.frame_post_draw
    if not game.detailed_map or game.sim.battle_time!=frozen_time:
        push_error("VISUAL_CAPTURE_FAIL: overlay toggle changed simulation state")
        quit(1)
        return
    if not _save_frame("battle_focus_detail.png"):
        quit(1)
        return
    game.call("_toggle_map_detail")
    if game.detailed_map:
        push_error("VISUAL_CAPTURE_FAIL: overlay does not return to clean mode")
        quit(1)
        return
    game.call("_reset_camera")
    for i in range(320):
        game.call("_process", 0.1)
    game.call("_refresh_hud")
    game.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("battle_240s.png"):
        quit(1)
        return
    # Record a later wide-field overview and a zoomed contact view.
    for i in range(600):
        if game.sim.finished: break
        game.call("_process",0.1)
    game.call("_reset_camera")
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("wide_overview.png"):
        quit(1)
        return
    if not game.sim.finished:
        game.call("_focus_selected")
        await process_frame
        await RenderingServer.frame_post_draw
        if not _save_frame("wide_contact.png"):
            quit(1)
            return
    # Record the real post-battle audit screen as visual evidence.
    var simulator = game.get("sim")
    var additional_steps: int = 0
    while not bool(simulator.get("finished")) and additional_steps < 4200:
        game.call("_process", 0.1)
        additional_steps += 1
    if not bool(simulator.get("finished")):
        push_error("VISUAL_CAPTURE_FAIL: unable to reach post-battle report")
        quit(1)
        return
    game.call("_refresh_hud")
    game.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    if game.outcome_cards.get_child_count() != 6:
        push_error("VISUAL_CAPTURE_FAIL: six commander results missing")
        quit(1)
        return
    if not _save_frame("battle_result.png"):
        quit(1)
        return
    # Start a second actual scenario to capture convoy movement and protection.
    game.queue_free()
    await process_frame
    game=MAIN_SCENE.instantiate()
    root.add_child(game)
    await process_frame
    game.call("_leave_title")
    game.call("_change_scenario",3)
    if game.sim.convoy.is_empty():
        push_error("VISUAL_CAPTURE_FAIL: escort scenario unavailable")
        quit(1)
        return
    game.set_process(false)
    game.call("_start")
    game.game_speed=4.0
    for i in range(150):
        if game.sim.finished: break
        game.call("_process",0.1)
    game.camera_center=game.sim.convoy["pos"]
    game.camera_zoom=1.0
    game.call("_clamp_camera")
    game.call("_refresh_hud")
    game.map_layer.queue_redraw()
    game.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("escort_live.png"):
        quit(1)
        return
    game.call("_reset_camera")
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("escort_overview.png"):
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
