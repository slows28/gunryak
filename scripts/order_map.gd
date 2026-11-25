extends Control
## Separate paper war-room: actual battle coordinates, independent rendering and input.
const ACTIONS: Array[String]=["지정 위치 이동","공격","지역 사수","전열 엄호","측후방 기동","구원 지원","예비 대기","철수"]
const PAPER=Color("#d6c29a")
const INK=Color("#554735")
const GOLD=Color("#d5b473")
const BLUE=Color("#315b79")
const RED=Color("#934e3e")
const MAP=Rect2(226,90,804,510)
const ART=preload("res://assets/art/fieldcraft.svg")
const PARCHMENT=preload("res://assets/art/war_parchment.svg")
const PORTRAITS=preload("res://assets/art/painted_atlas.webp")
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
    roster.add_theme_constant_override("v_separation",8)
    roster.fixed_icon_size=Vector2i(38,38)
    roster.add_theme_stylebox_override("panel",_panel_style("#1e201d","#77603d"))
    roster.add_theme_stylebox_override("selected",_panel_style("#50402c","#e4bd6b"))
    roster.add_theme_stylebox_override("selected_focus",_panel_style("#50402c","#e4bd6b"))
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
    info=_label("",Vector2(1111,125),Vector2(155,103),13,Color("#eadbc1"))
    info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _label("① 행동",Vector2(1048,235),Vector2(216,24),14,GOLD)
    action_choice=_choice(Vector2(1046,265),Vector2(218,39),ACTIONS)
    action_choice.item_selected.connect(func(_i: int):
        draft_dirty=true
        queue_redraw())
    _label("② 목적지 · 지도에서 지정",Vector2(1048,320),Vector2(220,25),14,GOLD)
    destination_label=_label("",Vector2(1048,350),Vector2(220,52),15,Color("#eadbc1"))
    destination_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _label("③ 협동 대상",Vector2(1048,415),Vector2(216,25),14,GOLD)
    partner_choice=_choice(Vector2(1046,447),Vector2(218,39),[])
    partner_choice.item_selected.connect(func(_i: int):
        draft_dirty=true
        queue_redraw())
    apply=_button("지시 확정",Vector2(1046,510),Vector2(218,45),_apply)
    _button("미확정 취소",Vector2(1046,558),Vector2(218,31),func():
        draft_dirty=false
        _select(selected_id))
    _label("진형·교전은 장수의 현장 판단",Vector2(1048,593),Vector2(218,32),13,Color("#c4b69e")).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    feedback=_label("",Vector2(25,637),Vector2(920,58),17,GOLD)
    feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _button("상세 편성",Vector2(22,721),Vector2(170,54),func(): game.call("_open_planning"))
    _button("메뉴",Vector2(205,721),Vector2(116,54),func():
        hide()
        game.call("_show_title"))
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
    b.add_theme_stylebox_override("normal",_panel_style("#2b2a24","#957b4b"))
    b.add_theme_stylebox_override("hover",_panel_style("#51432c","#e7c77d"))
    b.add_theme_stylebox_override("pressed",_panel_style("#655135","#f1d79b"))
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
        var portrait: AtlasTexture=_portrait(str(u["name"]))
        roster.add_item("%s  %d명\n%s"%[u["name"],int(u["troops"]),u["type"]],portrait)
        roster.set_item_metadata(roster.item_count-1,id)
    feedback.text="부대 말을 끌거나 지도에 목적지를 찍고 행동 및 연계 대상을 지정하십시오."
    if mid_battle: feedback.text="전투 중 명령은 6턴부터 전령으로 전달됩니다. 확정 전까지 기존 작전 유지."
    draft_dirty=false
    _select(game.selected_id)
    show()
    game.move_child(self,game.get_child_count()-1)
    queue_redraw()

