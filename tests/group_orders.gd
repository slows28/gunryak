extends SceneTree
## Shared orders run through the actual planning UI, moving couriers and combat.
const Main=preload("res://main.tscn")
var game: Control
var failures:=0
var capture_dir:=""

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, label_: String) -> void:
    if not ok:
        failures+=1
        push_error("GROUP_ORDERS "+label_)

func click(point: Vector2) -> void:
    var move:=InputEventMouseMotion.new()
    move.position=point
    root.push_input(move,true)
    for down in [true,false]:
        var press:=InputEventMouseButton.new()
        press.position=point
        press.button_index=MOUSE_BUTTON_LEFT
        press.pressed=down
        root.push_input(press,true)
    await process_frame

func frame(name_: String) -> void:
    if capture_dir.is_empty(): return
    game.queue_redraw()
    game.map_layer.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(capture_dir.path_join(name_+".png"))==OK,name_)

func field_replay() -> void:
    var sim=game.sim
    sim.rng.seed=137
    sim.signature_seed=137
    var ids: Array=[]
    for id in sim.command_ids(0):
        if sim.find_unit(id).name in ["관흥","왕평","위연","마속"]: ids.append(id)
    var pin: Vector2=sim.outposts[0].pos
    check(ids.size()==4 and sim.issue_group_order(ids,"공격",pin),"four actual Qishan generals share one destination")
    game.order_view.launch.pressed.emit()
    game.game_speed=4.0
    var helpers:={}
    var hitters:={}
    var shown:=false
    var battle_frame:=false
    for tick in range(1600):
        game._process(0.1)
        if game.order_view.visible: game.order_view.launch.pressed.emit()
        if sim.finished: break
        if not shown and not game.skill_shots.is_empty() and game.skill_elapsed>=0.23:
            shown=true
            await frame("06-field-skill")
        for id: int in ids:
            var unit: Dictionary=sim.find_unit(id)
            var ally: int=unit.get("field_choice",{}).get("ally",-1)
            var target: int=unit.get("field_choice",{}).get("target",-1)
            if ally==id or ally not in ids or target<0 or not unit.get("rally_covering",false): continue
            helpers[unit.name]=true
            if sim.combat_contacts.get(id,{}).get("defender_id",-1)!=target: continue
            hitters[unit.name]=true
            if not battle_frame:
                battle_frame=true
                game.skill_shots.clear()
                game.camera_center=Vector2(unit.pos).lerp(sim.find_unit(target).pos,0.5)
                game.camera_zoom=1.75
                game._clamp_camera()
                await frame("05-field-relief")
        if battle_frame and shown and helpers.size()>=3: break
    print("QISHAN_GROUP members=",ids.size()," helpers=",helpers.keys()," landed=",hitters.keys()," day=",sim.turn)
    check(not hitters.is_empty() and shown,"an allied corps attacks the same opponent and an autonomous skill is shown during normal play")
    print("GROUP_FIELD_PASS" if failures==0 else "GROUP_FIELD_FAIL")
    game._quit_game(0 if failures==0 else 1)

