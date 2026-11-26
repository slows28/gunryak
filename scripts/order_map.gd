extends Control
## Separate paper war-room: actual battle coordinates, independent rendering and input.
const CommandMarks = preload("res://scripts/command_marks.gd")
const ACTIONS: Array[String]=["지정 위치 이동","공격","지역 사수","전열 엄호","측후방 기동","구원 지원","예비 대기","철수"]
const PAPER=Color("#d6c29a")
const INK=Color("#554735")
const GOLD=Color("#d5b473")
const BLUE=Color("#315b79")
const RED=Color("#934e3e")
const MAP=Rect2(344,76,713,628)
const DESK=Color("#131a22")
const SHEET=Color("#ede4d0")
const RAIL=Color("#1c2732")
const SHEET_TEXT=Color("#282720")
const SHEET_MUTED=Color("#66543d")
const ART=preload("res://assets/art/fieldcraft.svg")
const Materials=preload("res://scripts/command_materials.gd")
const FieldGeometry=preload("res://scripts/field_geometry.gd")
const INK_RELIEF=preload("res://assets/art/ink_relief.webp")
var lacquer := Materials.plaque()
var route_summary: Label
var survey: OptionButton
var survey_detail: Label
var survey_sites: Dictionary={}
var survey_key: String=""
const COMMAND_SKIN=preload("res://assets/art/command_skin.svg")
var game: Control
var sim
var font: Font
var action_choice: OptionButton
var action_buttons: Array[Button]=[]
var progress_label: Label
var action_description: Label
var march_diagram: Dictionary={}
var map_hint: Label
var march_preview: Label
var partner_caption: Label
var partner_choice: OptionButton
var roster: ItemList
var info: Label
var feedback: Label
var destination_label: Label
var title: Label
var launch: Button
var apply: Button
var post_buttons: Dictionary={}
var post_mode: String=""
var post_cursor:=Vector2.INF
var placement: CheckButton
var selected_id: int=0
var destination: Vector2=Vector2.ZERO
var has_destination: bool=false
var drag_id: int=-1
var drag_origin: Vector2
var drag_position: Vector2
var dragging: bool=false
var draft_dirty: bool=false
var drafts: Dictionary={}
var in_battle: bool=false

func configure(owner_game: Control,used_font: Font) -> void:
    game=owner_game
    sim=game.sim
    font=used_font
    size=Vector2(1280,800)
    mouse_filter=Control.MOUSE_FILTER_STOP
    _label("軍略",Vector2(20,8),Vector2(82,39),24,GOLD)
    title=_label("",Vector2(111,7),Vector2(555,38),24,Color("#f3ecdc"))
    progress_label=_label("",Vector2(682,13),Vector2(578,30),14,Color("#cdd8d9"))
    progress_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    progress_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    _label("아군 군단",Vector2(1082,86),Vector2(160,29),20,Color("#f3ecdc"))
    roster=ItemList.new()
    roster.position=Vector2(1077,126)
    roster.size=Vector2(178,285)
    roster.add_theme_font_size_override("font_size",14)
    roster.add_theme_constant_override("v_separation",8)
    roster.fixed_icon_size=Vector2i(34,34)
    add_child(roster)
    roster.item_selected.connect(func(index: int): _select(int(roster.get_item_metadata(index))))
    placement=CheckButton.new()
    placement.text="군단 초기 배치"
    placement.position=Vector2(1079,410)
    placement.tooltip_text="아군 배치 구역 안에서 군단의 출발점 이동"
    add_child(placement)
    placement.toggled.connect(func(enabled: bool):
        if enabled: _set_post_mode(""))
    for post: String in ["보급기지","책사"]:
        var button:=_button("기지 구축" if post=="보급기지" else "책사 배치",Vector2(1078 if post=="보급기지" else 1169,445),Vector2(86,33),_pick_post.bind(post))
        button.toggle_mode=true
        button.add_theme_font_size_override("font_size",14)
        post_buttons[post]=button
    map_hint=_label("지도에서 목적지 지정\n군단 말을 끌어도 됩니다.",Vector2(1082,480),Vector2(170,33),12,Color("#cdd8d9"))
    _label("행군로",Vector2(1082,519),Vector2(164,24),16,GOLD)
    route_summary=_label("",Vector2(1082,548),Vector2(171,60),13,Color("#f4e6c9"))
    route_summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    survey=_choice(Vector2(1080,613),Vector2(173,31),[])
    survey.tooltip_text="지점을 표시하고 선택한 군단의 통행 조건을 확인"
    survey.item_selected.connect(_survey_site)
    survey_detail=_label("",Vector2(1082,648),Vector2(170,49),13,Color("#e2d1a6"))
    survey_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _label("군령서",Vector2(35,88),Vector2(276,30),21,SHEET_TEXT)
    info=_label("",Vector2(111,126),Vector2(202,85),14,SHEET_TEXT)
    info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _label("목적지",Vector2(35,221),Vector2(276,23),15,SHEET_MUTED)
    destination_label=_label("",Vector2(35,245),Vector2(276,40),15,SHEET_TEXT)
    destination_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _label("행동",Vector2(35,296),Vector2(276,24),15,SHEET_MUTED)
    action_choice=_choice(Vector2(35,326),Vector2(276,39),ACTIONS)
    action_choice.hide()
    var labels:Array[String]=["이동","공격","사수","아군 보호","우회","구원","예비","철수"]
    for i in range(ACTIONS.size()):
        var b:Button=_button(labels[i],Vector2(35+(i%2)*141,326+floori(float(i)/2.0)*40),Vector2(135,34),_choose_action.bind(i))
        _paper_button(b)
        b.toggle_mode=true
        b.tooltip_text=ACTIONS[i]
        action_buttons.append(b)
    action_description=_label("",Vector2(35,486),Vector2(276,38),13,SHEET_MUTED)
    action_description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    partner_caption=_label("협동 대상",Vector2(35,532),Vector2(276,23),15,SHEET_MUTED)
    partner_choice=_choice(Vector2(35,560),Vector2(276,38),[])
    partner_choice.item_selected.connect(func(_i: int): _mark_draft())
    _paper_button(partner_choice)
    partner_choice.add_theme_constant_override("modulate_arrow",1)
    march_preview=_label("",Vector2(35,599),Vector2(277,22),13,SHEET_MUTED)
    apply=_button("지시 확정",Vector2(35,625),Vector2(135,43),_apply)
    game._primary_button(apply)
    var cancel := _button("초안 취소",Vector2(176,625),Vector2(135,43),func():
        drafts.erase(selected_id)
        draft_dirty=false
        _select(selected_id)
        feedback.text="이 군단의 미확정 변경을 취소했습니다.")
    _paper_button(cancel)
    feedback=_label("",Vector2(274,727),Vector2(776,52),15,Color("#f3ecdc"))
    feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _button("상세 편성",Vector2(18,733),Vector2(126,41),func(): game.call("_open_planning"))
    _button("메뉴",Vector2(153,733),Vector2(100,41),func():
        if _review_pending_draft(): return
        hide()
        game.call("_show_title"))
    launch=_button("전투 개시",Vector2(1067,725),Vector2(198,57),_launch)
    game._primary_button(launch)
    launch.add_theme_font_size_override("font_size",21)
    hide()

