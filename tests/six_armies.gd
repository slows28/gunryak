extends SceneTree
const WarSim = preload("res://scripts/war_sim.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Main = preload("res://main.tscn")
var failures: int = 0
func check(ok: bool,label: String) -> void:
    if not ok:
        failures += 1
        push_error(label)
    else: print("PASS "+label)
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    for scenario in range(5):
        var sim := WarSim.new()
        sim.set_six_armies(true)
        sim.set_scenario(scenario)
        sim.tactical_enabled = true
        check(sim.command_ids(0).size()==6 and sim.command_ids(1).size()==6 and sim.units.size()==12,"six distinct leaders scenario "+str(scenario))
        check(sim.total_troops(0)==713 and sim.reserve_limit[0]==1,"actual initial manpower and reserve cap")
        check(sim.select_unit_mission(8,"본진 방어","명령 엄수"),"sixth commander receives preplan")
        sim.start()
        check(sim.units.size()==12,"no hidden duplicate formations")
        var issued: bool = false
        for i in range(4200):
            if sim.finished: break
            sim.step(0.1)
            if sim.turn>=6 and not issued:
                issued=sim.request_order(8,"중앙 진격","재량 위임")
        check(sim.finished and sim.validate_state().is_empty() and sim.units.size()<=14,"battle valid, at most seven per faction")
        print("SIX_ARMY_ROW "+JSON.stringify({"scenario":scenario,"seconds":sim.battle_time,"winner":sim.winning_side,"blue":sim.total_troops(0),"red":sim.total_troops(1),"delivered":sim.delivered_orders,"intercepted":sim.intercepted_orders,"issued":issued,"result":sim.result}))
    var model := Campaign.new()
    model.set_six_armies(true)
    model.save_path = "user://gunryak_six_test.json"
    check(model.state["active"].size()==6 and model.state["roster"].size()==9,"six armies and spare officers")
    check(model.recruit(6) and model.assign(5,6),"replacement commander recruitment")
    var sim := WarSim.new()
    sim.set_six_armies(true)
    check(model.prepare(1,sim) and sim.find_unit(8)["name"]=="요화","sixth strategic slot deploys correct general")
    sim.start()
    for i in range(4200):
        if sim.finished: break
        sim.step(0.1)
    check(model.conclude(sim) and model.state["troops"][5]==floori(sim.corps_report(8)["troops"]),"sixth slot survivors persist")
    check(model.save(),"save six-army campaign")
    var loaded := Campaign.new()
    loaded.set_six_armies(true)
    loaded.save_path = model.save_path
    check(loaded.load_save() and loaded.state["active"]==model.state["active"],"six-army save roundtrip")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(model.save_path))
    var game: Control = Main.instantiate()
    root.add_child(game)
    await process_frame
    check(game.unit_list.item_count==6,"six commander UI entries")
    game.call("_on_unit_selected",5)
    check(game.selected_id==8,"last commander selection maps to correct unit ID")
    game.call("_begin_campaign")
    check(game.strategy_view.slot_choice.item_count==6,"six strategic UI slots")
    game.queue_free()
    await process_frame
    print("GUNRYAK_SIX_PASS" if failures==0 else "GUNRYAK_SIX_FAIL "+str(failures))
    quit(0 if failures==0 else 1)
