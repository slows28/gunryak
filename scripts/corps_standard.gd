extends RefCounted
## Atlas rows follow the settled formation, then faction. Both factions fly the same field dye.
const ATLAS = preload("res://assets/art/corps_standards.webp")
const CELL := Vector2i(64,80)
const DYES := {
    "횡대": Color("#355f98"),
    "종대": Color("#be973d"),
    "방진": Color("#3c7e4b"),
    "어린진": Color("#bf642f"),
    "학익진": Color("#875995"),
    "봉시진": Color("#a33848"),
    "안행진": Color("#247f84")
}
const NAMES := {"왕":"王","마":"馬","위":"魏","장":"張","강":"姜","관":"關","곽":"郭","비":"費","진":"陳","등":"鄧","오":"吳","문":"文","서":"徐","학":"郝","조":"曹","요":"廖","손":"孫","대":"戴"}
const GLYPHS := "王馬魏張姜關郭費陳鄧吳文徐郝曹廖孫戴備"

static func insignia(unit: Dictionary) -> String:
    var title := str(unit["name"])
    if title.contains("예비대"): return "備"
    var first := title.left(1)
    return NAMES.get(first,first)

static func tile(unit: Dictionary) -> Rect2i:
    var column := GLYPHS.find(insignia(unit))
    if column < 0: column = GLYPHS.length() # Blank embroidered field for custom names.
    var row := DYES.keys().find(unit["formation"])
    if row < 0: row = DYES.size() # Undrilled and legacy formations have undyed linen.
    return Rect2i(Vector2i(column,2*row+int(unit["side"]))*CELL,CELL)

static func paint(canvas: CanvasItem, unit: Dictionary, foot: Vector2, zoom: float, font: Font, opacity: float, phase: float = 0.0, waving: bool = false) -> void:
    var top := foot-Vector2(0,35)*zoom
    var tint := Color(1,1,1,opacity)
    canvas.draw_line(foot,top,Color(Color("#403326"),opacity),2.6*zoom,true)
    canvas.draw_line(foot-Vector2(0.65*zoom,0),top-Vector2(0.65*zoom,0),Color(Color("#d7b776"),opacity),0.9*zoom,true)
    canvas.draw_circle(top,1.45*zoom,Color(Color("#edce8d"),opacity))
    var source := Rect2(tile(unit)).grow(-0.5)
    var origin := top+Vector2(0,2)*zoom
    var size := Vector2(22,27)*zoom
    if waving:
        var texture_size := ATLAS.get_size()
        var drop := Vector2(0,size.y)
        var previous := origin
        for strip in 4:
            var t := (strip+1)*0.25
            var edge := origin+Vector2(size.x*t,1.6*sin(phase-t*4.4)*t*zoom)
            var uv0 := (source.position+Vector2(source.size.x*(t-0.25),0))/texture_size
            var uv1 := (source.position+Vector2(source.size.x*t,source.size.y))/texture_size
            canvas.draw_polygon(PackedVector2Array([previous,edge,edge+drop,previous+drop]),PackedColorArray([tint]),PackedVector2Array([uv0,Vector2(uv1.x,uv0.y),uv1,Vector2(uv0.x,uv1.y)]),ATLAS)
            previous = edge
    else:
        canvas.draw_texture_rect_region(ATLAS,Rect2(origin,size),source,tint)
    if source.position.x >= GLYPHS.length()*CELL.x and font != null:
        var point_size := maxi(8,roundi(17*zoom))
        var first := insignia(unit)
        var baseline := origin+Vector2(0,20)*zoom
        canvas.draw_string_outline(font,baseline,first,HORIZONTAL_ALIGNMENT_CENTER,size.x,point_size,2,Color(Color("#302824"),opacity))
        canvas.draw_string(font,baseline,first,HORIZONTAL_ALIGNMENT_CENTER,size.x,point_size,tint)
