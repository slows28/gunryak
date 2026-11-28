extends RefCounted
## Pick a legal opening station within the scenario's assembly sector. Keep the
## authored anchor so reviewing orders can never walk an army across the map.
static func arrange(sim) -> void:
    if sim.started or not sim.long_operation: return
    for unit in sim.units:
        if not unit.has("assembly_origin"): unit.assembly_origin = unit.pos
    var officers: Array = sim.units.duplicate()
    officers.sort_custom(func(a,b): return a.deployment > b.deployment if a.deployment != b.deployment else a.id < b.id)
    var occupied := {}
    for u in officers:
        if u.reserve or u.troops <= 0 or u.has("parent_id"): continue
        var facing := Vector2.RIGHT if u.side == 0 else Vector2.LEFT
        var area: Rect2 = sim.deployment_area()
        if u.side == 1: area.position.x = sim.field_size.x - area.end.x
        var origin: Vector2 = u.assembly_origin
        var order: Dictionary = sim.opening_letters.get(u.id,{})
        var mission: String = order.get("mission",u.mission)
        var pin: Vector2 = order.get("destination",u.order_destination if u.has_destination else origin)
        var anchor := origin
        var guard := mission == "본진 방어"
        var ground: String = sim.terrain_at(origin)
        var skilled: bool = u.deployment >= 75
        var why := "보병 선열"
        var shape := "방진" if mission in ["지역 사수","본진 방어"] else "횡대"
        var depth := 78.0
        if guard:
            anchor = sim._home_point(u.side)
            depth = 58.0
            shape = "방진"
            why = "본진 주둔"
        elif u.type == "궁병":
            depth = -82.0
            shape = "안행진" if skilled else "횡대"
            why = "궁병 후열"
        elif u.type == "기병":
            depth = 6.0
            anchor.y += -68.0 if origin.y < sim.field_size.y*0.5 else 68.0
            shape = "봉시진" if skilled and ground in ["평지","도로"] else "종대"
            why = "기병 측익"
        elif skilled and mission == "공격":
            shape = "어린진"
        if not guard: anchor.y += clampf(pin.y-origin.y,-180.0,180.0)*0.36
        var ideal := anchor + facing*depth
        var skill: float = u.deployment / 100.0
        var preferred := origin.lerp(ideal,clampf((skill-0.3)/0.6,0.15,1.0)) if not guard else ideal
        var best: Vector2 = origin
        var best_cost := INF
        for along in [0,-55,55,-110,110]:
            for across in [0,-60,60,-120,120]:
                var point := preferred + facing*float(along) + Vector2.DOWN*float(across)
                if not area.has_point(point) or sim.in_open_water(point): continue
                var blocked := false
                for structure in sim.structures:
                    if structure.hp > 0 and Rect2(structure.rect).grow(12).has_point(point): blocked = true; break
                if blocked: continue
                for other in officers:
                    if other.id==u.id or other.reserve or other.troops<=0: continue
                    var other_point: Vector2=occupied.get(other.id,other.assembly_origin)
                    if point.distance_squared_to(other_point)<56.0*56.0: blocked=true; break
                if blocked: continue
                var terrain: String = sim.terrain_at(point)
                var cost := point.distance_to(preferred)
                if u.type=="궁병" and terrain=="고지": cost -= 72.0*skill
                if u.type=="기병" and terrain not in ["도로","평지"]: cost += 90.0*skill
                if cost<best_cost: best=point; best_cost=cost
        occupied[u.id]=best
        u.pos=best
        u.goal=best
        u.facing=facing
        u.formation=shape
        u.deployment_reason=why+" · "+sim.terrain_at(best)
        if u.defense_set: u.defense_anchor=best
        if u.has("hq_defense_offset"): u.hq_defense_offset=best-sim._home_point(u.side)
        if u.has("rally_origin"): u.rally_origin=best
    sim.RallyOrders.refresh(sim)
