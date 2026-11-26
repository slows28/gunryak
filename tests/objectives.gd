extends SceneTree
const War=preload("res://scripts/war_sim.gd")
const Front=preload("res://scripts/front_view.gd")
var failures:=0

func check(ok: bool, message: String) -> void:
    if ok: print("PASS ",message)
    else:
        failures+=1
        push_error(message)

func _initialize() -> void:
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
    check(home["pos"]==s.bases[0]["pos"] and home["state"]=="파괴까지 20초" and home["alert"],"raid clock and focus refer to the chosen first depot")
    s.bases[0]["alive"]=false
    s._check_victory()
    check(s.finished and s.winning_side==1 and "첫 보급기지" in s.result_detail and other["alive"],"depot defense debrief identifies the lost primary depot")
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
