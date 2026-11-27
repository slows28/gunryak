extends RefCounted
## File positions are in forward/lateral coordinates, in units of file spacing.
static var patterns: Dictionary = {}

# Relative contribution of the occupied formation to the existing push contest.
static func frontage_factor(shape: String) -> float:
    match shape:
        "횡대": return 1.06
        "종대": return 0.77
        "방진": return 1.28
        "어린진": return 1.19
        "학익진": return 1.10
        "봉시진": return 1.18
        "안행진": return 0.85
    return 1.0

# How firmly the unengaged ranks retain the ordered pattern at this contact.
static func rank_hold(unit: Dictionary, normal: Vector2, pressure: float) -> float:
    if unit["routed"]: return 0.0
    var shape: String = unit["formation"]
    var structure := lerpf(0.40,1.0,inverse_lerp(0.77,1.28,frontage_factor(shape)))
    var facing := clampf(Vector2(unit["facing"]).dot(normal),0.0,1.0)
    if shape != "방진": structure *= lerpf(0.68,1.0,facing)
    var cohesion := smoothstep(36.0,90.0,float(unit["cohesion"]))
    var ordered := 1.0 if str(unit["next_formation"]).is_empty() else 0.55
    return structure * lerpf(0.22,1.0,cohesion) * lerpf(1.0,0.68,clampf(pressure,0.0,1.0)) * ordered

static func role_text(shape: String) -> String:
    match shape:
        "방진": return "충격에 강함 · 느린 이동"
        "횡대": return "넓은 전열 · 동시 교전"
        "종대": return "빠른 이동 · 좁은 전열"
        "어린진": return "근접 공격 강화"
        "학익진": return "측후방 공격 강화"
        "봉시진": return "기병 공격 강화 · 빠른 이동"
        "안행진": return "궁병 사격 강화"
    return ""

static func pattern(shape: String, count: int) -> Array[Vector2]:
    if not patterns.has(shape): patterns[shape] = {}
    if patterns[shape].has(count): return patterns[shape][count]
    var local: Array[Vector2]=[]
    var width: int=mini(count,8)
    if shape=="종대": width=mini(count,4)
    elif shape=="방진": width=ceili(sqrt(float(count)))
    elif shape in ["어린진","봉시진"]: width=7
    elif shape=="학익진": width=mini(count,10)
    elif shape=="안행진": width=mini(count,9)
    var row: int=0
    while local.size()<count:
        var row_width: int=width
        if shape=="어린진": row_width=mini(7,3+row*2)
        elif shape=="봉시진": row_width=mini(7,1+row*2)
        row_width=mini(row_width,count-local.size())
        for i in range(row_width):
            var lateral: float=float(i)-float(row_width-1)*0.5
            var depth: float=-float(row)
            if shape=="학익진": depth+=absf(lateral)*0.65
            elif shape=="안행진": depth+=lateral*0.45
            local.append(Vector2(depth,lateral))
        row+=1
    var center:=Vector2.ZERO
    for p in local: center+=p
    center/=float(local.size())
    for i in range(local.size()): local[i] -= center
    patterns[shape][count] = local
    return local

# Keep file identities. Exchanging two destinations that shorten total squared
# travel removes long crossovers without changing the commander's chosen shape.
static func match_files(origins: Array[Vector2], destinations: Array[Vector2]) -> Array[Vector2]:
    var matched: Array[Vector2] = destinations.duplicate()
    var changed := true
    while changed:
        changed = false
        for i in range(matched.size()):
            for j in range(i):
                var delta := (origins[i] - origins[j]).dot(matched[i] - matched[j])
                if delta >= -0.0001: continue
                var other := matched[j]
                matched[j] = matched[i]
                matched[i] = other
                changed = true
    return matched

static func sample(origins: Array[Vector2], targets: Array[Vector2], progress: float) -> Array[Vector2]:
    var result: Array[Vector2] = []
    for i in range(origins.size()):
        # Adjacent files step off in sequence. Each rank arrives before the
        # order completes, including outer files with further to travel.
        var delay := 0.035 * float(i % 4)
        var t := smoothstep(delay, 1.0 - (0.105 - delay), progress)
        result.append(origins[i].lerp(targets[i], t))
    return result
