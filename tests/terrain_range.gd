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
    for kind in ["평지","도로","숲","고지","습지","하천"]:
        check(sim.terrain_at(sites[kind])==kind,"survey location matches "+kind)
    var foot:=sim.find_unit(0)
    var rider:=sim.find_unit(2)
    check(sim.terrain_movement_percent(0,sites["습지"])==66 and sim.terrain_movement_percent(2,sites["습지"])==48,"wetland movement by troop type")
    for basin: Rect2 in Geometry.TRAINING_MARSHES:
        var edge:=Vector2(basin.end.x,basin.get_center().y)
        check(sim.terrain_at(edge-Vector2(2,0))=="습지" and sim.terrain_at(edge+Vector2(2,0))!="습지","wetland boundary")
    var strides: Dictionary={}
    for kind in ["평지","도로","숲","고지","습지"]:
        rider["pos"]=sites[kind]
        rider["goal"]=Vector2(sites[kind])+Vector2(70,0)
        rider["action"]="지정 위치 이동"
        rider["fatigue"]=0.0
        sim._move_unit(rider,0.1)
        var moved: float=Vector2(rider["pos"]).distance_to(sites[kind])
        strides[kind]=moved
        check(moved>0 and sim.terrain_at(rider["pos"])==kind,"unit advances on "+kind)
    check(strides["도로"]>strides["평지"] and strides["평지"]>strides["고지"] and strides["고지"]>strides["숲"] and strides["숲"]>strides["습지"],"actual cavalry movement follows the surveyed terrain costs")
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
    print("GUNRYAK_TERRAIN_RANGE_PASS" if failures==0 else "GUNRYAK_TERRAIN_RANGE_FAIL")
    quit(0 if failures==0 else 1)
