extends SceneTree
const WarSim=preload("res://scripts/war_sim.gd")
var failures: int=0

func check(condition: bool, label: String) -> void:
    if condition: print("PASS ",label)
    else:
        failures+=1
        push_error(label)

func field():
    var sim:=WarSim.new()
    sim.set_long_operation(true)
    sim.set_scenario(WarSim.TRAINING_SCENARIO)
    sim.enemy_strategy_enabled=false
    for u in sim.units:
        if u["id"] not in [0,1,2,3]: u["troops"]=0.0
        if u["id"]==3:
            u["pos"]=Vector2(2500,1510)
            u["goal"]=u["pos"]
            u["ai_cooldown"]=10000.0
    return sim

func position(sim, id: int, p: Vector2) -> void:
    var u: Dictionary=sim.find_unit(id)
    u["pos"]=p
    u["goal"]=p

func company(sim, origin: Vector2, direction: Vector2) -> void:
    var right:=Vector2(-direction.y,direction.x)
    position(sim,0,origin)
    position(sim,1,origin-direction*107.0)
    position(sim,2,origin-direction*45.0+right*105.0)
    sim.select_unit_mission(2,"전열 엄호","현장 판단",1)
    sim.select_unit_mission(1,"전열 엄호","현장 판단",0)
    sim.issue_map_order(0,"지정 위치 이동",origin+direction*350.0)
    sim.start()

