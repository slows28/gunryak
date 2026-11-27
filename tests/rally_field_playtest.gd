extends SceneTree
## Full Mugong battle. Only the opening assignments of three Shu corps change.
const Campaign = preload("res://scripts/northern_campaign.gd")
const War = preload("res://scripts/war_sim.gd")

func _initialize() -> void:
    var campaign := Campaign.new()
    campaign.save_path = "user://rally-mugong-replay.json"
    for stage in range(1,11):
        campaign.state.reward = stage
        if not campaign.claim(campaign.choices()[0]):
            quit(1)
            return
    var sim := War.new()
    sim.set_long_operation(true)
    if not campaign.prepare(11,sim):
        quit(1)
        return
    var corps: Array[Dictionary] = []
    var post: Dictionary = sim.outposts[0]
    for id in sim.command_ids(0).slice(0,3):
        if not sim.issue_map_order(id,"지역 사수",post.pos):
            quit(1)
            return
        corps.append(sim.find_unit(id))
    var arrived := {}
    var simultaneous := 0
    var exits := {}
    var zhao: Dictionary = {}
    for u in sim.units:
        if u.name == "조운": zhao = u
    sim.start()
    while not sim.finished and sim.step_count < 6000:
        sim.step(0.1)
        var present := 0
        for u in corps:
            if not u.has("rally_station") or u.troops <= 0 or u.routed: continue
            if Vector2(u.pos).distance_to(u.rally_station.point) < 22.0:
                arrived[u.name] = true
                present += 1
        simultaneous = maxi(simultaneous,present)
        for u in sim.units:
            if u.action == "포위 이탈": exits[u.name] = true
    print("MUGONG_RALLY post=",post.name," arrived=",arrived.keys()," simultaneous=",simultaneous," exits=",exits.keys()," Zhao=",zhao.general_state," troops=",roundi(zhao.troops)," outcome=",sim.result)
    quit(0 if sim.finished and sim.validate_state().is_empty() else 1)
