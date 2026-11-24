extends SceneTree
## Scene load sanity test -- tests rendering-node code in a headless run.
## Run: godot --headless --path . --script res://tests/scene_smoke.gd
const MAIN_SCENE = preload("res://main.tscn")
var frames: int = 0
var instance: Control

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
        instance.call("_start")
    if frames >= 180:
        if instance == null or not instance.is_inside_tree():
            push_error("GUNRYAK_SCENE_FAIL: main scene exited unexpectedly")
            quit(1)
        else:
            print("GUNRYAK_SCENE_PASS: 180 engine frames; scene instantiated")
            quit(0)
    return false
