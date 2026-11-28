extends SceneTree

const Main=preload("res://main.tscn")
var game
var failed:=false
var folder:=""

func _initialize() -> void:
    call_deferred("_play")

func check(ok: bool, message: String) -> void:
    if not ok:
        failed=true
        push_error(message)

func capture(filename: String) -> void:
    if folder.is_empty(): return
    game.map_layer.queue_redraw()
    game.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(folder+"/"+filename+".png")==OK,"save "+filename)

func press_v() -> void:
    var key:=InputEventKey.new()
    key.keycode=KEY_V
    key.pressed=true
    game._unhandled_key_input(key)

func _play() -> void:
    var args:=OS.get_cmdline_user_args()
    if not args.is_empty():
        folder=args[0]
        DirAccess.make_dir_recursive_absolute(folder)
    game=Main.instantiate()
    root.add_child(game)
    game.set_process(false)
    check(game.standalone_difficulty.selected==1,"default standalone uses normal reconnaissance")
    for level in [1,0,2]:
        game.standalone_difficulty.select(level)
        game._leave_title(5)
        var sim=game.sim
        var foe: Dictionary=sim.find_unit(sim.command_ids(1)[0])
        var own: Dictionary=sim.find_unit(0)
        var original: Vector2=foe.pos
        check(not sim.player_sees_enemy(foe),"opposing camp outside allied observation")
        check(game._visible_unit(foe)==(level==0),"opening deployment uses selected difficulty")
        await capture("orders-%d"%level)
        game._start()
        game._show_enemy_roster()
        game.camera_zoom=game._overview_zoom()
        game.camera_center=sim.field_size*0.5
        game._clamp_camera()
        await capture("field-%d"%level)
        if level==0:
            check(not game.fog_button.disabled and not game.fog_enabled and game._visible_unit(foe),"easy permits full daytime view")
            check(game.enemy_watch_button.visible,"easy exposes the opponent watch control")
            game.enemy_watch_button.button_pressed=true
            game._toggle_enemy_watch()
            var overlay: Image=game.visibility_texture.get_image()
            var pixel: Vector2i=Vector2i(foe.pos/sim.field_size*Vector2(overlay.get_size()))
            check(overlay.get_pixelv(pixel).a>0.1 and game._show_enemy_watch(),"enemy observation marks a location occupied by its corps")
            await capture("field-enemy-watch")
            press_v()
            check(not game.enemy_watch_button.visible and not game._show_enemy_watch(),"recon mode clears opposing coverage")
            check(game.fog_enabled and not game._visible_unit(foe),"easy may opt into reconnaissance")
            press_v()
        else:
            press_v()
            game._toggle_fog(false)
            check(not game.enemy_watch_button.visible and not game._show_enemy_watch(),"opponent watch is unavailable")
            check(game.fog_button.disabled and game.plan_fog.disabled and game.plan_fog.button_pressed and game.fog_enabled,"both controls and V enforce the lock")
            check(game.enemy_strength.text=="정찰 제한" and game.enemy_list.get_item_metadata(0)==-1,"no live enemy roster or troop total")
            foe.pos=own.pos+Vector2(10,0)
            game._refresh_hud()
            game._inspect_enemy_row(0)
            check(game.observed_enemy_id==foe.id and game._visible_unit(foe),"friendly observation reveals a real contact")
            foe.pos=original
            game._refresh_hud()
            check(game.observed_enemy_id==-1 and game.enemy_list.get_item_metadata(0)==-1,"contact clears when sight is lost")
            var gate: Dictionary=sim.structures[0]
            gate.hp=0.0
            sim._log(str(gate.name)+" 파괴: 통행 가능")
            game._refresh_battle_feed()
            check(not game.event_label.text.contains(gate.name),"unseen gate change stays out of the battle feed")
            game.order_view.survey_key="성문"
            game.order_view._refresh_survey()
            check(game.order_view.survey_detail.text.contains("미확인"),"survey hides remote gate damage")
        sim.battle_time=sim.turn_duration()*0.7
        game._update_night_watch()
        press_v()
        check(game.fog_enabled and game.fog_button.disabled,"night watch remains binding")
        sim.battle_time=sim.turn_duration()
        game._update_night_watch()
        check(game.fog_enabled==(level>0),"dawn restores only permitted vision")
    game._begin_campaign()
    for level in [0,1,2]:
        game.campaign.reset()
        game.campaign.save_path="user://visibility-test.json"
        game.strategy_view.refresh()
        game.strategy_view.difficulty.select(level)
        game.strategy_view.difficulty.item_selected.emit(level)
        check(game._launch_campaign_battle(1),"launch campaign from preparation")
        check(game.battle_difficulty==level and game.fog_enabled==(level>0),"campaign setting applied before orders")
    if not failed: print("BATTLE_VISIBILITY_PASS")
    game._quit_game(1 if failed else 0)