func _run() -> void:
    if DisplayServer.get_name()!="headless" and not OS.get_cmdline_user_args().is_empty():
        capture_dir=OS.get_cmdline_user_args()[0]
        DirAccess.make_dir_recursive_absolute(capture_dir)
    game=Main.instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false)
    game.campaign.save_path="user://group_command_test.json"
    check(game._launch_campaign_battle(1),"Qishan campaign loads")
    var sheet=game.order_view
    var sim=game.sim
    if "--field" in OS.get_cmdline_user_args():
        await field_replay()
        return
    var ids: Array=sim.command_ids(0).slice(0,3)
    var original: String=sim.find_unit(ids[1]).mission
    await click(sheet.group_button.get_global_rect().get_center())
    for row in [1,2]:
        var box: Rect2=sheet.roster.get_item_rect(row)
        await click(sheet.roster.global_position+box.get_center())
    check(sheet.recipients==ids,"ordinary roster clicks select three armies")
    var pin:=Vector2(760,740)
    sheet.destination=pin
    sheet.has_destination=true
    sheet._choose_action(sheet.ACTIONS.find("공격"))
    await frame("01-orders")
    await click(sheet.apply.get_global_rect().get_center())
    check(sim.opening_letters.size()==3 and sim.couriers.is_empty(),"orders sealed before departure")
    await click(sheet.launch.get_global_rect().get_center())
    check(sim.started and sim.couriers.size()==3,"a separate courier leaves for each army")
    if sim.couriers.size()!=3:
        quit(1)
        return
    var first: Dictionary=sim.find_unit(ids[0])
    var second: Dictionary=sim.find_unit(ids[1])
    var third: Dictionary=sim.find_unit(ids[2])
    sim.couriers[0].pos=first.pos
    sim._update_couriers(0.01)
    check(first.has("order_group") and not second.has("order_group") and second.mission==original,"first receipt cannot change another unit")
    for letter in sim.couriers: letter.pos=sim.find_unit(letter.unit_id).pos
    sim._update_couriers(0.01)
    check(first.get("order_group",-1)==third.get("order_group",-2) and second.mission=="공격","all receipts join one company")
    for u in [first,second,third]: u.action="명령 수행"
    var companies: Array=sim.LinkedMarch._companies(sim)
    check(companies.any(func(company): return company.has(first) and company.has(second) and company.has(third)),"three-member march graph")
    var foe: Dictionary=sim.find_unit(sim.command_ids(1)[0])
    var independent: Dictionary=sim.find_unit(sim.command_ids(0)[3])
    for u in sim.units:
        if u.id not in [first.id,second.id,third.id,foe.id,independent.id]: u.troops=0.0
    first.pos=pin
    second.pos=pin+Vector2(-95,30)
    third.pos=pin+Vector2(-110,-50)
    independent.pos=pin+Vector2(-230,120)
    foe.pos=pin+Vector2(19,0)
    for u in [first,second,third,independent,foe]:
        u.goal=u.pos
        u.facing=Vector2.LEFT if u==foe else Vector2.RIGHT
        u.action="교전"
        u.front_pressure=0.0
    sim.battle_time=4.0
    sim._combat(0.1)
    check(first.get("last_attacker",-1)==foe.id,"actual hit raises the alarm")
    check(sim.RallyOrders.group_response(sim,second).is_empty(),"distant member has yet to receive the field signal")
    sim.battle_time+=1.0
    for u in [second,third]:
        sim._decide(u)
        check(u.field_choice.get("ally",-1)==first.id and u.field_choice.get("target",-1)==foe.id,"each recipient answers the same attack")
    check(not independent.has("group_signal"),"unlinked neighbor needs a rider")
    var old: Vector2=first.facing
    first.facing=Vector2.UP
    first.goal=first.pos
    sim._move_unit(first,0.1)
    check(Vector2(first.facing).dot(old)>0.0 and first.facing!=old,"line turns progressively into the opponent")
    sim._scan_situations()
    var report: Dictionary={}
    for r in sim.incoming_reports:
        if r.unit_id==first.id: report=r
    check(not report.is_empty() and sim.report_request(report)=="구원 요청" and sim.relief_riders.any(func(r): return r.report==report),"HQ and local riders carry the request")
    for i in range(180):
        sim.battle_time+=0.1
        sim._move_reporting_messengers(0.1)
        sim._move_relief_riders(0.1)
    game._refresh_hud()
    check(report in sim.open_situations(),"HQ receives the report after the ride")
    check(game.arrival_messages.any(func(m): return "구원 요청" in m.text),"arrival notice names the requested action")
    await frame("02-relief")
    sim.turn=2
    check(not sim.issue_group_order(ids,"공격",pin),"day two has no whole-army orders")
    sim.turn=3
    game._open_due_council()
    check(sheet.visible and sheet.council_round==1 and sim.paused,"day three council")
    await frame("03-council")
    sheet.launch.pressed.emit()
    check(sim.issue_map_order(second.id,"지역 사수",pin) and not sim.issue_group_order(ids,"공격",pin) and sim.couriers.size()==1,"pending recipient rejects the whole batch without a partial send")
    sim.couriers[0].pos=second.pos
    sim._update_couriers(0.01)
    check(not second.has("order_group"),"new individual order releases a member only after delivery")
    check(not sim.issue_map_order(second.id,"공격",pin),"one strategic letter per army on each command day")
    sim.turn=4
    game._open_due_council()
    check(not sheet.visible,"quiet fourth day")
    sim.turn=5
    game._open_due_council()
    check(sheet.visible and sheet.council_round==2,"second council on day five")
    sheet.launch.pressed.emit()
    var camera: Vector2=game.camera_center
    var before: int=first.skill_stats.get("pace",{}).get("uses",0)
    var witnessed: Array=[]
    sim.skill_started.connect(func(id,_title):
        if id==first.id: witnessed.append(first.skill_stats.get("pace",{}).get("uses",0)))
    sim.Skills._activate(sim,first,"pace",-1)
    check(witnessed==[before] and not game.skill_shots.is_empty() and game.skill_elapsed==0.0,"camera receives actor before the effect is applied")
    game._advance_skill_shot(0.3)
    await frame("04-skill")
    game._advance_skill_shot(1.1)
    check(game.skill_shots.is_empty() and game.camera_center.is_equal_approx(camera),"skill framing returns to prior view")
    foe.pos=sim.field_size-Vector2(45,45)
    game._skill_started(foe.id,"은폐")
    check(game.skill_shots.is_empty(),"unseen opponent never reveals itself through the camera")
    print("GROUP_ORDERS_PASS" if failures==0 else "GROUP_ORDERS_FAIL %d" % failures)
    game._quit_game(0 if failures==0 else 1)
