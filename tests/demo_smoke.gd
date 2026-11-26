extends SceneTree
const Campaign = preload("res://scripts/campaign.gd")
const WarSim = preload("res://scripts/war_sim.gd")
const Main = preload("res://main.tscn")
var failures: int = 0
func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error(label)
    else:
        print("PASS "+label)
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var campaign := Campaign.new()
    campaign.save_path = "user://gunryak_demo_test.json"
    var sim := WarSim.new()
    check(campaign.available(1) and campaign.available(2) and not campaign.available(5),"strategic adjacency")
    var gold: int = campaign.state["gold"]
    check(campaign.recruit(3) and campaign.state["gold"] == gold-55,"recruitment cost")
    check(campaign.assign(0,3),"assign recruited commander")
    check(campaign.replenish(0) and campaign.state["troops"][0] == 165,"recruit reserve troops")
    check(campaign.set_type(0,"기병"),"change troop type")
    check(campaign.prepare(1,sim),"launch campaign battle")
    check(sim.find_unit(0)["name"] == "강유" and sim.find_unit(0)["type"] == "기병" and int(sim.find_unit(0)["troops"]) == 165,"actual deployed army matches strategic settings")
    check(not campaign.save(),"mid-battle save prevented")
    sim.start()
    for i in range(1801):
        if sim.finished: break
        sim.step(0.1)
    check(sim.finished and sim.validate_state().is_empty(),"campaign battle reaches actual result")
    var won: bool = sim.winning_side == 0
    check(campaign.conclude(sim),"battle results update strategic state")
    check(campaign.state["pending"] == -1 and (campaign.state["victories"] == 1 if won else campaign.state["defeats"] == 1),"real victory or defeat recorded")
    check(campaign.save(),"save campaign")
    var loaded := Campaign.new()
    loaded.save_path = campaign.save_path
    check(loaded.load_save() and loaded.state["gold"] == campaign.state["gold"] and loaded.state["active"] == campaign.state["active"],"save round trip")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(campaign.save_path))
    sim.set_scenario(3)
    check(not sim.convoy.is_empty(),"escort scenario has real convoy")
    sim.find_unit(0)["pos"] = sim.convoy["pos"]
    var before: Vector2 = sim.convoy["pos"]
    sim._update_convoy(0.1)
    check(before.distance_to(sim.convoy["pos"]) > 0,"escorted convoy moves")
    sim.convoy["hp"] = 0.0
    sim._check_victory()
    check(sim.finished and sim.winning_side == 1,"convoy destruction loses battle")
    sim.set_scenario(4)
    check(sim.structures.size() == 3,"siege has destructible structures")
    sim.structures[0]["hp"] = 0.0
    sim.outposts[0]["owner"] = 0
    sim.outposts[0]["hold"] = 12.0
    sim.turn = 3
    sim._check_victory()
    check(sim.finished and sim.winning_side == 0,"siege requires gate and hold")
    var game: Control = Main.instantiate()
    root.add_child(game)
    await process_frame
    game.call("_begin_campaign")
    check(game.strategy_view.visible,"campaign UI opens")
    check(game.call("_launch_campaign_battle",1),"campaign UI launches real battle")
    check(game.sim.find_unit(0)["name"] == "왕평","campaign UI deployment")
    print("GUNRYAK_DEMO_PASS" if failures == 0 else "GUNRYAK_DEMO_FAIL "+str(failures))
    game._quit_game(0 if failures == 0 else 1)
