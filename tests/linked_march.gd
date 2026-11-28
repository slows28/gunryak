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
    _check_opening_screen()
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
    sim.turn=7
    sim.battle_time=6.0*sim.turn_duration()
    check(sim.issue_map_order(2,"지정 위치 이동",courier_target,-1) and sim.find_unit(2)["assigned_link"]==1,"a travelling courier leaves the existing link active")
    sim.couriers.back()["pos"]=sim.find_unit(2)["pos"]
    sim.step(0.1)
    check(sim.find_unit(2)["assigned_link"]==-1 and not sim.march_plans.has(2),"delivery removes the old link on the same movement tick")
    check(not sim.issue_map_order(2,"지정 위치 이동",courier_target,0),"a second letter must await the next command day")
    sim.turn=9
    sim.battle_time=8.0*sim.turn_duration()
    check(sim.issue_map_order(2,"지정 위치 이동",courier_target,0),"new linked march can be ordered on day nine")
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
    var deck:=Vector2(sim.river_x(by),by)
    company(sim,deck-Vector2(290,0),Vector2.RIGHT)
    sim.find_unit(0)["order_destination"]=deck
    var on_land: bool=true
    for tick in range(420):
        sim.step(0.1)
        for id in [0,1,2]: on_land=on_land and not sim.in_open_water(sim.find_unit(id)["pos"])
    check(on_land and Vector2(sim.find_unit(0)["pos"]).distance_to(deck)<8 and sim.march_plans.get(0,{}).get("phase","")=="대형 유지","a bridge can be the final order location without the company overshooting the deck")
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
    sim=field()
    position(sim,0,Vector2(630,220))
    position(sim,1,Vector2(630,1400))
    target=Vector2(1650,850)
    var solo: float=sim.map_order_crossing(0,target)
    var preview: Dictionary=sim.LinkedMarch.preview(sim,sim.find_unit(1),0,target)
    sim.issue_map_order(1,"지정 위치 이동",target,0)
    sim.start()
    sim.step(0.1)
    check(preview["bridge"]!=solo and sim.march_plans[0]["bridge"]==preview["bridge"] and sim.march_plans[1]["bridge"]==preview["bridge"],"distant linked corps share the issuing guide's previewed crossing")
    sim.reset()
    check(sim.march_plans.is_empty(),"new deployment clears the previous march")
    print("GUNRYAK_LINKED_MARCH_PASS" if failures==0 else "GUNRYAK_LINKED_MARCH_FAIL")
    quit(0 if failures==0 else 1)

static func stage_opening_screen(sim) -> void:
    # The rear starts ahead of the infantry on the same unedited mission.
    for u in sim.units:
        if u["id"] not in [0,6,3]: u["troops"]=0.0
    var foot: Dictionary=sim.find_unit(0)
    var bow: Dictionary=sim.find_unit(6)
    var foe: Dictionary=sim.find_unit(3)
    foot["pos"]=Vector2(505,465)
    bow["pos"]=Vector2(610,542)
    foe["pos"]=Vector2(2450,440)
    foe["ai_cooldown"]=10000.0
    for u in [foot,bow,foe]: u["goal"]=u["pos"]
    sim.enemy_strategy_enabled=false

static func introduce_screen_contact(sim) -> void:
    var foe: Dictionary=sim.find_unit(3)
    foe["pos"]=Vector2(1010,420)
    foe["goal"]=foe["pos"]

func _check_opening_screen() -> void:
    var sim:=WarSim.new()
    sim.set_long_operation(true)
    sim.set_scenario(WarSim.TRAINING_SCENARIO)
    stage_opening_screen(sim)
    sim.start()
    var foot:=sim.find_unit(0)
    var bow:=sim.find_unit(6)
    var foe:=sim.find_unit(3)
    var stationary_shots:=0
    var screened:=0
    for tick in range(400):
        if tick==70: introduce_screen_contact(sim)
        var prior_shots: float=bow["shots_used"]
        sim.step(0.1)
        if tick==0:
            check(sim.march_plans[6]["role"]=="후열" and sim.march_plans[0]["phase"]=="대형 집결","unedited corps with a common objective form up on deployment")
        if tick==40:
            check(Vector2(foot["pos"]).distance_to(Vector2(505,465))<6,"front holds its ground while the archer passes outside its formation")
        if tick<70: continue
        var axis:=Vector2(bow["pos"]).direction_to(foe["pos"])
        var offset: Vector2=foot["pos"]-bow["pos"]
        if offset.dot(axis)>0 and offset.dot(axis)<Vector2(bow["pos"]).distance_to(foe["pos"]) and absf(offset.cross(axis))<45:
            screened+=1
        if bow["shots_used"]>prior_shots and bow["motion_speed"]<2: stationary_shots+=1
    check(screened>=290 and stationary_shots>=150,"archer fires from a settled rear rank with infantry between it and the opponent")
    print("OPENING_LINE samples=330 guarded=",screened," stationary_volleys_steps=",stationary_shots)
    # A sidestep by the front rank must not send the same escort to its opposite flank.
    bow["mission"]="전열 엄호"
    bow["assigned_link"]=foot["id"]
    foot["facing"]=Vector2.UP
    var first:=sim._coordinated_order(bow,foe,"진격","",foot["pos"])
    foot["facing"]=Vector2.DOWN
    var second:=sim._coordinated_order(bow,foe,"진격","",foot["pos"])
    check(Vector2(first["goal"]).distance_to(second["goal"])<1 and Vector2(foot["pos"]).direction_to(foe["pos"]).dot(Vector2(second["goal"])-foot["pos"])<0,"escort station follows the visible front, independent of the guard's turning animation")
    foot["pos"]=Vector2(600,520)
    bow["pos"]=Vector2(674,510)
    foe["pos"]=Vector2(760,510)
    var rescue:=sim._screen_station(foot,foe,"교전")
    check(rescue.get("action")=="궁병 보호" and Vector2(rescue["goal"]).x>bow["pos"].x and Vector2(rescue["goal"]).x<foe["pos"].x,"infantry moves between the exposed rear rank and its observed opponent")
    foot["tactical_until"]=sim.battle_time+8
    check(sim._screen_station(foot,foe,"방어").is_empty(),"active courier instruction takes priority over local screening")
    sim._reset_cooperation(foot,-1)
    check(not bow.has("opening_screen"),"new orders release the opening deployment")
