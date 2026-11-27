extends RefCounted
## Ordered chapters use the existing valleys, rivers, siege walls and autonomous field AI.
# title, terrain template, objective, briefing, focal site, added forest, reward IDs
const CHAPTERS := [
    ["기산 진출전",0,"field","기산 야전 · 18분 이후 위군 손실 10,000명 또는 거점 두 곳 유지.",Vector2(1270,775),Rect2(630,630,210,140),["strike","square","dash"]],
    ["천수 공략전",0,"sites","천수의 세 거점 가운데 두 곳을 확보하십시오.",Vector2(1230,405),Rect2(1610,1080,250,150),["inspire","rapid","harass"]],
    ["기곡 전투",1,"lure","위군이 기곡 유인 지점을 점령하도록 유인한 뒤, 촉군으로 탈환하십시오.",Vector2(1080,830),Rect2(930,720,225,145),["ambush","decoy","swift"]],
    ["가정 전투",2,"hold","가정의 본진을 지키고 작전 종료 시 고갯길을 확보하십시오.",Vector2(735,550),Rect2(1040,600,230,140),["iron","last","counter"]],
    ["상규 전투",1,"flank","측후방에서 누적 피해 150명을 내고 상규 고지를 확보하십시오.",Vector2(1450,710),Rect2(1050,455,220,175),["breach","fury","wing"]],
    ["농서 평정전",0,"fronts","북로와 남로를 동시에 확보하십시오.",Vector2(1390,780),Rect2(1090,970,280,145),["link","relief","rally"]],
    ["진창 공방전",4,"siege","진창의 성문을 파괴한 뒤 성내 진입로를 확보하십시오.",Vector2(2110,845),Rect2(1390,510,180,175),["siege","focus","screen"]],
    ["미현 공략전",1,"line","미현의 외곽 방어선과 안쪽 거점을 함께 장악하십시오.",Vector2(1700,855),Rect2(1430,620,175,230),["charge","pursue","enclose"]],
    ["오장원 전투",0,"duel","오장원에서 적의 가용 전력을 줄이십시오. 18분 이후 병력 우세와 중앙 거점이 필요합니다.",Vector2(1430,875),Rect2(945,505,245,180),["chain","bastion","war_drum"]],
    ["위수 도하전",0,"river","두 군단 이상이 위수를 건너고 동쪽 교두보를 확보하십시오.",Vector2(1690,847),Rect2(1740,960,220,150),["ford","bridge","surprise"]],
    ["무공 전투",1,"link","같은 적을 향한 군단 협동 타격으로 누적 피해 120명을 내고 무공을 확보하십시오.",Vector2(1530,855),Rect2(1310,1050,210,165),["cascade","reshape","reverse"]],
    ["장안 외곽 전투",0,"decisive","위군 주력의 병력을 개전 대비 30% 이상 줄이고 거점 두 곳을 확보하십시오.",Vector2(1630,870),Rect2(1600,1050,260,185),["tiger","thunder","ram"]],
    ["장안 함락전",4,"capital","장안 성문을 열고 궁성 앞을 2분간 유지하십시오.",Vector2(2190,865),Rect2(1590,545,245,160),[]]
]
const FIELD_NAMES := ["기산 대영","천수 관도","기곡 유인 지점","가정 고갯길","상규 고지","농서 중로","진창 성내 진입로","미현 내성길","오장원 중앙","위수 동쪽 교두보","무공 집결지","장안 외곽 대영","장안 궁성 앞"]
const WEI_BENCH := ["장호","조휴","진태","등애"]
static func deploy(sim, number: int) -> void:
    var stage: Array=CHAPTERS[number-1]
    sim.scenario_title=stage[0]
    sim.scenario_goal=stage[3]
    sim.scenario_limit=sim.LONG_LIMIT
    sim.forests.append(stage[5])
    sim.outposts[0]["pos"]=stage[4]
    sim.outposts[0]["name"]=FIELD_NAMES[number-1]
    if stage[2]=="fronts":
        sim.outposts[0]["pos"]=Vector2(1340,405)
        sim.outposts[0]["name"]="농서 북로"
        sim.outposts[1]["name"]="농서 남로"
    if stage[2]=="hold": sim.hill=Rect2(605,465,280,190)
    if stage[2]=="line": sim.outposts[1]["name"]="미현 외곽 방어선"
    if stage[2] in ["siege","capital"]:
        sim.structures[0]["name"]="장안 정문" if number==13 else "진창 성문"
        if number==13:
            sim.structures[0]["max_hp"]*=1.25
            sim.structures[0]["hp"]=sim.structures[0]["max_hp"]
    var enemy_count:=12+(1 if number>=9 else 0)+(1 if number>=12 else 0)
    for i in range(enemy_count-10):
        var kind: String=["보병","궁병","기병","보병"][i]
        sim._add_unit(1,WEI_BENCH[i],kind,"신중" if i%2==0 else "공격",76.0+number,Vector2(2310+38*i,565+230*i),"중앙 진격" if i%2==0 else "북측 확보",3850.0)
        var unit: Dictionary=sim.units.back()
        unit["formation"]="안행진" if kind=="궁병" else "어린진"
        if number>=5: unit["mission"]="측후방 기동" if kind=="기병" else "중앙 진격"
    if stage[2] in PRESSURE_MODES: assign_home_guard(sim)
    sim._map_terrain_posts()
    sim.chapter={"number":number,"mode":stage[2],"baited":false,"enemy_count":enemy_count,"enemy_initial":0,"metrics":{}}

