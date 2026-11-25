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
