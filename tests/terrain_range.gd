extends SceneTree
## Fixed probes and real unit movement on the same selectable scenario as the player.
const WarSim=preload("res://scripts/war_sim.gd")
const FrontView=preload("res://scripts/front_view.gd")
const Geometry=preload("res://scripts/field_geometry.gd")
var failures: int=0

func check(value: bool, description: String) -> void:
    if not value:
        failures+=1
        push_error(description)
    else: print("PASS ",description)

func _initialize() -> void:
    var sim:=WarSim.new()
    sim.set_long_operation(true)
    sim.set_scenario(WarSim.TRAINING_SCENARIO)
    var sites:=sim.training_sites()
    _check_charge_terrain(sim, sites)
    for kind in ["평지","도로","숲","고지","습지","갈대밭","하천"]:
        check(sim.terrain_at(sites[kind])==kind,"survey location matches "+kind)
    var foot:=sim.find_unit(0)
    var rider:=sim.find_unit(2)
    check(sim.terrain_movement_percent(0,sites["습지"])==66 and sim.terrain_movement_percent(2,sites["습지"])==48,"wetland movement by troop type")
    for basin: Rect2 in Geometry.TRAINING_MARSHES:
        var edge:=Vector2(basin.end.x,basin.get_center().y)
        check(sim.terrain_at(edge-Vector2(2,0))=="습지" and sim.terrain_at(edge+Vector2(2,0))!="습지","wetland boundary")
    var strides: Dictionary={}
    for kind in ["평지","도로","숲","고지","습지","갈대밭"]:
        rider["pos"]=sites[kind]
        rider["goal"]=Vector2(sites[kind])+Vector2(70,0)
        rider["action"]="지정 위치 이동"
        rider["fatigue"]=0.0
        sim._move_unit(rider,0.1)
        var moved: float=Vector2(rider["pos"]).distance_to(sites[kind])
        strides[kind]=moved
        check(moved>0 and sim.terrain_at(rider["pos"])==kind,"unit advances on "+kind)
    check(strides["도로"]>strides["평지"] and strides["평지"]>strides["고지"] and strides["고지"]>strides["숲"] and strides["숲"]>strides["습지"],"actual cavalry movement follows the surveyed terrain costs")
    check(strides["고지"]>strides["갈대밭"] and strides["갈대밭"]>strides["숲"],"reeds slow cavalry less than woodland")
    check(sim.map_order_issue(0,"지역 사수",sites["습지"]).is_empty(),"passable wetland accepts a destination")
    check(not sim.map_order_issue(0,"지역 사수",sites["하천"]).is_empty(),"open water rejects a destination")
    for name in ["북측 교량","중앙 교량","남측 교량"]:
        var bridge: Vector2=sites[name]
        var goal:=bridge+Vector2(100,0)
        foot["pos"]=bridge-Vector2(100,0)
        foot["goal"]=goal
        foot["action"]="지정 위치 이동"
        foot["bridge_y"]=-1.0
        var correct: bool=sim.map_order_crossing(0,goal)==bridge.y and sim.terrain_at(bridge)=="교량"
        var touched: bool=false
        for tick in range(100):
            sim._move_unit(foot,0.1)
            var point: Vector2=foot["pos"]
            correct=correct and not sim.in_open_water(point)
            touched=touched or sim.terrain_at(point)=="교량"
            if point.distance_to(goal)<5.0: break
        check(correct and touched and Vector2(foot["pos"]).distance_to(goal)<5.0,"preview and unit cross safely at "+name)
    var gate: Rect2=sim.structures[0]["rect"]
    var bank:=gate.get_center()-Vector2(gate.size.x*0.5+15,0)
    check(sim._structure_move(foot,bank,gate.get_center())==bank,"intact enemy gate blocks entry")
    sim.turn=7
    sim.battle_time=WarSim.LONG_OBJECTIVE_OPEN
    for unit in sim.units:
        unit["pos"]=Vector2(100,100)
    foot["pos"]=sites["점령 거점"]
    sim._update_outposts(sim.capture_duration())
    sim._update_outposts(31.0)
    check(sim.outposts[0]["owner"]==0 and sim._objective_winner()==-1,"holding the eastern objective still requires opening the gate")
    foot["pos"]=bank
    for tick in range(350): sim._update_structures(0.1)
    check(sim.structures[0]["hp"]==0.0 and sim._structure_move(foot,bank,gate.get_center())==gate.get_center(),"destroyed gate opens")
    check(sim._objective_winner()==0,"holding the objective and opening the gate completes the exercise")
    var wall: Rect2=sim.structures[1]["rect"]
    check(is_equal_approx(wall.end.y,gate.position.y) and sim._structure_move(foot,wall.position-Vector2(20,0),wall.get_center())!=wall.get_center(),"palisade joins the gate and remains solid")
    var target:=sim.find_unit(3)
    target["pos"]=sites["숲"]
    foot["pos"]=Vector2(target["pos"])-Vector2(165,0)
    for ally in sim.units:
        if ally["side"]==0 and ally["id"]!=0: ally["pos"]=Vector2(40,40)
    sim.commanders[0]["pos"]=Vector2(35,35)
    for scout in sim.scouts: scout["pos"]=Vector2(30,30)
    check(sim.player_can_see(target["pos"]) and not FrontView.observes_unit(sim,target,true),"forest concealment shrinks detection distance")
    foot["pos"]=Vector2(target["pos"])-Vector2(45,0)
    check(FrontView.observes_unit(sim,target,true),"near observer reveals forest target")
    foot["pos"]=sites["고지"]
    var reach: float=200.0*(0.85+sim._effective_stat(foot,"intelligence")*0.002)*1.08
    check(sim.player_can_see(Vector2(foot["pos"])+Vector2(reach,0)),"high ground extends observation")
    sim.reset()
    check(sim.training_sites()==sites and sim.structures[0]["hp"]==sim.structures[0]["max_hp"],"range reset restores fixtures")
    var archer:=sim.find_unit(1)
    archer["pos"]=sites["보급기지"]
    archer["rations"]=30.0
    archer["ammo"]=20.0
    for i in range(41): sim._supply_logic(0.1)
    check(archer["supplied"] and archer["rations"]>30.0 and archer["ammo"]>20.0,"surveyed supply base replenishes both rations and arrows")
    for unit in sim.units:
        if unit["side"]==1: unit["routed"]=true
    sim.find_unit(0)["pos"]=sim.commanders[1]["pos"]
    sim._check_victory()
    check(not sim.finished,"reaching the enemy commander leaves the terrain exercise running")
    sim.battle_time=sim.scenario_limit
    sim._check_victory()
    check(sim.finished and sim.winning_side==1 and sim.result.contains("훈련 종료"),"unfinished exercise ends at its time limit")
    sim.set_scenario(0)
    check(sim.training_sites().is_empty() and sim.terrain_at(sites["습지"])!="습지","other scenarios have no training basins")
    _check_relief_selection()
    _check_relief_report()
    _check_bridge_approaches()
    _check_fields(sim)
    _check_reed_sight(sim)
    print("GUNRYAK_TERRAIN_RANGE_PASS" if failures==0 else "GUNRYAK_TERRAIN_RANGE_FAIL")
    quit(0 if failures==0 else 1)

