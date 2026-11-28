extends Control
# Strategic map and army-management interface. All buttons modify the real campaign state.
const Campaign = preload("res://scripts/campaign.gd")
const TerrainArt = preload("res://scripts/terrain_art.gd")
const GOLD = Color("#e7c589")
const TEXT = Color("#efe6d2")
const BLUE = Color("#70bfd8")
const RED = Color("#e38b73")
var campaign
var font: Font
var atlas: Texture2D
var launch: Callable
var exit_to_title: Callable
var selected_node: int = 1
var selected_slot: int = 0
var selected_officer: int = 0
var resources: Label
var region_info: Label
var roster: ItemList
var troops: Label
var history: Label
var message: Label
var attack: Button
var slot_choice: OptionButton
var type_choice: OptionButton
var formation_choice: OptionButton
const SHAPES: Array[String] = ["횡대","종대","방진","어린진","학익진","봉시진","안행진"]
var difficulty_choice: OptionButton
var map_canvas: Control
var land_texture: ImageTexture
var land_key: String = ""
var current_region: Label

class MapCanvas extends Control:
    var painter: Callable
    func _draw() -> void:
        if painter.is_valid(): painter.call(self)

func configure(model, game_font: Font, art: Texture2D, launch_handler: Callable, exit_handler: Callable) -> void:
    campaign = model
    font = game_font
    atlas = art
    launch = launch_handler
    exit_to_title = exit_handler

func _ready() -> void:
    size = Vector2(1280,800)
    mouse_filter = Control.MOUSE_FILTER_STOP
    var background := ColorRect.new()
    background.size = size
    background.color = Color("#101b1e")
    add_child(background)
    _panel(Vector2(21,104),Vector2(826,581))
    _panel(Vector2(853,104),Vector2(407,647))
    _panel(Vector2(21,691),Vector2(826,60))
    var header := _label("軍略  /  북벌 전역",Vector2(24,13),Vector2(700,40),31)
    header.add_theme_color_override("font_color",GOLD)
    resources = _label("",Vector2(25,62),Vector2(1210,32),19)
    var canvas := MapCanvas.new()
    canvas.position = Vector2(24,111)
    canvas.size = Vector2(820,570)
    canvas.painter = _draw_map
    canvas.gui_input.connect(_map_input)
    add_child(canvas)
    map_canvas = canvas
    var region_panel := Panel.new()
    region_panel.position = Vector2(35,580)
    region_panel.size = Vector2(797,88)
    region_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    region_panel.add_theme_stylebox_override("panel",_panel_style(Color("#142427"),Color("#7c8269")))
    add_child(region_panel)
    region_info = _label("",Vector2(50,590),Vector2(770,70),16)
    region_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
    region_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    attack = _button("선택 지역 출전",Vector2(28,699),Vector2(181,44),_attack)
    attack.add_theme_stylebox_override("normal",_panel_style(Color("#796038"),GOLD))
    attack.add_theme_stylebox_override("hover",_panel_style(Color("#937849"),GOLD))
    _button("휴식 · 군량 25",Vector2(214,697),Vector2(155,44),_rest)
    _button("군량 구매 · 25",Vector2(379,697),Vector2(155,44),_resupply)
    _button("저장",Vector2(544,697),Vector2(105,44),_save)
    _button("타이틀",Vector2(659,697),Vector2(125,44),exit_to_title)
    _label("군단 편성",Vector2(869,113),Vector2(370,35),23)
    slot_choice = _choice(Vector2(869,151),Vector2(114,35),["제1군","제2군","제3군","제4군","제5군","제6군","제7군","제8군","제9군","제10군"])
    slot_choice.item_selected.connect(_choose_slot)
    type_choice = _choice(Vector2(991,151),Vector2(111,35),["보병","궁병","기병"])
    type_choice.item_selected.connect(_choose_type)
    formation_choice = _choice(Vector2(1110,151),Vector2(130,35),SHAPES)
    formation_choice.hide()
    troops = _label("",Vector2(869,190),Vector2(370,128),14)
    _button("병력 500명 보충 · 15",Vector2(869,317),Vector2(371,38),_replenish)
    _label("장수 명부 · 등용 55",Vector2(869,360),Vector2(370,28),18)
    roster = ItemList.new()
    roster.position = Vector2(869,389)
    roster.size = Vector2(371,149)
    roster.add_theme_font_size_override("font_size",14)
    roster.fixed_icon_size = Vector2i(28,28)
    roster.item_selected.connect(func(index: int): selected_officer = index)
    add_child(roster)
    _button("등용",Vector2(869,550),Vector2(180,38),_recruit)
    _button("선택 군에 배치",Vector2(1060,550),Vector2(180,38),_assign)
    difficulty_choice = _choice(Vector2(869,597),Vector2(371,34),["입문 · 전체 관전 가능","보통 · 아군 정찰","어려움 · 아군 정찰"])
    difficulty_choice.item_selected.connect(_difficulty)
    history = _label("",Vector2(869,641),Vector2(371,105),12)
    history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message = _label("",Vector2(24,753),Vector2(1215,34),15)
    message.add_theme_color_override("font_color",GOLD)
    refresh()

