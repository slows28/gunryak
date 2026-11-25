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
    for scenario in range(5):
        var sim := WarSim.new()
        sim.set_six_armies(true)
        sim.set_scenario(scenario)
        sim.tactical_enabled = true
        check(sim.command_ids(0).size()==6 and sim.command_ids(1).size()==6 and sim.units.size()==12,"six distinct leaders scenario "+str(scenario))
        check(sim.total_troops(0)==23500 and sim.reserve_limit[0]==1,"actual initial manpower and reserve cap")
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
        check(sim.units.size()==12,"no hidden duplicate formations")
        var issued: bool = false
        for i in range(4200):
            if sim.finished: break
            sim.step(0.1)
            if sim.turn>=6 and not issued:
                issued=sim.request_order(8,"중앙 진격","재량 위임")
        check(sim.finished and sim.validate_state().is_empty() and sim.units.size()<=14,"battle valid, at most seven per faction")
        var linked: float=0.0
        var counter: float=0.0
        var flanking: float=0.0
        var maneuver: float=0.0
        var support: float=0.0
        var completed: int=0
        var screened: float=0.0
        for u in sim.units:
            if int(u["side"])==0:
                linked+=float(u["linked_hits"])
                counter+=float(u["counter_damage"])
                flanking+=float(u["flank_damage"])
                maneuver+=float(u["maneuver_distance"])
                support+=float(u["support_seconds"])
                completed+=int(u["flank_completed"])
                screened+=float(u["screened_damage"])
        print("COOPERATION_ROW "+JSON.stringify({"scenario":scenario,"linked_damage":linked,"counter_damage":counter,"flank_damage":flanking,"maneuver_distance":maneuver,"support_seconds":support,"flank_completed":completed,"screened_damage":screened}))
        print("SIX_ARMY_ROW "+JSON.stringify({"scenario":scenario,"seconds":sim.battle_time,"winner":sim.winning_side,"blue":sim.total_troops(0),"red":sim.total_troops(1),"delivered":sim.delivered_orders,"intercepted":sim.intercepted_orders,"issued":issued,"result":sim.result}))
    var model := Campaign.new()
    model.set_six_armies(true)
    model.save_path = "user://gunryak_six_test.json"
    check(model.state["active"].size()==6 and model.state["roster"].size()==9,"six armies and spare officers")
    check(model.replenish(2) and int(model.state["troops"][2])==3700,"500 soldiers replenished")
    check(model.set_formation(5,"학익진"),"strategic formation selection")
    check(model.recruit(6) and model.assign(5,6),"replacement commander recruitment")
    var sim := WarSim.new()
    sim.set_six_armies(true)
    check(model.prepare(1,sim) and sim.find_unit(8)["name"]=="요화","sixth strategic slot deploys correct general")
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
    check(game.unit_list.item_count==6,"six commander UI entries")
    game.call("_on_unit_selected",5)
    check(game.selected_id==8,"last commander selection maps to correct unit ID")
    game.call("_on_unit_selected",-1)
    game.call("_on_unit_selected",99)
    check(game.selected_id==8,"invalid selection does not corrupt commander ID")
    game.call("_open_planning")
    check(game.plan_donor.item_count==6,"planning lists every independent commander")
    game.planning_dialog.hide()
    game.call("_begin_campaign")
    check(game.strategy_view.slot_choice.item_count==6,"six strategic UI slots")
    game.queue_free()
    await process_frame
    print("GUNRYAK_SIX_PASS" if failures==0 else "GUNRYAK_SIX_FAIL "+str(failures))
    quit(0 if failures==0 else 1)
