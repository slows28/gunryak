extends RefCounted
## Local footwork for the representatives at a confirmed infantry hit.
## Time is the simulation clock. Identical steps produce identical exchanges.
enum Role { PRESS, HOLD, YIELD_GROUND, FILL }
enum Pose { GATHER, THRUST, SHIELD, STUMBLE, STEP_IN, RECOVER }
const DURATION := 0.76
const REACH := 13.0

static func person(index: int, core: int) -> int:
    @warning_ignore("integer_division")
    return (index / core) * 24 + index % core

static func slot(key: int, core: int) -> int:
    @warning_ignore("integer_division")
    return (key / 24) * core + key % 24 if key % 24 < core else -1

static func begin(hit: Dictionary, attacker: Dictionary, defender: Dictionary, pressure: float) -> void:
    if hit.get("kind","") != "근접" or not hit.has("visual_from") or hit.get("damage",0.0) <= 0: return
    var feet: PackedVector2Array = attacker["end"]
    var opposing: PackedVector2Array = defender["end"]
    var partners: PackedInt32Array = attacker["partners"]
    var occupied: Dictionary = attacker["exchanges"]
    var defending: Dictionary = defender["exchanges"]
    var enemy: int = hit["defender_id"]
    var limit := clampi(2 + int(hit["contacts"]), 3, 10)
    var count := 0
    var start := posmod(hash(Vector2i(hit["attacker_id"],roundi(hit["time"]*10))),maxi(1,partners.size()))
    for k in partners.size():
        var i := (start + k) % partners.size()
        var key := person(i,attacker["core"])
        if partners[i] < enemy*4096 or partners[i] >= (enemy+1)*4096 or occupied.has(key): continue
        var other_key := partners[i] - enemy*4096
        if defending.has(other_key): continue
        var j := slot(other_key,defender["core"])
        if j < 0 or j >= opposing.size(): continue
        var gap := feet[i].distance_to(opposing[j])
        if gap < 1.0 or gap > REACH: continue
        var axis := feet[i].direction_to(opposing[j])
        if Vector2.from_angle(attacker["heading"][i]).dot(axis) < 0.25: continue
        var variation := hash(Vector3i(key,other_key,roundi(hit["time"]*10)))
        var at: float = hit["time"] + (variation % 5) * 0.012
        var yielding := pressure > 0.12 or variation % 3 == 0
        var step := minf(4.6,maxf(0.0,gap-4.6) + (1.4 if yielding else 0.0))
        occupied[key] = _action(Role.PRESS,feet[i],axis,axis*step,at,enemy)
        var sidestep := axis.orthogonal() * (1.0 if (variation & 8) == 0 else -1.0)
        var way := axis * (4.3 + 1.5*pressure) + sidestep*3.4 if yielding else axis * 0.8
        defending[other_key] = _action(Role.YIELD_GROUND if yielding else Role.HOLD,opposing[j],-axis,way,at,hit["attacker_id"])
        if yielding: _fill_gap(defender,j,axis,way,at,hit["attacker_id"])
        count += 1
        if count >= limit: break

static func _action(role: Role, root: Vector2, facing: Vector2, travel: Vector2, at: float, enemy: int) -> Dictionary:
    return {"role":role,"root":root,"facing":facing,"travel":travel,"at":at,"enemy":enemy}

static func _fill_gap(state: Dictionary, front: int, inward: Vector2, leaving: Vector2, at: float, enemy: int) -> void:
    var points: PackedVector2Array = state["end"]
    var core: int = state["core"]
    var best := -1
    var nearest := 11.0*11.0
    # Neighbouring representatives in the same file have stable identities.
    for i in range(front % core,points.size(),core):
        if state["exchanges"].has(person(i,core)): continue
        var behind := points[i]-points[front]
        if behind.dot(inward)<2.5: continue
        var distance := behind.length_squared()
        if distance < nearest:
            nearest=distance
            best=i
    if best >= 0:
        var behind := points[best]-points[front]
        if behind.distance_squared_to(leaving)<4.5*4.5:
            # Step around the oncoming relief on the other shoulder.
            var other_side := inward*2.0*leaving.dot(inward)-leaving
            if behind.distance_squared_to(other_side)<4.5*4.5: return
            state["exchanges"][person(front,core)]["travel"]=other_side
        var travel := (points[front]-points[best]).limit_length(7.5)
        state["exchanges"][person(best,core)] = _action(Role.FILL,points[best],-inward,travel,at,enemy)

static func foot(action: Dictionary, age: float, station: Vector2) -> Vector2:
    var amount := 0.0
    match action["role"]:
        Role.PRESS: amount=smoothstep(0.065,0.22,age)
        Role.HOLD, Role.YIELD_GROUND: amount=smoothstep(0.15,0.33,age)
        Role.FILL:
            amount=smoothstep(0.25,0.49,age)
    var planted: Vector2=action["root"]+Vector2(action["travel"])*amount
    return planted.lerp(station,smoothstep(0.50,DURATION,age))

static func pose(role: Role, age: float) -> Pose:
    match role:
        Role.PRESS:
            if age<0.10: return Pose.GATHER
            if age<0.32: return Pose.THRUST
        Role.HOLD, Role.YIELD_GROUND:
            if age<0.17 or (role==Role.HOLD and age<0.48): return Pose.SHIELD
            if age<0.40: return Pose.STUMBLE
        Role.FILL:
            if age<0.25: return Pose.GATHER
            if age<0.47: return Pose.STEP_IN
            return Pose.SHIELD
    return Pose.RECOVER
