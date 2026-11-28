extends RefCounted
## Shared stations belong to received map orders. The original pin remains the
## strategic objective; stations use the common direction of approach.
const March = preload("res://scripts/linked_march.gd")
const MISSIONS = ["지정 위치 이동", "지역 사수", "예비 대기", "공격"]

# A field signal carries a witnessed position. An unseen attacker cannot be tracked.
static func signal_contact(sim, struck: Dictionary, attacker_id: int, source: Vector2) -> void:
    if not sim.long_operation or sim.battle_time-struck.get("last_group_call",-100.0)<3.0: return
    struck["last_group_call"]=sim.battle_time
    for member in sim.units:
        if member.side!=struck.side or member.troops<=0 or member.reserve or member.routed: continue
        var grouped: bool=struck.has("order_group") and member.get("order_group",-1)==struck.order_group
        if not grouped:
            if member.id==struck.id or member.mission in ["예비 대기","본진 방어","철수","보급기지 수색"]: continue
            # Corps already on shared stations keep their existing ranked relief logic.
            if struck.id in member.get("rally_station",{}).get("members",[]) and Vector2(struck.pos).distance_to(struck.rally_station.point)<=115.0 and Vector2(member.pos).distance_to(member.rally_station.point)<=155.0: continue
            if not _local_help(sim,member,struck): continue
            # A frontline already exchanging blows holds its engagement. Local
            # reinforcements come from corps able to turn towards the caller.
            var committed: int=member.get("last_strike_target",-1)
            if committed>=0 and committed!=attacker_id and sim.battle_time-member.get("last_strike_at",-100.0)<3.0: continue
            if sim.battle_time-member.last_hit<2.6 and member.get("last_attacker",-1)!=attacker_id: continue
        var prior: Dictionary=member.get("group_signal",{})
        var gap: float=Vector2(member["pos"]).distance_to(struck["pos"])
        if not prior.is_empty() and sim.battle_time<prior["expires"]:
            if sim.battle_time<prior["arrives"]: continue
            if prior["ally"]==struck["id"] and prior["target"]==attacker_id: continue
            if prior["ally"]!=struck["id"] and prior["gap"]<=gap: continue
        var arrives: float=sim.battle_time+gap/160.0
        member["group_signal"]={"ally":struck["id"],"target":attacker_id,"source":source,"point":struck["pos"],"gap":gap,"arrives":arrives,"expires":arrives+6.0,"local":not grouped}

static func group_response(sim, unit: Dictionary) -> Dictionary:
    var call: Dictionary=unit.get("group_signal",{})
    if call.is_empty() or sim.battle_time<call["arrives"] or sim.battle_time>=call["expires"]: return {}
    if unit["routed"] or unit["reserve"] or unit["mission"] in ["철수","본진 방어"] or unit["morale"]<32 or unit["tactical_until"]>sim.battle_time: return {}
    var ally: Dictionary=sim.find_unit(call["ally"])
    if ally.is_empty() or ally.troops<=0 or ally.routed: return {}
    var local: bool=call.get("local",false)
    if local:
        if not _local_help(sim,unit,ally): return {}
    elif not unit.has("order_group") or ally.get("order_group",-1)!=unit.order_group: return {}
    var foe: Dictionary=sim.find_unit(call["target"])
    var seen: bool=not foe.is_empty() and sim._locally_observed(unit,foe)
    if local and not seen: return {}
    var point: Vector2=call["point"]
    var source: Vector2=foe["pos"] if seen else call["source"]
    var front:=point.direction_to(source)
    if front.is_zero_approx(): front=unit["facing"]
    if not seen: source=point+front*32.0
    var slot: Dictionary=unit.get("rally_station",{})
    var lane:=clampf((Vector2(slot.get("point",unit["pos"]))-point).dot(front.orthogonal()),-48.0,48.0)
    var goal:=point+front*minf(32.0,point.distance_to(source))+front.orthogonal()*lane
    if unit["type"]=="궁병": goal=source-front*145.0+front.orthogonal()*lane
    if unit["type"]=="기병" and ally["id"]!=unit["id"]:
        # Screen the attacked wing. Cavalry only closes on a committed foe.
        var occupied: bool=seen and foe.get("last_strike_target",-1)==ally["id"] and ally["type"]=="보병"
        var wing:=front.orthogonal()*(1.0 if lane>=0.0 else -1.0)
        goal=source+wing*44.0 if occupied and unit["cohesion"]>=45.0 else point-front*50.0+wing*42.0
    if unit["mission"] in ["지역 사수","예비 대기"] and unit["has_destination"]:
        var anchor: Vector2=unit["order_destination"]
        goal=anchor+(goal-anchor).limit_length(142.0)
    return {"action":"아군 보호","goal":sim._field_point(goal),"ally":ally["id"],"target":foe["id"] if seen else -1,"reason":("%s군 피격 · 같은 지역에서 지원" if local else "%s군 피격 방향으로 연계 대응") % ally["name"],"rally_cover":true}

