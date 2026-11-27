extends SceneTree
## Deterministic field exercises with the campaign roster and the actual order,
## decision, contact, movement and collision steps. Optional: -- screenshot_dir.
const Main = preload("res://main.tscn")
var failures := 0
var game: Control
var sim
var folder: String
var baseline := false

func _initialize() -> void:
    call_deferred("_exercise")

func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        if not baseline: push_error(message)

func prepare() -> void:
    game._campaign_mode(true)
    game.campaign.save_path = "user://rally-exercise.json"
    game._begin_campaign()
    game._launch_campaign_battle(1)
    sim = game.sim
    sim.enemy_strategy_enabled = false

func capture(label: String, center: Vector2, zoom: float, id: int) -> void:
    if folder.is_empty(): return
    game.selected_id=id
    game._select_unit()
    game.camera_center=center
    game.camera_zoom=zoom
    game._clamp_camera()
    game.render_clock=sim.battle_time
    game._refresh_hud()
    game.map_layer.queue_redraw()
    game.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(folder+"/"+label+".png")==OK,"save exercise frame")

func _exercise() -> void:
    var args := OS.get_cmdline_user_args()
    baseline="baseline" in args
    if not args.is_empty() and args[0]!="baseline":
        folder=args[0]
        DirAccess.make_dir_recursive_absolute(folder)
    game=Main.instantiate()
    root.add_child(game)
    game.set_process(false)
    await rally()
    await escape()
    if not baseline: constraints()
    print("RALLY_ESCAPE_PASS" if failures==0 else "RALLY_ESCAPE_REPRODUCED" if baseline else "RALLY_ESCAPE_FAIL")
    game._quit_game(0 if failures==0 or baseline else 1)

func rally() -> void:
    prepare()
    var ids: Array = sim.command_ids(0).slice(0,3)
    var enemy: int = sim.command_ids(1)[0]
    var pin := Vector2(810,760)
    var starts := [Vector2(420,690),Vector2(376,760),Vector2(434,857)]
    for u in sim.units:
        if u.id in ids:
            u.pos=starts[ids.find(u.id)]
            u.goal=u.pos
            check(sim.issue_map_order(u.id,"지정 위치 이동",pin),"accept each map order")
        elif u.id==enemy:
            u.pos=Vector2(2250,1220)
            u.goal=u.pos
            u.ai_cooldown=10000.0
        else: u.troops=0.0
    game.order_view.open(false)
    game.order_view._select(ids[0])
    check(game.order_view.march_preview.text.contains("공동 집결 3개 군단"),"the operations map identifies the confirmed group")
    await capture("orders",pin,1.60,ids[0])
    game._start()
    # An observed weak unit is behind the horse; a second placement physically
    # blocks its approach. Exercise the public order through the normal AI.
    var horse: Dictionary=sim.find_unit(ids[2])
    var foe: Dictionary=sim.find_unit(enemy)
    var reserve_pos: Vector2=foe.pos
    var bearing: Vector2=Vector2(horse.pos).direction_to(pin)
    foe.troops=1000.0
    foe.morale=44.0
    foe.cohesion=42.0
    foe.pos=Vector2(horse.pos)-bearing*78.0
    sim._decide(horse)
    var towards: float=bearing.dot(Vector2(horse.pos).direction_to(horse.goal))
    print("SIDE_CONTACT ",horse.action," direction=",snappedf(towards,0.01))
    check(towards>0.5 and horse.action=="지정 위치 이동","a tempting contact behind the travelling corps cannot reverse its order")
    foe.pos=Vector2(horse.pos)+bearing*68.0
    sim._decide(horse)
    check(horse.action in ["교전","돌파"] and Vector2(horse.goal).is_equal_approx(foe.pos),"a body blocking the approach is engaged")
    foe.pos=reserve_pos
    foe.troops=foe.initial_troops
    horse.ai_cooldown=0
    var arrived:=0
    var points:=PackedVector2Array()
    for tick in 470:
        sim.step(0.1)
        if not folder.is_empty(): game._update_contact_fronts(0.1)
    for id: int in ids:
        var u: Dictionary=sim.find_unit(id)
        var station: Dictionary=u.get("rally_station",{})
        points.append(u.pos)
        if not station.is_empty() and Vector2(u.pos).distance_to(station.point)<22.0 and u.destination_reached and Vector2(u.facing).dot(station.forward)>0.92: arrived+=1
        print("RALLY ",u.name," ",u.pos," ",u.action," ",u.reason," station=",station.get("point","-"))
    check(arrived==3,"three independently ordered corps must reach and face their distinct stations")
    var front := points[0]-points[1]
    check(front.x>68 and absf(points[2].y-points[0].y)>65,"bow is behind infantry and horse is on its wing")
    print("DRESSED ",arrived,"/3  depth=",roundi(front.x)," wing=",roundi(absf(points[2].y-points[0].y)))
    await capture("rally",pin,1.60,ids[0])
    sim.turn=5
    check(sim.issue_map_order(ids[1],"지역 사수",Vector2(470,770)),"dispatch another order")
    check(sim.find_unit(ids[1]).order_destination==pin,"in-flight order cannot remove the old station")
    sim.couriers.back().pos=sim.find_unit(ids[1]).pos
    sim.step(0.1)
    check(not sim.find_unit(ids[1]).has("rally_station") and sim.find_unit(ids[0]).get("rally_station",{}).get("count",0)==2,"reassign stations on receipt only")

