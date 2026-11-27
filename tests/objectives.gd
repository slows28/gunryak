extends SceneTree
const War=preload("res://scripts/war_sim.gd")
const Front=preload("res://scripts/front_view.gd")
var failures:=0

func check(ok: bool, message: String) -> void:
    if ok: print("PASS ",message)
    else:
        failures+=1
        push_error(message)

func check_headquarters_watch() -> void:
    var s:=War.new()
    s.set_long_operation(true)
    var home:=s._home_point(0)
    var scout:=s.find_unit(s.command_ids(0)[0])
    var raider:=s.find_unit(s.command_ids(1)[0])
    s.chapter={"mode":"link"}
    for unit in s.units: unit["pos"]=s.field_size-Vector2(30,30)
    raider["pos"]=home+Vector2(267,0)
    s._update_headquarters(0.1)
    check(not s.home_approach_seen() and s.headquarters_state(0)=="주둔군 없음","unseen raider and empty camp")
    scout["pos"]=raider["pos"]+Vector2(35,0)
    s.battle_time+=1.1
    s._update_headquarters(0.1)
    check(s.home_approach_seen() and s.headquarters[0]["occupation"]==0,"observed approach precedes occupation")
    var notices:=s.field_notices.size()
    s.battle_time+=1.1
    s._update_headquarters(0.1)
    check(s.field_notices.size()==notices,"one notice for a continuing sighting")
    raider["pos"]=s.field_size-Vector2(30,30)
    s.battle_time+=4.0
    s._update_headquarters(0.1)
    check(not s.home_approach_seen(),"report expires when contact is lost")
    check(s.issue_map_order(scout.id,"본진 방어",Vector2.ZERO) and scout.order_destination==home,"headquarters order anchors to current camp")
    check(not s.LinkedMarch._available(scout),"another corps cannot pull the headquarters guard into a linked march")
    var next:=home+Vector2(0,120)
    check(s.place_post("본진",next) and scout.order_destination==next and not s.home_approach_seen(),"headquarters duty follows relocation")
    scout["pos"]=next
    scout["routed"]=true
    check(s.headquarters_state(0)=="주둔군 없음" and not s.home_guard_roster().contains("전담"),"a routed guard cannot block occupation")