func _label(t:String,p:Vector2,s:Vector2,fs:int,c:Color)->Label:
    var l:=Label.new()
    l.text=t
    l.position=p
    l.size=s
    l.add_theme_font_override("font",font)
    l.add_theme_font_size_override("font_size",fs)
    l.add_theme_color_override("font_color",c)
    l.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(l)
    return l

func _choice(p:Vector2,s:Vector2,items:Array[String])->OptionButton:
    var o:=OptionButton.new()
    o.position=p
    o.size=s
    for t in items: o.add_item(t)
    add_child(o)
    return o

func _button(t:String,p:Vector2,s:Vector2,callback:Callable)->Button:
    var b:=Button.new()
    b.text=t
    b.position=p
    b.size=s
    b.pressed.connect(callback)
    add_child(b)
    return b

func _paper_button(button: Button) -> void:
    button.add_theme_stylebox_override("normal",game._ui_box(Color("#f6efdf"),Color("#c9b99d")))
    button.add_theme_stylebox_override("hover",game._ui_box(Color("#fff7e7"),Color("#9c694c")))
    button.add_theme_stylebox_override("pressed",game._ui_box(Color("#5b3e31")))
    button.add_theme_stylebox_override("hover_pressed",game._ui_box(Color("#704a39")))
    button.add_theme_stylebox_override("focus",game._ui_box(Color.TRANSPARENT,Color("#a43d2e")))
    button.add_theme_color_override("font_color",SHEET_TEXT)
    button.add_theme_color_override("font_hover_color",SHEET_TEXT)
    button.add_theme_color_override("font_focus_color",SHEET_TEXT)
    button.add_theme_color_override("font_pressed_color",Color.WHITE)
    button.add_theme_color_override("font_hover_pressed_color",Color.WHITE)

func open(mid_battle:bool=false)->void:
    in_battle=mid_battle
    title.text=("전령 지시" if mid_battle else "작전 지도")+"   /   "+sim.scenario_title
    progress_label.text="군단 선택 → 목적지 지정 → 지시 확정"
    launch.text="전장 복귀" if mid_battle else "전투 개시"
    placement.disabled=mid_battle
    placement.set_pressed_no_signal(false)
    post_mode=""
    post_cursor=Vector2.INF
    for post: String in post_buttons:
        post_buttons[post].set_pressed_no_signal(false)
    post_buttons["보급기지"].text="배급 명부" if mid_battle else "기지 구축"
    post_buttons["보급기지"].toggle_mode=not mid_battle
    post_buttons["책사"].visible=not mid_battle
    roster.clear()
    for id in sim.command_ids(0):
        var u:Dictionary=sim.find_unit(id)
        var portrait: AtlasTexture=_portrait(str(u["name"]))
        roster.add_item("%s  %s명"%[u["name"],_troop_text(int(u["troops"]))],portrait)
        roster.set_item_tooltip(roster.item_count-1,str(u["type"])+" · "+str(u["mission"]))
        roster.set_item_metadata(roster.item_count-1,id)
    feedback.text="부대 말을 끌거나 지도에 목적지를 찍고 행동 및 연계 대상을 지정하십시오."
    if mid_battle: feedback.text="전투 중 명령은 6턴부터 전령으로 전달됩니다. 확정 전까지 기존 작전 유지."
    if not mid_battle: drafts.clear()
    survey_sites=sim.training_sites()
    survey.clear()
    survey_key=""
    if not survey_sites.is_empty():
        survey.add_item("지형 답사")
        for site in survey_sites: survey.add_item(site)
        survey.select(0)
    survey.visible=not survey_sites.is_empty()
    survey_detail.visible=survey.visible
    drag_id=-1
    drag_origin=Vector2.ZERO
    dragging=false
    draft_dirty=false
    _select(game.selected_id)
    show()
    game.move_child(self,game.get_child_count()-1)
    queue_redraw()

func _select(id:int)->void:
    var u:Dictionary=sim.find_unit(id)
    if u.is_empty(): return
    if draft_dirty and selected_id==id: return
    selected_id=id
    game.selected_id=id
    for i in range(roster.item_count):
        if int(roster.get_item_metadata(i))==id: roster.select(i)
    info.text="%s 군단\n%s  ·  %d명\n사기 %d  /  응집 %d\n현재: %s"%[u["name"],u["type"],int(u["troops"]),int(u["morale"]),int(u["cohesion"]),u["mission"]]
    var idx:int=ACTIONS.find(str(u["mission"]))
    action_choice.select(maxi(0,idx))
    partner_choice.clear()
    partner_choice.add_item("자동 / 없음")
    partner_choice.set_item_metadata(0,-1)
    partner_choice.select(0)
    var dispatch: Dictionary=sim.map_dispatches.get(id,{})
    var incoming: bool=in_battle and dispatch.get("status","")=="이동 중"
    var assigned:int=int(u.get("assigned_link",-1))
    if incoming:
        for letter in sim.couriers:
            if int(letter["unit_id"])==id and letter.get("map_dispatch",false):
                assigned=int(letter.get("partner",-1))
                break
    for other in sim.command_ids(0):
        if other==id: continue
        var friend:Dictionary=sim.find_unit(other)
        if float(friend["troops"])<=0: continue
        partner_choice.add_item(str(friend["name"])+" 군단")
        partner_choice.set_item_metadata(partner_choice.item_count-1,other)
        if other==assigned: partner_choice.select(partner_choice.item_count-1)
    has_destination=bool(u.get("has_destination",false))
    destination=u.get("order_destination",u["pos"]) if has_destination else u["pos"]
    if incoming:
        has_destination=true
        destination=dispatch["destination"]
        action_choice.select(maxi(0,ACTIONS.find(str(dispatch["mission"]))))
    var draft: Dictionary = drafts.get(id,{})
    draft_dirty=not draft.is_empty()
    if draft_dirty:
        destination=draft["destination"]
        has_destination=draft["has_destination"]
        action_choice.select(draft["action"])
        for row in range(partner_choice.item_count):
            if int(partner_choice.get_item_metadata(row))==int(draft["partner"]):
                partner_choice.select(row)
                break
    _sync_actions()
    _update_destination()
    queue_redraw()

