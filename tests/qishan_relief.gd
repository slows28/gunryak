extends SceneTree
## Replay a real hit on a stationed Guan Xing, then replay the full opening
## with all twelve received orders and independently clicked central pins.
const War = preload("res://scripts/war_sim.gd")
const North = preload("res://scripts/northern_campaign.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
    if not ok:
        failures+=1
        push_error(message)

func field():
    var sim := War.new()
    sim.set_long_operation(true)
    sim.tactical_enabled=true
    var campaign := North.new()
    check(campaign.prepare(1,sim),"prepare Qishan")
    sim.rng.seed=137
    return sim

func officer(sim, name_: String) -> Dictionary:
    for u in sim.units:
        if u.name==name_: return u
    return {}

func controlled_contact(mixed: bool) -> void:
    var sim=field()
    var guan=officer(sim,"관흥")
    var foot=officer(sim,"왕평")
    var bow=officer(sim,"마속")
    var reserve=officer(sim,"장익")
    var foe=sim.find_unit(sim.command_ids(1)[0])
    var pin:=Vector2(780,780)
    for u in sim.units:
        if u.id not in [guan.id,foot.id,bow.id,reserve.id,foe.id]: u.troops=0.0
        u.ai_cooldown=1000.0
    for u in [guan,foot,bow,reserve]:
        u.pos=pin-Vector2(320,0)
        check(sim.issue_map_order(u.id,"예비 대기" if u==reserve else ("지역 사수" if mixed and u==foot else "지정 위치 이동"),
            pin+Vector2(8,0) if mixed and u==foot else pin),"issue distinct map clicks")
    sim.start()
    check(guan.get("rally_station",{}).get("count",0)==3,"adjacent move and hold orders share ground, reserve keeps its post")
    if not guan.has("rally_station"): return
    var ap: Vector2=guan.rally_station.point
    for u in [guan,foot,bow]:
        if not u.has("rally_station"): return
        u.pos=u.rally_station.point
        u.goal=u.pos
    # The first arrival holds the flank. An infantry file is still approaching
    # its post. Neither file starts in contact with the attacker.
    foot.pos=ap+Vector2(-66,-72)
    bow.pos=ap+Vector2(-116,-46)
    foe.pos=ap+Vector2(20,1)
    foe.goal=foe.pos
    foe.facing=Vector2.LEFT
    guan.facing=Vector2.RIGHT
    reserve.pos=foot.pos
    for u in [guan,foot,bow,reserve,foe]: u.goal=u.pos
    sim._combat(0.1)
    check(foe.get("last_strike_target",-1)==guan.id,"the attacker actually wounded Guan Xing")
    var start: Vector2=foot.pos
    for u in [foot,bow,reserve]: sim._decide(u)
    check(foot.field_choice.get("ally",-1)==guan.id and foot.field_choice.get("target",-1)==foe.id,"infantry supports the first arrival before reaching its own slot")
    check(bow.field_choice.get("ally",-1)==guan.id and bow.goal==bow.pos,"archer covers the same fight from firing distance")
    check(reserve.field_choice.get("ally",-1)!=guan.id,"explicit reserve keeps its assignment")
    var joined:={}
    for tick in 80:
        sim.step(0.1)
        for hit in sim.combat_contacts.values():
            if hit.defender_id==foe.id and hit.damage>0: joined[hit.attacker_id]=true
    check(start.distance_to(foot.pos)>10 and joined.has(foot.id) and joined.has(bow.id),"infantry physically closes and both supporting corps deal damage")
    foe.pos=Vector2(2000,1400)
    for u in [foot,bow]:
        sim._decide(u)
        check(not u.get("rally_covering",false) and Vector2(u.goal).distance_to(u.rally_station.point)<=18.0,"loss of contact releases the helper back to its own slot")
    print("CONTROL mixed=",mixed," first_arrival=",guan.name," foot=",foot.name," bow=",bow.name," joined=",joined.keys()," foot_walked=",roundi(start.distance_to(foot.pos)))

func campaign_opening() -> void:
    var sim=field()
    var pin: Vector2=sim.outposts[0].pos
    for id in sim.command_ids(0): check(sim.issue_map_order(id,"지정 위치 이동",pin),"order the whole force to the centre")
    var guan=officer(sim,"관흥")
    var helpers:={}
    var hit_by:={}
    var hits_in_relief:={}
    sim.start()
    for tick in 1050:
        sim.step(0.1)
        if sim.finished: break
        for hit in sim.combat_contacts.values():
            if hit.defender_id==guan.id: hit_by[hit.attacker_id]=true
        for u in sim.units:
            var order: Dictionary=u.get("field_choice",{})
            if u.side!=0 or not u.get("rally_covering",false) or order.get("ally",-1)!=guan.id or not hit_by.has(order.get("target",-1)): continue
            helpers[u.name]=true
            var hit: Dictionary=sim.combat_contacts.get(u.id,{})
            if hit.get("defender_id",-1)==order.target and hit.damage>0: hits_in_relief[u.name]=true
    print("QISHAN opening helpers=",helpers.keys()," hit_attacker_while_helping=",hits_in_relief.keys()," Guan casualties=",roundi(guan.casualties_taken))
    check(not hits_in_relief.is_empty(),"at least one rally member actively helps Guan Xing and hits his attacker in the full opening")

func _initialize() -> void:
    if "opening" not in OS.get_cmdline_user_args():
        controlled_contact(false)
        controlled_contact(true)
    campaign_opening()
    print("QISHAN_RELIEF_PASS" if failures==0 else "QISHAN_RELIEF_FAIL")
    quit(0 if failures==0 else 1)
