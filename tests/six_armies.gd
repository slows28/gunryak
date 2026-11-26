extends SceneTree
const WarSim = preload("res://scripts/war_sim.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Main = preload("res://main.tscn")
var failures: int = 0
func check(ok: bool,label: String) -> void:
    if not ok:
        failures += 1
        push_error(label)
    else: print("PASS "+label)
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var dust_sim := WarSim.new()
    dust_sim.set_six_armies(true)
    var u_dust: Dictionary = dust_sim.find_unit(0)
    u_dust["formation"]="종대"
    u_dust["facing"]=Vector2.RIGHT
    var road := Vector2(250.0,dust_sim.road_y(250.0,0))
    var grass := Vector2(250.0,650.0)
    check(dust_sim.dusty_ground(road) and not dust_sim.dusty_ground(grass),"soil and grass classification")
    check(not dust_sim.dusty_ground(Vector2(dust_sim.river_x(390.0),390.0)) and not dust_sim.dusty_ground(Vector2(dust_sim.river_x(600.0),600.0)),"no soil dust on bridge or river")
    u_dust["pos"]=road
    dust_sim._emit_march_dust(u_dust,road,Vector2.ZERO)
    check(dust_sim.dust_effects.is_empty(),"stationary road produces no dust")
    dust_sim._emit_march_dust(u_dust,road-Vector2(12,0),Vector2(12,0))
    check(not dust_sim.dust_effects.is_empty(),"marching on soil produces dust")
    var valid_soil: bool=true
    for puff in dust_sim.dust_effects:
        valid_soil=valid_soil and dust_sim.dusty_ground(puff["pos"])
    check(valid_soil,"every puff originates on exposed soil")
    dust_sim.dust_effects.clear()
    u_dust["pos"]=grass
    dust_sim._emit_march_dust(u_dust,grass-Vector2(12,0),Vector2(12,0))
    check(dust_sim.dust_effects.is_empty(),"marching across grass produces no dust")
    u_dust["pos"]=road
    dust_sim._emit_march_dust(u_dust,road-Vector2(12,0),Vector2(12,0))
    dust_sim.battle_time+=WarSim.DUST_LIFE+0.1
    dust_sim._record_presentation()
    check(dust_sim.dust_effects.is_empty(),"dust expires after stopping")
    # Controlled tactical comparisons use the real damage and movement engine.
    var tactics := WarSim.new()
    tactics.set_six_armies(true)
    var cavalry: Dictionary=tactics.find_unit(2)
    var infantry: Dictionary=tactics.find_unit(3)
    var archer: Dictionary=tactics.find_unit(1)
    var target: Dictionary=tactics.find_unit(4)
    cavalry["pos"]=Vector2(600,880)
    infantry["pos"]=Vector2(650,880)
    archer["pos"]=Vector2(500,880)
    target["pos"]=Vector2(700,880)
    infantry["formation"]="방진"
    var front_counter: float=tactics.tactical_matchup(cavalry,infantry,false)
    var flank_counter: float=tactics.tactical_matchup(cavalry,infantry,true)
    check(front_counter<0.8 and flank_counter>1.0,"cavalry counter depends on formation and attack direction")
    check(tactics.tactical_matchup(cavalry,target,false)>1.0,"cavalry counters archers")
    check(tactics.tactical_matchup(infantry,cavalry,false)>1.0,"square infantry counters cavalry")
    # Isolate two attackers and one defender; run the actual combat function.
    for u in tactics.units:
        if int(u["id"]) not in [0,1,3]: u["troops"]=0.0
    var main: Dictionary=tactics.find_unit(0)
    main["pos"]=Vector2(600,880)
    main["facing"]=Vector2.RIGHT
    main["formation"]="어린진"
    infantry["facing"]=Vector2.LEFT
    infantry["pos"]=Vector2(650,880)
    archer["pos"]=Vector2(500,880)
    archer["facing"]=Vector2.RIGHT
    check(tactics._has_combined_arms(main,infantry),"bow and infantry actually in shared contact range")
    tactics._combat(0.1)
    var linked_damage: float=float(main["linked_hits"])
    check(linked_damage>0.0,"actual linked combat damage recorded")
    archer["pos"]=Vector2(250,880)
    check(not tactics._has_combined_arms(main,infantry),"no cooperation bonus outside actual range")
    archer["mission"]="전열 엄호"
    var escort: Dictionary=tactics._coordinated_order(archer,{},"진격","",Vector2.ZERO)
    check(escort["action"]=="협동 엄호" and int(archer["link_id"])==int(main["id"]),"archer links to friendly frontline")
    var support_goal: Vector2=escort["goal"]
    check(support_goal.x<float(main["pos"].x),"archer takes position behind infantry")
    # Explicit partners are validated and retained until a new order arrives.
    check(tactics.select_unit_mission(1,"전열 엄호","안행진 유지",0),"valid named partner")
    check(not tactics.select_unit_mission(1,"전열 엄호","안행진 유지",3),"enemy partner rejected")
    check(not tactics.select_unit_mission(1,"전열 엄호","안행진 유지",1),"self partner rejected")
    check(int(archer["assigned_link"])==0,"named partner retained")
    archer["pos"]=Vector2(500,880)
    main["pos"]=Vector2(600,880)
    infantry["pos"]=Vector2(650,880)
    check(not tactics._physical_screen(archer,infantry).is_empty(),"physical infantry screen in contact")
    main["pos"]=Vector2(600,1080)
    check(tactics._physical_screen(archer,infantry).is_empty(),"no protection with guard displaced")
    main["pos"]=Vector2(600,880)
    var cavalry_plan := WarSim.new()
    cavalry_plan.set_six_armies(true)
    var wing: Dictionary=cavalry_plan.find_unit(2)
    var front: Dictionary=cavalry_plan.find_unit(0)
    var foe: Dictionary=cavalry_plan.find_unit(3)
    wing["pos"]=Vector2(650,1035)
    front["pos"]=Vector2(600,880)
    front["facing"]=Vector2.RIGHT
    foe["pos"]=Vector2(650,880)
    foe["facing"]=Vector2.LEFT
    check(cavalry_plan.select_unit_mission(2,"측후방 기동","봉시진 유지",0),"named flank partner")
    var order: Dictionary=cavalry_plan._coordinated_order(wing,foe,"진격","",Vector2.ZERO)
    wing["pos"]=wing["flank_goal"]
    front["pos"]=Vector2(400,880)
    order=cavalry_plan._coordinated_order(wing,foe,"진격","",Vector2.ZERO)
    check(order["action"]=="협동 대기","flank waits for frontal contact")
    front["pos"]=Vector2(600,880)
    order=cavalry_plan._coordinated_order(wing,foe,"진격","",Vector2.ZERO)
    check(order["action"]=="돌파","flank commits when partner contacts enemy")
    print("TACTICAL_EVIDENCE "+JSON.stringify({"cavalry_front_square":front_counter,"cavalry_flank_square":flank_counter,"linked_damage":linked_damage,"escort_goal":str(support_goal)}))
    # A controlled enemy wing sees a real cavalry threat to its archer.
    var enemy_ai:=WarSim.new()
    enemy_ai.set_long_operation(true)
    var red_guard:Dictionary=enemy_ai.find_unit(3)
    var red_archer:Dictionary=enemy_ai.find_unit(4)
    var blue_horse:Dictionary=enemy_ai.find_unit(2)
    for soldier in enemy_ai.units:
        soldier["pos"]=Vector2(2500,1500) if int(soldier["side"])==1 else Vector2(180,1500)
    red_guard["pos"]=Vector2(1850,900)
    red_archer["pos"]=Vector2(1950,900)
    blue_horse["pos"]=Vector2(1770,900)
    enemy_ai._enemy_strategy()
    check(red_guard["ai_role"]=="궁병 보호" and int(red_guard["ai_partner"])==4,"red infantry reacts to observed cavalry threat")
    var defensive:Dictionary=enemy_ai._coordinated_order(red_guard,blue_horse,"방어","",red_guard["pos"])
    check(defensive["action"]=="궁병 보호" and (defensive["goal"] as Vector2).x<1950.0,"guard intercepts before archer")
    blue_horse["pos"]=Vector2(180,1500)
    enemy_ai.battle_time=25.0
    enemy_ai._enemy_strategy()
    check(str(red_guard["ai_role"])=="","expired red role is not refreshed without observation")
    # Real movement and combat tests for the long-operation route constraints.
    var route_sim:=WarSim.new()
    route_sim.set_long_operation(true)
    var traveler:Dictionary=route_sim.find_unit(2)
    for u in route_sim.units:
        if int(u["id"])!=2: u["troops"]=0.0
    var start_pos:=Vector2(850,650)
    var end_pos:=Vector2(1600,650)
    traveler["pos"]=start_pos
    traveler["goal"]=end_pos
    traveler["action"]="지정 위치 이동"
    var chosen_goal:Vector2=route_sim._committed_bridge_route(traveler,start_pos,end_pos)
    var committed:float=float(traveler["bridge_y"])
    check(committed in [390.0,850.0,1300.0] and chosen_goal.y==committed,"select actual bridge for opposite bank destination")
    var alternate:Vector2=route_sim._committed_bridge_route(traveler,start_pos,Vector2(1800,1050))
    check(alternate.y==committed and float(traveler["bridge_y"])==committed,"retain crossing despite changing destination on far bank")
    var dry:bool=true
    for step in range(600):
        route_sim._move_unit(traveler,0.1)
        dry=dry and route_sim.terrain_at(traveler["pos"])!="하천"
        if (traveler["pos"] as Vector2).distance_to(end_pos)<5.0: break
    check(dry and (traveler["pos"] as Vector2).distance_to(end_pos)<10.0 and int(traveler["bridge_crossings"])==1,"actual army reaches opposite bank through one bridge without entering water")
    var rx:float=route_sim.river_x(650.0)
    var bank:=Vector2(rx-29.0,650.0)
    var blocked:Vector2=route_sim._land_motion(traveler,bank,Vector2(rx-24.0,650.0))
    check(route_sim.terrain_at(blocked)!="하천" and bank.distance_to(blocked)<=5.01,"frontline pressure cannot displace army into river or teleport")
    traveler["pos"]=bank
    traveler["formation"]="학익진"
    traveler["facing"]=Vector2.DOWN
    var slots_dry:bool=true
    for spot in route_sim.army_slots(traveler,40,10.0):
        slots_dry=slots_dry and route_sim.terrain_at(spot)!="하천"
    for spot in route_sim.formation_slots(traveler):
        slots_dry=slots_dry and route_sim.terrain_at(spot)!="하천"
    check(slots_dry,"both combat and displayed ranks remain on land")
    check(route_sim._river_separates(Vector2(rx-35.0,650.0),Vector2(rx+35.0,650.0)),"unbridged channel separates melee")
    check(not route_sim.issue_map_order(2,"지역 사수",Vector2(rx,650.0),-1),"reject destination in river")
    var committed_flank:=WarSim.new()
    committed_flank.set_long_operation(true)
    var cf:Dictionary=committed_flank.find_unit(0)
    var cw:Dictionary=committed_flank.find_unit(2)
    var ce:Dictionary=committed_flank.find_unit(3)
    cf["pos"]=Vector2(600,880)
    cf["facing"]=Vector2.RIGHT
    ce["pos"]=Vector2(650,880)
    ce["facing"]=Vector2.LEFT
    cw["pos"]=Vector2(650,1035)
    check(committed_flank.select_unit_mission(2,"측후방 기동","현장 판단",0),"long-operation named flank")
    committed_flank._coordinated_order(cw,ce,"진격","",Vector2.ZERO)
    cw["pos"]=cw["flank_goal"]
    var strike:Dictionary=committed_flank._coordinated_order(cw,ce,"진격","",Vector2.ZERO)
    check(strike["action"]=="돌파" and int(cw["flank_phase"])==2 and int(cw["flank_commits"])==1,"flank enters committed attack once")
    committed_flank.battle_time=30.0
    strike=committed_flank._coordinated_order(cw,ce,"진격","",Vector2.ZERO)
    check(strike["action"]=="돌파" and int(cw["flank_commits"])==1 and int(cw["flank_completed"])==1,"committed attack survives waypoint timeout without duplicate maneuver")
    # A long route receives more time than a short maneuver, and a reached
    # waypoint retains a separate window to synchronize with the frontal army.
    var budget_sim:=WarSim.new()
    budget_sim.set_long_operation(true)
    var budget_wing:Dictionary=budget_sim.find_unit(2)
    var budget_front:Dictionary=budget_sim.find_unit(0)
    var budget_enemy:Dictionary=budget_sim.find_unit(3)
    budget_wing["pos"]=Vector2(800,650)
    budget_front["pos"]=Vector2(1500,650)
    budget_enemy["pos"]=Vector2(1560,650)
    budget_enemy["facing"]=Vector2.LEFT
    check(budget_sim.select_unit_mission(2,"측후방 기동","현장 판단",0),"assign route budget test partner")
    budget_sim._coordinated_order(budget_wing,budget_enemy,"진격","",Vector2.ZERO)
    check(float(budget_wing["flank_until"])>24.0 and float(budget_wing["flank_until"])<=80.0,"wide route receives bounded travel budget")
    # Scenario-specific default commander protection respects explicit map orders.
    var escort_sim:=WarSim.new()
    escort_sim.set_long_operation(true)
    escort_sim.set_scenario(3)
    var rear_id:int=escort_sim._escort_rearguard(0)
    check(rear_id>=0,"escort assigns a living default infantry rear guard")
    if rear_id>=0:
        var rear:Dictionary=escort_sim.find_unit(rear_id)
        check(str(rear["type"])=="보병" and int(rear["side"])==0,"rear guard has valid side and type")
        rear["has_destination"]=true
        check(escort_sim._escort_rearguard(0)!=rear_id,"explicit map order excludes default rear guard")
        rear["has_destination"]=false
        rear["routed"]=true
        check(escort_sim._escort_rearguard(0)!=rear_id,"routed army cannot be assigned protection")
    # Verify the information shown on the battlefield against actual movement.
    var cargo_sim:=WarSim.new()
    cargo_sim.set_long_operation(true)
    cargo_sim.set_scenario(3)
    var wagon_origin:Vector2=cargo_sim.convoy["pos"]
    for u in cargo_sim.units:
        u["pos"]=Vector2(200,1200) if int(u["side"])==0 else Vector2(2500,1500)
    check(cargo_sim.convoy_status()["state"]=="호위 대기","cargo reports unguarded wait")
    cargo_sim._update_convoy(0.1)
    check(cargo_sim.convoy["pos"]==wagon_origin and float(cargo_sim.convoy["unguarded_seconds"])>0.0,"unguarded wagon actually waits")
    var cargo_guard:Dictionary=cargo_sim.find_unit(0)
    cargo_guard["pos"]=wagon_origin+Vector2(30,0)
    cargo_sim.started=true
    cargo_sim._update_convoy(0.1)
    check(float(cargo_sim.convoy_status()["progress"])>0.0 and cargo_sim.convoy_status()["state"]=="호위 이동","cargo progress reflects actual movement")
    var cargo_enemy:Dictionary=cargo_sim.find_unit(3)
    cargo_enemy["pos"]=cargo_sim.convoy["pos"]
    var stopped:Vector2=cargo_sim.convoy["pos"]
    cargo_sim._update_convoy(0.1)
    check(cargo_sim.convoy_status()["state"]=="교전 정체" and cargo_sim.convoy["pos"]==stopped and float(cargo_sim.convoy["hp"])<100.0,"cargo contested state matches halt and damage")
    cargo_guard["pos"]=cargo_sim.commanders[0]["pos"]
    check(cargo_sim.commander_guard_count(0)>0,"commander protection uses actual capture radius")
    cargo_guard["routed"]=true
    check(cargo_sim.commander_guard_count(0)==0,"routed guard does not protect commander")
    var route_preview_sim:=WarSim.new()
    route_preview_sim.set_long_operation(true)
    var route_preview_unit:Dictionary=route_preview_sim.find_unit(2)
    route_preview_unit["pos"]=Vector2(800,650)
    route_preview_unit["goal"]=Vector2(1600,650)
    route_preview_sim._committed_bridge_route(route_preview_unit,route_preview_unit["pos"],route_preview_unit["goal"])
    var preview_bridge:float=float(route_preview_unit["bridge_y"])
    var preview:Array[Vector2]=route_preview_sim.committed_route_preview(route_preview_unit)
    check(preview.size()==3 and preview[0].y==preview_bridge and preview[1].y==preview_bridge and preview.back()==route_preview_unit["goal"],"route preview reflects actual committed bridge and destination")
    check(float(route_preview_unit["bridge_y"])==preview_bridge,"route preview does not mutate army route")
    # Actual damage suffered by an intervening infantry line is measured
    # separately from damage reduction to an attacked archer.
    var screen_sim:=WarSim.new()
    screen_sim.set_long_operation(true)
    var guard:Dictionary=screen_sim.find_unit(0)
    var bow:Dictionary=screen_sim.find_unit(1)
    var assault:Dictionary=screen_sim.find_unit(5)
    for u in screen_sim.units:
        if int(u["id"]) not in [0,1,5]: u["troops"]=0.0
    guard["pos"]=Vector2(600,880)
    guard["formation"]="방진"
    guard["facing"]=Vector2.RIGHT
    bow["pos"]=Vector2(500,880)
    assault["pos"]=Vector2(650,880)
    assault["facing"]=Vector2.LEFT
    check(screen_sim._guarding_archer_in_contact(guard,assault),"actual line interposed before archer")
    screen_sim._combat(0.1)
    check(float(guard["guard_intercept_damage"])>0.0,"actual melee damage recorded on protective infantry")
    print("ROUTE_EVIDENCE "+JSON.stringify({"bridge":committed,"crossings":traveler["bridge_crossings"],"position":str(traveler["pos"]),"no_water":dry,"flank_commits":cw["flank_commits"],"guard_damage":guard["guard_intercept_damage"]}))
    for scenario in range(5):
        var sim := WarSim.new()
        sim.set_long_operation(true)
        sim.set_scenario(scenario)
        sim.tactical_enabled = true
        check(sim.command_ids(0).size()==10 and sim.command_ids(1).size()==10 and sim.units.size()==20,"six distinct leaders scenario "+str(scenario))
        check(sim.total_troops(0)==38000 and sim.reserve_limit[0]==1,"actual initial manpower and reserve cap")
        var within_range: bool = true
        for unit in sim.units:
            within_range = within_range and float(unit["troops"])>=3000.0 and float(unit["troops"])<=5000.0
        check(within_range,"every initial army 3000–5000")
        check(sim.select_unit_mission(8,"본진 방어","명령 엄수"),"sixth commander receives preplan")
        if scenario==0:
            sim.select_unit_mission(1,"전열 엄호","안행진 유지")
            sim.select_unit_mission(2,"측후방 기동","봉시진 유지")
            sim.select_unit_mission(7,"구원 지원","재량 위임")
        sim.start()
        check(sim.units.size()==20,"no hidden duplicate formations")
        var issued: bool = false
        var water_ticks:int=0
        for i in range(4250):
            if sim.finished: break
            sim.step(0.1)
            for u in sim.units:
                if float(u["troops"])>0.0 and sim.terrain_at(u["pos"])=="하천": water_ticks+=1
            if sim.turn>=WarSim.COURIER_TURN and not issued:
                issued=sim.request_order(8,"중앙 진격","재량 위임")
        check(sim.operation_limit()==(1680.0 if scenario==3 else 1500.0),"25-minute scenario budget / 28-minute escort")
        check(sim.finished and sim.validate_state().is_empty() and sim.units.size()<=22,"ten field armies and at most one reserve per faction")
        var linked: float=0.0
        var counter: float=0.0
        var flanking: float=0.0
        var maneuver: float=0.0
        var support: float=0.0
        var completed: int=0
        var screened: float=0.0
        var bridge_count:int=0
        var water_count:int=0
        var commits:int=0
        var aborts:int=0
        var guard_damage:float=0.0

        for u in sim.units:
            if int(u["side"])==0:
                linked+=float(u["linked_hits"])
                counter+=float(u["counter_damage"])
                flanking+=float(u["flank_damage"])
                maneuver+=float(u["maneuver_distance"])
                support+=float(u["support_seconds"])
                completed+=int(u["flank_completed"])
                screened+=float(u["screened_damage"])
                bridge_count+=int(u["bridge_crossings"])
                water_count+=int(u["blocked_water_steps"])
                commits+=int(u["flank_commits"])
                aborts+=int(u["flank_aborts"])
                guard_damage+=float(u["guard_intercept_damage"])
        print("ROUTE_ROW "+JSON.stringify({"scenario":scenario,"crossings":bridge_count,"blocked_steps":water_count,"water_ticks":water_ticks,"flank_commits":commits,"flank_aborts":aborts,"guard_damage":guard_damage}))
        check(water_ticks==0,"no ground army center enters river in actual scenario "+str(scenario))
        print("COOPERATION_ROW "+JSON.stringify({"scenario":scenario,"linked_damage":linked,"counter_damage":counter,"flank_damage":flanking,"maneuver_distance":maneuver,"support_seconds":support,"flank_completed":completed,"screened_damage":screened,"enemy_replans":sim.enemy_replans}))
        if scenario==3:
            print("ESCORT_ROW "+JSON.stringify({"progress":sim.convoy_status()["progress"],"hp":sim.convoy["hp"],"guarded":sim.convoy_status()["guards"],"moving_seconds":float(sim.convoy.get("moving_seconds",0.0))*sim.operation_scale(),"blocked_seconds":float(sim.convoy.get("blocked_seconds",0.0))*sim.operation_scale(),"unguarded_seconds":float(sim.convoy.get("unguarded_seconds",0.0))*sim.operation_scale(),"commander_guards":sim.commander_guard_count(0)}))
        print("SIX_ARMY_ROW "+JSON.stringify({"scenario":scenario,"seconds":sim.operation_elapsed(),"model_seconds":sim.battle_time,"winner":sim.winning_side,"blue":sim.total_troops(0),"red":sim.total_troops(1),"delivered":sim.delivered_orders,"intercepted":sim.intercepted_orders,"issued":issued,"result":sim.result}))
    var model := Campaign.new()
    model.set_six_armies(true)
    model.save_path = "user://gunryak_six_test.json"
    check(model.state["active"].size()==10 and model.state["roster"].size()==13,"six armies and spare officers")
    check(model.replenish(2) and int(model.state["troops"][2])==3700,"500 soldiers replenished")
    check(model.set_formation(5,"학익진"),"strategic formation selection")
    check(model.recruit(6) and model.assign(5,6),"replacement commander recruitment")
    check(model.assign(0,2),"aggressive officer can take the first army")
    var sim := WarSim.new()
    sim.set_six_armies(true)
    check(model.prepare(1,sim) and sim.find_unit(8)["name"]=="요화","sixth strategic slot deploys correct general")
    var replacement: Dictionary=sim.find_unit(8)
    check(replacement["mind"]["profile"]["style"]==replacement["personality"],"replacement general starts with own profile")
    var first: Dictionary=sim.find_unit(0)
    check(first["name"]=="위연" and first["mind"]["confidence"]==72.0 and first["mind"]["trust"]==first["loyalty"],"initial confidence and trust follow the assigned officer")
    check(sim.find_unit(8)["formation"]=="학익진","actual strategic formation deployed")
    var u: Dictionary = sim.find_unit(0)
    var signatures: Dictionary = {}
    for shape in WarSim.LARGE_FORMATIONS:
        u["formation"]=shape
        var points: Array[Vector2]=sim.formation_slots(u)
        signatures[str(points)]=true
        check(points.size()>0 and points.size()<=24,"bounded real slots "+shape)
    check(signatures.size()==7,"seven different formation geometries")
    sim.start()
    for i in range(4200):
        if sim.finished: break
        sim.step(0.1)
    check(model.conclude(sim) and model.state["troops"][5]==floori(sim.corps_report(8)["troops"]),"sixth slot survivors persist")
    check(model.save(),"save six-army campaign")
    var loaded := Campaign.new()
    loaded.set_six_armies(true)
    loaded.save_path = model.save_path
    check(loaded.load_save() and loaded.state["active"]==model.state["active"] and loaded.state["formations"]==model.state["formations"],"six-army save roundtrip")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(model.save_path))
    var game: Control = Main.instantiate()
    root.add_child(game)
    await process_frame
    check(game.general_cards.size()==10 and game.sim.command_ids(0).size()==10,"six commander cards map to six independent units")
    game.call("_on_unit_selected",5)
    check(game.selected_id==8,"last commander selection maps to correct unit ID")
    game.call("_on_unit_selected",-1)
    game.call("_on_unit_selected",99)
    check(game.selected_id==8,"invalid selection does not corrupt commander ID")
    game.call("_open_planning")
    check(game.plan_donor.item_count==10,"planning lists every independent commander")
    game.planning_dialog.hide()
    game.call("_leave_title")
    check(game.order_view.visible and not game.sim.started,"independent planning map opens before battle")
    check(int(game.order_view.partner_choice.get_item_metadata(0))==-1,"no-partner selection retains explicit sentinel")
    check(game.order_view.action_buttons.size()==9,"eight positional actions and freedom of command")
    game.order_view.call("_choose_action",3)
    check(game.order_view.action_choice.selected==3 and game.order_view.action_buttons[3].button_pressed,"action tiles update the authoritative selection")
    game.order_view.draft_dirty=false
    game.order_view.call("_select",game.selected_id)
    var map_sim=game.sim
    var dest:=Vector2(790,900)
    var crossing: float=map_sim.map_order_crossing(1,Vector2(1920,910))
    check(crossing in [390.0,850.0,1300.0] and float(map_sim.find_unit(1)["bridge_y"])<0.0,"planning forecast uses a real bridge without committing the army")
    var river:=Vector2(float(map_sim.river_x(600.0)),600.0)
    check(map_sim.in_open_water(river) and not map_sim.map_order_issue(1,"지역 사수",river,-1).is_empty(),"open water preflight rejects the destination")
    check(map_sim.issue_map_order(1,"전열 엄호",dest,0),"map order accepts destination action and partner")
    var map_unit:Dictionary=map_sim.find_unit(1)
    check(map_unit["policy"]=="현장 판단" and map_unit["order_destination"]==dest and int(map_unit["assigned_link"])==0,"general retains formation judgment")
    game.call("_start")
    check(not game.order_view.visible and map_sim.started,"battle view is separate")
    game.set_process(false)
    game.game_speed=1.0
    var prior: float=map_sim.operation_elapsed()
    for i in range(40): game.call("_process",0.1)
    check(absf(map_sim.operation_elapsed()-prior-4.0)<0.5,"normal playback clock matches elapsed active real time")
    game.game_speed=4.0
    prior=map_sim.operation_elapsed()
    for i in range(40): game.call("_process",0.1)
    check(absf(map_sim.operation_elapsed()-prior-16.0)<0.5,"four times playback clock")
    game.game_speed=1.0
    game.call("_open_order_map")
    game.order_view.call("_select",1)
    game.order_view.destination=Vector2(1000,800)
    game.order_view.has_destination=true
    game.order_view.call("_choose_action",2)
    check(game.order_view.apply.disabled and game.order_view.feedback.text.contains("5일차"),"early draft shows the courier gate before submission")
    game.order_view.call("_launch")
    check(not game.order_view.visible and not map_sim.paused,"return to battle without discarding an early draft")
    game.call("_open_order_map")
    check(game.order_view.draft_dirty and game.order_view.destination==Vector2(1000,800),"early draft is available after reopening the war room")
    game.order_view.drafts.clear()
    game.order_view.draft_dirty=false
    game.order_view.call("_launch")
    map_sim.battle_time=4.0*map_sim.turn_duration()-0.05
    map_sim.turn=4
    game.game_speed=4.0
    game.step_buffer=0.0
    game.call("_process",0.10)
    check(map_sim.turn==5 and game.order_view.in_battle and game.order_view.feedback.text.contains("파견 가능"),"entering turn five opens the actionable dispatch map")
    check(game.order_view.visible and map_sim.paused and game.order_view.title.text.contains("1차 중간회의"),"day five council pauses simulation")
    var next_dest:=Vector2(12,800)
    var reachable_dest:=Vector2(18,800)
    game.order_view.call("_select",1)
    game.order_view.destination=next_dest
    game.order_view.has_destination=true
    game.order_view.partner_choice.select(0)
    game.order_view.call("_choose_action",2)
    check(not game.order_view.apply.disabled,"turn-five order can be confirmed on the map")
    game.order_view.apply.pressed.emit()
    check(map_sim.has_pending_courier(1),"midbattle destination order dispatched")
    game.order_view.call("_select",0)
    game.order_view.call("_select",1)
    check(game.order_view.destination==reachable_dest and game.order_view.action_choice.selected==2,"planning sheet restores a dispatched destination before delivery")
    check(map_sim.map_dispatches[1]["status"]=="이동 중" and map_sim.map_order_issue(1,"지역 사수",next_dest,-1).contains("이미"),"dispatch tracking and duplicate courier preflight")
    game.call("_refresh_hud")
    check(game.order_status_label.text.contains("전령 이동"),"live command panel shows the selected general's pending courier")
    check(map_unit["order_destination"]==dest,"order not applied before courier delivery")
    for letter in map_sim.couriers: letter["pos"]=map_unit["pos"]
    map_sim._update_couriers(0.1)
    check(map_unit["order_destination"]==reachable_dest and map_unit["mission"]=="지역 사수","courier delivers actual map order")
    check(map_sim.map_dispatches[1]["status"]=="도착","courier status resolves only on actual delivery")
    game.order_view.hide()
    game.call("_return_to_battle")
    game.call("_process",0.10)
    check(not map_sim.paused and not game.order_view.visible,"return restores battle clock without reopening the dispatch map")
    check(game.order_status_label.text.contains("전령 도착") and game.order_status_label.text.contains("목적지 미도달"),
        "inspector distinguishes courier delivery from reaching the destination")
    map_unit["destination_reached"]=true
    game.call("_refresh_hud")
    check(game.order_status_label.text.ends_with("목적지 도달"),"inspector shows verified arrival")
    check(game.situation_btn.theme_type_variation==&"" and not game.situation_btn.disabled,"idle reports button is neutral and accessible")
    var routine: Dictionary={"id":90,"unit_id":1,"sender":map_unit["name"],"kind":"군량 부족","title":"군량 부족","status":"대기","urgent":false,"pos":map_unit["pos"],"written_at":map_sim.battle_time}
    routine["rider"]=map_sim._field_rider(map_sim.commanders[0]["pos"],0,-90)
    map_sim.situation_reports.append(routine)
    map_sim.incoming_reports.append(routine)
    map_sim._move_reporting_messengers(0.1)
    check(not game.arrival_messages.any(func(m): return m["id"]==90),"report in transit stays hidden")
    routine["written_at"]-=2.0
    map_sim._move_reporting_messengers(0.1)
    game.call("_refresh_hud")
    check(game.situation_btn.theme_type_variation==&"" and not game.messenger_card.visible and not game.dispatch_headline.visible,"routine reports enter the inbox quietly")
    check(game.arrival_rows[0].visible and game.arrival_rows[0].get_meta("report_id")==90 and "군량 부족" in game.arrival_rows[0].text and not map_sim.paused,"ordinary courier posts a nonblocking message on the left")
    map_sim.respond_situation(90,"현장 판단")
    map_sim.situation_reports.append({"id":91,"unit_id":1,"title":"전선 압박","status":"미대응","pos":map_unit["pos"]})
    game.call("_refresh_hud")
    check(game.situation_btn.theme_type_variation==&"UrgentReport" and game.situation_btn.text.ends_with(" 1"),
        "only an open live report highlights the reports button")
    check(map_sim.respond_situation(91,"현장 판단"),"a commander can acknowledge the active report")
    game.call("_refresh_hud")
    check(game.situation_btn.theme_type_variation==&"" and game.command_outcome.text.contains("재량 유지"),
        "acknowledgment clears the highlight and appears in the selected commander's result")
    map_sim.situation_reports.append({"id":92,"unit_id":map_sim.command_ids(0)[0],"executor":1,
        "status":"실행 중","response":"지원","action_seen":"긴급 지원"})
    game.call("_refresh_hud")
    check(game.command_outcome.text.contains("관측 행동 긴급 지원"),"an actual response state is distinguishable from delivery")
    game.call("_begin_campaign")
    check(game.strategy_view.slot_choice.item_count==10,"six strategic UI slots")
    print("GUNRYAK_SIX_PASS" if failures==0 else "GUNRYAK_SIX_FAIL "+str(failures))
    game._quit_game(0 if failures==0 else 1)
