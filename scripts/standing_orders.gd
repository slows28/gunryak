extends RefCounted
## Instructions delivered with the map order. Search knowledge belongs to the corps.
const RAID := "보급기지 수색"
const SWEEP_ROWS := 7

static func clear(unit: Dictionary) -> void:
    for key in ["encounter","raid_withdrawing","search_position","search_leg"]:
        unit.erase(key)

static func decide(sim, unit: Dictionary, enemy: Dictionary, action: String) -> Dictionary:
    var mode: String = unit.get("encounter","")
    var raid: bool = unit.mission == RAID
    if mode.is_empty() and not raid: return {}
    if not unit.has_destination or unit.routed or unit.rallying or unit.morale < 19 or unit.troops < 600: return {}
    if sim.command_confused(unit.side) or sim.battle_time < unit.tactical_until: return {}
    if action in ["패주","후퇴","휴식","재집결","보급 복귀","탄약 보충","사기 혼란"]: return {}
    if raid: return _search(sim,unit,enemy)
    if enemy.is_empty() or unit.mission == "본진 방어" or action in ["거리 유지","기병 대기"]: return {}
    var here: Vector2 = unit.pos
    if here.distance_to(enemy.pos) > 170.0 or sim._river_separates(here,enemy.pos): return {}
    match mode:
        "공격":
            if unit.type == "기병" and action in ["협동 우회","측면 우회"]: return {}
            return _engage(unit,enemy,"진군 중 관측한 적과 교전")
        "사수":
            return {"action":"전열 유지","reason":"조우 지시 · 현 위치에서 전열 사수","goal":here,"target":enemy.id}
        "지원":
            var ally: Dictionary = {}
            var best := 245.0
            for friend in sim.units:
                if friend.side != unit.side or friend.id == unit.id or friend.troops <= 0 or friend.routed or friend.reserve: continue
                var gap := here.distance_to(friend.pos)
                if gap >= best or Vector2(friend.pos).distance_to(enemy.pos) > 150.0 or sim._river_separates(here,friend.pos): continue
                ally = friend
                best = gap
            if not ally.is_empty():
                var order := _engage(unit,enemy,"%s군이 맞선 적을 지원" % ally.name)
                order.ally = ally.id
                return order
            return {"action":"전열 유지","reason":"지원할 아군을 기다리며 전열 유지","goal":here,"target":enemy.id}
    return {}

static func _engage(unit: Dictionary, enemy: Dictionary, why: String) -> Dictionary:
    var action := "돌파" if unit.type == "기병" else "교전"
    var goal: Vector2 = enemy.pos
    if unit.type == "궁병" and Vector2(unit.pos).distance_to(enemy.pos) <= 155.0:
        action = "엄호 사격"
        goal = unit.pos
    return {"action":action,"reason":why,"goal":goal,"target":enemy.id}

static func _search(sim, unit: Dictionary, enemy: Dictionary) -> Dictionary:
    var here: Vector2 = unit.pos
    if unit.get("raid_withdrawing",false):
        return {"action":"전술 철수","reason":"수색 중 적 발견 · 습격 중단 후 본진 복귀","goal":sim._home_point(unit.side)}
    var observed: Dictionary = {}
    var nearest := INF
    for base in sim.bases:
        if base.side == unit.side or not sim._can_see_base(unit,base): continue
        var distance := here.distance_to(base.pos)
        if distance < nearest:
            observed = base
            nearest = distance
    if not observed.is_empty():
        unit.search_position = observed.pos
        if not enemy.is_empty() and Vector2(enemy.pos).distance_to(observed.pos) <= sim.GUARD_RADIUS and not sim._river_separates(here,enemy.pos):
            return _engage(unit,enemy,"습격 속행 · 보급기지 수비대와 교전")
        return {"action":"기지 습격","reason":"정찰로 확인한 적 보급기지 급습","goal":observed.pos}
    if unit.has("search_position"):
        var last: Vector2 = unit.search_position
        if here.distance_to(last) >= 210.0 * sim.watch_factor(here,unit.side):
            return {"action":RAID,"reason":"마지막으로 관측한 기지 위치 재확인","goal":last}
        unit.erase("search_position")
    if not enemy.is_empty() and here.distance_to(enemy.pos) < 115.0 and not sim._river_separates(here,enemy.pos):
        return _engage(unit,enemy,"수색 속행 · 진로를 막는 적과 교전")
    # Visit the ordered waypoint first. Then sweep the opposite bank, starting
    # from its nearest lane. No base coordinate is used to plan this route.
    var pin: Vector2 = unit.order_destination
    var leg: int = unit.get("search_leg",-1)
    if leg < 0 and here.distance_to(pin) > 40.0:
        return {"action":RAID,"reason":"수색 출발 거점으로 이동","goal":pin}
    leg=maxi(0,leg)
    var first_row := clampi(floori(pin.y / sim.field_size.y * SWEEP_ROWS),0,SWEEP_ROWS-1)
    for attempt in range(SWEEP_ROWS*2):
        @warning_ignore("integer_division")
        var row := (first_row + leg/2) % SWEEP_ROWS
        var x := 0.94 if leg % 4 in [1,2] else 0.56
        var goal: Vector2 = sim.field_size * Vector2(x if unit.side==0 else 1.0-x, (row+0.5)/SWEEP_ROWS)
        var blocked: bool = sim.in_open_water(goal)
        for structure in sim.structures:
            if structure.hp>0 and Rect2(structure.rect).grow(8).has_point(goal): blocked=true
        if not blocked and here.distance_to(goal)>40.0:
            unit.search_leg=leg
            return {"action":RAID,"reason":"적 진영 순찰 · 보급기지 미발견","goal":goal}
        leg=(leg+1)%(SWEEP_ROWS*2)
    return {"action":RAID,"reason":"수색 구역 관측 중","goal":here}
