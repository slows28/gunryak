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
    sim.battle_time = 100.0
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
