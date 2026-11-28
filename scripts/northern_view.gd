extends Control
const Field=preload("res://scripts/northern_field.gd")
const Skills=preload("res://scripts/field_skills.gd")
const Atlas=preload("res://scripts/northern_atlas.gd")
const Ink=Color("#182728")
const Gold=Color("#dbc08a")
const Paper=Color("#ede3ce")
var campaign
var font: Font
var launch: Callable
var back: Callable
var corps_buttons: Array[Button]=[]
var commander_heading: Label
var assign_button: Button
var officer_choice: OptionButton
var type_choice: OptionButton
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
var canvas: Atlas
var slot:=0
var portraits: Array[TextureRect]=[]
var commander_portrait: TextureRect
var card_skills: Array[Label]=[]
var trait_names: Array[Label]=[]
var trait_tracks: Array[ColorRect]=[]
var trait_pins: Array[ColorRect]=[]
var strength: Label
const TYPE_COLORS := {"보병":Color("#a6bb9d"),"궁병":Color("#b6c6ce"),"기병":Color("#d6b58a")}

func configure(model,face: Font,_art: Texture2D,start: Callable,exit: Callable) -> void:
    campaign=model
    font=face
    launch=start
    back=exit

func _ready() -> void:
    size=Vector2(1280,800)
    mouse_filter=Control.MOUSE_FILTER_STOP
    block(Rect2(0,0,1280,800),Color("#152021"))
    block(Rect2(30,105,724,310),Ink)
    block(Rect2(30,420,724,230),Ink)
    block(Rect2(776,110,474,540),Color("#223132"))
    text("북벌 전역",39,19,325,26,16,Gold)
    summary=text("",36,46,900,50,31,Paper)
    difficulty=option(969,44,273)
    for t in ["입문 · 전체 관전 가능","보통 · 아군 정찰","어려움 · 아군 정찰"]: difficulty.add_item("난이도   "+t)
    difficulty.item_selected.connect(func(i):
        if campaign.preparing(): campaign.state.difficulty=i;persist())
    canvas=Atlas.new()
    canvas.position=Vector2(42,110)
    canvas.size=Atlas.MAP_SIZE
    canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(canvas)
    brief=text("",48,371,683,43,16,Paper)
    block(Rect2(30,420,724,2),Color("#897955"))
    text("출진 군단",48,426,160,34,22,Gold)
    strength=text("",210,428,510,30,15,Paper)
    strength.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    var group:=ButtonGroup.new()
    for i in campaign.state.active.size():
        var card:=button("",46+(i%4)*174,466+floori(float(i)/4)*59,167,_select_corps.bind(i))
        card.size.y=54
        card.toggle_mode=true
        card.button_group=group
        card.alignment=HORIZONTAL_ALIGNMENT_LEFT
        card.add_theme_font_size_override("font_size",16)
        for mode in ["normal","hover","pressed","hover_pressed"]:
            var box:=StyleBoxFlat.new()
            box.bg_color={"normal":Color("#243534"),"hover":Color("#344541"),"pressed":Color("#484739"),"hover_pressed":Color("#534e3e")}[mode]
            box.border_color=Gold if mode.ends_with("pressed") else Color("#495a50")
            box.set_border_width_all(1)
            box.border_width_left=3
            box.content_margin_left=53
            box.content_margin_top=1
            box.content_margin_bottom=20
            card.add_theme_stylebox_override(mode,box)
        var portrait:=TextureRect.new()
        portrait.position=Vector2(6,5)
        portrait.size=Vector2(40,44)
        portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
        portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
        portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
        card.add_child(portrait)
        portraits.append(portrait)
        card_skills.append(_card_label(card,Vector2(53,28),Vector2(109,20),13,Gold))
        corps_buttons.append(card)
    block(Rect2(799,116,58,51),Color("#897955"))
    commander_portrait=TextureRect.new()
    commander_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    commander_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
    place(commander_portrait,800,117,56,49)
    commander_heading=text("",870,116,205,41,26,Paper)
    type_choice=option(1078,123,144)
    for t in ["보병","궁병","기병"]: type_choice.add_item(t)
    type_choice.item_selected.connect(func(i):
        if campaign.preparing(): campaign.state.types[slot]=type_choice.get_item_text(i); persist(); refresh())
    army=text("",802,166,426,28,16,Paper)
    for i in Skills.Profiles.AXES.size():
        var x:=803+106*i
        var label:=text("",x,193,94,23,14,Gold)
        label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        trait_names.append(label)
        var track:=ColorRect.new()
        track.color=Color("#60726b")
        place(track,x+5,221,84,3)
        track.mouse_filter=Control.MOUSE_FILTER_IGNORE
        trait_tracks.append(track)
        var pin:=ColorRect.new()
        pin.color=Gold
        place(pin,x+5,218,4,9)
        pin.mouse_filter=Control.MOUSE_FILTER_IGNORE
        trait_pins.append(pin)
    officer_choice=option(800,242,261)
    for o in campaign.officers: officer_choice.add_item("%s · %s · 판단 %d" % [o["name"],o["personality"],o["stats"][3]])
    officer_choice.item_selected.connect(func(i): assign_button.disabled=not campaign.preparing() or i==campaign.state.active[slot])
    assign_button=button("장수 교체",1073,242,149,func():
        if campaign.assign(slot,officer_choice.selected): persist();refresh())
    block(Rect2(800,294,422,1),Color("#45514c"))
    innate=text("",802,298,420,99,15,Paper)
    innate.add_theme_constant_override("line_spacing",0)
    innate.add_theme_constant_override("paragraph_spacing",0)
    equipped=text("",802,402,420,29,18,Gold)
    owner_list=ItemList.new()
    owner_list.add_theme_font_size_override("font_size",15)
    place(owner_list,800,438,226,124)
    owner_list.item_selected.connect(func(_i): _describe())
    description=text("",1041,434,186,140,15,Paper)
    equip_button=button("",800,581,422,_change_gear)
    reward_bar=HBoxContainer.new()
    place(reward_bar,40,661,1170,45)
    button("메인 메뉴",39,731,142,back)
    button("기록 저장",194,731,142,func(): persist())
    status=text("",356,728,569,45,15,Gold)
    action=button("작전 지도 열기",973,720,267,func():
        if campaign.state.complete: back.call()
        elif not launch.call(campaign.state.stage): status.text=campaign.save_error)
    action.size.y=59
    get_parent()._primary_button(action)
    refresh()

