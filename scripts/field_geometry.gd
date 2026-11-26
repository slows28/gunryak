extends RefCounted
## Shared terrain geometry. A road must actually reach the existing crossing.
## Simulation, battlefield raster, and command map sample this same function.
const TRAINING_SCENARIO := 5
# Wide-field coordinates. Elliptical basins sit clear of the roads and river.
const TRAINING_MARSHES := [Rect2(650,576,338,168),Rect2(1630,1452,318,148)]

static func basin_radius(point: Vector2, basin: Rect2) -> float:
    return ((point-basin.get_center())/(basin.size*0.5)).length()

static func river_x(y:float)->float:
    return 1120.0+sin(y/225.0)*100.0+sin(y/89.0)*34.0

static func road_y(x:float,lane:int,scale:float,scenario:int)->float:
    var base:float=[131.0,282.0,435.0][lane]*scale
    if scale<=1.0: return base
    var crossing:float=[390.0,850.0,1300.0][lane]
    var anchor:float=river_x(crossing)
    var distance:float=x-anchor
    # Different approach curves, but all converge on a real bridge.
    var bend:float=sin(x/220.0+float(lane)*1.6+float(scenario)*0.52)*48.0+sin(x/94.0+float(lane))*19.0
    var approach:float=smoothstep(42.0,360.0,absf(distance))
    var broad:float=sin(distance/420.0+float(lane)*1.5)*[18.0,70.0,39.0,52.0,64.0][clampi(scenario,0,4)]
    return lerpf(crossing,base+bend+broad,approach)
