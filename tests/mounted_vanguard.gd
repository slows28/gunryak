extends SceneTree

const Main = preload("res://main.tscn")
const PIN = Vector2(800,760)
var game: Control
var sim
var directory := ""
var baseline := false
var failed := false

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if ok or baseline: return
    failed=true
    push_error(label)

func place(unit: Dictionary, point: Vector2, troops: int) -> void:
    unit.pos=point
    unit.goal=point
    unit.troops=float(troops)
    unit.facing=Vector2.RIGHT if unit.side==0 else Vector2.LEFT
    unit.cohesion=75.0
    unit.morale=78.0
    unit.formation="횡대"
    unit.next_formation=""

func setup(side: int, rating: int, mission: String="공격") -> Array:
    sim.reset()
    sim.set_scenario(sim.TRAINING_SCENARIO)
    sim.tactical_enabled=true
    sim.enemy_strategy_enabled=false
    var own: Array=sim.command_ids(side)
    var opp: Array=sim.command_ids(1-side)
    var horse: Dictionary=sim.find_unit(own[2])
    var foot: Dictionary=sim.find_unit(own[0])
    var foe: Dictionary=sim.find_unit(opp[0])
    var axis:=Vector2.RIGHT if side==0 else Vector2.LEFT
    for u in sim.units:
        u.troops=0.0
        u.ai_cooldown=1000.0
    place(horse,PIN,3200)
    place(foot,PIN-axis*160+Vector2(0,35),3100)
    place(foe,PIN+axis*150,4900)
    sim.outposts[0].pos=PIN
    sim._update_outposts(sim.capture_duration())
    check(sim.outposts[0].owner==side,"corps physically captures the station")
    if side==0:
        check(sim.issue_map_order(horse.id,mission,PIN),"accepted player order")
    else:
        horse.mission="중앙 진격"
    game._start()
    horse.judgment=float(rating)
    horse.obedience="명령 엄수"
    horse.ai_cooldown=0.0
    foe.goal=foe.pos
    foot.goal=foot.pos
    return [horse,foot,foe,axis]

func capture(label: String, horse: Dictionary) -> void:
    if directory.is_empty(): return
    game.selected_id=horse.id
    game._select_unit()
    game.camera_center=PIN+Vector2(68,-50) if label=="wing" else PIN+Vector2(55,0)
    game.camera_zoom=1.65
    game._clamp_camera()
    game.render_clock=sim.battle_time
    game._refresh_hud()
    game.map_layer.queue_redraw()
    game.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(directory+"/"+label+".png")==OK,"save battlefield frame")

func field_run(side: int) -> void:
    var actors:=setup(side,88)
    var horse: Dictionary=actors[0]
    var foot: Dictionary=actors[1]
    var foe: Dictionary=actors[2]
    var held:=true
    var drift:=0.0
    for tick in 38:
        sim.step(0.1)
        if not directory.is_empty(): game._update_contact_fronts(0.1)
        held=held and horse.action=="기병 대기"
        drift=maxf(drift,PIN.distance_to(horse.pos))
    print("STATION side=",side," held=",held," travel=",snappedf(drift,0.1)," action=",horse.action," reason=",horse.reason)
    check(held and drift<15,"outnumbered first arrival waits at its own station")
    if side==0: await capture("station",horse)
    # Release the approaching infantry while the assigned cavalry keeps its original orders.
    foot.goal=foe.pos
    foot.action="교전"
    var first_contact:=-1
    var first_sortie:=-1
    var first_hit:=-1
    var chosen:=-1
    var outside_lag:=0.0
    var most_turn:=0.0
    var previous_center: Vector2=horse.pos
    for tick in 420:
        sim.step(0.1)
        if not directory.is_empty(): game._update_contact_fronts(0.1)
        elif not baseline: game._step_riders(0.1)
        if not baseline and horse.action in ["협동 우회","돌파"]:
            var tracks: Dictionary=game.rider_tracks[horse.id]
            for i in tracks.end.size():
                var change:=absf(angle_difference(tracks.from_heading[i],tracks.heading[i]))
                most_turn=maxf(most_turn,change)
                outside_lag=maxf(outside_lag,Vector2(tracks.end[i]).distance_to(tracks.raw[i]))
                var move: Vector2=tracks.end[i]-tracks.start[i]
                check(move.length()<=1.22*previous_center.distance_to(horse.pos)+4.5,"individual rider stride stays bounded on a turn")
                if move.length()>1.2:
                    check(move.normalized().dot(Vector2.from_angle(tracks.heading[i]))>0.98,"moving rider follows its own heading")
        previous_center=horse.pos
        if first_contact<0 and sim._in_melee(foot,foe): first_contact=tick
        if first_sortie<0 and horse.action=="협동 우회":
            first_sortie=tick
            chosen=int(horse.get("flank_target",-1))
        if first_hit<0 and horse.damage_dealt>0:
            first_hit=tick
            if not baseline:
                var close_rider:=false
                var foe_files: Array=sim.formation_slots(foe)
                for rider: Vector2 in game.rider_tracks[horse.id].end:
                    for point: Vector2 in foe_files:
                        if rider.distance_to(point)<=34: close_rider=true; break
                    if close_rider: break
                check(close_rider,"first damage has a rider on the enemy line")
        if side==0 and tick==108: await capture("wing",horse)
    if not baseline:
        print("RIDER_TURN side=",side," peak_degrees=",rad_to_deg(most_turn)," outside_lag=",outside_lag)
        check(most_turn<=0.441 and outside_lag>4.0,"riders turn through the bend over successive strides")
    print("RELIEF side=",side," contact=",first_contact," sortie=",first_sortie," target=",chosen," first_hit=",first_hit," commits=",horse.flank_commits," damage=",roundi(horse.damage_dealt))
    check(first_contact>=0 and first_sortie>=first_contact and chosen==foe.id,"actual infantry contact precedes target selection on both sides")
    check(horse.flank_commits>0 and first_hit>=first_sortie and horse.damage_dealt>0,"ride the flank and land a real hit")