func escape() -> void:
    prepare()
    var center := Vector2(800,760)
    var officer: Dictionary={}
    var foes: Array = sim.command_ids(1).slice(0,3)
    var offsets := [Vector2(-78,6),Vector2(75,12),Vector2(3,84)]
    for u in sim.units:
        if u.name=="조운":
            officer=u
            u.pos=center
            u.goal=center
            check(sim.issue_map_order(u.id,"지정 위치 이동",center+Vector2(245,15)),"issue Zhao Yun's original map order")
        elif u.id in foes:
            u.type="보병"
            u.pos=center+offsets[foes.find(u.id)]
            u.goal=u.pos
            u.action="방어"
            u.ai_cooldown=10000.0
        else: u.troops=0.0
    check(not officer.is_empty(),"campaign contains Zhao Yun")
    if officer.is_empty(): return
    game._start()
    var trapped:=0
    var escaped:=false
    var resumed:=false
    var distance:=0.0
    for tick in 140:
        var before: Vector2=officer.pos
        sim.step(0.1)
        if not folder.is_empty(): game._update_contact_fronts(0.1)
        if officer.surrounded: trapped+=1
        if officer.action=="포위 이탈":
            escaped=true
            distance+=before.distance_to(officer.pos)
        if escaped and not officer.surrounded and officer.action in ["지정 위치 이동","지정 지역 사수"]: resumed=true
        if tick in [0,20,70]: await capture("escape-%02d" % tick,center+Vector2(0,-32),2.0,officer.id)
    print("ESCAPE ",officer.name," trapped_ticks=",trapped," moved=",roundi(distance)," final=",officer.pos," remaining=",roundi(officer.troops)," state=",officer.general_state," resume=",resumed)
    check(trapped>0 and escaped and distance>50 and resumed and officer.troops>0,"open exit permits real movement and return to the original order")

func constraints() -> void:
    prepare()
    var officer: Dictionary={}
    for u in sim.units:
        if u.name=="조운": officer=u
    var p := Vector2(810,745)
    officer.pos=p
    var count:=0
    for u in sim.units:
        if u.side==officer.side: continue
        u.pos=p+Vector2.from_angle(count*TAU/8.0)*42.0
        if count>=8: u.troops=0
        count+=1
    officer.surrounded=sim._encirclement(officer)
    sim._decide(officer)
    check(officer.surrounded and officer.action!="포위 이탈","a closed ring has no traversable exit")
    # Turn the one open sector towards the river, away from any bridge.
    var coast := Vector2(sim.river_x(610)-39,610)
    officer.pos=coast
    count=0
    for u in sim.units:
        if u.side==officer.side: continue
        u.pos=coast+Vector2.from_angle(count*TAU/8.0)*40.0
        u.troops=3000.0 if count in [2,3,4,5,6] else 0.0
        count+=1
    officer.surrounded=sim._encirclement(officer)
    sim._decide(officer)
    check(officer.action!="포위 이탈","open water cannot serve as an exit")
    var pin := Vector2(sim.river_x(630)-36,630)
    var stations:=PackedVector2Array()
    var ids: Array=sim.command_ids(0)
    for id in ids: check(sim.issue_map_order(id,"지역 사수",pin),"corps can be assigned the riverbank")
    for id in ids:
        var u: Dictionary=sim.find_unit(id)
        var station: Dictionary=u.get("rally_station",{})
        if station.is_empty():
            check(false,"missing riverbank station")
            continue
        var at: Vector2=station.point
        check(not sim.in_open_water(at) and not sim._river_separates(pin,at),"station is reachable from rally pin")
        for other in stations: check(at.distance_to(other)>48.0,"riverbank stations remain distinct")
        stations.append(at)
    print("RIVER_STATIONS ",stations.size())
