extends SceneTree
## Capture each cue after changing real game state. The optional WAV contains
## the actual master mix, including the transitions.
const Main=preload("res://main.tscn")
var game
var tap:=AudioEffectCapture.new()
var samples:=PackedVector2Array()
var errors:=0
var record:=false
func _initialize(): call_deferred("_run")
func expect(ok: bool,label: String):
    if not ok: push_error(label);errors+=1

func listen(key: String) -> void:
    game._update_score(0.2)
    expect(game.score.selected==key,"score state "+key)
    var player: AudioStreamPlayer=game.score.players[key]
    expect(player.stream.loop==(key not in ["homecoming","ashes"]),"loop property "+key)
    tap.clear_buffer()
    await create_timer(5.0 if record else 3.2).timeout
    var frames:=tap.get_buffer(tap.get_frames_available())
    expect(not frames.is_empty(),"mixed audio for "+key)
    var energy:=0.0
    var peak:=0.0
    for i in frames.size():
        var frame:=frames[i]
        peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
        if i>=frames.size()/2: energy+=frame.length_squared()
    expect(peak<0.99 and energy/maxi(1,frames.size())>0.0000001,"audible and unclipped "+key)
    expect(is_equal_approx(game.score.weights[key],1.0),"crossfade completes "+key)
    print("CUE ",key," starts ",float(samples.size())/AudioServer.get_mix_rate()," frames ",frames.size()," peak ",peak)
    if record: samples.append_array(frames)

func _run():
    record=not OS.get_cmdline_user_args().is_empty()
    game=Main.instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false)
    game.hide()
    tap.buffer_length=8.0
    AudioServer.add_bus_effect(0,tap)
    await listen("council")
    game._leave_title(0)
    game._start()
    var sim=game.sim
    sim.battle_time=0.0
    await listen("road")
    sim.battle_time=sim.turn_duration()*0.7
    var hidden: Vector2=sim.field_size-Vector2(15,15)
    sim.combat_contacts={999:{"from":hidden,"to":hidden}}
    expect(not sim.player_can_see(hidden),"unobserved contact fixture")
    await listen("night")
    var ally: Dictionary=sim.find_unit(0)
    sim.combat_contacts={0:{"from":ally.pos,"to":ally.pos+Vector2(8,0)}}
    await listen("contact")
    sim.combat_contacts.clear()
    game._update_score(0.2)
    expect(game.score.selected=="contact","a short gap between blows keeps the cue")
    sim.headquarters[0].occupation=1.0
    await listen("peril")
    game.order_view.show()
    game._update_score(0.2)
    expect(game.score.selected=="council","a council takes priority over field music")
    game.order_view.hide()
    sim._finish("북벌 — 승리")
    await listen("homecoming")
    game._leave_title(0)
    game._start()
    sim.order_retreat()
    await listen("ashes")
    game._show_title()
    game._update_score(0.2)
    expect(game.score.selected=="council","return to title clears the result score")
    if record:
        var pcm:=PackedByteArray()
        pcm.resize(samples.size()*4)
        for i in samples.size():
            pcm.encode_s16(i*4,roundi(clampf(samples[i].x,-1,1)*32767))
            pcm.encode_s16(i*4+2,roundi(clampf(samples[i].y,-1,1)*32767))
        var wav:=AudioStreamWAV.new()
        wav.stereo=true
        wav.format=AudioStreamWAV.FORMAT_16_BITS
        wav.mix_rate=roundi(AudioServer.get_mix_rate())
        wav.data=pcm
        expect(wav.save_to_wav(OS.get_cmdline_user_args()[0])==OK,"write soundtrack preview")
    AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
    print("GUNRYAK_FIELD_SCORE_PASS" if errors==0 else "GUNRYAK_FIELD_SCORE_FAIL")
    game._quit_game(0 if errors==0 else 1)
