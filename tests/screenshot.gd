extends SceneTree
## Captures real Godot-rendered UI frames (not mockups).
## Requires a real graphics display such as Xvfb; DO NOT use --headless.
const MAIN_SCENE = preload("res://main.tscn")
const FrontView = preload("res://scripts/front_view.gd")
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
    if game.general_cards.size() != 6:
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
    var orders: Control=game.order_view
    var east:=Vector2(1920,910)
    orders.destination=east
    orders.has_destination=true
    orders.call("_choose_action",2)
    orders.call("_select",0)
    orders.call("_select",1)
    var crossing: float=game.sim.map_order_crossing(1,east)
    if orders.destination!=east or orders.action_choice.selected!=2 or crossing<0.0 or not orders.destination_label.text.contains("예상") or not orders.route_summary.text.contains(game.call("_bridge_name",crossing)):
        push_error("VISUAL_CAPTURE_FAIL: commander draft or bridge projection missing")
        quit(1)
        return
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("bridge_order_draft.png"):
        quit(1)
        return
    orders.destination=Vector2(game.sim.river_x(600.0),600.0)
    orders.call("_mark_draft")
    if not orders.apply.disabled or not orders.feedback.text.contains("교량이나 강둑"):
        push_error("VISUAL_CAPTURE_FAIL: river destination accepted by the command UI")
        quit(1)
        return
    orders.drafts.clear()
    orders.draft_dirty=false
    orders.call("_select",1)
    print("ORDER_DRAFT_ROUTE_PASS")
    game.call("_start")
    var own_id: int=game.selected_id
    if game.fog_enabled or game.enemy_list.item_count!=6:
        push_error("VISUAL_CAPTURE_FAIL: both sides must be visible in default demo")
        quit(1)
        return
    game.call("_show_enemy_roster")
    game.call("_inspect_enemy_row",0)
    if game.observed_enemy_id<0 or game.selected_id!=own_id or game.commander_scroll.visible or not game.enemy_list.visible:
        push_error("VISUAL_CAPTURE_FAIL: enemy inspection changed friendly command authority")
        quit(1)
        return
    game.call("_refresh_hud")
    game.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("enemy_inspection.png"):
        quit(1)
        return
    game.call("_toggle_fog",true)
    if game.enemy_strength.text!="정찰 제한":
        push_error("VISUAL_CAPTURE_FAIL: hidden total shown in top bar")
        quit(1)
        return
    for sector in game.sector_cards:
        if sector.own_bar.visible or sector.enemy_bar.visible or not sector.enemy.text.begins_with("관측 적군"):
            push_error("VISUAL_CAPTURE_FAIL: front balance must respect limited observation")
            quit(1)
            return
    for row in range(game.enemy_list.item_count):
        var id: int=int(game.enemy_list.get_item_metadata(row))
        if id<0: continue
        if not game.call("_visible_unit",game.sim.find_unit(id)):
            push_error("VISUAL_CAPTURE_FAIL: hidden enemy leaked to roster")
            quit(1)
            return
    game.call("_toggle_fog",false)
    var strength_sum: int=0
    for i in range(game.sector_cards.size()):
        var sector=game.sector_cards[i]
        var front: Dictionary=game.sector_snapshot[i]
        strength_sum+=int(front["own"])
        if sector.state.text!=front["state"] or sector.enemy.text!="적군  "+game.call("_number_text",front["enemy"]):
            push_error("VISUAL_CAPTURE_FAIL: front label disagrees with current observed forces")
            quit(1)
            return
    if strength_sum!=game.sim.total_troops(0) or game.friendly_strength.text!=game.call("_number_text",strength_sum):
        push_error("VISUAL_CAPTURE_FAIL: friendly strength does not match fronts")
        quit(1)
        return
    game.call("_show_friendly_roster")
    game.call("_reset_camera")
    if game.combat_sounds.size()!=3 or game.combat_players.size()!=4:
        push_error("VISUAL_CAPTURE_FAIL: battle Foley not initialized")
        quit(1)
        return
    print("PLAYABILITY_PASS: enemy inspection, fog, command isolation and combat audio")
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
    var journal_center: Vector2=game.camera_center
    var journal_zoom: float=game.camera_zoom
    var journal_general: int=game.selected_id
    var journal_time: float=game.sim.battle_time
    game.journal_button.pressed.emit()
    await process_frame
    await RenderingServer.frame_post_draw
    if not game.journal_dialog.visible or game.journal_events.is_empty():
        push_error("VISUAL_CAPTURE_FAIL: observed contact missing from command journal")
        quit(1)
        return
    if not _save_frame("battle_journal.png"):
        quit(1)
        return
    game.journal_list.item_activated.emit(0)
    if game.journal_dialog.visible or game.camera_zoom!=1.4 or game.sim.battle_time!=journal_time:
        push_error("VISUAL_CAPTURE_FAIL: journal did not navigate without advancing time")
        quit(1)
        return
    game.camera_center=journal_center
    game.camera_zoom=journal_zoom
    game.call("_on_unit_selected",game.sim.command_ids(0).find(journal_general))
    game.map_layer.queue_redraw()
    print("BATTLE_JOURNAL_PASS")
    game.call("_open_mind_report")
    await process_frame
    await RenderingServer.frame_post_draw
    if not game.mind_report.text.contains("왕평") or not game.mind_report.text.contains("마속") or not game.mind_report.text.contains("관측:") or not game.mind_report.text.contains("최근 명령:"):
        push_error("VISUAL_CAPTURE_FAIL: live general report incomplete")
        quit(1)
        return
    if not _save_frame("general_mind_report.png"):
        quit(1)
        return
    game.mind_dialog.hide()
    game.call("_toggle_feed")
    if not game.battle_feed.visible or not game.event_label.visible or not game.general_cards[5].visible:
        push_error("VISUAL_CAPTURE_FAIL: battle log must keep the commander cards available")
        quit(1)
        return
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("commander_battle_log.png"):
        quit(1)
        return
    game.call("_toggle_feed")
    var portraits: Texture2D=load("res://assets/art/general_portraits.svg")
    if portraits==null or portraits.get_size()!=Vector2(1152,864):
        push_error("VISUAL_CAPTURE_FAIL: general portrait atlas unavailable")
        quit(1)
        return
    var officers: Texture2D=load("res://assets/art/shu_commanders.webp")
    if officers==null or officers.get_size()!=Vector2(768,512):
        push_error("VISUAL_CAPTURE_FAIL: friendly portrait sheet unavailable")
        quit(1)
        return
    var regions: Array[String]=[]
    var painted: Texture2D=load("res://assets/art/painted_atlas.webp")
    for side in range(2):
        for id in game.sim.command_ids(side):
            var u: Dictionary=game.sim.find_unit(id)
            var icon: AtlasTexture=game.call("_commander_icon",str(u["name"]),side)
            var key: String=icon.atlas.resource_path+":"+str(icon.region)
            if (side==0 and icon.atlas!=officers) or (side==1 and icon.atlas not in [portraits,painted]) or regions.has(key):
                push_error("VISUAL_CAPTURE_FAIL: commander portrait reused or missing")
                quit(1)
                return
            regions.append(key)
    print("GENERAL_PORTRAITS_PASS: "+str(regions.size())+" distinct live portrait regions")
    if not game.mind_report.text.contains("건의:"):
        push_error("VISUAL_CAPTURE_FAIL: general proposal not presented")
        quit(1)
        return
    if game.general_cards.size()!=6:
        push_error("VISUAL_CAPTURE_FAIL: persistent six commander cards missing")
        quit(1)
        return
    for i in range(6):
        var card=game.general_cards[i]
        var officer_id: int=game.sim.command_ids(0)[i]
        var expected_troops: String=game.call("_number_text",roundi(game.sim.corps_report(officer_id)["troops"]))+"명"
        if not card.visible or card.commander.text!=game.sim.find_unit(officer_id)["name"] or card.strength.text!=expected_troops or card.action.text.is_empty() or card.mood.text.is_empty() or card.note.text.is_empty():
            push_error("VISUAL_CAPTURE_FAIL: commander card missing live state")
            quit(1)
            return
    var field := Rect2(game.MAP_TOP_LEFT,game.MAP_SIZE)
    var screen := Rect2(0,0,1280,800)
    var occupied: Array[Rect2]=[]
    for card in game.general_cards:
        var box: Rect2=card.get_rect()
        if box.intersects(field) or not screen.encloses(box):
            push_error("VISUAL_CAPTURE_FAIL: commander strip obstructs the battlefield or falls outside the screen")
            quit(1)
            return
        for prior_box in occupied:
            if box.intersects(prior_box):
                push_error("VISUAL_CAPTURE_FAIL: commander cards overlap")
                quit(1)
                return
        occupied.append(box)
    game.sector_cards[2].pressed.emit()
    if not game.sector_cards[2].button_pressed or game.sector_selection!=2:
        push_error("VISUAL_CAPTURE_FAIL: south front focus did not respond")
        quit(1)
        return
    game.call("_select_general_card",2)
    if game.sector_cards[2].button_pressed or game.selected_id!=game.sim.command_ids(0)[2]:
        push_error("VISUAL_CAPTURE_FAIL: commander card did not select real leader")
        quit(1)
        return
    var selected: Dictionary=game.sim.find_unit(game.selected_id)
    var original_reason: String=selected["reason"]
    var mind: Dictionary=selected["mind"]
    var original_proposal: String=mind["proposal"]
    var long_reason: String=("측면에서 접근하는 군단을 막고 아군 기병이 합류할 때까지 도하로를 지킨다. ").repeat(6)
    selected["reason"]=long_reason
    mind["proposal"]="재집결"
    game.call("_refresh_hud")
    await process_frame
    await process_frame
    var scrollbar: VScrollBar=game.commander_scroll.get_v_scroll_bar()
    if game.decision_label.text!=long_reason or game.decision_label.get_line_count()<3 or game.decision_label.max_lines_visible!=-1 or not scrollbar.visible or not game.commander_request.text.contains("재집결"):
        push_error("VISUAL_CAPTURE_FAIL: long judgment must wrap and leave the proposal reachable")
        quit(1)
        return
    scrollbar.value=scrollbar.max_value
    var scroll_position: int=game.commander_scroll.scroll_vertical
    game.call("_refresh_hud")
    if scroll_position<=0 or game.commander_scroll.scroll_vertical!=scroll_position:
        push_error("VISUAL_CAPTURE_FAIL: periodic refresh moved the reader away from scrolled text")
        quit(1)
        return
    selected["reason"]=original_reason
    mind["proposal"]=original_proposal
    game.call("_select_general_card",0)
    if game.commander_scroll.scroll_vertical!=0 or not game.general_cards[0].button_pressed:
        push_error("VISUAL_CAPTURE_FAIL: switching commanders did not return the inspector to the top")
        quit(1)
        return
    print("COMMANDER_DESK_SCROLL_PASS")
    var sites: Texture2D=load("res://assets/art/field_sites.svg")
    if sites==null or sites.get_size()!=Vector2(1536,384):
        push_error("VISUAL_CAPTURE_FAIL: site art unavailable")
        quit(1)
        return
    for i in range(4):
        if sites.get_image().get_region(Rect2i(i*384,0,384,384)).get_used_rect().size.x<100:
            push_error("VISUAL_CAPTURE_FAIL: empty site texture")
            quit(1)
            return
    game.call("_reset_camera")
    game.map_layer.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("commander_live_board.png"):
        quit(1)
        return
    for i in range(game.map_label_areas.size()):
        for j in range(i+1,game.map_label_areas.size()):
            if game.map_label_areas[i].intersects(game.map_label_areas[j]):
                push_error("VISUAL_CAPTURE_FAIL: overlapping allocated map labels")
                quit(1)
                return
    if game.forest_instances.is_empty() or game.forest_textures.size()!=5:
        push_error("VISUAL_CAPTURE_FAIL: separate forest layer missing")
        quit(1)
        return
    for texture in game.forest_textures:
        var canopy: Image=texture.get_image()
        if canopy.get_size()!=Vector2i(192,192) or canopy.get_pixel(0,0).a>0.1 or canopy.get_pixel(86,137).a<0.8:
            push_error("VISUAL_CAPTURE_FAIL: canopy atlas must preserve transparency and trunk alignment")
            quit(1)
            return
    var previous_y: float=-INF
    for tree in game.forest_instances:
        var point:Vector2=tree["pos"]
        if point.y<previous_y or game.sim.terrain_at(point)=="하천":
            push_error("VISUAL_CAPTURE_FAIL: invalid forest instance order or location")
            quit(1)
            return
        for lane in range(3):
            if absf(point.y-game.sim.road_y(point.x,lane))<34.0:
                push_error("VISUAL_CAPTURE_FAIL: tree on road")
                quit(1)
                return
        previous_y=point.y
    print("FOREST_DEPTH_LAYER_PASS: "+str(game.forest_instances.size())+" trees")
    print("MAP_LABEL_LAYOUT_PASS")
    print("COMMANDER_BOARD_AND_SITES_PASS")
    print("GENERAL_REPORT_VISUAL_PASS")

    game.call("_toggle_feed")
    if not game.combat_brief.text.contains("아군 손실") or not game.live_order_label.text.contains("현재:"):
        push_error("VISUAL_CAPTURE_FAIL: real battle feedback missing")
        quit(1)
        return
    game.call("_toggle_feed")
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
    if terrain_size.x<2700 or terrain_size.y<1710:
        push_error("VISUAL_CAPTURE_FAIL: terrain resolution did not improve")
        quit(1)
        return
    var actual_strength: float=float(game.sim.find_unit(0)["troops"])
    var actual_slots: Array[Vector2]=game.sim.formation_slots(game.sim.find_unit(0))
    var sample_army: Dictionary=game.sim.find_unit(0).duplicate(true)
    sample_army["id"]=-600
    sample_army["type"]="보병"
    sample_army["troops"]=4680.0
    sample_army["next_formation"]=""
    sample_army["contact_target_id"]=-1
    var slots: Array[Vector2]=game.call("_visual_slots",sample_army)
    var cavalry: Dictionary=sample_army.duplicate()
    cavalry["type"]="기병"
    var mounted_slots: Array[Vector2]=game.call("_visual_slots",cavalry)
    if slots.size()!=213 or mounted_slots.size()!=144 or float(game.sim.find_unit(0)["troops"])!=actual_strength or (
        game.sim.formation_slots(game.sim.find_unit(0))!=actual_slots
    ):
        push_error("VISUAL_CAPTURE_FAIL: density or presentation isolation invalid")
        quit(1)
        return
    var saved_density_zoom: float=game.camera_zoom
    var density_units: Array[Dictionary]=[sample_army]
    var density_view:=Rect2(Vector2.ZERO,game.sim.field_size)
    game.camera_zoom=1.8
    var close_batch: Array[Dictionary]=game.call("_visible_soldier_batch",density_units,density_view)
    game.camera_zoom=0.8
    var distant_batch: Array[Dictionary]=game.call("_visible_soldier_batch",density_units,density_view)
    game.camera_zoom=saved_density_zoom
    if close_batch.size()!=slots.size() or distant_batch.size()!=96:
        push_error("VISUAL_CAPTURE_FAIL: unexpected amount of representative soldiers at supported zoom levels")
        quit(1)
        return
    var deck: Image=game.TerrainArt.TIMBER_CROSSING.get_image()
    if deck.get_size()!=Vector2i(520,211) or deck.get_pixel(0,0).a>0.1 or deck.get_pixel(260,105).a<0.9:
        push_error("VISUAL_CAPTURE_FAIL: crossing deck or transparent banks missing")
        quit(1)
        return
    var terrain_pixels: Image=game.terrain_cache.get_image()
    for crossing_y in [390.0,850.0,1300.0]:
        var deck_center: Color=terrain_pixels.get_pixel(roundi(game.sim.river_x(crossing_y)),roundi(crossing_y))
        if deck_center.r<=deck_center.b:
            push_error("VISUAL_CAPTURE_FAIL: bridge deck missing from minimap terrain")
            quit(1)
            return
    var cloth: Image=game.CORPS_STANDARDS.get_image()
    var crane: Color=cloth.get_pixel(18,33)
    var tiger: Color=cloth.get_pixel(146,33)
    if cloth.get_size()!=Vector2i(256,160) or crane.b<=crane.r or tiger.r<=tiger.b or minf(crane.a,tiger.a)<0.9:
        push_error("VISUAL_CAPTURE_FAIL: faction standards must have distinct dyed cloth")
        quit(1)
        return
    if not game.commander_scroll.visible or game.enemy_list.visible or game.commander_scroll.get_global_rect().intersects(game.live_order_button.get_global_rect()):
        push_error("VISUAL_CAPTURE_FAIL: commander inspector must leave command controls accessible")
        quit(1)
        return
    game.call("_refresh_visibility")
    if game.visibility_texture.get_size()!=Vector2(90,57):
        push_error("VISUAL_CAPTURE_FAIL: refined fog texture missing")
        quit(1)
        return
    var batch_units: Array[Dictionary]=[]
    batch_units.append(game.sim.find_unit(0))
    batch_units.append(game.sim.find_unit(3))
    var rendered: Array[Dictionary]=game.call("_visible_soldier_batch",batch_units,Rect2(Vector2.ZERO,game.sim.field_size))
    var prev_y: float=-INF
    for item in rendered:
        var point: Vector2=item["point"]
        if point.y<prev_y:
            push_error("VISUAL_CAPTURE_FAIL: opposing soldiers not depth sorted")
            quit(1)
            return
        prev_y=point.y
    if rendered.is_empty():
        push_error("VISUAL_CAPTURE_FAIL: no globally sorted soldier instances")
        quit(1)
        return
    print("INTEGRATED_VISUAL_PASS: terrain "+str(terrain_size)+" / denser presentation slots / command skin / HQ bridge / depth sort / live roster / refined fog")

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
            # Exercise the same button the player uses. Do not set the camera
            # or select a commander in the harness after pressing it.
            var focused:Dictionary=game.sim.visual_effects.back()
            var own_ids:Array[int]=game.sim.command_ids(0)
            var expected:int=-1
            for key in ["attacker_id","defender_id"]:
                if own_ids.has(int(focused.get(key,-1))):
                    expected=int(focused[key])
                    break
            if expected<0: continue
            var origin:Vector2=focused.get("visual_from",focused["from"])
            var target:Vector2=focused.get("visual_to",focused["to"])
            var half_view:Vector2=game.MAP_SIZE*0.5/1.8
            var expected_center:Vector2=origin.lerp(target,0.5).clamp(half_view,game.sim.field_size-half_view)
            game.call("_show_enemy_roster")
            game.contact_button.pressed.emit()
            if game.selected_id!=expected or game.observing_enemy or not is_equal_approx(game.camera_zoom,1.8) or not game.camera_center.is_equal_approx(expected_center):
                push_error("VISUAL_CAPTURE_FAIL: combat button did not frame the contact and select its commander")
                quit(1)
                return
            print("COMBAT_COMMANDER_FOCUS_PASS")
            await process_frame
            await RenderingServer.frame_post_draw
            if not _save_frame("live_combat_effect.png"):
                quit(1)
                return
            combat_captured=true
            break
    if not combat_captured:
        push_error("VISUAL_CAPTURE_FAIL: no combat event to verify the focus button")
        quit(1)
        return
    var observed_loss: bool=false
    for id in game.recent_losses:
        var sample: Dictionary=game.recent_losses[id]
        var victim: Dictionary=game.sim.find_unit(id)
        if not victim.is_empty() and int(sample["count"])>0 and int(sample["count"])<=roundi(float(victim["casualties_taken"])): observed_loss=true
    if not observed_loss:
        push_error("VISUAL_CAPTURE_FAIL: no actual casualty feedback")
        quit(1)
        return
    print("REAL_CASUALTY_FEEDBACK_PASS")
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
    if not await _capture_combat_drill():
        quit(1)
        return
    if not await _capture_field_report():
        quit(1)
        return
    if not await _capture_training_field():
        quit(1)
        return
    if not await _capture_linked_march():
        quit(1)
        return
    if not await _capture_field_judgment():
        quit(1)
        return
    print("GUNRYAK_VISUAL_CAPTURE_PASSED")
    quit(0)

