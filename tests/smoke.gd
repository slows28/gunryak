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
    for scenario in range(36):
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
    # 4 missions × 4 formation policies: every combination exactly once.
    var mission_options: Array[String] = ["중앙 진격", "북측 확보", "남측 우회", "본진 방어"]
    var policy_options: Array[String] = ["현장 판단", "횡대 유지", "종대 유지", "방진 유지"]
    var tried: Dictionary = {}
    for variant in range(mission_options.size() * policy_options.size()):
        var alternate = WarSim.new()
        var mission: String = mission_options[variant % mission_options.size()]
        var policy: String = policy_options[int(variant / mission_options.size())]
        var combination: String = mission + " + " + policy
        check(not tried.has(combination), "new plan-policy combination %d" % variant)
        tried[combination] = true
        check(alternate.select_unit_mission(variant % 3, mission, policy), "alternative planning %d" % variant)
        alternate.rng.seed = 120000 + variant
        alternate.start()
        var loop: int = 0
        while not alternate.finished and loop < 2200:
            alternate.step(0.1)
            loop += 1
            if loop % 90 == 0 and not alternate.validate_state().is_empty():
                check(false, "alternative plan state %d" % variant)
                break
        check(alternate.finished, "alternative plan completes %d" % variant)
    check(tried.size() == 16, "all 16 distinct plan-policy combinations tested")

    var replay = WarSim.new()
    replay.rng.seed = 90000
    replay.start()
    var t: int = 0
    while not replay.finished and t < 2200:
        replay.step(0.1)
        t += 1
    check(_signature(replay) == signatures[0], "identical seed replay matches")

    # A supply raid must persist across successive ~2-second AI decisions.
    var raid = WarSim.new()
    var raider: Dictionary = raid.find_unit(2)
    raider["pos"] = Vector2(592, 310)
    raid._decide(raider)
    check(str(raider["action"]) == "기지 습격", "raider starts observed supply raid")
    var first_raid_target: Vector2 = raider["goal"]
    raid.battle_time = 2.1
    raid._decide(raider)
    check(str(raider["action"]) == "기지 습격", "raid persists beyond first AI tick")
    check((raider["goal"] as Vector2).distance_to(first_raid_target) < 1.0, "raid target stays stable")
    raid.battle_time = 4.2
    raid._decide(raider)
    check(str(raider["action"]) == "기지 습격", "raid survives second AI tick")
    raid.bases[1]["alive"] = false
    raid._decide(raider)
    check(str(raider["action"]) != "기지 습격", "destroyed base cancels raid")
    check(not bool(raider["raid_active"]), "canceled raid releases active state")

    # Distant enemies cannot be observed or trigger contact combat AI.
    var fog = WarSim.new()
    var scout: Dictionary = fog.find_unit(0)
    check(fog._nearest_visible_enemy(scout).is_empty(), "initial commander cannot see remote enemy")
    fog._decide(scout)
    check(str(scout["action"]) == "진격", "out-of-sight enemy does not trigger combat AI")
    check(fog.validate_state().is_empty(), "raids and intelligence states remain valid")


    # The archer must physically retreat away from a VISIBLE close enemy, not
    # merely set its goal to its own position and freeze.
    var spacing = WarSim.new()
    var archer: Dictionary = spacing.find_unit(1)
    var attacker: Dictionary = spacing.find_unit(4)
    archer["pos"] = Vector2(475, 285)
    attacker["pos"] = Vector2(535, 285)
    var contact_distance: float = (archer["pos"] as Vector2).distance_to(attacker["pos"])
    spacing._decide(archer)
    check(str(archer["action"]) == "거리 유지", "archer chooses spacing against nearby visible enemy")
    var escape_goal: Vector2 = archer["goal"]
    check(escape_goal.x < 475.0, "archer retreat goal is behind its current position")
    spacing._move_unit(archer, 0.1)
    check((archer["pos"] as Vector2).distance_to(attacker["pos"]) > contact_distance, "archer physically gains space")
    check(str(archer["reason"]).find("근접") >= 0, "archer decision explains observed pressure")
    check(spacing.validate_state().is_empty(), "archer spacing preserves invariants")
    attacker["pos"] = Vector2(640, 285)
    spacing._decide(archer)
    check(str(archer["action"]) == "진격", "archer resumes assigned mission outside contact range")

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
