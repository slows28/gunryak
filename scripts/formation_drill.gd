extends RefCounted
## File positions are in forward/lateral coordinates, in units of file spacing.
static var patterns: Dictionary = {}

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
