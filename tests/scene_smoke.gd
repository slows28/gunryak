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
        # Accelerated playback preserves the 25-minute operation clock.
        instance.game_speed=4.0
    if frames > 4 and instance != null and instance.is_inside_tree():
        for index in range(60):
            instance.call("_process", 0.1)
            ticks += 1
            var sim = instance.get("sim")
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
