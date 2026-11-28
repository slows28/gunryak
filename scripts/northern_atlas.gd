extends Control
## Relief and waterways use these WGS84 bounds (west, south, east, north).
## Historical battlefields are represented by their surrounding localities.
const BOUNDS := Vector4(103.0, 32.98, 110.0, 35.14)
const MAP_SIZE := Vector2(700, 260)
const RELIEF := preload("res://assets/art/northern_theater.webp")
const HANZHONG := Vector2(107.03, 33.07)

# Short map name, geographic anchor (longitude, latitude), printed label center.
const SITES := [
    ["기산", Vector2(105.32, 34.23), Vector2(201, 132)],
    ["천수", Vector2(105.33, 34.74), Vector2(202, 46)],
    ["기곡", Vector2(106.95, 33.34), Vector2(363, 205)],
    ["가정", Vector2(106.05, 35.00), Vector2(342, 23)],
    ["상규", Vector2(105.70, 34.56), Vector2(292, 91)],
    ["농서", Vector2(104.63, 35.00), Vector2(147, 40)],
    ["진창", Vector2(107.38, 34.36), Vector2(396, 79)],
    ["미현", Vector2(107.75, 34.27), Vector2(460, 57)],
    ["오장원", Vector2(107.61, 34.24), Vector2(433, 146)],
    ["위수", Vector2(108.02, 34.234), Vector2(514, 150)],
    ["무공", Vector2(108.12, 34.37), Vector2(523, 45)],
    ["장안 외곽", Vector2(108.65, 34.30), Vector2(589, 65)],
    ["장안", Vector2(108.86, 34.30), Vector2(635, 116)],
]
const INK := Color("#373b32")
const PAPER := Color("#f2e3c3")
const VERMILION := Color("#973c2a")
const CONQUERED := Color("#2d6663")

var stage := 1
var complete := false

func set_progress(chapter: int, finished: bool) -> void:
    stage=chapter
    complete=finished
    queue_redraw()

static func project_point(lon_lat: Vector2) -> Vector2:
    return Vector2(inverse_lerp(BOUNDS.x,BOUNDS.z,lon_lat.x),inverse_lerp(BOUNDS.w,BOUNDS.y,lon_lat.y))*MAP_SIZE

func _draw() -> void:
    var face:=get_theme_default_font()
    draw_texture_rect(RELIEF,Rect2(Vector2.ZERO,MAP_SIZE),false)
    _map_text(face,"농우 · 관중",Vector2(16,23),17,INK)
    _map_text(face,"100 km",Vector2(17,58),11,INK)
    draw_line(Vector2(677,35),Vector2(677,13),INK,1.3,true)
    draw_colored_polygon(PackedVector2Array([Vector2(677,8),Vector2(673,19),Vector2(677,17),Vector2(681,19)]),INK)
    _map_text(face,"북",Vector2(671,48),12,INK)
    var origin:=project_point(HANZHONG)
    var previous:=origin
    for i in SITES.size():
        var point:=project_point(SITES[i][1])
        if complete or i+1<stage:
            draw_line(previous,point,Color(CONQUERED,0.73),1.7,true)
        elif i+1==stage:
            draw_dashed_line(previous,point,VERMILION,2.0,5.0,true,true)
        else:
            draw_dashed_line(previous,point,Color(INK,0.56),1.1,3.8,true,true)
        previous=point
    draw_rect(Rect2(origin-Vector2(3.5,3.5),Vector2(7,7)),CONQUERED)
    _map_text(face,"한중",origin+Vector2(8,4),14,INK)
    _map_text(face,"진 령 산 맥",Vector2(306,163),15,Color("#5a614b"))
    _map_text(face,"위수",Vector2(646,91),13,Color("#345f66"))
    _map_text(face,"한수",Vector2(460,241),13,Color("#345f66"))
    _map_text(face,"중국 내 위치",Vector2(21,236),12,PAPER,Color("#334641"))
    draw_dashed_line(Vector2(545,241),Vector2(568,241),INK,1.3,4,true,true)
    _map_text(face,"전장 진행 순서",Vector2(574,245),12,INK)
    for i in SITES.size():
        _draw_site(i,face)

func _map_text(face: Font, caption: String, baseline: Vector2, px: int, color: Color, halo:=PAPER) -> void:
    draw_string_outline(face,baseline,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,px,3,halo)
    draw_string(face,baseline,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,px,color)

func _draw_site(i: int, face: Font) -> void:
    var site: Array=SITES[i]
    var point:=project_point(site[1])
    var center: Vector2=site[2]
    var current:=i+1==stage and not complete
    var held:=i+1<stage or complete
    var ink:=VERMILION if current else (CONQUERED if held else INK)
    var caption:="%02d %s" % [i+1,site[0]]
    var px:=15 if current else 14
    var plate:=_label_rect(center,caption,px,face)
    draw_line(point,point.clamp(plate.position,plate.end),ink,1.1,true)
    if current: draw_arc(point,8,0,TAU,32,VERMILION,1.6,true)
    draw_circle(point,4.5,ink,true,-1,true)
    if not current and not held: draw_circle(point,2.6,PAPER,true,-1,true)
    var baseline:=Vector2(plate.position.x,center.y+face.get_ascent(px)-face.get_height(px)/2)
    if current:
        draw_rect(plate,VERMILION)
    else:
        draw_string_outline(face,baseline,caption,HORIZONTAL_ALIGNMENT_CENTER,plate.size.x,px,4,PAPER)
    draw_string(face,baseline,caption,HORIZONTAL_ALIGNMENT_CENTER,plate.size.x,px,PAPER if current else ink)

func _label_rect(center: Vector2, caption: String, px: int, face: Font) -> Rect2:
    var extent:=Vector2(ceilf(face.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x)+8,20)
    return Rect2(center-extent/2,extent)