func _selected_partner() -> int:
    return -1 if partner_choice.selected<0 else int(partner_choice.get_item_metadata(partner_choice.selected))

func _mark_draft() -> void:
    draft_dirty=true
    drafts[selected_id]={"destination":destination,"has_destination":has_destination,"action":action_choice.selected,"partner":_selected_partner()}
    _update_destination()
    queue_redraw()

func _refresh_draft_roster() -> void:
    for row in range(roster.item_count):
        var id: int=roster.get_item_metadata(row)
        var unit: Dictionary=sim.find_unit(id)
        var mark: String="* " if drafts.has(id) else ""
        roster.set_item_text(row,"%s%s  %s명" % [mark,unit["name"],_troop_text(int(unit["troops"]))])

func _update_destination()->void:
    _refresh_draft_roster()
    march_diagram={}
    if ACTIONS[action_choice.selected]!="철수":
        var unit: Dictionary=sim.find_unit(selected_id)
        var projected: Vector2=destination if has_destination else unit["goal"]
        march_diagram=sim.LinkedMarch.preview(sim,unit,_selected_partner(),projected)
    destination_label.text=_destination_text(destination) if has_destination else "지도에서 목표를 선택"
    march_preview.text=march_diagram.get("caption","")
    _refresh_map_hint()
    _refresh_route_summary()
    _refresh_survey()
    var problem: String = "지도에서 목적지를 먼저 선택하십시오."
    if has_destination:
        problem=sim.map_order_issue(selected_id,ACTIONS[action_choice.selected],destination,_selected_partner())
    apply.disabled=not problem.is_empty()
    apply.tooltip_text=problem
    var dispatch: String=game.dispatch_line(selected_id)
    if not drafts.is_empty():
        progress_label.text="미확정 %d개 · * 표시 군단" % drafts.size()
    elif not dispatch.is_empty():
        progress_label.text=dispatch
    elif has_destination:
        progress_label.text="행동과 연계를 검토하고 지시를 확정하십시오."
    else:
        progress_label.text="군단 선택 → 목적지 지정 → 지시 확정"
    if in_battle or draft_dirty:
        feedback.text=problem if not problem.is_empty() else ("도착 전까지 현재 지시를 유지합니다." if in_battle else "지시를 확정하거나 다른 군단의 계획을 작성할 수 있습니다.")

func _refresh_map_hint() -> void:
    if post_mode=="":
        map_hint.text="지도에서 목적지 지정\n군단 말을 끌어도 됩니다." if march_diagram.is_empty() else "행군 대형\n%s 속도 기준" % march_diagram["limiter"]
        return
    if post_cursor==Vector2.INF:
        map_hint.text="아군 구역에 "+post_mode+" 위치 지정"
        return
    if not sim.post_placement_issue(post_mode,post_cursor).is_empty():
        map_hint.text="배치 불가 · 다른 땅 선택"
    elif post_mode=="보급기지":
        var count:=0
        for unit in sim.units:
            if unit["side"]==0 and unit["troops"]>0 and post_cursor.distance_to(unit["pos"])<=sim.supply_radius(): count+=1
        map_hint.text="배급권 안 아군 %d개 군단\n개전 후 %d초에 배급 시작" % [count,roundi(sim.BASE_BUILD_SECONDS*sim.operation_scale())]
    else:
        map_hint.text="전령 출발지 · "+_grid_ref(post_cursor)+"\n클릭해 책사 위치 확정"

func _pick_post(post: String) -> void:
    if in_battle:
        if post=="보급기지": game.open_supply_ledger()
        return
    _set_post_mode("" if post==post_mode else post)

func _set_post_mode(mode: String) -> void:
    post_mode=mode
    drag_origin=Vector2.ZERO
    drag_id=-1
    dragging=false
    post_cursor=Vector2.INF if mode=="" else (sim.bases[0]["pos"] if mode=="보급기지" else sim.commanders[0]["pos"])
    for post: String in post_buttons: post_buttons[post].set_pressed_no_signal(post==mode)
    if mode!="":
        placement.set_pressed_no_signal(false)
        feedback.text="기지 위치를 직접 정하면 전투 중 그 자리에 머뭅니다." if mode=="보급기지" else "책사를 배치할 위치를 클릭하세요. 전령은 책사가 있는 곳에서 출발합니다."
    _refresh_map_hint()
    queue_redraw()

func _grid_ref(point: Vector2) -> String:
    var relative: Vector2=point/sim.field_size
    return String.chr(65+clampi(floori(relative.x*8),0,7))+str(1+clampi(floori(relative.y*6),0,5))

func _route_points(unit: Dictionary, target: Vector2) -> PackedVector2Array:
    var route:=PackedVector2Array([unit["pos"]])
    var crossing: float=sim.map_order_crossing(int(unit["id"]),target)
    if unit["id"]==selected_id and target==destination and not march_diagram.is_empty():
        crossing=march_diagram["bridge"]
    elif crossing>=0.0:
        var shared: float=sim.march_plans.get(unit["id"],{}).get("bridge",-1.0)
        if shared>=0.0: crossing=shared
    if crossing>=0.0: route.append(Vector2(sim.river_x(crossing),crossing))
    route.append(target)
    return route

