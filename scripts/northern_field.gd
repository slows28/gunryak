extends RefCounted
## Ordered chapters use the existing valleys, rivers, siege walls and autonomous field AI.
# title, terrain template, objective, briefing, focal site, added forest, reward IDs
const CHAPTERS := [
    ["기산 진출전",0,"field","기산 야전 · 18분 이후 위군 손실 10,000명 또는 거점 두 곳 유지.",Vector2(1270,775),Rect2(630,630,210,140),["strike","square","dash"]],
    ["천수 공략전",0,"sites","천수의 세 거점 가운데 두 곳을 확보하십시오.",Vector2(1230,405),Rect2(1610,1080,250,150),["inspire","rapid","harass"]],
    ["기곡 전투",1,"lure","위군을 기곡 유인 지점으로 끌어들인 뒤 그 지점을 탈환하십시오.",Vector2(1080,830),Rect2(930,720,225,145),["ambush","decoy","swift"]],
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
    sim._map_terrain_posts()
    sim.chapter={"number":number,"mode":stage[2],"baited":false,"enemy_count":enemy_count,"enemy_initial":0,"metrics":{}}

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
    if mode=="lure" and not c["baited"]:
        for u in sim.units:
            if u["side"]==1 and u["troops"]>0 and Vector2(u["pos"]).distance_to(site["pos"])<=100:
                c["baited"]=true
                break
    if sim.battle_time<sim.LONG_OBJECTIVE_OPEN and sim.step_count%10!=0: return
    var standing: Array[int]=[0,0]
    var flank:=0.0
    var linked:=0.0
    var crossed:=0
    var wei_losses:=0.0
    for u in sim.units:
        if u["troops"]>0 and not u["routed"]: standing[u["side"]]+=1
        if u["side"]==1: wei_losses+=float(u["casualties_taken"])
        if u["side"]==0:
            flank+=float(u["flank_damage"])
            linked+=float(u["linked_hits"])
            if u["bridge_crossings"]>0 and u["troops"]>0 and u["pos"].x>sim.river_x(u["pos"].y): crossed+=1
    if standing[0]==0 and sim.reinforcements_used[0]>=sim.reserve_limit[0]:
        sim._finish("아군 전투 불능 — 패배")
        return
    if standing[1]==0 and sim.reinforcements_used[1]>=sim.reserve_limit[1] and mode not in ["siege","capital"]:
        sim._finish("위군 전투 불능 — 승리")
        return
    if sim.battle_time<sim.LONG_OBJECTIVE_OPEN: return
    var required:=30.0 if mode in ["siege","capital"] else 45.0
    var count:=0
    for post in sim.outposts:
        if post["owner"]==0 and post["hold"]>=required: count+=1
    var first: bool=site["owner"]==0 and site["hold"]>=required
    var second: bool=sim.outposts[1]["owner"]==0 and sim.outposts[1]["hold"]>=required
    var timed_out: bool=sim.battle_time>=sim.scenario_limit
    var won:=false
    match mode:
        "field": won=count>=2 or wei_losses>=10000
        "sites": won=count>=2
        "lure": won=first and c["baited"]
        "hold": won=timed_out and first
        "flank": won=first and flank>=150
        "fronts","line": won=first and second
        "siege","capital": won=first and sim.structures[0]["hp"]<=0
        "duel": won=first and sim.total_troops(0)>sim.total_troops(1)
        "river": won=first and crossed>=2
        "link": won=first and linked>=120
        "decisive": won=count>=2 and sim.total_troops(1)<=0.7*float(c["enemy_initial"])
    if won or timed_out:
        sim._finish(sim.scenario_title+(" — 승리" if won else " 목표 미달 — 패배"),"%s · 확보 %d곳 · 아군 %d명 / 위군 %d명" % [site["name"],count,sim.total_troops(0),sim.total_troops(1)])
