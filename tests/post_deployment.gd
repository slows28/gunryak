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
    sim._supply_logic(0.1)
    check(archer["rations"]>40 and archer["ammo"]>40 and first["rations"]==archer["rations"],"all armies inside one radius replenish simultaneously")
    _check_network()
    sim.reset()
    check(sim.bases[0]["state"]=="가동" and not sim.commanders[0].has("home"),"new battle clears manually placed posts")
    if failures==0: print("GUNRYAK_POST_DEPLOYMENT_PASS")
    quit(1 if failures else 0)

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
    var next:=origin+Vector2.DOWN*(s.supply_radius()+28.0)
    blue["pos"]=next
    blue["routed"]=true
    s._extend_supply(0)
    check(s.bases.size()==2,"rout does not construct a forward camp")
    blue["routed"]=false
    s._extend_supply(0)
    var post: Dictionary=s.bases.back()
    check(s.bases.size()==3 and post["pos"]==next and home["pos"]==origin,"southbound march creates another base without moving the original")
    s._extend_supply(0)
    check(s.bases.size()==3 and not s._has_supply(0,next),"unfinished post does not supply or spawn duplicates")
    for tick in range(31): s._supply_logic(0.1)
    check(s._has_supply(0,next) and s._has_supply(0,origin),"original and forward sources work independently")
    blue["pos"]=origin.lerp(next,0.5)
    blue["rations"]=30.0
    s._supply_logic(1.0)
    check(is_equal_approx(blue["rations"],32.5),"overlapping radii grant one refill")
    check(s._has_supply(0,origin+Vector2.LEFT*s.supply_radius()) and not s._has_supply(0,origin+Vector2.LEFT*(s.supply_radius()+0.01)),"coverage boundary is inclusive and finite")
    red["pos"]=next
    s._supply_logic(1.0)
    check(post["alive"] and s.raid_seconds_left(post)==20,"one physical raider has twenty operation seconds left after four")
    reserve["pos"]=next
    s._supply_logic(0.5)
    check(s.raid_seconds_left(post)==8,"second raider speeds up remaining work")
    blue["pos"]=next
    s._supply_logic(0.1)
    check(post["raid_work"]==0.0 and post["alive"],"arriving defender interrupts destruction")
    blue["pos"]=origin
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
    check(post["alive"] and s._has_supply(0,next),"attacked camp supplies until the actual destruction tick")
    s._supply_logic(0.1)
    check(not post["alive"] and not s._has_supply(0,next) and s._has_supply(0,origin),"only destroyed forward radius disappears")
    reserve["troops"]=0.0
    var red_origin: Vector2=s.bases[1]["pos"]
    red["supply_mark"]=red_origin
    red["pos"]=red_origin+Vector2.LEFT*(s.supply_radius()+45)
    s._extend_supply(1)
    check(s.bases.back()["side"]==1 and s.bases.back()["pos"]==red["pos"],"opposing march builds westward by the same rule")
