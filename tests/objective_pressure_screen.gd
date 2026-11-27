extends SceneTree
## A live Mugong replay. Pass the same tick, officer and camera to compare two builds.
const Main=preload("res://main.tscn")

func _initialize() -> void: call_deferred("replay")

func replay() -> void:
    var args:=OS.get_cmdline_user_args()
    if args.size() not in [1,5]:
        push_error("Use -- SCREENSHOT.png [TICK OFFICER X Y]")
        quit(2)
        return
    var game=Main.instantiate()
    root.add_child(game)
    game.set_process(false)
    game._begin_campaign()
    var campaign=game.campaign
    campaign.save_path="user://pressure-screen.json"
    for n in range(1,11):
        campaign.state.reward=n
        if not campaign.claim(campaign.choices()[0]):
            game._quit_game(1)
            return
    for entry in [[0,"pace"],[2,"shield"],[3,"regroup"]]: campaign.equip(entry[0],entry[1])
    game._launch_campaign_battle(11)
    var sim=game.sim
    for id in sim.command_ids(0):
        var bow: bool=sim.find_unit(id).type=="궁병"
        if not sim.issue_map_order(id,"지역 사수" if bow else "공격",sim.outposts[0].pos+(Vector2(-90,0) if bow else Vector2.ZERO)):
            game._quit_game(1)
            return
    game._start()
    var officer: int=int(args[2]) if args.size()==5 else -1
    var limit: int=int(args[1]) if args.size()==5 else 3000
    while not sim.finished and sim.step_count<limit:
        sim.step(0.1)
        if sim.step_count%3==0: game._update_contact_fronts(0.3)
        if args.size()==5: continue
        for u in sim.units:
            if u.side==1 and u.action in ["거점 차단","거점 엄호 사격"] and game._visible_unit(u):
                officer=u.id
                break
        if officer>=0: break
    if officer<0:
        push_error("No visible officer reacting to the concentration")
        game._quit_game(1)
        return
    var leader: Dictionary=sim.find_unit(officer)
    game._show_enemy_roster()
    if game._visible_unit(leader): game.observed_enemy_id=officer
    game.camera_zoom=1.45
    game.camera_center=Vector2(float(args[3]),float(args[4])) if args.size()==5 else leader.pos
    game._clamp_camera()
    game._refresh_hud()
    game.map_layer.queue_redraw()
    game.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    print("PRESSURE_FRAME ",sim.step_count," ",officer," ",game.camera_center.x," ",game.camera_center.y," ",leader.name," ",leader.action," ",game.enemy_intel.text)
    var ok: bool=root.get_texture().get_image().save_png(args[0])==OK
    if args.size()==1: ok=ok and "관측 ·" in game.enemy_intel.text
    game._quit_game(0 if ok else 1)
