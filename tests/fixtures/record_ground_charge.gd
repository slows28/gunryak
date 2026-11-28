extends SceneTree
## Reproducible 30-frame-per-simulation-second capture on the playable terrain range.
## GROUND_CAPTURE is an optional existing directory for the frames.
const Main = preload("res://main.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = Main.instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false)
    game._leave_title(game.sim.TRAINING_SCENARIO)
    var sim = game.sim
    sim.rng.seed = 137
    sim.signature_seed = 137
    var folder := OS.get_environment("GROUND_CAPTURE")
    if not folder.is_empty():
        var map = game.order_view
        map._select(2)
        map._choose_action(2)
        for ground in ["평지", "습지"]:
            map.destination = sim.training_sites()[ground]
            map.has_destination = true
            map._update_destination()
            print("ORDER ", ground, " ", map.destination_label.text.replace("\n"," / "))
            await process_frame
            await RenderingServer.frame_post_draw
            if root.get_texture().get_image().save_png(folder.path_join("orders-plain.png" if ground == "평지" else "orders-marsh.png")) != OK:
                game._quit_game(1)
                return
        map.drafts.clear()
    var rider: Dictionary = sim.find_unit(2)
    var foot: Dictionary = sim.find_unit(3)
    for unit in sim.units:
        if unit.id not in [2, 3]: unit.troops = 0.0
    rider.pos = Vector2(585,750)
    rider.facing = Vector2.RIGHT
    rider.formation = "봉시진"
    rider.action = "공격 지속"
    foot.pos = Vector2(760,750)
    foot.facing = Vector2.LEFT
    foot.formation = "횡대"
    foot.action = "방어"
    for unit in [rider,foot]:
        unit.goal = foot.pos
        unit.ai_cooldown = 12.0
        unit.next_formation = ""
        unit.fatigue = 0.0
        unit.cohesion = 92.0
        unit.morale = 92.0
    game._start()
    game._on_unit_selected(sim.command_ids(0).find(2))
    game.camera_center = Vector2(708,750)
    game.camera_zoom = 3.6
    game._clamp_camera()
    var frame := 0
    var impact_frame := -1
    while frame < 85:
        game._process(sim.operation_scale() / 30.0)
        if impact_frame < 0 and rider.charges > 0:
            impact_frame = frame
            var event: Dictionary = sim.combat_contacts.get(2,{})
            print("CONTACT frame=", frame, " shock=", event.shock, " gap=", Vector2(event.visual_from).distance_to(event.visual_to), " recoil=", event.get("recoil",Vector2.ZERO), " ground=", sim.terrain_at(event.visual_to))
        game.map_layer.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        if not folder.is_empty():
            var path := folder.path_join("frame-%03d.jpg" % frame)
            if root.get_texture().get_image().save_jpg(path,0.86) != OK:
                game._quit_game(1)
                return
        if impact_frame >= 0 and frame >= impact_frame + 24: break
        frame += 1
    print("CAPTURE impact=",impact_frame," end=",frame," day=",sim.turn)
    game._quit_game(0 if impact_frame >= 0 else 1)