func reading(side: int, rating: int) -> String:
    var actors:=setup(side,rating)
    var horse: Dictionary=actors[0]
    var foot: Dictionary=actors[1]
    var foe: Dictionary=actors[2]
    var axis: Vector2=actors[3]
    place(foot,foe.pos-axis*36,3100)
    sim._decide(horse)
    print("READ side=",side," judgment=",rating," action=",horse.action," reason=",horse.reason)
    var first: String=horse.action
    if rating==55:
        foe.cohesion=33.0
        sim._decide(horse)
        check(horse.action=="협동 우회","same lower-rated commander recognizes a clear opening")
    return first

func constraints() -> void:
    var actors:=setup(0,95,"지역 사수")
    var horse: Dictionary=actors[0]
    var foot: Dictionary=actors[1]
    var foe: Dictionary=actors[2]
    place(foot,foe.pos-Vector2(30,0),3100)
    foe.cohesion=32
    sim._decide(horse)
    check(horse.goal.distance_to(PIN)<1,"explicit defense stays put even with an opening")
    horse.tactical_order="철수"
    horse.tactical_until=sim.battle_time+20
    sim._decide(horse)
    check(horse.action=="전술 철수" and not horse.has("mounted_anchor"),"delivered withdrawal supersedes waiting")
    actors=setup(0,95)
    horse=actors[0]
    foot=actors[1]
    foe=actors[2]
    place(foot,foe.pos-Vector2(32,0),4800)
    var intact: Dictionary=sim.find_unit(sim.command_ids(1)[1])
    place(intact,foe.pos-Vector2(35,41),2600)
    intact.type="보병"
    intact.formation="방진"
    foe.cohesion=30
    sim._decide(horse)
    check(horse.flank_target==foe.id and horse.field_choice.get("target",-1)==foe.id,"choose the disrupted enemy over the nearer intact square")
    place(foe,Vector2(2200,1200),3000)
    place(intact,Vector2(2240,1140),3000)
    horse.pos=PIN+Vector2(90,25)
    sim._decide(horse)
    check(horse.goal==PIN and horse.flank_target<0,"lost observations lead back to the captured area")

func river_station() -> void:
    var actors:=setup(0,88)
    var horse: Dictionary=actors[0]
    var foe: Dictionary=actors[2]
    var y:=700.0
    var bank:=Vector2(sim.river_x(y)-68.0,y)
    horse.pos=bank
    horse.order_destination=bank
    foe.pos=Vector2(sim.river_x(y)+68.0,y)
    foe.troops=900
    foe.cohesion=25
    check(sim._locally_observed(horse,foe) and sim._river_separates(bank,foe.pos),"weak opponent is visible across the water")
    sim._decide(horse)
    check(horse.action=="기병 대기" and horse.goal==bank,"a defender across the river does not authorize a crossing")

func infantry_reading() -> void:
    var actors:=setup(0,88)
    var officer: Dictionary=actors[1]
    var foe: Dictionary=actors[2]
    actors[0].troops=0.0
    place(officer,PIN,4400)
    place(foe,PIN+Vector2(132,0),2400)
    officer.mission="공격"
    officer.personality="균형"
    foe.cohesion=60.0
    officer.judgment=88
    var early: Dictionary=sim.FieldJudgment.choose(sim,officer,foe,"진격")
    officer.judgment=55
    var late: Dictionary=sim.FieldJudgment.choose(sim,officer,foe,"진격")
    check(early.get("action","")=="공격 지속" and late.is_empty(),"judgment also affects optional infantry attacks")

func _run() -> void:
    var args:=OS.get_cmdline_user_args()
    baseline="baseline" in args
    if not args.is_empty() and args[0]!="baseline":
        directory=args[0]
        DirAccess.make_dir_recursive_absolute(directory)
    game=Main.instantiate()
    root.add_child(game)
    game.set_process(false)
    game._leave_title(5)
    sim=game.sim
    for side in 2:
        await field_run(side)
        check(reading(side,88)=="협동 우회","high judgment recognizes the marginal opening")
        check(reading(side,55)=="기병 대기","same commander with lower judgment waits for clearer evidence")
    constraints()
    infantry_reading()
    river_station()
    print("MOUNTED_BASELINE" if baseline else ("MOUNTED_VANGUARD_FAIL" if failed else "MOUNTED_VANGUARD_PASS"))
    game._quit_game(1 if failed else 0)
