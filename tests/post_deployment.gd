extends SceneTree
const WarSim=preload("res://scripts/war_sim.gd")
var failures:=0

func check(ok: bool, caption: String) -> void:
    if ok: print("PASS ",caption)
    else:
        failures+=1
        push_error(caption)

func _initialize() -> void:
    var sim:=WarSim.new()
    sim.set_long_operation(true)
    sim.set_scenario(WarSim.TRAINING_SCENARIO)
    var depot:=Vector2(508,742)
    var advisor:=Vector2(690,1050)
    var enemy_pos: Vector2=sim.bases[1]["pos"]
    var home_pos: Vector2=sim.commanders[0]["pos"]
    check(sim.place_post("보급기지",depot) and sim.bases[0]["pos"]==depot,"select a fixed depot site")
    check(sim.commanders[0]["pos"]==home_pos and sim.bases[1]["pos"]==enemy_pos,"depot changes only the friendly base")
    check(sim.place_post("본진",advisor) and sim._home_point(0)==advisor and sim.commanders[0]["pos"]==advisor and sim.commanders[0]["goal"]==advisor,"headquarters and strategist share the chosen origin and goal")
    check(not sim.place_post("보급기지",Vector2(809,659)) and not sim.place_post("책사",sim.field_size-Vector2(50,50)) and not sim.place_post("책사",Vector2.INF),"wetland, enemy deployment and non-finite locations rejected")
    check(sim.bases[0]["pos"]==depot and sim.commanders[0]["pos"]==advisor,"invalid placements preserve prior positions")
    sim.start()
    var base: Dictionary=sim.bases[0]
    check(base["state"]=="설치" and sim._nearest_base(0,depot,true).is_empty(),"committed site builds at launch and withholds rations")
    check(not sim.place_post("보급기지",Vector2(488,770)) and not sim.place_post("본진",depot),"fixed depot and headquarters are locked on day one")
    sim.paused=true
    sim.step(0.1)
    check(base["build_timer"]==sim.BASE_BUILD_SECONDS,"construction follows the simulation clock")
    sim.paused=false
    for tick in range(31): sim.step(0.1)
    check(base["state"]=="가동" and base["build_timer"]==0.0 and sim._nearest_base(0,depot,true)==base,"completed depot actually opens supply")
    sim.battle_time=95.0
    sim._supply_logic(0.1)
    check(base["pos"]==depot and base["state"]=="가동","manual depot stays where the player built it")
    check(sim._home_point(0)==advisor and sim.commanders[0]["pos"]==advisor,"strategist remains at relocated headquarters during the battle")
    sim.turn=6
    check(sim.request_order(0,"공격","현장 판단") and sim.couriers.back()["pos"]==advisor,"courier originates from relocated headquarters")
    _check_sites_and_migration()
    var archer:=sim.find_unit(1)
    archer["pos"]=depot+Vector2(770,0)
    archer["shipment_from"]=-1
    archer["rations"]=30.0
    archer["ammo"]=30.0
    for tick in range(400): sim._deliver_rations(archer,0.1)
    check(archer.get("deliveries",0)>0 and archer["ammo"]>30,"distant archer receives real timed shipments without a supply radius")
    _check_night_and_replies()
    _check_network()
    _check_supply_front()
    _check_crew_losses()
    _check_interrupted_work()
    _check_cavalry_intercept()
    _check_capture()
    _check_independent_victory()
    _check_crew_crossing()
    sim.reset()
    check(sim.bases[0]["state"]=="가동" and not sim.commanders[0].has("home"),"new battle clears manually placed posts")
    if failures==0: print("GUNRYAK_POST_DEPLOYMENT_PASS")
    quit(1 if failures else 0)

