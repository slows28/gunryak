extends RefCounted
## One weathered cloth dye per faction. The commander owns the embroidered character.
const ATLAS = preload("res://assets/art/corps_standards.webp")
const CELL := Vector2i(64,80)
const FACTION_DYES := [Color("#3d5967"), Color("#854c40")]
const NAMES := {"왕":"王","마":"馬","위":"魏","장":"張","강":"姜","관":"關","곽":"郭","비":"費","진":"陳","등":"鄧","오":"吳","문":"文","서":"徐","학":"郝","요":"廖","손":"孫","대":"戴","조":"趙","황":"黃","유":"劉","향":"向","나":"羅","양":"楊","부":"傅","동":"董","윤":"尹","이":"李","고":"高"}
const GLYPHS := "王馬魏張姜關郭費陳鄧吳文徐郝曹廖孫戴趙黃劉向羅楊傅董尹李高備"

static func insignia(unit: Dictionary) -> String:
    var title := str(unit["name"])
    if title.contains("예비대"): return "備"
    if title.begins_with("조진") or title.begins_with("조휴"): return "曹"
    var first := title.left(1)
    return NAMES.get(first,first)

static func tile(unit: Dictionary) -> Rect2i:
    var column := GLYPHS.find(insignia(unit))
    if column < 0: column = GLYPHS.length() # Blank embroidered field for custom names.
    return Rect2i(Vector2i(column,int(unit["side"]))*CELL,CELL)

static func paint(canvas: CanvasItem, unit: Dictionary, foot: Vector2, zoom: float, font: Font, opacity: float, phase: float = 0.0, waving: bool = false) -> void:
    var top := foot-Vector2(0,35)*zoom
    var tint := Color(1,1,1,opacity)
    canvas.draw_line(foot,top,Color(Color("#403326"),opacity),1.65*zoom,true)
    canvas.draw_line(foot-Vector2(0.65*zoom,0),top-Vector2(0.65*zoom,0),Color(Color("#d7b776"),opacity),0.65*zoom,true)
    canvas.draw_circle(top,1.05*zoom,Color(Color("#edce8d"),opacity))
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