func _check_charge_terrain(sim, sites: Dictionary) -> void:
    var rider: Dictionary = sim.find_unit(2)
    var foot: Dictionary = sim.find_unit(3)
    # Hold troop strength, approach distance, alignment and speed constant.
    # Each target stands on the actual training-map feature.
    var shocks := {}
    var stride := Vector2.RIGHT * 10.0
    var plain: Vector2 = sites["평지"]
    for key in ["평지", "도로", "고지", "북측 교량", "갈대밭", "숲", "습지"]:
        rider.pos = plain
        sim._update_charge(rider, Vector2.ZERO, 0.1, false)
        for tick in 10: sim._update_charge(rider, stride, 0.1, true)
        foot.pos = sites[key]
        rider.pos = foot.pos - Vector2.RIGHT * 20.0
        shocks[key] = sim._charge_impact(rider, foot)
    foot.pos = plain
    rider.pos = plain - Vector2.RIGHT * 20.0
    check(is_equal_approx(sim._charge_impact(rider, foot, sites["습지"]), shocks["습지"]), "a front rank in soft ground gets cover even with its standard on the plain")
    var road: float = shocks["도로"]
    check(road > 0.0 and is_equal_approx(shocks["평지"], road * 1.22), "full run on open ground adds 22 percent impact")
    check(is_equal_approx(shocks["고지"], road * 0.80) and is_equal_approx(shocks["북측 교량"], road * 0.60), "high ground and bridge restrict mounted impact")
    check(is_equal_approx(shocks["갈대밭"], road * 0.60) and is_equal_approx(shocks["숲"], road * 0.45) and is_equal_approx(shocks["습지"], road * 0.36), "sheltered ranks absorb the approach at the terrain boundary")
    check(sim.terrain_movement_percent(rider.id, sites["중앙 교량"]) == 78 and sim.terrain_movement_percent(foot.id, sites["중앙 교량"]) == 91, "a crossing slows mounted files more than foot")
    rider.pos = sites["고지"]
    sim._update_charge(rider, stride, 0.1, true)
    check(rider.open_run == 0.0 and rider.charge > 32.0, "leaving the plain loses the open-ground bonus")
    rider.pos = plain
    sim._update_charge(rider, -stride, 0.1, true)
    check(is_equal_approx(rider.open_run, 10.0) and is_equal_approx(rider.charge, 10.0), "turning the horse starts a fresh run")
    rider.pos = sites["습지"]
    sim._update_charge(rider, stride, 0.1, true)
    check(rider.charge == 0.0 and rider.open_run == 0.0, "soft ground breaks the run")
    print("GROUND_IMPACT ", shocks)
    sim.reset()
    sim.set_scenario(WarSim.TRAINING_SCENARIO)