func _check_sites_and_migration() -> void:
    var s:=WarSim.new()
    s.set_long_operation(true)
    s.set_scenario(WarSim.TRAINING_SCENARIO)
    var first:=Vector2(508,742)
    var second:=Vector2(690,1050)
    var original: Vector2=s.headquarters[0]["pos"]
    var unit:=s.find_unit(0)
    var troop_pos: Vector2=unit["pos"]
    var objectives:=s.outposts.size()
    var supplied:=s._nearest_base(0,second,true)
    check(original==s.commanders[0]["pos"] and s._home_point(1)==s.commanders[1]["pos"],"both strategists begin in their respective headquarters")
    check(s.place_post("임시 거점",second) and not s.place_post("임시 거점",second+Vector2.ONE),"temporary site can be placed once on a clear plot")
    check(s.temporary_sites.size()==1 and s.planning_sites().size()==objectives+s.terrain_posts.size()+1 and s.outposts.size()==objectives and s.bases.size()==2 and s._nearest_base(0,second,true)==supplied,"planning marker neither scores nor supplies")
    check(s.place_post("본진",first) and s.place_post("본진",second) and s.next_hq_day==5 and unit["pos"]==troop_pos,"pregame moves are repeatable without moving troops or spending day five")
    s.start()
    for day in range(1,5):
        s.turn=day
        check(not s.place_post("본진",first) and s._home_point(0)==second,"headquarters stays locked on day %d" % day)
    s.turn=5
    check(not s.place_post("본진",Vector2.INF) and s.next_hq_day==5,"invalid move leaves entitlement intact")
    check(s.place_post("본진",first) and s._home_point(0)==first and s.commanders[0]["pos"]==first and s.commanders[0]["goal"]==first and s.next_hq_day==10,"day-five relocation takes the entire command post to its new site")
    check(not s.place_post("본진",second),"no second move on the same day")
    s.turn=9
    check(not s.place_post("본진",second),"four elapsed days cannot unlock migration")
    s.turn=10
    s.headquarters[0]["occupation"]=0.1
    check(not s.place_post("본진",second) and s.next_hq_day==10,"a besieged headquarters cannot escape by relocation")
    s.headquarters[0]["occupation"]=0.0
    s.turn=12
    check(s.place_post("본진",second) and s.next_hq_day==17,"unused move remains available and starts a fresh five-day interval")
    var raider:=s.find_unit(3)
    for corps in s.units:
        if corps["side"]==0: corps["pos"]=Vector2(1000,250)
    raider["pos"]=original
    s._update_headquarters(s.HQ_CAPTURE_SECONDS)
    check(not s.headquarters[0]["occupied"],"enemy at the previous capital cannot capture the new headquarters")
    raider["pos"]=second
    s._update_headquarters(s.HQ_CAPTURE_SECONDS)
    s._check_victory()
    check(s.finished and s.winning_side==1 and "본진 함락" in s.result,"occupation of the relocated command post decides the battle")
    s.reset()
    check(s.temporary_sites.is_empty() and s.next_hq_day==5 and s._home_point(0)==original,"new battle clears flags, position and migration clock")

