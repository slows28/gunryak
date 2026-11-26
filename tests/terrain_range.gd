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
    sim._supply_logic(1.0)
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
    _check_fields(sim)
    _check_reed_sight(sim)
    print("GUNRYAK_TERRAIN_RANGE_PASS" if failures==0 else "GUNRYAK_TERRAIN_RANGE_FAIL")
    quit(0 if failures==0 else 1)

func _check_fields(sim) -> void:
    var enemy_totals := [26400,26400,29240,26400,23200,23200]
    for scenario in range(6):
        sim.set_scenario(scenario)
        var valid: bool = sim.total_troops(0)==23500 and sim.total_troops(1)==enemy_totals[scenario]
        for unit in sim.units:
            valid = valid and unit["troops"]==unit["initial_troops"] and unit["troops"]<=WarSim.MAX_TROOPS
        check(valid and sim.command_ids(1).size()==6, "starting musters for "+sim.scenario_title)
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
    check(sim.total_troops(1)==26400,"returning from training reapplies the field muster exactly once")

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
