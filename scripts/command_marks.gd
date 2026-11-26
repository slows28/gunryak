extends RefCounted
## Screen-sized signs shared by the order sheet and the live map.
const MARCH = Color("#ace7ff")
const GUARD = Color("#99efd0")
const PRESS = Color("#ffbd79")
const INK = Color("#1e2a2c")

static func stroke(canvas: CanvasItem, points: PackedVector2Array, color: Color, scale: float) -> void:
    canvas.draw_polyline(points,INK,4.5*scale,true)
    canvas.draw_polyline(points,color,2.1*scale,true)

static func shield(canvas: CanvasItem, center: Vector2, k: float, color: Color) -> void:
    var path:=PackedVector2Array()
    for offset in [Vector2(-7,-7),Vector2(0,-9),Vector2(7,-7),Vector2(6,1),Vector2(0,7),Vector2(-6,1)]:
        path.append(center+offset*k)
    canvas.draw_colored_polygon(path,INK)
    path.append(path[0])
    stroke(canvas,path,color,k)

static func chevron(canvas: CanvasItem, tip: Vector2, direction: Vector2, color: Color, k: float) -> void:
    var base:=tip-direction*7*k
    var wing:=direction.orthogonal()*5*k
    stroke(canvas,PackedVector2Array([base+wing,tip,base-wing]),color,k)
