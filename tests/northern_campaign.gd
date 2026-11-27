extends SceneTree
const North=preload("res://scripts/northern_campaign.gd")
const Sim=preload("res://scripts/war_sim.gd")
const Skills=preload("res://scripts/field_skills.gd")
var errors:=0
func check(ok:bool,reason:String):
    if not ok: push_error(reason);errors+=1
func _initialize():
    var campaign:=North.new()
    campaign.save_path="user://northern-regression.json"
    var sim:=Sim.new()
    sim.set_long_operation(true)
    check(campaign.officers.size()==25 and Skills.CATALOG.size()==39,"roster and equipment catalog")
    check(campaign.equip(0,"pace") and campaign.equip(2,"pace") and not campaign.state.gear.has("0"),"unique transfer by officer")
    check(campaign.assign(10,24) and campaign.state.active[10]==24,"reserve commander can enter any of twelve slots")
    var next:=North.new()
    next.save_path=campaign.save_path
    for n in range(1,14):
        check(campaign.prepare(n,sim),"stage %d prepare" % n)
        check(sim.validate_state().is_empty() and sim.command_ids(0).size()==12 and sim.command_ids(1).size()>=12 and sim.operation_limit()==1500,"chapter scale or length")
        check(not campaign.equip(0,"pace") and not campaign.prepare(n+1,sim),"battle loadout lock")
        sim.start()
        sim.step(0.1)
        if n==1:
            sim.headquarters[0].occupied=true
            sim.find_unit(0).troops=0
            sim._check_victory()
            check(sim.finished and sim.winning_side==1 and campaign.conclude(sim) and campaign.save(),"loss through HQ")
            check(next.load_save() and next.state.stage==1 and next.state.gear.get("2")=="pace","retry save")
            check(campaign.prepare(1,sim) and sim.find_unit(0).troops==4500 and sim.find_unit(0).general_hp==100,"fresh forces")
            sim.start()
        # Exercise the real objective evaluator with controlled endgame positions.
        sim.battle_time=sim.scenario_limit
        sim.turn=15
        for post in sim.outposts: post.owner=0;post.hold=60
        sim.find_unit(0).flank_damage=180
        sim.find_unit(0).linked_hits=180
        for id in sim.command_ids(0).slice(0,2):
            sim.find_unit(id).bridge_crossings=1
            sim.find_unit(id).pos=Vector2(1705,847)
        sim.find_unit(3).pos=sim.outposts[0].pos
        sim.find_unit(0).pos=sim.outposts[0].pos
        for id in sim.command_ids(1): sim.find_unit(id).troops*=0.6
        for gate in sim.structures: gate.hp=0.0
        sim._check_victory()
        check(sim.finished and sim.winning_side==0 and campaign.conclude(sim),"actual objective result %d" % n)
        check(not campaign.conclude(sim) and campaign.save(),"settle once and save")
        check(next.load_save() and next.state.reward==campaign.state.reward,"unclaimed reward survives restart")
        if n<13:
            var choices:=next.choices()
            check(choices.size()==3 and not next.prepare(n+1,sim),"reward gate")
            check(next.claim(choices[0]) and not next.claim(choices[1]) and campaign.load_save(),"exactly one reward")
    check(campaign.state.complete and campaign.state.claimed.size()==12 and campaign.state["items"].size()==15,"Chang'an reached")
    _skills()
    print("GUNRYAK_NORTHERN_PASS" if errors==0 else "GUNRYAK_NORTHERN_FAIL "+str(errors))
    quit(0 if errors==0 else 1)

func _skills():
    var sim:=Sim.new()
    sim.set_long_operation(true)
    var u:=sim.find_unit(0)
    var foe:=sim.find_unit(3)
    var ally:=sim.find_unit(1)
    u.pos=Vector2(720,750)
    foe.pos=Vector2(748,750)
    ally.pos=Vector2(749,780)
    sim.battle_time=8
    u.mission="공격"
    sim.combat_contacts={0:{"kind":"근접","from":u.pos,"to":foe.pos,"attacker_id":0,"defender_id":3},1:{"kind":"화살","from":ally.pos,"to":foe.pos,"attacker_id":1,"defender_id":3}}
    var cohesion:float=foe.cohesion
    Skills.attach(u,"breach","link")
    Skills.tick(sim,u)
    check(u.field_skill.get("id","")=="link" and Skills.attack_factor(u,foe,false,10)>10,"collaboration needs two angles")
    sim.battle_time+=5
    Skills.tick(sim,u)
    check(u.field_skill.get("id","")=="breach" and foe.cohesion<cohesion,"breach alters real cohesion")
    sim.battle_time+=30
    u.mission="지역 사수"
    u.last_hit=sim.battle_time
    u.front_pressure=0.5
    Skills.attach(u,"iron","pursue")
    Skills.tick(sim,u)
    check(u.field_skill.get("id","")=="iron" and Skills.absorb(u,10)<10 and u.mission=="지역 사수","hold takes priority over pursuit")
    u.tactical_order="철수"
    u.tactical_until=sim.battle_time+4
    Skills.tick(sim,u)
    check(u.field_skill.is_empty(),"urgent withdrawal ends defensive or offensive skills")
    sim.battle_time+=6
    u.morale=10
    Skills.attach(u,"last","")
    Skills.tick(sim,u)
    sim._update_general_conditions(u,0.1)
    check(not u.routed and u.field_skill.get("id","")=="last","stand prevents an actual rout")
    sim.battle_time+=6
    Skills.tick(sim,u)
    sim._update_general_conditions(u,0.1)
    check(u.routed,"stand expires")
    u.routed=false
    u.morale=75
    u.mission="지정 위치 이동"
    u.action="지정 위치 이동"
    u.goal=u.pos+Vector2(150,0)
    u.motion_speed=20
    sim.battle_time+=6
    Skills.attach(u,"relief","")
    Skills.tick(sim,u)
    check(u.field_skill.get("id","")=="relief","ordered movement activates speed")
    var initial:float=ally.morale
    ally.morale=34
    Skills.attach(u,"inspire","")
    sim.battle_time+=6
    Skills.tick(sim,u)
    check(u.field_skill.get("id","")=="inspire" and ally.morale>34 and ally.morale<=initial,"nearby actual morale rises")
