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
func _play():
    folder=ProjectSettings.globalize_path("res://test_results/northern_screen")
    if not OS.get_cmdline_user_args().is_empty(): folder=OS.get_cmdline_user_args()[0]
    DirAccess.make_dir_recursive_absolute(folder)
    game=Main.instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false)
    game._begin_campaign()
    game.campaign.save_path="user://northern-screen-verify.json"
    var prep=game.strategy_view
    prep.slot_choice.select(2)
    prep.slot_choice.item_selected.emit(2)
    prep.equip_choice.select(1)
    prep.equip_choice.item_selected.emit(1)
    prep.equip_button.pressed.emit()
    expect(game.campaign.state.gear.get("2","")=="pace","select and equip from preparation")
    expect(prep.description.text.contains("이동 속도 증가") and prep.innate.text.contains("재사용"),"readable effects and cooldowns")
    await frame("01-preparation")
    prep.action.pressed.emit()
    expect(game.order_view.visible and game.sim.command_ids(0).size()==12,"preparation opens real orders")
    await frame("02-orders")
    game._start()
    expect(game.sim.started and game.general_cards.size()==12,"twelve live cards")
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
    # Complete the first chapter through the same objective resolver used during play.
    sim.battle_time=sim.LONG_OBJECTIVE_OPEN+1
    sim.turn=12
    for post in sim.outposts:
        post.owner=0
        post.hold=60.0
    sim._check_victory()
    expect(sim.finished and sim.winning_side==0,"actual first-stage objective")
    game._show_outcome()
    expect(game.reward_options.visible and game.reward_options.get_child_count()==3 and game.campaign_next.disabled,"three result options")
    await frame("04-rewards")
    expect(game.reward_options.get_global_rect().end.y<=game.campaign_next.global_position.y and game.campaign_next.get_global_rect().end.y<=game.size.y,"reward and navigation fit without overlap")
    game.reward_options.get_child(0).pressed.emit()
    game.campaign_next.pressed.emit()
    expect(prep.visible and game.campaign.state.stage==2,"next stage preparation")
    prep.equip_choice.select(4)
    prep.equip_button.pressed.emit()
    expect(game.campaign.state.gear.get("2","")=="strike","earned item transferred to commander")
    await frame("05-next-loadout")
    prep.action.pressed.emit()
    expect("strike" in sim.find_unit(2).skill_ids and sim.scenario_title=="천수 공략전","equipped skill enters next battle")
    print("NORTHERN_SCREEN_PASS" if not failed else "NORTHERN_SCREEN_FAIL")
    game._quit_game(1 if failed else 0)
