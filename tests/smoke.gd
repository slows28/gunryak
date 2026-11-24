extends SceneTree
## Automated engine regression test: exit status 0 only when all checks pass.
## Run: godot --headless --path . --script res://tests/smoke.gd
const WarSim = preload("res://scripts/war_sim.gd")

var failures: int = 0
var passes: int = 0

func check(condition: bool, label: String) -> void:
    if condition:
        passes += 1
        print("PASS ", label)
    else:
        failures += 1
        push_error("FAIL " + label)

func _initialize() -> void:
    var s = WarSim.new()
    check(s.units.size() == 6, "initial six units")
    check(s.bases.size() == 2, "two autonomous supply bases")
    check(s.commanders.size() == 2, "both strategists exist")
    check(s.select_unit_mission(0, "중앙 진격", "방진 유지"), "planning before battle")
    check(str(s.find_unit(0)["formation"]) == "방진", "planned formation installed")
    check(not s.request_order(0, "본진 방어", "현장 판단"), "courier prohibited before turn six")
    s.start()
    check(s.started, "battle start")
    var first_step: float = s.battle_time
    s.paused = true
    s.step(0.1)
    check(is_equal_approx(s.battle_time, first_step), "pause freezes battle simulation")
    s.paused = false
    for i in range(35):
        s.step(0.1)
        if i % 5 == 0:
            check(s.validate_state().is_empty(), "valid state after %d tenths" % i)
    check(s.battle_time > 3.0, "battle passes first three seconds")

    # Full battles: deterministic seeds and repeated state validation.
    var signatures: Array[String] = []
    for scenario in range(6):
        var run = WarSim.new()
        run.rng.seed = 90000 + scenario
        run.start()
        var ticks: int = 0
        while not run.finished and ticks < 2200:
            run.step(0.1)
            ticks += 1
            if ticks % 50 == 0 and not run.validate_state().is_empty():
                check(false, "state validation seed %d at tick %d" % [scenario, ticks])
                break
        check(run.finished, "battle terminates seed %d" % scenario)
        check(run.units.size() <= 10, "bounded reinforcement units seed %d" % scenario)
        check(run.validate_state().is_empty(), "all state invariants seed %d" % scenario)
        check(run.result != "", "battle has result seed %d" % scenario)
        if scenario == 0:
            signatures.append(_signature(run))
    var replay = WarSim.new()
    replay.rng.seed = 90000
    replay.start()
    var t: int = 0
    while not replay.finished and t < 2200:
        replay.step(0.1)
        t += 1
    check(_signature(replay) == signatures[0], "identical seed replay matches")

    # Re-formation must take time, not change instantaneously.
    var forma = WarSim.new()
    var lead: Dictionary = forma.find_unit(0)
    lead["next_formation"] = "종대"
    lead["form_remaining"] = 0.5
    forma._formation_transition(lead, 0.2)
    check(str(lead["formation"]) == "횡대", "formation switch is not instantaneous")
    forma._formation_transition(lead, 0.4)
    check(str(lead["formation"]) == "종대", "formation eventually switches")
    check(str(lead["next_formation"]) == "", "formation transition completes cleanly")

    # Messenger must travel, rather than changing orders immediately.
    var messages = WarSim.new()
    messages.start()
    messages.turn = 6
    messages.battle_time = 90.0
    var subject: Dictionary = messages.find_unit(0)
    subject["pos"] = Vector2(500, 260)
    messages.commanders[0]["pos"] = Vector2(200, 260)
    var former: String = str(subject["mission"])
    check(messages.request_order(0, "본진 방어", "방진 유지"), "turn six messenger dispatch")
    check(not messages.request_order(0, "남측 우회", "횡대 유지"), "duplicate courier blocked")
    messages._update_couriers(0.1)
    check(str(subject["mission"]) == former, "order unchanged before courier arrival")
    for j in range(40):
        messages._update_couriers(0.1)
    check(str(subject["mission"]) == "본진 방어", "order changes upon courier arrival")
    check(messages.couriers.is_empty(), "delivered messenger removed")

    # Supply must impose a penalty only after three operational turns.
    var supply = WarSim.new()
    for base in supply.bases:
        base["alive"] = false
    var isolated: Dictionary = supply.find_unit(0)
    supply._supply_logic(WarSim.TURN_SECONDS * 2.0)
    check(is_equal_approx(float(isolated["morale"]), 100.0), "no early supply morale penalty")
    supply._supply_logic(WarSim.TURN_SECONDS + 1.0)
    check(float(isolated["out_supply"]) >= WarSim.TURN_SECONDS * 3.0, "supply shortage counted")
    check(float(isolated["morale"]) < 100.0, "shortage imposes morale penalty")

    # Commander capture requires physical proximity and no defending force.
    var capture = WarSim.new()
    var assault: Dictionary = capture.find_unit(0)
    assault["pos"] = capture.commanders[1]["pos"]
    capture._check_victory()
    check(capture.finished and capture.result.find("승리") >= 0, "enemy strategist captured after penetration")

    print("GUNRYAK_TEST_SUMMARY pass=%d fail=%d" % [passes, failures])
    quit(0 if failures == 0 else 1)

func _signature(run) -> String:
    var text: String = "%s,%d,%d" % [run.result, run.total_troops(0), run.total_troops(1)]
    for unit in run.units:
        var pos: Vector2 = unit["pos"]
        text += "|%d:%.2f,%.2f,%.2f" % [int(unit["id"]), pos.x, pos.y, float(unit["troops"])]
    return text