func _card_label(card: Button,at: Vector2,extent: Vector2,px: int,ink: Color) -> Label:
    var label:=Label.new()
    label.position=at
    label.size=extent
    label.add_theme_font_size_override("font_size",px)
    label.add_theme_color_override("font_color",ink)
    label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    card.add_child(label)
    return label

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

func _select_corps(index: int) -> void:
    slot=index
    refresh()

func _describe() -> void:
    var rows:=owner_list.get_selected_items()
    equip_button.disabled=true
    if rows.is_empty():
        description.text="장비를 선택하세요."
        equip_button.text="장비 선택"
        return
    var id: String=owner_list.get_item_metadata(rows[0])
    description.text=Skills.describe(id)
    var idx: int=campaign.state.active[slot]
    var name_text: String=campaign.officers[idx].name
    var owner: Variant=campaign.state.gear.find_key(id)
    if owner==str(idx): equip_button.text="%s · 장착 해제" % name_text
    elif owner!=null: equip_button.text="%s → %s · 장비 이전" % [campaign.officers[int(owner)].name,name_text]
    else: equip_button.text="%s에게 장착" % name_text
    equip_button.disabled=not campaign.preparing()

func _change_gear() -> void:
    var rows:=owner_list.get_selected_items()
    if rows.is_empty(): return
    var idx: int=campaign.state.active[slot]
    var id: String=owner_list.get_item_metadata(rows[0])
    if campaign.state.gear.get(str(idx),"")==id: id=""
    if campaign.equip(idx,id):
        persist()
        refresh()

func refresh() -> void:
    if corps_buttons.is_empty(): return
    var s: Dictionary=campaign.state
    var idx:int=s.active[slot]
    var chapter: Array=Field.CHAPTERS[int(s.stage)-1]
    summary.text="%02d장   %s" % [s.stage,chapter[0]]
    brief.text="장안 함락 · 북벌 완수" if s.complete else ("%s 승전 · 아래에서 전리품 하나를 고르세요." % chapter[0] if s.reward else chapter[3])
    strength.text="%d개 군단   ·   총 병력 %s명" % [s.active.size(),get_parent()._number_text(campaign.TROOPS.reduce(func(a,b): return a+b,0))]
    for i in s.active.size():
        var name_text: String=campaign.officers[s.active[i]].name
        var card:=corps_buttons[i]
        card.text="%s · %s" % [name_text,s.types[i]]
        portraits[i].texture=get_parent()._commander_icon(name_text,0)
        card_skills[i].text=Skills.title(name_text)
        card_skills[i].add_theme_color_override("font_color",TYPE_COLORS[s.types[i]])
        corps_buttons[i].tooltip_text="%d군  %s  ·  병력 %d명" % [i+1,name_text,campaign.TROOPS[i]]
        corps_buttons[i].set_pressed_no_signal(i==slot)
    commander_portrait.texture=portraits[slot].texture
    commander_heading.text="%s  ·  제%d군" % [campaign.officers[idx].name,slot+1]
    officer_choice.select(idx)
    type_choice.select(["보병","궁병","기병"].find(s.types[slot]))
    var officer: Dictionary=campaign.officers[idx]
    var stats: Array=officer.stats
    army.text="통솔 %d    무력 %d    지력 %d    판단 %d    충성 %d" % stats
    var axes: Array=Skills.Profiles.DATA[officer.name][0]
    for i in axes.size():
        var poles: Array=Skills.Profiles.AXES[i]
        trait_names[i].text="%s · %s" % poles
        trait_names[i].tooltip_text="%s %d / %s %d" % [poles[0],100-axes[i],poles[1],axes[i]]
        trait_names[i].mouse_filter=Control.MOUSE_FILTER_PASS
        trait_pins[i].position.x=trait_tracks[i].position.x+(trait_tracks[i].size.x-4)*axes[i]/100.0
    innate.text="고유기   %s\n%s\n전반 80%% · 후반 65%%   |   각 1회 판정 · 재사용 16초" % [Skills.title(officer.name),Skills.describe_signature(officer.name)]
    var gear: String=s.gear.get(str(idx),"")
    equipped.text="장착 장비   "+("없음" if gear=="" else str(Skills.CATALOG[gear][0]))
    owner_list.clear()
    for id: String in s["items"]:
        var owner: Variant=s.gear.find_key(id)
        var title: String=Skills.CATALOG[id][0]
        owner_list.add_item(title+"  ·  "+("미장착" if owner==null else str(campaign.officers[int(owner)].name)))
        owner_list.set_item_metadata(owner_list.item_count-1,id)
    if owner_list.item_count>0: owner_list.select(maxi(0,s["items"].find(gear)))
    _describe()
    difficulty.select(s.difficulty)
    for node in [type_choice,officer_choice,difficulty]: node.disabled=not campaign.preparing()
    assign_button.disabled=true
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
    canvas.set_progress(s.stage,s.complete)