func _check_fields(sim) -> void:
    var enemy_totals := [43700,43700,49160,43700,38100,38100]
    for scenario in range(6):
        sim.set_scenario(scenario)
        var valid: bool = sim.total_troops(0)==38000 and sim.total_troops(1)==enemy_totals[scenario]
        for unit in sim.units:
            valid = valid and unit["troops"]==unit["initial_troops"] and unit["troops"]<=WarSim.MAX_TROOPS
        check(valid and sim.command_ids(1).size()==10, "starting musters for "+sim.scenario_title)
        var sites: Dictionary = sim.field_survey_sites()
        for kind in ["습지","갈대밭","고지","숲"]:
            check(sim.terrain_at(sites[kind])==kind,"survey "+sim.scenario_title+" "+kind)
        for kind in ["습지","갈대밭"]:
            for bed: Rect2 in (sim.marshes if kind=="습지" else sim.reedbeds):
                var clear := true
                for i in range(16):
                    var offset := Vector2.from_angle(i*TAU/16.0)*bed.size*0.5
                    clear = clear and sim.terrain_at(bed.get_center()+offset*0.98)==kind
                    clear = clear and sim.terrain_at(bed.get_center()+offset*1.02)!=kind
                check(clear,"passable mapped boundary in "+sim.scenario_title+" "+kind)
    sim.reset()
    sim.set_scenario(0)
    check(sim.total_troops(1)==43700,"returning from training reapplies the field muster exactly once")

func _check_reed_sight(sim) -> void:
    sim.set_scenario(WarSim.TRAINING_SCENARIO)
    var foot: Dictionary = sim.find_unit(0)
    var target: Dictionary = sim.find_unit(3)
    for unit in sim.units:
        if unit["id"] not in [0,3]: unit["troops"]=0
    sim.commanders[0]["pos"]=Vector2(70,70)
    for scout in sim.scouts: scout["alive"]=false
    var bed: Vector2=sim.training_sites()["갈대밭"]
    var ranges: Array[Vector2i]=[]
    for target_pos: Vector2 in [bed+Vector2(0,130),bed]:
        target["pos"]=target_pos
        var reach := Vector2i.ZERO
        for distance in range(350,49,-1):
            foot["pos"]=target_pos-Vector2(distance,0)
            if reach.x==0 and not sim._nearest_visible_enemy(foot).is_empty(): reach.x=distance
            if reach.y==0 and FrontView.observes_unit(sim,target,true): reach.y=distance
        ranges.append(reach)
    print("DETECTION_RANGE AI/player plain ",ranges[0]," reeds ",ranges[1])
    check(ranges[0].x>ranges[1].x+40 and ranges[0].y>ranges[1].y+30 and ranges[1].y>75,"approaching a reedbed reveals its troops later in AI and player scouting")
    foot["pos"]=bed
    check(is_equal_approx(sim.terrain_sight_factor(bed),0.82) and sim.terrain_movement_percent(0,bed)==84 and sim.terrain_movement_percent(2,bed)==63,"reed survey matches observer and march modifiers")
    var travel: Array[float]=[]
    var cavalry: Dictionary=sim.find_unit(2)
    cavalry["troops"]=cavalry["initial_troops"]
    target["pos"]=Vector2(2480,1440)
    for tile in ["평지","갈대밭","습지"]:
        var center: Vector2=sim.training_sites()[tile]
        cavalry["pos"]=center-Vector2(30,0)
        cavalry["goal"]=center+Vector2(30,0)
        cavalry["action"]="지정 위치 이동"
        cavalry["fatigue"]=0.0
        var steps := 0
        while steps<100 and Vector2(cavalry["pos"]).distance_to(cavalry["goal"])>2.0:
            sim._move_unit(cavalry,0.1)
            steps+=1
        check(steps<100,"cavalry reaches the end of the "+tile+" course")
        travel.append(steps*0.1*sim.operation_scale())
    print("CAVALRY_60_WORLD_OPERATION_SECONDS plain/reeds/marsh ",travel)
    check(travel[0]<travel[1] and travel[1]<travel[2],"same 60-unit march takes longer in reeds and marsh")
    var scout: Dictionary=sim.scouts[0]
    scout["alive"]=true
    scout["report_timer"]=0.0
    target["pos"]=bed
    scout["pos"]=bed-Vector2(160,0)
    sim._update_scouts(0.0)
    check(scout["reports"]==0,"scout cannot report distant concealed troops")
    scout["pos"]=bed-Vector2(70,0)
    sim._update_scouts(0.0)
    check(scout["reports"]==1,"scout approaching reedbed sends an actual report")