static func _local_help(sim, unit: Dictionary, ally: Dictionary) -> bool:
    var here: Vector2=unit.pos
    var point: Vector2=ally.pos
    if here.distance_squared_to(point)>185.0*185.0 or sim._river_separates(here,point): return false
    if unit.mission in ["예비 대기","본진 방어","철수","보급기지 수색"] or unit.troops<600 or unit.cohesion<40 or unit.morale<35: return false
    if unit.has_destination and unit.mission=="지역 사수" and point.distance_to(unit.order_destination)>135.0: return false
    # A mounted vanguard already covering its sector answers through its own
    # wait/flank/charge sequence, which commits to a rider's real contact.
    if unit.type=="기병" and (unit.has("mounted_anchor") or unit.flank_phase>0 or unit.action in ["기병 대기","협동 우회","측면 우회","돌파"]): return false
    if unit.type=="궁병" and unit.ammo<12: return false
    return true

static func refresh(sim) -> void:
    var groups: Array[Array] = []
    for unit in sim.units:
        unit.erase("rally_station")
        if not unit.has("rally_origin") or not unit["has_destination"] or unit["troops"] <= 0 or unit["mission"] not in MISSIONS:
            continue
        var pin: Vector2 = unit["order_destination"]
        # Nearby clicks can denote one patch of ground. Compare against a fixed
        # pin so a chain of orders cannot merge fronts or span a riverbank.
        var matched := false
        for members in groups:
            var leader: Dictionary = members[0]
            var anchor: Vector2 = leader["order_destination"]
            if leader["side"]!=unit["side"] or (leader["mission"]=="예비 대기")!=(unit["mission"]=="예비 대기"): continue
            if pin.distance_to(anchor)>32.0 or sim._river_separates(pin,anchor) or sim._detour_goal(unit,pin,anchor)!=anchor: continue
            members.append(unit)
            matched = true
            break
        if not matched: groups.append([unit])
    for members in groups:
        if members.size() < 2: continue
        var group: Array[Dictionary] = []
        group.assign(members)
        group.sort_custom(func(a,b): return a["id"] < b["id"])
        var pin: Vector2 = group[0]["order_destination"]
        var origin := Vector2.ZERO
        for unit in group: origin += Vector2(unit["rally_origin"])
        var forward := (origin / group.size()).direction_to(pin)
        if forward.is_zero_approx(): forward = group[0]["facing"]
        var deck: bool = sim.terrain_at(pin) == "교량"
        if deck: forward = Vector2.RIGHT if origin.x/group.size() < pin.x else Vector2.LEFT
        var slots := March._deck_slots(group,group[0]) if deck else March._slots(group,4)
        var members_at_pin := PackedInt32Array()
        for member in group: members_at_pin.append(member["id"])
        var occupied := PackedVector2Array()
        for unit in group:
            var slot: Dictionary = slots[unit["id"]]
            var offset: Vector2 = slot["offset"]
            var desired := pin + forward * offset.x + Vector2(-forward.y,forward.x) * offset.y
            var point := _place(sim,unit,pin,desired,occupied)
            occupied.append(point)
            unit["rally_station"] = {"point":point,"forward":forward,"role":slot["role"],"count":group.size(),"members":members_at_pin}

