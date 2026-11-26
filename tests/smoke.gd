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
    check(not s.request_order(0, "본진 방어", "현장 판단"), "courier prohibited before turn five")
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
    check(str(scout["action"]) in ["진격", "거점 점령", "거점 방어"] and fog._nearest_visible_enemy(scout).is_empty(), "out-of-sight enemy does not trigger combat AI")
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


    # Physical formation footprints must be shared by combat and the renderer.
    var frontage = WarSim.new()
    for other in frontage.units:
        if int(other["id"]) not in [0, 3]:
            other["troops"] = 0.0
    var blue: Dictionary = frontage.find_unit(0)
    var red: Dictionary = frontage.find_unit(3)
    blue["pos"] = Vector2(400, 300)
    red["pos"] = Vector2(430, 300)
    blue["facing"] = Vector2.RIGHT
    red["facing"] = Vector2.LEFT
    blue["formation"] = "횡대"
    red["formation"] = "횡대"
    check(frontage.formation_slots(blue).size() == 12, "line uses 12 real formation slots")
    var line_contacts: int = frontage.formation_contacts(blue, red, 30.0)
    blue["formation"] = "종대"
    var column_contacts: int = frontage.formation_contacts(blue, red, 30.0)
    check(line_contacts > column_contacts, "line engages with wider frontage than column")
    check(column_contacts > 0, "column still physically engages opponents")

    blue["formation"] = "횡대"
    var before_line: float = float(red["troops"])
    frontage._combat(0.1)
    var line_loss: float = before_line - float(red["troops"])
    check(line_loss > 0.0, "frontline clash removes defender troops")
    red["troops"] = red["initial_troops"]
    red["morale"] = 100.0
    blue["formation"] = "종대"
    frontage._combat(0.1)
    var column_loss: float = float(red["initial_troops"]) - float(red["troops"])
    check(line_loss > column_loss, "physical frontage changes actual casualties")

    var defense = WarSim.new()
    for other in defense.units:
        if int(other["id"]) not in [2, 3]:
            other["troops"] = 0.0
    var cavalry: Dictionary = defense.find_unit(2)
    var target: Dictionary = defense.find_unit(3)
    cavalry["pos"] = Vector2(400, 300)
    cavalry["facing"] = Vector2.RIGHT
    cavalry["charge"] = 40.0
    cavalry["charge_speed"] = 75.0
    cavalry["charge_dir"] = Vector2.RIGHT
    target["pos"] = Vector2(432, 300)
    target["facing"] = Vector2.LEFT
    target["formation"] = "횡대"
    defense._combat(0.1)
    var line_cavalry_loss: float = float(target["initial_troops"]) - float(target["troops"])
    target["troops"] = target["initial_troops"]
    target["morale"] = 100.0
    target["formation"] = "방진"
    cavalry["charge"] = 40.0
    cavalry["charge_speed"] = 75.0
    cavalry["charge_dir"] = Vector2.RIGHT
    cavalry["charge_cooldown"] = 0.0
    defense._combat(0.1)
    var square_cavalry_loss: float = float(target["initial_troops"]) - float(target["troops"])
    check(line_cavalry_loss > square_cavalry_loss, "formed square resists cavalry shock")
    check(defense.validate_state().is_empty(), "formation collision preserves world invariants")

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
    messages.turn = WarSim.COURIER_TURN
    messages.battle_time = 90.0
    var subject: Dictionary = messages.find_unit(0)
    subject["pos"] = Vector2(500, 260)
    messages.commanders[0]["pos"] = Vector2(200, 260)
    var former: String = str(subject["mission"])
    check(messages.request_order(0, "본진 방어", "방진 유지"), "turn five messenger dispatch")
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
    check(capture.commander_captured(1) and capture.command_confused(1) and not capture.finished, "enemy strategist captured after penetration and surviving army stays in battle")


    # M2 batch: (1) physical body collision; (2) morale and formation pressure.
    var physics = WarSim.new()
    var blue_line: Dictionary = physics.find_unit(0)
    var red_line: Dictionary = physics.find_unit(3)
    for outsider in physics.units:
        if int(outsider["id"]) not in [0, 3]:
            outsider["troops"] = 0.0
    blue_line["pos"] = Vector2(400, 300)
    red_line["pos"] = Vector2(400, 300)
    blue_line["formation"] = "횡대"
    red_line["formation"] = "횡대"
    physics._resolve_frontline(0.1)
    check((blue_line["pos"] as Vector2).distance_to(red_line["pos"]) >= 33.9, "overlapping enemy formations separate physically")
    var weak = WarSim.new()
    var strong_line: Dictionary = weak.find_unit(0)
    var weak_line: Dictionary = weak.find_unit(3)
    for outsider in weak.units:
        if int(outsider["id"]) not in [0, 3]:
            outsider["troops"] = 0.0
    strong_line["pos"] = Vector2(400, 300)
    weak_line["pos"] = Vector2(435, 300)
    strong_line["troops"] = 145.0
    weak_line["troops"] = 36.0
    weak_line["morale"] = 60.0
    var weak_start_x: float = (weak_line["pos"] as Vector2).x
    weak._resolve_frontline(0.1)
    check((weak_line["pos"] as Vector2).x > weak_start_x, "weaker formation is pushed away from the stronger front")
    check(float(weak_line["front_pressure"]) > 0.0, "frontline pressure visible in model")
    check(weak.validate_state().is_empty(), "frontline collision state remains valid")

    # (3) Personality selects only physically reachable, observed flank maneuvers.
    var flank = WarSim.new()
    var horse: Dictionary = flank.find_unit(2)
    var observed: Dictionary = flank.find_unit(3)
    horse["pos"] = Vector2(528, 215)
    observed["pos"] = Vector2(640, 215)
    observed["troops"] = 70.0
    observed["facing"] = Vector2.LEFT
    flank._decide(horse)
    check(str(horse["action"]) == "측면 우회", "aggressive cavalry plans flank instead of frontal rush")
    check(absf((horse["goal"] as Vector2).y - (observed["pos"] as Vector2).y) > 70.0, "flank goal is physically to the enemy side")
    var cautious: Dictionary = flank.find_unit(0)
    cautious["pos"] = Vector2(528, 215)
    flank._decide(cautious)
    check(str(cautious["action"]) != "측면 우회", "cautious commander cannot select aggressive flank")

    # (4) Road speeds movement, forests slow cavalry; hill aids physical archery.
    var terrain = WarSim.new()
    var walker: Dictionary = terrain.find_unit(0)
    walker["formation"] = "횡대"
    walker["next_formation"] = ""
    walker["action"] = "진격"
    check(terrain.terrain_at(Vector2(210, 282)) == "도로", "roads recognized at map coordinates")
    check(terrain.terrain_at(Vector2(351, 120)) == "숲", "woodland recognized at map coordinates")
    check(terrain.terrain_at(Vector2(450, 250)) == "고지", "hill recognized at map coordinates")
    walker["pos"] = Vector2(210, 210)
    walker["goal"] = Vector2(310, 210)
    terrain._move_unit(walker, 0.1)
    var plain_distance: float = (walker["pos"] as Vector2).x - 210.0
    walker["pos"] = Vector2(210, 282)
    walker["goal"] = Vector2(310, 282)
    terrain._move_unit(walker, 0.1)
    var road_distance: float = (walker["pos"] as Vector2).x - 210.0
    walker["pos"] = Vector2(351, 120)
    walker["goal"] = Vector2(440, 120)
    terrain._move_unit(walker, 0.1)
    var forest_distance: float = (walker["pos"] as Vector2).x - 351.0
    check(road_distance > plain_distance and plain_distance > forest_distance, "terrain makes real travel-speed differences")

    var hill = WarSim.new()
    for outsider in hill.units:
        if int(outsider["id"]) not in [1, 4]:
            outsider["troops"] = 0.0
    var bow: Dictionary = hill.find_unit(1)
    var enemy_bow: Dictionary = hill.find_unit(4)
    bow["pos"] = Vector2(439, 250)
    enemy_bow["pos"] = Vector2(540, 250)
    hill._combat(0.1)
    var hill_loss: float = float(enemy_bow["initial_troops"]) - float(enemy_bow["troops"])
    enemy_bow["troops"] = enemy_bow["initial_troops"]
    enemy_bow["morale"] = 100.0
    bow["pos"] = Vector2(439, 330)
    enemy_bow["pos"] = Vector2(540, 330)
    hill._combat(0.1)
    var plain_loss: float = float(enemy_bow["initial_troops"]) - float(enemy_bow["troops"])
    check(hill_loss > plain_loss, "high ground increases actual archer combat damage")

    # (5) Couriers require a physical route and can be intercepted or escorted.
    var intercepted = WarSim.new()
    intercepted.start()
    intercepted.turn = 6
    var recipient: Dictionary = intercepted.find_unit(0)
    recipient["pos"] = Vector2(500, 260)
    intercepted.commanders[0]["pos"] = Vector2(200, 260)
    var enemy_interceptor: Dictionary = intercepted.find_unit(3)
    enemy_interceptor["pos"] = Vector2(214, 260)
    var old_mission: String = str(recipient["mission"])
    check(intercepted.request_order(0, "본진 방어", "방진 유지"), "physical courier dispatched")
    intercepted._update_couriers(0.1)
    check(intercepted.couriers.is_empty() and intercepted.intercepted_orders == 1, "unescorted courier intercepted on enemy contact")
    check(str(recipient["mission"]) == old_mission, "interception preserves old orders")
    var escorted = WarSim.new()
    escorted.start()
    escorted.turn = 6
    var escorted_recipient: Dictionary = escorted.find_unit(0)
    escorted_recipient["pos"] = Vector2(500, 260)
    escorted.commanders[0]["pos"] = Vector2(200, 260)
    escorted.find_unit(3)["pos"] = Vector2(214, 260)
    escorted.find_unit(1)["pos"] = Vector2(214, 270)
    check(escorted.request_order(0, "본진 방어", "방진 유지"), "escorted courier dispatched")
    escorted._update_couriers(0.1)
    check(escorted.intercepted_orders == 0 and escorted.couriers.size() == 1, "friendly escort protects threatened courier")
    escorted.find_unit(3)["pos"] = Vector2(760, 170)
    for j in range(30):
        escorted._update_couriers(0.1)
    check(escorted.delivered_orders == 1 and escorted.couriers.is_empty(), "protected courier eventually delivers order")
    check(str(escorted_recipient["mission"]) == "본진 방어", "delivered courier changes mission")
    check(escorted.validate_state().is_empty(), "courier interception state remains valid")


    # M3-1: Re-formation duration varies with ability and creates vulnerability.
    var reform_test = WarSim.new()
    var veteran_reformer: Dictionary = reform_test.find_unit(0)
    var junior_reformer: Dictionary = reform_test.find_unit(1)
    veteran_reformer["policy"] = "방진 유지"
    junior_reformer["policy"] = "방진 유지"
    reform_test._decide(veteran_reformer)
    reform_test._decide(junior_reformer)
    check(float(veteran_reformer["form_remaining"]) < float(junior_reformer["form_remaining"]), "experienced general changes formation sooner")
    var shock = WarSim.new()
    for u in shock.units:
        if int(u["id"]) not in [0, 3]:
            u["troops"] = 0.0
    var reform_attacker: Dictionary = shock.find_unit(0)
    var reform_defender: Dictionary = shock.find_unit(3)
    reform_attacker["pos"] = Vector2(400, 300)
    reform_defender["pos"] = Vector2(431, 300)
    shock._combat(0.1)
    var stable_loss: float = float(reform_defender["initial_troops"]) - float(reform_defender["troops"])
    reform_defender["troops"] = reform_defender["initial_troops"]
    reform_defender["morale"] = 100.0
    reform_defender["next_formation"] = "방진"
    reform_defender["form_remaining"] = 2.0
    shock._combat(0.1)
    var reform_loss: float = float(reform_defender["initial_troops"]) - float(reform_defender["troops"])
    check(reform_loss > stable_loss, "formation changing under fire causes greater actual losses")
    shock._formation_transition(reform_defender, 2.1)
    check(int(reform_defender["reforms_completed"]) == 1, "formation transition counted in battle report")

    # M3-2: A cautious commander reacts to seen cavalry and counterattacks weakness.
    var counter = WarSim.new()
    var veteran: Dictionary = counter.find_unit(3)
    veteran["pos"] = Vector2(420, 300)
    var cavalry_threat: Dictionary = counter.find_unit(2)
    cavalry_threat["pos"] = Vector2(535, 300)
    counter._decide(veteran)
    check(str(veteran["action"]) == "방어" and str(veteran["next_formation"]) == "방진", "cautious enemy sees cavalry and orders square")
    cavalry_threat["pos"] = Vector2(140, 430)
    var weak_infantry: Dictionary = counter.find_unit(0)
    veteran["facing"] = Vector2.RIGHT
    weak_infantry["pos"] = Vector2(470, 300)
    weak_infantry["troops"] = 45.0
    veteran["action"] = "방어"
    counter._decide(veteran)
    check(str(veteran["action"]) == "명령 수행", "strict loyal general retains distant ordered objective instead of pursuing")
    veteran["action"] = "방어"
    counter._apply_policy(veteran, "재량 위임")
    counter._decide(veteran)
    check(str(veteran["action"]) == "반격", "experienced cautious enemy with discretion counterattacks observed weakness")

    # M3-3: Raiders have to defeat or draw off physical supply guards.
    var depot = WarSim.new()
    var camp: Dictionary = depot.bases[0]
    for friend in depot.units:
        if int(friend["side"]) == 0:
            friend["pos"] = Vector2(310, 220)
    var camp_guard: Dictionary = depot.find_unit(0)
    camp_guard["pos"] = Vector2(125, 308)
    depot.find_unit(3)["pos"] = Vector2(116, 310)
    depot._supply_logic(0.1)
    check(bool(camp["alive"]), "defended supply base withstands raider at gate")
    camp_guard["pos"] = Vector2(340, 310)
    depot._supply_logic(0.1)
    check(camp["alive"] and camp["raid_work"]>0, "undefended base begins a timed raid")
    for tick in range(59): depot._supply_logic(0.1)
    check(not bool(camp["alive"]), "undefended supply base falls after sustained physical raid")

    # M3-4: Uncontested occupation requires elapsed time; defenders deny capture.
    var flags = WarSim.new()
    for enemy in flags.units:
        if int(enemy["side"]) == 1:
            enemy["pos"] = Vector2(790, 280)
    var site_a: Dictionary = flags.outposts[0]
    var site_b: Dictionary = flags.outposts[1]
    flags.find_unit(0)["pos"] = site_a["pos"]
    flags.find_unit(2)["pos"] = site_b["pos"]
    flags._update_outposts(7.1)
    check(int(site_a["owner"]) == 0 and int(site_b["owner"]) == 0, "both strategic objectives captured after required occupation")
    flags.find_unit(3)["pos"] = site_a["pos"]
    flags._update_outposts(0.5)
    check(is_equal_approx(float(site_a["hold"]), 0.0), "enemy contest blocks strategic hold")
    flags.find_unit(3)["pos"] = Vector2(800, 300)
    flags._update_outposts(8.1)
    flags.turn = 3
    flags._check_victory()
    check(flags.finished and flags.result.find("요충지") >= 0, "holding both outposts triggers scenario victory")

    # M3-5: Reports use actual combat losses and recorded commands.
    var report: Array[String] = flags.battle_report()
    check(report.size() == 4, "battle report gives outcome and three player generals")
    check(report[0].find("요충지") >= 0, "battle report retains actual victory reason")
    check(report[1].find("판단") >= 0 and report[1].find("피해") >= 0, "report includes decisions and damage")
    check(float(reform_attacker["damage_dealt"]) > 0.0 and float(reform_defender["casualties_taken"]) > 0.0, "report telemetry is based on real combat")

    # M8: actual enemy movement is blocked until a defensive object is destroyed.
    var siege = WarSim.new()
    siege.set_scenario(2)
    var wall: Dictionary = siege.structures[0]
    var invader: Dictionary = siege.find_unit(3)
    invader["pos"] = Vector2(248,150)
    check(siege._structure_move(invader,Vector2(248,150),Vector2(235,150)) == Vector2(248,150),"intact palisade blocks enemy entry")
    wall["hp"] = 0.1
    siege._update_structures(0.1)
    check(float(wall["hp"]) == 0.0 and siege._structure_move(invader,Vector2(248,150),Vector2(235,150)) == Vector2(235,150),"nearby assault destroys palisade and opens path")
    check(siege.merit(invader) >= 0, "merit is nonnegative and derived from real events")
    print("GUNRYAK_TEST_SUMMARY pass=%d fail=%d" % [passes, failures])
    quit(0 if failures == 0 else 1)

func _signature(run) -> String:
    var text: String = "%s,%d,%d" % [run.result, run.total_troops(0), run.total_troops(1)]
    for unit in run.units:
        var pos: Vector2 = unit["pos"]
        text += "|%d:%.2f,%.2f,%.2f" % [int(unit["id"]), pos.x, pos.y, float(unit["troops"])]
    return text
