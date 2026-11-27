extends Node
## One real-time crossfade follows the music independently of simulation speed.
const TRACKS := {
    "council": preload("res://assets/audio/river_watch.ogg"),
    "road": preload("res://assets/audio/road.ogg"),
    "night": preload("res://assets/audio/night.ogg"),
    "contact": preload("res://assets/audio/contact.ogg"),
    "peril": preload("res://assets/audio/peril.ogg"),
    "homecoming": preload("res://assets/audio/homecoming.ogg"),
    "ashes": preload("res://assets/audio/ashes.ogg"),
}
const LEVEL := {"council":-12.0,"road":-13.0,"night":-15.0,"contact":-14.0,"peril":-15.0,"homecoming":-12.0,"ashes":-14.0}
const FADE_SECONDS:=2.4
var players: Dictionary={}
var weights: Dictionary={}
var origins: Dictionary={}
var selected: String=""
var elapsed:=0.0
var enabled:=true
var battle_hold:=0.0
var alarm_hold:=0.0

func _ready() -> void:
    for key: String in TRACKS:
        var player:=AudioStreamPlayer.new()
        player.stream=TRACKS[key]
        player.volume_db=-80.0
        add_child(player)
        players[key]=player
        weights[key]=0.0
    select("council")

func reset_field() -> void:
    battle_hold=0.0
    alarm_hold=0.0

func battlefield(sim,seconds: float) -> String:
    # Contact and HQ reports use confirmed observations. Unseen movement
    # and the camera's spectator/fog toggle never change the score.
    var engaged:=false
    for hit in sim.combat_contacts.values():
        if sim.player_can_see(hit["to"]) and sim.player_can_see(hit["from"]):
            engaged=true
            break
    battle_hold=8.0 if engaged else maxf(0.0,battle_hold-seconds)
    alarm_hold=6.0 if sim.headquarters[0]["occupation"]>0 else maxf(0.0,alarm_hold-seconds)
    if alarm_hold>0: return "peril"
    if battle_hold>0: return "contact"
    return "night" if sim.night_depth()>(0.35 if selected=="night" else 0.55) else "road"

func select(key: String) -> void:
    if key==selected: return
    selected=key
    origins=weights.duplicate()
    elapsed=0.0
    var player: AudioStreamPlayer=players[key]
    AudioServer.lock()
    if not player.playing and not player.stream_paused:
        player.play()
        player.stream_paused=not enabled
    AudioServer.unlock()

func set_enabled(value: bool) -> void:
    enabled=value
    AudioServer.lock()
    for player: AudioStreamPlayer in players.values():
        if player.playing or player.stream_paused: player.stream_paused=not enabled
    AudioServer.unlock()

func _process(delta: float) -> void:
    if not enabled or elapsed>=FADE_SECONDS: return
    elapsed=minf(FADE_SECONDS,elapsed+delta)
    var blend:=smoothstep(0,FADE_SECONDS,elapsed)
    # The audio driver mixes on its own thread. Apply each frame's gains and
    # release outgoing playbacks together between mix buffers.
    AudioServer.lock()
    for key: String in players:
        var player: AudioStreamPlayer=players[key]
        if key!=selected and origins[key]==0.0:
            if player.playing: player.stop()
            continue
        var weight:=lerpf(origins[key],1.0 if key==selected else 0.0,blend)
        weights[key]=weight
        player.volume_db=LEVEL[key]+linear_to_db(maxf(0.0001,sqrt(weight)))
        if elapsed>=FADE_SECONDS and key!=selected and player.playing: player.stop()
    AudioServer.unlock()