func _capture_field_judgment() -> bool:
    game.queue_free()
    await process_frame
    game=MAIN_SCENE.instantiate()
    root.add_child(game)
    game.set_process(false)
    game._leave_title(5)
    var drill=preload("res://tests/field_judgment.gd")
    drill.stage(game.sim)
    game._start()
    game.selected_id=0
    game.camera_center=Vector2(737,766)
    game.camera_zoom=2.10
    game._clamp_camera()
    var general: Dictionary=game.sim.find_unit(0)
    for mode in ["아군 보호","공격 지속"]:
        if mode=="공격 지속": drill.expose_opening(game.sim)
        general["ai_cooldown"]=0.0
        game.sim.step(0.1)
        if general["action"]!=mode or game._field_action(general)!=mode:
            push_error("VISUAL_CAPTURE_FAIL: missing general decision "+mode)
            return false
        game._refresh_hud()
        game.map_layer.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        if not _save_frame("field_protect.png" if mode=="아군 보호" else "field_press.png"): return false
    print("FIELD_JUDGMENT_VISUAL_PASS")
    return true

func _capture_linked_march() -> bool:
    game.queue_free()
    await process_frame
    game=MAIN_SCENE.instantiate()
    root.add_child(game)
    game.set_process(false)
    game._leave_title(5)
    var sheet: Control=game.order_view
    var destination:=Vector2(650,1460)
    for entry in [[0,Vector2(650,400)],[1,Vector2(630,275)],[2,Vector2(500,385)]]:
        if not game.sim.place_unit(entry[0],entry[1]): return false
    for id in [0,2,1]:
        sheet._select(id)
        sheet.destination=destination
        sheet.has_destination=true
        if id!=0: sheet.partner_choice.select(1)
        sheet._choose_action(0)
        sheet._apply()
    if sheet.march_diagram.get("group",[]).size()!=3 or not sheet.march_preview.text.contains("궁병 후열") or sheet.march_diagram["forward"].y<0.95:
        push_error("VISUAL_CAPTURE_FAIL: southbound company missing from order sheet")
        return false
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("linked_march_orders.png"): return false
    sheet.launch.pressed.emit()
    for i in range(128): game._process(0.1)
    for id in [0,1,2]:
        var march: Dictionary=game.sim.march_plans.get(id,{})
        var u: Dictionary=game.sim.find_unit(id)
        if march.get("phase","")!="연계 행군" or absf(u["motion_speed"]-march["pace"])>0.02:
            push_error("VISUAL_CAPTURE_FAIL: displayed company moving outside its shared pace")
            return false
    game.selected_id=1
    game.camera_center=Vector2(620,558)
    game.camera_zoom=1.02
    game._clamp_camera()
    game._refresh_hud()
    game.queue_redraw()
    game.map_layer.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("linked_march_field.png"): return false
    print("LINKED_MARCH_VISUAL_PASS")
    return true

