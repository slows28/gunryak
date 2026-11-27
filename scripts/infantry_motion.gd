extends RefCounted

# Keep each representative in its file when losses change the number of files.
# The arrays use the same layer-major ordering as WarSim.representative_slots.
static func plant(old: Dictionary, slots: Array[Vector2], core: int, center: Vector2,
        tick: int, dt: float, in_contact: bool) -> Dictionary:
    var start := PackedVector2Array()
    var end := PackedVector2Array()
    var walked := PackedFloat32Array()
    start.resize(slots.size())
    end.resize(slots.size())
    walked.resize(slots.size())
    var continuous: bool = old.get("tick", -2) == tick - 1
    var prior: PackedVector2Array = old.get("end", PackedVector2Array())
    var distance: PackedFloat32Array = old.get("walked", PackedFloat32Array())
    var old_core: int = old.get("core", 0)
    var advance: float = center.distance_to(old.get("center", center))
    # Allow the files to keep pace with a moving corps while limiting how fast
    # they can individually cross the ground during a pivot or change of shape.
    var pace := advance + 29.0 * dt
    for i in slots.size():
        @warning_ignore("integer_division")
        var layer: int = i / core
        var file := i % core
        var from_index := layer * old_core + file
        var goal: Vector2 = slots[i]
        if not continuous or file >= old_core or from_index >= prior.size():
            start[i] = goal
            end[i] = goal
            continue
        var planted := prior[from_index]
        var gap := planted.distance_to(goal)
        var step_off: bool = (tick + layer * 7 + file * 5) % 3 == 0
        start[i] = planted
        # Small pressure changes shift weight first. Feet move when the file
        # actually yields ground, or when it is this soldier's turn to step.
        if in_contact and (gap <= 0.85 or (gap < 3.4 and not step_off)):
            end[i] = planted
        else:
            end[i] = planted.move_toward(goal, pace)
        walked[i] = distance[from_index] + planted.distance_to(end[i])
    return {"start":start, "end":end, "walked":walked, "core":core, "center":center, "tick":tick}

# A short exchange begins on an actual visual hit event. Some nearby soldiers
# brace through that exchange. The next event picks a fresh group.
static func swing_age(unit_id: int, person: int, now: float, event_time: float) -> float:
    var age := now - event_time
    if age < 0.0 or age > 0.54: return -1.0
    var choice := hash(Vector3i(unit_id, person, roundi(event_time * 10.0)))
    if choice % 5 < 2: return -1.0
    return age - float((choice >> 5) % 13) * 0.011

static func contact_pose(age: float) -> int:
    if age < 0.08 or age >= 0.38: return 2
    if age < 0.20: return 3
    return 4

# Aim at one of the actual representatives of the contacted file. Match along
# the line so adjacent soldiers do not all turn towards a single anchor.
static func opponent_for(point: Vector2, heading: Vector2, positions: PackedVector2Array, file: int, core: int, prior: int) -> int:
    var best := INF
    var target := -1
    var tangent := heading.orthogonal()
    for i in range(file, positions.size(), core):
        var offset := positions[i] - point
        var across := offset.dot(tangent)
        var cost := offset.length_squared() + 2.0 * across * across
        @warning_ignore("integer_division")
        if prior == (i / core) * 24 + file: cost -= 9.0
        if cost < best:
            best = cost
            target = i
    return target

# Once formations mingle the closest opponent can belong to a different
# file. Index only participants of actual infantry contacts on the fixed step.
const NEIGHBOUR_RANGE := 12.0
static func bins_for(feet: PackedVector2Array) -> Dictionary:
    var bins := {}
    for i in feet.size():
        var cell := Vector2i((feet[i] / NEIGHBOUR_RANGE).floor())
        if not bins.has(cell): bins[cell] = []
        bins[cell].append(i)
    return bins

static func nearby_opponent(point: Vector2, feet: PackedVector2Array, bins: Dictionary, prior_index: int) -> int:
    var cell := Vector2i((point/NEIGHBOUR_RANGE).floor())
    var best := NEIGHBOUR_RANGE*NEIGHBOUR_RANGE
    var match_index := -1
    for y in range(-1,2):
        for x in range(-1,2):
            var bucket: Array = bins.get(cell+Vector2i(x,y),[])
            for j: int in bucket:
                var gap := point.distance_squared_to(feet[j])
                if gap > NEIGHBOUR_RANGE*NEIGHBOUR_RANGE: continue
                if j == prior_index: gap -= 6.0
                if gap < best:
                    best = gap
                    match_index = j
    return match_index

# Share the remaining gap when two planted feet step towards each other.
# Preserve lateral travel and steps away from the opposing person.
static func stop_at_contact(start: Vector2, goal: Vector2, other_start: Vector2, other_goal: Vector2) -> Vector2:
    var gap := start.distance_to(other_start)
    if gap < 0.01 or gap > 15.0: return goal
    var normal := (other_start - start) / gap
    var closing := (goal - start).dot(normal)
    if closing <= 0.0: return goal
    var opposing := (other_start - other_goal).dot(normal)
    var available := maxf(0.0, gap - 4.5 + maxf(0.0, -opposing))
    var share := clampf(available / (closing + maxf(0.0, opposing)), 0.0, 1.0)
    return goal - normal * closing * (1.0 - share)

# Resolve simultaneous short-range crowding from frozen positions. Opposite
# files may mingle, but no representative has to occupy another's footprint.
static func spread_neighbours(points: PackedVector2Array, identities: PackedInt32Array) -> void:
    const SPACE := 4.1
    for pass_index in 3:
        var cells := {}
        var shifts := PackedVector2Array()
        shifts.resize(points.size())
        for i in points.size():
            var cell := Vector2i((points[i]/SPACE).floor())
            for y in range(-1,2):
                for x in range(-1,2):
                    var bucket: Array = cells.get(cell+Vector2i(x,y),[])
                    for j: int in bucket:
                        var gap := points[i]-points[j]
                        var length_sq := gap.length_squared()
                        if length_sq >= SPACE*SPACE: continue
                        var dist := sqrt(length_sq)
                        var normal := gap / dist if dist > 0.001 else Vector2.from_angle(float(identities[i]+identities[j])*2.39996)
                        if dist <= 0.001 and identities[i] < identities[j]: normal = -normal
                        var correction := normal * ((SPACE-dist)*0.5)
                        shifts[i] += correction
                        shifts[j] -= correction
            if not cells.has(cell): cells[cell] = []
            cells[cell].append(i)
        for i in points.size():
            points[i] += shifts[i].limit_length(SPACE*0.55)
