extends RefCounted
## March orders for one movement tick, calculated before any corps takes its step.
## Local offsets use forward / right coordinates, independent of the faction.
const COOPERATIVE_MISSIONS = ["전열 엄호","측후방 기동","구원 지원","궁병 보호"]
const INTERRUPTS = ["후퇴","패주","재집결","전술 재집결","휴식","탄약 보충","보급 복귀","전술 철수","거리 유지","측면 방어","긴급 방어","긴급 지원","궁병 보호","교전","반격"]

static func _partner(unit: Dictionary, now: float) -> int:
    if int(unit["assigned_link"])>=0: return unit["assigned_link"]
    if now<float(unit["ai_role_until"]) and unit["ai_role"] in COOPERATIVE_MISSIONS:
        return unit["ai_partner"]
    return unit["link_id"] if unit["mission"] in COOPERATIVE_MISSIONS else -1

static func _available(unit: Dictionary) -> bool:
    return unit["troops"]>0 and not unit["routed"] and unit["mission"]!="철수" and unit["action"] not in INTERRUPTS

static func _companies(sim, edit_id: int=-1, partner_override: int=-1) -> Array:
    var groups: Array=[]
    var neighbors: Dictionary={}
    for unit in sim.units:
        var partner_id:=partner_override if unit["id"]==edit_id else _partner(unit,sim.battle_time)
        if partner_id<0 or not _available(unit): continue
        var partner: Dictionary=sim.find_unit(partner_id)
        if partner.is_empty() or partner["side"]!=unit["side"] or not _available(partner): continue
        var id: int=unit["id"]
        if not neighbors.has(id): neighbors[id]=[]
        if not neighbors.has(partner_id): neighbors[partner_id]=[]
        neighbors[id].append(partner_id)
        neighbors[partner_id].append(id)
    var visited: Dictionary={}
    for id: int in neighbors:
        if visited.has(id): continue
        var queue: Array=[id]
        var group: Array[Dictionary]=[]
        visited[id]=true
        while not queue.is_empty():
            var member: int=queue.pop_back()
            group.append(sim.find_unit(member))
            for other: int in neighbors[member]:
                if not visited.has(other):
                    visited[other]=true
                    queue.append(other)
        group.sort_custom(func(a,b): return a["id"]<b["id"])
        groups.append(group)
    return groups

static func plan(sim, previous: Dictionary, dt: float) -> Dictionary:
    var plans: Dictionary={}
    for group: Array in _companies(sim): _plan_group(sim,group,previous,dt,plans)
    return plans

static func _guide(group: Array[Dictionary], now: float) -> Dictionary:
    var best:=group[0]
    for unit in group:
        if unit["has_destination"]:
            if not best["has_destination"] or int(unit.get("march_sequence",0))>int(best.get("march_sequence",0)):
                best=unit
        elif not best["has_destination"] and _partner(best,now)>=0 and _partner(unit,now)<0:
            best=unit
    return best

static func _slots(group: Array[Dictionary]) -> Dictionary:
    var ranks: Dictionary={}
    for unit in group:
        var kind: String=unit["type"]
        if not ranks.has(kind): ranks[kind]=[]
        ranks[kind].append(unit["id"])
    var slots: Dictionary={}
    var width: float=maxi(ranks.get("보병",[]).size(),ranks.get("궁병",[]).size())*45.0+60.0
    for kind: String in ranks:
        var line: Array=ranks[kind]
        for i in range(line.size()):
            var offset:=Vector2(0.0,(i-(line.size()-1)*0.5)*90.0)
            var role: String="나란히"
            if ranks.size()>1:
                match kind:
                    "보병":
                        offset.x=45.0
                        role="전열"
                    "궁병":
                        offset.x=-62.0
                        role="후열"
                    "기병":
                        offset.y=(width+floori(i/2.0)*90.0)*(1.0 if i%2==0 else -1.0)
                        role="우익" if offset.y>0 else "좌익"
            slots[line[i]]={"offset":offset,"role":role}
    return slots

static func preview(sim, selected: Dictionary, partner_id: int, destination: Vector2) -> Dictionary:
    for group: Array in _companies(sim,selected["id"],partner_id):
        if not group.has(selected): continue
        var slots:=_slots(group)
        var heading:=Vector2(selected["pos"]).direction_to(destination)
        if heading.is_zero_approx(): heading=selected["facing"]
        var crossing: float=sim.map_order_crossing(selected["id"],destination)
        if crossing>=0:
            var entry:=Vector2(sim.river_x(crossing),crossing)
            heading=Vector2(selected["pos"]).direction_to(entry)
        var limiter: String=""
        var pace: float=INF
        var captions:=PackedStringArray()
        for unit in group:
            var rate: float=sim._movement_rate(unit,sim._nearest_visible_enemy(unit))
            if rate<pace:
                pace=rate
                limiter=unit["name"]
            var role: String=slots[unit["id"]]["role"]
            var caption: String="%s %s" % [unit["type"],role]
            if caption not in captions: captions.append(caption)
        return {"group":group,"slots":slots,"forward":heading,"limiter":limiter,"caption":" · ".join(captions)}
    return {}