func _capture_training_field() -> bool:
    game.queue_free()
    await process_frame
    game=MAIN_SCENE.instantiate()
    root.add_child(game)
    game.set_process(false)
    var entry: Button
    for child in game.title_screen.get_children():
        if child is Button and child.text=="지형 시험장": entry=child
    if entry==null:
        push_error("VISUAL_CAPTURE_FAIL: training field missing from title")
        return false
    entry.pressed.emit()
    var sheet: Control=game.order_view
    if not sheet.visible or not sheet.survey.visible or sheet.survey_sites.size()!=13:
        push_error("VISUAL_CAPTURE_FAIL: training field is missing survey landmarks")
        return false
    sheet.destination=sheet.survey_sites["점령 거점"]
    sheet.has_destination=true
    sheet.call("_choose_action",2)
    var drafts: Dictionary=sheet.drafts.duplicate(true)
    var index: int=sheet.survey_sites.keys().find("습지")+1
    sheet.survey.select(index)
    sheet.survey.item_selected.emit(index)
    if sheet.drafts!=drafts or not sheet.survey_detail.text.contains("66%") or sheet.apply.disabled:
        push_error("VISUAL_CAPTURE_FAIL: surveying the marsh changed the order or showed incorrect cost")
        return false
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("training_orders.png"): return false
    sheet.apply.pressed.emit()
    sheet.launch.pressed.emit()
    if not game.sim.started or sheet.visible:
        push_error("VISUAL_CAPTURE_FAIL: unable to launch the training operation")
        return false
    game.camera_center=sheet.survey_sites["습지"]
    game.camera_zoom=1.05
    game.call("_clamp_camera")
    game.map_layer.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("training_marsh.png"): return false
    game.call("_reset_camera")
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("training_overview.png"): return false
    print("TRAINING_FIELD_VISUAL_PASS")
    return true