func _refresh_route_summary() -> void:
    var u: Dictionary=sim.find_unit(selected_id)
    if u.is_empty() or not has_destination:
        route_summary.text="목적지를 지정하면 예상 경로를 표시합니다."
        return
    if sim.long_operation and sim.in_open_water(destination):
        route_summary.text=_grid_ref(destination)+"  ·  하천\n교량이나 육지를 선택하십시오."
        return
    var route:=_route_points(u,destination)
    var steps:=PackedStringArray([_grid_ref(route[0])])
    if route.size()==3: steps.append(game.call("_bridge_name",route[1].y))
    steps.append(_grid_ref(destination))
    var distance: float=0.0
    for i in range(1,route.size()): distance+=route[i-1].distance_to(route[i])
    route_summary.text=" → ".join(steps)+"\n예상 거리  "+str(roundi(distance))+" 지도 단위"

func _survey_site(index: int) -> void:
    survey_key=survey.get_item_text(index) if index>0 else ""
    _refresh_survey()
    queue_redraw()

func _refresh_survey() -> void:
    if survey_key.is_empty():
        survey_detail.text=""
        return
    var point: Vector2=survey_sites[survey_key]
    var note: String="이동 %d%%" % sim.terrain_movement_percent(selected_id,point)
    match survey_key:
        "숲": note+=" · 은폐"
        "고지": note+=" · 시야 확대"
        "북측 교량","중앙 교량","남측 교량": note+=" · 도하로"
        "하천": note="도하 불가 · 교량 이용" if sim.long_operation else note
        "성문","목책":
            var structure: Dictionary=sim.structures[0 if survey_key=="성문" else 1]
            note="적 시설 · 통행 제한" if float(structure["hp"])>0.0 else "파괴 · 통행 가능"
        "보급기지": note="군량·화살 보충" if sim.bases[0]["state"]=="가동" else str(sim.bases[0]["state"])
        "점령 거점": note="성문 파괴 후 거점 확보"
    survey_detail.text="%s  %s\n%s" % [_grid_ref(point),survey_key,note]

func _apply()->void:
    if not has_destination:
        feedback.text="먼저 지도에서 목적지를 지정하십시오."
        return
    var action:String=ACTIONS[action_choice.selected]
    var partner:int=_selected_partner()
    var problem: String=sim.map_order_issue(selected_id,action,destination,partner)
    if not problem.is_empty():
        feedback.text=problem
        return
    if sim.issue_map_order(selected_id,action,destination,partner):
        drafts.erase(selected_id)
        draft_dirty=false
        _update_destination()
        feedback.text="전령 파견 완료 · 도착까지 기존 지시 유지" if in_battle else "작전 지시 확정 · "+str(sim.find_unit(selected_id)["name"])+" / "+action
        queue_redraw()
    else:
        feedback.text="군단 상태가 변경되어 지시를 확정할 수 없습니다."

func _review_pending_draft() -> bool:
    if drafts.is_empty(): return false
    if not draft_dirty: _select(int(drafts.keys()[0]))
    feedback.text="미확정 지시 %d개를 확정하거나 취소한 뒤 진행하십시오." % drafts.size()
    return true

func _launch()->void:
    if not in_battle and _review_pending_draft(): return
    hide()
    if in_battle: game.call("_return_to_battle")
    else: game.call("_start")

func _point(p:Vector2)->Vector2:
    return MAP.position+p/sim.field_size*MAP.size

func _world(p:Vector2)->Vector2:
    return ((p-MAP.position)/MAP.size*sim.field_size).clamp(Vector2(1,1),sim.field_size-Vector2(1,1))

func _gui_input(event:InputEvent)->void:
    if post_mode!="":
        if event is InputEventMouseMotion:
            post_cursor=_world(event.position) if MAP.has_point(event.position) else Vector2.INF
            _refresh_map_hint()
            queue_redraw()
        elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
            if event.pressed: drag_origin=event.position
            elif MAP.has_point(drag_origin) and MAP.has_point(event.position):
                var point:=_world(event.position)
                var problem: String=sim.post_placement_issue(post_mode,point)
                if problem.is_empty() and sim.place_post(post_mode,point):
                    feedback.text="%s %s · %s" % [post_mode,_grid_ref(point),"개전과 함께 구축 시작" if post_mode=="보급기지" else "책사 배치 완료"]
                    survey_sites=sim.training_sites()
                    _refresh_survey()
                    _set_post_mode("")
                else:
                    feedback.text=problem
                drag_origin=Vector2.ZERO
            accept_event()
        return
    if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
        if event.pressed and MAP.has_point(event.position):
            drag_origin=event.position
            drag_position=event.position
            drag_id=-1
            var best:float=23.0
            for id in sim.command_ids(0):
                var u:Dictionary=sim.find_unit(id)
                var d:float=_point(u["pos"]).distance_to(event.position)
                if float(u["troops"])>0 and d<best:
                    best=d
                    drag_id=id
            if drag_id>=0:
                if selected_id!=drag_id: _select(drag_id)
                if selected_id!=drag_id:
                    drag_id=-1
                    drag_origin=Vector2.ZERO
                    accept_event()
                    return
            dragging=false
            accept_event()
        elif not event.pressed and (drag_id>=0 or MAP.has_point(drag_origin)):
            if MAP.has_point(event.position) and (dragging or drag_id<0):
                var p:Vector2=_world(event.position)
                if placement.button_pressed and not in_battle:
                    feedback.text="초기 배치 변경" if sim.place_unit(selected_id,p) else "아군 배치 구역 및 부대 간격을 확인하십시오."
                else:
                    destination=p
                    has_destination=true
                    _mark_draft()
            drag_id=-1
            drag_origin=Vector2.ZERO
            dragging=false
            queue_redraw()
            accept_event()
    elif event is InputEventMouseMotion and drag_id>=0:
        drag_position=event.position
        dragging=drag_origin.distance_to(drag_position)>5.0
        queue_redraw()
        accept_event()

