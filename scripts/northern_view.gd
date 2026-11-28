extends Control
const Field=preload("res://scripts/northern_field.gd")
const Skills=preload("res://scripts/field_skills.gd")
const Art=preload("res://scripts/terrain_art.gd")
const Ink=Color("#182728")
const Gold=Color("#dbc08a")
const Paper=Color("#ede3ce")
var campaign
var font: Font
var launch: Callable
var back: Callable
var slot_choice: OptionButton
var officer_choice: OptionButton
var type_choice: OptionButton
var equip_choice: OptionButton
var owner_list: ItemList
var summary: Label
var brief: Label
var army: Label
var innate: Label
var equipped: Label
var description: Label
var status: Label
var action: Button
var equip_button: Button
var difficulty: OptionButton
var reward_bar: HBoxContainer
var route_texture: Texture2D
var canvas: Control
var slot:=0

class Route extends Control:
    var paint: Callable
    func _draw(): paint.call(self)

func configure(model,face: Font,_art: Texture2D,start: Callable,exit: Callable) -> void:
    campaign=model
    font=face
    launch=start
    back=exit

func _ready() -> void:
    size=Vector2(1280,800)
    mouse_filter=Control.MOUSE_FILTER_STOP
    block(Rect2(0,0,1280,800),Color("#131d22"))
    block(Rect2(26,96,732,570),Ink)
    block(Rect2(780,96,474,570),Color("#233134"))
    text("北伐  /  장안으로 가는 길",32,18,740,46,30,Gold)
    summary=text("",34,62,1160,26,17,Paper)
    canvas=Route.new()
    canvas.position=Vector2(42,116)
    canvas.size=Vector2(700,220)
    canvas.paint=_route
    add_child(canvas)
    brief=text("",48,355,683,75,18,Paper)
    text("보유 장비",48,438,370,28,20,Gold)
    owner_list=ItemList.new()
    place(owner_list,48,476,336,158)
    owner_list.item_selected.connect(func(i): equip_choice.select(i+1);_describe())
    description=text("",402,478,330,145,16,Paper)
    text("출전 편성",803,114,330,32,22,Gold)
    slot_choice=option(803,160,230)
    slot_choice.item_selected.connect(func(i): slot=i; refresh())
    type_choice=option(1043,160,185)
    for t in ["보병","궁병","기병"]: type_choice.add_item(t)
    type_choice.item_selected.connect(func(i):
        if campaign.preparing(): campaign.state.types[slot]=type_choice.get_item_text(i); persist(); refresh())
    army=text("",805,212,424,30,16,Paper)
    officer_choice=option(803,264,250)
    for o in campaign.officers: officer_choice.add_item("%s · %s · 판단 %d" % [o["name"],o["personality"],o["stats"][3]])
    button("장수 배치",1063,264,165,func():
        if campaign.assign(slot,officer_choice.selected): persist();refresh())
    innate=text("",805,323,420,91,15,Paper)
    equipped=text("",805,424,420,30,16,Gold)
    equip_choice=option(803,467,251)
    equip_choice.item_selected.connect(func(_i): _describe())
    equip_button=button("장비 재배치",1063,467,165,func():
        var id: String=equip_choice.get_item_metadata(equip_choice.selected)
        if campaign.equip(campaign.state.active[slot],id):
            persist(); refresh()
        else: status.text="같은 장수의 고유 스킬과 겹치는 장비입니다.")
    difficulty=option(803,575,425)
    for t in ["입문","보통","어려움"]: difficulty.add_item("전투 난이도 · "+t)
    difficulty.item_selected.connect(func(i):
        if campaign.preparing(): campaign.state.difficulty=i;persist())
    reward_bar=HBoxContainer.new()
    place(reward_bar,42,675,930,45)
    action=button("작전 지도 열기",977,685,250,func():
        if campaign.state.complete: back.call()
        elif not launch.call(campaign.state.stage): status.text=campaign.save_error)
    button("타이틀",35,740,135,back)
    button("기록 저장",180,740,145,func(): persist())
    status=text("",350,740,870,40,15,Gold)
    refresh()

func place(node: Control,x:int,y:int,w:int,h:int) -> void:
    node.position=Vector2(x,y)
    node.size=Vector2(w,h)
    add_child(node)
func block(rect: Rect2,color: Color) -> void:
    var panel:=ColorRect.new()
    panel.color=color
    panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
    place(panel,int(rect.position.x),int(rect.position.y),int(rect.size.x),int(rect.size.y))
func text(value:String,x:int,y:int,w:int,h:int,fs:int,color:Color) -> Label:
    var node:=Label.new()
    node.text=value
    node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    node.add_theme_font_size_override("font_size",fs)
    node.add_theme_color_override("font_color",color)
    place(node,x,y,w,h)
    return node
func button(title:String,x:int,y:int,w:int,handler:Callable) -> Button:
    var node:=Button.new()
    node.text=title
    node.pressed.connect(handler)
    place(node,x,y,w,40)
    return node
func option(x:int,y:int,w:int) -> OptionButton:
    var node:=OptionButton.new()
    place(node,x,y,w,40)
    return node

func persist() -> void:
    status.text="출전 기록 저장됨" if campaign.save() else campaign.save_error

