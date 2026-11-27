extends SceneTree
## Cross every ordered shape with every opponent shape, then swap the two
## commanders. The experiment uses the shipping contact, loss and push solvers.
const Sim = preload("res://scripts/war_sim.gd")
const CASES := ["보병 정면","보병 측면","기병 충격","궁병 사격"]
const TICKS := 30

func _initialize() -> void:
    var trials := []
    for encounter: String in CASES:
        for own: String in Sim.LARGE_FORMATIONS:
            for other: String in Sim.LARGE_FORMATIONS:
                for reverse in [false,true]:
                    var row := _engage(encounter,own,other,reverse)
                    if not row["valid"] or maxf(row["dealt"],row["lost"]) <= 0.0 or (encounter == "궁병 사격" and minf(row["dealt"],row["lost"]) <= 0.0):
                        push_error("FORMATION_EFFICIENCY_FAIL "+JSON.stringify(row))
                        quit(1)
                        return
                    trials.append(row)
    var path := "res://test_results/formation_efficiency.json"
    if OS.get_cmdline_user_args().size() > 0: path = OS.get_cmdline_user_args()[0]
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
    var file := FileAccess.open(path,FileAccess.WRITE)
    if file == null:
        push_error("FORMATION_EFFICIENCY_FAIL could not save "+path)
        quit(1)
        return
    file.store_string(JSON.stringify(trials))
    print("GUNRYAK_FORMATION_EFFICIENCY_PASS trials=",trials.size())
    quit()

func _engage(encounter: String, shape: String, opposing_shape: String, reverse: bool) -> Dictionary:
    var sim := Sim.new()
    sim.set_long_operation(true)
    sim.forests.clear()
    sim.hill = Rect2()
    sim.battle_time = 1.0
    for u in sim.units: u["troops"] = 0.0
    var own := sim.find_unit(3 if reverse else 0)
    var foe := sim.find_unit(0 if reverse else 3)
    var distance := 112.0 if encounter == "궁병 사격" else 38.0
    var axis := Vector2.LEFT if reverse else Vector2.RIGHT
    for u: Dictionary in [own,foe]:
        var attacker: bool = u["id"] == own["id"]
        var facing := axis if attacker else -axis
        u["type"] = "궁병" if encounter == "궁병 사격" else "보병"
        u["formation"] = shape if attacker else opposing_shape
        u["next_formation"] = ""
        u["troops"] = 3600.0
        u["initial_troops"] = 3600.0
        u["morale"] = 90.0
        u["cohesion"] = 90.0
        u["fatigue"] = 0.0
        u["specialty"] = ""
        u["ammo"] = 100.0
        u["pos"] = Vector2(839,750)-facing*distance*0.5
        u["facing"] = facing
    if encounter == "보병 측면": foe["facing"] = axis.orthogonal()
    if encounter == "기병 충격":
        own["type"] = "기병"
        own["charge"] = 80.0
        own["charge_speed"] = 80.0
        own["charge_dir"] = axis
    var contacts := 0
    for tick in TICKS:
        sim.step_count += 1
        sim.battle_time += 0.1
        sim._resolve_frontline(0.1)
        sim._combat(0.1)
        contacts += int(own["contact_troops"])
    return {"case":encounter,"own":shape,"foe":opposing_shape,"reverse":reverse,
        "dealt":own["damage_dealt"],"lost":own["casualties_taken"],"files":float(contacts)/TICKS,
        "yield":own["pushed_distance"],"push":foe["pushed_distance"],"charges":own["charges"],
        "valid":is_equal_approx(3600.0-float(foe["troops"]),float(own["damage_dealt"])) and is_equal_approx(3600.0-float(own["troops"]),float(own["casualties_taken"]))}
