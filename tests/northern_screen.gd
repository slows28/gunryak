extends SceneTree
const Main=preload("res://main.tscn")
var game: Control
var folder: String
var failed:=false

func _initialize(): call_deferred("_play")
func expect(value: bool,message: String) -> void:
    if not value: push_error("NORTHERN_SCREEN_FAIL "+message);failed=true
func frame(filename: String) -> void:
    game.map_layer.queue_redraw()
    game.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    expect(root.get_texture().get_image().save_png(folder+"/"+filename+".png")==OK,filename)
func click_at(at: Vector2) -> void:
    var motion:=InputEventMouseMotion.new()
    motion.position=at
    root.push_input(motion,true)
    for down in [true,false]:
        var event:=InputEventMouseButton.new()
        event.position=at
        event.button_index=MOUSE_BUTTON_LEFT
        event.pressed=down
        root.push_input(event,true)
    await process_frame

func press_key(code: Key) -> void:
    for down in [true,false]:
        var key:=InputEventKey.new()
        key.keycode=code
        key.pressed=down
        root.push_input(key,true)
    await process_frame

func check_atlas(prep: Control) -> void:
    var atlas=prep.canvas
    var face: Font=atlas.get_theme_default_font()
    var bounds:=Rect2(Vector2.ZERO,atlas.size)
    expect(atlas.SITES.size()==prep.Field.CHAPTERS.size(),"every campaign chapter has a map site")
    for chapter in atlas.SITES.size():
        var labels: Array[Rect2]=[]
        for i in atlas.SITES.size():
            var site: Array=atlas.SITES[i]
            var name_text: String=site[0]
            expect(str(prep.Field.CHAPTERS[i][0]).begins_with(name_text),"map sites match chapter order")
            expect(bounds.has_point(atlas.project_point(site[1])),"geographic position inside theater")
            var label: Rect2=atlas._label_rect(site[2],"%02d %s" % [i+1,name_text],15 if i==chapter else 14,face)
            expect(bounds.encloses(label),"full chapter label in frame")
            for other in labels: expect(not other.intersects(label),"neighboring chapter names stay separate")
            labels.append(label)
    expect(prep.brief.position.y>=atlas.get_rect().end.y,"briefing stays below the map")

func review_roster() -> void:
    var ids: Array=game.sim.command_ids(0)
    var area: Rect2=game.corps_grid.get_global_rect()
    var seen: Array[Rect2]=[]
    for i in ids.size():
        var card=game.general_cards[i]
        var bounds: Rect2=card.get_global_rect()
        expect(card.is_visible_in_tree() and area.encloses(bounds),"all commanders on screen at once")
        for other in seen: expect(not bounds.intersects(other),"commander cards remain separate")
        seen.append(bounds)
        var u: Dictionary=game.sim.find_unit(ids[i])
        expect(card.commander.text==u.name and card.troop_type.text==u.type,"each roster card names its commander and current troop type")
        expect(card.troop_type.is_visible_in_tree() and not card.troop_type.get_global_rect().intersects(card.action.get_global_rect()),"troop and action occupy separate readable columns")
    expect(game.objective_label.get_line_count()<=2 and game.objective_label.get_global_rect().end.y<=game.map_clip.get_global_rect().position.y,"Qishan objective fits above the field")
    for sector in game.sector_cards: expect(not sector.own.visible,"compact fronts show the situation")
    game.map_detail_button.pressed.emit()
    for sector in game.sector_cards: expect(sector.own.visible and sector.enemy.visible,"detailed fronts show both permitted totals")
    game.map_detail_button.pressed.emit()
    var orig: Vector2=game.camera_center
    await click_at(game.panel_toggle.get_global_rect().get_center())
    expect(not game.commander_scroll.is_visible_in_tree() and game.map_clip.size.x>1200,"panel closes and releases map space")
    var cursor:=Vector2(1140,430)
    var anchor: Vector2=game._world_mouse(cursor)
    var wheel:=InputEventMouseButton.new()
    wheel.position=cursor
    wheel.button_index=MOUSE_BUTTON_WHEEL_UP
    wheel.pressed=true
    var zoom: float=game.camera_zoom
    root.push_input(wheel,true)
    wheel.pressed=false
    root.push_input(wheel,true)
    expect(game.camera_zoom>zoom and game._world_mouse(cursor).distance_to(anchor)<0.1,"expanded battlefield zoom anchors under the cursor")
    var last=game.general_cards[ids.size()-1]
    await click_at(last.action.get_global_rect().get_center())
    expect(game.selected_id==ids.back() and not game.command_panel.visible,"last commander selects without reopening inspector")
    await frame("03-expanded")
    await click_at(game.panel_toggle.get_global_rect().get_center())
    expect(game.commander_scroll.is_visible_in_tree() and game.map_clip.size==game.MAP_SIZE and last.button_pressed,"reopening restores selected inspector")
    game._select_general_card(0)
    game.camera_center=orig
    game._clamp_camera()