# A field commander can commit to a nearby objective after seeing a mass of
# enemy corps there twice. Two commanders can take stations. Further help
# requires a delivered request. Each station expires with its last sighting.
const PRESSURE_MODES:=["sites","fronts","line","link","decisive"]
const MASS_RADIUS:=240.0
const MASS_CORPS:=4
const WATCH_SECONDS:=17.0

# The objective watch draws on field corps. Keep one existing infantry corps
# on the ordinary headquarters mission, under the same rules as a Shu garrison.
static func assign_home_guard(sim) -> void:
    var home: Vector2=sim.headquarters[1]["pos"]
    var guard: Dictionary={}
    var nearest:=INF
    for u in sim.units:
        if u["side"]!=1 or u.has("parent_id") or u["reserve"] or u["routed"] or u["troops"]<600: continue
        if u["mission"]=="본진 방어" and u["has_destination"]: return
        if u["type"]!="보병" or u["has_destination"] or u["defense_set"]: continue
        var distance: float=Vector2(u["pos"]).distance_squared_to(home)
        if distance<nearest:
            guard=u
            nearest=distance
    if not guard.is_empty():
        guard["mission"]="본진 방어"
        guard["has_destination"]=true
        guard["order_destination"]=home

static func review_pressure(sim) -> void:
    var mode: String=sim.chapter.get("mode","")
    if mode not in PRESSURE_MODES: return
    var sites:=2
    if mode=="link": sites=1
    elif mode in ["sites","decisive"]: sites=sim.outposts.size()
    var candidates: Array[Dictionary]=[]
    var active:=0
    for u in sim.units:
        if u["side"]!=1: continue
        var prior: Dictionary=u.get("post_watch",{})
        if not prior.is_empty() and prior["until"]<=sim.battle_time:
            u.erase("post_watch")
            prior={}
        if not _watch_ready(sim,u):
            u.erase("post_watch")
            u.erase("post_sighting")
            continue
        if not prior.is_empty(): active+=1
        var seen:=_massed_corps(sim,u,sites,prior.get("site",-1))
        if seen.is_empty():
            u.erase("post_sighting")
            continue
        var earlier: Dictionary=u.get("post_sighting",{})
        u["post_sighting"]={"site":seen["site"],"time":sim.battle_time}
        if not prior.is_empty():
            u["post_watch"]=seen
        elif earlier.get("site",-1)==seen["site"] and sim.battle_time-float(earlier["time"])<=10.0 and sim.battle_time>earlier["time"]:
            candidates.append({"unit":u,"watch":seen,"distance":Vector2(u["pos"]).distance_squared_to(seen["station"])})
    candidates.sort_custom(func(a,b): return a.distance<b.distance)
    for slot in range(mini(candidates.size(),2-active)):
        var candidate:=candidates[slot]
        var u: Dictionary=candidate["unit"]
        u["post_watch"]=candidate["watch"]
        u["ai_cooldown"]=0.0
        if sim.tactical_enabled and sim.battle_time>=float(sim.chapter.get("next_site_call",0.0)) and sim.battle_time-float(u.get("last_relief_request",-100.0))>=30.0:
            var report: Dictionary={"id":sim.step_count*100+u["id"],"side":1,"unit_id":u["id"],"sender":u["name"],"pos":u["pos"],"site":candidate["watch"]["site"],"written_at":sim.battle_time}
            sim._send_relief_request(u,report)
            sim.chapter["next_site_call"]=sim.battle_time+30.0