func _make_route() -> void:
    var nodes: Array=[]
    for i in Field.CHAPTERS.size():
        var pos:=_route_point(i)*Vector2(820.0/700.0,570.0/220.0)
        nodes.append({"pos":[pos.x,pos.y],"links":[i+1] if i<12 else []})
    route_texture=Art.campaign_map(nodes,[])

func _route_point(i:int) -> Vector2:
    var row:=floori(float(i)/5.0)
    var col:=i%5 if row%2==0 else 4-i%5
    return Vector2(68+col*140,28+row*75)
func _route(layer:Control) -> void:
    if route_texture!=null: layer.draw_texture_rect(route_texture,Rect2(Vector2.ZERO,layer.size),false,Color("#938d7c"))
    for i in Field.CHAPTERS.size():
        var point:=_route_point(i)
        if i>0: layer.draw_line(_route_point(i-1),point,Color("#bfa874"),2,true)
    for i in Field.CHAPTERS.size():
        var point:=_route_point(i)
        var current:bool=i+1==campaign.state.stage
        var past:bool=i+1<campaign.state.stage or campaign.state.complete
        layer.draw_circle(point,8,Color("#273637"))
        layer.draw_circle(point,5,Gold if current else (Color("#6eabbd") if past else Color("#ac8170")))
        if current: layer.draw_arc(point,11,0,TAU,28,Gold,2,true)
        var title:String=Field.CHAPTERS[i][0].get_slice(" ",0)
        if i in [11,12]: title="장안 외곽" if i==11 else "장안 궁성"
        var b:=point+Vector2(-48,24)
        layer.draw_string_outline(font,b,title,HORIZONTAL_ALIGNMENT_CENTER,96,14,4,Color("#293331"))
        layer.draw_string(font,b,title,HORIZONTAL_ALIGNMENT_CENTER,96,14,Paper)
func _describe() -> void:
    var id: String=equip_choice.get_item_metadata(equip_choice.selected)
    description.text=Skills.describe(id) if id!="" else "장비를 고르면 조건과 효과를 확인할 수 있습니다."
    if id!="": owner_list.select(campaign.state["items"].find(id))
func refresh() -> void:
    if not is_instance_valid(slot_choice): return
    var s: Dictionary=campaign.state
    var idx:int=s.active[slot]
    var chapter: Array=Field.CHAPTERS[int(s.stage)-1]
    summary.text="제갈량의 북벌   /   %02d · %s      %d개 군단 출전" % [s.stage,chapter[0],s.active.size()]
    brief.text="장안 함락 · 북벌 완수" if s.complete else ("%s 승전 · 아래에서 전리품 하나를 고르십시오." % chapter[0] if s.reward else chapter[3])
    slot_choice.clear()
    for i in s.active.size(): slot_choice.add_item("%02d군  %s" % [i+1,campaign.officers[s.active[i]].name])
    slot_choice.select(slot)
    officer_choice.select(idx)
    type_choice.select(["보병","궁병","기병"].find(s.types[slot]))
    army.text="%s · %s · 판단력 %d · 출전 병력 %s명" % [campaign.officers[idx].name,campaign.officers[idx].personality,campaign.officers[idx].stats[3],campaign.TROOPS[slot]]
    var innate_lines:=Skills.describe(campaign.INNATE[idx]).split("\n")
    innate.text="고유 전술   %s\n%s\n%s" % [Skills.CATALOG[campaign.INNATE[idx]][1],innate_lines[1],innate_lines[2]]
    var gear: String=s.gear.get(str(idx),"")
    equipped.text="장착 장비   "+("없음" if gear=="" else str(Skills.CATALOG[gear][0]))
    equip_choice.clear()
    owner_list.clear()
    equip_choice.add_item("장착 해제")
    equip_choice.set_item_metadata(0,"")
    for id: String in s["items"]:
        var owner: Variant=s.gear.find_key(id)
        var title: String=Skills.CATALOG[id][0]
        owner_list.add_item(title+"  ·  "+("미장착" if owner==null else str(campaign.officers[int(owner)].name)))
        equip_choice.add_item(title)
        equip_choice.set_item_metadata(equip_choice.item_count-1,id)
    equip_choice.select(s["items"].find(gear)+1)
    _describe()
    difficulty.select(s.difficulty)
    for node in [slot_choice,type_choice,officer_choice,equip_choice,equip_button,difficulty]: node.disabled=not campaign.preparing()
    for child in reward_bar.get_children(): reward_bar.remove_child(child);child.queue_free()
    for id: String in campaign.choices():
        var b:=Button.new()
        b.text="%s · %s" % [Skills.CATALOG[id][0],Skills.CATALOG[id][1]]
        b.tooltip_text=Skills.describe(id)
        b.pressed.connect(func():
            if campaign.claim(id): status.text="전리품 수령 · 장비 재배치 가능";refresh()
            else: status.text=campaign.save_error)
        reward_bar.add_child(b)
    action.disabled=s.reward>0
    action.text="북벌 완수 · 타이틀" if s.complete else "작전 지도 열기"
    if visible and route_texture==null: _make_route()
    canvas.queue_redraw()