func _draw()->void:
    draw_texture_rect(Materials.WALNUT,Rect2(0,0,1280,800),false,Color("#d7cabc"))
    draw_style_box(lacquer,Rect2(0,0,1280,59))
    draw_rect(Rect2(0,0,6,56),Color("#cf674e"))
    draw_rect(Rect2(21,82,312,628),Color(0.07,0.05,0.03,0.65))
    draw_texture_rect(Materials.PAPER,Rect2(16,76,312,628),false)
    draw_rect(Rect2(23,83,298,614),Color("#ae926b"),false,1)
    draw_line(Vector2(35,118),Vector2(311,118),Color("#a68e68"))
    draw_rect(Rect2(16,76,312,4),Color("#a43d2e"))
    draw_line(Vector2(35,220),Vector2(311,220),Color("#c9b99d"))
    draw_line(Vector2(35,622),Vector2(311,622),Color("#c9b99d"))
    draw_style_box(lacquer,Rect2(1068,76,196,628))
    draw_line(Vector2(1081,515),Vector2(1252,515),Color("#8d7953"))
    draw_style_box(lacquer,Rect2(6,716,1268,78))
    if not march_diagram.is_empty(): _draw_march_diagram()
    if sim==null: return
    draw_rect(Rect2(MAP.position+Vector2(3,5),MAP.size),Color(0.08,0.05,0.025,0.65))
    draw_texture_rect(Materials.SILK,MAP,false)
    draw_rect(MAP.grow(1),Color("#998568"),false,1.0)
    for mark in range(1,8):
        var x: float=MAP.position.x+MAP.size.x*mark/8.0
        draw_line(Vector2(x,MAP.position.y),Vector2(x,MAP.end.y),Color(0.32,0.22,0.10,0.11))
    for mark in range(1,6):
        var y: float=MAP.position.y+MAP.size.y*mark/6.0
        draw_line(Vector2(MAP.position.x,y),Vector2(MAP.end.x,y),Color(0.32,0.22,0.10,0.11))
    for column in range(8):
        _ink(String.chr(65+column),MAP.position+Vector2((column+0.5)*MAP.size.x/8.0-4,20),11,INK)
    for row in range(6):
        _ink(str(row+1),MAP.position+Vector2(10,(row+0.5)*MAP.size.y/6.0),11,INK)
    if sim.scenario_id==FieldGeometry.TRAINING_SCENARIO:
        for basin: Rect2 in FieldGeometry.TRAINING_MARSHES:
            var rim:=PackedVector2Array()
            var center:=_point(basin.get_center())
            var radius:=_point(basin.end)-center
            for i in range(41): rim.append(center+Vector2.from_angle(i*TAU/40.0)*radius)
            draw_colored_polygon(rim.slice(0,40),Color(0.28,0.43,0.35,0.30))
            draw_polyline(rim,Color("#798666"),1.0,true)
            for i in range(-2,3):
                var y: float=i*0.28
                var dx: float=sqrt(1.0-y*y)*radius.x*0.62
                var start:=center+Vector2(-dx,y*radius.y)
                draw_line(start,start+Vector2(dx*0.65,-1),Color(0.30,0.44,0.40,0.45),1,true)
                var reed:=center+Vector2(dx*(0.50+0.22*cos(i*2.8)),y*radius.y)
                draw_multiline(PackedVector2Array([reed,reed+Vector2(0,-7),reed,reed+Vector2(-3,-5),reed,reed+Vector2(3,-4)]),Color("#67775c"),1,true)
            _ink("습지",center+Vector2(-12,5),12,INK)
    for lane in range(3):
        var line:=PackedVector2Array()
        for x in range(0,int(sim.field_size.x)+1,35): line.append(_point(Vector2(x,sim.road_y(float(x),lane))))
        draw_polyline(line,Color("#816746"),4.8,true)
        draw_polyline(line,Color("#e8d6ab"),2.6,true)
        for j in range(0,line.size()-1,2):
            draw_line(line[j],line[j+1],Color("#a48758"),0.9,true)
    var river:=PackedVector2Array()
    for y in range(0,int(sim.field_size.y)+1,16): river.append(_point(Vector2(sim.river_x(float(y)),float(y))))
    draw_polyline(river,Color("#596d63"),19,true)
    draw_polyline(river,Color("#8ba49a"),14,true)
    draw_polyline(river,Color("#c4c8a9"),3,true)
    for bank_offset in [-9.0,9.0]:
        var bank_line:=PackedVector2Array()
        for i in range(river.size()):
            var rp:Vector2=river[i]
            bank_line.append(rp+Vector2(bank_offset+sin(float(i)*0.72)*1.1,0))
        draw_polyline(bank_line,Color("#4b675c"),0.85,true)
    for y in [390.0,850.0,1300.0]:
        var p:Vector2=_point(Vector2(sim.river_x(y),y))
        draw_rect(Rect2(p-Vector2(15,9),Vector2(30,18)),Color("#826b47"))
        draw_rect(Rect2(p-Vector2(13,7),Vector2(26,14)),Color("#c4a573"))
        for x in range(-12,13,4): draw_line(p+Vector2(x,-7),p+Vector2(x,7),INK,0.8)
        draw_line(p+Vector2(-15,-9),p+Vector2(15,-9),INK,1.2)
        draw_line(p+Vector2(-15,9),p+Vector2(15,9),INK,1.2)
    for forest in sim.forests:
        var area:Rect2=forest
        var center:Vector2=_point(area.get_center())
        var extent: Vector2=area.size/sim.field_size*MAP.size
        draw_texture_rect_region(INK_RELIEF,Rect2(center-extent*0.53,extent*1.06),Rect2(384,0,384,212))
    var hill:Rect2=sim.hill
    for ring in range(6):
        var contour:=PackedVector2Array()
        var hcenter:Vector2=_point(hill.get_center())
        var hsize:Vector2=hill.size/sim.field_size*MAP.size*(0.15+ring*0.075)
        for j in range(25):
            var angle:float=TAU*float(j)/24.0
            contour.append(hcenter+Vector2(cos(angle)*hsize.x,sin(angle)*hsize.y)*(0.86+0.13*sin(angle*3.0)))
        draw_polyline(contour,Color(0.42,0.32,0.19,0.26),1.0,true)
    var hc:Vector2=_point(hill.get_center())
    var ridge_extent: Vector2=hill.size/sim.field_size*MAP.size*1.32
    draw_texture_rect_region(INK_RELIEF,Rect2(hc-ridge_extent*0.52,ridge_extent),Rect2(0,0,384,212))
    _ink("고지",hc+Vector2(39,-32),11,INK)
    draw_rect(Rect2(MAP.position,Vector2(MAP.size.x*0.30,MAP.size.y)),Color(0.20,0.35,0.45,0.05))
    # Reserve visible army counters before placing the names of nearby sites.
    var occupied: Array[Rect2]=[]
    for structure in sim.structures:
        if structure["hp"]>0:
            var fort: Rect2=structure["rect"]
            occupied.append(Rect2(_point(fort.position),_point(fort.end)-_point(fort.position)).grow(2))
    for unit in sim.units:
        if float(unit["troops"])>0.0 and game.call("_visible_unit",unit):
            var p: Vector2=_point(unit["pos"])
            var half_width: float=maxf(24.0,font.get_string_size(str(unit["name"]),HORIZONTAL_ALIGNMENT_LEFT,-1,13).x*0.5+8.0)
            occupied.append(Rect2(p-Vector2(half_width,35),Vector2(half_width*2,57)))
    # Cartographic objective symbols do not imply a castle on open ground.
    for site in sim.outposts:
        var p:Vector2=_point(site["pos"])
        var known:bool=not game.fog_enabled or not sim.started or sim.finished or sim.player_can_see(site["pos"])
        var owner:int=int(site["owner"]) if known else -1
        var color:Color=BLUE if owner==0 else (Color("#a04f3d") if owner==1 else INK)
        draw_circle(p,9,Color("#d8c39a"),true)
        draw_polyline(PackedVector2Array([p+Vector2(0,-7),p+Vector2(7,0),p+Vector2(0,7),p+Vector2(-7,0),p+Vector2(0,-7)]),color,1.6,true)
        if owner>=0: draw_circle(p,3,color)
        _site_label(str(site["name"]),p,18,12,occupied)
    # Actual fortification segments only: gate is part of the connected wall.
    for structure in sim.structures:
        var area:Rect2=structure["rect"]
        var a:Vector2=_point(area.position)
        var b:Vector2=_point(area.end)
        var box:=Rect2(a,b-a)
        if float(structure["hp"])<=0.0:
            draw_rect(box.grow(1),Color(0.35,0.26,0.17,0.28),false,1)
            continue
        var gate:bool=str(structure["kind"])=="성문"
        draw_rect(box.grow(1),Color("#95714b") if gate else Color("#68543b"))
        draw_rect(box.grow(1),INK,false,1.2)
        if gate:
            var mid:Vector2=box.get_center()
            draw_line(mid-Vector2(5,0),mid+Vector2(5,0),INK,2.0,true)
            _site_label(str(structure["name"]),mid,-18,11,occupied)
    if post_mode!="":
        var edge:=_point(Vector2(sim.field_size.x*0.5,0))
        draw_rect(Rect2(edge,MAP.end-edge),Color(0.18,0.13,0.10,0.16))
        draw_dashed_line(edge,Vector2(edge.x,MAP.end.y),INK,1.5,7.0)
    if post_mode=="보급기지" or sim.bases[0]["state"]=="착공 예정":
        var center: Vector2=post_cursor if post_mode=="보급기지" and post_cursor!=Vector2.INF else sim.bases[0]["pos"]
        if sim.post_placement_issue("보급기지",center).is_empty():
            var previous:=_point(center+Vector2.RIGHT*sim.supply_radius())
            for step in range(1,65):
                var next:=_point(center+Vector2.from_angle(TAU*step/64.0)*sim.supply_radius())
                if MAP.has_point(previous) and MAP.has_point(next):
                    draw_line(previous,next,Color("#387065"),1.8,true)
                previous=next
    for b in sim.bases:
        if not b["alive"]: continue
        if b["side"]==0: continue
        if int(b["side"])!=0 and game.fog_enabled and not sim.player_can_see(b["pos"]): continue
        var p:Vector2=_point(b["pos"])
        draw_rect(Rect2(p-Vector2(8,8),Vector2(16,16)),INK,false,2)
        _ink("군량",p+Vector2(-12,-11),12,INK)
    for u in sim.units:
        if float(u["troops"])<=0: continue
        if not game.call("_visible_unit",u): continue
        var p:Vector2=_point(u["pos"])
        if int(u["side"])==0 and bool(u.get("has_destination",false)) and int(u["id"])!=selected_id:
            var route:=_route_points(u,u["order_destination"])
            for i in range(1,route.size()):
                _arrow(_point(route[i-1]),_point(route[i]),Color(BLUE,0.62),1.5)
        if int(u["side"])==0:
            var partner:Dictionary=sim.find_unit(int(u.get("assigned_link",-1)))
            if not partner.is_empty() and int(u["id"])!=selected_id: _dashed(p,_point(partner["pos"]),Color(0.40,0.31,0.49,0.42))
    var selected:Dictionary=sim.find_unit(selected_id)
    if not selected.is_empty() and partner_choice.selected>=0:
        var linked:Dictionary=sim.find_unit(int(partner_choice.get_item_metadata(partner_choice.selected)))
        if not linked.is_empty():
            var start:=_point(selected["pos"])
            var end:=_point(linked["pos"])
            if ACTIONS[action_choice.selected] in ["전열 엄호","구원 지원"]:
                draw_line(start,end,Color("#396856"),2.4,true)
                CommandMarks.shield(self,end+Vector2(12,0),0.85,CommandMarks.GUARD)
            else:
                _dashed(start,end,Color("#365f82"))
    if has_destination:
        var u:Dictionary=sim.find_unit(selected_id)
        var target: Vector2=_point(destination)
        var ink: Color=RED if sim.long_operation and sim.in_open_water(destination) else Color("#98452f")
        if not u.is_empty():
            var origin:Vector2=_point(u["pos"])
            var route:=_route_points(u,destination)
            if route.size()==3:
                var bridge:=_point(route[1])
                draw_polyline(PackedVector2Array([origin,bridge,target]),Color("#f0dca9"),6.0,true)
                draw_line(origin,bridge,ink,2.8,true)
                _arrow(bridge,target,ink,2.8)
                draw_circle(bridge,8.0,ink,false,2.0,true)
            elif ink==RED:
                _dashed(origin,target,ink)
            else:
                _arrow(origin,target,Color("#e9d6a5"),5.5)
                _arrow(origin,target,ink,2.8)
        draw_circle(target,12,ink,false,2,true)
        draw_circle(target,3,ink)
        var dispatch: Dictionary=sim.map_dispatches.get(selected_id,{})
        var in_transit: bool=in_battle and dispatch.get("status","")=="이동 중" and destination.is_equal_approx(dispatch.get("destination",Vector2.INF))
        var stamp: String="초안" if draft_dirty else ("전달 중" if in_transit else "지시")
        var label_pos:=target+Vector2(14,-10)
        label_pos=label_pos.clamp(MAP.position+Vector2(5,5),MAP.end-Vector2(53,24))
        var stamp_area:=Rect2(label_pos,Vector2(49 if stamp=="전달 중" else 34,19))
        draw_rect(stamp_area,Color("#f0dfbc"))
        draw_rect(stamp_area,ink,false,1.3)
        _ink(stamp,label_pos+Vector2(4,14),12,ink)
    for u in sim.units:
        if float(u["troops"])<=0: continue
        if not game.call("_visible_unit",u): continue
        _piece(u,_point(u["pos"]),int(u["id"])==selected_id)
    var depot: Dictionary=sim.bases[0]
    var advisor:=_point(sim.commanders[0]["pos"])
    var depot_point:=_point(depot["pos"])
    if depot["alive"]:
        draw_rect(Rect2(depot_point-Vector2(6,6),Vector2(12,12)),Color("#2a534d"))
        draw_rect(Rect2(depot_point-Vector2(6,6),Vector2(12,12)),Color("#eedca8"),false,1.4)
        _post_label("기지 예정지" if depot["state"]=="착공 예정" else "보급기지",depot_point,1)
    draw_circle(advisor,5,Color("#513c52"))
    draw_circle(advisor,5,Color("#ead6a4"),false,1.4,true)
    _post_label("책사",advisor,-1)
    if post_mode!="" and post_cursor!=Vector2.INF:
        var mark:=_point(post_cursor)
        var ink:=BLUE if sim.post_placement_issue(post_mode,post_cursor).is_empty() else RED
        draw_arc(mark,10,0,TAU,32,ink,2,true)
        draw_line(mark-Vector2(5,0),mark+Vector2(5,0),ink,1.5)
        draw_line(mark-Vector2(0,5),mark+Vector2(0,5),ink,1.5)
    if dragging and drag_id>=0 and MAP.has_point(drag_position):
        var u:Dictionary=sim.find_unit(drag_id)
        if not u.is_empty(): _piece(u,drag_position,true)
    if survey_sites.has(survey_key):
        var mark:=_point(survey_sites[survey_key])
        draw_arc(mark,14,0,TAU,36,Color("#f3dfac"),4,true)
        draw_arc(mark,14,0,TAU,36,BLUE,1.8,true)
        _plate(survey_key,mark+Vector2(0,-23),12,Color("#f4dcaa"))
    var compass:Vector2=MAP.end-Vector2(39,MAP.size.y-46)
    draw_arc(compass,20,0,TAU,40,Color("#6f5736"),1.4,true)
    draw_colored_polygon(PackedVector2Array([compass+Vector2(0,-17),compass+Vector2(5,7),compass,compass+Vector2(-5,7)]),INK)
    _ink("北",compass+Vector2(-7,-23),13,INK)
    var scale_origin:Vector2=MAP.end-Vector2(142,20)
    draw_line(scale_origin,scale_origin+Vector2(94,0),INK,1.4)
    for dx in [0,47,94]: draw_line(scale_origin+Vector2(dx,-4),scale_origin+Vector2(dx,4),INK,1.2)
    _ink("%d 지도 단위" % roundi(94.0*sim.field_size.x/MAP.size.x),scale_origin+Vector2(10,-8),10,INK)
    _ink("북로",_point(Vector2(sim.field_size.x*0.65,sim.road_y(sim.field_size.x*0.65,0)) )+Vector2(0,-12),12,INK)
    _ink("남로",_point(Vector2(sim.field_size.x*0.65,sim.road_y(sim.field_size.x*0.65,2)) )+Vector2(0,-12),12,INK)
    var u:Dictionary=sim.find_unit(selected_id)
    if not u.is_empty():
        var portrait:AtlasTexture=_portrait(str(u["name"]))
        if portrait!=null:
            draw_texture_rect(portrait,Rect2(35,124,64,75),false)
        else:
            _art(3,Rect2(35,124,64,75))
    var legend:=MAP.position+Vector2(26,MAP.size.y-22)
    _arrow(legend,legend+Vector2(25,0),Color("#98452f"),2)
    _ink("행군로",legend+Vector2(32,4),12,INK)
    _dashed(legend+Vector2(88,0),legend+Vector2(116,0),Color("#73537c"))
    _ink("협동",legend+Vector2(122,4),12,INK)

