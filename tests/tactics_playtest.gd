extends SceneTree
const WarSim = preload("res://scripts/war_sim.gd")
var failures: int = 0
func check(ok: bool,label: String) -> void:
    if ok:
        print("PASS "+label)
    else:
        failures += 1
        push_error(label)
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    _check_returning_rider()
    _check_local_relief()
    var sim := WarSim.new()
    sim.tactical_enabled = true
    sim.start()
    var target: Dictionary = sim.find_unit(0)
    check(not sim.request_tactical(0,"사수"),"no tactical commands before turn six")
    target["morale"] = 39.0
    sim.battle_time = 90.0
    sim.turn = 6
    sim._scan_situations()
    check(sim.open_situations().is_empty(),"report delay is real")
    for i in range(100):
        sim.battle_time+=0.1
        sim._move_reporting_messengers(0.1)
    sim._scan_situations()
    check(not sim.open_situations().is_empty(),"delayed allied report arrives")
    if not sim.open_situations().is_empty():
        var report: Dictionary = sim.open_situations()[0]
        check(sim.respond_situation(int(report["id"]),"사수"),"response queues actual courier")
        check(sim.command_points == 2 and sim.couriers.size() == 1 and target["tactical_order"] == "","command spends resource but is not telepathic")
        sim.couriers[0]["pos"] = target["pos"]
        sim._update_couriers(0.1)
        check(sim.tactical_delivered == 1 and target["tactical_order"] == "사수","courier arrival changes unit order")
        sim._decide(target)
        check(str(target["action"]) == "긴급 방어","delivered hold order affects decision")
    var aggressive: Dictionary = sim.find_unit(2)
    var enemy: Dictionary = sim.find_unit(3)
    aggressive["pos"] = Vector2(400,280)
    aggressive["troops"] = 95.0
    enemy["pos"] = Vector2(430,280)
    enemy["troops"] = 35.0
    aggressive["morale"] = 90.0
    sim._deliver_tactical(aggressive,{"tactical_order":"철수"})
    check(sim.tactical_refused == 1,"aggressive commander refuses withdrawal when advantage is observed")
    sim._apply_policy(aggressive,"명령 엄수")
    sim._deliver_tactical(aggressive,{"tactical_order":"철수"})
    check(aggressive["tactical_order"] == "철수","strict order restores compliance")
    var outcomes: Array = []
    for strategy in ["현장 판단","명령 엄수","재량 위임"]:
        var game := WarSim.new()
        game.tactical_enabled = true
        for id in range(3):
            var unit: Dictionary = game.find_unit(id)
            game.select_unit_mission(id,str(unit["mission"]),strategy)
        game.start()
        var responses: int = 0
        for i in range(1801):
            if game.finished: break
            game.step(0.1)
            if game.turn >= 6 and i%20 == 0:
                for report in game.open_situations():
                    var response: String = "현장 판단" if strategy == "재량 위임" else ("사수" if strategy == "명령 엄수" else "지원")
                    if game.respond_situation(int(report["id"]),response):
                        responses += 1
        var row: Dictionary = {"strategy":strategy,"result":game.result,"blue":game.total_troops(0),"red":game.total_troops(1),"reports":game.situation_serial,"responses":responses,"delivered":game.tactical_delivered,"refused":game.tactical_refused,"seconds":game.battle_time}
        outcomes.append(row)
        check(game.finished and game.validate_state().is_empty(),"strategy "+strategy+" completes")
        print("GUNRYAK_PLAYTEST "+JSON.stringify(row))
    var distinct: Dictionary = {}
    for row in outcomes:
        distinct["%d:%d" % [row["blue"],row["red"]]] = true
    check(distinct.size() >= 2,"strategic policies produce different actual outcomes")
    print("GUNRYAK_TACTICS_PASS" if failures == 0 else "GUNRYAK_TACTICS_FAIL "+str(failures))
    quit(0 if failures == 0 else 1)