static func _place(sim, unit: Dictionary, pin: Vector2, desired: Vector2, occupied: PackedVector2Array) -> Vector2:
    # On the riverbank, at a wall or at a map edge, find a dry, separate berth.
    var best: Vector2 = pin
    var best_score := INF
    for ring in range(5):
        for i in (1 if ring == 0 else 12):
            var point: Vector2 = sim._field_point(desired + Vector2.from_angle(i*TAU/12.0)*ring*64.0)
            if sim.in_open_water(point) or sim._river_separates(pin,point) or sim._structure_move(unit,pin,point) != point: continue
            var clearance := 100.0
            for other in occupied: clearance = minf(clearance,point.distance_to(other))
            var score := point.distance_to(desired) + 4.0*maxf(0,75.0-clearance)
            if score < best_score:
                best = point
                best_score = score
            if is_zero_approx(score): return best
        if best_score <= (ring+1)*64.0: break
    return best

static func decision(sim, unit: Dictionary, enemy: Dictionary, action: String) -> Dictionary:
    if not unit.has("rally_station") or unit["routed"] or unit["rallying"] or sim.battle_time < unit["tactical_until"]: return {}
    if action in ["패주","후퇴","재집결","전술 철수","휴식","탄약 보충","보급 복귀","계획 경유","전술 재집결","긴급 방어","긴급 지원"]: return {}
    var station: Dictionary = unit["rally_station"]
    var point: Vector2 = station["point"]
    var p: Vector2 = unit["pos"]
    var distance := p.distance_to(point)
    unit["destination_reached"] = distance <= 18.0
    var role: String = station["role"]
    if not enemy.is_empty() and unit["mission"]!="예비 대기":
        var cover := _support_contact(sim,unit,station,enemy)
        if cover.is_empty() and distance<=66.0:
            cover = _cover_arrival(sim,unit,station)
        if not cover.is_empty(): return cover
    if not enemy.is_empty() and not enemy["routed"] and not sim._river_separates(p,enemy["pos"]):
        var foe: Vector2 = enemy["pos"]
        var ahead := p.direction_to(point).dot(p.direction_to(foe))
        if unit["type"] == "궁병" and action == "거리 유지" and p.distance_to(foe) < 110.0 and ahead > -0.25: return {}
        if unit["type"] != "궁병" and ((ahead > 0.35 and p.distance_to(foe) < 88.0) or (unit["mission"] == "공격" and foe.distance_to(unit["order_destination"]) < 200.0 and distance < 65.0)):
            return {"action":"교전","reason":"공동 집결 · "+role+" 진로의 적과 교전","goal":foe}
    if distance <= 12.0:
        return {"action":"예비 대기" if unit["mission"]=="예비 대기" else "지정 지역 사수","reason":"공동 집결 · "+role+" 정렬 완료","goal":p}
    return {"action":"지정 위치 이동","reason":"공동 집결 · "+role+" 위치로 이동","goal":point}

