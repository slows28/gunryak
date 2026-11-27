extends SceneTree
## Mugong's first observed daytime infantry clash, at normal battle speed.
## Add "-- close" for the player's maximum wheel zoom. A movie uses 24 fps.
const Main = preload("res://main.tscn")
const Exchange = preload("res://scripts/infantry_exchange.gd")

func _initialize() -> void:
    call_deferred("_replay")

func _replay() -> void:
    var game = Main.instantiate()
    root.add_child(game)
    game.set_process(false)
    game._campaign_mode(true)
    game.campaign.save_path = "user://infantry-contact-review.json"
    game._begin_campaign()
    for chapter in range(1,11):
        game.campaign.state.reward = chapter
        if not game.campaign.claim(game.campaign.choices()[0]):
            game._quit_game(1)
            return
    game._launch_campaign_battle(11)
    game._start()
    var sim = game.sim
    var focus: Dictionary = {}
    while sim.step_count < 620 and focus.is_empty():
        sim.step(0.1)
        if sim.step_count < 80: continue
        game._update_contact_fronts(0.1)
        if sim.night_depth() > 0.15: continue
        for fight in game._recent_fights():
            var fx: Dictionary = fight.fx
            if fx.kind != "근접" or not fx.has("defender_id"): continue
            if sim.find_unit(fx.attacker_id).type == "보병" and sim.find_unit(fx.defender_id).type == "보병":
                focus = fight
                break
    if focus.is_empty():
        push_error("No visible infantry clash in Mugong")
        game._quit_game(1)
        return
    var hit: Dictionary = focus.fx
    var pair := [int(hit.attacker_id), int(hit.defender_id)]
    var close := "close" in OS.get_cmdline_user_args()
    var graphical := DisplayServer.get_name() != "headless"
    game._select_friendly_combatant(hit)
    game.camera_center = focus.point
    game.camera_zoom = 0.76
    game._clamp_camera()
    var camera: Vector2 = game.camera_center
    var cursor: Vector2 = game.MAP_TOP_LEFT + game.MAP_SIZE * 0.5 + Vector2(42,23)
    var anchor: Vector2 = game._world_mouse(cursor)
    game._change_zoom(9.0,cursor)
    var camera_ok: bool = is_equal_approx(game.camera_zoom,4.25) and anchor.is_equal_approx(game._world_mouse(cursor))
    game.camera_center = camera
    game.camera_zoom = 0.76
    game._clamp_camera()
    game.game_speed = 1.0
    game.fog_enabled = true
    Input.warp_mouse(Vector2(470,390))
    game._refresh_hud()
    var start: int = sim.step_count
    print("CONTACT ", start, " ", sim.find_unit(pair[0]).name, " ", sim.find_unit(pair[1]).name, " ", focus.point)
    var seen := {}
    var counts := [0,0,0,0]
    var tick := -1
    for frame in 432:
        if frame == 72:
            game._change_zoom((4.25 if close else 2.55) - game.camera_zoom)
        game._process(1.0 / 24.0)
        if graphical: await RenderingServer.frame_post_draw
        if sim.step_count == tick: continue
        tick = sim.step_count
        for id: int in pair:
            var actions: Dictionary = game.infantry_feet.get(id,{}).get("exchanges",{})
            for soldier: int in actions:
                var action: Dictionary = actions[soldier]
                if action.enemy not in pair: continue
                var key := Vector3i(id,soldier,roundi(action.at*1000.0))
                if seen.has(key): continue
                seen[key] = true
                counts[action.role] += 1
                if action.role == Exchange.Role.FILL:
                    var screen: Vector2 = game.MAP_TOP_LEFT + game.MAP_SIZE * 0.5 + (Vector2(action.root)-game.camera_center)*game.camera_zoom
                    print("RELIEF frame=", frame, " point=", screen.round(), " world=", action.root)
    print("FINISH ", sim.step_count, " day=", sim.turn, " paused=", sim.paused, " troops=",
        roundi(sim.find_unit(pair[0]).troops), "/", roundi(sim.find_unit(pair[1]).troops),
        " press/hold/yield/fill=", counts)
    var passed: bool = sim.step_count > start + 36 and not sim.paused and counts.min() > 0 and camera_ok
    print("GUNRYAK_INFANTRY_REPLAY_PASS" if passed else "GUNRYAK_INFANTRY_REPLAY_FAIL")
    game._quit_game(0 if passed else 1)