func _post_label(caption: String, point: Vector2, side: int) -> void:
    var offset: float=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x*0.5+14
    var pos: Vector2=(point+Vector2(side*offset,side*11)).clamp(MAP.position+Vector2(offset,12),MAP.end-Vector2(offset,12))
    _plate(caption,pos,12,Color("#e9dfbc"))

func _ink(t:String,p:Vector2,fs:int,c:Color)->void:
    if font!=null: draw_string(font,p,t,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,c)

func _arrow(a:Vector2,b:Vector2,c:Color,w:float)->void:
    if a.distance_to(b)<12: return
    var d:Vector2=(b-a).normalized()
    draw_line(a,b,c,w,true)
    draw_colored_polygon(PackedVector2Array([b,b-d*12+d.orthogonal()*6,b-d*12-d.orthogonal()*6]),c)

func _dashed(a:Vector2,b:Vector2,c:Color)->void:
    var d:float=a.distance_to(b)
    var direction:Vector2=(b-a).normalized()
    for i in range(0,int(d),10): draw_line(a+direction*i,a+direction*minf(float(i)+5,d),c,2,true)

func _draw_march_diagram() -> void:
    var center:=Vector2(1217,484)
    var forward: Vector2=march_diagram["forward"]
    var right:=Vector2(-forward.y,forward.x)
    var slots: Dictionary=march_diagram["slots"]
    var positions:=PackedVector2Array()
    for unit in march_diagram["group"]:
        var offset: Vector2=slots[unit["id"]]["offset"]
        positions.append(forward*offset.x+right*offset.y)
    var bounds:=Rect2(positions[0],Vector2.ZERO)
    for point in positions: bounds=bounds.expand(point)
    var scale_factor:=minf(0.22,40.0/maxf(1.0,maxf(bounds.size.x,bounds.size.y)))
    var tip:=center+forward*30.0
    draw_line(tip-forward*5.0-right*3.0,tip,GOLD,1.5,true)
    draw_line(tip-forward*5.0+right*3.0,tip,GOLD,1.5,true)
    for i in range(positions.size()):
        var unit: Dictionary=march_diagram["group"][i]
        var point:=center+(positions[i]-bounds.get_center())*scale_factor
        draw_circle(point,8.5,Color("#294958"))
        draw_arc(point,8.5,0,TAU,24,GOLD if unit["id"]==selected_id else Color("#79909a"),1,true)
        _ink(str(unit["type"]).left(1),point+Vector2(-5,4),11,Color("#f3ead4"))