func _select(id:int)->void:
    var u:Dictionary=sim.find_unit(id)
    if u.is_empty(): return
    if draft_dirty and selected_id==id: return
    if draft_dirty and selected_id!=id:
        feedback.text="현재 부대의 미확정 지시를 먼저 확정하거나 취소하십시오."
        for i in range(roster.item_count):
            if int(roster.get_item_metadata(i))==selected_id: roster.select(i)
        return
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
    var assigned:int=int(u.get("assigned_link",-1))
    for other in sim.command_ids(0):
        if other==id: continue
        var friend:Dictionary=sim.find_unit(other)
        if float(friend["troops"])<=0: continue
        partner_choice.add_item(str(friend["name"])+" 군단")
        partner_choice.set_item_metadata(partner_choice.item_count-1,other)
        if other==assigned: partner_choice.select(partner_choice.item_count-1)
    has_destination=bool(u.get("has_destination",false))
    destination=u.get("order_destination",u["pos"]) if has_destination else u["pos"]
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
    var partner:int=int(partner_choice.get_item_metadata(partner_choice.selected))
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
    if in_battle: game.call("_return_to_battle")
    else: game.call("_start")

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
    draw_rect(Rect2(0,0,1280,800),Color("#171915"))
    draw_rect(Rect2(0,0,1280,68),Color("#25231c"))
    for i in range(6):
        draw_line(Vector2(0,65+i),Vector2(1280,65+i),Color(0.8,0.62,0.32,0.16-float(i)*0.018),1.0)
    draw_line(Vector2(12,69),Vector2(1268,69),GOLD,1.0)
    for panel in [Rect2(12,77,207,552),Rect2(1038,77,234,552),Rect2(12,630,1260,160)]:
        _frame(panel)
    if sim==null: return
    draw_rect(MAP.grow(6),Color("#49341e"))
    draw_texture_rect(PARCHMENT,MAP,false)
    draw_rect(MAP.grow(2),Color("#d0af70"),false,1.5)
    _scroll_rod(MAP.position.x-3.0)
    _scroll_rod(MAP.end.x+3.0)
    for band in range(10):
        draw_rect(MAP.grow(-float(band)*2.4),Color(0.32,0.20,0.08,0.028),false,3.0)
    for i in range(6):
        var fold_x:float=MAP.position.x+MAP.size.x*(float(i)+0.5)/6.0
        draw_line(Vector2(fold_x,MAP.position.y),Vector2(fold_x+1,MAP.end.y),Color(0.38,0.27,0.14,0.045),1.0)
    var rng:=RandomNumberGenerator.new()
    rng.seed=41+sim.scenario_id
    for i in range(100):
        var p:Vector2=MAP.position+Vector2(rng.randf()*MAP.size.x,rng.randf()*MAP.size.y)
        draw_line(p,p+Vector2(rng.randf_range(1,5),rng.randf_range(-1,1)),Color(0.30,0.22,0.10,rng.randf_range(0.025,0.11)),1)
    for lane in range(3):
        var line:=PackedVector2Array()
        for x in range(0,int(sim.field_size.x)+1,35): line.append(_point(Vector2(x,sim.road_y(float(x),lane))))
        draw_polyline(line,Color("#8e7654"),4.8,true)
        draw_polyline(line,Color("#e8d6ab"),2.6,true)
        draw_polyline(line,Color("#ac9165"),0.8,true)
    var river:=PackedVector2Array()
    for y in range(0,int(sim.field_size.y)+1,16): river.append(_point(Vector2(sim.river_x(float(y)),float(y))))
    draw_polyline(river,Color("#596d63"),19,true)
    draw_polyline(river,Color("#8ba49a"),14,true)
    draw_polyline(river,Color("#c4c8a9"),3,true)
    for y in [390.0,850.0,1300.0]:
        var p:Vector2=_point(Vector2(sim.river_x(y),y))
        draw_rect(Rect2(p-Vector2(13,8),Vector2(26,16)),Color("#a88a57"))
        for x in range(-12,13,4): draw_line(p+Vector2(x,-8),p+Vector2(x,8),INK,0.8)
    for forest in sim.forests:
        var area:Rect2=forest
        var center:Vector2=_point(area.get_center())
        var radius:Vector2=area.size/sim.field_size*MAP.size*0.54
        var outline:=PackedVector2Array()
        for j in range(18):
            var angle:float=TAU*float(j)/18.0
            var rough:float=0.76+rng.randf()*0.24
            outline.append(center+Vector2(cos(angle)*radius.x,sin(angle)*radius.y)*rough)
        draw_colored_polygon(outline,Color(0.34,0.38,0.20,0.15))
        for i in range(5):
            var p:Vector2=_point(area.position+Vector2(rng.randf()*area.size.x,rng.randf()*area.size.y))
            var h:float=rng.randf_range(37,70)
            _art(1,Rect2(p-Vector2(h*0.5,h*0.65),Vector2(h,h)),Color(1,1,1,0.92))
    var hill:Rect2=sim.hill
    for ring in range(3):
        var contour:=PackedVector2Array()
        var hcenter:Vector2=_point(hill.get_center())
        var hsize:Vector2=hill.size/sim.field_size*MAP.size*(0.24+ring*0.12)
        for j in range(25):
            var angle:float=TAU*float(j)/24.0
            contour.append(hcenter+Vector2(cos(angle)*hsize.x,sin(angle)*hsize.y)*(0.86+0.13*sin(angle*3.0)))
        draw_polyline(contour,Color(0.42,0.32,0.19,0.26),1.0,true)
    var hc:Vector2=_point(hill.get_center())
    _art(0,Rect2(hc-Vector2(90,92),Vector2(180,142)),Color(1,1,1,0.96))
    draw_rect(Rect2(MAP.position,Vector2(MAP.size.x*0.30,MAP.size.y)),Color(0.20,0.35,0.45,0.05))
    for site in sim.outposts:
        var p:Vector2=_point(site["pos"])
        _art(2,Rect2(p-Vector2(32,56),Vector2(64,64)))
        draw_circle(p,4,Color("#b79553"))
        draw_circle(p,5,INK,false,1.2,true)
        _plate(str(site["name"]),p+Vector2(0,15),12,Color("#dbc58d"))
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
    var u:Dictionary=sim.find_unit(selected_id)
    if not u.is_empty():
        var portrait:AtlasTexture=_portrait(str(u["name"]))
        if portrait!=null:
            draw_texture_rect(portrait,Rect2(1047,125,59,79),false)
        else:
            _art(3,Rect2(1042,125,69,79))
    _plate("이동 경로  ·  협동 대상",Vector2(337,582),12,Color("#dbc58d"))

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
    if selected:
        draw_circle(p,19,Color(0.98,0.75,0.22,0.18))
        draw_arc(p,19,0,TAU,40,Color("#edc56b"),2.2,true)
    _art(3+int(u["side"]),Rect2(p-Vector2(25,43),Vector2(50,50)))
    _plate(str(u["name"]),p+Vector2(0,12),13,Color("#f0ce84") if selected else Color("#ded2b0"))