static func _watch_ready(sim,u: Dictionary) -> bool:
    if u.has("parent_id") or u["type"] not in ["보병","궁병"] or u["troops"]<600 or u["routed"] or u["reserve"]: return false
    if u["mission"]=="본진 방어" or u["has_destination"] or u["defense_set"] or u["tactical_until"]>sim.battle_time: return false
    return u["morale"]>=40 and u["cohesion"]>=35 and u["rations"]>=20

static func _massed_corps(sim,u: Dictionary,sites: int,committed_site: int) -> Dictionary:
    var best: Dictionary={}
    for i in range(sites):
        if committed_site>=0 and i!=committed_site: continue
        var site: Vector2=sim.outposts[i]["pos"]
        if Vector2(u["pos"]).distance_squared_to(site)>360.0*360.0 or sim._river_separates(u["pos"],site): continue
        var center:=Vector2.ZERO
        var count:=0
        for foe in sim.units:
            if foe["side"]!=0 or foe.has("parent_id") or foe["routed"] or foe["reserve"] or foe["troops"]<600: continue
            if site.distance_squared_to(foe["pos"])>MASS_RADIUS*MASS_RADIUS: continue
            if not sim._locally_observed(u,foe) or sim._river_separates(foe["pos"],site): continue
            center+=Vector2(foe["pos"])
            count+=1
        if count<MASS_CORPS or count<=int(best.get("count",0)): continue
        var offset:=site.direction_to(center/count)*(28.0 if u["type"]=="보병" else -75.0)
        var station: Vector2=sim._field_point(site+offset)
        if sim.in_open_water(station) or sim._river_separates(site,station): station=site
        best={"site":i,"station":station,"count":count,"until":sim.battle_time+WATCH_SECONDS}
    return best

# Mark an opening assignment on the ordinary orders map. The player can
# replace or cancel every assignment before dispatching the army.
static func opening_orders(sim) -> void:
    var mode: String=sim.chapter["mode"]
    var commanders: Array[int]=sim.command_ids(0)
    var multi: bool=mode in ["sites","fronts","line","decisive"]
    var taken: Array[int]=[]
    for post_index in range(2 if multi else 1):
        var site: Dictionary=sim.outposts[post_index]
        var target: Vector2=site["pos"]
        for kind in ["보병","궁병","기병"]:
            var leader: Dictionary={}
            var nearest:=INF
            for id in commanders:
                var u: Dictionary=sim.find_unit(id)
                if id in taken or u["type"]!=kind: continue
                var distance: float=Vector2(u["pos"]).distance_squared_to(target)
                if distance<nearest: leader=u;nearest=distance
            if leader.is_empty(): continue
            var guard: bool=kind=="보병" and mode not in ["siege","capital","flank"]
            var partner: int=taken[0] if mode=="link" and not taken.is_empty() else -1
            var mission: String="지역 사수" if guard else "공격"
            if mode=="flank" and kind=="기병": mission="측후방 기동"
            if sim.issue_map_order(leader["id"],mission,target,partner):
                taken.append(leader["id"])

