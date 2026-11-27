extends SceneTree
## Measure the game's mixed output. The same test can use a real audio driver.
const MAIN_SCENE=preload("res://main.tscn")
var game
var tap:=AudioEffectCapture.new()
var failures:=0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if ok: print("PASS ",message)
    else:
        failures+=1
        push_error(message)

func _sample(label: String, seconds: float) -> float:
    tap.clear_buffer()
    await create_timer(seconds).timeout
    var frames:=tap.get_frames_available()
    if frames<=0:
        check(false,"no audio frames for "+label)
        return 0.0
    var data:=tap.get_buffer(frames)
    var peak:=0.0
    var squared:=0.0
    for frame in data:
        peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
        squared+=(frame.x*frame.x+frame.y*frame.y)*0.5
    print("MIX ",label," frames=",frames," rms=",snappedf(sqrt(squared/frames),0.000001)," peak=",snappedf(peak,0.000001))
    check(peak<0.99,"unclipped output "+label)
    return peak

func _run() -> void:
    game=MAIN_SCENE.instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false)
    game._leave_title(0)
    game._start()
    var sim=game.sim
    game.hide()
    tap.buffer_length=3.0
    AudioServer.add_bus_effect(0,tap)
    print("AUDIO_DRIVER ",AudioServer.get_driver_name()," rate=",AudioServer.get_mix_rate())
    check(await _sample("ambient",0.85)>0.00005,"ambient music reaches the master bus")
    check(game.score.players["council"].stream is AudioStreamOggVorbis and game.score.players["council"].stream.loop and game.score.players["council"].stream.get_length()>90.0,"full chamber score loops in the game")
    game.score.set_enabled(false)
    await create_timer(0.15).timeout
    var point: Vector2=sim.find_unit(0)["pos"]
    game.camera_center=point
    game.fog_enabled=true
    var previous: float=-1.0
    for kind in ["근접","화살","돌격"]:
        sim.battle_time+=1.0
        sim.visual_effects.clear()
        sim.visual_effects.append({"from":point,"to":point,"kind":kind,"time":sim.battle_time})
        var cursor: int=game.combat_audio_cursor
        if kind=="화살":
            game._update_audio_and_warning()
            check(game.combat_audio_cursor==cursor,"drawing the bow is silent before release")
            sim.battle_time+=0.25
        if kind=="근접":
            var unseen: Vector2=sim.field_size-Vector2(20,20)
            sim.battle_time+=0.1
            sim.visual_effects.append({"from":unseen,"to":unseen,"kind":"돌격","time":sim.battle_time})
            check(not sim.player_can_see(unseen),"second simultaneous fight is outside allied vision")
        game._update_audio_and_warning()
        check(game.combat_audio_cursor==cursor+1,"visible "+kind+" reaches an audio player")
        var channel: AudioStreamPlayer=game.combat_players[cursor%game.combat_players.size()]
        var first_take:=channel.stream
        game._play_combat_audio({"kind":kind,"from":point,"to":point})
        check(game.combat_audio_cursor==cursor+1,"simultaneous impacts respect real-time spacing "+kind)
        var peak:=await _sample(kind,0.74)
        game._play_combat_audio({"kind":kind,"from":point,"to":point})
        check(game.combat_players[(cursor+1)%game.combat_players.size()].stream!=first_take,"next audible event uses another performance "+kind)
        await create_timer(0.62).timeout
        check(peak>0.001 and not is_equal_approx(peak,previous),"distinct audible effect "+kind)
        previous=peak
    sim.visual_effects.clear()
    var rider: Dictionary = sim.find_unit(2)
    rider["pos"] = point
    rider["charge"] = 45.0
    var cursor: int = game.combat_audio_cursor
    game._update_audio_and_warning()
    check(game.combat_audio_cursor == cursor + 1 and await _sample("gallop", 0.74) > 0.001,
        "an approaching visible charge has an audible hoofbeat before contact")
    rider["charge"] = 0.0
    sim.battle_time += 0.1
    for kind in ["근접", "돌격", "근접"]:
        sim.visual_effects.append({"from":point, "to":point, "kind":kind, "time":sim.battle_time})
    game._update_audio_and_warning()
    var impact: AudioStreamPlayer = game.combat_players[(cursor + 1) % game.combat_players.size()]
    check(impact.stream in game.combat_sounds["돌격"] and impact.stream not in game.combat_sounds["질주"],
        "first contact is audible above simultaneous melee with a distinct impact")
    await create_timer(0.65).timeout
    sim.visual_effects.clear()
    sim.battle_time+=1.0
    sim.urgent_deliveries+=1
    game._update_audio_and_warning()
    check(await _sample("messenger",0.38)>0.001,"urgent messenger arrival sounds")
    game._update_audio_and_warning()
    check(await _sample("same report",0.20)<0.00001,"one report sounds only once")
    var raider: Dictionary=sim.find_unit(3)
    for u in sim.units: u["pos"]=sim.field_size*0.5
    raider["pos"]=sim.headquarters[0]["pos"]
    sim._update_headquarters(0.1)
    game._update_audio_and_warning()
    check(await _sample("headquarters",0.45)>0.001,"actual headquarters occupation raises an audible alarm")
    game._update_audio_and_warning()
    check(await _sample("same siege",0.20)<0.00001,"continuous siege does not repeat the alarm each frame")
    game._toggle_sound()
    sim.urgent_deliveries+=1
    game._update_audio_and_warning()
    game._play_combat_audio({"from":point,"to":point,"kind":"근접"})
    check(await _sample("muted",0.4)<0.00001,"mute silences music, combat and alerts")
    game._toggle_sound()
    check(await _sample("restored",0.8)>0.00005,"unmuting restores the background music")
    AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
    if failures==0: print("GUNRYAK_AUDIO_PASS")
    game._quit_game(1 if failures else 0)