static func _plan_group(sim, group: Array[Dictionary], previous: Dictionary, dt: float, plans: Dictionary) -> void:
    var guide:=_guide(group,sim.battle_time)
    var origin: Vector2=guide["pos"]
    var target: Vector2=guide["goal"]
    if guide["action"]!="계획 경유":
        if guide["has_destination"]: target=guide["order_destination"]
        elif _partner(guide,sim.battle_time)>=0: target=sim._mission_point(guide["side"],guide["mission"])
    var slowest:=guide
    var pace: float=INF
    for unit in group:
        var enemy: Dictionary=sim._nearest_visible_enemy(unit)
        if not enemy.is_empty() and Vector2(unit["pos"]).distance_to(enemy["pos"])<205.0: return
        var rate: float=sim._movement_rate(unit,enemy)
        if rate<pace:
            pace=rate
            slowest=unit
    var prior: Dictionary=previous.get(guide["id"],{})
    var bridge: float=-1.0
    var crossing: bool=false
    var bank: int=1 if target.x>=sim.river_x(target.y) else -1
    if sim.long_operation:
        for unit in group:
            var p: Vector2=unit["pos"]
            var bank_distance: float=(p.x-sim.river_x(p.y))*bank
            if bank_distance>=0:
                if bank_distance<60.0 and float(prior.get("bridge",-1))>=0.0: bridge=prior["bridge"]
                continue
            if float(prior.get("bridge",-1))>=0 and prior.get("bank",0)==bank: bridge=prior["bridge"]
            else: bridge=sim.map_order_crossing(unit["id"],target)
            break
    if bridge>=0.0:
        var entry:=Vector2(sim.river_x(bridge)-bank*155.0,bridge)
        crossing=origin.distance_to(entry)<135.0 or (origin.x-sim.river_x(origin.y))*bank>=0 or (prior.get("phase","")=="도하" and prior.get("bank",0)==bank)
        if not crossing: target=entry
    var forward: Vector2=prior.get("forward",guide["facing"])
    if origin.distance_to(target)>6.0: forward=origin.direction_to(target)
    if forward.is_zero_approx(): forward=Vector2.RIGHT if guide["side"]==0 else Vector2.LEFT
    if crossing: forward=Vector2(bank,0)
    var right:=Vector2(-forward.y,forward.x)
    var slots:=_slots(group)
    var waiting: bool=false
    for unit in group:
        var slot: Dictionary=slots[unit["id"]]
        var local: Vector2=slot["offset"]-slots[guide["id"]]["offset"]
        var point: Vector2=sim._field_point(origin+forward*local.x+right*local.y)
        if crossing:
            # Spread the rally points beyond the exit so later corps can clear the deck.
            point=Vector2(sim.river_x(bridge)+bank*(185.0+slot["offset"].x),bridge+slot["offset"].y)
        else:
            # A flank slot beside the river must stay on the guide's bank.
            var guide_bank: float=signf(origin.x-sim.river_x(origin.y))
            if sim.long_operation and (point.x-sim.river_x(point.y))*guide_bank<34.0:
                point.x=sim.river_x(point.y)+guide_bank*34.0
            if Vector2(unit["pos"]).distance_to(point)>42.0: waiting=true
        slot["point"]=point
    var shift:=Vector2.ZERO
    if not waiting and not crossing: shift=origin.move_toward(target,pace*dt)-origin
    for unit in group:
        var id: int=unit["id"]
        var slot: Dictionary=slots[id]
        var phase: String="도하" if crossing else ("대형 집결" if waiting else "연계 행군")
        if not waiting and not crossing and origin.distance_to(target)<=2.0: phase="대형 유지"
        var peer: Dictionary=guide if id!=guide["id"] else (group[1] if group[0]["id"]==id else group[0])
        plans[id]={"goal":sim._field_point(slot["point"]+shift),"forward":forward,"pace":pace,
            "role":slot["role"],"phase":phase,"slowest":slowest["name"],"peer":peer["id"],"bridge":bridge,"bank":bank}