static func victory(sim) -> void:
    var c: Dictionary=sim.chapter
    var mode: String=c["mode"]
    var site: Dictionary=sim.outposts[0]
    if mode=="lure" and site["owner"]==1: c["baited"]=true
    if sim.battle_time<sim.LONG_OBJECTIVE_OPEN and sim.step_count%10!=0: return
    var standing: Array[int]=[0,0]
    var flank:=0.0
    var linked:=0.0
    var crossed:=0
    var garrison:=false
    var wei_losses:=0.0
    for u in sim.units:
        if u["troops"]>0 and not u["routed"]: standing[u["side"]]+=1
        if u["side"]==1: wei_losses+=float(u["casualties_taken"])
        if u["side"]==0:
            if u["troops"]>0 and not u["routed"] and Vector2(u["pos"]).distance_to(site["pos"])<=sim.OUTPOST_RADIUS: garrison=true
            flank+=float(u["flank_damage"])
            linked+=float(u["linked_hits"])
            if on_east_bank(sim,u): crossed+=1
    if standing[0]==0 and sim.reinforcements_used[0]>=sim.reserve_limit[0]:
        sim._finish("아군 전투 불능 — 패배")
        return
    if standing[1]==0 and sim.reinforcements_used[1]>=sim.reserve_limit[1] and mode not in ["siege","capital"]:
        sim._finish("위군 전투 불능 — 승리")
        return
    if sim.battle_time<sim.LONG_OBJECTIVE_OPEN: return
    # Occupied territory persists after the garrison moves. Only an explicit
    # holding objective requires uninterrupted presence on its capture circle.
    var required:=30.0 if mode in ["siege","capital"] else (45.0 if mode=="field" else 0.0)
    var secured: Array[bool]=[]
    for post in sim.outposts:
        secured.append(post["owner"]==0 and post["challenger"]<0 and not post.get("contested",false) and post["hold"]>=required)
    var count:=secured.count(true)
    var first: bool=secured[0]
    var second: bool=secured[1]
    var timed_out: bool=sim.battle_time>=sim.scenario_limit
    var won:=false
    match mode:
        "field": won=count>=2 or wei_losses>=10000
        "sites": won=count>=2
        "lure": won=first and c["baited"]
        "hold": won=timed_out and site["owner"]==0 and garrison
        "flank": won=first and flank>=150
        "fronts","line": won=first and second
        "siege","capital": won=first and sim.structures[0]["hp"]<=0
        "duel": won=first and sim.total_troops(0)>sim.total_troops(1)
        "river": won=first and crossed>=2
        "link": won=first and linked>=120
        "decisive": won=count>=2 and sim.total_troops(1)<=0.7*float(c["enemy_initial"])
    if won or timed_out:
        var detail: String="확보 거점 %d곳" % count
        match mode:
            "field": detail+=" · 위군 전투 손실 %d / 10,000명" % roundi(wei_losses)
            "lure": detail+=" · 위군 점령 "+("확인" if c["baited"] else "미달")+" · 촉군 탈환 "+("완료" if won else "미달")
            "hold": detail+=" · 고갯길 수비대 "+("주둔" if garrison else "부재")
            "flank": detail+=" · 측후방 피해 %d / 150명" % roundi(flank)
            "link": detail+=" · 협동 피해 %d / 120명" % floori(linked)
            "river": detail+=" · 건넌 군단 %d / 2" % crossed
            "siege","capital": detail+=" · 성문 내구도 %d%% · 성내 유지 %d / 120초" % [ceili(100.0*sim.structures[0]["hp"]/sim.structures[0]["max_hp"]),floori(site["hold"]*sim.operation_scale()) if site["owner"]==0 else 0]
            "decisive": detail+=" · 위군 잔여 %d%%" % ceili(100.0*sim.total_troops(1)/float(c["enemy_initial"]))
            "duel": detail+=" · 아군 %d명 / 위군 %d명" % [sim.total_troops(0),sim.total_troops(1)]
        sim._finish(sim.scenario_title+(" — 승리" if won else " 목표 미달 — 패배"),detail)

static func on_east_bank(sim,u: Dictionary) -> bool:
    return u["bridge_crossings"]>0 and u["troops"]>0 and u["pos"].x>sim.river_x(u["pos"].y)

# Each letter records one commander's own observations at departure. Keep
# traffic below ordinary emergency reports and do not create a reply request.
static func report_progress(sim) -> void:
    var ledger: Dictionary=sim.chapter["metrics"]
    if sim.battle_time<ledger.get("next_letter",0.0): return
    for letter in sim.incoming_reports:
        if letter.has("objective_account"): return
    for id in sim.command_ids(0):
        var u: Dictionary=sim.find_unit(id)
        if u["troops"]<=0 or u["routed"]: continue
        var dispatch: Array=_river_report(sim,u) if sim.chapter["mode"]=="river" else _link_report(sim,u)
        if dispatch.is_empty(): continue
        var kind: String=dispatch[0]
        var key: String=kind+str(id)
        if kind in ["도하 완료","서안 복귀"]:
            if ledger.get("bank"+str(id),"")==kind: continue
            ledger["bank"+str(id)]=kind
        elif ledger.has(key) or (kind in ["교량 접근","합류 대기"] and ledger.get(kind,0)>=2): continue
        ledger[key]=true
        ledger[kind]=int(ledger.get(kind,0))+1
        ledger["next_letter"]=sim.battle_time+6.0
        sim._send_situation(u,kind,"",false,Vector2.ZERO,"",0,0,dispatch[1])
        return

