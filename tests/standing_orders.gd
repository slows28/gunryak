extends SceneTree
const Main=preload("res://main.tscn")
var failed:=false
var game
var folder:=""
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if ok: print("PASS ",message)
    else:
        failed=true
        push_error(message)

func click(point: Vector2) -> void:
    for down in [true,false]:
        var event:=InputEventMouseButton.new()
        event.button_index=MOUSE_BUTTON_LEFT
        event.position=point
        event.pressed=down
        root.push_input(event,true)
    await process_frame

func capture(name_: String) -> void:
    if folder.is_empty(): return
    await process_frame
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(folder.path_join(name_+".png"))==OK,name_)

func _run() -> void:
    if DisplayServer.get_name()!="headless" and not OS.get_cmdline_user_args().is_empty():
        folder=OS.get_cmdline_user_args()[0]
        DirAccess.make_dir_recursive_absolute(folder)
    game=Main.instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false)
    game._leave_title(game.sim.TRAINING_SCENARIO)
    var sim=game.sim
    var sheet=game.order_view
    var foot: Dictionary=sim.find_unit(0)
    var friend: Dictionary=sim.find_unit(1)
    var foe: Dictionary=sim.find_unit(3)
    for u in sim.units: check(u.facing==(Vector2.RIGHT if u.side==0 else Vector2.LEFT),"opening facing "+u.name)
    await click(sheet.deploy_button.get_global_rect().get_center())
    var point:=Vector2(190,740)
    await click(sheet._point(point))
    check(Vector2(foot.pos).distance_to(point)<5 and foot.facing==Vector2.RIGHT,"map places the active corps facing the enemy")
    var old: Vector2=foot.pos
    var ally_old: Vector2=friend.pos
    check(not sim.deploy_corps([foot.id,friend.id],Vector2(2100,800)).is_empty() and old==foot.pos and ally_old==friend.pos,"illegal group placement is atomic")
    var shift:=Vector2(75,65)
    check(sim.deploy_corps([foot.id,friend.id],old+shift).is_empty() and foot.pos==old+shift and friend.pos==ally_old+shift,"moving linked corps keeps their spacing")
    var shape: int=sim.LARGE_FORMATIONS.find("학익진")
    sheet.formation_choice.select(shape)
    sheet.formation_choice.item_selected.emit(shape)
    check(foot.formation=="학익진" and not sheet.site_choice.visible and sheet.formation_choice.visible,"deployment previews the selected opening formation")
    await capture("deployment")
    await click(sheet.deploy_button.get_global_rect().get_center())
    var site: Dictionary=sim.planning_sites()[0]
    await click(sheet.action_buttons[2].get_global_rect().get_center())
    await click(sheet._point(site.pos))
    check(foot.has_destination and Vector2(foot.order_destination).is_equal_approx(site.pos) and foot.encounter=="사수" and not sheet.draft_dirty,"one site click registers movement with its contact instruction")
    var raid_row: int=sheet.TASKS.find(9)
    sheet.task_choice.select(raid_row)
    sheet.task_choice.item_selected.emit(raid_row)
    check(sheet.raid_response.visible and not sheet.action_buttons[1].visible,"raid displays its own contact choices")
    await capture("supply-search")
    await click(sheet._point(site.pos))
    check(foot.mission==sim.StandingOrders.RAID and foot.encounter=="철수","raid and disengagement are one order")
    game._start()
    check(not sim.place_unit(0,point),"deployment is closed during battle")
    sim.turn=3
    check(sim.issue_map_order(0,sim.StandingOrders.RAID,site.pos,-1,"강행") and foot.encounter=="철수","new raid policy waits for its courier")
    for letter in sim.couriers: letter.pos=sim.find_unit(letter.unit_id).pos
    sim._update_couriers(0.01)
    check(foot.encounter=="강행","courier receipt changes the policy")
    for u in sim.units:
        if u.id not in [0,1,3]: u.troops=0.0
    foot.pos=Vector2(420,740)
    friend.pos=foot.pos+Vector2(-100,10)
    foe.pos=Vector2(2000,680)
    var depot: Dictionary=sim.bases[1]
    depot.pos=Vector2(1950,810)
    foot.order_destination=Vector2(710,740)
    sim._decide(foot)
    check(foot.action=="보급기지 수색" and foot.goal==foot.order_destination and not foot.has("search_position"),"unseen depot coordinates are unknown")
    foot.pos=foot.order_destination
    sim._decide(foot)
    check(foot.action=="보급기지 수색" and foot.goal.x>sim.field_size.x*0.5 and foot.goal!=depot.pos,"a western waypoint leads to a search of the enemy bank")
    foot.pos=Vector2(420,740)
    depot.pos=foot.pos+Vector2(80,0)
    sim._decide(foot)
    check(foot.action=="기지 습격" and foot.goal==depot.pos,"observed camp becomes the raid target")
    foe.pos=depot.pos
    sim._decide(foot)
    check(foot.field_choice.get("target",-1)==foe.id and foot.action=="교전","continue order engages the observed camp guard")
    foot.encounter="철수"
    sim._decide(foot)
    foe.pos=Vector2(2100,700)
    sim._decide(foot)
    check(foot.raid_withdrawing and foot.action=="전술 철수" and foot.goal==sim._home_point(0),"retreat persists after sight of guard is lost")
    foot.pos=depot.pos
    friend.pos=Vector2(200,300)
    sim._update_base_raid(depot,1.0)
    check(depot.raid_work==0.0,"withdrawing corps no longer dismantles the depot")
    sim.StandingOrders.clear(foot)
    foot.encounter="강행"
    sim._decide(foot)
    sim._update_base_raid(depot,sim.RAID_SECONDS)
    check(not depot.alive and not sim.finished,"continued raid destroys the undefended depot without ending the battle")
    sim.StandingOrders.clear(foot)
    foot.mission="공격"
    foe.pos=foot.pos+Vector2(82,0)
    friend.pos=foe.pos+Vector2(-18,15)
    for mode in ["공격","지원","사수"]:
        foot.encounter=mode
        sim._decide(foot)
        check(foot.field_choice.get("target",-1)==foe.id and (mode!="사수" or foot.goal==foot.pos) and (mode!="지원" or foot.field_choice.get("ally",-1)==friend.id),"encounter directive "+mode)
    print("STANDING_ORDERS_PASS" if not failed else "STANDING_ORDERS_FAIL")
    game._quit_game(1 if failed else 0)
