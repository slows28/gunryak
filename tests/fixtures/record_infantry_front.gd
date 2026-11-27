extends SceneTree
## Run with Godot 4.7.2 against the 8998ca8 checkout, using this script's
## absolute path. Pass "-- /path/to/infantry-front-8998ca8.state".
const Main = preload("res://main.tscn")

func _initialize() -> void:
    call_deferred("_record")

func _record() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 1:
        quit(2)
        return
    var game = Main.instantiate()
    root.add_child(game)
    game.set_process(false)
    game._leave_title(1)
    game._start()
    for tick in 406: game.sim.step(0.1)
    var fields := {}
    for property in game.sim.get_property_list():
        if (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0: continue
        var value = game.sim.get(property.name)
        if typeof(value) != TYPE_OBJECT: fields[property.name] = value
    fields["-rng"] = game.sim.rng.state
    var file := FileAccess.open_compressed(args[0],FileAccess.WRITE,FileAccess.COMPRESSION_ZSTD)
    if file == null:
        game._quit_game(1)
        return
    file.store_var(fields)
    file.close()
    game._quit_game()
