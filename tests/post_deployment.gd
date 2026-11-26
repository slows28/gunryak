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
    check(sim.place_post("보급기지",depot) and sim.bases[0]["target"]==depot,"select a fixed depot site")
    check(sim.commanders[0]["pos"]==home_pos and sim.bases[1]["pos"]==enemy_pos,"depot changes only the friendly base")
    check(sim.place_post("책사",advisor) and sim.commanders[0]["pos"]==advisor and sim.commanders[0]["goal"]==advisor,"independent commander origin and goal")
    check(not sim.place_post("보급기지",Vector2(809,659)) and not sim.place_post("책사",sim.field_size-Vector2(50,50)) and not sim.place_post("책사",Vector2.INF),"wetland, enemy deployment and non-finite locations rejected")
    check(sim.bases[0]["pos"]==depot and sim.commanders[0]["pos"]==advisor,"invalid placements preserve prior positions")
    sim.start()
    var base: Dictionary=sim.bases[0]
    check(base["state"]=="설치" and not sim._has_supply(0,depot),"committed site builds at launch and withholds rations")
    check(not sim.place_post("보급기지",Vector2(488,770)) and not sim.place_post("책사",depot),"no mid-battle placement")
    sim.paused=true
    sim.step(0.1)
    check(base["build_timer"]==sim.BASE_BUILD_SECONDS,"construction follows the simulation clock")
    sim.paused=false
    for tick in range(31): sim.step(0.1)
    check(base["state"]=="가동" and base["build_timer"]==0.0 and sim._has_supply(0,depot),"completed depot actually opens supply")
    sim.battle_time=95.0
    sim._supply_logic(0.1)
    check(base["pos"]==depot and base["state"]=="가동","manual depot stays where the player built it")
    sim.reposition_commander(true)
    sim._move_commanders(0.5)
    sim.reposition_commander(false)
    sim._move_commanders(1.0)
    check(sim.commanders[0]["pos"]==advisor,"return to HQ uses selected origin")
    sim.turn=6
    check(sim.request_order(0,"공격","현장 판단") and sim.couriers.back()["pos"]==advisor,"real turn-six courier originates from the chosen advisor")
    for u in sim.units:
        if u["side"]==0: u["pos"]=depot+Vector2.RIGHT*(sim.supply_radius()+10.0)
    var first:=sim.find_unit(0)
    var archer:=sim.find_unit(1)
    for u in [first,archer]:
        u["pos"]=depot
        u["rations"]=40.0
    archer["ammo"]=40.0
    base["stock"]=0.20
    sim.set_supply_priority(1,2)
    sim._supply_logic(0.1)
    check(archer["rations"]>40 and archer["ammo"]>40 and first["rations"]<40.0,"scarce stock goes to the priority archer before the ordinary unit")
    sim.reset()
    check(sim.bases[0]["state"]=="가동" and not sim.commanders[0].has("home"),"new battle clears manually placed posts")
    if failures==0: print("GUNRYAK_POST_DEPLOYMENT_PASS")
    quit(1 if failures else 0)