func _piece(u:Dictionary,p:Vector2,selected:bool)->void:
    var c:Color=BLUE if int(u["side"])==0 else RED
    if selected:
        draw_circle(p,19,Color(0.98,0.75,0.22,0.18))
        draw_arc(p,19,0,TAU,40,Color("#edc56b"),2.2,true)
    draw_texture_rect_region(COMMAND_SKIN,Rect2(p-Vector2(25,37),Vector2(50,50)),Rect2(512+int(u["side"])*128,0,128,128))
    var kind:String="步" if str(u["type"])=="보병" else ("弓" if str(u["type"])=="궁병" else "騎")
    _ink(kind,p+Vector2(-6,-9),14,Color("#f1ddb1"))
    _plate(str(u["name"]),p+Vector2(0,12),13,Color("#f0ce84") if selected else Color("#ded2b0"))

func _art(tile:int,rect:Rect2,tint:Color=Color.WHITE)->void:
    draw_texture_rect_region(ART,rect,Rect2(float(tile%4)*256.0,float(floori(float(tile)/4.0))*256.0,256,256),tint)

func _portrait(name:String)->AtlasTexture:
    var side: int=0 if name in ["왕평","마속","위연","강유","관흥","장익"] else 1
    return game.call("_commander_icon",name,side)

