extends SceneTree
## Full Mugong battle. Add "-- roles" for an escort and two delegated corps.
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
    var delegated := "roles" in OS.get_cmdline_user_args()
    if delegated:
        var ids := sim.command_ids(0)
        if not sim.issue_map_order(ids[0],"전열 엄호",post.pos,ids[1]):
            quit(1)
            return
        for id in [ids[2],ids[3]]:
            if not sim.issue_map_order(id,"자유 재량",Vector2.ZERO):
                quit(1)
                return
    var protect_ticks := [0,0]
    var assigned := [{},{}]
    var waited := [{},{}]
    var sorties := [{},{}]
    var cover_ticks := 0
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
            if u.troops <= 0 or u.routed: continue
            if u.ai_role_until>sim.battle_time and u.ai_partner>=0: assigned[u.side][u.id]=true
            if u.action in ["아군 보호","궁병 보호"]: protect_ticks[u.side]+=1
            if u.get("rally_covering",false): cover_ticks+=1
            if u.action=="기병 대기": waited[u.side][u.id]=u.name
            if u.has("mounted_anchor") and u.action=="돌파": sorties[u.side][u.id]=u.name
    print("MUGONG_RALLY post=",post.name," arrived=",arrived.keys()," simultaneous=",simultaneous," exits=",exits.keys()," Zhao=",zhao.general_state," troops=",roundi(zhao.troops)," outcome=",sim.result)
    print("ROLE_RUN delegated=",delegated," automatic_corps=",assigned[0].size(),"/",assigned[1].size()," protection_corps_ticks=",protect_ticks," arrival_cover_corps_ticks=",cover_ticks)
    print("MOUNTED_FIELD waited=",waited[0].values(),"/",waited[1].values()," committed=",sorties[0].values(),"/",sorties[1].values())
    quit(0 if sim.finished and sim.validate_state().is_empty() else 1)
