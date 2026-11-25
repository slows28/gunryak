extends SceneTree
const WarSim = preload("res://scripts/war_sim.gd")
# Comparative playtest, not a human enjoyment score.
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var rows: Array = []
    for scenario in range(5):
        for strategy in ["엄수","위임","지원","보존"]:
            var sim := WarSim.new()
            sim.set_scenario(scenario)
            sim.tactical_enabled = true
            for id in range(3):
                var unit: Dictionary = sim.find_unit(id)
                sim.select_unit_mission(id,str(unit["mission"]),"명령 엄수" if strategy == "엄수" else "재량 위임")
            sim.start()
            var responses: int = 0
            var reports_seen: Dictionary = {}
            for tick in range(1802):
                if sim.finished: break
                sim.step(0.1)
                if tick%20 != 0: continue
                for report in sim.open_situations():
                    reports_seen[report["id"]] = true
                    if sim.turn < 6: continue
                    var response: String = "현장 판단"
                    if strategy == "엄수": response = "사수"
                    elif strategy == "지원": response = "지원"
                    elif strategy == "보존": response = "철수" if report["kind"] == "포위 위험" else "재집결"
                    if sim.respond_situation(int(report["id"]),response): responses += 1
            var row: Dictionary = {"scenario":scenario,"strategy":strategy,"winner":sim.winning_side,"result":sim.result,"seconds":sim.battle_time,"blue":sim.total_troops(0),"red":sim.total_troops(1),"reports":reports_seen.size(),"responses":responses,"delivered":sim.tactical_delivered,"refused":sim.tactical_refused,"intercepted":sim.intercepted_orders,"valid":sim.finished and sim.validate_state().is_empty()}
            rows.append(row)
            print("BALANCE_ROW "+JSON.stringify(row))
    var file := FileAccess.open("res://test_results/balance_matrix.json",FileAccess.WRITE)
    if file != null: file.store_string(JSON.stringify(rows,"  "))
    for row in rows:
        if not row["valid"]:
            quit(1)
            return
    print("GUNRYAK_BALANCE_PASS")
    quit(0)
