extends SceneTree
## Mirror a protection assignment across both sides using their own command authority.
const Main = preload("res://main.tscn")
var game: Control
var sim
var failed := false
var directory := ""
var baseline := false

func _initialize() -> void:
    call_deferred("_run")

func expect(condition: bool, detail: String) -> void:
    if condition: return
    failed=true
    if not baseline: push_error(detail)

func reset_field() -> void:
    sim.reset()
    sim.set_scenario(sim.TRAINING_SCENARIO)
    sim.tactical_enabled=true
    sim.enemy_strategy_enabled=true
    for u in sim.units:
        u.troops=0.0
        u.ai_cooldown=1000.0

func deploy(id: int, point: Vector2) -> Dictionary:
    var u: Dictionary=sim.find_unit(id)
    u.troops=u.initial_troops
    u.pos=point
    u.goal=point
    u.facing=Vector2.RIGHT if u.side==0 else Vector2.LEFT
    return u

func partners(side: int) -> void:
    reset_field()
    var aim:=Vector2.RIGHT if side==0 else Vector2.LEFT
    var p:=Vector2(790,760)
    var own: Array=sim.command_ids(side)
    var opponents: Array=sim.command_ids(1-side)
    var guard:=deploy(own[0],p+aim*22+Vector2(0,65))
    var bow:=deploy(own[1],p)
    var horse:=deploy(opponents[2],p+aim*93)
    var bait:=deploy(opponents[1],p+aim*12+Vector2(0,127))
    guard.personality="공격"
    guard.loyalty=40.0
    guard.obedience="성향 기반"
    bait.cohesion=30.0
    bait.morale=40.0
    bait.troops=850
    for fixed in [horse,bait,bow]:
        fixed.tactical_order="사수"
        fixed.tactical_anchor=fixed.pos
        fixed.tactical_until=60.0
        fixed.ai_cooldown=0.0
    if side==0: expect(sim.issue_map_order(guard.id,"자유 재량",Vector2.ZERO),"accept delegated role")
    expect(sim._physical_screen(bow,horse).is_empty(),"start with an exposed bow")
    game._start()
    guard.ai_cooldown=0.0
    sim.step(0.1)
    var chose: bool=guard.ai_role=="궁병 보호" and guard.ai_partner==bow.id
    var action: String=guard.action
    var pos: Vector2=guard.pos
    var diverted := false
    var intercepted := false
    var damage: float=guard.damage_dealt
    for tick in 55:
        sim.step(0.1)
        if not directory.is_empty():
            game._update_contact_fronts(0.1)
            if side==0 and tick==35: await capture("guard",guard.id,p+Vector2(0,34))
        if guard.field_choice.get("target",-1)==bait.id and guard.action=="공격 지속": diverted=true
        if sim._physical_screen(bow,horse).get("id",-1)==guard.id: intercepted=true
    print("PAIR side=",side," role=",chose," first=",action," physically_screened=",intercepted," chased_bait=",diverted," moved=",roundi(pos.distance_to(guard.pos))," damage=",roundi(guard.damage_dealt-damage))
    expect(chose and not diverted and intercepted,"delegated infantry should select its archer and physically screen it on either side")
    if side==0:
        sim.turn=5
        expect(sim.issue_map_order(guard.id,"지역 사수",p-aim*190),"send new order from operations map")
        expect(guard.ai_partner==bow.id,"in-flight order leaves the current role active")
        sim.couriers.back().pos=guard.pos
        sim.step(0.1)
        expect(guard.mission=="지역 사수" and guard.ai_partner<0,"accepted replacement ends delegated assignment")

