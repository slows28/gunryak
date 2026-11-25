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
    # Validate all 18 atlas cells and all four facing choices without mutating units.
    var atlas: Texture2D = load("res://assets/art/soldier_sprites.svg")
    if atlas==null or atlas.get_width()!=288 or atlas.get_height()!=576:
        push_error("VISUAL_CAPTURE_FAIL: soldier atlas dimensions invalid")
        quit(1)
        return
    var atlas_pixels: Image = atlas.get_image()
    for side in range(2):
        for kind in range(3):
            for column in range(3):
                var cell := Rect2i(column*96,(side*3+kind)*96,96,96)
                if atlas_pixels.get_region(cell).get_used_rect().size.x<20:
                    push_error("VISUAL_CAPTURE_FAIL: empty soldier sprite cell")
                    quit(1)
                    return
                var sample: Dictionary = {"side":side,"type":["보병","궁병","기병"][kind],"facing":[Vector2.RIGHT,Vector2.DOWN,Vector2.UP][column]}
                var region: Rect2 = game.call("_soldier_region",sample)
                if region!=Rect2(cell):
                    push_error("VISUAL_CAPTURE_FAIL: incorrect soldier facing atlas region")
                    quit(1)
                    return
    var left_sample: Dictionary={"side":1,"type":"기병","facing":Vector2.LEFT}
    if game.call("_soldier_region",left_sample)!=Rect2(0,480,96,96):
        push_error("VISUAL_CAPTURE_FAIL: wrong mirrored profile")
        quit(1)
        return
    var saved_zoom: float=game.camera_zoom
    var saved_center: Vector2=game.camera_center
    game.camera_zoom=2.5
    game.call("_clamp_camera")
    game.map_layer.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("soldier_detail.png"):
        quit(1)
        return
    game.camera_zoom=saved_zoom
    game.camera_center=saved_center
    game.call("_clamp_camera")
    game.map_layer.queue_redraw()
    print("SOLDIER_ATLAS_PASS: 18 populated cells, all facing regions checked")
    var scenery_atlas: Texture2D=load("res://assets/art/battlefield_detail.svg")
    if scenery_atlas==null or scenery_atlas.get_size()!=Vector2(768,512):
        push_error("VISUAL_CAPTURE_FAIL: scenery atlas dimensions invalid")
        quit(1)
        return
    var scenery_pixels: Image=scenery_atlas.get_image()
    for tile in range(6):
        var cell:=Rect2i((tile%3)*256,floori(float(tile)/3.0)*256,256,256)
        if scenery_pixels.get_region(cell).get_used_rect().size.x<40:
            push_error("VISUAL_CAPTURE_FAIL: scenery atlas cell empty")
            quit(1)
            return
    var shadow_alpha: float=scenery_pixels.get_pixel(135,230).a
    if shadow_alpha<0.15 or shadow_alpha>0.60:
        push_error("VISUAL_CAPTURE_FAIL: bridge shadow must remain translucent")
        quit(1)
        return
    var prior_center: Vector2=game.camera_center
    var prior_zoom: float=game.camera_zoom
    game.camera_center=Vector2(game.sim.river_x(850.0),850.0)
    game.camera_zoom=2.0
    game.call("_clamp_camera")
    game.map_layer.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("bridge_material_detail.png"):
        quit(1)
        return
    game.camera_center=prior_center
    game.camera_zoom=prior_zoom
    game.call("_clamp_camera")
    game.map_layer.queue_redraw()
    print("SCENERY_ATLAS_PASS: six populated atlas regions and real bridge capture")
    var motion_atlas: Texture2D=load("res://assets/art/soldier_motion.svg")
    if motion_atlas==null or motion_atlas.get_size()!=Vector2(1728,576):
        push_error("VISUAL_CAPTURE_FAIL: motion atlas dimensions invalid")
        quit(1)
        return
    var motion_pixels: Image=motion_atlas.get_image()
    for row in range(6):
        for col in range(18):
            var cell:=Rect2i(col*96,row*96,96,96)
            if motion_pixels.get_region(cell).get_used_rect().size.x<20:
                push_error("VISUAL_CAPTURE_FAIL: empty motion atlas cell")
                quit(1)
                return
    var pose_unit: Dictionary={"type":"보병","motion_speed":0.0,"routed":false,"last_visual":10.0,"last_hit":-100.0,"contact_troops":4,"ammo":100.0}
    if game.call("_soldier_pose",pose_unit,1,10.04)!=3 or game.call("_soldier_pose",pose_unit,1,10.20)!=4 or game.call("_soldier_pose",pose_unit,1,10.43)!=2:
        push_error("VISUAL_CAPTURE_FAIL: attack pose timing incorrect")
        quit(1)
        return
    pose_unit["type"]="궁병"
    pose_unit["ammo"]=0.0
    if game.call("_soldier_pose",pose_unit,1,10.8)!=-1:
        push_error("VISUAL_CAPTURE_FAIL: empty quiver still preparing shot")
        quit(1)
        return
    pose_unit["type"]="기병"
    pose_unit["motion_speed"]=50.0
    pose_unit["routed"]=true
    var stride:int=game.call("_soldier_pose",pose_unit,1,10.02)
    if stride<0 or stride>1 or game.call("_soldier_pose",pose_unit,1,10.02)!=stride:
        push_error("VISUAL_CAPTURE_FAIL: routed or frozen stride invalid")
        quit(1)
        return
    print("SOLDIER_MOTION_PASS: 108 atlas cells and deterministic attack/march timing")


    # Verify presentation-only density, the real high-resolution terrain and shared skin.
    var skin: Texture2D=load("res://assets/art/command_skin.svg")
    if skin==null or skin.get_size()!=Vector2(768,256):
        push_error("VISUAL_CAPTURE_FAIL: command skin atlas dimensions invalid")
        quit(1)
        return
    var terrain_size: Vector2=game.terrain_cache.get_size()
    if terrain_size.x<2025 or terrain_size.y<1282:
        push_error("VISUAL_CAPTURE_FAIL: terrain resolution did not improve")
        quit(1)
        return
    var sample_army: Dictionary=game.sim.find_unit(0).duplicate(true)
    sample_army["troops"]=4680.0
    sample_army["next_formation"]=""
    var slots: Array=game.call("_visual_slots",sample_army)
    if slots.size()!=72:
        push_error("VISUAL_CAPTURE_FAIL: increased formation density missing")
        quit(1)
        return
    if float(game.sim.find_unit(0)["troops"])==4680.0:
        print("VISUAL_NOTE: actual unit coincidentally has sample strength")
    print("INTEGRATED_VISUAL_PASS: terrain "+str(terrain_size)+" / 72 presentation slots / command skin")

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
    var combat_captured: bool=false
    for i in range(600):
        if game.sim.finished: break
        game.call("_process",0.1)
        if combat_captured: continue
        for fx in game.sim.visual_effects:
            var age: float=game.sim.battle_time-float(fx["time"])
            if age<0.1 or age>0.35: continue
            if not game.sim.player_can_see(fx["from"]) or not game.sim.player_can_see(fx["to"]): continue
            game.camera_center=(fx["from"] as Vector2).lerp(fx["to"],0.5)
            game.camera_zoom=1.8
            game.call("_clamp_camera")
            game.map_layer.queue_redraw()
            await process_frame
            await RenderingServer.frame_post_draw
            if not _save_frame("live_combat_effect.png"):
                quit(1)
                return
            combat_captured=true
            break
    if not combat_captured:
        print("VISUAL_NOTE: no visible combat event in capture window")
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