static func _river_report(sim,u: Dictionary) -> Array:
    var name: String=u["name"]
    if on_east_bank(sim,u):
        return ["도하 완료","%s군이 위수를 건너 동안에 도착했습니다. 승리하려면 동쪽 강둑에 두 군단이 남아 있고 교두보도 우리 손에 있어야 합니다." % name]
    if u["bridge_crossings"]>0 and u["pos"].x<sim.river_x(u["pos"].y):
        return ["서안 복귀","%s군이 위수 서쪽으로 돌아왔습니다. 지금은 동안에 주둔한 군단 수에서 빠집니다." % name]
    var bridge: float=u["bridge_y"]
    if bridge<0 or u["bridge_bank"]<=0 or u["pos"].x>=sim.river_x(u["pos"].y): return []
    var gate:=Vector2(sim.river_x(bridge),bridge)
    if gate.distance_to(u["pos"])>220: return []
    var which: String="북측" if bridge<600 else ("남측" if bridge>1100 else "중앙")
    return ["교량 접근","%s군이 %s 교량 서쪽 진입로에 있습니다. 교량을 지나 동안에 닿아야 도하로 집계됩니다." % [name,which]]

static func _link_report(sim,u: Dictionary) -> Array:
    var elapsed: float=sim.battle_time-float(u.get("joint_time",-100.0))
    if u.has("joint_time"):
        var ally: Dictionary=sim.find_unit(u["joint_partner"])
        var partner: String=ally.get("name","협동 군단")
        var credit: int=floori(u["linked_hits"])
        if elapsed<=3.0:
            var kind: String="협공 성과" if credit>=120 and sim.chapter["metrics"].has("협공 성립"+str(u["id"])) else "협공 성립"
            return [kind,"%s군과 %s군이 같은 적을 쳤습니다. 우리 군단의 누적 협공 피해는 %d명입니다. 전군이 120명을 채우고 무공 집결지를 확보해야 합니다." % [u["name"],partner,credit]]
        if elapsed>=6.0:
            return ["협공 중단","%s군과 마지막으로 협공한 뒤 %d초 동안 추가 협동 타격이 없었습니다. 우리 군단의 누적 기여는 %d명입니다." % [partner,floori(elapsed*sim.operation_scale()),credit]]
    var other: Dictionary=sim.find_unit(u["assigned_link"])
    if not other.is_empty() and u["pos"].distance_to(other["pos"])>245:
        return ["합류 대기","연계 대상인 %s군과 거리가 벌어졌습니다. 다른 병과가 같은 적을 타격할 수 있는 거리까지 합류해야 합니다." % other["name"]]
    return []

# Only delivered observations enter the desk. A late letter keeps the
# situation as it was described at that time, including the reporting corps.
static func receive(sim,report: Dictionary) -> void:
    var receipts: Dictionary=sim.chapter.get("receipts",{})
    receipts[report["unit_id"]]=report
    sim.chapter["receipts"]=receipts
    var eastern:=PackedStringArray()
    var joint_damage:=0.0
    for latest in receipts.values():
        if latest.get("east_bank",false): eastern.append(latest["sender"])
        joint_damage+=float(latest.get("joint_credit",0.0))
    var summary: String
    if report.has("east_bank"):
        summary="수신 보고 기준  ·  동안 %d/2개 군단" % eastern.size()
        if not eastern.is_empty(): summary+="  ·  "+" · ".join(eastern)
    else:
        summary="수신 보고 기준  ·  협공 피해 %d/120명" % floori(joint_damage)
    report["desk_summary"]=summary
    sim.chapter["desk_summary"]=summary
