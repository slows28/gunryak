extends SceneTree
const Main=preload("res://main.tscn")
var game
var folder: String
func _initialize(): call_deferred("_run")
func capture(name: String) -> void:
    game._refresh_hud()
    game.map_layer.queue_redraw()
    game.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(folder+"/"+name+".png")
func _run():
    var args:=OS.get_cmdline_user_args()
    var n:=int(args[0])
    folder=args[1]
    DirAccess.make_dir_recursive_absolute(folder)
    var baseline:=args.size()==4
    var stop:=int(args[2]) if baseline else -1
    game=Main.instantiate()
    root.add_child(game)
    game.set_process(false)
    game._begin_campaign()
    var campaign=game.campaign
    campaign.save_path="user://report-screen-%d.json" % n
    for i in range(1,n):
        campaign.state.reward=i
        campaign.claim(campaign.choices()[0])
    campaign.equip(0,"pace")
    campaign.equip(2,"shield")
    campaign.equip(3,"regroup")
    game._launch_campaign_battle(n)
    game._start()
    var sim=game.sim
    var letter: Dictionary={}
    var selected: int=int(args[3]) if baseline else 0
    while not sim.finished:
        sim.step(0.1)
        game._update_contact_fronts(0.1)
        if baseline:
            if sim.step_count==stop: break
            continue
        for r in sim.situation_reports:
            if r["status"]=="작전 보고 수신" and r["kind"]==("도하 완료" if n==10 else "협공 성립"):
                letter=r
                selected=r.unit_id
                break
        if not letter.is_empty(): break
    game.selected_id=selected
    game._select_unit()
    game.camera_center=sim.find_unit(selected).pos
    game.camera_zoom=1.45
    game._clamp_camera()
    await capture("field-%d"%n)
    if baseline: game._quit_game();return
    if letter.is_empty():
        push_error("Chapter finished without a contribution letter")
        game._quit_game(1)
        return
    game._open_situations(letter.id)
    await capture("letter-%d"%n)
    var ok: bool=game.situation_detail.text.contains(letter.objective_account) and not game.reply_yes.visible and game.situation_record.text==letter.desk_summary
    game.situation_dialog.hide()
    game._close_situations()
    game._open_order_map()
    await capture("map-%d"%n)
    print("CHAPTER_REPORT ",n," tick ",sim.step_count," unit ",selected," ",letter.sender," ",letter.kind," ",letter.desk_summary," ",letter.objective_account)
    game._quit_game(0 if ok else 1)