func _capture_combat_drill() -> bool:
    # Run two real engagements at a known location. Time and damage come from
    # WarSim. Positioning the units makes simultaneous fronts reproducible.
    game.queue_free()
    await process_frame
    game=MAIN_SCENE.instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false)
    game.call("_leave_title")
    game.call("_start")
    game.sim.battle_time=10.0
    game.sim.forests.clear()
    for unit in game.sim.units:
        unit["troops"]=0.0
    var rider: Dictionary=game.sim.find_unit(2)
    rider["pos"]=Vector2(990,780)
    rider["troops"]=rider["initial_troops"]
    rider["facing"]=Vector2.RIGHT
    rider["charge"]=63.0
    rider["charge_speed"]=75.0
    rider["charge_dir"]=Vector2.RIGHT
    var square: Dictionary=game.sim.find_unit(3)
    square["pos"]=Vector2(1025,780)
    square["type"]="보병"
    square["formation"]="방진"
    square["facing"]=Vector2.LEFT
    square["troops"]=square["initial_troops"]
    var archer: Dictionary=game.sim.find_unit(1)
    archer["pos"]=Vector2(960,1010)
    archer["facing"]=Vector2.RIGHT
    archer["troops"]=archer["initial_troops"]
    var target: Dictionary=game.sim.find_unit(4)
    target["pos"]=Vector2(1095,1010)
    target["troops"]=target["initial_troops"]
    game.sim._combat(0.1)
    game.call("_update_contact_fronts",0.1)
    var attacks: Dictionary=game.sim.combat_contacts
    if not bool(attacks.get(2,{}).get("braced",false)) or attacks.get(1,{}).get("arrow_lanes",[]).size()<4:
        push_error("VISUAL_CAPTURE_FAIL: real drill did not generate a brace and multiple arrow lanes")
        return false
    game.contact_button.pressed.emit()
    var first_pair: Vector2i=game.combat_focus_pair
    var first_center: Vector2=game.camera_center
    game.contact_button.pressed.emit()
    if game.combat_focus_pair==first_pair or first_center.is_equal_approx(game.camera_center):
        push_error("VISUAL_CAPTURE_FAIL: contact button did not cycle through simultaneous visible fights")
        return false
    game.call("_on_unit_selected",game.sim.command_ids(0).find(2))
    var exchange: Vector2=game.call("_recent_corps_exchange",2)
    if not is_equal_approx(exchange.x,float(rider["damage_dealt"])) or not is_equal_approx(exchange.y,float(rider["casualties_taken"])):
        push_error("VISUAL_CAPTURE_FAIL: recent exchange is inconsistent with the actual combat")
        return false
    if not game.combat_exchange.text.contains("최근 8초") or not game.commander_observation.text.contains("방진에 돌격 저지"):
        push_error("VISUAL_CAPTURE_FAIL: selected commander does not explain the actual brace encounter")
        return false
    game.camera_center=Vector2(1032,896)
    game.camera_zoom=1.52
    game.render_clock=game.sim.battle_time+0.32
    game.detailed_map=true
    game.call("_clamp_camera")
    game.map_layer.queue_redraw()
    game.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    print("COMBAT_DRILL_PASS")
    if not _save_frame("combat_drill.png"):
        return false
    if not await _capture_bow_motion(archer,target): return false
    return await _capture_contact_shape(rider,square)