func _check_network() -> void:
    var s:=WarSim.new()
    s.set_long_operation(true)
    s.set_scenario(WarSim.TRAINING_SCENARIO)
    var origin:=Vector2(350,435)
    var blue:=s.find_unit(0)
    var red:=s.find_unit(3)
    var reserve:=s.find_unit(4)
    var home: Dictionary=s.bases[0]
    home["pos"]=origin
    blue["pos"]=origin
    for u in s.units:
        if u["id"] not in [0,3,4]: u["troops"]=0.0
    s.start()
    s._extend_supply(0)
    check(s.bases.size()==2,"stationary launch does not spawn a depot")
    var next:=origin+Vector2.DOWN*s.MARCH_LEG
    blue["pos"]=next
    blue["routed"]=true
    s._extend_supply(0)
    check(s.bases.size()==2,"rout does not construct a forward camp")
    blue["routed"]=false
    s._extend_supply(0)
    var crew: Dictionary=s.supply_crews[0]
    check(s.bases.size()==2 and crew["state"]=="이동" and crew["pos"]==origin,"only the separate supply crew can start construction")
    s._supply_logic(0.1)
    check(crew["pos"]!=origin and crew["pos"]!=next and s._nearest_base(0,next,true)==home,"crew travels on the map before construction")
    for tick in range(250):
        s._supply_logic(0.1)
        if s.bases.size()==3: break
    var post: Dictionary=s.bases.back()
    check(s.bases.size()==3 and post["pos"]==next and home["pos"]==origin,"southbound march creates another base without moving the original")
    s._extend_supply(0)
    check(s.bases.size()==3 and s._nearest_base(0,next,true)==home,"unfinished post does not supply or spawn duplicates")
    for tick in range(31): s._supply_logic(0.1)
    check(s._nearest_base(0,next,true)==post and s._nearest_base(0,origin,true)==home,"original and forward sources work independently")
    blue["pos"]=origin.lerp(next,0.5)
    blue["shipment_from"]=-1
    blue["rations"]=30.0
    var prior:=int(blue.get("deliveries",0))
    s._deliver_rations(blue,0.1)
    var delay: float=blue["delivery_left"]
    s._deliver_rations(blue,delay+0.01)
    check(blue["deliveries"]==prior+1 and blue["rations"]>30.0,"two operating depots send one shipment per corps at a time")
    red["pos"]=next
    s._extend_supply(1)
    check(s.bases.size()==3,"raider cannot found a camp on the enemy depot it is attacking")
    s._supply_logic(1.0)
    check(post["alive"] and s.raid_seconds_left(post)==20,"one physical raider has twenty operation seconds left after four")
    reserve["pos"]=next
    s._supply_logic(0.5)
    check(s.raid_seconds_left(post)==8,"second raider speeds up remaining work")
    blue["pos"]=next
    s._supply_logic(0.1)
    check(post["raid_work"]==0.0 and post["alive"],"arriving defender interrupts destruction")
    blue["pos"]=next+Vector2(135,0)
    blue["morale"]=50.0
    s._supply_logic(0.5)
    red["pos"]=origin+Vector2(900,0)
    reserve["pos"]=red["pos"]
    s._supply_logic(0.1)
    check(post["raid_rate"]==0 and post["raid_work"]==0,"abandoned raid does not keep counting")
    red["pos"]=next
    reserve["pos"]=next
    s.paused=true
    s.step(0.1)
    check(post["raid_work"]==0.0,"pause freezes raids")
    s.paused=false
    for tick in range(29): s._supply_logic(0.1)
    check(post["alive"] and s._nearest_base(0,next,true)==post,"attacked camp supplies until the actual destruction tick")
    s._supply_logic(0.1)
    check(not post["alive"] and s._nearest_base(0,next,true)==home and s._nearest_base(0,origin,true)==home,"only destroyed forward radius disappears")
    check(blue["morale"]==25.0 and blue["morale_news"]=="보급기지 상실","completed raid shocks nearby friendly morale once")
    reserve["troops"]=0.0
    var red_origin: Vector2=s.bases[1]["pos"]
    red["supply_mark"]=red_origin
    red["pos"]=red_origin+Vector2.LEFT*s.MARCH_LEG
    s._extend_supply(1)
    var west: Vector2=s.supply_crews[1]["goal"]
    check(west.x<=red_origin.x-s.MARCH_LEG*0.9 and s.bases.back()["side"]==0,"opposing crew receives its own destination")
    for tick in range(350):
        s._supply_logic(0.1)
        if s.bases.back()["side"]==1: break
    check(s.bases.back()["side"]==1 and s.bases.back()["pos"]==west,"opposing march builds westward by the same rule")

func _check_supply_front() -> void:
    var s := WarSim.new()
    s.set_long_operation(true)
    s.set_scenario(WarSim.TRAINING_SCENARIO)
    var origin := Vector2(420,750)
    var foot := s.find_unit(0)
    var bow := s.find_unit(1)
    var foe := s.find_unit(3)
    for u in s.units:
        if u["id"] not in [0,1,3]: u["troops"] = 0
    s.bases[0]["pos"] = origin
    foot["pos"] = origin
    bow["pos"] = origin
    s.start()
    var edge := origin + Vector2.RIGHT * (s.MARCH_LEG-2)
    foot["pos"] = edge
    foot["goal"] = edge + Vector2(130,0)
    s._extend_supply(0)
    var crew: Dictionary = s.supply_crews[0]
    check(crew["state"]=="대기","a short march never orders another camp")
    foot["pos"]=edge+Vector2(7,0)
    s._extend_supply(0)
    check(crew["state"]=="이동","a full march leg orders an actual crew departure")
    foot["pos"] = origin
    foot["goal"] = origin
    s._extend_supply(0)
    check(crew["state"] == "대기" and crew["goal"] == crew["pos"], "crew drops an obsolete unsited camp when the column returns")
    var front := origin + Vector2(355,0)
    foot["pos"] = front
    bow["pos"] = front + Vector2(-20,24)
    foe["pos"] = front + Vector2(36,8)
    s._extend_supply(0)
    var site: Vector2 = crew["goal"]
    check(crew["state"] == "이동" and s._safe_crew_site(0,site) and site.distance_to(front)<s.MARCH_LEG, "a threatened frontage is supplied from a safe nearby site")
    foot["morale"]=60.0
    bow["morale"]=50.0
    for tick in range(185):
        s.battle_time += 0.1
        s._supply_logic(0.1)
    check(s._nearest_base(0,front,true)["pos"]==site and foot["morale"]==74.0 and bow["morale"]==64.0, "one operational depot covers both advancing corps without a manual order")

