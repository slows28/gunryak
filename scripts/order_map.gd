extends Control
## Separate paper war-room: actual battle coordinates, independent rendering and input.
const ACTIONS: Array[String]=["지정 위치 이동","공격","지역 사수","전열 엄호","측후방 기동","구원 지원","예비 대기","철수"]
const PAPER=Color("#d6c29a")
const INK=Color("#554735")
const GOLD=Color("#d5b473")
const BLUE=Color("#315b79")
const RED=Color("#934e3e")
const MAP=Rect2(226,90,804,510)
var game: Control
var sim
var font: Font
var action_choice: OptionButton
var partner_choice: OptionButton
var roster: ItemList
var info: Label
var feedback: Label
var destination_label: Label
var title: Label
var launch: Button
var apply: Button
var placement: CheckButton
var selected_id: int=0
var destination: Vector2=Vector2.ZERO
var has_destination: bool=false
var drag_id: int=-1
var drag_origin: Vector2
var drag_position: Vector2
var dragging: bool=false
var draft_dirty: bool=false
var in_battle: bool=false
var background: ImageTexture

func configure(owner_game: Control,used_font: Font) -> void:
    game=owner_game
    sim=game.sim
    font=used_font
    size=Vector2(1280,800)
    mouse_filter=Control.MOUSE_FILTER_STOP
    title=_label("",Vector2(28,16),Vector2(700,48),26,GOLD)
    _label("軍略   /   作戰圖",Vector2(1040,18),Vector2(220,40),20,GOLD)
    _label("아군 군단",Vector2(23,87),Vector2(180,32),19,GOLD)
    roster=ItemList.new()
    roster.position=Vector2(16,128)
    roster.size=Vector2(199,334)
    roster.add_theme_font_size_override("font_size",15)
    roster.add_theme_constant_override("v_separation",18)
    add_child(roster)
    roster.item_selected.connect(func(index: int): _select(int(roster.get_item_metadata(index))))
    _label("지도 조작",Vector2(24,478),Vector2(185,25),16,GOLD)
    placement=CheckButton.new()
    placement.text="초기 배치"
    placement.position=Vector2(20,512)
    add_child(placement)
    var guide=_label("말을 끌어 목적지 지정\n초기 배치 선택 시\n아군 영역 내 이동",Vector2(24,551),Vector2(190,80),13,Color("#c4b69e"))
    guide.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _label("작전 지시",Vector2(1048,88),Vector2(220,30),19,GOLD)
    info=_label("",Vector2(1048,125),Vector2(218,103),15,Color("#eadbc1"))
    info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _label("① 행동",Vector2(1048,235),Vector2(216,24),14,GOLD)
    action_choice=_choice(Vector2(1046,265),Vector2(218,39),ACTIONS)
    action_choice.item_selected.connect(func(_i: int): draft_dirty=true; queue_redraw())
    _label("② 목적지 · 지도에서 지정",Vector2(1048,320),Vector2(220,25),14,GOLD)
    destination_label=_label("",Vector2(1048,350),Vector2(220,52),15,Color("#eadbc1"))
    destination_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _label("③ 협동 대상",Vector2(1048,415),Vector2(216,25),14,GOLD)
    partner_choice=_choice(Vector2(1046,447),Vector2(218,39),[])
    partner_choice.item_selected.connect(func(_i: int): draft_dirty=true; queue_redraw())
    apply=_button("지시 확정",Vector2(1046,510),Vector2(218,45),_apply)
    _label("진형·교전은 장수의 현장 판단",Vector2(1048,565),Vector2(218,51),13,Color("#c4b69e")).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    feedback=_label("",Vector2(25,637),Vector2(920,58),17,GOLD)
    feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _button("상세 편성",Vector2(22,721),Vector2(170,54),func(): game._open_planning())
    _button("메뉴",Vector2(205,721),Vector2(116,54),func(): hide(); game._show_title())
    launch=_button("전투 개시",Vector2(1008,718),Vector2(252,58),_launch)
    var style:=StyleBoxFlat.new()
    style.bg_color=Color("#704133")
    style.border_color=GOLD
    style.set_border_width_all(2)
    launch.add_theme_stylebox_override("normal",style)
    launch.add_theme_font_size_override("font_size",22)
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

func open(mid_battle:bool=false)->void:
    in_battle=mid_battle
    title.text="군략  ·  "+sim.scenario_title+"  /  "+("전령 지시" if mid_battle else "작전 회의")
    launch.text="전장 복귀" if mid_battle else "전투 개시"
    placement.disabled=mid_battle
    placement.set_pressed_no_signal(false)
    roster.clear()
    for id in sim.command_ids(0):
        var u:Dictionary=sim.find_unit(id)
        roster.add_item("%s  ·  %d명"%[u["name"],int(u["troops"])])
        roster.set_item_metadata(roster.item_count-1,id)
    feedback.text="부대 말을 끌거나 지도에 목적지를 찍고 행동 및 연계 대상을 지정하십시오."
    if mid_battle: feedback.text="전투 중 명령은 6턴부터 전령으로 전달됩니다. 확정 전까지 기존 작전 유지."
    _select(game.selected_id)
    show()
    game.move_child(self,game.get_child_count()-1)
    queue_redraw()