func _capture_contact_shape(rider: Dictionary,square: Dictionary) -> bool:
    game.camera_zoom=2.8
    game.camera_center=(rider["pos"] as Vector2).lerp(square["pos"],0.5)
    game.call("_clamp_camera")
    game.call("_on_unit_selected",game.sim.command_ids(0).find(2))
    var base: Array[Vector2]=game.call("_visual_slots",square)
    for tick in range(4):
        game.sim.battle_time+=0.1
        game.sim._combat(0.1)
        game.call("_update_contact_fronts",0.1)
    if not game.fronts_by_unit.has(2) or not game.fronts_by_unit.has(3) or game.fronts_by_unit.has(1) or game.fronts_by_unit.has(4):
        push_error("VISUAL_CAPTURE_FAIL: observed melee must fold both formations and spare distant archers")
        return false
    var folded: Array[Vector2]=game.call("_contact_slots",square,base)
    var largest: float=0.0
    var untouched: int=0
    for i in range(base.size()):
        largest=maxf(largest,base[i].distance_to(folded[i]))
        if base[i].is_equal_approx(folded[i]): untouched+=1
    if largest<5.0 or untouched==0:
        push_error("VISUAL_CAPTURE_FAIL: contact must bend engaged files and leave distant files in formation")
        return false
    game.render_clock=game.sim.battle_time
    game.map_layer.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save_frame("formation_contact.png"): return false
    rider["pos"]=Vector2(640,780)
    game.sim._combat(0.1)
    game.call("_update_contact_fronts",0.1)
    var recovering: Array[Vector2]=game.call("_contact_slots",square,base)
    var i: int=0
    while base[i].is_equal_approx(folded[i]): i+=1
    var remaining: float=recovering[i].distance_to(base[i])
    if remaining<=0.0 or remaining>=folded[i].distance_to(base[i]):
        push_error("VISUAL_CAPTURE_FAIL: disengagement must ease the bent ranks back")
        return false
    for tick in range(15): game.call("_update_contact_fronts",0.1)
    if game.fronts_by_unit.has(3):
        push_error("VISUAL_CAPTURE_FAIL: old contact still affects the formation after recovery")
        return false
    print("FORMATION_CONTACT_PASS max_shift=%.2f untouched=%d/%d" % [largest,untouched,base.size()])
    return true