func _check_crew_losses() -> void:
    var s:=WarSim.new()
    s.set_long_operation(true)
    s.start()
    var crew: Dictionary=s.supply_crews[0]
    var home: Vector2=crew["pos"]
    var raider:=s.find_unit(3)
    for u in s.units:
        if u["id"]!=3: u["pos"]=home+Vector2(320,130)
    raider["pos"]=home
    var strength: float=raider["troops"]
    s._supply_logic(0.1)
    check(crew["strength"]<100 and crew["state"]=="회피" and raider["troops"]<strength,"weak guard skirmishes and the supply crew flees")
    for tick in range(40):
        raider["pos"]=crew["pos"]
        s._supply_logic(0.1)
    check(crew["state"]=="괴멸" and strength-raider["troops"]<3.0,"an unsupported crew is overrun with little damage to its attacker")
    var marcher:=s.find_unit(0)
    marcher["pos"]=home+Vector2(0,430)
    s._extend_supply(0)
    check(s.bases.size()==2 and not s._nearest_base(0,home,true).is_empty(),"destroyed builders cannot found camps and existing depots operate independently")
    var ready: float = crew["reassemble_at"]
    raider["pos"] = s.headquarters[0]["pos"]
    s.battle_time = ready - 0.1
    s._update_supply_crew(crew,0.1)
    check(crew["strength"] == 0, "losing a crew costs a full operation turn")
    s.battle_time = ready
    s._update_supply_crew(crew,0.1)
    check(crew["strength"] == 0, "enemy at headquarters blocks reassembly")
    raider["pos"] = s.headquarters[1]["pos"]
    s._update_supply_crew(crew,0.1)
    check(crew["state"] == "대기" and crew["strength"] == 60 and crew["pos"] == s.headquarters[0]["pos"] and s.bases.size() == 2,
        "a weak replacement starts at secure headquarters without creating a depot")


func _check_capture() -> void:
    var s:=WarSim.new()
    s.set_long_operation(true)
    s.set_scenario(2)
    s.tactical_enabled=true
    check(s.place_post("본진",Vector2(162,1545)),"establish the isolated command post for the capture exercise")
    s.start()
    s.battle_time=89.0
    s.turn=6
    var c: Dictionary=s.commanders[0]
    var general:=s.find_unit(0)
    var raider:=s.find_unit(3)
    var start: Vector2=c["pos"]
    general["pos"]=start
    raider["pos"]=start
    s._check_victory()
    check(not s.commander_captured(0),"a real escort prevents capture")
    general["pos"]=start+Vector2(340,-60)
    check(s.issue_map_order(0,"지정 위치 이동",start+Vector2(400,0)),"send a real courier before capture")
    s._check_victory()
    var expires: float=c["recover_at"]
    check(s.command_confused(0) and not s.finished and s.couriers.is_empty() and general["action"]=="지휘 혼란","capture disrupts command without ending the battle")
    check(not s.request_order(0,"공격","현장 판단") and not s.request_tactical(0,"사수") and not s.order_retreat(),"captured strategist cannot issue commands or concede")
    s.paused=true
    s.step(0.1)
    check(c["recover_at"]==expires and s.battle_time==89.0,"pause freezes confusion")
    s.paused=false
    var origin: Vector2=general["pos"]
    for tick in range(149): s.step(0.1)
    check(s.turn>6 and s.command_confused(0) and c["recover_at"]==expires and general["pos"].distance_to(origin)<90.0,"full turn of confusion survives the turn boundary without recapture")
    s.step(0.1)
    var decisions: int=general["decisions"]
    check(not s.command_confused(0) and s.commander_captured(0) and general["action"]!="지휘 혼란" and not s.command_confused(1),"living generals resume autonomous decisions exactly one turn later")
    for tick in range(40): s.step(0.1)
    check(general["decisions"]>decisions and not s.request_order(0,"공격","현장 판단"),"independent decisions continue after recovery")
    s.battle_time=s.scenario_limit-0.05
    s.step(0.1)
    check(s.finished and s.winning_side==0 and "방어 성공" in s.result,"army whose strategist was captured wins by its scenario objective")
    s.reset()
    check(not s.commander_captured(0) and not s.command_confused(0),"new battle clears capture and confusion")