# The existing crossing drill starts aligned with each deck. This replay starts
# at the water's edge, where relief units can be pushed while their target moves.
func _check_bridge_approaches() -> void:
    var sim := WarSim.new()
    sim.set_long_operation(true)
    sim.set_scenario(2)
    var unit := sim.find_unit(7)
    for other in sim.units:
        if other["id"] != unit["id"]: other["troops"] = 0.0
    for bridge: float in [390.0, 850.0, 1300.0]:
        for bank: int in [-1, 1]:
            for offset: float in [-108.0, 108.0]:
                var y := bridge + offset
                var shore := Vector2(sim.river_x(y) + bank * 28.0, y)
                var goal := Vector2(sim.river_x(bridge) - bank * 120.0, bridge)
                unit["pos"] = shore
                unit["goal"] = goal
                unit["action"] = "긴급 지원"
                unit["fatigue"] = 0.0
                unit["bridge_y"] = -1.0
                unit["bridge_crossings"] = 0
                sim._committed_bridge_route(unit, shore, goal)
                var preview := sim.committed_route_preview(unit)
                var entry := Vector2(sim.river_x(bridge) + bank * 64.0, bridge)
                var entered := false
                var safe := true
                for tick in range(200):
                    sim._move_unit(unit, 0.1)
                    var p: Vector2 = unit["pos"]
                    entered = entered or (sim.on_river_channel(p) and absf(p.y - bridge) <= 38.0)
                    safe = safe and not sim.in_open_water(p)
                    if p.distance_to(goal) < 3.0: break
                var reached := Vector2(unit["pos"]).distance_to(goal) < 3.0
                check(preview[0] == entry and entered and safe and reached and unit["bridge_crossings"] == 1,
                    "relief arrives via deck from bank %d at y %.0f, bridge %.0f" % [bank, y, bridge])

            var y := bridge + 108.0
            var shore := Vector2(sim.river_x(y) + bank * 28.0, y)
            var ally := shore + Vector2(bank * 85.0, 0)
            var rider := sim._field_rider(shore, 0, -10)
            sim._committed_bridge_route(rider, shore, Vector2(sim.river_x(bridge) - bank * 120.0, bridge))
            var arrived := false
            for tick in range(10):
                arrived = sim._advance_rider(rider, ally, 0.1)
                if arrived: break
            check(arrived and rider["bridge_y"] < 0 and rider["bridge_crossings"] == 0,
                "rider drops obsolete bridge when recipient returns to bank %d, bridge %.0f" % [bank, bridge])

            # A unit pushed beyond the deck on the exit shore has already landed.
            rider = sim._field_rider(shore, 0, -10)
            rider["bridge_y"] = bridge
            rider["bridge_bank"] = bank
            sim._advance_rider(rider, ally, 0.1)
            check(rider["pos"] == shore.move_toward(ally, 15.0) and rider["bridge_crossings"] == 1
                and rider["bridge_y"] < 0, "resume mission after displacement onto exit bank %d, bridge %.0f" % [bank, bridge])

            # Turn the recipient around just after the rider has entered the deck.
            var deck := Vector2(sim.river_x(bridge) + bank * 9.0, bridge)
            rider = sim._field_rider(deck, 0, -10)
            rider["bridge_y"] = bridge
            rider["bridge_bank"] = -bank
            var furthest := 0.0
            arrived = false
            for tick in range(60):
                arrived = sim._advance_rider(rider, ally, 0.1)
                var pos: Vector2 = rider["pos"]
                furthest = maxf(furthest, (pos.x - sim.river_x(pos.y)) * -bank)
                if arrived: break
            check(arrived and furthest >= 55.0 and rider["bridge_crossings"] == 2,
                "rider clears occupied deck before returning, bank %d bridge %.0f" % [bank, bridge])

    for side: int in [0, 1]:
        var helper := sim.find_unit(7 if side == 0 else 3)
        var ally := sim.find_unit(2 if side == 0 else 4)
        helper["troops"] = helper["initial_troops"]
        ally["troops"] = ally["initial_troops"]
        helper["tactical_order"] = "지원"
        helper["tactical_until"] = sim.battle_time + 24.0
        helper["tactical_target"] = ally["id"]
        for bank: int in [-1, 1]:
            var y := 1408.0
            var shore := Vector2(sim.river_x(y) + bank * 28.0, y)
            ally["pos"] = shore
            var order := sim._tactical_decision(helper, {}, "대기", "", helper["pos"], INF, 1.0)
            var slot: Vector2 = order["goal"]
            check(order["action"] == "긴급 지원" and not sim.in_open_water(slot)
                and (slot.x - sim.river_x(slot.y)) * bank > 0.0 and is_equal_approx(slot.distance_to(shore), 32.0),
                "support slot stays beside the recipient on dry ground, side %d bank %d" % [side, bank])