func _initialize() -> void:
    check_headquarters_watch()
    var s:=War.new()
    s.set_long_operation(true)
    for scenario in range(6):
        s.set_scenario(scenario)
        var rows:=Front.objective_targets(s,false)
        check(rows.size()==[3,1,1,2,2,2][scenario],"scenario %d shows only its actual objectives" % scenario)
    s.reset()
    s.set_scenario(0)
    s.start()
    var site: Dictionary=s.outposts[0]
    var blue:=s.find_unit(0)
    var red:=s.find_unit(3)
    blue["pos"]=site["pos"]
    s._update_outposts(s.capture_duration()*0.5)
    check(Front.objective_targets(s,false)[0]["state"]=="아군 점령 50%","capture progress uses the real timer")
    s._update_outposts(s.capture_duration()*0.5)
    s._update_outposts(20.0)
    check(Front.objective_targets(s,false)[0]["state"]=="아군 80/180초","occupation displays the actual hold in operation seconds")
    red["pos"]=site["pos"]
    s._update_outposts(0.1)
    check(Front.objective_targets(s,false)[0]["state"]=="경합 · 유지 중단" and site["hold"]==0.0,"contested site visibly loses hold progress")
    blue["pos"]=s.bases[0]["pos"]
    s._update_outposts(2.0)
    red["pos"]=s.bases[1]["pos"]
    blue["pos"]=site["pos"]
    s._update_outposts(0.5)
    check(site["challenger"]==-1 and Front.objective_targets(s,false)[0]["state"]=="아군 2/180초","returning holder clears a stale enemy challenge")
    site["pos"]=s.field_size-Vector2(30,30)
    site["owner"]=1
    check(Front.objective_targets(s,true)[0]["state"]=="미확인" and not Front.objective_targets(s,true)[0]["alert"],"unseen enemy control is concealed")
    s.reset()
    s.set_scenario(2)
    s.place_post("보급기지",Vector2(510,710))
    s.start()
    var other:=s._base(0,Vector2(900,800))
    s.bases.append(other)
    s.bases[0]["raid_rate"]=1
    s.bases[0]["raid_work"]=1.0
    var home:=Front.objective_targets(s,true)[0]
    check(home["pos"]==s._home_point(0) and home["pos"]!=s.bases[0]["pos"] and not home["alert"],"headquarters stays fixed when the player relocates the first depot")
    for u in s.units:
        u["pos"]=s.bases[0]["pos"]+Vector2(350,0)
    var raider:=s.find_unit(3)
    raider["pos"]=s.bases[0]["pos"]
    s.bases[0]["raid_work"]=0.0
    s._update_base_raid(s.bases[0],2.0)
    blue=s.find_unit(0)
    blue["pos"]=raider["pos"]
    s._update_base_raid(s.bases[0],0.1)
    blue["pos"]+=Vector2(350,0)
    s._update_base_raid(s.bases[0],2.0)
    s.find_unit(4)["pos"]=raider["pos"]
    s._update_base_raid(s.bases[0],2.0)
    s._check_victory()
    check(is_equal_approx(s.bases[0]["raid_elapsed"]*s.operation_scale(),16.0) and s.bases[0]["raiders_at_loss"]==2,"depot raid still records actual time and raiders")
    check(not s.finished and not s.bases[0]["alive"] and other["alive"],"losing the first depot only removes that supply radius")
    check(not s.field_notices.is_empty(),"supply loss is available in the notification inbox")
    raider["pos"]=home["pos"]
    s._update_headquarters(6.0)
    check(Front.objective_targets(s,true)[0]["state"]=="함락까지 24초","actual headquarters occupation countdown")
    blue["pos"]=raider["pos"]
    s._update_headquarters(0.1)
    check(s.headquarters[0]["occupation"]==0.0,"a defender interrupts headquarters occupation")
    blue["pos"]+=Vector2(350,0)
    s._update_headquarters(s.HQ_CAPTURE_SECONDS)
    s._check_victory()
    check(s.finished and s.winning_side==1 and "본진 함락" in s.result and "48초" in s.result_detail,"only successful headquarters occupation ends defense")
    s.reset()
    s.set_scenario(1)
    for u in s.units: u["pos"]=s.field_size*0.5
    s.find_unit(0)["pos"]=s.headquarters[1]["pos"]
    s._update_headquarters(s.HQ_CAPTURE_SECONDS)
    s._check_victory()
    check(s.finished and s.winning_side==0 and "적 본진 함락" in s.result,"enemy headquarters falls on the same terms in other operations")
    s.reset()
    s.set_scenario(3)
    var target:=Front.objective_targets(s,false)
    check(target[0]["pos"]==s.convoy["pos"] and target[1]["pos"]==s.convoy["goal"],"escort buttons distinguish the wagon from its destination")
    s.convoy["pos"]=s.convoy["goal"]
    s._check_victory()
    check(s.winning_side==0 and "도착점" in s.result_detail,"escort victory explains arrival")
    s.reset()
    s.set_scenario(5)
    s.start()
    s.battle_time=s.scenario_limit
    s._check_victory()
    check(s.winning_side==1 and "성문 내구도 100%" in s.result_detail and "0/120초" in s.result_detail,"siege timeout shows both unmet conditions")
    s.reset()
    s.set_scenario(0)
    s.start()
    s.turn=20
    s.battle_time=s.LONG_OBJECTIVE_OPEN
    for i in [0,2]:
        s.outposts[i]["owner"]=0
        s.outposts[i]["hold"]=45.0
    s._check_victory()
    check(s.winning_side==0 and s.outposts[0]["name"] in s.result_detail and s.outposts[2]["name"] in s.result_detail and "180초" in s.result_detail,"winning pair and hold time appear in the debrief")
    s.reset()
    check(s.result_detail.is_empty(),"a new operation clears the previous decision")
    if failures==0: print("GUNRYAK_OBJECTIVES_PASS")
    quit(1 if failures else 0)