func _check_independent_victory() -> void:
    var s:=WarSim.new()
    s.reserve_limit.assign([0,0])
    var defender:=s.find_unit(0)
    var attacker:=s.find_unit(3)
    for unit in s.units:
        if unit["id"] not in [0,3]: unit["troops"]=0.0
    attacker["pos"]=s.commanders[0]["pos"]
    defender["pos"]=Vector2(attacker["pos"])+Vector2(79,0)
    # The raider rides through the undefended post and continues toward the army.
    attacker["goal"]=defender["pos"]
    attacker["action"]="진군"
    attacker["ai_cooldown"]=8.0
    attacker["troops"]=55.0
    s.start()
    for tick in range(1800):
        s.step(0.1)
        if s.finished: break
    check(s.commander_captured(0) and defender["damage_dealt"]>0 and s.winning_side==0 and "전멸 또는 패주" in s.result,"surviving general fights and wins without any further orders")

func _check_crew_crossing() -> void:
    var s:=WarSim.new()
    s.set_long_operation(true)
    s.start()
    var crew: Dictionary=s.supply_crews[0]
    var from:=Vector2(s.river_x(510)-190,510)
    var to:=Vector2(s.river_x(540)+280,540)
    s.bases[0]["pos"]=from
    crew["pos"]=from
    var marcher:=s.find_unit(0)
    marcher["pos"]=to
    marcher["supply_mark"]=from
    s._extend_supply(0)
    var entered_water:=false
    for tick in range(1400):
        s._update_supply_crew(crew,0.1)
        if s.in_open_water(crew["pos"]): entered_water=true
        if crew["state"]=="구축": break
    check(not entered_water and crew["bridge_crossings"]==1 and crew["state"]=="구축" and s.bases.back()["pos"]==crew["goal"],"crew reaches the far bank via a real bridge before building")

func _check_interrupted_work() -> void:
    var s:=WarSim.new()
    s.set_long_operation(true)
    var home:=Vector2(400,520)
    s.place_post("보급기지",home)
    s.start()
    for u in s.units:
        if u["side"]==0: u["pos"]=home+Vector2(0,310)
    var enemy:=s.find_unit(3)
    var crew: Dictionary=s.supply_crews[0]
    s._supply_logic(0.5)
    var remaining: float=s.bases[0]["build_timer"]
    enemy["pos"]=home
    s._supply_logic(0.1)
    check(crew["state"]=="회피" and s.bases[0]["build_timer"]==remaining,"work stops immediately when an unescorted crew flees")
    enemy["pos"]=s.bases[1]["pos"]
    for tick in range(250):
        s.battle_time+=0.1
        s._supply_logic(0.1)
        if s.bases[0]["state"]=="가동": break
    check(s.bases[0]["state"]=="가동" and home.is_equal_approx(crew["pos"]),"returning builder completes the interrupted site")

func _check_cavalry_intercept() -> void:
    var s:=WarSim.new()
    var crew: Dictionary=s.supply_crews[1]
    var rider:=s.find_unit(2)
    rider["pos"]=Vector2(220,120)
    crew["pos"]=Vector2(317,120)
    crew["goal"]=Vector2(340,120)
    crew["state"]="이동"
    s._decide(rider)
    check(rider["action"]=="보급부대 추격" and rider["goal"]==crew["pos"],"cavalry spots an exposed moving crew and pursues its actual position")

