extends SceneTree

const WarSim = preload("res://scripts/war_sim.gd")
const DEFAULT_SEEDS = [20261124, 20261127]

# No player intervention. Pass a map and a seed to replay one result.
func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    var maps := range(6)
    var seeds: Array = DEFAULT_SEEDS
    if not args.is_empty():
        if args.size() != 2 or not args[0].is_valid_int() or not args[1].is_valid_int() or not int(args[0]) in maps:
            push_error("Expected a scenario number (0–5) and an integer seed.")
            quit(2)
            return
        maps = [int(args[0])]
        seeds = [int(args[1])]
    var failed := false
    for battle_seed in seeds:
        for scenario in maps:
            var report := play_battle(scenario, battle_seed)
            print("AFTERMATH ", JSON.stringify(report))
            if not report["errors"].is_empty():
                failed = true
    quit(1 if failed else 0)

func play_battle(scenario: int, battle_seed: int) -> Dictionary:
    var sim := WarSim.new()
    sim.tactical_enabled = true
    sim.set_long_operation(true)
    sim.set_scenario(scenario)
    sim.rng.seed = battle_seed
    sim.start()
    var errors: Array[String] = []
    var inactive_hits := 0
    var wagon_hits := 0
    var without_striker := 0
    var without_guard := 0
    var hp := float(sim.convoy.get("hp", 0.0))
    var step_limit := ceili(sim.scenario_limit / 0.1) + 2
    for tick in range(step_limit):
        if sim.finished: break
        sim.step(0.1)
        for hit in sim.combat_contacts.values():
            var attacker := sim.find_unit(hit["attacker_id"])
            if attacker["action"] in ["휴식", "사기 혼란", "수레 공격"]:
                inactive_hits += 1
        if not sim.convoy.is_empty() and sim.convoy["hp"] < hp:
            var situation := sim.convoy_status()
            wagon_hits += 1
            if situation["strikers"] == 0: without_striker += 1
            if situation["guards"] == 0: without_guard += 1
            hp = sim.convoy["hp"]
        if sim.step_count % 100 == 0:
            errors.append_array(sim.validate_state())
            if not errors.is_empty(): break
    if not sim.finished: errors.append("전투 미종료")
    if inactive_hits > 0: errors.append("휴식·혼란·수레 공격 중 군단 타격")
    if without_striker > 0: errors.append("공격자가 없는 수레 피해")
    var expected := 0
    for unit in sim.units:
        expected += floori(float(unit["casualties_taken"]) / WarSim.LOSSES_PER_FALLEN)
    if sim.fallen_marks.size() != expected: errors.append("전투 손실과 시신 수 불일치")
    for mark in sim.fallen_marks:
        if sim.in_open_water(mark["point"]):
            errors.append("강물 위 시신")
            break
    return {"map": sim.scenario_title, "seed": battle_seed, "outcome": sim.result,
        "operation_seconds": snappedf(sim.operation_elapsed(), 0.1), "bodies": sim.fallen_marks.size(),
        "expected": expected, "inactive_hits": inactive_hits, "wagon_hits": wagon_hits,
        "hits_without_striker": without_striker, "hits_without_guard": without_guard, "errors": errors}