func _play():
    folder=ProjectSettings.globalize_path("res://test_results/northern_screen")
    if not OS.get_cmdline_user_args().is_empty(): folder=OS.get_cmdline_user_args()[0]
    DirAccess.make_dir_recursive_absolute(folder)
    game=Main.instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false)
    var menu=game.title_screen
    game.campaign.save_path="user://northern-screen-%s.json" % Time.get_ticks_usec()
    menu.refresh("")
    if not menu.record_available: expect(menu.primary.text=="북벌 시작" and not menu.new_record.visible,"first visit has a single campaign action")
    var portrait: TextureRect
    for image_node in menu.find_children("*","TextureRect",false,false):
        if image_node.texture==menu.ART: portrait=image_node
    expect(is_instance_valid(portrait) and menu.get_global_rect().encloses(portrait.get_global_rect()),"full title portrait fits the viewport")
    await frame("00-title")
    for i in 9:
        await press_key(KEY_TAB)
        expect(menu.is_ancestor_of(root.gui_get_focus_owner()),"Tab stays on the title screen")
    var fog: bool=game.fog_enabled
    await press_key(KEY_V)
    expect(game.fog_enabled==fog,"menu ignores battlefield shortcuts")
    await click_at(menu.audio.get_global_rect().get_center())
    expect(menu.audio.text=="음향 꺼짐" and not game.sound_enabled,"audio state shown")
    await click_at(menu.audio.get_global_rect().get_center())
    await click_at(menu.practice_entry.get_global_rect().get_center())
    expect(menu.practice.visible and menu.difficulty.is_visible_in_tree(),"solo difficulty with solo entry")
    await frame("00-practice")
    await press_key(KEY_ESCAPE)
    expect(menu.home.visible and not menu.practice.visible,"Escape returns to campaign")
    if menu.record_available: await click_at(menu.new_record.get_global_rect().get_center())
    else: await click_at(menu.primary.get_global_rect().get_center())
    var prep=game.strategy_view
    check_atlas(prep)
    expect(prep.canvas.stage==1,"theater opens at Qishan")
    for i in prep.corps_buttons.size():
        var card: Button=prep.corps_buttons[i]
        expect(card.is_visible_in_tree() and card.text.contains(game.campaign.state.types[i]),"all troop types visible before departure")
    await click_at(prep.corps_buttons[2].get_global_rect().get_center())
    await click_at(prep.equip_button.get_global_rect().get_center())
    expect(game.campaign.state.gear.get("2","")=="pace","select and equip from preparation")
    expect(prep.description.text.contains("+17.6%") and prep.description.text.contains("발동") and prep.owner_list.get_item_icon(0)!=null and prep.innate.text.contains("재사용"),"readable effects and cooldowns")
    expect(prep.equip_button.text.contains("해제"),"equipped item has an explicit removal action")
    await click_at(prep.corps_buttons[0].get_global_rect().get_center())
    expect(prep.equip_button.text.contains("위연 → 왕평"),"transfer shows both officers before confirmation")
    await click_at(prep.corps_buttons[2].get_global_rect().get_center())
    await frame("01-preparation")
    await click_at(prep.corps_buttons[10].get_global_rect().get_center())
    expect(prep.innate.text.contains("용담 돌파") and prep.army.text.contains("진형 93") and prep.trait_pins.size()==4,"Zhao Yun's signature, six abilities and four traits")
    await frame("01-zhao")
    await click_at(prep.corps_buttons[1].get_global_rect().get_center())
    var original: int=prep.officer_choice.selected
    prep.officer_choice.select(14)
    prep.officer_choice.item_selected.emit(14)
    await click_at(prep.assign_button.get_global_rect().get_center())
    expect(prep.innate.text.contains("백발백중") and prep.type_choice.get_item_text(prep.type_choice.selected)=="궁병","Huang Zhong can be assigned to archers")
    expect(prep.innate.get_rect().end.y<prep.equipped.position.y,"signature and gear details are separate")
    await frame("01-huang")
    prep.officer_choice.select(original)
    prep.officer_choice.item_selected.emit(original)
    await click_at(prep.assign_button.get_global_rect().get_center())
    await click_at(prep.corps_buttons[2].get_global_rect().get_center())
    var stored:=FileAccess.get_file_as_string(game.campaign.save_path)
    await press_key(KEY_ESCAPE)
    expect(menu.primary.text=="편성으로 돌아가기" and menu.reload_record.visible,"active preparation and disk record separately available")
    await click_at(menu.new_record.get_global_rect().get_center())
    expect(menu.confirm.visible and menu.cancel.has_focus(),"starting over defaults to cancel")
    await frame("01-confirm")
    await press_key(KEY_ESCAPE)
    expect(not menu.confirm.visible and FileAccess.get_file_as_string(game.campaign.save_path)==stored,"cancel preserves saved file")
    await click_at(menu.reload_record.get_global_rect().get_center())
    expect(menu.confirm.visible,"reloading warns before leaving the current screen")
    await click_at(menu.proceed.get_global_rect().get_center())
    expect(prep.visible and game.campaign.state.gear.get("2","")=="pace","real saved load restores equipment")
    prep.action.pressed.emit()
    expect(game.order_view.visible and game.sim.command_ids(0).size()==12,"preparation opens real orders")
    await frame("02-orders")
    await click_at(game.order_view.guard_button.get_global_rect().get_center())
    var plan: Dictionary=game.order_view.drafts.duplicate(true)
    expect(plan.size()==1 and game.order_view.launch.text.contains("미확정 1"),"draft count visible on start action")
    await press_key(KEY_ESCAPE)
    expect(menu.primary.text=="작전 지도로 돌아가기" and menu.detail.text.contains("미확정 지시 1개"),"menu names the operation and its draft")
    await frame("02-resume")
    await click_at(menu.primary.get_global_rect().get_center())
    expect(game.order_view.visible and game.order_view.drafts==plan,"resume preserves the draft")
    await click_at(game.order_view.launch.get_global_rect().get_center())
    expect(not game.sim.started and game.order_view.visible,"review cannot accidentally start battle")
    await click_at(game.order_view.apply.get_global_rect().get_center())
    await click_at(game.order_view.launch.get_global_rect().get_center())
    await press_key(KEY_ESCAPE)
    expect(game.sim.paused and menu.primary.text=="전투 계속","live battle pauses in menu")
    menu.primary.release_focus()
    await press_key(KEY_SPACE)
    expect(game.sim.paused,"battle clock stays paused while menu is open")
    await click_at(menu.primary.get_global_rect().get_center())
    expect(not game.sim.paused and not menu.visible,"resume restores the running battle")
    expect(game.sim.started and game.general_cards.size()==12 and game.friendly_tab.text=="아군 12","twelve live cards and roster count")
    game.camera_zoom=1.5
    game.camera_center=game.sim.field_size*0.5
    game._clamp_camera()
    Input.warp_mouse(Vector2(1277,415))
    await process_frame
    await process_frame
    var at:Vector2=game.camera_center
    game._process(0.12)
    expect(game.camera_center.x>at.x and is_equal_approx(game.camera_center.y,at.y),"right window edge pans east")
    Input.warp_mouse(Vector2(520,390))
    await process_frame
    at=game.camera_center
    game._process(0.12)
    expect(at==game.camera_center,"center stops camera")
    Input.warp_mouse(Vector2(17,280))
    await process_frame
    game._process(0.12)
    expect(game.camera_center.x<at.x,"map edge pans west")
    game._open_demo_help()
    at=game.camera_center
    game._process(0.12)
    expect(game.camera_center==at,"help blocks edge panning")
    game.tutorial_dialog.hide()
    Input.warp_mouse(Vector2(520,390))
    var sim=game.sim
    for i in 510:
        sim.step(0.1)
        if i>470: game._update_contact_fronts(0.1)
    var person: Dictionary=sim.find_unit(0)
    game.camera_center=person.pos
    game.camera_zoom=1.8
    game._clamp_camera()
    game._refresh_hud()
    await frame("03-live")
    await review_roster()
    # Complete the first chapter through the same objective resolver used during play.
    sim.battle_time=sim.LONG_OBJECTIVE_OPEN+1
    sim.turn=12
    # Exercise the real capture and occupancy rules before the result screen.
    for u in sim.units: u.pos=sim._home_point(u.side)
    var columns: Array=sim.command_ids(0)
    for i in 2: sim.find_unit(columns[i]).pos=sim.outposts[i].pos
    for tick in ceili((sim.capture_duration()+46.0)*10): sim._update_outposts(0.1)
    sim._check_victory()
    expect(sim.finished and sim.winning_side==0,"actual first-stage objective")
    if failed:
        game._quit_game(1)
        return
    game._show_outcome()
    expect(game.reward_options.visible and game.reward_options.get_child_count()==3 and game.campaign_next.disabled,"three result options")
    await frame("04-rewards")
    expect(game.reward_options.get_global_rect().end.y<=game.campaign_next.global_position.y and game.campaign_next.get_global_rect().end.y<=game.reward_options.get_parent().get_parent().get_global_rect().end.y-6,"reward and navigation fit without overlap")
    game.reward_options.get_child(0).pressed.emit()
    game.campaign_next.pressed.emit()
    expect(prep.visible and game.campaign.state.stage==2 and prep.canvas.stage==2,"next stage preparation and theater marker")
    prep.owner_list.select(3)
    prep.owner_list.item_selected.emit(3)
    await click_at(prep.equip_button.get_global_rect().get_center())
    expect(game.campaign.state.gear.get("2","")=="strike","earned item transferred to commander")
    await frame("05-next-loadout")
    prep.action.pressed.emit()
    expect("strike" in sim.find_unit(2).skill_ids and sim.scenario_title=="천수 공략전","equipped skill enters next battle")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(game.campaign.save_path))
    print("NORTHERN_SCREEN_PASS" if not failed else "NORTHERN_SCREEN_FAIL")
    game._quit_game(1 if failed else 0)