func _check_night_and_replies() -> void:
    var s := WarSim.new()
    s.set_long_operation(true)
    s.tactical_enabled = true
    s.start()
    var observer := s.find_unit(0)
    var enemy := s.find_unit(3)
    var home: Vector2 = s.headquarters[0]["pos"]
    observer["pos"] = Vector2(630,780)
    enemy["pos"] = Vector2(observer["pos"]) + Vector2(210,0)
    for other in s.units:
        if other != observer and other != enemy: other["troops"] = 0
    check(s.day_caption() == "1일차 · 낮" and not s._nearest_visible_enemy(observer).is_empty(),"daylight identifies the distant contact")
    s.battle_time = s.turn_duration() * 0.7
    check(s.day_caption() == "1일차 · 밤" and s._nearest_visible_enemy(observer).is_empty(),"night conceals the same distant contact from the general")
    check(is_equal_approx(s.watch_factor(home,0),0.85) and is_equal_approx(s.watch_factor(observer["pos"],0),0.55),"manned camp watch extends night vision")
    s.bases[0]["pos"]=observer["pos"]
    s.bases[0]["state"]="설치"
    check(is_equal_approx(s.watch_factor(observer["pos"],0),0.55),"unfinished camp has no watch fires")
    s.bases[0]["state"]="가동"
    check(is_equal_approx(s.watch_factor(observer["pos"],0),0.85),"completed camp lights the watch")
    s.bases[0]["alive"]=false
    check(is_equal_approx(s.watch_factor(observer["pos"],0),0.55),"destroyed camp extinguishes its watch")
    s.battle_time = s.turn_duration()
    s.step(0.1)
    check(s.day_caption() == "2일차 · 낮","dawn restores the day watch")
    var report := {"id":801,"unit_id":0,"proposal":"사수","status":"대기","expires":100.0}
    s.situation_reports.append(report)
    check(not s.reply_to_report(801,true),"answers need an arrived report")
    report["status"]="미대응"
    var original: String=observer["mission"]
    check(s.reply_to_report(801,false) and not s.reply_to_report(801,true),"a returned refusal cannot be answered twice")
    check(report["reply_status"]=="이동 중" and observer["mission"]==original,"refusal rides back to the reporting commander")
    s.couriers.back()["pos"]=observer["pos"]
    s._update_couriers(0.1)
    check(report["status"]=="불허 전달" and observer["mission"]==original and observer["tactical_order"]=="","refusal arrives and preserves existing orders")
    var next := {"id":802,"unit_id":0,"proposal":"사수","status":"미대응","expires":100.0}
    s.situation_reports.append(next)
    check(s.reply_to_report(802,true) and observer["tactical_order"]=="","early approval travels without immediately changing the battle")
    s.couriers.back()["pos"]=observer["pos"]
    s._update_couriers(0.1)
    check(next["reply_status"]=="회신 도착" and observer["tactical_order"]=="사수" and next["status"]=="명령 수령","received approval changes the reporting commander's actual orders")

    var intercepted := {"id":803,"unit_id":0,"proposal":"재집결","status":"미대응","expires":100.0}
    s.situation_reports.append(intercepted)
    s.commanders[0]["pos"] = Vector2(350,800)
    enemy["pos"] = s.commanders[0]["pos"]
    check(s.reply_to_report(803,true),"a third request can receive its own decision")
    s._update_couriers(0.1)
    check(intercepted["status"]=="전령 차단" and intercepted["reply_status"]=="전령 차단" and observer["tactical_order"]=="사수","an intercepted approval never replaces an existing order")
    enemy["troops"]=0
    var across := {"id":804,"unit_id":0,"proposal":"재집결","status":"미대응","expires":100.0}
    observer["pos"]=Vector2(s.river_x(640.0)+125,640)
    s.commanders[0]["pos"]=Vector2(s.river_x(640.0)-90,640)
    s.situation_reports.append(across)
    check(s.reply_to_report(804,true),"dispatch a reply across the river")
    var rider: Dictionary=s.couriers.back()
    var wet:=false
    for i in range(200):
        s._update_couriers(0.1)
        wet = wet or s.in_open_water(rider["pos"])
        if s.couriers.is_empty(): break
    check(not wet and rider["bridge_crossings"]==1 and across["status"]=="명령 수령","reply reaches the original sender through a real bridge")
