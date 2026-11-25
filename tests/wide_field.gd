extends SceneTree
const WarSim = preload("res://scripts/war_sim.gd")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var failures: int = 0
    for scenario in range(5):
        var sim := WarSim.new()
        sim.set_wide_field(true)
        sim.set_scenario(scenario)
        sim.tactical_enabled = true
        var before: Vector2 = sim.units[0]["pos"]
        var enemy: Vector2 = sim.units[3]["pos"]
        if sim.field_size != Vector2(2700,1710) or before.distance_to(enemy) < 1800.0:
            failures += 1
        if sim.forests.size() < 6 or sim.terrain_at(Vector2(70,sim.road_y(70,0))) != "도로":
            failures += 1
        if scenario == 1:
            sim.outposts[0]["owner"] = 0
            sim.outposts[0]["hold"] = 40.0
            sim.turn = 3
            if sim._objective_winner() != -1: failures += 1
            sim.reset()
        var before_blue: int = sim.total_troops(0)
        var before_red: int = sim.total_troops(1)
        sim.start()
        if sim.units.size() != 12 or sim.total_troops(0) != before_blue or sim.total_troops(1) != before_red:
            failures += 1
        var crossing := Vector2(sim.river_x(390.0),390.0)
        var river := Vector2(sim.river_x(600.0),600.0)
        if sim.terrain_at(crossing) != "교량" or sim.terrain_at(river) != "하천":
            failures += 1
        if sim._terrain_movement_multiplier(sim.units[0],crossing) <= sim._terrain_movement_multiplier(sim.units[0],river):
            failures += 1
        var initial_corps: Dictionary = sim.corps_report(0)
        if int(initial_corps["troops"]) != 145: failures += 1
        var max_x: float = before.x
        for i in range(4200):
            if sim.finished: break
            sim.step(0.1)
            max_x = maxf(max_x,float((sim.units[0]["pos"] as Vector2).x))
            if i%30 == 0 and sim.turn >= 6:
                for report in sim.open_situations():
                    sim.respond_situation(int(report["id"]),"지원")
        var valid: bool = sim.finished and sim.validate_state().is_empty()
        if not valid: failures += 1
        print("WIDE_FIELD_ROW "+JSON.stringify({"scenario":scenario,"seconds":sim.battle_time,"result":sim.result,"max_x":max_x,"blue":sim.total_troops(0),"red":sim.total_troops(1),"orders":sim.delivered_orders,"valid":valid}))
    print("GUNRYAK_WIDE_PASS" if failures == 0 else "GUNRYAK_WIDE_FAIL "+str(failures))
    quit(0 if failures == 0 else 1)