func _initialize() -> void:
    for heading: Vector2 in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP,Vector2(1,1).normalized()]:
        var sim=field()
        company(sim,Vector2(625,700),heading)
        var correct: bool=true
        for tick in range(26):
            sim.step(0.1)
            if sim.march_plans.size()!=3:
                correct=false
                break
            var front: Dictionary=sim.find_unit(0)
            var bow: Dictionary=sim.find_unit(1)
            var horse: Dictionary=sim.find_unit(2)
            var right:=Vector2(-heading.y,heading.x)
            correct=correct and sim.march_plans[0]["phase"]=="연계 행군" and Vector2(front["facing"]).dot(heading)>0.99
            correct=correct and (Vector2(front["pos"])-Vector2(bow["pos"])).dot(heading)>90 and (Vector2(horse["pos"])-Vector2(front["pos"])).dot(right)>95
            for u: Dictionary in [front,bow,horse]:
                correct=correct and absf(u["motion_speed"]-sim.march_plans[0]["pace"])<0.02
        check(correct,"three linked corps keep the slowest actual pace and rotated ranks toward "+str(heading))
    var sim=field()
    var origin:=Vector2(650,510)
    company(sim,origin,Vector2.DOWN)
    position(sim,2,origin+Vector2(-300,-140))
    sim.step(0.1)
    check(sim.march_plans[0]["phase"]=="대형 집결" and sim.find_unit(0)["pos"]==origin and sim.find_unit(2)["motion_speed"]>0,"distant wing walks into assembly and guide waits")
    for tick in range(200):
        sim.step(0.1)
        if sim.march_plans.get(0,{}).get("phase","")=="연계 행군": break
    check(sim.march_plans.get(0,{}).get("phase","")=="연계 행군","company resumes without moving a corps instantly")
    sim.find_unit(2)["routed"]=true
    sim.step(0.1)
    check(not sim.march_plans.has(2) and sim.march_plans.has(0),"rout releases the wing while the remaining pair stays together")
    sim=field()
    var marsh: Vector2=sim.training_sites()["습지"]
    company(sim,marsh+Vector2(45,-105),Vector2.RIGHT)
    sim.find_unit(2)["fatigue"]=95
    sim.find_unit(2)["next_formation"]="방진"
    sim.find_unit(2)["form_remaining"]=10.0
    for u in sim.units: u["ai_cooldown"]=99.0
    sim.step(0.1)
    check(sim.terrain_at(sim.find_unit(2)["pos"])=="습지" and sim.march_plans[0]["slowest"]==sim.find_unit(2)["name"],"fatigued cavalry reforming in marsh sets the pace even for infantry")
    sim=field()
    company(sim,Vector2(600,750),Vector2.RIGHT)
    sim.step(0.1)
    var courier_target:=Vector2(600,1250)
    sim.turn=6
    sim.battle_time=75.0
    check(sim.issue_map_order(2,"지정 위치 이동",courier_target,-1) and sim.find_unit(2)["assigned_link"]==1,"a travelling courier leaves the existing link active")
    sim.couriers.back()["pos"]=sim.find_unit(2)["pos"]
    sim.step(0.1)
    check(sim.find_unit(2)["assigned_link"]==-1 and not sim.march_plans.has(2),"delivery removes the old link on the same movement tick")
    check(sim.issue_map_order(2,"지정 위치 이동",courier_target,0),"new linked march can be ordered during battle")
    sim.couriers.back()["pos"]=sim.find_unit(2)["pos"]
    sim.step(0.1)
    check(sim.march_plans.has(2) and sim.march_plans[0]["forward"].dot(Vector2.DOWN)>0.9,"delivered destination rotates the connected group")
    sim.find_unit(0)["troops"]=0.0
    sim.step(0.1)
    check(sim.march_plans.is_empty(),"loss of the named anchor breaks its links")
    sim=field()
    var by: float=850
    var start:=Vector2(sim.river_x(by)-265,by)
    company(sim,start,Vector2.RIGHT)
    var target:=Vector2(sim.river_x(by)+350,by+100)
    sim.find_unit(0)["order_destination"]=target
    var wet: bool=false
    var on_bridge: Dictionary={}
    var regrouped: bool=false
    for tick in range(1200):
        sim.step(0.1)
        for id in [0,1,2]:
            var point: Vector2=sim.find_unit(id)["pos"]
            wet=wet or sim.in_open_water(point)
            if sim.terrain_at(point)=="교량": on_bridge[id]=absf(point.y-by)<40
        if on_bridge.size()==3 and sim.march_plans.get(0,{}).get("phase","")=="연계 행군" and Vector2(sim.find_unit(0)["pos"]).distance_to(target)<12:
            regrouped=true
            break
    check(on_bridge.size()==3 and not on_bridge.values().has(false) and not wet,"all three corps use the same actual bridge and remain on land")
    check(regrouped,"marching ranks reform beyond the bridge and reach the ordered objective")
    sim=field()
    position(sim,0,Vector2(600,520))
    position(sim,1,Vector2(490,520))
    sim.select_unit_mission(1,"전열 엄호","현장 판단")
    sim.start()
    sim.step(0.1)
    check(sim.find_unit(1)["link_id"]==0 and sim.march_plans.has(0) and sim.march_plans.has(1),"automatic escort uses its actual selected partner")
    position(sim,3,sim.find_unit(0)["pos"]+Vector2(120,0))
    sim.step(0.1)
    check(not sim.march_plans.has(0),"a locally observed engagement restores autonomous combat movement")
    sim=field()
    sim.find_unit(1)["type"]="보병"
    origin=Vector2(620,570)
    position(sim,0,origin)
    position(sim,1,origin+Vector2(0,90))
    sim.select_unit_mission(1,"전열 엄호","현장 판단",0)
    sim.issue_map_order(0,"지정 위치 이동",origin+Vector2(120,0),1)
    sim.start()
    for tick in range(125): sim.step(0.1)
    check(sim.march_plans.size()==2 and sim.march_plans[1]["role"]=="나란히" and sim.march_plans[0]["phase"]=="대형 유지","mutually linked infantry arrive abreast and hold their facing")
    sim.reset()
    check(sim.march_plans.is_empty(),"new deployment clears the previous march")
    print("GUNRYAK_LINKED_MARCH_PASS" if failures==0 else "GUNRYAK_LINKED_MARCH_FAIL")
    quit(0 if failures==0 else 1)