func _select(id:int)->void:
    var u:Dictionary=sim.find_unit(id)
    if u.is_empty(): return
    selected_id=id
    game.selected_id=id
    for i in range(roster.item_count):
        if int(roster.get_item_metadata(i))==id: roster.select(i)
    info.text="%s 군단\n%s  ·  %d명\n사기 %d  /  응집 %d\n현재: %s"%[u["name"],u["type"],int(u["troops"]),int(u["morale"]),int(u["cohesion"]),u["mission"]]
    var idx:int=ACTIONS.find(str(u["mission"]))
    action_choice.select(maxi(0,idx))
    partner_choice.clear()
    partner_choice.add_item("자동 / 없음",-1)
    var assigned:int=int(u.get("assigned_link",-1))
    for other in sim.command_ids(0):
        if other==id: continue
        var friend:Dictionary=sim.find_unit(other)
        if float(friend["troops"])<=0: continue
        partner_choice.add_item(str(friend["name"])+" 군단",other)
        if other==assigned: partner_choice.select(partner_choice.item_count-1)
    has_destination=bool(u.get("has_destination",false))
    destination=u.get("order_destination",u["pos"])
    draft_dirty=false
    _update_destination()
    queue_redraw()

func _update_destination()->void:
    destination_label.text="지도 선택 대기" if not has_destination else "%s  ·  %d / %d"%[sim.terrain_at(destination),roundi(destination.x),roundi(destination.y)]

func _apply()->void:
    if not has_destination:
        feedback.text="먼저 지도에서 목적지를 지정하십시오."
        return
    var action:String=ACTIONS[action_choice.selected]
    var partner:int=partner_choice.get_selected_id()
    if sim.issue_map_order(selected_id,action,destination,partner):
        feedback.text="전령 파견 완료 · 도착까지 기존 지시 유지" if in_battle else "작전 지시 확정 · "+str(sim.find_unit(selected_id)["name"])+" / "+action
        draft_dirty=false
        queue_redraw()
    else: feedback.text="지시 불가 · 전령 허용 턴, 부대 상태 또는 기존 전령 확인"

func _launch()->void:
    if draft_dirty:
        feedback.text="미확정 지시가 있습니다. 지시 확정 후 진행하십시오."
        return
    hide()
    if in_battle: game._return_to_battle()
    else: game._start()

func _point(p:Vector2)->Vector2:
    return MAP.position+p/sim.field_size*MAP.size

func _world(p:Vector2)->Vector2:
    return ((p-MAP.position)/MAP.size*sim.field_size).clamp(Vector2(1,1),sim.field_size-Vector2(1,1))