func _check_returning_rider() -> void:
    var sim:=WarSim.new()
    sim.tactical_enabled=true
    sim.set_long_operation(true)
    sim.start()
    var unit:=sim.find_unit(0)
    var origin:=Vector2(sim.river_x(520)+170,520)
    var post:=Vector2(sim.river_x(530)-220,530)
    unit["pos"]=origin
    unit["rations"]=12.0
    sim.commanders[0]["pos"]=post
    sim.battle_time=4.0
    sim._scan_situations()
    var report: Dictionary=sim.incoming_reports[0]
    var rider: Dictionary=report["rider"]
    check(report["sender"]=="왕평" and not report.has("arrive") and sim.open_situations().is_empty(),"unreceived letter has no arrival time or inbox entry")
    sim._scan_situations()
    check(sim.incoming_reports.size()==1,"one field dispatch per incident")
    sim.paused=true
    sim.step(0.1)
    check(rider["pos"]==origin and sim.battle_time==4.0,"pause freezes the reporting rider")
    sim.paused=false
    unit["name"]="교대 장수"
    unit["morale"]=76.0
    unit["pos"]+=Vector2(80,0)
    var wet:=false
    var moved:=false
    for tick in range(350):
        sim.battle_time+=0.1
        if tick==36: sim.commanders[0]["pos"]=post+Vector2(-140,175)
        sim._move_reporting_messengers(0.1)
        moved=moved or rider["pos"]!=origin
        wet=wet or sim.in_open_water(rider["pos"])
        if report["status"]!="대기": break
    check(moved and not wet and rider["bridge_crossings"]==1,"reporting rider physically crosses at a bridge")
    check(rider["pos"]==sim.commanders[0]["pos"] and sim.open_situations().has(report),"letter reaches the strategist's new position")
    check(report["sender"]=="왕평" and report["pos"]==origin and report["rations"]==12,"dispatch identity position and condition are immutable")
    check(is_equal_approx(report["expires"]-report["arrive"],26.0),"response window starts on actual delivery")
    sim.reset()
    sim.start()
    sim.find_unit(0)["rations"]=12.0
    sim._scan_situations()
    sim.commanders[0]["captured"]=true
    sim._move_reporting_messengers(0.1)
    sim.battle_time+=4.0
    sim._scan_situations()
    check(sim.incoming_reports.is_empty() and sim.situation_reports.is_empty(),"a captured strategist cannot receive or reveal an undelivered report")

func _check_local_relief() -> void:
    for style in ["신중","공격"]:
        var sim:=WarSim.new()
        sim.tactical_enabled=true
        sim.set_long_operation(true)
        sim.start()
        for u in sim.units: u["pos"]=Vector2(2450,1440)
        var sender:=sim.find_unit(0)
        var ally:=sim.find_unit(1)
        sender["pos"]=Vector2(425,510)
        sender["surrounded"]=true
        ally["pos"]=Vector2(550,510)
        ally["personality"]=style
        ally["morale"]=60.0
        sim.commanders[0]["pos"]=Vector2(830,990)
        sim.commanders[0]["captured"]=true
        sim.battle_time=20.0
        sim._scan_situations()
        var report: Dictionary=sim.incoming_reports[0]
        var hq_rider: Dictionary=report["rider"]
        check(sim.relief_riders.size()==1 and sim.relief_riders[0]["recipient"]==ally["id"] and ally["tactical_order"]=="","distinct riders leave the threatened corps before any decision")
        for tick in range(12):
            sim.battle_time+=0.1
            sim._move_relief_riders(0.1)
        var accepted: bool=style=="공격"
        check((ally["tactical_order"]=="지원")==accepted and not report.has("relief_answer"),"local decision at delivery depends on temperament and is not yet known at headquarters")
        for tick in range(250):
            sim.battle_time+=0.1
            sim._move_relief_riders(0.1)
            sim._move_reporting_messengers(0.1)
        check(hq_rider["pos"]==sim.headquarters[0]["pos"] and report["status"]=="미대응","urgent message reaches the fixed headquarters even with a captured strategist")
        check(("수락" if accepted else "거절") in report.get("relief_answer","") and not sim.field_notices.is_empty(),"headquarters gets the local commander's actual reply by messenger")
        if accepted:
            ally["tactical_until"]=sim.battle_time+5.0
            var next:=sim._tactical_decision(ally,{},"대기","",ally["pos"],900,1.0)
            check(next["action"]=="긴급 지원" and "현지 구원" in next["reason"],"accepted request produces an actual support action")
