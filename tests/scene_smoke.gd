extends SceneTree
## Tests main scene, HUD updates, and a complete large-field battle.
const MAIN_SCENE = preload("res://main.tscn")
const LIMIT_TICKS: int = 4200
var instance: Control
var frames: int = 0
var ticks: int = 0

func _initialize() -> void:
    instance = MAIN_SCENE.instantiate()
    root.call_deferred("add_child", instance)

func _process(_dt: float) -> bool:
    frames += 1
    if frames == 4:
        if instance == null or not instance.is_inside_tree():
            push_error("GUNRYAK_SCENE_FAIL: main scene did not load")
            quit(1)
            return false
        instance.set_process(false)
        instance.call("_start")
        var model = instance.sim
        var leader: Dictionary=model.find_unit(0)
        if not leader.has("mind") or model.find_unit(2)["mind"]["confidence"]<=leader["mind"]["confidence"]:
            push_error("GUNRYAK_SCENE_FAIL: general psychology or personality initialization missing")
            quit(1)
            return false
        # Isolated fixture: never alter the real battle or its random state.
        var mind_model=preload("res://scripts/general_mind.gd")
        var sample: Dictionary=leader.duplicate(true)
        sample["surrounded"]=true
        sample["mind"]=mind_model.record(sample,{},"방어","통제된 검사: 포위",1.0)
        sample["mind"]=mind_model.update(sample,1.0)
        if sample["mind"]["mood"]!="위기감" or sample["mind"]["observed"]!="현재 시야 내 적 없음" or sample["mind"]["action"]!="방어":
            push_error("GUNRYAK_SCENE_FAIL: reported decision or crisis state incorrect")
            quit(1)
            return false
        var trust: float=float(sample["mind"]["trust"])
        mind_model.order(sample,"거부: 검사",1.1,true)
        if float(sample["mind"]["trust"])>=trust or sample["mind"]["last_order"]!="거부: 검사":
            push_error("GUNRYAK_SCENE_FAIL: command reaction not recorded")
            quit(1)
            return false
        var aggressive: Dictionary=model.find_unit(2).duplicate(true)
        aggressive["mind"]["confidence"]=90.0
        aggressive["mind"]["stress"]=12.0
        var confident: float=mind_model.initiative_threshold(aggressive)
        aggressive["mind"]["confidence"]=25.0
        aggressive["mind"]["stress"]=90.0
        var anxious: float=mind_model.initiative_threshold(aggressive)
        if confident>=anxious or confident<1.12 or anxious>1.55:
            push_error("GUNRYAK_SCENE_FAIL: psychological initiative threshold incorrect")
            quit(1)
            return false
        if sample["mind"]["proposal"]!="지원":
            push_error("GUNRYAK_SCENE_FAIL: encircled general did not request support")
            quit(1)
            return false
        var after_refusal: float=float(sample["mind"]["trust"])
        mind_model.acknowledge(sample,1.2)
        if float(sample["mind"]["trust"])<=after_refusal:
            push_error("GUNRYAK_SCENE_FAIL: acknowledgement did not restore trust")
            quit(1)
            return false
        print("GENERAL_PERSONALITY_PASS: bounded initiative, support request, trust response")
        # Separate sim verifies report dispatch, receipt, actual execution and end.
        var fixture=preload("res://scripts/war_sim.gd").new()
        fixture.tactical_enabled=true
        fixture.start()
        fixture.turn=6
        fixture.battle_time=80.0
        fixture.situation_reports.append({"id":901,"unit_id":0,"title":"검사 보고","kind":"전선 압박","status":"미대응"})
        if not fixture.respond_situation(901,"사수"):
            push_error("GUNRYAK_SCENE_FAIL: report dispatch failed")
            quit(1)
            return false
        var letter: Dictionary=fixture.couriers.back()
        var actor: Dictionary=fixture.find_unit(0)
        fixture._deliver_tactical(actor,letter)
        if fixture.situation_reports[0]["status"]!="명령 수령" or int(letter["report_id"])!=901:
            push_error("GUNRYAK_SCENE_FAIL: report receipt not linked")
            quit(1)
            return false
        fixture._decide(actor)
        fixture._update_response_outcomes()
        if fixture.situation_reports[0]["status"]!="실행 중":
            push_error("GUNRYAK_SCENE_FAIL: actual tactical action not tracked")
            quit(1)
            return false
        actor["casualties_taken"]=7.0
        actor["damage_dealt"]=11.0
        fixture.battle_time=105.0
        fixture._update_response_outcomes()
        if fixture.situation_reports[0]["status"]!="실행 종료" or int(fixture.situation_reports[0]["loss_delta"])!=7 or int(fixture.situation_reports[0]["damage_delta"])!=11:
            push_error("GUNRYAK_SCENE_FAIL: tactical execution result invalid")
            quit(1)
            return false
        # The representative rendering uses actual tactical slots, without
        # changing troop count or the underlying formation.
        var view_model=preload("res://scripts/front_view.gd")
        var leaders: Array[Dictionary]=[]
        for side in range(2):
            for id in model.command_ids(side): leaders.append(model.find_unit(id))
        var sectors: Array[Dictionary]=view_model.summarize(model,false)
        var blue: int=0
        var red: int=0
        for sector in sectors:
            blue+=int(sector["own"])
            red+=int(sector["enemy"])
        if sectors.size()!=3 or blue!=model.total_troops(0) or red!=model.total_troops(1):
            push_error("GUNRYAK_SCENE_FAIL: sector manpower does not reconcile")
            quit(1)
            return false
        var actual: Array[Vector2]=model.formation_slots(leader)
        var visible: Array[Vector2]=model.representative_slots(leader,72)
        if visible.size()!=72 or actual.is_empty():
            push_error("GUNRYAK_SCENE_FAIL: formation presentation missing")
            quit(1)
            return false
        for i in range(visible.size()):
            if visible[i].distance_to(actual[i%actual.size()])>12.0 or model.terrain_at(visible[i])=="하천":
                push_error("GUNRYAK_SCENE_FAIL: representative soldier escaped actual anchor")
                quit(1)
                return false
        var local: Array[Vector2]=[Vector2(18,0),Vector2(50,0)]
        if view_model.local_target(Vector2.ZERO,local,30.0)!=Vector2(18,0) or view_model.local_target(Vector2.ZERO,local,10.0)!=Vector2.INF:
            push_error("GUNRYAK_SCENE_FAIL: visual contact range incorrect")
            quit(1)
            return false
        if view_model.advance_toward_contact(Vector2.ZERO,Vector2(18,0),1.0,"보병")!=Vector2(9,0):
            push_error("GUNRYAK_SCENE_FAIL: visual contact displacement incorrect")
            quit(1)
            return false
        var old_speed: float=instance.game_speed
        var old_time: float=model.battle_time
        instance.call("_advance_highlight")
        if not instance.highlight_active or instance.game_speed!=16.0 or model.battle_time!=old_time:
            push_error("GUNRYAK_SCENE_FAIL: highlight start skipped simulation")
            quit(1)
            return false
        # Run fixed steps in the real scene. Cancel restores the old speed.
        instance.call("_process",0.1)
        if model.battle_time<=old_time or model.step_count<1:
            push_error("GUNRYAK_SCENE_FAIL: highlight did not advance real fixed steps")
            quit(1)
            return false
        instance.call("_stop_highlight","검사 종료",true)
        if instance.highlight_active or instance.game_speed!=old_speed or not model.paused:
            push_error("GUNRYAK_SCENE_FAIL: highlight did not restore speed and pause")
            quit(1)
            return false
        model.paused=false
        var geography=preload("res://scripts/war_sim.gd").new()
        geography.set_long_operation(true)
        var signature: String=str(geography.forests)
        for scenario in range(1,5):
            if not geography.set_scenario(scenario) or str(geography.forests)==signature:
                push_error("GUNRYAK_SCENE_FAIL: repeated battlefield geography")
                quit(1)
                return false
            signature=str(geography.forests)
        print("FRONT_OVERHAUL_PASS: real anchors, reconciled sectors, distinct maps and fixed-step highlights")
        print("COMMAND_OUTCOME_PASS")
        print("GENERAL_MIND_FIXTURE_PASS")
        # Accelerated playback preserves the 25-minute operation clock.
        instance.game_speed=4.0
    if frames > 4 and instance != null and instance.is_inside_tree():
        for index in range(60):
            instance.call("_process", 0.1)
            ticks += 1
            var sim = instance.get("sim")
            if ticks == 120:
                var leader: Dictionary=sim.find_unit(0)
                var m: Dictionary=leader["mind"]
                if float(m["decision_at"])<=0.0 or str(m["action"])!=str(leader["action"]) or str(m["reason"])!=str(leader["reason"]) or m["history"].is_empty():
                    push_error("GUNRYAK_SCENE_FAIL: real decision is not reflected in general report")
                    quit(1)
                    return false
                instance.call("_refresh_mind_report")
                if not instance.mind_report.text.contains(str(leader["reason"])):
                    push_error("GUNRYAK_SCENE_FAIL: live general dossier omitted decision reason")
                    quit(1)
                    return false
                print("GENERAL_MIND_LIVE_PASS")
            if ticks % 120 == 0:
                var errors: Array = sim.call("validate_state")
                if not errors.is_empty():
                    push_error("GUNRYAK_SCENE_FAIL: " + str(errors[0]))
                    quit(1)
                    return false
            if bool(sim.get("finished")):
                var result: String = str(sim.get("result"))
                if result.is_empty():
                    push_error("GUNRYAK_SCENE_FAIL: battle ended without result")
                    quit(1)
                else:
                    print("GUNRYAK_SCENE_PASS: battle completed in %d simulated ticks: %s" % [ticks, result])
                    quit(0)
                return false
            if ticks >= LIMIT_TICKS:
                push_error("GUNRYAK_SCENE_FAIL: battle did not finish before limit")
                quit(1)
                return false
    if frames >= 300:
        push_error("GUNRYAK_SCENE_FAIL: scene watchdog expired")
        quit(1)
    return false