func _check_relief_report() -> void:
    var sim := WarSim.new()
    sim.set_long_operation(true)
    sim.set_scenario(WarSim.TRAINING_SCENARIO)
    var actor := sim.find_unit(7)
    var ally := sim.find_unit(2)
    var report := {"unit_id": ally["id"], "executor": actor["id"], "response": "지원",
        "status": "명령 수령", "until": 24.0}
    sim.situation_reports.append(report)
    actor["tactical_target"] = ally["id"]
    actor["tactical_until"] = report["until"]
    actor["action"] = "긴급 지원"
    var shore := Vector2(sim.river_x(1420.0), 1420.0)
    actor["pos"] = shore + Vector2(29, 0)
    ally["pos"] = shore - Vector2(29, 0)
    sim._update_response_outcomes()
    check(report["status"] == "실행 중" and not report.has("joined_at"), "departing across open water does not confirm support arrival")
    var gate: Rect2 = sim.structures[0]["rect"]
    actor["pos"] = Vector2(gate.end.x + 2.0, gate.get_center().y)
    ally["pos"] = Vector2(gate.position.x - 2.0, gate.get_center().y)
    sim._update_response_outcomes()
    check(not report.has("joined_at"), "an intact enemy gate separates the two units")
    sim.structures[0]["hp"] = 0
    sim.battle_time = 12.0
    sim._update_response_outcomes()
    ally["pos"] = shore
    sim.battle_time = 25.0
    sim._update_response_outcomes()
    check(report.get("joined_at", -1.0) == 12.0 and report["status"] == "실행 종료",
        "first physical arrival survives separation and order expiry")

func _check_relief_selection() -> void:
    var sim := WarSim.new()
    sim.set_long_operation(true)
    sim.set_scenario(2)
    var sender := sim.find_unit(7)
    var across := sim.find_unit(2)
    var inland := sim.find_unit(0)
    for unit in sim.units:
        if unit["id"] not in [7, 2, 0]: unit["troops"] = 0.0
    var y := 1070.0
    sender["pos"] = Vector2(sim.river_x(y) + 29.0, y)
    across["pos"] = Vector2(sim.river_x(y) - 29.0, y)
    inland["pos"] = sender["pos"] + Vector2(120, 0)
    inland["morale"] = across["morale"]
    var report := {"id": 400, "side": 0, "unit_id": sender["id"]}
    sim._send_relief_request(sender, report)
    check(sim.relief_riders.back()["recipient"] == inland["id"] and sim.support_for_report(sender) == inland,
        "local messenger and command desk favor the shorter passable route")
    inland["pos"] = sender["pos"] + Vector2(600, 0)
    sim._send_relief_request(sender, report)
    check(sim.relief_riders.back()["recipient"] == across["id"], "an across-river neighbor can still receive the request")