func _capture_bow_motion(archer: Dictionary, target: Dictionary) -> bool:
    var release: float=FrontView.VOLLEY_RELEASE+FrontView.volley_lane_delay(1)
    if FrontView.bow_phase(0.04)!=FrontView.BowPhase.LIFT or FrontView.bow_phase(0.14)!=FrontView.BowPhase.DRAW or (
        FrontView.bow_phase(FrontView.VOLLEY_RELEASE)!=FrontView.BowPhase.RELEASE or FrontView.bow_phase(0.38)!=FrontView.BowPhase.LOWER
    ) or not is_zero_approx(FrontView.arrow_age(release,1)) or FrontView.arrow_age(release-0.01,1)>=0.0:
        push_error("VISUAL_CAPTURE_FAIL: arrow must appear on the release pose of its own shooting lane")
        return false
    var p: Vector2=archer["pos"]
    var q: Vector2=target["pos"]
    var lanes: Array[Vector2]=game.sim.combat_contacts[int(archer["id"])]["arrow_lanes"]
    var lane: int=game.call("_nearest_volley_lane",lanes[0],lanes)
    if lane!=0 or FrontView.arrow_position(p,q,0.5,8.0).y>=p.lerp(q,0.5).y:
        push_error("VISUAL_CAPTURE_FAIL: volley travel does not use its source and curved flight")
        return false
    game.call("_on_unit_selected",game.sim.command_ids(0).find(int(archer["id"])))
    game.camera_center=p.lerp(q,0.46)
    game.camera_zoom=2.8
    game.call("_clamp_camera")
    var view:=Rect2(Vector2.ZERO,game.sim.field_size)
    var samples: Array[float]=[0.03,0.09,0.15,0.21,0.255,0.31,0.37,0.43,0.50,0.58,0.66,0.76]
    var shooters: Array[Dictionary]=[archer]
    for i in range(samples.size()):
        game.render_clock=game.sim.battle_time+samples[i]
        var batch: Array[Dictionary]=game.call("_visible_soldier_batch",shooters,view)
        var firing: bool=false
        for soldier in batch:
            if FrontView.bow_phase(float(soldier["bow_age"]))==FrontView.BowPhase.RELEASE:
                firing=true
                break
        if i==4 and not firing:
            push_error("VISUAL_CAPTURE_FAIL: no real archer enters the release pose")
            return false
        game.map_layer.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        if not _save_frame("archer_motion_%02d.png" % i):
            return false
    print("ARCHER_MOTION_PASS")
    return true