func _label(value: String, p: Vector2, extent: Vector2, fs: int) -> Label:
    var item := Label.new()
    item.text = value
    item.position = p
    item.size = extent
    item.add_theme_font_override("font",font)
    item.add_theme_font_size_override("font_size",fs)
    item.add_theme_color_override("font_color",TEXT)
    add_child(item)
    return item

func _button(value: String,p: Vector2,extent: Vector2,handler: Callable) -> Button:
    var btn := Button.new()
    btn.text = value
    btn.position = p
    btn.size = extent
    btn.pressed.connect(handler)
    add_child(btn)
    return btn

func _choice(p: Vector2,extent: Vector2,items: Array[String]) -> OptionButton:
    var option := OptionButton.new()
    option.position = p
    option.size = extent
    for item in items: option.add_item(item)
    add_child(option)
    return option

func refresh() -> void:
    if not is_instance_valid(resources):
        return
    var state: Dictionary = campaign.state
    resources.text = "전략 %d일차   군자금 %d   군량 %d   예비병 %d   점령 %d/6   승 %d / 패 %d" % [state["turn"],state["gold"],state["food"],state["pool"],state["owned"].size(),state["victories"],state["defeats"]]
    if state["complete"]:
        region_info.text = "북벌 데모 완주 — 천수 확보. 전략 기록을 저장하고 다른 경로에 도전하십시오."
    elif state["failed"]:
        region_info.text = "북벌 중단 — 세 차례 패배. 타이틀에서 새 캠페인을 시작할 수 있습니다."
    else:
        var node: Dictionary = Campaign.NODES[selected_node]
        region_info.text = "%s  |  적 전력 지수 %d  |  출전 군량 55\n%s" % [node["name"],state["garrison"][selected_node],node["story"]]
    attack.disabled = not campaign.available(selected_node) or int(state["food"]) < (55 if campaign.six_armies else 35)
    var lines: PackedStringArray = []
    for i in range(state["active"].size()):
        if floori(i/5.0)!=floori(selected_slot/5.0): continue
        var idx: int = int(state["active"][i])
        lines.append("%s %s · %s · %s · %d명" % ["▶" if i == selected_slot else "  ",Campaign.OFFICERS[idx]["name"],state["types"][i],state["formations"][i] if campaign.six_armies else "횡대",state["troops"][i]])
    troops.text = "\n".join(lines)
    slot_choice.select(selected_slot)
    type_choice.select(["보병","궁병","기병"].find(state["types"][selected_slot]))
    if campaign.six_armies: formation_choice.select(SHAPES.find(state["formations"][selected_slot]))
    difficulty_choice.select(int(state["difficulty"]))
    roster.clear()
    for i in range(state["roster"].size()):
        var p: Dictionary = state["roster"][i]
        var officer: Dictionary = Campaign.OFFICERS[i]
        var status: String = "전사" if p["dead"] else ("HP %d · 경험 %d" % [p["hp"],p["xp"]] if p["recruited"] else "미등용")
        var icon := AtlasTexture.new()
        icon.atlas = atlas
        # Existing portraits are used only for their actual commanders.
        if i < 3:
            icon.region = Rect2(float(i)*128,128,128,128)
            roster.add_item("%s · %s · %s" % [officer["name"],officer["specialty"],status],icon)
        else:
            roster.add_item("%s · %s · %s" % [officer["name"],officer["specialty"],status])
    roster.select(selected_officer)
    var records: PackedStringArray = []
    for i in range(maxi(0,state["history"].size()-3),state["history"].size()):
        records.append(str(state["history"][i]))
    history.text = "최근 전략 기록\n"+"\n".join(records)
    var key: String = str(state["owned"])
    if land_texture == null or key != land_key:
        land_texture = TerrainArt.campaign_map(Campaign.NODES,state["owned"])
        land_key = key
    map_canvas.queue_redraw()

func _map_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        for i in range(Campaign.NODES.size()):
            var at: Array = Campaign.NODES[i]["pos"]
            if event.position.distance_to(Vector2(at[0],at[1])) <= 57.0:
                selected_node = i
                refresh()
                return

