extends SceneTree
const WarSim=preload("res://scripts/war_sim.gd")
const Campaign=preload("res://scripts/campaign.gd")
var failures:=0

func check(ok: bool, message: String) -> void:
    if ok: print("PASS ",message)
    else:
        failures+=1
        push_error(message)

func _initialize() -> void:
    var sim:=WarSim.new()
    sim.set_long_operation(true)
    for scenario in range(6):
        sim.set_scenario(scenario)
        var sites:=sim.planning_sites()
        var names:={}
        var dry:=true
        for site in sites:
            names[site["name"]]=true
            dry=dry and not sim.in_open_water(site["pos"])
        check(sim.command_ids(0).size()==10 and sim.command_ids(1).size()==10 and names.size()==sites.size() and dry and sim.terrain_posts.size()>=14,"ten commanders per side and individually named landmarks on map %d" % scenario)
    var target:=sim.terrain_posts[0]
    var leader:=sim.find_unit(sim.command_ids(0)[9])
    check(sim.issue_map_order(leader["id"],"지역 사수",target["pos"]),"tenth officer accepts a bridgehead assignment")
    check(sim.issue_map_order(leader["id"],"자유 재량",Vector2.INF) and not leader["has_destination"] and leader["assigned_link"]==-1,"free role releases the appointed site and partner")
    sim.start()
    var old_pos: Vector2=leader["pos"]
    leader["pos"]=target["pos"]
    sim._update_outposts(sim.capture_duration())
    check(target["owner"]==0 and not sim.outposts.has(target),"ordinary bridgehead changes hands independently of victory sites")
    leader["pos"]=old_pos
    var anchor: Dictionary=sim.outposts[0]
    sim.turn=5
    check(sim.issue_map_order(leader["id"],"지역 사수",anchor["pos"]),"send a fixed assignment by courier")
    sim.couriers.back()["pos"]=leader["pos"]
    sim._update_couriers(0.1)
    check(not sim.issue_map_order(leader["id"],"자유 재량",Vector2.INF),"the day-five delivery does not reopen that army's dispatch slot")
    sim.turn=6
    check(not sim.issue_map_order(leader["id"],"자유 재량",Vector2.INF),"no strategic changes on the intervening day")
    sim.turn=7
    check(leader["has_destination"] and sim.issue_map_order(leader["id"],"자유 재량",Vector2.INF) and leader["mission"]=="지역 사수","prior assignment stays in force until the free-role courier arrives")
    sim.couriers.back()["pos"]=leader["pos"]
    sim._update_couriers(0.1)
    check(leader["mission"]=="자유 재량" and not leader["has_destination"] and not sim._assigned_outpost(leader).is_empty(),"free general chooses a real battlefield objective")
    _raid_and_rebuild()
    _victory_news()
    _migrate_campaign()
    if failures==0: print("GUNRYAK_FIELD_OPERATIONS_PASS")
    quit(1 if failures else 0)

func _raid_and_rebuild() -> void:
    var s:=WarSim.new()
    s.set_long_operation(true)
    var camp: Dictionary=s.bases[0]
    var pos: Vector2=camp["pos"]
    var witness:=s.find_unit(0)
    var remote:=s.find_unit(1)
    var raider:=s.find_unit(3)
    for unit in s.units:
        if unit["id"] not in [0,1,3]: unit["troops"]=0
    witness["pos"]=pos+Vector2(140,0)
    remote["pos"]=pos+Vector2(450,0)
    raider["pos"]=pos
    for unit in [witness,remote]: unit["morale"]=20.0
    s.start()
    s._update_base_raid(camp,s.RAID_SECONDS-0.1)
    check(witness["morale"]==20,"raid warning alone does not lower morale")
    s._update_base_raid(camp,0.11)
    s._update_general_conditions(witness,0.1)
    check(witness["morale"]==0 and witness["routed"] and witness["action"]=="사기 혼란" and witness["deserted"]>0 and remote["morale"]==20,"nearby loss causes panic and desertions, distant corps unaffected")
    raider["pos"]=s._home_point(1)
    s._extend_supply(0)
    for tick in range(90):
        s.battle_time+=0.1
        s._supply_logic(0.1)
    check(s.bases.size()==2 and s.bases[0]["alive"] and s.bases[0]["state"]=="가동" and witness["morale"]>=14 and remote["morale"]==20,"crew rebuilds the lost depot on its existing plot and news lifts local morale")
    s._extend_supply(0)
    check(s.supply_crews[0]["state"]=="대기","a stationary army does not commission repeated depots")

func _victory_news() -> void:
    var s:=WarSim.new()
    s.set_long_operation(true)
    var victor:=s.find_unit(0)
    var foe:=s.find_unit(3)
    var friend:=s.find_unit(1)
    for unit in s.units:
        if unit["id"] not in [0,1,3]: unit["troops"]=0
    victor["pos"]=Vector2(520,510)
    foe["pos"]=Vector2(539,510)
    friend["pos"]=Vector2(550,600)
    victor["morale"]=52.0
    friend["morale"]=40.0
    foe["troops"]=0.01
    for i in range(8): s._combat(0.1)
    check(foe["troops"]==0 and friend["morale"]==58 and victor["morale"]>60,"witnessing an enemy corps eliminated grants a single morale gain")

func _migrate_campaign() -> void:
    var campaign:=Campaign.new()
    campaign.set_six_armies(true)
    var old: Dictionary=campaign.state.duplicate(true)
    old["version"]=3
    old["gold"]=83
    old["roster"][0]["xp"]=221
    old["roster"].resize(9)
    for key in ["active","troops","types","formations"]: old[key].resize(6)
    campaign.save_path="user://gunryak-migration-fixture.json"
    var file:=FileAccess.open(campaign.save_path,FileAccess.WRITE)
    file.store_string(JSON.stringify(old))
    file.close()
    check(campaign.load_save() and campaign.state["active"].size()==10 and campaign.state["gold"]==83 and campaign.state["roster"][0]["xp"]==221 and campaign.state["troops"].slice(0,6)==old["troops"],"existing six-corps campaign keeps commander experience, resources and armies when expanded to ten")