func _gui_input(event:InputEvent)->void:
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
            if drag_id>=0: _select(drag_id)
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
                    draft_dirty=true
                    _update_destination()
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
    draw_rect(Rect2(0,0,1280,800),Color("#211c17"))
    draw_rect(Rect2(0,0,1280,68),Color("#33291e"))
    draw_line(Vector2(12,69),Vector2(1268,69),GOLD,1.0)
    for panel in [Rect2(12,77,207,552),Rect2(1038,77,234,552),Rect2(12,630,1260,160)]:
        draw_rect(panel,Color("#30271e"))
        draw_rect(panel,Color("#796044"),false,1.2)
    if sim==null: return
    draw_rect(MAP.grow(5),Color("#816447"))
    draw_rect(MAP,PAPER)
    var rng:=RandomNumberGenerator.new()
    rng.seed=41+sim.scenario_id
    for i in range(1100):
        var p:Vector2=MAP.position+Vector2(rng.randf()*MAP.size.x,rng.randf()*MAP.size.y)
        draw_line(p,p+Vector2(rng.randf_range(1,5),rng.randf_range(-1,1)),Color(0.30,0.22,0.10,rng.randf_range(0.025,0.11)),1)
    for lane in range(3):
        var line:=PackedVector2Array()
        for x in range(0,int(sim.field_size.x)+1,35): line.append(_point(Vector2(x,sim.road_y(float(x),lane))))
        draw_polyline(line,Color("#a48a61"),3.1,true)
        draw_polyline(line,Color("#eee0b9"),1.0,true)
    var river:=PackedVector2Array()
    for y in range(0,int(sim.field_size.y)+1,16): river.append(_point(Vector2(sim.river_x(float(y)),float(y))))
    draw_polyline(river,Color("#6c8c8c"),17,true)
    draw_polyline(river,Color("#a8b7ad"),9,true)
    for y in [390.0,850.0,1300.0]:
        var p:Vector2=_point(Vector2(sim.river_x(y),y))
        draw_rect(Rect2(p-Vector2(13,8),Vector2(26,16)),Color("#a88a57"))
        for x in range(-12,13,4): draw_line(p+Vector2(x,-8),p+Vector2(x,8),INK,0.8)
    for forest in sim.forests:
        var area:Rect2=forest
        for i in range(27):
            var p:Vector2=_point(area.position+Vector2(rng.randf()*area.size.x,rng.randf()*area.size.y))
            var h:float=rng.randf_range(5,11)
            draw_polyline(PackedVector2Array([p+Vector2(-h*0.5,0),p+Vector2(0,-h),p+Vector2(h*0.5,0),p+Vector2(-h*0.5,0)]),Color("#626d49"),1.2,true)
            draw_line(p,p+Vector2(0,3),INK,1)
    var hill:Rect2=sim.hill
    for i in range(10):
        var p:Vector2=_point(hill.position+Vector2(rng.randf()*hill.size.x,rng.randf()*hill.size.y))
        draw_polyline(PackedVector2Array([p+Vector2(-15,7),p+Vector2(-6,-6),p+Vector2(1,-17),p+Vector2(10,-1),p+Vector2(18,7)]),Color("#817055"),1.7,true)
        draw_line(p+Vector2(1,-17),p+Vector2(1,6),Color("#a48c66"),1)
    draw_rect(Rect2(MAP.position,Vector2(MAP.size.x*0.30,MAP.size.y)),Color(0.20,0.35,0.45,0.05))
    for site in sim.outposts:
        var p:Vector2=_point(site["pos"])
        draw_circle(p,7,Color("#b79553"))
        draw_circle(p,7,INK,false,1.5,true)
        _ink(str(site["name"]),p+Vector2(-25,-12),13,INK)
    for b in sim.bases:
        if int(b["side"])!=0 and game.fog_enabled and not sim.player_can_see(b["pos"]): continue
        var p:Vector2=_point(b["pos"])
        draw_rect(Rect2(p-Vector2(8,8),Vector2(16,16)),INK,false,2)
        _ink("군량",p+Vector2(-12,-11),12,INK)
    for u in sim.units:
        if float(u["troops"])<=0: continue
        if int(u["side"])!=0 and game.fog_enabled and not sim.player_can_see(u["pos"]): continue
        var p:Vector2=_point(u["pos"])
        if int(u["side"])==0 and bool(u.get("has_destination",false)):
            _arrow(p,_point(u["order_destination"]),BLUE,2.0)
        if int(u["side"])==0:
            var partner:Dictionary=sim.find_unit(int(u.get("assigned_link",-1)))
            if not partner.is_empty(): _dashed(p,_point(partner["pos"]),Color("#79658d"))
    if has_destination:
        var u:Dictionary=sim.find_unit(selected_id)
        if not u.is_empty(): _arrow(_point(u["pos"]),_point(destination),Color("#ab7625"),3.0)
        draw_circle(_point(destination),12,Color("#ab7625"),false,2,true)
        draw_circle(_point(destination),3,Color("#ab7625"))
    for u in sim.units:
        if float(u["troops"])<=0: continue
        if int(u["side"])!=0 and game.fog_enabled and not sim.player_can_see(u["pos"]): continue
        _piece(u,_point(u["pos"]),int(u["id"])==selected_id)
    if dragging and drag_id>=0 and MAP.has_point(drag_position):
        var u:Dictionary=sim.find_unit(drag_id)
        if not u.is_empty(): _piece(u,drag_position,true)
    _ink("北",MAP.position+Vector2(775,30),17,INK)
    draw_line(MAP.position+Vector2(783,40),MAP.position+Vector2(783,64),INK,2)
    _ink("한중 방면  /  군사지도",MAP.position+Vector2(14,25),14,INK)

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

func _piece(u:Dictionary,p:Vector2,selected:bool)->void:
    var c:Color=BLUE if int(u["side"])==0 else RED
    draw_circle(p+Vector2(2,4),16,Color(0.2,0.12,0.06,0.24))
    draw_circle(p,15,Color("#9a7951"))
    draw_circle(p,12,c)
    draw_circle(p,15,Color("#f0d89d") if selected else INK,false,2.5,true)
    draw_line(p+Vector2(-4,0),p+Vector2(-4,-24),INK,2)
    draw_colored_polygon(PackedVector2Array([p+Vector2(-3,-24),p+Vector2(14,-21),p+Vector2(11,-9),p+Vector2(-3,-12)]),c)
    _ink("蜀" if int(u["side"])==0 else "魏",p+Vector2(0,-13),10,Color("#f2e6c7"))
    var t:String=str(u["name"])
    _ink(t,p+Vector2(-15,29),14,INK)
