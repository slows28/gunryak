extends Control
# Strategic map and army-management interface. All buttons modify the real campaign state.
const Campaign = preload("res://scripts/campaign.gd")
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
var difficulty_choice: OptionButton
var map_canvas: Control

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
    background.color = Color("#1a1e1b")
    add_child(background)
    var header := _label("軍略  /  북벌 전략 지도",Vector2(24,18),Vector2(700,40),28)
    header.add_theme_color_override("font_color",GOLD)
    resources = _label("",Vector2(25,67),Vector2(1210,32),18)
    var canvas := MapCanvas.new()
    canvas.position = Vector2(24,111)
    canvas.size = Vector2(820,570)
    canvas.painter = _draw_map
    canvas.gui_input.connect(_map_input)
    add_child(canvas)
    map_canvas = canvas
    region_info = _label("",Vector2(34,590),Vector2(800,82),15)
    region_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
    region_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    attack = _button("출전 준비",Vector2(24,697),Vector2(180,44),_attack)
    _button("휴식 · 군량 25",Vector2(214,697),Vector2(155,44),_rest)
    _button("군량 구매 · 25",Vector2(379,697),Vector2(155,44),_resupply)
    _button("저장",Vector2(544,697),Vector2(105,44),_save)
    _button("타이틀",Vector2(659,697),Vector2(125,44),exit_to_title)
    _label("군단 편성",Vector2(869,113),Vector2(370,35),23)
    slot_choice = _choice(Vector2(869,151),Vector2(180,35),["제1군","제2군","제3군"])
    slot_choice.item_selected.connect(_choose_slot)
    type_choice = _choice(Vector2(1060,151),Vector2(180,35),["보병","궁병","기병"])
    type_choice.item_selected.connect(_choose_type)
    troops = _label("",Vector2(869,195),Vector2(370,82),15)
    _button("병력 20명 보충 · 15",Vector2(869,272),Vector2(371,38),_replenish)
    _label("장수 명부 · 등용 55",Vector2(869,326),Vector2(370,28),18)
    roster = ItemList.new()
    roster.position = Vector2(869,361)
    roster.size = Vector2(371,181)
    roster.add_theme_font_size_override("font_size",14)
    roster.fixed_icon_size = Vector2i(25,25)
    roster.item_selected.connect(func(index: int): selected_officer = index)
    add_child(roster)
    _button("등용",Vector2(869,550),Vector2(180,38),_recruit)
    _button("선택 군에 배치",Vector2(1060,550),Vector2(180,38),_assign)
    difficulty_choice = _choice(Vector2(869,597),Vector2(371,34),["난이도 · 입문","난이도 · 보통","난이도 · 어려움"])
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
    resources.text = "전략 %d턴   군자금 %d   군량 %d   예비병 %d   점령 %d/6   승 %d / 패 %d" % [state["turn"],state["gold"],state["food"],state["pool"],state["owned"].size(),state["victories"],state["defeats"]]
    if state["complete"]:
        region_info.text = "북벌 데모 완주 — 천수 확보. 전략 기록을 저장하고 다른 경로에 도전하십시오."
    elif state["failed"]:
        region_info.text = "북벌 중단 — 세 차례 패배. 타이틀에서 새 캠페인을 시작할 수 있습니다."
    else:
        var node: Dictionary = Campaign.NODES[selected_node]
        region_info.text = "%s  |  적 전력 지수 %d  |  출전 군량 35\n%s" % [node["name"],state["garrison"][selected_node],node["story"]]
    attack.disabled = not campaign.available(selected_node) or int(state["food"]) < 35
    var lines: PackedStringArray = []
    for i in range(3):
        var idx: int = int(state["active"][i])
        lines.append("%s %s · %s · %d명" % ["▶" if i == selected_slot else "  ",Campaign.OFFICERS[idx]["name"],state["types"][i],state["troops"][i]])
    troops.text = "\n".join(lines)
    slot_choice.select(selected_slot)
    type_choice.select(["보병","궁병","기병"].find(state["types"][selected_slot]))
    difficulty_choice.select(int(state["difficulty"]))
    roster.clear()
    for i in range(Campaign.OFFICERS.size()):
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
    for i in range(18):
        var points := PackedVector2Array()
        for x in range(0,821,20):
            points.append(Vector2(x,20+i*29+sin(float(x)*0.012+i*0.7)*16.0))
        canvas.draw_polyline(points,Color(0.57,0.63,0.44,0.13),1.0,true)
    var state: Dictionary = campaign.state
    for i in range(Campaign.NODES.size()):
        var node: Dictionary = Campaign.NODES[i]
        var a := Vector2(node["pos"][0],node["pos"][1])
        for j in node["links"]:
            if int(j) > i:
                var dest: Dictionary = Campaign.NODES[int(j)]
                var b := Vector2(dest["pos"][0],dest["pos"][1])
                canvas.draw_line(a,b,Color("#b6a176"),4.0,true)
    for i in range(Campaign.NODES.size()):
        var node: Dictionary = Campaign.NODES[i]
        var p := Vector2(node["pos"][0],node["pos"][1])
        var c: Color = BLUE if i in state["owned"] else RED
        canvas.draw_circle(p,38,Color("#202c28"))
        canvas.draw_arc(p,38,0,TAU,48,GOLD if i == selected_node else c,3,true)
        canvas.draw_texture_rect_region(atlas,Rect2(p-Vector2(25,28),Vector2(50,50)),Rect2(5*128,5*128,128,128))
        if campaign.available(i):
            canvas.draw_arc(p,48,0,TAU,48,GOLD,1.5,true)
        canvas.draw_string(font,p+Vector2(-42,60),str(node["name"]),HORIZONTAL_ALIGNMENT_LEFT,-1,17,TEXT)
    canvas.draw_string(font,Vector2(24,32),"청색: 점령  /  적색: 적군  /  금색 원: 공격 가능",HORIZONTAL_ALIGNMENT_LEFT,-1,15,GOLD)

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
    _tell(campaign.replenish(selected_slot),"병력 20명 보충")
func _recruit() -> void:
    _tell(campaign.recruit(selected_officer),"장수 등용 완료")
func _assign() -> void:
    _tell(campaign.assign(selected_slot,selected_officer),"장수 배치 완료")
func _rest() -> void:
    _tell(campaign.rest(),"휴식 및 전략 턴 진행")
func _resupply() -> void:
    _tell(campaign.resupply(),"군량 45 확보")
func _save() -> void:
    _tell(campaign.save(),"캠페인 저장 완료")
func _attack() -> void:
    if not bool(launch.call(selected_node)):
        _tell(false,"")