func _draw_map(canvas: Control) -> void:
    canvas.draw_rect(Rect2(0,0,820,570),Color("#34453b"))
    if land_texture != null:
        canvas.draw_texture_rect(land_texture,Rect2(0,0,820,570),false)
    # The strategic province graphics use the exact campaign adjacency nodes.
    var state: Dictionary = campaign.state
    for i in range(Campaign.NODES.size()):
        var node: Dictionary = Campaign.NODES[i]
        var a := Vector2(node["pos"][0],node["pos"][1])
        for j in node["links"]:
            if int(j) > i:
                var dest: Dictionary = Campaign.NODES[int(j)]
                var b := Vector2(dest["pos"][0],dest["pos"][1])
                var mid: Vector2 = (a+b)*0.5+(b-a).normalized().orthogonal()*13.0
                var route := PackedVector2Array([a,mid,b])
                canvas.draw_polyline(route,Color("#313d34"),6,true)
                canvas.draw_polyline(route,Color("#c6b68b"),2.0,true)
                if (i in state["owned"]) != (int(j) in state["owned"]):
                    canvas.draw_circle(mid,4.0,GOLD)
    for i in range(Campaign.NODES.size()):
        var node: Dictionary = Campaign.NODES[i]
        var p := Vector2(node["pos"][0],node["pos"][1])
        var ours: bool = i in state["owned"]
        var c: Color = BLUE if ours else RED
        canvas.draw_circle(p+Vector2(4,5),33,Color(0.08,0.12,0.12,0.50))
        canvas.draw_circle(p,30,Color("#253832"))
        if i == selected_node:
            canvas.draw_arc(p,41,0,TAU,48,GOLD,3,true)
        elif campaign.available(i):
            canvas.draw_arc(p,38,0,TAU,48,Color(GOLD,0.75),1.5,true)
        canvas.draw_texture_rect_region(atlas,Rect2(p-Vector2(34,38),Vector2(68,68)),Rect2(6*128,5*128,128,128))
        canvas.draw_texture_rect_region(atlas,Rect2(p+Vector2(20,-33),Vector2(26,35)),Rect2((6 if ours else 7)*128,4*128,128,128))
        var label: String = str(node["name"])
        var width: float = maxf(78.0,font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x+20.0)
        var plate := Rect2(p+Vector2(-width*0.5,30),Vector2(width,26))
        canvas.draw_rect(plate,Color(0.07,0.13,0.14,0.92))
        canvas.draw_rect(Rect2(plate.position,Vector2(3,26)),c)
        canvas.draw_string(font,p+Vector2(-width*0.5+10,49),label,HORIZONTAL_ALIGNMENT_LEFT,-1,17,TEXT)
    canvas.draw_rect(Rect2(15,14,297,34),Color(0.07,0.13,0.14,0.88))
    canvas.draw_string(font,Vector2(25,36),"촉군 영토  /  위군 영토  /  공격 가능",HORIZONTAL_ALIGNMENT_LEFT,-1,14,GOLD)
    var cp := Vector2(780,45)
    canvas.draw_circle(cp,23,Color(0.07,0.13,0.14,0.60))
    canvas.draw_arc(cp,23,0,TAU,36,GOLD,1.2,true)
    canvas.draw_colored_polygon(PackedVector2Array([cp+Vector2(0,-17),cp+Vector2(-6,6),cp,cp+Vector2(6,6)]),GOLD)
    canvas.draw_string(font,cp+Vector2(-4,17),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,10,TEXT)
    canvas.draw_string(font,Vector2(24,454),"가상 북벌 전역 · 지리 및 영토 경계는 게임용 도식",HORIZONTAL_ALIGNMENT_LEFT,-1,11,TEXT)

func _tell(ok: bool, success: String) -> void:
    message.text = success if ok else "실행 불가: 자원·장수 상태·작전 조건을 확인하십시오."
    refresh()

func _choose_slot(index: int) -> void:
    selected_slot = index
    refresh()
func _choose_type(index: int) -> void:
    _tell(campaign.set_type(selected_slot,["보병","궁병","기병"][index]),"병과 편성 변경")
func _difficulty(index: int) -> void:
    campaign.state["difficulty"] = index
    refresh()
func _replenish() -> void:
    _tell(campaign.replenish(selected_slot),"병력 500명 보충")
func _recruit() -> void:
    _tell(campaign.recruit(selected_officer),"장수 등용 완료")
func _assign() -> void:
    _tell(campaign.assign(selected_slot,selected_officer),"장수 배치 완료")
func _rest() -> void:
    _tell(campaign.rest(),"하루 휴식 및 전략 일자 진행")
func _resupply() -> void:
    _tell(campaign.resupply(),"군량 45 확보")
func _save() -> void:
    _tell(campaign.save(),"캠페인 저장 완료")
func _attack() -> void:
    if not bool(launch.call(selected_node)):
        _tell(false,"")

func _panel_style(bg: Color,stroke: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = stroke
    style.set_border_width_all(1)
    style.set_corner_radius_all(4)
    return style

func _panel(p: Vector2, extent: Vector2) -> void:
    var box := Panel.new()
    box.position = p
    box.size = extent
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_theme_stylebox_override("panel",_panel_style(Color("#1b2b2d"),Color("#536662")))
    add_child(box)
