extends SceneTree
const Sim=preload("res://scripts/war_sim.gd")
const Field=preload("res://scripts/northern_field.gd")
var errors:=0

func check(value: bool,message: String) -> void:
    if not value:
        errors+=1
        push_error(message)

func _initialize() -> void:
    var sim:=Sim.new()
    sim.set_long_operation(true)
    sim.tactical_enabled=true
    Field.deploy(sim,11)
    var site:=Vector2(1780,715)
    sim.outposts[0].pos=site
    for u in sim.units:
        u.pos=Vector2(320,460) if u.side==0 else Vector2(2440,500)
    var attackers:=sim.command_ids(0).slice(0,4)
    var defenders:=sim.command_ids(1).slice(0,5)
    for i in defenders.size():
        var u:=sim.find_unit(defenders[i])
        u.merge({"pos":site+Vector2(12,10*i),"type":"보병" if i!=1 else "궁병","mission":"중앙 진격","has_destination":false,"defense_set":false,"reserve":false,"routed":false,"morale":90,"cohesion":90,"rations":85},true)
    var guard:=sim.find_unit(defenders[3])
    guard.mission="본진 방어"
    var reserve:=sim.find_unit(defenders[4])
    reserve.pos=site+Vector2(300,0)
    for i in attackers.size():
        var u:=sim.find_unit(attackers[i])
        u.pos=site+Vector2(-42,i*12)
        u.reserve=false
        u.routed=false
        u.order_destination=site
    var fourth:=sim.find_unit(attackers[3])
    fourth.pos=Vector2(450,700)
    for t in [0,8]:
        sim.battle_time=t
        Field.review_pressure(sim)
    check(not sim.find_unit(defenders[0]).has("post_sighting"),"hidden fourth formation cannot count from its orders")
    fourth.pos=site+Vector2(-35,30)
    fourth.parent_id=attackers[0]
    sim.battle_time=16
    Field.review_pressure(sim)
    check(not sim.find_unit(defenders[0]).has("post_sighting"),"a detachment cannot count as another army")
    fourth.erase("parent_id")
    sim.battle_time=24
    Field.review_pressure(sim)
    check(sim.find_unit(defenders[0]).has("post_sighting") and sim.relief_riders.is_empty(),"first confirmed sighting only")
    sim.battle_time=32
    Field.review_pressure(sim)
    var watchers:=sim.units.filter(func(u): return u.has("post_watch"))
    check(watchers.size()==2 and not guard.has("post_watch"),"two local stations preserve the HQ guard")
    for u in watchers:
        check(u.mission=="중앙 진격" and u.post_watch.count==4,"temporary duty preserves the assigned mission")
    check(sim.relief_riders.size()==1 and reserve.tactical_order=="","a physical request leaves the post")
    if sim.relief_riders.size()==1:
        var request: Dictionary=sim.relief_riders.front()
        check(request.recipient==reserve.id,"request routed to the available field formation")
        reserve.mission="본진 방어"
        for tick in range(30): sim._move_relief_riders(0.1)
        check(request.get("returning",false) and reserve.tactical_order=="","new HQ duty takes priority at delivery")
    for id in attackers: sim.find_unit(id).pos=Vector2(430,520)
    sim.battle_time=40
    Field.review_pressure(sim)
    check(sim.units.any(func(u): return u.has("post_watch")),"brief loss of sight does not erase the last observed station")
    sim.battle_time=50
    Field.review_pressure(sim)
    check(not sim.units.any(func(u): return u.has("post_watch")),"stale positions do not track unseen attackers")
    print("GUNRYAK_PRESSURE_PASS" if errors==0 else "GUNRYAK_PRESSURE_FAIL")
    quit(0 if errors==0 else 1)