func _capture_field_report() -> bool:
    game.queue_free()
    await process_frame
    game=MAIN_SCENE.instantiate()
    root.add_child(game)
    game.set_process(false)
    await process_frame
    game.call("_leave_title")
    game.call("_start")
    game.game_speed=4.0
    for tick in range(3600):
        game.call("_process",0.1)
        if game.sim.turn>=6 and not game.sim.open_situations().is_empty(): break
    if game.sim.open_situations().is_empty():
        push_error("VISUAL_CAPTURE_FAIL: no delivered field report in the operation")
        return false
    game.call("_refresh_hud")
    var report: Dictionary=game.call("_prioritized_situations")[0]
    var reporter_index: int=game.sim.command_ids(0).find(int(report["unit_id"]))
    if reporter_index<0 or not game.general_cards[reporter_index].report_link.visible or not game.dispatch_headline.visible or not game.dispatch_headline.text.contains(report["title"]):
        push_error("VISUAL_CAPTURE_FAIL: current field dispatch is missing from the battlefield")
        return false
    # A second delivered report exercises per-commander selection even while another
    # commander has the highest priority. Remove the fixture before resuming the operation.
    var other: Dictionary=report.duplicate(true)
    other["id"]=int(report["id"])+100000
    other["unit_id"]=game.sim.command_ids(0)[(reporter_index+1)%game.general_cards.size()]
    other["pos"]=game.sim.find_unit(other["unit_id"])["pos"]
    other["kind"]="지휘 건의"
    game.sim.situation_reports.append(other)
    game.call("_refresh_hud")
    var other_card=game.general_cards[(reporter_index+1)%game.general_cards.size()]
    other_card.report_link.pressed.emit()
    await process_frame
    if game.situation_selected!=other["id"] or game.selected_id!=other["unit_id"] or not game.sim.paused:
        push_error("VISUAL_CAPTURE_FAIL: portrait link opened another commander's report")
        return false
    game.situation_dialog.get_ok_button().pressed.emit()
    await process_frame
    game.sim.situation_reports.erase(other)
    game.call("_refresh_hud")
    game.dispatch_headline.pressed.emit()
    await process_frame
    await RenderingServer.frame_post_draw
    if game.order_view.visible or not game.sim.paused or game.selected_id!=int(report["unit_id"]) or not game.situation_pin.is_equal_approx(report["pos"]) or not game.situation_detail.text.contains(report["reason"]):
        push_error("VISUAL_CAPTURE_FAIL: report did not frame the observed event with its original evidence")
        return false
    if not _save_frame("field_dispatch.png"): return false
    var support: Dictionary=game.sim.support_for_report(game.sim.find_unit(int(report["unit_id"])))
    var btn: Button=game.situation_options[2]
    if support.is_empty() or not btn.text.contains(support["name"]) or btn.disabled:
        push_error("VISUAL_CAPTURE_FAIL: support preview does not identify an available commander")
        return false
    btn.pressed.emit()
    if report["status"]!="전령 파견" or int(report["executor"])!=int(support["id"]) or not game.situation_record.text.contains(support["name"]):
        push_error("VISUAL_CAPTURE_FAIL: issuing support did not retain the report and actual executor")
        return false
    var support_index: int=game.sim.command_ids(0).find(int(support["id"]))
    if support_index<0 or game.general_cards[support_index].note_kind.text!="전령" or not game.general_cards[support_index].note.text.contains("지원"):
        push_error("VISUAL_CAPTURE_FAIL: tactical courier is missing from the receiving commander's card")
        return false
    game.situation_dialog.get_ok_button().pressed.emit()
    await process_frame
    if game.sim.paused or game.order_view.visible or game.situation_dialog.visible:
        push_error("VISUAL_CAPTURE_FAIL: returning from the report did not resume the battlefield")
        return false
    for tick in range(1200):
        game.call("_process",0.1)
        if report["status"]=="실행 종료": break
    game.sim.paused=true
    game.situation_btn.pressed.emit()
    var row: int=game.situation_ids.find(report["id"])
    if row<0 or report["status"]!="실행 종료":
        push_error("VISUAL_CAPTURE_FAIL: support order did not finish in the matched operation")
        return false
    game.situation_list.select(row)
    game.situation_list.item_selected.emit(row)
    await process_frame
    await RenderingServer.frame_post_draw
    for evidence in ["전령 파견","명령 수령","실행 종료",str(report["action_seen"]),"손실 %d" % report["loss_delta"]]:
        if not game.situation_record.text.contains(evidence):
            push_error("VISUAL_CAPTURE_FAIL: incomplete field response history")
            return false
    if not _save_frame("field_dispatch_outcome.png"): return false
    game.situation_dialog.get_ok_button().pressed.emit()
    await process_frame
    if not game.sim.paused:
        push_error("VISUAL_CAPTURE_FAIL: report unexpectedly unpaused a paused battle")
        return false
    print("FIELD_DISPATCH_PASS reporter=%s support=%s sent=%s received=%s resolved=%s damage=%d loss=%d" % [
        game.sim.find_unit(int(report["unit_id"]))["name"],support["name"],game.call("_operation_clock",float(report["sent_at"])*game.sim.operation_scale()),
        game.call("_operation_clock",float(report["received_at"])*game.sim.operation_scale()),game.call("_operation_clock",float(report["resolved_at"])*game.sim.operation_scale()),
        report["damage_delta"],report["loss_delta"]])
    return true

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