func rally_cover() -> void:
    reset_field()
    var pin:=Vector2(800,760)
    var foot:=deploy(0,pin-Vector2(300,0))
    var bow:=deploy(1,pin-Vector2(380,0))
    var foe:=deploy(3,pin+Vector2(78,-15))
    for u in [foot,bow]: expect(sim.issue_map_order(u.id,"지역 사수",pin),"give the same location to both corps")
    game._start()
    var station: Vector2=foot.rally_station.point
    foot.pos=station
    foot.goal=station
    bow.pos=pin+Vector2(-10,-60)
    bow.goal=bow.pos
    sim._decide(foot)
    var decision: Dictionary=foot.field_choice
    var covered: bool=decision.get("ally",-1)==bow.id and decision.get("target",-1)==foe.id
    var start: Vector2=foot.pos
    var goal: Vector2=foot.goal
    foot.ai_cooldown=1000.0
    for step in 9: sim.step(0.1)
    print("ARRIVAL target=",decision.get("target",-1)," ally=",decision.get("ally",-1)," reason=",foot.reason," walked=",roundi(start.distance_to(foot.pos))," order_distance=",roundi(goal.distance_to(station)))
    expect(covered and goal.distance_to(station)<=56.1 and start.distance_to(foot.pos)>4,"stationed corps physically covers the approach inside its assigned area")
    await capture("arrival",0,pin)
    foe.pos=Vector2(2220,1300)
    sim._decide(foot)
    expect(foot.field_choice.is_empty() and foot.goal.distance_to(station)<=12,"return to station once the hostile contact is gone")

func wings(side: int) -> void:
    reset_field()
    var own: Array=sim.command_ids(side)
    var opposing: Array=sim.command_ids(1-side)
    var axis:=Vector2.RIGHT if side==0 else Vector2.LEFT
    var p:=Vector2(780,890)
    var foot:=deploy(own[0],p)
    var horse:=deploy(own[2],p-axis*90+Vector2(0,45))
    var foe:=deploy(opposing[0],p+axis*35)
    horse.morale=85
    horse.cohesion=85
    if side==0: expect(sim.issue_map_order(horse.id,"자유 재량",Vector2.ZERO),"delegate the cavalry")
    game._start()
    sim.step(0.1)
    var paired: bool=horse.ai_role=="측후방 기동" and horse.ai_partner==foot.id
    expect(paired,"cavalry must link to the engaged infantry on either side")
    expect(sim.Skills.mission(horse,sim.battle_time)=="march","delegated role sets skill eligibility")
    foe.pos=Vector2(2370,1360)
    sim.battle_time=horse.ai_role_until+1.0
    sim._plan_local_roles(side)
    expect(horse.ai_role.is_empty(),"a cavalry role expires after losing its observed contact")
    print("WING side=",side," paired=",paired," expired=",horse.ai_role.is_empty())

func named_escort() -> void:
    reset_field()
    var p:=Vector2(740,750)
    var foot:=deploy(0,p-Vector2(60,0))
    var bow:=deploy(1,p)
    var horse:=deploy(5,p+Vector2(184,0))
    expect(sim.issue_map_order(0,"전열 엄호",p+Vector2(350,0),bow.id),"accept explicit escort and rendezvous")
    game._start()
    sim._decide(foot)
    var d: float=Vector2(foot.goal).distance_to(bow.pos)
    print("ESCORT ",foot.action," partner_distance=",roundi(d)," reason=",foot.reason)
    expect(d<=90.1 and foot.action in ["궁병 보호","협동 엄호","아군 보호","전열 유지"],"named guard meets local pressure before the distant pin")
    horse.pos=Vector2(2340,1250)
    sim._decide(foot)
    expect(foot.goal==foot.order_destination,"no contact on the march restores the rendezvous")
    foot.tactical_order="철수"
    foot.tactical_until=sim.battle_time+12
    sim._decide(foot)
    expect(foot.action=="전술 철수","the courier's withdrawal takes precedence")

func capture(label: String, id: int, center: Vector2) -> void:
    if directory.is_empty(): return
    game.selected_id=id
    game._select_unit()
    game.camera_center=center
    game.camera_zoom=2.0
    game._clamp_camera()
    game.render_clock=sim.battle_time
    game._refresh_hud()
    game.map_layer.queue_redraw()
    game.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    expect(root.get_texture().get_image().save_png(directory+"/"+label+".png")==OK,"write replay frame")

func _run() -> void:
    var args:=OS.get_cmdline_user_args()
    baseline="baseline" in args
    if not args.is_empty() and args[0]!="baseline":
        directory=args[0]
        DirAccess.make_dir_recursive_absolute(directory)
    game=Main.instantiate()
    root.add_child(game)
    game.set_process(false)
    game._leave_title(5)
    sim=game.sim
    await partners(0)
    await partners(1)
    if not baseline:
        wings(0)
        wings(1)
    named_escort()
    await rally_cover()
    print("MUTUAL_ROLES_REPRO" if baseline else ("MUTUAL_ROLES_FAIL" if failed else "MUTUAL_ROLES_PASS"))
    game._quit_game(1 if failed and not baseline else 0)
