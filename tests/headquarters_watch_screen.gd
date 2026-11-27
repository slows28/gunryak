extends SceneTree
## Replay the Mugong orders from the campaign field trial and use the real alert,
## order sheet and courier. An optional "baseline" flag captures the earlier UI.
const Main=preload("res://main.tscn")
var game
var folder: String
var failures:=0

func _initialize() -> void: call_deferred("replay")

func expect(value: bool,message: String) -> void:
    if not value:
        failures+=1
        push_error(message)

func capture(label: String) -> void:
    game._refresh_hud()
    game.map_layer.queue_redraw()
    game.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    expect(root.get_texture().get_image().save_png(folder+"/"+label+".png")==OK,"save "+label)

func replay() -> void:
    var args:=OS.get_cmdline_user_args()
    folder=args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://test_results/hq_watch")
    var baseline:=args.size()>1 and args[1]=="baseline"
    DirAccess.make_dir_recursive_absolute(folder)
    game=Main.instantiate()
    root.add_child(game)
    game.set_process(false)
    game._begin_campaign()
    var campaign=game.campaign
    campaign.save_path="user://hq-watch-playtest.json"
    for n in range(1,11):
        campaign.state.reward=n
        campaign.claim(campaign.choices()[0])
    campaign.equip(0,"pace")
    campaign.equip(2,"shield")
    campaign.equip(3,"regroup")
    game._launch_campaign_battle(11)
    if not baseline:
        expect(game.sim.place_post("본진",Vector2(670,855)),"legal western camp for the approach replay")
    game._start()
    var sim=game.sim
    var sent: Dictionary={}
    # The first raid moves with the opposing AI. Replay to an actionable
    # observation rather than assuming every build reaches it on the same tick.
    while not sim.finished and (not baseline or sim.step_count<2220):
        sim.step(0.1)
        for i in range(game.arrival_messages.size()-1,-1,-1):
            game.arrival_messages[i].remaining-=0.1*sim.operation_scale()
            if game.arrival_messages[i].remaining<=0: game.arrival_messages.remove_at(i)
        if sim.home_approach_seen(): game._update_contact_fronts(0.1)
        if not baseline and sim.turn>=sim.COURIER_TURN and sim.home_approach_seen() and sim.headquarters[0].occupation==0:
            game._refresh_hud()
            if game.dispatch_headline.visible and "인근 적 관측" in game.dispatch_headline.text and sim.home_relief_candidate()>=0: break
        if sim.turn<sim.COURIER_TURN or sim.step_count%20!=0: continue
        for letter in sim.chapter.get("receipts",{}).values():
            var id: int=letter.unit_id
            if not sent.has(id) and letter.get("joint_credit",0)>0 and sim.issue_map_order(id,"공격",sim.outposts[0].pos):
                sent[id]=true
    var home: Vector2=sim.headquarters[0].pos
    game.camera_zoom=1.25
    game.camera_center=home+Vector2(175,0)
    game._clamp_camera()
    await capture("watch")
    if baseline:
        game._open_order_map()
        await capture("orders")
        game._quit_game(failures)
        return
    expect(sim.headquarters[0].occupation==0 and game.dispatch_headline.visible and "인근 적 관측" in game.dispatch_headline.text,"actionable sighting before occupation")
    var candidate: int=sim.home_relief_candidate()
    var previous: String=sim.find_unit(candidate).mission
    game.dispatch_headline.pressed.emit()
    var desk=game.order_view
    expect(desk.visible and desk.selected_id==candidate and desk.drafts.has(candidate) and not desk.apply.disabled,"ready reinforcement is a draft on the map")
    expect(not sim.has_pending_courier(candidate) and sim.find_unit(candidate).mission==previous,"opening alert leaves player in control")
    await capture("orders")
    desk.apply.pressed.emit()
    expect(sim.has_pending_courier(candidate) and sim.find_unit(candidate).mission==previous and "전령 이동 중" in desk.guard_summary.text,"confirmed order is in transit")
    await capture("dispatch")
    desk.launch.pressed.emit()
    for tick in range(300):
        sim.step(0.1)
        if not sim.has_pending_courier(candidate): break
    var delivered: bool=sim.find_unit(candidate).mission=="본진 방어"
    expect(delivered and "전담" in sim.home_guard_roster(),"a real rider delivered the command")
    print("HQ_WATCH_SCREEN ",sim.find_unit(candidate).name," ",sim.map_dispatches.get(candidate,{})," ",sim.home_guard_roster())
    print("HQ_WATCH_SCREEN_PASS" if failures==0 else "HQ_WATCH_SCREEN_FAIL")
    game._quit_game(failures)
