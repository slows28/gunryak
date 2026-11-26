extends SceneTree

const WarSim = preload("res://scripts/war_sim.gd")
const POLICIES = ["엄수", "위임", "지원", "보존"]
const STEP = 0.1


func _initialize() -> void:
    call_deferred("_play")


func _play() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 2 or not args[0].is_valid_int() or not args[1].is_valid_int() or int(args[0]) not in range(5):
        push_error("Usage: -- SCENARIO_ID(0-4) SEED")
        quit(2)
        return

    var scenario := int(args[0])
    var seed_value := int(args[1])
    var sim := WarSim.new()
    for policy: String in POLICIES:
        sim.set_long_operation(true)
        sim.set_scenario(scenario)
        sim.tactical_enabled = true
        sim.rng.seed = seed_value
        var commands := sim.command_ids(0)
        var expected_duration := 1680 if scenario == 3 else 1500
        if commands.size() != 10 or sim.command_ids(1).size() != 10 or sim.operation_limit() != expected_duration:
            push_error("Unexpected army count or operation duration")
            quit(1)
            return

        var initial_policy := "명령 엄수" if policy == "엄수" else "재량 위임"
        for id in commands:
            var unit := sim.find_unit(id)
            if not sim.select_unit_mission(id, unit["mission"], initial_policy):
                push_error("Initial order rejected")
                quit(1)
                return

        sim.start()
        var responses := 0
        for tick in range(ceili(sim.scenario_limit / STEP) + 3):
            if sim.finished:
                break
            sim.step(STEP)
            if tick % 20 != 0 or sim.turn < WarSim.COURIER_TURN:
                continue
            for report in sim.open_situations():
                var order := "현장 판단"
                match policy:
                    "엄수":
                        order = "사수"
                    "지원":
                        order = "지원"
                    "보존":
                        order = "철수" if report["kind"] == "포위 위험" else "재집결"
                if sim.respond_situation(report["id"], order):
                    responses += 1

        var errors := sim.validate_state()
        if not sim.finished or sim.winning_side not in [0, 1] or not errors.is_empty():
            push_error("Operation ended without a valid result: " + str(errors))
            quit(1)
            return
        print("DEMO_ROW ", JSON.stringify({
            "scenario": scenario, "map": sim.scenario_title, "seed": seed_value,
            "strategy": policy, "win": int(sim.winning_side == 0),
            "result": sim.result, "detail": sim.result_detail,
            "clock": roundi(sim.operation_elapsed()), "blue": sim.total_troops(0),
            "red": sim.total_troops(1), "responses": responses,
        }))
    quit(0)