func _art(tile:int,rect:Rect2,tint:Color=Color.WHITE)->void:
    draw_texture_rect_region(ART,rect,Rect2(float(tile%4)*256.0,float(floori(float(tile)/4.0))*256.0,256,256),tint)

func _portrait(name:String)->AtlasTexture:
    var names:Array[String]=["왕평","마속","위연","장합"]
    var idx:int=names.find(name)
    if idx<0: return null
    var tex:=AtlasTexture.new()
    tex.atlas=PORTRAITS
    var tile:int=8+idx
    tex.region=Rect2((tile%8)*128,floori(float(tile)/8.0)*128,128,128)
    return tex

func _panel_style(bg:String,border:String)->StyleBoxFlat:
    var style:=StyleBoxFlat.new()
    style.bg_color=Color(bg)
    style.border_color=Color(border)
    style.set_border_width_all(1)
    style.corner_radius_top_left=3
    style.corner_radius_top_right=3
    style.corner_radius_bottom_left=3
    style.corner_radius_bottom_right=3
    style.content_margin_left=7
    style.content_margin_right=7
    return style

func _frame(rect:Rect2)->void:
    draw_rect(rect,Color("#22231e"))
    draw_rect(rect,Color("#a38a53"),false,1.4)
    draw_rect(rect.grow(-4),Color("#594a30"),false,1.0)
    for corner in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
        var d:Vector2=Vector2(1 if corner.x==rect.position.x else -1,1 if corner.y==rect.position.y else -1)
        draw_polyline(PackedVector2Array([corner+Vector2(d.x*19,0),corner+Vector2(d.x*5,d.y*5),corner+Vector2(0,d.y*19)]),Color("#d0b371"),1.8,true)

func _scroll_rod(x:float)->void:
    for i in range(7):
        draw_line(Vector2(x-3+i,MAP.position.y-4),Vector2(x-3+i,MAP.end.y+4),Color("#4e3520").lerp(Color("#d7b179"),sin(float(i)/6.0*PI)),1.0)
    for y in [MAP.position.y-5,MAP.end.y+5]:
        draw_circle(Vector2(x,y),6,Color("#7b5b35"))
        draw_arc(Vector2(x,y),5,0,TAU,24,Color("#d7b179"),1.4,true)

func _plate(t:String,p:Vector2,fs:int,c:Color)->void:
    var width:float=font.get_string_size(t,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x+14.0
    var rect:=Rect2(p-Vector2(width/2.0,9),Vector2(width,18))
    draw_rect(rect,Color("#342b20"))
    draw_rect(rect,Color("#b09561"),false,1.0)
    _ink(t,p+Vector2(-width/2.0+7,5),fs,c)