# A received group order also covers members who arrived first. A helper
# must see the attacker and stay within one local move of its assigned post.
static func _support_contact(sim, unit: Dictionary, station: Dictionary, nearest: Dictionary) -> Dictionary:
    var p: Vector2 = unit["pos"]
    var post: Vector2 = station["point"]
    var bow: bool = unit["type"] == "궁병"
    if p.distance_to(post)>220.0 or unit["troops"]<600 or unit["cohesion"]<40 or unit["morale"]<35: return {}
    if bow and (unit["ammo"]<12 or (nearest["type"]!="궁병" and p.distance_to(nearest["pos"])<110.0)): return {}
    var members: PackedInt32Array = station["members"]
    var best := {}
    var cost := INF
    for ally_id in members:
        if ally_id==unit["id"]: continue
        var ally: Dictionary=sim.find_unit(ally_id)
        if sim.battle_time-ally["last_hit"]>3.0: continue
        var foe: Dictionary=sim.find_unit(ally.get("last_attacker",-1))
        if foe.is_empty() or foe["routed"] or not sim._locally_observed(unit,foe): continue
        var ap: Vector2 = ally["pos"]
        if ally["routed"] or ally["troops"]<600: continue
        # An arriving column can come under fire in the helper's assigned sector.
        if minf(ap.distance_to(ally["rally_station"]["point"]),ap.distance_to(post))>120.0: continue
        if p.distance_to(ap)>225.0 or sim._river_separates(p,ap): continue
        var ep: Vector2 = foe["pos"]
        if nearest["id"]!=foe["id"] and sim._in_melee(unit,nearest): continue
        var approach := ep.direction_to(p)
        # Mounted reserves may meet an exposed flank; an observed, stronger
        # line facing the horse still calls for waiting on the infantry.
        if unit["type"]=="기병" and approach.dot(foe["facing"])>0.25 and (foe["troops"]>=unit["troops"] or foe["formation"]=="방진"): continue
        var goal := ep + approach*minf(28.0,p.distance_to(ep))
        if bow:
            goal = p if p.distance_to(ep)<=166.0 else ep+approach*150.0
        elif sim._river_separates(p,ep): continue
        var leash := 125.0 if unit["mission"]=="지역 사수" else 185.0
        if goal.distance_to(post)>leash or sim.in_open_water(goal) or sim._river_separates(p,goal) or sim._detour_goal(unit,p,goal)!=goal: continue
        var responders := 0
        for id in members:
            if id==unit["id"]: continue
            var other: Dictionary = sim.find_unit(id)
            if other["routed"] or other["troops"]<600: continue
            if other.get("rally_covering",false) and other.get("field_choice",{}).get("ally",-1)==ally_id: responders+=1
        if responders>=2: continue
        var travel := p.distance_to(goal) + float(responders)*40.0
        var request: Dictionary=unit.get("rally_request",{})
        if request.get("end",-1.0)>sim.battle_time and request["ally"]==ally_id: travel-=65.0
        if travel>=cost: continue
        cost = travel
        best = {"action":"아군 보호","goal":goal,"ally":ally_id,"target":foe["id"],"rally_cover":true,
            "reason":"공동 집결 · %s군을 공격한 %s군에 %s" % [ally["name"],foe["name"],"엄호 사격" if bow else "구원 기동"]}
    return best

# A corps already on station covers a late member inside its assigned area.
# Re-evaluate the actual shot or intercept on each normal command decision.
static func _cover_arrival(sim, unit: Dictionary, station: Dictionary) -> Dictionary:
    var p: Vector2=unit["pos"]
    var post: Vector2=station["point"]
    var bow: bool=unit["type"]=="궁병"
    if unit["cohesion"]<40 or unit["morale"]<35 or (bow and unit["ammo"]<12): return {}
    if p.distance_to(post)>28.0 and not unit.get("rally_covering",false): return {}
    var best := {}
    var best_gap := INF
    for id in station.get("members",PackedInt32Array()):
        if id==unit["id"]: continue
        var ally: Dictionary=sim.find_unit(id)
        if ally.is_empty() or ally["troops"]<600 or ally["routed"] or not ally.has("rally_station"): continue
        var ap: Vector2=ally["pos"]
        if ap.distance_to(ally["rally_station"]["point"])<=28 or ap.distance_to(post)>180 or sim._river_separates(p,ap): continue
        var threat: Dictionary=sim._observed_threat_to(unit,ally)
        if threat.is_empty(): continue
        var foe: Vector2=threat["pos"]
        var gap:=ap.distance_to(foe)
        if gap>118 or gap>=best_gap or sim._river_separates(p,foe): continue
        var intercept:=ap.lerp(foe,0.5)
        var goal:=p if bow else post+(intercept-post).limit_length(56.0)
        if bow:
            if p.distance_to(foe)<110.0 or p.distance_to(foe)>173.0: continue
        elif goal.distance_to(intercept)>32 or sim.in_open_water(goal) or sim._river_separates(p,goal) or sim._detour_goal(unit,p,goal)!=goal: continue
        best_gap=gap
        best={"action":"아군 보호","goal":goal,"ally":id,"target":threat["id"],"rally_cover":true,
            "reason":"공동 집결 · %s군이 합류하도록 %s" % [ally["name"],"엄호 사격" if bow else "접근로 엄호"]}
    return best
