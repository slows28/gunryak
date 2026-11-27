extends RefCounted
## Short local navigation goals for a surrounded corps. Only visible bodies and
## the game's impassable terrain participate in the choice.
const STEP := 116.0

static func decision(sim, unit: Dictionary) -> Dictionary:
    var must_hold: bool = sim.battle_time < unit["tactical_until"] and unit["tactical_order"] not in ["철수","재집결"]
    if unit["routed"] or must_hold or unit["mission"] == "본진 방어":
        unit.erase("escape_step")
        return {}
    var p: Vector2 = unit["pos"]
    var previous: Dictionary = unit.get("escape_step",{})
    if not unit["surrounded"] and previous.is_empty(): return {}
    var threats := PackedVector2Array()
    var observed: Array[Dictionary] = []
    var close_foes := 0
    for other in sim.units:
        if other["side"] == unit["side"] or other["troops"] <= 0 or other["routed"]: continue
        var pos: Vector2 = other["pos"]
        if p.distance_squared_to(pos) < 160.0*160.0 and sim._locally_observed(unit,other) and not sim._river_separates(p,pos):
            threats.append(pos)
            observed.append(other)
            if p.distance_squared_to(pos) <= 95.0*95.0: close_foes += 1
    var stalled_axis := Vector2.ZERO
    if not previous.is_empty():
        var target: Vector2 = previous["goal"]
        var moved: float = Vector2(previous["last_pos"]).distance_to(p)
        if moved < 5.0 and sim.battle_time - previous["checked_at"] >= 1.2:
            stalled_axis = p.direction_to(target)
        elif sim.battle_time < previous["until"] and p.distance_to(target) > 12.0 and _clearance(p,target,threats) > 16.0:
            if moved >= 5.0:
                previous["last_pos"] = p
                previous["checked_at"] = sim.battle_time
            return previous
        unit.erase("escape_step")
    if not unit["surrounded"] or observed.size() < 2 or not sim._encirclement(unit,observed): return {}
    # Nearby formed corps can hold a shared front. Do not peel a healthy
    # formation out of an even engagement simply because two foes are visible.
    if sim._nearby_corps(unit["side"],p,95.0,true) >= close_foes and unit["cohesion"] >= 48.0 and unit["morale"] >= 45.0: return {}
    var home: Vector2 = sim._home_point(unit["side"])
    var desired := p.direction_to(home)
    var best := Vector2.INF
    var best_score := -INF
    for i in 16:
        var axis := Vector2.from_angle(i*TAU/16.0)
        var target: Vector2 = sim._field_point(p+axis*STEP)
        if p.distance_to(target)<STEP*0.86 or sim._river_separates(p,target) or sim._detour_goal(unit,p,target)!=target: continue
        if sim.in_open_water(p.lerp(target,0.25)) or sim.in_open_water(p.lerp(target,0.5)) or sim.in_open_water(p.lerp(target,0.75)) or sim.in_open_water(target): continue
        var gap := _clearance(p,target,threats)
        if gap < 27.0: continue
        var separation := INF
        for foe in threats: separation = minf(separation,target.distance_to(foe))
        var score := gap + 0.45*separation + 14.0*desired.dot(axis)
        score -= 45.0 * maxf(0,stalled_axis.dot(axis))
        if score > best_score:
            best_score = score
            best = target
    if best == Vector2.INF: return {}
    var command := {"action":"포위 이탈","reason":"여러 방향에서 적 관측 · 열린 쪽으로 이탈 후 임무 복귀","goal":best,"until":sim.battle_time+5.5,"last_pos":p,"checked_at":sim.battle_time}
    unit["escape_step"] = command
    return command

static func _clearance(p: Vector2, target: Vector2, threats: PackedVector2Array) -> float:
    var clearance := 160.0
    for foe in threats:
        # Bodies already touching us can be left behind. Only a body ahead
        # narrows the remaining path; ordinary movement still resolves contact.
        if (foe-p).dot(target-p) <= 0: continue
        clearance = minf(clearance,foe.distance_to(Geometry2D.get_closest_point_to_segment(foe,p,target)))
    return clearance