func _site_label(caption: String, location: Vector2, offset_y: int, size_px: int, occupied: Array[Rect2]) -> void:
    var extent:=Vector2(font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x+14,18)
    var position_on_map:=location+Vector2(0,offset_y)
    var least_overlap:=INF
    for shift in [Vector2(0,offset_y),Vector2(0,-offset_y),Vector2(0,offset_y*2),Vector2(0,-offset_y*2),Vector2(-extent.x*0.64,offset_y),Vector2(extent.x*0.64,offset_y)]:
        var candidate: Vector2=(location+shift).clamp(MAP.position+extent*0.5,MAP.end-extent*0.5)
        var bounds:=Rect2(candidate-extent*0.5,extent).grow(2)
        var overlap: float=0.0
        for area in occupied: overlap+=bounds.intersection(area).get_area()
        if overlap<least_overlap:
            least_overlap=overlap
            position_on_map=candidate
            if is_zero_approx(overlap): break
    if location.distance_to(position_on_map)>22:
        draw_line(location,position_on_map,INK,1.1,true)
    occupied.append(Rect2(position_on_map-extent*0.5,extent))
    _plate(caption,position_on_map,size_px,Color("#dbc58d"))

func _plate(t:String,p:Vector2,fs:int,c:Color)->void:
    var width:float=font.get_string_size(t,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x+14.0
    var rect:=Rect2(p-Vector2(width/2.0,9),Vector2(width,18))
    draw_rect(rect,Color("#342b20"))
    draw_rect(rect,Color("#b09561"),false,1.0)
    _ink(t,p+Vector2(-width/2.0+7,5),fs,c)

func _choose_action(index:int)->void:
    action_choice.select(index)
    _sync_actions()
    _mark_draft()

func _sync_actions()->void:
    var descriptions:Array[String]=["동행 군단과 느린 쪽의 보속으로 이동","목표 지역의 적을 공격","지정 구역을 확보하고 방어","위협이 접근하면 지정 아군을 우선 보호","적의 측후방으로 기동","위기에 처한 연계 군단을 지원","지정 지점에서 투입을 대기","목표 지점으로 철수"]
    for i in range(action_buttons.size()):
        action_buttons[i].set_pressed_no_signal(i==action_choice.selected)
    if action_choice.selected>=0 and action_choice.selected<descriptions.size():
        action_description.text=descriptions[action_choice.selected]
        match ACTIONS[action_choice.selected]:
            "지정 위치 이동": partner_caption.text="함께 이동할 군단"
            "전열 엄호","구원 지원": partner_caption.text="보호할 군단"
            _: partner_caption.text="협동 대상"

func _destination_text(p:Vector2)->String:
    var terrain:String=sim.terrain_at(p)
    var detail: String="이동 속도 %d%%" % int(sim.terrain_movement_percent(selected_id,p))
    var crossing: float=march_diagram.get("bridge",sim.map_order_crossing(selected_id,p))
    if terrain=="하천" and sim.long_operation:
        detail="목표 지정 불가"
    elif crossing>=0.0:
        detail+=" · "+str(game.call("_bridge_name",crossing))+" 예상"
    var nearest:String=""
    var distance:float=220.0
    for site in sim.outposts:
        var d:float=p.distance_to(site["pos"])
        if d<distance:
            distance=d
            nearest=str(site["name"])
    if nearest!="": return nearest+" 인근 · "+terrain+"\n"+detail
    return ("서부" if p.x<sim.field_size.x*0.5 else "동부")+" "+("북로" if p.y<sim.field_size.y/3.0 else ("남로" if p.y>sim.field_size.y*2.0/3.0 else "중앙"))+" · "+terrain+"\n"+detail

func _troop_text(n:int)->String:
    var digits:String=str(n)
    if digits.length()>3: return digits.substr(0,digits.length()-3)+","+digits.right(3)
    return digits
