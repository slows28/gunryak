extends RefCounted
## Shared stations belong to received map orders. The original pin remains the
## strategic objective; stations use the common direction of approach.
const March = preload("res://scripts/linked_march.gd")
const MISSIONS = ["지정 위치 이동", "지역 사수", "예비 대기", "공격"]

static func refresh(sim) -> void:
    var groups := {}
    for unit in sim.units:
        unit.erase("rally_station")
        if not unit.has("rally_origin") or not unit["has_destination"] or unit["troops"] <= 0 or unit["mission"] not in MISSIONS:
            continue
        var pin: Vector2 = unit["order_destination"]
        var key := Vector4i(unit["side"], MISSIONS.find(unit["mission"]), roundi(pin.x), roundi(pin.y))
        if not groups.has(key): groups[key] = []
        groups[key].append(unit)
    for members: Array in groups.values():
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
    if action in ["패주","후퇴","재집결","전술 철수","휴식","탄약 보충","보급 복귀","계획 경유"]: return {}
    var station: Dictionary = unit["rally_station"]
    var point: Vector2 = station["point"]
    var p: Vector2 = unit["pos"]
    var distance := p.distance_to(point)
    unit["destination_reached"] = distance <= 18.0
    var role: String = station["role"]
    if distance <= 66.0 and not enemy.is_empty() and unit["mission"]!="예비 대기":
        var cover := _cover_arrival(sim,unit,station)
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
        best={"action":"아군 보호","goal":goal,"ally":id,"target":threat["id"],"arrival_cover":true,
            "reason":"공동 집결 · %s군이 합류하도록 %s" % [ally["name"],"엄호 사격" if bow else "접근로 엄호"]}
    return best
