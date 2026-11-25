extends Control
## 2D tactical screen. Simulation is entirely separate in war_sim.gd.
const WarSim = preload("res://scripts/war_sim.gd")
const BattleAudio = preload("res://scripts/battle_audio.gd")
const FrontView=preload("res://scripts/front_view.gd")
const TerrainArt = preload("res://scripts/terrain_art.gd")
const Campaign = preload("res://scripts/campaign.gd")
const CampaignView = preload("res://scripts/campaign_view.gd")
const OrderMap = preload("res://scripts/order_map.gd")
const PAINTED_ART = preload("res://assets/art/painted_atlas.webp")
const SOLDIER_ART = preload("res://assets/art/soldier_sprites.svg")
const SOLDIER_MOTION = preload("res://assets/art/soldier_motion.svg")
const SCENERY_ART = preload("res://assets/art/battlefield_detail.svg")
const BRIDGE_HQ = preload("res://assets/art/bridge_hq.svg")
const GENERAL_PORTRAITS=preload("res://assets/art/general_portraits.svg")
const FIELD_SITES=preload("res://assets/art/field_sites.svg")
const PORTRAIT_NAMES=["왕평","마속","위연","강유","관흥","장익","장합","위군 궁대","위군 기병","곽회","비요","왕쌍"]
const FIELDCRAFT = preload("res://assets/art/fieldcraft.svg")
const PAINTED_FX = preload("res://assets/art/painted_fx.webp")
const TITLE_ART = preload("res://assets/art/title_art.webp")
const MAP_TOP_LEFT: Vector2 = Vector2(16, 124)
const MAP_SIZE: Vector2 = Vector2(934, 550)
const MINIMAP_AREA = Rect2(1128,609,126,80)
const COL_BG: Color = Color("#131a22")
const COL_PANEL: Color = Color("#1c2732")
const COL_LINE: Color = Color("#3d4d5a")
const COL_ACTIVE: Color = Color("#a43d2e")
const COL_TEXT: Color = Color("#eee7d2")
const COL_MUTED: Color = Color("#a6b6b4")
const COL_BLUE: Color = Color("#8ed5e7")
const COL_RED: Color = Color("#f19985")
const COL_GOLD: Color = Color("#efc878")

var sim = WarSim.new()
var korean_font: SystemFont
var selected_id: int = 0
var detailed_map: bool = false
var map_detail_button: Button
var step_buffer: float = 0.0
var ui_clock: float = 0.0
var runtime_notice: String = ""
var game_speed: float = 1.0
var ignore_options: bool = false
var status_label: Label
var battle_title_label: Label
var clock_label: Label
var turn_label: Label
var objective_label: Label
var selected_label: Label
var details_label: Label
var readiness_label: Label
var decision_label: Label
var event_label: Label
var notice_label: Label
var unit_list: ItemList
var roster_overlay: Control
var mission_choice: OptionButton
var policy_choice: OptionButton
var start_btn: Button
var pause_btn: Button
var speed_btn: Button
var apply_btn: Button
var planning_dialog: AcceptDialog
var timeline_dialog: AcceptDialog
var timeline_view: TextEdit
var plan_status: Label
var plan_scenario: OptionButton
var plan_donor: OptionButton
var plan_deputy: OptionButton
var plan_priority: OptionButton
var plan_fog: CheckButton
var plan_takeover: Button
var map_mode: String = "선택"
var fog_enabled: bool = false # Demo defaults to transparent battlefield; recon rules remain optional.
var enemy_list: ItemList
var enemy_tab: Button
var friendly_tab: Button
var fog_button: Button
var observing_enemy: bool = false
var observed_enemy_id: int = -1
var contact_button: Button
var combat_brief: Label
var mind_dialog: AcceptDialog
var mind_report: RichTextLabel
var mind_button: Button
var thought_feed: Label
var general_cards: Array[Button]=[]
var map_label_areas: Array[Rect2]=[]
var fallen_marks: Array[Dictionary]=[]
var loss_carry: Dictionary={}
var battle_warning: String=""
var sector_cards: Array[Button]=[]
var sector_snapshot: Array[Dictionary]=[]
var sector_selection: int=-1
var contact_cache: Dictionary={}
var contact_cache_step: int=-1
var formation_render_cache: Dictionary={}
var journal_button: Button
var journal_dialog: AcceptDialog
var journal_list: ItemList
var journal_events: Array[Dictionary]=[]
var journal_keys: Dictionary={}
var highlight_button: Button
var highlight_active: bool=false
var highlight_seen: Dictionary={}
var highlight_start: float=0.0
var highlight_deadline: float=0.0
var highlight_prior_speed: float=1.0
var feed_toggle: Button
var feed_heading: Label
var show_general_feed: bool=true
var battle_samples: Dictionary = {}
var recent_losses: Dictionary = {}
var sample_time: float = -100.0
var previous_centers: Dictionary = {}
var plan_actions: Array[Button] = []
var map_layer: Control
var map_clip: Control
var camera_zoom: float = 1.0
var camera_center: Vector2 = MAP_SIZE * 0.5
var visibility_texture: ImageTexture
var dust_texture: ImageTexture
var visibility_stamp: float = -100.0
var render_clock: float = 0.0
var phase_label: Label
var warning_label: Label
var brief_dialog: AcceptDialog
var brief_text: Label
var analysis_dialog: AcceptDialog
var analysis_chart: Control
var portrait: Control
var sound_player: AudioStreamPlayer
var combat_players: Array[AudioStreamPlayer] = []
var combat_sounds: Dictionary = {}
var combat_audio_cursor: int=0
var sound_enabled: bool = true
var music_player: AudioStreamPlayer
var tutorial_dialog: AcceptDialog
var retreat_dialog: ConfirmationDialog
var situation_btn: Button
var situation_dialog: AcceptDialog
var situation_list: ItemList
var situation_detail: Label
var situation_options: Array[Button] = []
var situation_ids: Array[int] = []
var situation_selected: int = -1
var situation_pause_before: bool = false
var situation_notice: String = ""
var last_audio_event: float = -1.0
var last_warning: String = ""
var last_audio_clock: float = -100.0
var finish_seen: bool = false
var title_screen: Control
var outcome_dialog: Control
var outcome_text: Label
var outcome_cards: VBoxContainer
var outcome_heading: Label
var outcome_comparison: Control
var terrain_cache: ImageTexture
var forest_instances: Array[Dictionary]=[]
var forest_textures: Array[ImageTexture]=[]
var terrain_scenario: int = -1
var terrain_variants: Dictionary = {}
var campaign_active: bool = false
var campaign = Campaign.new()
var strategy_view: Control
var order_view: Control
var order_pause_before: bool = false
var live_order_label: Label
var order_status_label: Label
var live_order_button: Button
var battle_recorded: bool = false
var chapter: int = 0
var campaign_results: Array[String] = []
var campaign_next: Button
var touch_origin: Vector2 = Vector2.ZERO
var touch_dragged: bool = false

class RenderLayer extends Control:
    var painter: Callable
    func _draw() -> void:
        if painter.is_valid():
            painter.call(self)

func _ready() -> void:
    sim.tactical_enabled = true
    sim.set_long_operation(true)
    campaign.set_six_armies(true)
    _install_korean_font()
    _build_map_layer()
    _rebuild_terrain()
    dust_texture = TerrainArt.dust_cloud()
    _reset_camera()
    _build_interface()
    _build_presentation()
    _setup_sound()
    _build_title_screen()
    _build_outcome_dialog()
    _build_demo_help()
    _build_situations()
    strategy_view = CampaignView.new()
    strategy_view.configure(campaign,korean_font,PAINTED_ART,_launch_campaign_battle,_show_title)
    add_child(strategy_view)
    strategy_view.hide()
    order_view=OrderMap.new()
    order_view.configure(self,korean_font)
    add_child(order_view)
    _refresh_unit_list()
    _select_unit()
    _refresh_hud()
    queue_redraw()

# Use a platform Korean-capable system font for both Control text and custom
# CanvasItem.draw_string(). The bundled default font has no Hangul glyphs.
# Linux CI installs fonts-nanum; Windows normally provides Malgun Gothic.
func _install_korean_font() -> void:
    korean_font = SystemFont.new()
    korean_font.font_names = PackedStringArray(["NanumGothic","Malgun Gothic","Noto Sans CJK KR","Apple SD Gothic Neo","UnDotum","Arial Unicode MS"])
    korean_font.allow_system_fallback = true
    var ui_theme := Theme.new()
    ui_theme.default_font = korean_font
    ui_theme.default_font_size = 14
    for type in ["Button","OptionButton"]:
        ui_theme.set_color("font_color",type,COL_TEXT)
        ui_theme.set_color("font_hover_color",type,Color("#ffffff"))
        ui_theme.set_color("font_pressed_color",type,Color("#ffffff"))
        ui_theme.set_color("font_disabled_color",type,Color("#91a0a9"))
        ui_theme.set_stylebox("normal",type,_ui_box(Color("#293644")))
        ui_theme.set_stylebox("hover",type,_ui_box(Color("#394b5b")))
        ui_theme.set_stylebox("pressed",type,_ui_box(Color("#415968"),COL_BLUE))
        ui_theme.set_stylebox("hover_pressed",type,_ui_box(Color("#415968"),COL_BLUE))
        ui_theme.set_stylebox("disabled",type,_ui_box(Color("#202a34")))
        ui_theme.set_stylebox("focus",type,_ui_box(Color.TRANSPARENT,COL_GOLD))
    ui_theme.set_stylebox("panel","ItemList",_ui_box(Color("#16212b")))
    var selected := _ui_box(Color("#304b59"))
    selected.border_color=COL_BLUE
    selected.border_width_left=3
    ui_theme.set_stylebox("selected","ItemList",selected)
    ui_theme.set_stylebox("selected_focus","ItemList",selected)
    ui_theme.set_color("font_color","ItemList",COL_TEXT)
    ui_theme.set_constant("v_separation","ItemList",5)
    var dialog := _ui_box(Color("#1c2732"),COL_LINE)
    dialog.content_margin_left=16
    dialog.content_margin_right=16
    dialog.content_margin_top=14
    dialog.content_margin_bottom=14
    ui_theme.set_stylebox("panel","AcceptDialog",dialog)
    var window_frame: StyleBoxFlat=dialog.duplicate()
    window_frame.expand_margin_top=33
    ui_theme.set_stylebox("embedded_border","Window",window_frame)
    ui_theme.set_stylebox("embedded_unfocused_border","Window",window_frame)
    theme = ui_theme

func _ui_box(background: Color, border: Color=Color.TRANSPARENT) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color=background
    style.border_color=border
    if border!=Color.TRANSPARENT: style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    style.content_margin_left=9
    style.content_margin_right=9
    style.content_margin_top=3
    style.content_margin_bottom=3
    return style

func _build_interface() -> void:
    _button("軍略",Vector2(16,10),Vector2(78,37),_show_title).add_theme_font_size_override("font_size",24)
    battle_title_label = _label("",Vector2(111,5),Vector2(260,29),24,COL_TEXT)
    phase_label = _label("",Vector2(112,34),Vector2(258,17),12,COL_MUTED)
    phase_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    clock_label = _label("",Vector2(383,2),Vector2(102,32),26,COL_GOLD)
    turn_label = _label("",Vector2(384,35),Vector2(102,16),11,COL_MUTED)
    start_btn = _button("출전",Vector2(488,11),Vector2(92,35),_start)
    _primary_button(start_btn)
    pause_btn = _button("일시정지",Vector2(488,11),Vector2(92,35),_pause)
    speed_btn = _button("속도 ×1",Vector2(588,11),Vector2(78,35),_speed)
    status_label = _label("",Vector2(968,7),Vector2(290,40),13,COL_TEXT)
    status_label.clip_text=true
    objective_label = _label("",Vector2(16,104),Vector2(934,18),13,COL_TEXT)
    objective_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    _label("지휘 본부",Vector2(970,69),Vector2(156,32),23,COL_TEXT)
    friendly_tab=_button("아군 6",Vector2(970,108),Vector2(91,28),_show_friendly_roster)
    enemy_tab=_button("적군 6",Vector2(1067,108),Vector2(91,28),_show_enemy_roster)
    fog_button=_button("전체 시야",Vector2(1164,108),Vector2(92,28),func(): _toggle_fog(not fog_enabled))
    friendly_tab.toggle_mode=true
    enemy_tab.toggle_mode=true
    fog_button.toggle_mode=true
    fog_button.tooltip_text="전체 관전과 정찰 제한 전환 · V"
    unit_list = ItemList.new()
    unit_list.position = Vector2(970,143)
    unit_list.size = Vector2(286,181)
    unit_list.add_theme_font_size_override("font_size",14)
    unit_list.add_theme_constant_override("v_separation",3)
    add_child(unit_list)
    unit_list.item_selected.connect(_on_unit_selected)
    roster_overlay=RenderLayer.new()
    roster_overlay.position=unit_list.position
    roster_overlay.size=unit_list.size
    roster_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
    roster_overlay.painter=_draw_roster_status
    add_child(roster_overlay)
    enemy_list=ItemList.new()
    enemy_list.position=unit_list.position
    enemy_list.size=unit_list.size
    enemy_list.add_theme_font_size_override("font_size",13)
    enemy_list.fixed_icon_size=Vector2i(23,23)
    enemy_list.add_theme_constant_override("v_separation",5)
    add_child(enemy_list)
    enemy_list.item_selected.connect(_inspect_enemy_row)
    enemy_list.hide()
    _label("작전 명령",Vector2(973,467),Vector2(280,21),15,COL_MUTED)
    mission_choice = _options(Vector2(970,482),["중앙 진격","북측 확보","남측 우회","본진 방어","전열 엄호","측후방 기동","구원 지원"])
    mission_choice.item_selected.connect(_on_choices_changed)
    mission_choice.hide()
    live_order_label = _label("",Vector2(973,487),Vector2(280,43),13,COL_TEXT)
    live_order_label.clip_text=true
    live_order_label.add_theme_constant_override("line_spacing",0)
    live_order_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    order_status_label = _label("",Vector2(973,530),Vector2(280,20),13,COL_GOLD)
    order_status_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    policy_choice = _options(Vector2(970,520),["현장 판단","명령 엄수","재량 위임","횡대 유지","종대 유지","방진 유지","어린진 유지","학익진 유지","봉시진 유지","안행진 유지"])
    policy_choice.item_selected.connect(_on_choices_changed)
    policy_choice.hide()
    apply_btn = _button("작전 적용 / 전령 보내기",Vector2(970,554),Vector2(286,40),_apply_order)
    apply_btn.hide()
    live_order_button=_button("작전 지도 열기",Vector2(970,554),Vector2(286,40),_open_order_map)
    _primary_button(live_order_button)
    live_order_button.add_theme_font_size_override("font_size",16)
    mind_button=_button("장수 보고",Vector2(1144,70),Vector2(112,28),_open_mind_report)
    mind_button.tooltip_text="전체 장수의 심리와 최근 명령 · G"
    selected_label = _label("",Vector2(1048,340),Vector2(198,26),19,COL_TEXT)
    selected_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    details_label = _label("",Vector2(1048,370),Vector2(198,19),13,COL_TEXT)
    readiness_label = _label("",Vector2(1048,391),Vector2(198,19),13,COL_TEXT)
    readiness_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    decision_label=_label("",Vector2(974,416),Vector2(272,43),13,COL_TEXT)
    decision_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    decision_label.clip_text=true
    decision_label.max_lines_visible=2
    feed_toggle=_button("전황 기록 보기",Vector2(1128,697),Vector2(136,24),_toggle_feed)
    feed_toggle.add_theme_font_size_override("font_size",12)
    event_label = _label("",Vector2(26,744),Vector2(1228,53),13,COL_TEXT)
    event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    notice_label = _label("",Vector2(16,675),Vector2(930,21),13,COL_MUTED)
    notice_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    highlight_button=_button("다음 주요 상황 ▶",Vector2(674,11),Vector2(128,35),_advance_highlight)
    highlight_button.tooltip_text="새 교전·위기·거점 변화·긴급 보고까지 진행"
    journal_button=_button("상황 기록",Vector2(810,11),Vector2(128,35),_open_journal)
    journal_button.tooltip_text="관측한 교전·위기의 당시 위치를 확인 · J"
    journal_dialog=AcceptDialog.new()
    journal_dialog.title="작전 상황 기록 · 항목 더블클릭으로 위치 확인"
    journal_dialog.ok_button_text="닫기"
    add_child(journal_dialog)
    journal_list=ItemList.new()
    journal_list.custom_minimum_size=Vector2(575,305)
    journal_list.add_theme_font_size_override("font_size",15)
    journal_list.add_theme_constant_override("v_separation",9)
    journal_list.item_activated.connect(_visit_journal_event)
    journal_dialog.add_child(journal_list)
    map_detail_button = _button("전술 표시 · 간결",Vector2(178,632),Vector2(130,32),_toggle_map_detail)
    map_detail_button.tooltip_text = "군단 진형과 전술 이동 경로 표시 전환"
    _build_planning_dialog()
    _build_mind_report()
    _button("브리핑",Vector2(970,609),Vector2(70,34),_open_briefing)
    _button("도움말",Vector2(1048,609),Vector2(70,34),_open_demo_help)
    _button("초기화",Vector2(970,651),Vector2(70,34),_reset)
    _button("철수",Vector2(1048,651),Vector2(70,34),_ask_retreat)
    contact_button=_button("최근 교전",Vector2(316,632),Vector2(94,32),_focus_combat)
    contact_button.tooltip_text="최근 관측된 교전으로 이동 · C"
    feed_heading=_label("아군 장수",Vector2(16,698),Vector2(180,22),15,COL_TEXT)
    combat_brief=_label("",Vector2(26,722),Vector2(1228,24),15,COL_GOLD)
    thought_feed=_label("",Vector2(26,747),Vector2(1228,46),12,COL_TEXT)
    thought_feed.hide()
    event_label.hide()
    for i in range(6):
        var card: Button=_button("",Vector2(16+i*209,730),Vector2(201,61),_select_general_card.bind(i))
        card.add_theme_font_size_override("font_size",13)
        card.expand_icon=true
        card.toggle_mode=true
        card.add_theme_constant_override("icon_max_width",39)
        card.add_theme_constant_override("h_separation",6)
        card.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
        card.alignment=HORIZONTAL_ALIGNMENT_LEFT
        general_cards.append(card)
    combat_brief.hide()
    _build_sector_board()
    situation_btn = _button("긴급 보고",Vector2(830,61),Vector2(120,40),func():
        _open_order_map()
        _open_situations())
    _primary_button(situation_btn)
    warning_label = _label("",Vector2(420,640),Vector2(513,24),12,COL_GOLD)
    warning_label.hide()
    warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _label(message: String, where: Vector2, extent: Vector2, font_size: int, color: Color) -> Label:
    var element := Label.new()
    element.text = message
    element.position = where
    element.size = extent
    element.add_theme_font_size_override("font_size", font_size)
    element.add_theme_color_override("font_color", color)
    add_child(element)
    return element

func _button(message: String, where: Vector2, extent: Vector2, handler: Callable) -> Button:
    var element := Button.new()
    element.text = message
    element.position = where
    element.size = extent
    element.add_theme_font_size_override("font_size", 14)
    add_child(element)
    element.pressed.connect(handler)
    return element

func _options(where: Vector2, choices: Array[String]) -> OptionButton:
    var element := OptionButton.new()
    element.position = where
    element.size = Vector2(295, 36)
    element.add_theme_font_size_override("font_size", 14)
    for choice in choices:
        element.add_item(choice)
    add_child(element)
    return element

func _refresh_unit_list() -> void:
    unit_list.clear()
    for i in sim.command_ids(0):
        var unit: Dictionary = sim.find_unit(i)
        var icon:AtlasTexture=_commander_icon(str(unit["name"]),int(unit["side"]))
        unit_list.add_item("%s  ·  %s / %s" % [str(unit["name"]),str(unit["type"]),str(unit["personality"])],icon)
        unit_list.set_item_metadata(unit_list.item_count-1,i)
    unit_list.fixed_icon_size = Vector2i(25,25)
    if unit_list.item_count > 0:
        var row: int = maxi(0,sim.command_ids(0).find(selected_id))
        unit_list.select(row)
        selected_id = int(unit_list.get_item_metadata(row))

func _draw_roster_status(canvas: Control) -> void:
    if not is_instance_valid(unit_list): return
    for index in range(unit_list.item_count):
        var uid: int=int(unit_list.get_item_metadata(index))
        var unit: Dictionary=sim.find_unit(uid)
        if unit.is_empty(): continue
        var row: Rect2=unit_list.get_item_rect(index)
        if row.end.y>canvas.size.y+1.0 or row.position.y<0.0: continue
        var strength: float=clampf(float(unit["troops"])/maxf(1.0,float(unit["initial_troops"])),0.0,1.0)
        var morale: float=clampf(float(unit["morale"])/100.0,0.0,1.0)
        var shade: Color=COL_RED if bool(unit["routed"]) else COL_BLUE
        var mind: Dictionary=unit.get("mind",{})
        var right: float=canvas.size.x-12.0
        var label: String=_number_text(roundi(sim.corps_report(uid)["troops"]))+"명"
        var w: float=korean_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
        canvas.draw_string(korean_font,Vector2(right-w,row.position.y+14),label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,COL_TEXT)
        var bar: Rect2=Rect2(right-64,row.position.y+19,64,3)
        canvas.draw_rect(bar,Color("#121915"))
        canvas.draw_rect(Rect2(bar.position,Vector2(bar.size.x*strength,bar.size.y)),shade)
        canvas.draw_rect(Rect2(bar.position+Vector2(0,5),Vector2(bar.size.x,2)),Color("#121915"))
        canvas.draw_rect(Rect2(bar.position+Vector2(0,5),Vector2(bar.size.x*morale,2)),COL_GOLD)
        var mood: String=str(mind.get("mood","준비"))
        canvas.draw_string(korean_font,Vector2(right-126,row.position.y+26),mood,HORIZONTAL_ALIGNMENT_LEFT,-1,10,_mood_color(mood))
        if index<unit_list.item_count-1:
            canvas.draw_line(Vector2(6,row.end.y+1),Vector2(canvas.size.x-6,row.end.y+1),Color(0.70,0.59,0.40,0.16),1.0)

func _show_friendly_roster() -> void:
    observing_enemy=false
    observed_enemy_id=-1
    unit_list.show()
    roster_overlay.show()
    enemy_list.hide()
    _refresh_hud()
    map_layer.queue_redraw()

func _show_enemy_roster() -> void:
    observing_enemy=true
    unit_list.hide()
    roster_overlay.hide()
    enemy_list.show()
    _refresh_hud()
    map_layer.queue_redraw()

func _inspect_enemy_row(index: int) -> void:
    if index<0 or index>=enemy_list.item_count or enemy_list.is_item_disabled(index): return
    var id: int=int(enemy_list.get_item_metadata(index))
    var u: Dictionary=sim.find_unit(id)
    if u.is_empty() or not _visible_unit(u): return
    observed_enemy_id=id
    camera_center=u["pos"]
    camera_zoom=maxf(1.0,camera_zoom)
    _clamp_camera()
    _refresh_hud()
    map_layer.queue_redraw()

func _refresh_enemy_roster() -> void:
    if not is_instance_valid(enemy_list): return
    var visible_ids: Array[int]=[]
    for id in sim.command_ids(1):
        var u: Dictionary=sim.find_unit(id)
        if not u.is_empty() and _visible_unit(u): visible_ids.append(id)
    var rebuild: bool=enemy_list.item_count!=maxi(1,visible_ids.size())
    if not rebuild and visible_ids.is_empty(): rebuild=enemy_list.get_item_metadata(0)!=-1
    if not rebuild and not visible_ids.is_empty():
        for i in range(visible_ids.size()):
            if enemy_list.get_item_metadata(i)!=visible_ids[i]:
                rebuild=true
                break
    if rebuild:
        enemy_list.clear()
        if visible_ids.is_empty():
            enemy_list.add_item("관측된 적군 없음")
            enemy_list.set_item_disabled(0,true)
            enemy_list.set_item_metadata(0,-1)
        else:
            for id in visible_ids:
                var leader: Dictionary=sim.find_unit(id)
                enemy_list.add_item("",_commander_icon(str(leader["name"]),1))
                enemy_list.set_item_metadata(enemy_list.item_count-1,id)
    for i in range(visible_ids.size()):
        var u: Dictionary=sim.find_unit(visible_ids[i])
        enemy_list.set_item_text(i,"%s   %s   %s명" % [str(u["name"]),_field_action(u),_number_text(roundi(float(u["troops"])))])
        enemy_list.set_item_custom_fg_color(i,COL_RED)
        enemy_list.set_item_tooltip(i,"%s · 사기 %d · 응집 %d" % [str(u["type"]),roundi(float(u["morale"])),roundi(float(u["cohesion"]))])
        if visible_ids[i]==observed_enemy_id: enemy_list.select(i)
    if not visible_ids.has(observed_enemy_id):
        observed_enemy_id=-1
        enemy_list.deselect_all()
    enemy_tab.text="적군 %d" % visible_ids.size()
    friendly_tab.set_pressed_no_signal(not observing_enemy)
    enemy_tab.set_pressed_no_signal(observing_enemy)
    fog_button.set_pressed_no_signal(fog_enabled)
    fog_button.text="정찰 시야" if fog_enabled else "전체 시야"

# Actual activity takes priority over the strategic mission or inferred intent.
func _field_action(u: Dictionary) -> String:
    if float(u["troops"])<=0.0: return "전멸"
    if bool(u["routed"]): return "패주"
    if sim.started and not sim.finished:
        var age: float=sim.battle_time-float(u.get("last_visual",-100.0))
        if age>=0.0 and age<0.95:
            if str(u["type"])=="궁병": return "사격 중"
            return "교전 중"
        if str(u.get("next_formation",""))!="": return "전열 변경"
        if float(u.get("motion_speed",0.0))>2.0 and float(u.get("bridge_y",-1.0))>=0.0: return "도하 기동"
    return str(u["action"])

# A combat camera must also inspect the friendly commander actually involved,
# rather than leaving an unrelated general's information on screen.
func _select_friendly_combatant(fx:Dictionary) -> void:
    var ids:Array[int]=sim.command_ids(0)
    for key in ["attacker_id","defender_id"]:
        var id:int=int(fx.get(key,-1))
        if not ids.has(id): continue
        selected_id=id
        _show_friendly_roster()
        unit_list.select(ids.find(id))
        _select_unit()
        return

func _focus_combat() -> void:
    for i in range(sim.visual_effects.size()-1,-1,-1):
        var fx: Dictionary=sim.visual_effects[i]
        if sim.battle_time-float(fx["time"])>0.9: continue
        var origin:Vector2=fx.get("visual_from",fx["from"])
        var target:Vector2=fx.get("visual_to",fx["to"])
        var origin_visible:bool=not fog_enabled or sim.player_can_see(origin)
        var target_visible:bool=not fog_enabled or sim.player_can_see(target)
        if not origin_visible and not target_visible: continue
        _select_friendly_combatant(fx)
        camera_center=origin.lerp(target,0.5) if origin_visible and target_visible else (origin if origin_visible else target)
        camera_zoom=1.8
        _clamp_camera()
        map_layer.queue_redraw()
        queue_redraw()
        return
    runtime_notice="아직 관측된 교전이 없습니다."
    _refresh_hud()

func _on_unit_selected(index: int) -> void:
    if index < 0 or index >= unit_list.item_count: return
    selected_id = int(unit_list.get_item_metadata(index))
    _show_friendly_roster()
    _select_unit()

func _select_unit() -> void:
    var unit: Dictionary = sim.find_unit(selected_id)
    if unit.is_empty():
        return
    ignore_options = true
    for i in range(mission_choice.item_count):
        if mission_choice.get_item_text(i) == str(unit["mission"]):
            mission_choice.select(i)
            break
    for i in range(policy_choice.item_count):
        if policy_choice.get_item_text(i) == str(unit["policy"]):
            policy_choice.select(i)
            break
    ignore_options = false
    _refresh_hud()

func _on_choices_changed(_index: int) -> void:
    if ignore_options:
        return
    _refresh_hud()

func _apply_order() -> void:
    var mission: String = mission_choice.get_item_text(mission_choice.selected)
    var policy: String = policy_choice.get_item_text(policy_choice.selected)
    if not sim.started:
        runtime_notice = "사전 작전 반영 완료" if sim.select_unit_mission(selected_id, mission, policy,int(sim.find_unit(selected_id).get("assigned_link",-1))) else "작전 설정 불가"
    elif sim.turn >= 6:
        runtime_notice = "전령 출발 · 도착 전까지 기존 명령 유지" if sim.request_order(selected_id, mission, policy,int(sim.find_unit(selected_id).get("assigned_link",-1))) else "파견 불가 · 기존 전령 또는 부대 상태 확인"
    _select_unit()
    _refresh_hud()
    queue_redraw()

func _start() -> void:
    if highlight_active: _stop_highlight("출전 준비",false)
    if is_instance_valid(title_screen):
        title_screen.hide()
    if is_instance_valid(order_view):
        order_view.drafts.clear()
        order_view.draft_dirty=false
        order_view.hide()
    battle_samples.clear()
    recent_losses.clear()
    fallen_marks.clear()
    loss_carry.clear()
    battle_warning=""
    previous_centers.clear()
    contact_cache.clear()
    formation_render_cache.clear()
    contact_cache_step=-1
    _clear_journal()
    sector_selection=-1
    sample_time=-100.0
    _show_friendly_roster()
    map_mode = "선택"
    runtime_notice = ""
    sim.start()
    var row: int=sim.command_ids(0).find(selected_id)
    if row>=0: unit_list.select(row)
    _select_unit()
    _refresh_hud()

# Optional FM-like highlight progression. No time jumps, no skipped fixed steps.
func _advance_highlight() -> void:
    if not sim.started or sim.finished: return
    if highlight_active:
        _stop_highlight("하이라이트 중지",true)
        return
    if order_view.visible or planning_dialog.visible or situation_dialog.visible: return
    highlight_seen=FrontView.milestones(sim,fog_enabled)
    highlight_start=sim.battle_time
    highlight_deadline=sim.battle_time+90.0/sim.operation_scale()
    highlight_prior_speed=game_speed
    highlight_active=true
    game_speed=16.0
    sim.paused=false
    runtime_notice="실제 전투 진행 중 · 다음 주요 상황 탐색"
    speed_btn.text="속도 ×16"
    _refresh_hud()

func _poll_highlight() -> void:
    if not highlight_active: return
    if sim.finished:
        _stop_highlight("전투 종료",false)
        return
    if sim.battle_time-highlight_start<1.0/sim.operation_scale(): return
    var current: Dictionary=FrontView.milestones(sim,fog_enabled)
    for key in current:
        if highlight_seen.has(key): continue
        var event: Dictionary=current[key]
        _frame_milestone(event)
        _stop_highlight(str(event["label"]),true)
        return
    if sim.battle_time>=highlight_deadline:
        _stop_highlight("90초 진행 · 새 주요 사건 없음",true)

func _stop_highlight(message: String,pause_after: bool) -> void:
    if not highlight_active: return
    highlight_active=false
    highlight_seen.clear()
    game_speed=highlight_prior_speed
    step_buffer=0.0
    render_clock=sim.battle_time
    if pause_after and not sim.finished: sim.paused=true
    runtime_notice=message
    speed_btn.text="속도 ×%s" % str(game_speed)
    _refresh_hud()
    map_layer.queue_redraw()
    queue_redraw()

func _pause() -> void:
    if not sim.started or sim.finished:
        return
    if highlight_active:
        _stop_highlight("하이라이트 중지",true)
        return
    sim.paused = not sim.paused
    _refresh_hud()

func _speed() -> void:
    if highlight_active: _stop_highlight("일반 속도로 복귀",false)
    if game_speed == 0.5:
        game_speed = 1.0
    elif game_speed == 1.0:
        game_speed = 2.0
    elif game_speed == 2.0:
        game_speed = 4.0
    else:
        game_speed = 0.5
    speed_btn.text = "속도 ×%s" % str(game_speed)

func _reset() -> void:
    if campaign_active and int(campaign.state["pending"]) >= 0:
        runtime_notice = "캠페인 전투 중에는 초기화할 수 없습니다."
        _refresh_hud()
        return
    if highlight_active: _stop_highlight("초기화",false)
    sim.reset()
    battle_samples.clear()
    recent_losses.clear()
    fallen_marks.clear()
    loss_carry.clear()
    battle_warning=""
    previous_centers.clear()
    contact_cache.clear()
    formation_render_cache.clear()
    contact_cache_step=-1
    _clear_journal()
    sector_selection=-1
    sample_time=-100.0
    _show_friendly_roster()
    _rebuild_terrain()
    _reset_camera()
    finish_seen = false
    last_audio_event = -1.0
    last_warning = ""
    map_mode = "선택"
    selected_id = 0
    step_buffer = 0.0
    runtime_notice = ""
    _refresh_unit_list()
    _select_unit()
    _refresh_hud()
    queue_redraw()
    if is_instance_valid(title_screen) and not title_screen.visible:
        if order_view.visible: order_view.hide()
        _open_order_map()

func _commander_forward() -> void:
    sim.reposition_commander(true)
    _refresh_hud()

func _commander_back() -> void:
    sim.reposition_commander(false)
    _refresh_hud()

func _process(delta: float) -> void:
    if sim.started and not sim.paused and not sim.finished:
        render_clock = sim.battle_time + step_buffer
    if is_instance_valid(title_screen) and not title_screen.visible and (not is_instance_valid(strategy_view) or not strategy_view.visible) and not sim.finished:
        if not planning_dialog.visible and not brief_dialog.visible and not situation_dialog.visible and not mind_dialog.visible:
            var pan := Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
            if pan.length_squared() > 0.0:
                camera_center += pan.normalized()*minf(delta,0.15)*410.0/camera_zoom
                _clamp_camera()
                map_layer.queue_redraw()
                queue_redraw()
    if sim.started and not sim.finished and not sim.paused:
        step_buffer += minf(delta, 0.15) * game_speed / sim.operation_scale()
        var ticks: int = 0
        while step_buffer >= 0.1 and ticks < 10:
            for u in sim.units: previous_centers[int(u["id"])]=u["pos"]
            sim.step(0.1)
            step_buffer -= 0.1
            ticks += 1
            if highlight_active: _poll_highlight()
            if sim.finished or sim.paused:
                break
        if ticks == 10:
            step_buffer = minf(step_buffer, 0.4)
    if sim.started and not sim.paused and not sim.finished:
        render_clock=sim.battle_time+step_buffer
        if sim.battle_time-sample_time>=0.8: _sample_battle_losses()
    # UI is updated at a bounded rate rather than issuing draw work every frame.
    ui_clock += minf(delta, 0.15)
    if ui_clock >= 0.2:
        ui_clock = 0.0
        if sim.started and not sim.finished:
            var problems: Array[String] = sim.validate_state()
            if not problems.is_empty():
                sim.paused = true
                runtime_notice = "전투 계산 중단: " + problems[0]
                push_error(runtime_notice)
        _refresh_hud()
        _update_audio_and_warning()
        queue_redraw()
        portrait.queue_redraw()
    if fog_enabled and sim.started and not sim.finished and sim.battle_time-visibility_stamp >= 2.0:
        _refresh_visibility()
    if is_instance_valid(map_layer) and (not sim.paused or not sim.started):
        map_layer.queue_redraw()
    if sim.finished and not finish_seen:
        finish_seen = true
        _play_cue(520.0, 0.28)
        _show_outcome()

func _refresh_hud() -> void:
    var phase: String = "준비 중"
    clock_label.text=_operation_clock(sim.operation_elapsed())
    battle_title_label.text = sim.scenario_title
    objective_label.text = "목표  ·  "+sim.scenario_goal
    phase_label.text="북벌 전략 %d턴" % int(campaign.state["turn"]) if campaign_active else "작전 준비"
    if sim.finished:
        phase = "전투 종료"
        phase_label.text=sim.result
    elif sim.paused:
        phase = "일시정지"
        phase_label.text=sim.operation_phase()+"  |  제한 "+_operation_clock(sim.operation_limit())
    elif sim.started:
        phase = "작전 %d턴" % sim.turn
        phase_label.text = sim.operation_phase() + "  |  " + ("긴급 지휘력 %d / 4" % sim.command_points if sim.turn >= 6 else "초기 작전 수행 · 보고 수신")
    turn_label.text=phase
    for index in range(unit_list.item_count):
        var uid: int = int(unit_list.get_item_metadata(index))
        var leader: Dictionary = sim.find_unit(uid)
        if leader.is_empty(): continue
        var state: String = _field_action(leader)
        var psyche: Dictionary=leader.get("mind",{})
        unit_list.set_item_text(index,"%d %s  %s" % [index+1,str(leader["name"]),state])
        unit_list.set_item_tooltip(index,"%s명 · 병사 사기 %d · 장수 %s\n%s\n%s" % [_number_text(roundi(sim.corps_report(uid)["troops"])),roundi(leader["morale"]),str(psyche.get("mood","전투 준비")),str(psyche.get("reason","")),str(psyche.get("concern",""))])
        unit_list.set_item_custom_fg_color(index,COL_MUTED if float(leader["troops"]) <= 0.0 else (COL_RED if bool(leader["routed"]) else COL_TEXT))
    if is_instance_valid(roster_overlay): roster_overlay.queue_redraw()
    _refresh_enemy_roster()
    var enemy_text: String = "정찰 제한" if fog_enabled and not sim.finished else _number_text(sim.total_troops(1))
    status_label.text = "아군 %s   /   적군 %s\n전령 %d 이동 · %d 도착 · %d 차단" % [_number_text(sim.total_troops(0)),enemy_text,sim.couriers.size(),sim.delivered_orders,sim.intercepted_orders]
    var own_guards: int = sim.commander_guard_count(0)
    status_label.tooltip_text = "책사 보호 반경 내 전투부대 %d개" % own_guards
    if own_guards == 0 and sim.started and not sim.finished:
        status_label.tooltip_text += " · 호위 없음: 적 접근 시 포획 위험"
    if not sim.convoy.is_empty():
        var transport: Dictionary = sim.convoy_status()
        status_label.tooltip_text += "\n수레 %s · 진행 %d%% · 내구도 %d%% · 호위 %d개" % [str(transport["state"]),roundi(float(transport["progress"])*100.0),roundi(sim.convoy["hp"]),int(transport["guards"])]
    if is_instance_valid(situation_btn):
        var count: int = sim.open_situations().size()
        situation_btn.text = "보고 %d" % count if count > 0 else "긴급 보고"
        situation_btn.disabled = not sim.started or sim.finished
        situation_btn.add_theme_color_override("font_color",COL_GOLD if count>0 else COL_TEXT)
    start_btn.disabled = sim.started or sim.finished
    pause_btn.disabled = not sim.started or sim.finished
    pause_btn.text = "재개" if sim.paused else "일시정지"
    if is_instance_valid(highlight_button):
        highlight_button.disabled=not sim.started or sim.finished
        highlight_button.text="탐색 중 · 중지" if highlight_active else "다음 주요 상황 ▶"
    _collect_journal()
    apply_btn.disabled = sim.started and (sim.turn < 6 or sim.finished)
    apply_btn.text = "초기 작전 설정" if not sim.started else "전령 보내기 (6턴~)"
    start_btn.visible=not sim.started
    pause_btn.visible=sim.started
    live_order_button.disabled=sim.finished
    live_order_button.text="작전 지도 열기" if not sim.started else "작전 지도 · 전령 지시"
    var unit: Dictionary = sim.find_unit(selected_id)
    if not unit.is_empty():
        var ally: Dictionary=sim.find_unit(int(unit.get("assigned_link",-1)))
        var dispatch: String=dispatch_line(selected_id)
        var third_line: String=dispatch if not dispatch.is_empty() else "연계: "+(str(ally["name"]) if not ally.is_empty() else "자동 / 없음")
        live_order_label.text="%s → %s\n현재: %s" % [str(unit["mission"]),_goal_name(unit["goal"]),_field_action(unit)]
        order_status_label.text=third_line
        order_status_label.tooltip_text=dispatch
        var leader_state: String = "부장 지휘" if bool(unit["active_deputy"]) else str(unit["general_state"])
        var corps: Dictionary = sim.corps_report(selected_id)
        selected_label.text = "%s · %s · %s명" % [str(unit["name"]),leader_state,_number_text(roundi(corps["troops"]))]
        var ammo_text: String = " · 화살 %d" % int(unit.get("ammo", 100.0)) if str(unit["type"]) == "궁병" else ""
        var psyche: Dictionary=unit.get("mind",{})
        var readiness: String="사기 %d · 응집 %d" % [int(unit["morale"]),int(unit["cohesion"])]
        if int(unit["rations"])<35: readiness="군량 %d · %s" % [int(unit["rations"]),readiness]
        elif str(unit["type"])=="궁병" and int(unit["ammo"])<35: readiness="화살 %d · %s" % [int(unit["ammo"]),readiness]
        details_label.text = "%s · %s" % [str(psyche.get("mood","준비")),str(unit["formation"])]
        readiness_label.text=readiness
        details_label.modulate=_mood_color(str(psyche.get("mood","준비")))
        decision_label.text = "판단: "+str(unit["reason"])
        var suggestion: String=str(psyche.get("proposal",""))
        var target:Dictionary=sim.find_unit(int(unit.get("contact_target_id",-1)))
        if not target.is_empty() and _visible_unit(target):
            decision_label.text+="\n교전: "+str(target["name"])+" · 손실 "+_number_text(roundi(float(corps["casualties_taken"])))
        elif not suggestion.is_empty(): decision_label.text+="\n건의: "+suggestion
        else: decision_label.text+="\n우려: "+str(psyche.get("concern",""))
        decision_label.tooltip_text=str(unit["reason"])+"\n"+str(psyche.get("observed",""))+"\n우려: "+str(psyche.get("concern",""))+"\n최근 명령: "+str(psyche.get("last_order",""))
    if not unit.is_empty():
        details_label.tooltip_text = "%s\n사기 %d · 응집 %d · 피로 %d\n식량 %d · 화살 %d\n%s" % [str(unit["name"]),int(unit["morale"]),int(unit["cohesion"]),int(unit["fatigue"]),int(unit["rations"]),int(unit["ammo"]),str(unit["reason"])]
        if sim.six_armies:
            details_label.tooltip_text += "\n협동 타격 %d · 상성 우위 타격 %d · 측후방 피해 %d" % [roundi(unit["linked_hits"]),roundi(unit["counter_damage"]),roundi(unit["flank_damage"])]
            if float(unit.get("bridge_y",-1.0))>=0.0:
                details_label.tooltip_text += "\n도하 예정: "+_bridge_name(float(unit["bridge_y"]))
            if str(unit["mission"])=="측후방 기동":
                var stages: Array[String] = ["측면 기동","정면 접촉 대기","협동 공격"]
                details_label.tooltip_text += "\n"+stages[clampi(int(unit["flank_phase"]),0,2)]+" · 완료 %d · 공격 %d · 중단 %d" % [int(unit["flank_completed"]),int(unit["flank_commits"]),int(unit["flank_aborts"])]
    if observing_enemy:
        order_status_label.text=""
        order_status_label.tooltip_text=""
        readiness_label.text=""
        details_label.modulate=Color.WHITE
        var enemy: Dictionary=sim.find_unit(observed_enemy_id)
        if not enemy.is_empty() and _visible_unit(enemy):
            live_order_label.text="적군 관측 · %s\n%s / %s / %s명" % [str(enemy["name"]),str(enemy["type"]),_field_action(enemy),_number_text(roundi(float(enemy["troops"])))]
            order_status_label.text="사기 %d · 응집 %d" % [roundi(float(enemy["morale"])),roundi(float(enemy["cohesion"]))]
            selected_label.text="적장 · "+str(enemy["name"])
            details_label.text="%s · %s" % [_field_action(enemy),str(enemy["formation"])]
            if not fog_enabled:
                readiness_label.text="가한 피해 %s / 손실 %s" % [_number_text(roundi(float(enemy["damage_dealt"]))),_number_text(roundi(float(enemy["casualties_taken"])))]
            decision_label.text="적군 관측 · 명령 불가"
            details_label.tooltip_text=details_label.text
            decision_label.tooltip_text=decision_label.text
        else:
            live_order_label.text="적군 관측\n군단을 선택하여 위치와 활동 확인"
            selected_label.text="관측할 적군 선택"
            details_label.text=""
            details_label.tooltip_text=""
            decision_label.text=""
            decision_label.tooltip_text=""
        live_order_button.text="아군 작전 지도"
    if is_instance_valid(combat_brief): combat_brief.text=_battle_brief()
    if is_instance_valid(thought_feed): thought_feed.text=_latest_general_reports()
    _refresh_general_cards()
    _refresh_sector_board()
    if is_instance_valid(mind_dialog) and mind_dialog.visible: _refresh_mind_report()
    var start_line: int = maxi(0, sim.events.size() - 3)
    var lines: String = ""
    for i in range(start_line, sim.events.size()):
        if not fog_enabled or sim.finished or _public_event(sim.events[i]):
            lines += sim.events[i] + "\n"
    if sim.finished:
        lines = sim.result+"\n장수 6개 군단의 상세 전과는 결산 화면에서 확인하십시오."
    event_label.text = lines
    if not sim.started:
        notice_label.text = sim.scenario_goal + "\n작전실: 병력·부장·배치·경유점\n지도 모드: " + map_mode
    elif sim.finished:
        notice_label.text = "작전실 → 전투 타임라인\n장수별 결산은 아래 전황 창\n[초기화]로 재실행"
    elif sim.turn < 6:
        notice_label.text = "최초 5분은 사전 명령 수행.\n이후부터 전령 전달이 가능합니다."
    else:
        notice_label.text = "장수 선택 후 전령 파견\n실제 전장 이동 중 차단될 수 있습니다."
    notice_label.text=notice_label.text.replace("\n","  ·  ")
    if runtime_notice != "":
        notice_label.text = runtime_notice
    elif not battle_warning.is_empty():
        notice_label.text = battle_warning

func _toggle_feed() -> void:
    show_general_feed=not show_general_feed
    thought_feed.hide()
    combat_brief.visible=not show_general_feed
    for card in general_cards: card.visible=show_general_feed
    event_label.visible=not show_general_feed
    feed_toggle.text="전황 기록 보기" if show_general_feed else "장수 카드 보기"
    feed_heading.text="아군 장수" if show_general_feed else "전황 기록"

func dispatch_line(id: int) -> String:
    var dispatch: Dictionary=sim.map_dispatches.get(id,{})
    if dispatch.is_empty(): return ""
    var status: String=dispatch["status"]
    if status=="이동 중" and sim.finished: status="종료 전 미도착"
    if status=="이동 중": return "전령 이동 · "+str(dispatch["mission"])
    return "전령 %s · %s %s" % [status,dispatch["mission"],_operation_clock(float(dispatch["time"]))]

func _collect_journal() -> void:
    if not sim.started or not is_instance_valid(journal_list): return
    var current: Dictionary=FrontView.milestones(sim,fog_enabled)
    for key in current:
        if journal_keys.has(key): continue
        journal_keys[key]=true
        var event: Dictionary=current[key]
        event["time"]=sim.operation_elapsed()
        journal_events.push_front(event)
        if journal_events.size()>16: journal_events.pop_back()
        journal_button.text="상황 기록 %d" % journal_events.size()

func _clear_journal() -> void:
    journal_events.clear()
    journal_keys.clear()
    if is_instance_valid(journal_button): journal_button.text="상황 기록"
    if is_instance_valid(journal_dialog): journal_dialog.hide()

func _open_journal() -> void:
    if order_view.visible or title_screen.visible: return
    journal_list.clear()
    for event in journal_events:
        journal_list.add_item("%s  ·  %s" % [_operation_clock(float(event["time"])),event["label"]])
        journal_list.set_item_metadata(journal_list.item_count-1,event)
    if journal_events.is_empty(): journal_list.add_item("관측한 주요 상황이 없습니다.")
    journal_dialog.popup_centered()

func _visit_journal_event(index: int) -> void:
    var event = journal_list.get_item_metadata(index)
    if not event is Dictionary: return
    journal_dialog.hide()
    _frame_milestone(event)

func _frame_milestone(event: Dictionary) -> void:
    var id: int=int(event.get("unit_id",-1))
    var row: int=sim.command_ids(0).find(id)
    if row>=0:
        unit_list.select(row)
        _on_unit_selected(row)
    camera_center=event["point"]
    camera_zoom=1.4
    _clamp_camera()
    map_layer.queue_redraw()
    queue_redraw()

func _select_general_card(index: int) -> void:
    var ids: Array[int]=sim.command_ids(0)
    if index>=ids.size(): return
    selected_id=ids[index]
    _show_friendly_roster()
    unit_list.select(index)
    _select_unit()
    _focus_selected()

func _fit_card_line(value:String,width:float) -> String:
    if korean_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x<=width: return value
    var shortened:String=value
    while shortened.length()>1 and korean_font.get_string_size(shortened+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,13).x>width:
        shortened=shortened.substr(0,shortened.length()-1)
    return shortened+"…"

func _refresh_general_cards() -> void:
    var ids: Array[int]=sim.command_ids(0)
    for i in range(general_cards.size()):
        var card: Button=general_cards[i]
        if i>=ids.size():
            card.hide()
            continue
        card.visible=show_general_feed
        var u: Dictionary=sim.find_unit(ids[i])
        var mind: Dictionary=u.get("mind",{})
        var mood: String=str(mind.get("mood","준비"))
        var reason: String=str(mind.get("reason","초기 배치"))
        var suggestion: String=str(mind.get("proposal",""))
        var pending: bool=sim.map_dispatches.get(ids[i],{}).get("status","")=="이동 중" and not sim.finished
        var headline: String="%s · %s" % [str(u["name"]),_field_action(u)]
        var state: String=mood
        if pending: state+=" · 전령 이동"
        if not suggestion.is_empty(): state+=" · 건의"
        var detail: String=suggestion if not suggestion.is_empty() else reason
        card.text="\n".join([_fit_card_line(headline,137.0),_fit_card_line(state,137.0),_fit_card_line(detail,137.0)])
        if card.icon==null or str(card.get_meta("general_name",""))!=str(u["name"]):
            card.icon=_commander_icon(str(u["name"]),0)
            card.set_meta("general_name",str(u["name"]))
        card.tooltip_text="기분: "+mood+"\n판단: "+reason+"\n관측: "+str(mind.get("observed",""))+"\n우려: "+str(mind.get("concern",""))+"\n최근 명령: "+str(mind.get("last_order",""))
        card.add_theme_color_override("font_color",_mood_color(mood) if mood not in ["침착","준비","전투 준비"] else COL_TEXT)
        card.add_theme_color_override("font_hover_color",COL_GOLD)
        card.set_pressed_no_signal(ids[i]==selected_id and not observing_enemy)
        if ids[i]==selected_id and not observing_enemy:
            card.add_theme_color_override("font_color",COL_GOLD)

# Three live fronts, persistent and clickable. Display counts are actual current
# manpower in each geographical sector, never invented territorial control.
func _build_sector_board() -> void:
    for i in range(3):
        var card: Button=_button("",Vector2(16+i*271,61),Vector2(263,40),_focus_sector.bind(i))
        card.add_theme_font_size_override("font_size",12)
        card.alignment=HORIZONTAL_ALIGNMENT_LEFT
        card.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
        var panel:=StyleBoxFlat.new()
        panel.bg_color=COL_PANEL
        panel.border_color=COL_LINE
        panel.set_border_width_all(1)
        panel.set_corner_radius_all(4)
        panel.content_margin_left=10
        panel.content_margin_right=8
        card.add_theme_stylebox_override("normal",panel)
        var hover: StyleBoxFlat=panel.duplicate()
        hover.bg_color=Color("#24383a")
        hover.border_color=COL_GOLD
        card.add_theme_stylebox_override("hover",hover)
        sector_cards.append(card)

func _refresh_sector_board() -> void:
    if sector_cards.size()!=3: return
    sector_snapshot=FrontView.summarize(sim,fog_enabled and not sim.finished)
    for i in range(3):
        var row: Dictionary=sector_snapshot[i]
        var card: Button=sector_cards[i]
        var enemy: String=_number_text(int(row["enemy"]))
        if fog_enabled and not sim.finished: enemy="관측 "+enemy
        card.text="%s  |  %s\n아 %s  /  적 %s" % [str(row["name"]),str(row["state"]),_number_text(int(row["own"])),enemy]
        card.tooltip_text="해당 구역 병력 합계 · 영토 점유율 아님\n교전 중 공격 부대 %d개 / 아군 최대 전열 압박 %.0f%%\n클릭: 해당 전선으로 이동" % [int(row["contacts"]),float(row["pressure"])*100.0]
        var color: Color=COL_RED if str(row["state"])=="아군 압박" else (COL_GOLD if int(row["contacts"])>0 else COL_TEXT)
        card.add_theme_color_override("font_color",color)
        card.modulate=Color.WHITE if sector_selection==i else Color(0.94,0.96,0.95)

func _focus_sector(index: int) -> void:
    if index<0 or index>=sector_snapshot.size(): return
    sector_selection=index
    camera_center=sector_snapshot[index]["focus"]
    camera_zoom=1.20
    _clamp_camera()
    map_layer.queue_redraw()
    queue_redraw()

func _mood_color(mood: String) -> Color:
    if mood in ["공황","위기감","지휘 불능","압박"]: return COL_RED
    if mood in ["불안","초조","동요","긴장","지침"]: return COL_GOLD
    if mood=="자신감": return Color("#a9d5a5")
    return COL_MUTED

func _latest_general_reports() -> String:
    var reports: Array[Dictionary]=[]
    for id in sim.command_ids(0):
        var u: Dictionary=sim.find_unit(id)
        var m: Dictionary=u.get("mind",{})
        var history: Array=m.get("history",[])
        if history.is_empty(): continue
        var last: Dictionary=history.back()
        reports.append({"time":last["time"],"name":u["name"],"text":last["text"],"category":last["category"]})
    reports.sort_custom(func(a:Dictionary,b:Dictionary)->bool: return float(a["time"])>float(b["time"]))
    var lines: Array[String]=[]
    for i in range(mini(3,reports.size())):
        var row: Dictionary=reports[i]
        lines.append("[%s] %s · %s" % [_operation_clock(float(row["time"])*sim.operation_scale()),str(row["name"]),str(row["text"])])
    if lines.is_empty(): return "장수의 판단과 명령 반응이 이곳에 실시간 기록됩니다."
    return "\n".join(lines)

func _build_mind_report() -> void:
    mind_dialog=AcceptDialog.new()
    mind_dialog.title="장수 보고실 · 실시간 심리 및 판단 (전투 계속 진행)"
    mind_dialog.ok_button_text="전장으로"
    add_child(mind_dialog)
    mind_report=RichTextLabel.new()
    mind_report.custom_minimum_size=Vector2(840,590)
    mind_report.bbcode_enabled=true
    mind_report.add_theme_font_size_override("normal_font_size",15)
    mind_report.add_theme_constant_override("line_separation",5)
    mind_report.add_theme_color_override("default_color",COL_TEXT)
    mind_report.scroll_active=true
    mind_dialog.add_child(mind_report)

func _open_mind_report() -> void:
    if not is_instance_valid(mind_dialog): return
    _refresh_mind_report()
    mind_dialog.popup_centered(Vector2i(870,650))

func _refresh_mind_report() -> void:
    var lines: Array[String]=["[color=#d7bd85]장수 개인의 심리 추정 모델 · 병사 사기와 별개 · 실제 AI 판단 근거 기록[/color]","[color=#a6b6b4]심리·신뢰는 독자 추격과 철수 명령 거부 기준에 제한적으로 반영됩니다. 공격력·방어력 보정은 없습니다.[/color]"]
    for id in sim.command_ids(0):
        var u: Dictionary=sim.find_unit(id)
        var m: Dictionary=u.get("mind",{})
        if m.is_empty(): continue
        var age: float=maxf(0.0,sim.battle_time-float(m["decision_at"]))*sim.operation_scale()
        var mood: String=str(m["mood"])
        lines.append("[color=#8ed5e7][b][font_size=19]%s[/font_size][/b][/color]  %s / %s  ·  [color=#%s]%s[/color]  ·  %d명" % [str(u["name"]),str(u["personality"]),str(u["type"]),_mood_color(mood).to_html(false),mood,roundi(float(u["troops"]))])
        lines.append("자신감 %d   긴장 %d   명령 신뢰 %d   병사 사기 %d   |   판단 %.1f초 전" % [roundi(float(m["confidence"])),roundi(float(m["stress"])),roundi(float(m["trust"])),roundi(float(u["morale"])),age])
        lines.append("[color=#efc878][b]판단:[/b][/color] %s  →  %s" % [str(m["action"]),str(m["reason"])])
        lines.append("[color=#a6b6b4]관측:[/color] %s   |   [color=#a6b6b4]우려:[/color] %s" % [str(m["observed"]),str(m["concern"])])
        var pending: String=""
        for courier in sim.couriers:
            if int(courier["unit_id"])==id:
                pending="  |  전령 이동 중: "+str(courier.get("tactical_order",courier.get("mission","승계")))
                break
        lines.append("최근 명령: %s%s" % [str(m["last_order"]),pending])
        var profile: Dictionary=m.get("profile",{})
        lines.append("성향: %s · 침착성 %d · 주도성 %d  |  건의: %s" % [str(profile.get("style","균형")),roundi(float(profile.get("composure",65.0))),roundi(float(profile.get("initiative",55.0))),str(m.get("proposal","")) if not str(m.get("proposal","")).is_empty() else "없음"])
        if id==selected_id:
            var h: Array=m["history"]
            for j in range(maxi(0,h.size()-3),h.size()):
                var e: Dictionary=h[j]
                lines.append("[color=#a6b6b4]  %s · %s · %s[/color]" % [_operation_clock(float(e["time"])*sim.operation_scale()),str(e["category"]),str(e["text"])])
        lines.append("")
    lines.append("[color=#d7bd85][b]지휘 결과 · 최근 대응 6건[/b][/color]")
    var logged: int=0
    for i in range(sim.situation_reports.size()-1,-1,-1):
        var report: Dictionary=sim.situation_reports[i]
        if str(report["status"]) in ["대기","미대응","시간 경과"]: continue
        var actor: Dictionary=sim.find_unit(int(report.get("executor",-1)))
        var actor_name: String=str(actor.get("name",""))
        lines.append("%s → %s · %s %s" % [str(report["title"]),str(report.get("response","현장 판단")),actor_name,str(report["status"])])
        if report.has("received_at"):
            lines.append("  관측 행동: %s | 수행 구간 손실 %d / 가한 피해 %d (인과 효과 아님)" % [str(report.get("action_seen","미확인")),int(report.get("loss_delta",0)),int(report.get("damage_delta",0))])
        logged+=1
        if logged>=6: break
    if logged==0: lines.append("아직 대응한 보고 없음")
    var next_text: String="\n".join(lines)
    if mind_report.text!=next_text:
        var scroll: float=mind_report.get_v_scroll_bar().value
        mind_report.text=next_text
        mind_report.get_v_scroll_bar().set_deferred("value",scroll)

func _goal_name(p: Vector2) -> String:
    for site in sim.outposts:
        if p.distance_to(site["pos"])<135.0: return str(site["name"])
    if sim.near_crossing(p.y) and absf(p.x-sim.river_x(p.y))<140.0: return _bridge_name(p.y)
    return ("북측" if p.y<sim.field_size.y/3.0 else ("남측" if p.y>sim.field_size.y*2.0/3.0 else "중앙"))+" "+sim.terrain_at(p)

func _battle_brief() -> String:
    if not sim.started: return "양 진영 배치 및 작전 확인"
    var own_loss: float=0.0
    var own_damage: float=0.0
    var fighting: int=0
    for u in sim.units:
        if int(u["side"])!=0: continue
        own_loss+=float(u.get("casualties_taken",0.0))
        own_damage+=float(u.get("damage_dealt",0.0))
        if _field_action(u) in ["교전 중","사격 중"]: fighting+=1
    return "교전·사격 %d개 부대  |  가한 피해 %s  ·  아군 손실 %s" % [fighting,_number_text(roundi(own_damage)),_number_text(roundi(own_loss))]

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _minimap_rect().has_point(event.position):
        camera_zoom = maxf(1.0,camera_zoom)
        camera_center = (event.position-_minimap_rect().position)*sim.field_size.x/MINIMAP_AREA.size.x
        _clamp_camera()
        map_layer.queue_redraw()
        queue_redraw()
        accept_event()
        return
    if event is InputEventScreenTouch and Rect2(MAP_TOP_LEFT,MAP_SIZE).has_point(event.position):
        if event.pressed:
            touch_origin = event.position
            touch_dragged = false
        elif not touch_dragged:
            _map_select(event.position)
        accept_event()
        return
    if event is InputEventScreenDrag and Rect2(MAP_TOP_LEFT,MAP_SIZE).has_point(event.position):
        if touch_origin.distance_to(event.position) > 10.0:
            touch_dragged = true
            camera_center -= event.relative/camera_zoom
            _clamp_camera()
            map_layer.queue_redraw()
            queue_redraw()
        accept_event()
        return
    if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0 and Rect2(MAP_TOP_LEFT,MAP_SIZE).has_point(event.position):
        camera_center -= event.relative / camera_zoom
        _clamp_camera()
        map_layer.queue_redraw()
        accept_event()
        return
    if event is InputEventMouseButton and event.pressed and Rect2(MAP_TOP_LEFT,MAP_SIZE).has_point(event.position):
        if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _change_zoom(0.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.25)
            accept_event()
            return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _map_select(event.position)

func _map_select(mouse_pos: Vector2) -> void:
    if not Rect2(MAP_TOP_LEFT, MAP_SIZE).has_point(mouse_pos):
        return
    if not sim.started and map_mode != "선택":
        var field_pos: Vector2 = _world_mouse(mouse_pos)
        var applied: bool = false
        match map_mode:
            "배치": applied = sim.place_unit(selected_id, field_pos)
            "경유점": applied = sim.add_waypoint(selected_id, field_pos)
            "방어선": applied = sim.set_defense_line(selected_id, field_pos)
        runtime_notice = "작전 계획 반영: " + map_mode if applied else "설정 불가: 배치 범위·거리 또는 경유점 한도 확인"
        if map_mode != "경유점" and applied:
            map_mode = "선택"
        _refresh_hud()
        queue_redraw()
        accept_event()
        return
    var nearest_id: int = -1
    var best: float = 47.0/maxf(0.5,camera_zoom)
    var world: Vector2 = _world_mouse(mouse_pos)
    for unit in sim.units:
        if float(unit["troops"]) <= 0.0 or not _visible_unit(unit) or unit.has("parent_id"): continue
        var i: int=int(unit["id"])
        var p: Vector2 = unit["pos"]
        var distance: float = world.distance_to(p)
        if distance < best:
            best = distance
            nearest_id = i
    if nearest_id >= 0:
        var hit: Dictionary=sim.find_unit(nearest_id)
        if int(hit["side"])==1:
            observed_enemy_id=nearest_id
            _show_enemy_roster()
            accept_event()
            return
        var row: int = sim.command_ids(0).find(nearest_id)
        if row >= 0 and row < unit_list.item_count:
            unit_list.select(row)
            _on_unit_selected(row)
            accept_event()

func _draw() -> void:
    draw_rect(Rect2(0,0,1280,800),COL_BG)
    draw_rect(Rect2(0,0,1280,56),Color("#202c38"))
    draw_rect(Rect2(0,0,6,56),Color("#cf674e"))
    draw_line(Vector2(0,55),Vector2(1280,55),COL_LINE,1.0)
    var elapsed: float=clampf(sim.operation_elapsed()/maxf(1.0,sim.operation_limit()),0,1)
    draw_rect(Rect2(383,51,555,2),Color("#354653"))
    if elapsed>0.0: draw_rect(Rect2(383,51,555*elapsed,2),COL_GOLD)
    draw_rect(Rect2(MAP_TOP_LEFT,MAP_SIZE),Color("#19232d"))
    draw_rect(Rect2(MAP_TOP_LEFT,MAP_SIZE).grow(1),COL_LINE,false)
    draw_rect(Rect2(961,61,303,632),COL_PANEL)
    draw_rect(Rect2(970,333,286,132),Color("#263747"))
    draw_rect(Rect2(970,333,3,132),COL_BLUE if not observing_enemy else COL_RED)
    draw_line(Vector2(970,601),Vector2(1256,601),COL_LINE,1.0)
    draw_line(Vector2(16,697),Vector2(1264,697),COL_LINE,1.0)
    _draw_force_balance()
    _draw_minimap()

func _draw_force_balance() -> void:
    # Current manpower share, not win probability; no data in recon mode.
    var area:=Rect2(968,51,288,2)
    draw_rect(area,Color("#353f40"))
    if fog_enabled and not sim.finished: return
    var own: float=float(sim.total_troops(0))
    var enemy: float=float(sim.total_troops(1))
    var ratio: float=own/maxf(1.0,own+enemy)
    draw_rect(Rect2(area.position,Vector2(area.size.x*ratio,area.size.y)),COL_BLUE)
    draw_rect(Rect2(area.position+Vector2(area.size.x*ratio,0),Vector2(area.size.x*(1.0-ratio),area.size.y)),COL_RED)

func _toggle_map_detail() -> void:
    detailed_map = not detailed_map
    map_detail_button.text = "전술 표시 · 상세" if detailed_map else "전술 표시 · 간결"
    map_layer.queue_redraw()

# Capture objectives are areas of terrain, not structures. Only sim.structures
# represents actual walls/gates; no building art is drawn for outposts.
func _draw_control_marker(p: Vector2,color: Color,active: bool) -> void:
    var k: float=1.0/camera_zoom
    var radius: float=7.0*k
    map_layer.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-radius),p+Vector2(radius,0),p+Vector2(0,radius),p+Vector2(-radius,0)]),Color("#17231f"))
    map_layer.draw_polyline(PackedVector2Array([p+Vector2(0,-radius),p+Vector2(radius,0),p+Vector2(0,radius),p+Vector2(-radius,0),p+Vector2(0,-radius)]),color,1.4*k,true)
    if active:
        map_layer.draw_circle(p,2.8*k,color)

func _draw_field_site(kind: int,p: Vector2,scale_factor: float) -> void:
    # Visual footprint aligned with the old marker; no new collision geometry.
    var area: Rect2=Rect2(p-Vector2(61,91)*scale_factor,Vector2(122,122)*scale_factor)
    map_layer.draw_texture_rect_region(FIELD_SITES,area,Rect2(kind*384,0,384,384))

func _draw_map(_canvas: Control) -> void:
    map_layer.draw_set_transform(MAP_SIZE * 0.5 - camera_center * camera_zoom, 0.0, Vector2.ONE * camera_zoom)
    map_label_areas.clear()
    var screen_corner: Vector2=camera_center-MAP_SIZE*0.5/camera_zoom
    map_label_areas.append(Rect2(screen_corner+Vector2(MAP_SIZE.x-60,4)/camera_zoom,Vector2(56,56)/camera_zoom))
    map_label_areas.append(Rect2(screen_corner+Vector2(8,MAP_SIZE.y-46)/camera_zoom,Vector2(397,37)/camera_zoom))
    map_label_areas.append(Rect2(screen_corner+Vector2(MAP_SIZE.x-126,MAP_SIZE.y-46)/camera_zoom,Vector2(122,37)/camera_zoom))
    var map_rect: Rect2 = Rect2(Vector2.ZERO,sim.field_size)
    if terrain_cache != null:
        map_layer.draw_texture_rect(terrain_cache,map_rect,false)
    else:
        map_layer.draw_rect(map_rect,Color("#58684e"))
    if sim.wide_field and camera_zoom >= 0.65:
        _draw_river_detail()
    if sim.wide_field and camera_zoom >= 0.60:
        for crossing in [390.0,850.0,1300.0]:
            _draw_bridge(Vector2(sim.river_x(crossing),crossing))
    if camera_zoom<0.65:
        for tree in _visible_trees(): _draw_tree(tree,false,[])
    if fog_enabled and sim.started and not sim.finished and visibility_texture != null:
        map_layer.draw_texture_rect(visibility_texture,map_rect,false)
    if sim.wide_field:
        for crossing in [390.0,850.0,1300.0]:
            var bridge := Vector2(sim.river_x(crossing),crossing)
            if detailed_map and camera_zoom >= 0.75:
                _map_plate(_bridge_name(crossing),bridge+Vector2(0,-45),COL_GOLD,11)
    if not sim.started:
        map_layer.draw_rect(Rect2(Vector2(35,22),Vector2(270*sim.layout_scale-35,sim.field_size.y-40)),Color(COL_BLUE,0.035))
        for y in range(22,int(sim.field_size.y)-18,36):
            map_layer.draw_line(Vector2(270*sim.layout_scale,y),Vector2(270*sim.layout_scale,y+16),Color(COL_BLUE,0.5),1.5)
    # Static gate art removed: show the actual, potentially relocating supply bases only.
    if detailed_map and camera_zoom >= 0.75:
        _map_text("북로",sim.layout_point(Vector2(440,106)),Color("#d6cfaa"),11)
        _map_text("중앙 고지",sim.hill.get_center()+Vector2(-29,-22),Color("#e2d9b5"),11)
        _map_text("남로",sim.layout_point(Vector2(440,466)),Color("#d6cfaa"),11)
    # Capture sites show control, contested progress and victory holds directly.
    for site in sim.outposts:
        var site_pos: Vector2 = _screen(site["pos"])
        var known: bool = not fog_enabled or sim.finished or sim.player_can_see(site["pos"])
        var owner: int = int(site["owner"]) if known else -1
        var color: Color = COL_BLUE if owner == 0 else (COL_RED if owner == 1 else COL_GOLD)
        if detailed_map or (known and int(site["challenger"])>=0):
            map_layer.draw_arc(site_pos, WarSim.OUTPOST_RADIUS, 0.0, TAU, 44, Color(color.r,color.g,color.b,0.20),1.2,true)
        var marker_scale: float = maxf(1.0,0.75/camera_zoom)
        _draw_control_marker(site_pos,color,known and owner>=0)
        var state: String = ("미확보" if owner < 0 else ("아군 확보" if owner == 0 else "적군 확보")) if known else "미확인"
        if detailed_map or not sim.started or owner>=0:
            _map_plate(str(site["name"])+" · "+state,site_pos+Vector2(0,-18)*marker_scale,color,12)
        if known and int(site["challenger"]) >= 0:
            var progress: float = clampf(float(site["progress"]) / sim.capture_duration(), 0.0, 1.0)
            map_layer.draw_rect(Rect2(site_pos + Vector2(-30, 11), Vector2(60, 4)), Color("#243138"))
            map_layer.draw_rect(Rect2(site_pos + Vector2(-30, 11), Vector2(60.0 * progress, 4)), COL_BLUE if int(site["challenger"]) == 0 else COL_RED)
    for base in sim.bases:
        if not bool(base["alive"]):
            continue
        if fog_enabled and not sim.finished and int(base["side"]) != 0 and not sim.player_can_see(base["pos"]):
            continue
        var p: Vector2 = _screen(base["pos"])
        var side: int = int(base["side"])
        var accent: Color = COL_BLUE if side == 0 else COL_RED
        if str(base["state"]) == "가동" and not sim.started:
            map_layer.draw_arc(p,WarSim.SUPPLY_RADIUS,0.0,TAU,56,Color(accent,0.18),1.0)
        _draw_field_site(2,p,0.96)
        _paint_tile(44,Rect2(p+Vector2(27,-3),Vector2(32,28)))
        map_layer.draw_circle(p+Vector2(15,-10),4.0,accent)
        _map_plate("군량 %d" % int(base.get("stock",100.0)),p+Vector2(0,32),accent,11)
    for commander in sim.commanders:
        if fog_enabled and not sim.finished and int(commander["side"]) != 0 and not sim.player_can_see(commander["pos"]):
            continue
        var p: Vector2 = _screen(commander["pos"])
        var accent: Color = COL_BLUE if int(commander["side"]) == 0 else COL_RED
        _paint_tile(41,Rect2(p-Vector2(15,20),Vector2(30,36)))
        if int(commander["side"])==0 and sim.started and not sim.finished:
            var guarded: bool = sim.commander_guard_count(0)>0
            var guard_color: Color = COL_BLUE if guarded else COL_RED
            var scale_factor: float = maxf(1.0,0.75/camera_zoom)
            _map_plate("책사 · "+("호위" if guarded else "노출"),p+Vector2(0,-29)*scale_factor,guard_color,maxi(11,roundi(11.0/camera_zoom)))
            if not guarded:
                map_layer.draw_arc(p,76.0,0,TAU,44,Color(COL_RED,0.45),1.5/camera_zoom,true)
        else:
            _draw_string("책사", p + Vector2(-14, -21), 13, COL_TEXT)
        if commander["pos"] != commander["goal"]:
            map_layer.draw_line(p, _screen(commander["goal"]), Color(accent.r, accent.g, accent.b, 0.6), 1.5)
    for scout in sim.scouts:
        if not bool(scout["alive"]):
            continue
        if fog_enabled and not sim.finished and int(scout["side"]) != 0 and not sim.player_can_see(scout["pos"]):
            continue
        var scout_p: Vector2 = _screen(scout["pos"])
        var scout_color: Color = COL_BLUE if int(scout["side"]) == 0 else COL_RED
        _paint_tile(42,Rect2(scout_p-Vector2(9,9),Vector2(18,18)))
        map_layer.draw_circle(scout_p,9.0,scout_color,false,1.5)
        map_layer.draw_line(scout_p, _screen(scout["goal"]), Color(scout_color, 0.20), 1.0)
        _draw_string("정찰", scout_p + Vector2(-12, -12), 10, scout_color)
    # Allied scout snapshots are displayed as aged reports rather than live positions.
    for id in sim.intelligence[0]:
        var report: Dictionary = sim.intelligence[0][id]
        var report_p: Vector2 = _screen(report["pos"])
        var age: float = maxf(0.0, sim.battle_time - float(report["time"]))
        if not fog_enabled or sim.player_can_see(report_p): continue
        map_layer.draw_arc(report_p, 12.0, 0.0, TAU, 24, Color(COL_GOLD, maxf(0.15, 0.65 - age * 0.025)), 1.5)
        _draw_string("정찰 %.0f초 전 · %d%%" % [age*sim.operation_scale(),int(float(report.get("confidence",0.0))*100.0)], report_p + Vector2(-30, 19), 10, COL_GOLD)
    for letter in sim.couriers:
        if fog_enabled and not sim.finished and int(letter["side"]) != 0 and not sim.player_can_see(letter["pos"]):
            continue
        var p: Vector2 = _screen(letter["pos"])
        var selected_courier: bool=int(letter["side"])==0 and not observing_enemy and int(letter["unit_id"])==selected_id
        var courier_radius: float=(6.0 if selected_courier else 4.0)/camera_zoom
        map_layer.draw_circle(p,courier_radius+1.5/camera_zoom,Color("#292316"))
        map_layer.draw_circle(p,courier_radius,COL_GOLD)
        if selected_courier:
            _map_plate("전령 → "+str(sim.find_unit(selected_id).get("name","")),p+Vector2(0,-15)/camera_zoom,COL_GOLD,11)
    # Draw real maneuver waypoints so an aggressive flanking decision is visible.
    for unit in sim.units:
        if not _visible_unit(unit):
            continue
        if fog_enabled and not sim.finished and int(unit["side"]) != 0:
            continue
        if not detailed_map or float(unit.get("bridge_y",-1.0))>=0.0: continue
        if float(unit["troops"]) > 0.0 and (int(unit["id"]) == selected_id or str(unit["action"]) in ["패주","측면 우회","돌파"]) and str(unit["action"]) in ["측면 우회", "거점 점령", "거점 방어", "재집결", "전열 지원", "탄약 보충", "보급 복귀", "패주", "정보 확인", "명령 수행", "계획 경유", "방어선 사수"]:
            var start_point: Vector2 = _screen(unit["pos"])
            var flank_waypoint: Vector2 = _screen(unit["goal"])
            map_layer.draw_line(start_point, flank_waypoint, Color(COL_GOLD, 0.58), 1.4)
            map_layer.draw_arc(flank_waypoint, 8.0, 0.0, TAU, 24, COL_GOLD, 1.3)
    if not sim.started:
        var selected: Dictionary = sim.find_unit(selected_id)
        if not selected.is_empty():
            var previous: Vector2 = _screen(selected["pos"])
            var step_number: int = 1
            for waypoint in selected["waypoints"]:
                var point: Vector2 = _screen(waypoint)
                map_layer.draw_line(previous, point, COL_GOLD, 2.0)
                map_layer.draw_circle(point, 9.0, COL_GOLD, false, 2.0)
                _draw_string(str(step_number),point+Vector2(-3,4),11,COL_TEXT)
                previous = point
                step_number += 1
            if bool(selected["defense_set"]):
                var anchor: Vector2 = _screen(selected["defense_anchor"])
                map_layer.draw_arc(anchor, 28.0,0.0,TAU,32,COL_BLUE,2.0)
                _draw_string("사수",anchor+Vector2(-12,4),11,COL_BLUE)
    if not observing_enemy:
        _draw_cooperation_links()
        _draw_selected_bridge_route()
    _draw_active_routes()
    _draw_fortifications()
    for report in sim.open_situations():
        var rp: Vector2 = report["pos"]
        var pulse: float = 0.65+0.25*sin(render_clock*5.0)
        var k: float=1.0/camera_zoom
        if detailed_map:
            map_layer.draw_arc(rp,46.0,0.0,TAU,40,Color(1.0,0.72,0.30,pulse),2.0,true)
        map_layer.draw_circle(rp+Vector2(15,-20)*k,7*k,Color("#574323"))
        _draw_string("!",rp+Vector2(12,-16)*k,maxi(8,roundi(13*k)),COL_GOLD)
    if not sim.convoy.is_empty():
        var wagon: Vector2 = sim.convoy["pos"]
        var cargo: Dictionary = sim.convoy_status()
        var k: float = maxf(1.0,0.75/camera_zoom)
        var cargo_color: Color = COL_RED if str(cargo["state"]) in ["교전 정체","파괴"] else COL_GOLD
        _paint_tile(44,Rect2(wagon-Vector2(17,15)*k,Vector2(34,30)*k))
        map_layer.draw_rect(Rect2(wagon+Vector2(-25,18)*k,Vector2(50,5)*k),Color("#352c20"))
        map_layer.draw_rect(Rect2(wagon+Vector2(-25,18)*k,Vector2(50*float(sim.convoy["hp"])/100.0,5)*k),cargo_color)
        _map_plate("수레 %d%% · %s" % [roundi(float(cargo["progress"])*100.0),str(cargo["state"])],wagon+Vector2(0,-33)*k,cargo_color,maxi(11,roundi(11.0/camera_zoom)))
        var finish: Vector2 = sim.convoy["goal"]
        map_layer.draw_arc(finish,20.0*k,0,TAU,36,Color(COL_GOLD,0.85),2.0*k,true)
        _map_plate("호위 도착점",finish+Vector2(0,-28)*k,COL_GOLD,maxi(11,roundi(11.0/camera_zoom)))
    var visible_units: Array[Dictionary] = []
    for unit in sim.units:
        if float(unit["troops"]) > 0.0 and _visible_unit(unit):
            visible_units.append(unit)
    visible_units.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return (a["pos"] as Vector2).y < (b["pos"] as Vector2).y)
    var field_view := Rect2(camera_center-MAP_SIZE*0.5/camera_zoom,MAP_SIZE/camera_zoom).grow(125.0)
    _draw_fallen(field_view)
    _draw_march_dust(field_view)
    _draw_contact_fronts(visible_units,field_view)
    if camera_zoom>=0.65:
        var soldiers: Array[Dictionary]=_visible_soldier_batch(visible_units,field_view)
        _draw_depth_scene(soldiers,_visible_trees(),visible_units)
    for unit in visible_units:
        if field_view.has_point(unit["pos"]): _draw_unit(unit)
    _draw_combat_effects()
    _draw_loss_markers()
    var label_areas: Array[Rect2] = map_label_areas
    var focus_id: int=observed_enemy_id if observing_enemy else selected_id
    visible_units.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
        if int(a["id"]) == focus_id:
            return int(b["id"]) != focus_id
        if int(b["id"]) == focus_id:
            return false
        return int(a["id"]) < int(b["id"]))
    for unit in visible_units:
        _draw_unit_label(unit,label_areas,visible_units)
    _draw_terrain_texture()
    map_layer.draw_rect(map_rect, Color(Color("#cad8d7"), 0.42), false, 1.5)


# Merge both factions before sorting by feet position. A front rank can now
# occlude a rear rank even when they belong to different armies.
# Pressure lines are based on real current melee contact pairs. No overlay for
# artillery-range arrows or invisible enemies; render behind soldiers.
# Trees and soldiers share a foot-position sort. A unit behind a tree is
# partially hidden instead of being painted on top of the tree canopy.
func _visible_trees() -> Array[Dictionary]:
    var view:=Rect2(camera_center-MAP_SIZE*0.5/camera_zoom,MAP_SIZE/camera_zoom).grow(75.0)
    var result: Array[Dictionary]=[]
    for tree in forest_instances:
        if view.has_point(tree["pos"]): result.append(tree)
    return result

func _draw_tree(tree: Dictionary,detail: bool,visible_units: Array) -> void:
    var index:int=int(tree["tile"])
    if index<0 or index>=forest_textures.size(): return
    var texture:ImageTexture=forest_textures[index]
    var p:Vector2=tree["pos"]
    var size:Vector2=texture.get_size()
    var shade:=Color.WHITE
    if detail:
        # Fade only near known friendly or observed enemy formations; do not
        # leak hidden enemy location through changing forest opacity.
        for u in visible_units:
            var center:Vector2=u["pos"]
            var distance_squared: float=center.distance_squared_to(p)
            if distance_squared>=115.0*115.0: continue
            var distance:float=sqrt(distance_squared)
            var engaged:bool=int(u.get("contact_target_id",-1))>=0
            if engaged and distance<115.0:
                shade.a=minf(shade.a,lerpf(0.12,0.45,smoothstep(45.0,115.0,distance)))
            elif distance<70.0:
                shade.a=minf(shade.a,lerpf(0.35,0.78,smoothstep(20.0,70.0,distance)))
        if fog_enabled and sim.started and not sim.finished and not sim.player_can_see(p):
            shade=Color(0.62,0.68,0.66,1.0)
    map_layer.draw_texture_rect(texture,Rect2(p-Vector2(size.x*0.5,size.y*0.70),size),false,shade)

func _draw_depth_scene(soldiers:Array[Dictionary],trees:Array[Dictionary],visible_units:Array[Dictionary])->void:
    # Both arrays have already been depth-sorted. Linear merge, no per-frame
    # sort of all scenery and actors together.
    var si:int=0
    var ti:int=0
    while si<soldiers.size() or ti<trees.size():
        if ti<trees.size() and (si>=soldiers.size() or float(trees[ti]["pos"].y)<=float(soldiers[si]["point"].y)):
            _draw_tree(trees[ti],true,visible_units)
            ti+=1
        else:
            var item:Dictionary=soldiers[si]
            _draw_soldier(item["point"],item["unit"],item["accent"],int(item["index"]),item["target"])
            si+=1

func _draw_contact_fronts(visible_units: Array[Dictionary],field_view: Rect2) -> void:
    if not sim.started or sim.finished: return
    var known: Dictionary={}
    for u in visible_units: known[int(u["id"])]=u
    var drawn: Dictionary={}
    for u in visible_units:
        var target: Dictionary=known.get(int(u.get("contact_target_id",-1)),{})
        if target.is_empty() or str(u["type"])=="궁병" or str(target["type"])=="궁병": continue
        var a: int=int(u["id"])
        var b: int=int(target["id"])
        var key:=Vector2i(mini(a,b),maxi(a,b))
        if drawn.has(key): continue
        drawn[key]=true
        var center: Vector2=(u["pos"] as Vector2).lerp(target["pos"],0.5)
        if not field_view.has_point(center): continue
        var normal: Vector2=((target["pos"] as Vector2)-(u["pos"] as Vector2)).normalized()
        if normal.length_squared()<0.1: continue
        var lateral: Vector2=normal.orthogonal()
        var shift: Dictionary=sim.front_shifts.get(key,{})
        var pressure: float=float(shift.get("pressure",0.0))
        var pressed: Dictionary=u if int(shift.get("loser",-1))==a else target
        var color: Color=COL_GOLD
        if pressure>0.12:
            color=COL_RED if int(pressed["side"])==0 else COL_BLUE
        var span: float=clampf(float(u.get("contact_troops",0))*3.0,16.0,60.0)
        for i in range(5):
            var p: Vector2=center+lateral*(float(i)-2.0)*span/2.0
            if sim.in_open_water(p): continue
            map_layer.draw_line(p-lateral*span*0.16,p+lateral*span*0.16,Color(color,0.48),2.0/camera_zoom,true)
            if pressure>0.12:
                var d: Vector2=shift["direction"]
                var reach: float=clampf(pressure*18.0,5.0,15.0)/camera_zoom
                var tip: Vector2=p+d*reach
                var wing: Vector2=lateral*reach*0.48
                map_layer.draw_polyline(PackedVector2Array([p+wing,tip,p-wing]),Color(color,0.78),1.8/camera_zoom,true)
        if camera_zoom>=0.85 and detailed_map:
            var front_text: String="접전"
            if pressure>0.12:
                front_text=str(pressed["name"])+" 전열 밀림"
            _map_plate(front_text,center+Vector2(0,20),color,11)

func _visible_soldier_batch(visible_units: Array[Dictionary],field_view: Rect2) -> Array[Dictionary]:
    var batch: Array[Dictionary]=[]
    if contact_cache_step!=sim.step_count:
        contact_cache.clear()
        formation_render_cache.clear()
        contact_cache_step=sim.step_count
    for unit in visible_units:
        if not field_view.has_point(unit["pos"]): continue
        var accent: Color=COL_BLUE if int(unit["side"])==0 else COL_RED
        if bool(unit["routed"]): accent=Color(accent,0.48)
        elif float(unit["ambush_ready"])>=3.0: accent=Color(accent,0.64)
        var id: int=int(unit["id"])
        var cacheable: bool=sim.started and not sim.paused and not sim.finished
        if not cacheable or not formation_render_cache.has(id):
            formation_render_cache[id]=_visual_slots(unit)
        var slots: Array[Vector2]=formation_render_cache[id]
        var target_id: int=int(unit.get("contact_target_id",-1))
        var target: Dictionary=sim.find_unit(target_id)
        var can_contact: bool=sim.started and not sim.finished and not bool(unit["routed"]) and target_id>=0 and not target.is_empty() and _visible_unit(target)
        var targets: Array[Vector2]=[]
        if can_contact:
            if not cacheable or not contact_cache.has(id):
                var anchors: Array[Vector2]=sim.formation_slots(target)
                var aim: Array[Vector2]=[]
                var reach: float=173.0 if str(unit["type"])=="궁병" else 34.0
                for point in slots: aim.append(FrontView.local_target(point,anchors,reach))
                contact_cache[id]=aim
            targets=contact_cache[id]
        # True frontage anchors come first; at medium zoom only thin out
        # representative soldiers layered around those anchors.
        var core: int=clampi(ceili(float(unit["troops"])/180.0),1,24)
        for index in range(slots.size()):
            if sim.six_armies and camera_zoom<1.10 and index>=core and (index-core)%2==1: continue
            var point: Vector2=slots[index]
            var center: Vector2=unit["pos"]
            var local_target: Vector2=targets[index] if index<targets.size() else Vector2.INF
            if sim.started and not sim.finished and not sim.paused and previous_centers.has(id):
                var previous: Vector2=previous_centers[id]
                point+=previous.lerp(center,clampf(step_buffer/0.1,0.0,1.0))-center
            var scatter: float=(100.0-float(unit["cohesion"]))*0.045
            if bool(unit["routed"]): scatter+=6.5
            point+=Vector2(sin(float(index)*7.3),cos(float(index)*5.7))*scatter
            var event_age: float=render_clock-float(unit.get("last_visual",-100.0))-float(index%5)*0.026
            if local_target!=Vector2.INF and event_age>=0.0 and event_age<=0.30:
                point=FrontView.advance_toward_contact(point,local_target,sin(clampf(event_age/0.30,0.0,1.0)*PI),str(unit["type"]))
            if sim.in_open_water(point): point=slots[index]
            point=Vector2(clampf(point.x,0.0,sim.field_size.x),clampf(point.y,0.0,sim.field_size.y))
            batch.append({"point":point,"unit":unit,"accent":accent,"index":index,"target":local_target})
    batch.sort_custom(func(a:Dictionary,b:Dictionary)->bool: return (a["point"] as Vector2).y<(b["point"] as Vector2).y)
    return batch


func _draw_formation_footprint(slots: Array[Vector2], fill: Color, outline: Color, width: float) -> void:
    var hull: PackedVector2Array = Geometry2D.convex_hull(PackedVector2Array(slots))
    # Godot closes the hull. The outline needs that closing point, but
    # polygon triangulation expects each vertex exactly once.
    if hull.size() < 4:
        return
    var polygon: PackedVector2Array = hull.slice(0, -1)
    # Slots pressed against a field or river boundary can collapse into a
    # shape with no usable interior. The outline is still useful there.
    if not Geometry2D.triangulate_polygon(polygon).is_empty():
        map_layer.draw_colored_polygon(polygon, fill)
    map_layer.draw_polyline(hull, outline, width, true)

func _draw_unit(unit: Dictionary) -> void:
    var side: int = int(unit["side"])
    var accent: Color = COL_BLUE if side == 0 else COL_RED
    var p: Vector2 = _screen(unit["pos"])
    var unit_type: String = str(unit["type"])
    if bool(unit["routed"]):
        accent = Color(accent, 0.48)
    elif float(unit["ambush_ready"]) >= 3.0:
        accent = Color(accent, 0.64)
    if camera_zoom < 0.65:
        # Draw the actual formation footprint in overview, not a flag pile or a
        # scaled copy of slot positions that expands beyond its real area.
        var k:float=1.0/camera_zoom
        var slots: Array[Vector2]=sim.formation_slots(unit)
        if slots.size()>=3:
            _draw_formation_footprint(slots,Color(accent,0.15),Color(accent,0.75),k)
        for spot in slots:
            map_layer.draw_circle(spot,1.45*k,Color("#15201d"))
            map_layer.draw_circle(spot,0.95*k,accent)
        var center_color: Color=COL_GOLD if int(unit["id"])==(observed_enemy_id if observing_enemy else selected_id) else accent
        map_layer.draw_circle(p,3.7*k,Color("#17221f"))
        map_layer.draw_circle(p,3.0*k,center_color,false,1.1*k,true)
        var front: Vector2=(unit["facing"] as Vector2).normalized()
        map_layer.draw_line(p+front*4*k,p+front*8*k,center_color,1.4*k,true)
        return
    var slots: Array[Vector2] = _visual_slots(unit)
    if detailed_map and sim.six_armies and slots.size()>2 and int(unit["id"])==selected_id and side==0:
        _draw_formation_footprint(slots,Color(accent,0.045),Color(COL_GOLD,0.35),1.2)
    var flag_extent: Vector2 = Vector2(15,22) if unit.has("parent_id") else Vector2(23,32)
    _paint_tile(38+side,Rect2(p-Vector2(flag_extent.x*0.5,flag_extent.y+7),flag_extent),Color(1,1,1,accent.a))
    if camera_zoom>=1.0 and not unit.has("parent_id"):
        var sway: float=sin(render_clock*sim.operation_scale()*2.0+float(unit["id"]))*2.0
        var top: Vector2=p+Vector2(-2,-36)
        map_layer.draw_line(p+Vector2(-2,-6),top,Color("#a58b58"),1.3,true)
        map_layer.draw_colored_polygon(PackedVector2Array([top,top+Vector2(15,sway+2),top+Vector2(12,sway+10),top+Vector2(0,9)]),Color(accent,0.87))
    var forward: Vector2 = unit["facing"]
    if detailed_map:
        map_layer.draw_line(p + forward*22.0, p + forward*35.0, Color(accent,0.8), 1.8)
    if detailed_map and str(unit["formation"]) == "방진" and side==0 and int(unit["id"])==selected_id:
        map_layer.draw_rect(Rect2(p-Vector2(25,25),Vector2(50,50)),Color(accent,0.20),false,1.0)
    if int(unit["id"]) == (observed_enemy_id if observing_enemy else selected_id):
        # Four unobtrusive selection brackets around the actual formation extent.
        var bounds := Rect2(p,Vector2.ZERO)
        for spot in slots: bounds = bounds.expand(spot)
        bounds = bounds.grow(8.0)
        var length: float = 10.0/camera_zoom
        for corner in [bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]:
            var dx: float = 1.0 if corner.x==bounds.position.x else -1.0
            var dy: float = 1.0 if corner.y==bounds.position.y else -1.0
            map_layer.draw_polyline(PackedVector2Array([corner+Vector2(dx*length,0),corner,corner+Vector2(0,dy*length)]),COL_GOLD,1.5/camera_zoom,true)
    if detailed_map and float(unit.get("front_pressure", 0.0)) > 0.10:
        map_layer.draw_arc(p, 38.0, forward.angle()-0.65, forward.angle()+0.65, 16, COL_RED if side == 0 else COL_BLUE, 2.5,true)
    var contacts: int = int(unit.get("contact_troops", 0))
    if detailed_map and contacts > 0 and unit_type != "궁병":
        map_layer.draw_arc(p, 30.0, forward.angle()-0.8, forward.angle()+0.8, 18, Color(COL_GOLD, 0.58), 1.5,true)
    if str(unit["next_formation"]) != "":
        _draw_string("↻", p + Vector2(28, 0), 15, COL_GOLD)

# Real goals only; avoid a misleading direct line across a committed crossing.
func _draw_active_routes() -> void:
    if not sim.started or sim.finished: return
    var k: float=1.0/camera_zoom
    for u in sim.units:
        if float(u["troops"])<=0.0 or not _visible_unit(u): continue
        var own: bool=int(u["side"])==0
        var chosen: bool=int(u["id"])==(observed_enemy_id if observing_enemy else selected_id)
        if not own and (not chosen or fog_enabled): continue
        if not chosen and not detailed_map and camera_zoom>=0.85: continue
        if float(u.get("bridge_y",-1.0))>=0.0 and own and chosen: continue
        if not chosen and float(u.get("motion_speed",0.0))<2.0: continue
        var p: Vector2=u["pos"]
        var goal: Vector2=u["goal"]
        if p.distance_to(goal)<20.0: continue
        var color: Color=Color(COL_BLUE if own else COL_RED,0.82 if chosen else 0.39)
        var route: Array[Vector2]=[goal]
        if float(u.get("bridge_y",-1.0))>=0.0: route=sim.committed_route_preview(u)
        for q in route:
            var d: Vector2=q-p
            var length: float=d.length()
            if length>2.0:
                var direction: Vector2=d/length
                for n in range(0,int(length),maxi(1,roundi(20*k))):
                    map_layer.draw_line(p+direction*n,p+direction*minf(length,n+11*k),color,(2.0 if chosen else 1.2)*k,true)
                map_layer.draw_colored_polygon(PackedVector2Array([q,q-direction*10*k+direction.orthogonal()*5*k,q-direction*10*k-direction.orthogonal()*5*k]),color)
            p=q
        if chosen: _map_plate(_goal_name(goal),goal+Vector2(0,15*k),COL_BLUE if own else COL_RED,12)

func _draw_unit_label(unit: Dictionary, occupied: Array[Rect2], visible_units: Array[Dictionary]) -> void:
    var p: Vector2 = unit["pos"]
    var side: int = int(unit["side"])
    var accent: Color = COL_BLUE if side == 0 else COL_RED
    var selected: bool = int(unit["id"]) == (observed_enemy_id if observing_enemy else selected_id)
    var inv: float = 1.0/camera_zoom
    var view := Rect2(camera_center-MAP_SIZE*0.5*inv,MAP_SIZE*inv).grow(-4.0*inv)
    if not view.grow(35.0).has_point(p):
        return
    var state: String = ""
    if bool(unit["routed"]): state = "패주"
    elif bool(unit["surrounded"]): state = "포위"
    elif str(unit["general_state"]) != "건재": state = str(unit["general_state"])
    elif bool(unit["rallying"]): state = "재집결"
    else: state = _field_action(unit)
    if unit.has("parent_id") and camera_zoom < 0.8: return
    # Place all unit text in viewport pixels; the camera never scales glyphs.
    var rich: bool = selected or detailed_map
    var label: String = str(unit["name"])
    if rich or camera_zoom>=0.9: label += "  "+_number_text(roundi(float(unit["troops"])))
    if rich and detailed_map: label += " · "+str(unit["formation"])
    if not state.is_empty() and (rich or state in ["패주","포위","전사","부상"]): label += " · "+state
    if side==0 and selected:
        label+=" / "+str(unit.get("mind",{}).get("mood","준비"))
    var fs: int = 14 if selected else 12
    var width: float = (korean_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x+18.0)*inv
    var height: float = (27.0 if selected else 21.0)*inv
    var chosen := Rect2()
    var found: bool = false
    var best_score: float = INF
    var vertical: float = maxf(42.0,36.0*inv)
    var horizontal: float = maxf(54.0,52.0*inv)
    for offset in [Vector2(0,-vertical),Vector2(0,vertical),Vector2(-horizontal,-vertical*0.5),Vector2(horizontal,-vertical*0.5),Vector2(-horizontal,vertical*0.5),Vector2(horizontal,vertical*0.5),Vector2(0,-vertical*1.6),Vector2(0,vertical*1.6),Vector2(-horizontal*1.8,-vertical),Vector2(horizontal*1.8,-vertical),Vector2(-horizontal*1.8,vertical),Vector2(horizontal*1.8,vertical)]:
        var candidate := Rect2(p+offset-Vector2(width*0.5,height*0.5),Vector2(width,height))
        if not view.encloses(candidate): continue
        var score: float = (candidate.get_center()-p).length()
        for prior in occupied:
            if prior.grow(4.0*inv).intersects(candidate): score += 10000.0
        for other in visible_units:
            var q: Vector2 = other["pos"]
            if Rect2(q-Vector2(29,30),Vector2(58,60)).intersects(candidate): score += 500.0
        if score<best_score:
            chosen=candidate
            best_score=score
            found=true
    if not found or best_score>=10000.0:
        return # the selected officer still has a permanent information panel
    occupied.append(chosen)
    var attachment: Vector2 = chosen.get_center()
    if selected or detailed_map:
        map_layer.draw_line(p,attachment,Color(accent,0.38),0.8*inv,true)
    var screen_origin: Vector2 = MAP_SIZE*0.5-camera_center*camera_zoom
    map_layer.draw_set_transform(screen_origin+chosen.position*camera_zoom,0.0,Vector2.ONE)
    var pixel_size: Vector2 = chosen.size*camera_zoom
    var rect := Rect2(Vector2.ZERO,pixel_size)
    map_layer.draw_rect(Rect2(Vector2(1,2),pixel_size),Color(0,0,0,0.27))
    map_layer.draw_rect(rect,Color("#171e1b") if selected else Color(0.07,0.10,0.09,0.83))
    if selected: map_layer.draw_rect(rect,Color(COL_GOLD,0.8),false,1.0)
    map_layer.draw_rect(Rect2(Vector2.ZERO,Vector2(3,pixel_size.y)),accent)
    _draw_string(label,Vector2(9,16 if selected else 14),fs,COL_TEXT)
    if rich:
        var ratio: float=clampf(float(unit["troops"])/maxf(1.0,float(unit["initial_troops"])),0.0,1.0)
        var bar_width: float=pixel_size.x-14.0
        var bar: Vector2=Vector2(8,pixel_size.y-4)
        map_layer.draw_rect(Rect2(bar,Vector2(bar_width,2)),Color("#394247"))
        map_layer.draw_rect(Rect2(bar,Vector2(bar_width*ratio,2)),accent)
    map_layer.draw_set_transform(screen_origin,0.0,Vector2.ONE*camera_zoom)

func _screen(p: Vector2) -> Vector2:
    return p

func _map_text(value: String, pos: Vector2, shade: Color, font_size: int) -> void:
    _draw_string(value, _screen(pos), font_size, shade)

func _draw_string(value: String, where: Vector2, font_size: int, shade: Color) -> void:
    if korean_font != null:
        map_layer.draw_string(korean_font, where, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shade)


func _visible_unit(unit: Dictionary) -> bool:
    return FrontView.observes_unit(sim,unit,fog_enabled)

func _build_planning_dialog() -> void:
    planning_dialog = AcceptDialog.new()
    planning_dialog.title = "군략 · 작전실"
    planning_dialog.ok_button_text = "닫기"
    add_child(planning_dialog)
    var root := VBoxContainer.new()
    root.custom_minimum_size = Vector2(560, 0)
    planning_dialog.add_child(root)
    plan_status = Label.new()
    plan_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(plan_status)
    plan_scenario = _plan_option(root,"전장 시나리오",["북남 요충지","중앙 고지 쟁탈","보급로 사수","군량 수레 호위","천수 돌파전"])
    plan_scenario.item_selected.connect(_change_scenario)
    plan_donor = _plan_option(root,"다른 장수 / 병력 제공 부대",["왕평 부대","마속 부대","위연 부대"])
    var troop_row := HBoxContainer.new()
    root.add_child(troop_row)
    _plan_button(troop_row,"병력 500명 받기",_transfer_in)
    _plan_button(troop_row,"병력 500명 보내기",_transfer_out)
    _plan_button(troop_row,"장수 교체",_swap_general)
    var link_row := HBoxContainer.new()
    root.add_child(link_row)
    var assign_link := Button.new()
    assign_link.text="선택 부대를 협동 대상으로 지정"
    link_row.add_child(assign_link)
    assign_link.pressed.connect(func(): _change_link(plan_donor.get_selected_id()))
    var clear_link := Button.new()
    clear_link.text="자동 선택"
    link_row.add_child(clear_link)
    clear_link.pressed.connect(func(): _change_link(-1))
    plan_deputy = _plan_option(root,"부장",["통솔형 부장","공격형 부장","책략형 부장"])
    plan_deputy.item_selected.connect(_change_deputy)
    plan_takeover = Button.new()
    plan_takeover.text = "부상 장수 지휘 교체 전령 (6턴~)"
    root.add_child(plan_takeover)
    plan_takeover.pressed.connect(_request_takeover)
    plan_priority = _plan_option(root,"보급 우선순위",["낮음","보통","높음"])
    plan_priority.item_selected.connect(_change_priority)
    var map_row := HBoxContainer.new()
    root.add_child(map_row)
    _plan_button(map_row,"계획 삭제",_clear_route)
    var mode_row := HBoxContainer.new()
    root.add_child(mode_row)
    _plan_button(mode_row,"작전 지도",func():
        planning_dialog.hide()
        _open_order_map())
    plan_fog = CheckButton.new()
    plan_fog.text = "책사 시야 제한"
    plan_fog.button_pressed = fog_enabled
    mode_row.add_child(plan_fog)
    plan_fog.toggled.connect(_toggle_fog)
    var timeline_btn := Button.new()
    timeline_btn.text = "전투 타임라인 보기 (전체 기록)"
    root.add_child(timeline_btn)
    timeline_btn.pressed.connect(_open_timeline)
    timeline_dialog = AcceptDialog.new()
    timeline_dialog.title = "전투 타임라인"
    timeline_dialog.ok_button_text = "닫기"
    add_child(timeline_dialog)
    timeline_view = TextEdit.new()
    timeline_view.editable = false
    timeline_view.custom_minimum_size = Vector2(780,500)
    timeline_dialog.add_child(timeline_view)

func _plan_option(parent: VBoxContainer, caption: String, options: Array[String]) -> OptionButton:
    var label := Label.new()
    label.text = caption
    parent.add_child(label)
    var option := OptionButton.new()
    for item in options:
        option.add_item(item)
    parent.add_child(option)
    return option

func _plan_button(parent: HBoxContainer, caption: String, handler: Callable) -> void:
    var btn := Button.new()
    btn.text = caption
    btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(btn)
    btn.pressed.connect(handler)
    if caption != "지도 선택 모드":
        plan_actions.append(btn)

func _open_planning() -> void:
    var unit: Dictionary = sim.find_unit(selected_id)
    if unit.is_empty():
        return
    plan_scenario.select(sim.scenario_id)
    plan_scenario.disabled = campaign_active or (sim.started and not sim.finished)
    plan_donor.clear()
    var ids: Array[int] = sim.command_ids(0)
    for i in ids:
        var candidate: Dictionary = sim.find_unit(i)
        plan_donor.add_item(str(candidate["name"]) + " 부대",i)
    plan_donor.select((ids.find(selected_id)+1)%ids.size())
    plan_deputy.select(int(unit["deputy_index"]))
    plan_deputy.disabled = sim.started
    plan_takeover.disabled = not sim.started or sim.finished or sim.turn < 6 or str(unit["general_state"]) != "부상" or bool(unit["active_deputy"])
    plan_priority.select(int(unit["supply_priority"]))
    plan_priority.disabled = sim.finished
    plan_fog.set_pressed_no_signal(fog_enabled)
    for btn in plan_actions:
        btn.disabled = sim.started
    _refresh_plan_status()
    planning_dialog.popup_centered()

func _refresh_plan_status() -> void:
    var unit: Dictionary = sim.find_unit(selected_id)
    plan_status.text = "%s / %s\n%s 부대 · %d명 · 경유점 %d개 · 부장 %s" % [sim.scenario_title,sim.scenario_goal,str(unit["name"]),int(unit["troops"]),unit["waypoints"].size(),sim.deputy_name(unit)]

func _change_scenario(index: int) -> void:
    if campaign_active:
        return
    if highlight_active: _stop_highlight("전장 변경",false)
    if sim.set_scenario(index):
        battle_samples.clear()
        recent_losses.clear()
        fallen_marks.clear()
        loss_carry.clear()
        battle_warning=""
        previous_centers.clear()
        contact_cache.clear()
        formation_render_cache.clear()
        contact_cache_step=-1
        _clear_journal()
        sector_selection=-1
        sample_time=-100.0
        _show_friendly_roster()
        _rebuild_terrain()
        _reset_camera()
        finish_seen = false
        last_audio_event = -1.0
        map_mode = "선택"
        selected_id = 0
        runtime_notice = ""
        _refresh_unit_list()
        _select_unit()
        planning_dialog.hide()
        queue_redraw()

func _transfer_in() -> void:
    if sim.transfer_troops(selected_id,plan_donor.get_selected_id(),500):
        _refresh_plan_status()
        _refresh_hud()
    else:
        plan_status.text = "병력 조정 불가: 최소 1,000명 / 최대 5,000명"

func _transfer_out() -> void:
    if sim.transfer_troops(plan_donor.get_selected_id(),selected_id,500):
        _refresh_plan_status()
        _refresh_hud()
    else:
        plan_status.text = "병력 조정 불가: 최소 1,000명 / 최대 5,000명"

func _swap_general() -> void:
    if campaign_active:
        plan_status.text = "캠페인 장수 교체는 전략 지도에서 수행하십시오."
        return
    if sim.swap_generals(selected_id,plan_donor.get_selected_id()):
        _refresh_unit_list()
        _select_unit()
        planning_dialog.hide()

func _change_deputy(index: int) -> void:
    sim.set_deputy(selected_id,index)
    _refresh_plan_status()

func _change_priority(index: int) -> void:
    sim.set_supply_priority(selected_id,index)
    _refresh_plan_status()

func _set_map_mode(mode: String) -> void:
    map_mode = mode
    runtime_notice = "지도에서 위치를 클릭하세요: " + mode if mode != "선택" else ""
    planning_dialog.hide()
    _refresh_hud()
    queue_redraw()

func _clear_route() -> void:
    sim.clear_plan(selected_id)
    _refresh_plan_status()
    queue_redraw()

func _open_timeline() -> void:
    planning_dialog.hide()
    timeline_view.text = sim.timeline_text() if sim.finished or not fog_enabled else "시야 제한 중에는 전체 타임라인을 공개하지 않습니다. 전투 종료 후 확인하거나 전체 관전 모드로 전환하세요."
    timeline_dialog.popup_centered()

func _toggle_fog(value: bool) -> void:
    if fog_enabled!=value:
        _clear_journal()
    fog_enabled = value
    if highlight_active: highlight_seen=FrontView.milestones(sim,fog_enabled)
    if is_instance_valid(plan_fog): plan_fog.set_pressed_no_signal(value)
    if value and sim.started: _refresh_visibility()
    _refresh_hud()
    map_layer.queue_redraw()
    queue_redraw()

func _request_takeover() -> void:
    if sim.request_deputy_takeover(selected_id):
        planning_dialog.hide()
        runtime_notice = "부장 지휘 교체 전령 파견"
        _refresh_hud()
    else:
        plan_status.text = "지휘 교체 불가: 부상, 6턴 이후, 전령 중복 여부 확인"

func _public_event(message: String) -> bool:
    # Conservative filtering of identifiable enemy-only events in limited view.
    if "적군" in message or "위군" in message:
        return false
    for unit in sim.units:
        if int(unit["side"]) == 1 and str(unit["name"]) in message:
            return false
    return true


func _build_map_layer() -> void:
    map_clip = Control.new()
    map_clip.position = MAP_TOP_LEFT
    map_clip.size = MAP_SIZE
    map_clip.clip_contents = true
    map_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(map_clip)
    var layer := RenderLayer.new()
    layer.size = MAP_SIZE
    layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    layer.painter = _draw_map
    map_clip.add_child(layer)
    map_layer = layer

func _world_mouse(p: Vector2) -> Vector2:
    return (p - MAP_TOP_LEFT - MAP_SIZE*0.5)/camera_zoom + camera_center

func _clamp_camera() -> void:
    var half: Vector2 = MAP_SIZE*0.5/camera_zoom
    camera_center.x = clampf(camera_center.x,minf(half.x,sim.field_size.x*0.5),maxf(sim.field_size.x-half.x,sim.field_size.x*0.5))
    camera_center.y = clampf(camera_center.y,minf(half.y,sim.field_size.y*0.5),maxf(sim.field_size.y-half.y,sim.field_size.y*0.5))

func _change_zoom(delta: float) -> void:
    camera_zoom = clampf(camera_zoom+delta,_overview_zoom(),2.5)
    _clamp_camera()
    if is_instance_valid(map_layer): map_layer.queue_redraw()
    queue_redraw()

func _overview_zoom() -> float:
    return minf(MAP_SIZE.x/sim.field_size.x,MAP_SIZE.y/sim.field_size.y)

func _reset_camera() -> void:
    render_clock = sim.battle_time
    camera_zoom = _overview_zoom()
    camera_center = sim.field_size*0.5
    if not sim.started:
        visibility_stamp = -100.0
        visibility_texture = null
    if is_instance_valid(map_layer): map_layer.queue_redraw()
    queue_redraw()

func _focus_selected() -> void:
    var unit: Dictionary = sim.find_unit(selected_id)
    if not unit.is_empty():
        camera_center = unit["pos"]
        camera_zoom = maxf(1.5,camera_zoom)
        _clamp_camera()
        map_layer.queue_redraw()
        queue_redraw()

func _build_presentation() -> void:
    _button("＋",Vector2(26,632),Vector2(33,32),func(): _change_zoom(0.25)).tooltip_text="전장 확대"
    _button("－",Vector2(65,632),Vector2(33,32),func(): _change_zoom(-0.25)).tooltip_text="전장 축소"
    _button("장수",Vector2(104,632),Vector2(68,32),_focus_selected).tooltip_text="선택한 장수로 이동 · F"
    _button("전체",Vector2(888,632),Vector2(52,32),_reset_camera).tooltip_text="전장 전체 보기 · Home"
    _button("음향",Vector2(828,632),Vector2(54,32),_toggle_sound)
    var card := RenderLayer.new()
    card.position = Vector2(974,343)
    card.size = Vector2(68,68)
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.painter = _draw_portrait
    add_child(card)
    portrait = card
    brief_dialog = AcceptDialog.new()
    brief_dialog.title = "군략 · 작전 브리핑"
    brief_dialog.ok_button_text = "작전실로"
    add_child(brief_dialog)
    brief_text = Label.new()
    brief_text.custom_minimum_size = Vector2(540,210)
    brief_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    brief_dialog.add_child(brief_text)
    brief_dialog.confirmed.connect(_open_planning)
    analysis_dialog = AcceptDialog.new()
    analysis_dialog.title = "전투 분석 · 병력 변화"
    analysis_dialog.ok_button_text = "닫기"
    add_child(analysis_dialog)
    var chart := RenderLayer.new()
    chart.custom_minimum_size = Vector2(620,300)
    chart.painter = _draw_history
    analysis_dialog.add_child(chart)
    analysis_chart = chart

func _open_briefing() -> void:
    var tactic: String = "북측 보병으로 적을 묶고 남측 기병과 중앙 궁병을 연계하십시오."
    if sim.scenario_id == 1:
        tactic = "고지에 화력을 집중하고 측면 지원군으로 접근로를 통제하십시오."
    elif sim.scenario_id == 2:
        tactic = "보급기지 주변에 방어선을 정하고 기병을 기동 예비대로 운용하십시오."
    elif sim.scenario_id == 3:
        tactic = "수레 125 거리 내에 호위군을 유지하고 접근하는 적을 차단하십시오."
    elif sim.scenario_id == 4:
        tactic = "보병으로 성문을 파괴하고 중앙 거점을 확보하십시오."
    var story: String = ""
    if campaign_active and int(campaign.state["pending"]) >= 0:
        story = str(Campaign.NODES[int(campaign.state["pending"])]["story"])+"\n"
    brief_text.text = story + "%s\n\n승리 목표: %s\n제한 시간: %s (기본 배속)\n\n권장 전략: %s\n\n첫 5분: 사전 작전 수행 / 이후: 전령 파견\n장수별 능력과 성향, 정찰 정보, 보급을 고려하십시오." % [sim.scenario_title,sim.scenario_goal,_operation_clock(sim.operation_limit()),tactic]
    brief_dialog.popup_centered()

func _open_analysis() -> void:
    analysis_dialog.popup_centered()
    analysis_chart.queue_redraw()

func _draw_history(canvas: Control) -> void:
    if korean_font == null:
        return
    canvas.draw_rect(Rect2(Vector2.ZERO,Vector2(620,300)),Color("#12222b"))
    var chart_rect := Rect2(48,45,540,195)
    for i in range(5):
        var y: float = chart_rect.position.y + chart_rect.size.y * float(i)/4.0
        canvas.draw_line(Vector2(48,y),Vector2(588,y),Color("#46575a"),1.0)
    canvas.draw_string(korean_font,Vector2(20,25),"아군 병력 / 적군 병력 (확인 가능한 기록)",HORIZONTAL_ALIGNMENT_LEFT,-1,14,COL_TEXT)
    var max_troops: float = 1.0
    var show_enemy: bool = not fog_enabled or sim.finished
    for sample in sim.troop_history:
        max_troops = maxf(max_troops,float(sample["blue"]))
        if show_enemy:
            max_troops = maxf(max_troops,float(sample["red"]))
    var prev_blue := Vector2.ZERO
    var prev_red := Vector2.ZERO
    var first: bool = true
    for sample in sim.troop_history:
        var x: float = 48.0 + 540.0*float(sample["time"])/maxf(1.0,sim.scenario_limit)
        var blue := Vector2(x,240.0-195.0*float(sample["blue"])/max_troops)
        var red := Vector2(x,240.0-195.0*float(sample["red"])/max_troops)
        if not first:
            canvas.draw_line(prev_blue,blue,COL_BLUE,2.5,true)
            if show_enemy:
                canvas.draw_line(prev_red,red,COL_RED,2.5,true)
        prev_blue = blue
        prev_red = red
        first = false
    canvas.draw_string(korean_font,Vector2(20,273),"아군 %d명 · 적군 %s" % [sim.total_troops(0),str(sim.total_troops(1)) if show_enemy else "미확인"],HORIZONTAL_ALIGNMENT_LEFT,-1,14,COL_GOLD)

func _minimap_rect() -> Rect2:
    return Rect2(MINIMAP_AREA.position,Vector2(MINIMAP_AREA.size.x,MINIMAP_AREA.size.x*sim.field_size.y/sim.field_size.x))

func _draw_minimap() -> void:
    var mini_rect := _minimap_rect()
    var origin: Vector2=mini_rect.position
    var factor: float=mini_rect.size.x/sim.field_size.x
    if terrain_cache != null:
        draw_texture_rect(terrain_cache,mini_rect,false)
    else:
        draw_rect(mini_rect,Color("#405641"))
    for unit in sim.units:
        if float(unit["troops"]) > 0.0 and _visible_unit(unit):
            draw_circle(origin+(unit["pos"] as Vector2)*factor,2.8,COL_BLUE if int(unit["side"]) == 0 else COL_RED)
    for site in sim.outposts:
        draw_circle(origin+(site["pos"] as Vector2)*factor,3.0,COL_GOLD,false,1.2)
    var visible_size: Vector2 = MAP_SIZE/camera_zoom
    var viewport := Rect2(origin+(camera_center-visible_size*0.5)*factor,visible_size*factor)
    draw_rect(viewport.intersection(mini_rect),COL_GOLD,false,1.4)
    draw_rect(mini_rect,Color("#9caa9b"),false,1.0)

func _draw_portrait(canvas: Control) -> void:
    var unit: Dictionary=sim.find_unit(observed_enemy_id if observing_enemy else selected_id)
    if unit.is_empty(): return
    canvas.draw_rect(Rect2(0,0,68,68),Color("#142427"))
    canvas.draw_texture_rect(_commander_icon(str(unit["name"]),int(unit["side"])),Rect2(1,1,66,66),false)
    canvas.draw_rect(Rect2(0,0,68,68),Color("#8d896e"),false,1.2)


func _draw_terrain_texture() -> void:
    # Small compass and a clean frame give orientation without repeated labels.
    # Compass stays at a constant screen size instead of growing with zoom.
    var offset: Vector2=MAP_SIZE*0.5-camera_center*camera_zoom
    map_layer.draw_set_transform(Vector2(MAP_SIZE.x-33,30),0.0,Vector2.ONE)
    map_layer.draw_circle(Vector2.ZERO,23,Color(0.08,0.12,0.13,0.72))
    map_layer.draw_arc(Vector2.ZERO,22,0.0,TAU,40,Color(COL_GOLD,0.65),1.0,true)
    for i in range(8):
        var d: Vector2=Vector2.from_angle(float(i)*TAU/8.0)
        map_layer.draw_line(d*18,d*21,Color(COL_GOLD,0.6),1.0,true)
    map_layer.draw_colored_polygon(PackedVector2Array([Vector2(0,-15),Vector2(-6,5),Vector2.ZERO,Vector2(6,5)]),COL_GOLD)
    _draw_string("N",Vector2(-4,14),10,COL_TEXT)
    map_layer.draw_set_transform(offset,0.0,Vector2.ONE*camera_zoom)

# Atlas rows: faction × infantry, archer, cavalry. Columns: profile, front, rear.
func _soldier_region(unit: Dictionary) -> Rect2:
    var kind: int = 1 if str(unit["type"])=="궁병" else (2 if str(unit["type"])=="기병" else 0)
    var direction: Vector2 = unit["facing"]
    var column: int = 0
    if absf(direction.y)>absf(direction.x)*1.10:
        column=1 if direction.y>0.0 else 2
    return Rect2(column*96,(int(unit["side"])*3+kind)*96,96,96)

# Read-only pose selection. Attack frames follow the actual emitted combat event.
# The sim clock freezes in pause; marching phase is scaled to operation time.
func _soldier_pose(unit: Dictionary, index: int, now: float) -> int:
    if not sim.started or sim.finished: return -1
    var kind: String = str(unit["type"])
    var moving: bool = float(unit.get("motion_speed",0.0))>2.0
    var routed: bool = bool(unit.get("routed",false))
    if not routed and now>=float(unit.get("last_hit",-100.0)) and now-float(unit.get("last_hit",-100.0))<0.09 and index%7==0:
        return 5
    var age: float = now-float(unit.get("last_visual",-100.0))
    var interval: float = 0.9 if kind=="궁병" else 0.55
    var engaged: bool = int(unit.get("contact_troops",0))>0
    if kind=="궁병" and float(unit.get("ammo",0.0))<=0.0: engaged=false
    if not routed and age>=0.0 and age<0.27:
        return 3 if age<0.11 else 4
    if not routed and engaged and age>=interval-0.19 and age<=interval+0.1:
        return 2
    if moving:
        var cadence: float = 7.0 if kind=="기병" else (4.8 if routed else 3.6)
        return posmod(floori(now*sim.operation_scale()*cadence+float(index%5)*0.23),2)
    return -1

func _soldier_motion_region(base: Rect2,pose: int) -> Rect2:
    return Rect2(base.position+Vector2(pose*288,0),base.size)

func _draw_soldier(p: Vector2, unit: Dictionary, accent: Color, index: int, target: Vector2=Vector2.INF) -> void:
    var direction: Vector2 = unit["facing"]
    if target!=Vector2.INF and not bool(unit["routed"]) and p.distance_squared_to(target)>0.1:
        direction=(target-p).normalized()
    var moving: bool = float(unit.get("motion_speed",0.0)) > 2.0 and sim.started and not sim.finished
    var kind: int = 1 if str(unit["type"])=="궁병" else (2 if str(unit["type"])=="기병" else 0)
    # The atlas uses a shared foot anchor. Taller silhouettes, compact lateral footprint.
    var extent: Vector2 = Vector2(13,18) if kind==2 else Vector2(9,13)
    if not sim.six_armies: extent*=1.25
    # Front and rear ranks no longer perform the same thrust on every tick.
    var visual_contact: bool=target!=Vector2.INF
    var delay: float=float(index%5)*0.026
    var pose: int = _soldier_pose(unit,index,render_clock-delay)
    if not visual_contact and pose in [2,3,4]: pose=-1
    var phase: float = render_clock*sim.operation_scale()*(13.0 if kind==2 else 9.0)+index*1.7
    var hit: bool = sim.battle_time-float(unit.get("last_hit",-100.0))<0.16 and index%4==0
    if moving:
        p+=direction*sin(phase)*(2.0 if kind==2 else 1.0)
        p.y+=sin(phase)*0.9
    if pose==3 and kind!=1 and visual_contact:
        p+=direction*(3.5 if kind==2 else 2.2)
    elif pose==2 and kind!=1: p-=direction*0.8
    if hit: p-=direction*1.0
    var variation: float=0.88+float(posmod(index*17+int(unit["id"])*7,11))*0.012
    var shade: Color = Color(1.0,0.78,0.70,accent.a) if hit else Color(variation,variation,variation,accent.a)
    var map_offset: Vector2 = MAP_SIZE*0.5-camera_center*camera_zoom
    # Shadow is separated from the art, so feet stay grounded and faction colors stay clear.
    if camera_zoom>=1.10:
        map_layer.draw_set_transform(map_offset+(p+Vector2(2.5,1.0))*camera_zoom,0.0,Vector2(1.0,0.45)*camera_zoom)
        map_layer.draw_circle(Vector2.ZERO,7.0 if kind==2 else 4.8,Color(0.04,0.05,0.035,0.30))
    var column: int=0
    if absf(direction.y)>absf(direction.x)*1.10: column=1 if direction.y>0.0 else 2
    var region: Rect2=Rect2(column*96,(int(unit["side"])*3+kind)*96,96,96)
    var mirror: float = -1.0 if region.position.x==0.0 and direction.x<0.0 else 1.0
    map_layer.draw_set_transform(map_offset+p*camera_zoom,0.0,Vector2(mirror,1.0)*camera_zoom)
    var art: Texture2D = SOLDIER_MOTION if pose>=0 else SOLDIER_ART
    var source: Rect2 = _soldier_motion_region(region,pose) if pose>=0 else region
    map_layer.draw_texture_rect_region(art,Rect2(Vector2(-extent.x*0.5,-extent.y*0.90),extent),source,shade)
    map_layer.draw_set_transform(map_offset,0.0,Vector2.ONE*camera_zoom)

# Aggregate real casualties, never invent floating damage from decorative effects.
func _sample_battle_losses() -> void:
    sample_time=sim.battle_time
    for u in sim.units:
        var id: int=int(u["id"])
        var total: float=float(u.get("casualties_taken",0.0))
        var previous: float=float(battle_samples.get(id,total))
        battle_samples[id]=total
        var change: int=roundi(maxf(0.0,total-previous))
        if change>0 and _visible_unit(u):
            recent_losses[id]={"count":change,"time":sim.battle_time,"pos":u["pos"],"side":u["side"]}
            _record_fallen(u,change)

# Non-graphic representative fallen soldiers derive only from measured casualties.
# Keep a remainder per unit so small losses accumulate instead of fabricating bodies.
func _record_fallen(u: Dictionary,change: int) -> void:
    var id: int=int(u["id"])
    var total: int=int(loss_carry.get(id,0))+change
    var count: int=mini(10,floori(float(total)/65.0))
    loss_carry[id]=total-count*65
    if count<=0: return
    var anchors: Array[Vector2]=sim.formation_slots(u)
    if anchors.is_empty(): anchors.append(u["pos"])
    for i in range(count):
        var k: int=posmod(sim.step_count*7+i*11+id*17,anchors.size())
        var p: Vector2=anchors[k]+Vector2.from_angle(float(k+i)*2.39996)*4.0
        if sim.terrain_at(p)=="하천": continue
        fallen_marks.append({"point":p,"side":u["side"],"kind":str(u["type"]),"angle":float(posmod(sim.step_count+i*47+id*13,628))/100.0})
    while fallen_marks.size()>480: fallen_marks.pop_front()

func _draw_fallen(view: Rect2) -> void:
    if camera_zoom<0.65: return
    var offset: Vector2=MAP_SIZE*0.5-camera_center*camera_zoom
    for entry in fallen_marks:
        var p: Vector2=entry["point"]
        if not view.has_point(p) or (fog_enabled and not sim.finished and not sim.player_can_see(p)): continue
        var side: int=int(entry["side"])
        var kind: int=1 if str(entry["kind"])=="궁병" else (2 if str(entry["kind"])=="기병" else 0)
        var region:=Rect2(0,(side*3+kind)*96,96,96)
        map_layer.draw_set_transform(offset+p*camera_zoom,float(entry["angle"]),Vector2.ONE*camera_zoom)
        map_layer.draw_texture_rect_region(SOLDIER_ART,Rect2(-6,-5,12,10),region,Color(0.57,0.55,0.48,0.70))
    map_layer.draw_set_transform(offset,0.0,Vector2.ONE*camera_zoom)

func _draw_loss_markers() -> void:
    if not sim.started or sim.finished or camera_zoom<0.70: return
    var offset: Vector2=MAP_SIZE*0.5-camera_center*camera_zoom
    for id in recent_losses:
        var item: Dictionary=recent_losses[id]
        var age: float=maxf(0.0,render_clock-float(item["time"]))
        if age>0.8: continue
        var u: Dictionary=sim.find_unit(id)
        if u.is_empty() or not _visible_unit(u): continue
        var p: Vector2=offset+(item["pos"] as Vector2)*camera_zoom+Vector2(22,-40-age*18)
        map_layer.draw_set_transform(p,0.0,Vector2.ONE)
        var caption: String="-"+_number_text(int(item["count"]))
        var color: Color=Color(COL_RED if int(item["side"])==0 else COL_GOLD,1.0-age*0.8)
        _draw_string(caption,Vector2(1,1),14,Color(0.04,0.05,0.04,color.a))
        _draw_string(caption,Vector2.ZERO,14,color)
    map_layer.draw_set_transform(offset,0.0,Vector2.ONE*camera_zoom)

func _draw_combat_effects() -> void:
    for fx in sim.visual_effects:
        var age: float = maxf(0.0,render_clock-float(fx["time"]))
        if age > 0.9:
            continue
        var p: Vector2 = fx["from"]
        var target: Vector2 = fx["to"]
        if fog_enabled and not sim.finished and not sim.player_can_see(p) and not sim.player_can_see(target):
            continue
        p=fx.get("visual_from",p)
        target=fx.get("visual_to",target)
        var alpha: float = clampf(1.0-age,0.0,1.0)
        match str(fx["kind"]):
            "화살":
                # One real volley event, several representative arrows; no extra damage.
                var direction: Vector2=(target-p).normalized()
                var lateral: Vector2=direction.orthogonal()
                for k in range(7):
                    var travel: float=clampf((age-float(k%3)*0.035)/0.48,0.0,1.0)
                    if age<float(k%3)*0.035 or travel>=1.0: continue
                    var spread: float=(float(k)-3.0)*3.3
                    var arrow: Vector2=p.lerp(target,travel)+lateral*spread+Vector2(0,-sin(travel*PI)*16.0)
                    var tail: Vector2=arrow-direction*9.0
                    map_layer.draw_line(tail,arrow,Color(0.22,0.18,0.12,alpha*0.8),1.8,true)
                    map_layer.draw_line(tail,arrow,Color(0.91,0.80,0.56,alpha),0.8,true)
                    map_layer.draw_line(arrow-direction*2.5+lateral*1.5,arrow,Color(0.95,0.93,0.80,alpha),1.0,true)
                if age>=0.48:
                    _paint_fx(1,target,22.0,alpha*0.65)
            "돌격":
                var contact: Vector2=p.lerp(target,0.70)
                _paint_fx(3,contact,34.0+age*22.0,alpha*0.65)
                for k in range(6):
                    var ray: Vector2=Vector2.from_angle(float(k)*TAU/6.0+float(fx["time"]))*(7.0+age*18.0)
                    map_layer.draw_line(contact+ray*0.6,contact+ray,Color(0.95,0.76,0.42,alpha*0.75),1.1,true)
            _:
                var impact: Vector2=(p+target)*0.5
                _paint_fx(4,impact,26.0,alpha*0.65)
                # Foot-level dust over actual contact; no new hit events.
                _paint_fx(3,impact+Vector2(0,3),18.0+age*24.0,alpha*0.28)
                for k in range(9):
                    var ray: Vector2=Vector2.from_angle(float(k)*TAU/9.0+float(fx["time"]))*(4.0+age*15.0)
                    map_layer.draw_line(impact+ray*0.45,impact+ray,Color(1.0,0.86,0.56,alpha*0.76),1.0,true)

func _setup_sound() -> void:
    sound_player = AudioStreamPlayer.new()
    sound_player.volume_db = -18.0
    add_child(sound_player)
    combat_sounds=BattleAudio.build()
    for i in range(4):
        var channel:=AudioStreamPlayer.new()
        channel.volume_db=-13.0
        add_child(channel)
        combat_players.append(channel)
    _setup_ambient_music()

func _toggle_sound() -> void:
    sound_enabled = not sound_enabled
    runtime_notice = "전장 음향 켜짐" if sound_enabled else "전장 음향 꺼짐"
    if not sound_enabled:
        sound_player.stop()
        for channel in combat_players: channel.stop()
        if is_instance_valid(music_player): music_player.stop()
    elif is_instance_valid(music_player):
        music_player.play()
    _refresh_hud()

func _play_cue(frequency: float, duration: float) -> void:
    if not sound_enabled or not is_instance_valid(sound_player):
        return
    var sample_rate: int = 16000
    var count: int = int(duration*sample_rate)
    var data := PackedByteArray()
    data.resize(count*2)
    for i in range(count):
        var t: float = float(i)/sample_rate
        var envelope: float = minf(1.0,t*80.0)*maxf(0.0,1.0-t/duration)
        var waveform: float = sin(TAU*frequency*t) + 0.22*sin(TAU*frequency*1.5*t)
        data.encode_s16(i*2,int(clampf(waveform*envelope*9000.0,-32767.0,32767.0)))
    var wav := AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = sample_rate
    wav.data = data
    sound_player.stream = wav
    sound_player.play()

func _play_combat_audio(fx: Dictionary) -> void:
    if not sound_enabled or combat_players.is_empty(): return
    var kind: String=str(fx["kind"])
    if not combat_sounds.has(kind): return
    var channel: AudioStreamPlayer=combat_players[combat_audio_cursor%combat_players.size()]
    combat_audio_cursor+=1
    var midpoint: Vector2=(fx["from"] as Vector2).lerp(fx["to"],0.5)
    var distance: float=camera_center.distance_to(midpoint)
    channel.volume_db=-10.0-clampf(distance/55.0,0.0,18.0)
    channel.pitch_scale=0.96+float(combat_audio_cursor%7)*0.014
    channel.stream=combat_sounds[kind]
    channel.play()

func _update_audio_and_warning() -> void:
    var warning: String = ""
    for unit in sim.units:
        if int(unit["side"]) != 0 or float(unit["troops"]) <= 0.0:
            continue
        if bool(unit["routed"]) or bool(unit["surrounded"]) or float(unit["rations"]) < 20.0:
            warning = "%s: %s" % [str(unit["name"]),"패주" if bool(unit["routed"]) else ("포위 위험" if bool(unit["surrounded"]) else "보급 부족")]
            break
    battle_warning=warning
    warning_label.text = warning
    if warning != "" and warning != last_warning:
        _play_cue(230.0,0.25)
        last_audio_clock = sim.battle_time
    last_warning = warning
    if sim.paused or sim.finished or sim.visual_effects.is_empty():
        return
    var fx: Dictionary = sim.visual_effects.back()
    if float(fx["time"]) > last_audio_event:
        last_audio_event = float(fx["time"])
        if sim.battle_time-last_audio_clock > 0.23 and (not fog_enabled or sim.player_can_see(fx["from"])):
            _play_combat_audio(fx)
            last_audio_clock = sim.battle_time

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if is_instance_valid(order_view) and order_view.visible: return
        if event.keycode >= KEY_1 and event.keycode <= KEY_6 and not title_screen.visible and not strategy_view.visible:
            var index: int = int(event.keycode-KEY_1)
            if index < unit_list.item_count:
                unit_list.select(index)
                _on_unit_selected(index)
                _focus_selected()
            return
        match event.keycode:
            KEY_SPACE: _pause()
            KEY_PLUS, KEY_EQUAL: _change_zoom(0.25)
            KEY_MINUS: _change_zoom(-0.25)
            KEY_F: _focus_selected()
            KEY_C: _focus_combat()
            KEY_G: _open_mind_report()
            KEY_J: _open_journal()
            KEY_V: _toggle_fog(not fog_enabled)
            KEY_HOME: _reset_camera()
            KEY_B: _open_briefing()
            KEY_A: _open_analysis()

func _art_region(tile: int) -> Rect2:
    return Rect2(float(tile%8)*128.0,float(floori(float(tile)/8.0))*128.0,128,128)

func _fx_region(tile: int) -> Rect2:
    return Rect2(float(tile%4)*128.0,float(floori(float(tile)/4.0))*128.0,128,128)

func _paint_tile(tile: int, rect: Rect2, tint: Color = Color.WHITE) -> void:
    map_layer.draw_texture_rect_region(PAINTED_ART,rect,_art_region(tile),tint)

func _paint_fx(tile: int, center: Vector2, extent: float, alpha: float) -> void:
    map_layer.draw_texture_rect_region(PAINTED_FX,Rect2(center-Vector2.ONE*extent*0.5,Vector2.ONE*extent),_fx_region(tile),Color(1,1,1,alpha))

func _paint_terrain(area: Rect2, tile: int, step: float) -> void:
    var y: float = area.position.y
    while y < area.end.y-0.01:
        var x: float = area.position.x
        while x < area.end.x-0.01:
            var extent := Vector2(minf(step,area.end.x-x),minf(step,area.end.y-y))
            var source: Rect2 = _art_region(tile)
            source.size = extent/step*128.0
            map_layer.draw_texture_rect_region(PAINTED_ART,Rect2(Vector2(x,y),extent),source,Color(0.84,0.84,0.78))
            x += step
        y += step

func _portrait_index(name: String) -> int:
    match name:
        "마속": return 1
        "위연": return 2
        "장합": return 3
        _: return 0

func _build_title_screen() -> void:
    title_screen=Control.new()
    title_screen.size=Vector2(1280,800)
    add_child(title_screen)
    var background := ColorRect.new()
    background.color=COL_BG
    background.size=title_screen.size
    title_screen.add_child(background)
    var art := TextureRect.new()
    art.texture=TITLE_ART
    art.position=Vector2(598,0)
    art.size=Vector2(682,800)
    art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art.mouse_filter=Control.MOUSE_FILTER_IGNORE
    title_screen.add_child(art)
    var blend := Gradient.new()
    blend.colors=PackedColorArray([COL_BG,Color(COL_BG,0)])
    var texture := GradientTexture2D.new()
    texture.gradient=blend
    texture.width=196
    texture.height=2
    var seam := TextureRect.new()
    seam.texture=texture
    seam.position=art.position
    seam.size=Vector2(196,800)
    seam.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    seam.mouse_filter=Control.MOUSE_FILTER_IGNORE
    title_screen.add_child(seam)
    var heading := _label("군략",Vector2(82,107),Vector2(440,104),77,COL_TEXT)
    heading.reparent(title_screen,false)
    var sub := _label("삼국지 군단 지휘",Vector2(88,218),Vector2(420,28),21,COL_GOLD)
    sub.reparent(title_screen,false)
    _title_button("새 북벌 캠페인",Vector2(88,288),Vector2(428,56),_begin_campaign,true)
    _title_button("캠페인 이어하기",Vector2(88,355),Vector2(428,50),_continue_campaign)
    _title_button("단독 전투",Vector2(88,416),Vector2(428,50),_leave_title)
    _title_button("전장 브리핑",Vector2(88,517),Vector2(208,43),_title_brief)
    _title_button("도움말 / 조작",Vector2(308,517),Vector2(208,43),_open_demo_help)
    _title_button("음향 전환",Vector2(88,571),Vector2(208,43),_toggle_sound)
    _title_button("종료",Vector2(308,571),Vector2(208,43),_quit_game)
    var version := _label(str(ProjectSettings.get_setting("application/config/version")),Vector2(88,730),Vector2(210,21),12,COL_MUTED)
    version.reparent(title_screen,false)
    title_screen.show()

func _title_button(caption: String, position: Vector2, extent: Vector2, callback: Callable, primary: bool=false) -> void:
    var button := _button(caption,position,extent,callback)
    button.reparent(title_screen,false)
    button.alignment=HORIZONTAL_ALIGNMENT_LEFT
    button.add_theme_font_size_override("font_size",18)
    if primary: _primary_button(button)

func _show_title() -> void:
    if is_instance_valid(order_view): order_view.hide()
    if is_instance_valid(strategy_view): strategy_view.hide()
    if is_instance_valid(outcome_dialog): outcome_dialog.hide()
    if sim.started and not sim.finished:
        sim.paused = true
    title_screen.show()
    move_child(title_screen,get_child_count()-1)

func _leave_title() -> void:
    campaign_active = false
    if is_instance_valid(strategy_view): strategy_view.hide()
    sim.reset()
    sim.set_scenario(0)
    _reset()
    title_screen.hide()
    _open_order_map()

func _title_brief() -> void:
    _leave_title()
    _open_briefing()

func _quit_game() -> void:
    get_tree().quit()

func _build_outcome_dialog() -> void:
    outcome_dialog = Control.new()
    outcome_dialog.size = Vector2(1280,800)
    add_child(outcome_dialog)
    var veil := ColorRect.new()
    veil.size = outcome_dialog.size
    veil.color = Color(0.06,0.06,0.05,0.78)
    outcome_dialog.add_child(veil)
    var panel := Panel.new()
    panel.position = Vector2(250,103)
    panel.size = Vector2(780,594)
    panel.add_theme_stylebox_override("panel",_ui_box(COL_PANEL,COL_LINE))
    outcome_dialog.add_child(panel)
    var layout := VBoxContainer.new()
    layout.position = Vector2(28,20)
    layout.size = Vector2(724,554)
    layout.add_theme_constant_override("separation",10)
    panel.add_child(layout)
    outcome_heading = Label.new()
    outcome_heading.add_theme_font_size_override("font_size",32)
    outcome_heading.add_theme_color_override("font_color",COL_GOLD)
    layout.add_child(outcome_heading)
    outcome_text = Label.new()
    outcome_text.add_theme_font_size_override("font_size",14)
    layout.add_child(outcome_text)
    var comparison := RenderLayer.new()
    comparison.custom_minimum_size = Vector2(724,68)
    comparison.painter = _draw_outcome_comparison
    layout.add_child(comparison)
    outcome_comparison = comparison
    var rule := HSeparator.new()
    layout.add_child(rule)
    var section := Label.new()
    section.text = "장수별 전과 및 피해"
    section.add_theme_font_size_override("font_size",18)
    section.add_theme_color_override("font_color",COL_GOLD)
    layout.add_child(section)
    outcome_cards = VBoxContainer.new()
    outcome_cards.add_theme_constant_override("separation",7)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(724,300)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    layout.add_child(scroll)
    outcome_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(outcome_cards)
    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation",8)
    layout.add_child(buttons)
    var close := Button.new()
    close.text = "전장으로"
    close.custom_minimum_size = Vector2(168,38)
    close.pressed.connect(func():
        if campaign_active: _advance_campaign()
        else: outcome_dialog.hide())
    buttons.add_child(close)
    var analysis := Button.new()
    analysis.text = "전투 분석"
    analysis.custom_minimum_size = Vector2(168,38)
    analysis.pressed.connect(_outcome_analysis)
    buttons.add_child(analysis)
    campaign_next = Button.new()
    campaign_next.text = "다음 전투 준비"
    campaign_next.custom_minimum_size = Vector2(230,38)
    _primary_button(campaign_next)
    campaign_next.pressed.connect(_advance_campaign)
    buttons.add_child(campaign_next)
    outcome_dialog.hide()

func _show_outcome() -> void:
    outcome_heading.text = ("승전  /  " if sim.winning_side == 0 else "패전  /  ") + sim.result
    outcome_heading.add_theme_font_size_override("font_size",25)
    outcome_heading.add_theme_color_override("font_color",COL_GOLD if sim.winning_side == 0 else COL_RED)
    outcome_text.text = "%s  /  %s  /  전령 도착 %d · 차단 %d\n긴급 지시 수락 %d · 거부 %d" % [sim.scenario_title,_operation_clock(sim.operation_elapsed()),sim.delivered_orders,sim.intercepted_orders,sim.tactical_delivered,sim.tactical_refused]
    if campaign_active:
        if not battle_recorded:
            battle_recorded = campaign.conclude(sim)
            campaign.save()
        outcome_text.text += "  /  전략 %d턴" % int(campaign.state["turn"])
    for child in outcome_cards.get_children():
        outcome_cards.remove_child(child)
        child.queue_free()
    for unit in sim.units:
        if int(unit["side"]) != 0 or not int(unit["id"]) in sim.command_ids(0):
            continue
        var card := PanelContainer.new()
        card.add_theme_stylebox_override("panel",_ui_box(Color("#243442"),COL_LINE))
        outcome_cards.add_child(card)
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation",12)
        card.add_child(row)
        var portrait_image := TextureRect.new()
        portrait_image.texture = _commander_icon(str(unit["name"]),0)
        portrait_image.custom_minimum_size = Vector2(61,61)
        portrait_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        portrait_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        row.add_child(portrait_image)
        var info := VBoxContainer.new()
        info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(info)
        var name_label := Label.new()
        name_label.text = "%s  ·  %s  ·  %d명 생존" % [str(unit["name"]),str(unit["general_state"]),int(unit["troops"])]
        name_label.add_theme_font_size_override("font_size",17)
        name_label.add_theme_color_override("font_color",COL_GOLD)
        info.add_child(name_label)
        var stats := Label.new()
        var corps: Dictionary = sim.corps_report(int(unit["id"]))
        name_label.text = "%s · %s · 군단 %d명 생존" % [str(unit["name"]),str(unit["general_state"]),int(corps["troops"])]
        stats.text = "피해 %d   손실 %d   이탈 %d   판단 %d   공적 %d" % [int(corps["damage_dealt"]),int(corps["casualties_taken"]),int(corps["deserted"]),int(corps["decisions"]),int(corps["merit"])]
        stats.add_theme_font_size_override("font_size",14)
        info.add_child(stats)
    campaign_next.visible = campaign_active
    campaign_next.text = "전략 지도로 돌아가기"
    outcome_comparison.queue_redraw()
    outcome_dialog.show()

func _draw_fortifications() -> void:
    for structure in sim.structures:
        var area: Rect2 = structure["rect"]
        var hp: float = float(structure["hp"])
        var ratio: float = hp/maxf(1.0,float(structure["max_hp"]))
        map_layer.draw_rect(area.grow(4.0),Color(0.12,0.10,0.08,0.36))
        if hp <= 0.0:
            map_layer.draw_rect(area,Color("#584b37"))
            _draw_string("파괴",area.get_center()+Vector2(-14,0),10,COL_MUTED)
            continue
        var tile: int = 46 if str(structure["kind"]) == "성문" else 47
        var cursor: float = area.position.y
        while cursor < area.end.y:
            var h: float = minf(25.0,area.end.y-cursor)
            _paint_tile(tile,Rect2(area.position.x-5.0,cursor,area.size.x+10.0,h),Color(1.0,0.75+ratio*0.25,0.55+ratio*0.45))
            cursor += h
        var p: Vector2 = area.get_center()
        map_layer.draw_rect(Rect2(p+Vector2(-19,-10),Vector2(38,4)),Color("#332a1d"))
        map_layer.draw_rect(Rect2(p+Vector2(-19,-10),Vector2(38*ratio,4)),COL_GOLD)
        _draw_string(str(structure["name"]),p+Vector2(-25,-16),10,COL_TEXT)

func _begin_campaign() -> void:
    if is_instance_valid(order_view): order_view.hide()
    campaign.reset()
    campaign_active = true
    _clear_journal()
    fallen_marks.clear()
    loss_carry.clear()
    battle_warning=""
    contact_cache.clear()
    contact_cache_step=-1
    sector_selection=-1
    battle_recorded = false
    title_screen.hide()
    strategy_view.show()
    strategy_view.refresh()

func _advance_campaign() -> void:
    if not campaign_active or not sim.finished:
        return
    outcome_dialog.hide()
    strategy_view.show()
    strategy_view.refresh()

func _rebuild_terrain() -> void:
    if terrain_cache != null and terrain_scenario == sim.scenario_id:
        return
    var key: String="%s/%d" % [str(sim.field_size),sim.scenario_id]
    if not terrain_variants.has(key):
        if terrain_variants.size()>=2: terrain_variants.erase(terrain_variants.keys()[0])
        var layers: Dictionary={"separate_trees":true}
        var ground: ImageTexture=TerrainArt.battlefield(sim.field_size,sim.forests,sim.hill,sim.scenario_id,sim.layout_scale,layers)
        terrain_variants[key]={"ground":ground,"trees":layers["trees"],"textures":layers["textures"]}
    var variant: Dictionary=terrain_variants[key]
    terrain_cache=variant["ground"]
    forest_instances=variant["trees"]
    forest_textures=variant["textures"]
    terrain_scenario = sim.scenario_id

func _blend_land(target: Image, source: Image, area: Rect2, feather: float, kind: int) -> void:
    var x0: int = maxi(0,int(floor(area.position.x)))
    var y0: int = maxi(0,int(floor(area.position.y)))
    var x1: int = mini(target.get_width(),int(ceil(area.end.x)))
    var y1: int = mini(target.get_height(),int(ceil(area.end.y)))
    var center: Vector2 = area.get_center()
    for y in range(y0,y1):
        for x in range(x0,x1):
            var point := Vector2(float(x),float(y))
            var edge: float = minf(minf(point.x-area.position.x,area.end.x-point.x),minf(point.y-area.position.y,area.end.y-point.y))
            var noise: float = sin(float(x)*0.082+float(y)*0.037)*4.5+sin(float(x)*0.037-float(y)*0.093)*3.0
            if kind == 1:
                var curve: float = sin(float(x)*0.014)*3.5+sin(float(x)*0.034)*1.8
                edge = area.size.y*0.5-absf(point.y-center.y-curve)
                noise *= 0.25
            else:
                var norm: Vector2 = (point-center)/(area.size*0.5)
                # Round the corners while retaining the simulation region's core.
                var radius: float = pow(pow(absf(norm.x),4.0)+pow(absf(norm.y),4.0),0.25)
                edge = minf(edge,(1.0-radius)*minf(area.size.x,area.size.y)*0.5)
            var weight: float = smoothstep(0.0,feather,edge+noise)
            if weight <= 0.001:
                continue
            var sx: int = posmod(int(float(x)*0.92),source.get_width())
            var sy: int = posmod(int(float(y)*0.92),source.get_height())
            var overlay: Color = source.get_pixel(sx,sy)
            if kind == 2:
                overlay = overlay.darkened(0.10)
            elif kind == 3:
                overlay = overlay.lerp(Color("#847658"),0.12)
            target.set_pixel(x,y,target.get_pixel(x,y).lerp(overlay,weight))

func _draw_outcome_comparison(canvas: Control) -> void:
    var blue: int = sim.total_troops(0)
    var red: int = sim.total_troops(1)
    var peak: float = maxf(1.0,maxf(float(blue),float(red)))
    canvas.draw_string(korean_font,Vector2(0,16),"아군 잔여 %d명" % blue,HORIZONTAL_ALIGNMENT_LEFT,-1,15,COL_BLUE)
    canvas.draw_string(korean_font,Vector2(0,51),"적군 잔여 %d명" % red,HORIZONTAL_ALIGNMENT_LEFT,-1,15,COL_RED)
    canvas.draw_rect(Rect2(192,4,510,15),Color("#121c1f"))
    canvas.draw_rect(Rect2(192,4,510*float(blue)/peak,15),COL_BLUE)
    canvas.draw_rect(Rect2(192,39,510,15),Color("#121c1f"))
    canvas.draw_rect(Rect2(192,39,510*float(red)/peak,15),COL_RED)

func _outcome_analysis() -> void:
    outcome_dialog.hide()
    _open_analysis()

func _launch_campaign_battle(target: int) -> bool:
    if highlight_active: _stop_highlight("전장 변경",false)
    if not campaign.prepare(target,sim):
        return false
    campaign_active = true
    battle_recorded = false
    strategy_view.hide()
    title_screen.hide()
    _rebuild_terrain()
    _reset_camera()
    finish_seen = false
    last_audio_event = -1.0
    last_warning = ""
    map_mode = "선택"
    selected_id = 0
    step_buffer = 0.0
    runtime_notice = ""
    _refresh_unit_list()
    _select_unit()
    _refresh_hud()
    queue_redraw()
    _open_order_map()
    return true

func _continue_campaign() -> void:
    if campaign.load_save():
        campaign_active = true
        title_screen.hide()
        strategy_view.show()
        strategy_view.refresh()
    else:
        runtime_notice = "저장된 캠페인이 없습니다."
        var dialog := AcceptDialog.new()
        dialog.dialog_text = runtime_notice
        add_child(dialog)
        dialog.confirmed.connect(dialog.queue_free)
        dialog.popup_centered()

func _portrait_tile(name: String) -> int:
    if name in ["왕평","마속","위연","장합"]:
        return 8+_portrait_index(name)
    return 0


func _build_demo_help() -> void:
    tutorial_dialog = AcceptDialog.new()
    tutorial_dialog.title = "군략 · 첫 출전 안내"
    tutorial_dialog.ok_button_text = "확인"
    tutorial_dialog.dialog_text = "0. 기본 전체 시야: 아군/적군 탭에서 양 진영 활동과 병력을 확인합니다. C: 최근 교전 위치, V: 정찰 시야 전환.\n1. 전략 지도에서 인접 지역을 선택합니다. 군량 55가 필요합니다.\n2. 장수 등용, 병력 보충, 병과 편성을 완료한 뒤 출전합니다.\n3. 종이 작전 지도에서 부대 말·목적지·행동·연계 대상을 지정합니다.\n4. 기본 배속 전투는 약 25분. 장수는 자율적으로 판단하며 5분 경과 후 전령 파견 가능. 긴급 보고를 열어 지원·사수·재집결·철수 지시를 내릴 수 있습니다.\n5. 숫자 1~6 장수 선택, Space 일시정지, 휠 확대, 방향키/가운데 마우스 이동. F는 장수 중심.\n6. 전투 결산 후 전략 지도로 복귀합니다. 승리·패배·생존 병력과 장수 상태가 유지됩니다.\n7. 철수는 패배로 계산하되 현재 병력을 보존합니다. 전략 지도에서 저장 가능.\n8. 입문 난이도는 적 전력을 줄입니다. 캠페인은 천수 확보 또는 3패로 종료합니다."
    add_child(tutorial_dialog)
    retreat_dialog = ConfirmationDialog.new()
    retreat_dialog.title = "전투 철수"
    retreat_dialog.dialog_text = "현재 병력을 보존하고 전투를 패배로 종료하시겠습니까?"
    retreat_dialog.ok_button_text = "철수"
    retreat_dialog.cancel_button_text = "계속 전투"
    retreat_dialog.confirmed.connect(_confirm_retreat)
    add_child(retreat_dialog)

func _open_demo_help() -> void:
    tutorial_dialog.popup_centered(Vector2i(740,330))

func _ask_retreat() -> void:
    if sim.started and not sim.finished:
        retreat_dialog.popup_centered()
    else:
        runtime_notice = "진행 중인 전투에서 철수할 수 있습니다."
        _refresh_hud()

func _confirm_retreat() -> void:
    if sim.order_retreat() and not finish_seen:
        finish_seen = true
        _show_outcome()

# Original synthesized ambient motif, not a sampled or licensed music track.
func _setup_ambient_music() -> void:
    music_player = AudioStreamPlayer.new()
    music_player.volume_db = -28.0
    add_child(music_player)
    var rate: int = 12000
    var length: float = 12.0
    var count: int = int(float(rate)*length)
    var pcm := PackedByteArray()
    pcm.resize(count*2)
    var notes: Array[float] = [146.83,196.0,220.0,196.0,164.81,146.83,110.0,130.81]
    for i in range(count):
        var t: float = float(i)/float(rate)
        var idx: int = mini(7,floori(t/1.5))
        var local: float = fmod(t,1.5)
        var env: float = minf(1.0,local*12.0)*exp(-local*2.5)
        var freq: float = notes[idx]
        var drone: float = sin(TAU*73.415*t)*0.14
        var voice: float = (sin(TAU*freq*local)+0.35*sin(TAU*freq*2.0*local))*env*0.40
        var seam: float = minf(1.0,minf(t,length-t)*4.0)
        pcm.encode_s16(i*2,int(clampf((drone+voice)*seam*18000.0,-32767.0,32767.0)))
    var wav := AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = rate
    wav.data = pcm
    wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
    wav.loop_begin = 0
    wav.loop_end = count
    music_player.stream = wav
    music_player.play()


func _build_situations() -> void:
    situation_dialog = AcceptDialog.new()
    situation_dialog.title = "책사 지휘실 · 긴급 전황"
    situation_dialog.ok_button_text = "전장 복귀"
    situation_dialog.confirmed.connect(_close_situations)
    situation_dialog.canceled.connect(_close_situations)
    add_child(situation_dialog)
    var layout := VBoxContainer.new()
    layout.custom_minimum_size = Vector2(640,320)
    layout.add_theme_constant_override("separation",9)
    situation_dialog.add_child(layout)
    situation_list = ItemList.new()
    situation_list.custom_minimum_size = Vector2(620,120)
    situation_list.item_selected.connect(_select_situation)
    layout.add_child(situation_list)
    situation_detail = Label.new()
    situation_detail.custom_minimum_size = Vector2(620,100)
    situation_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(situation_detail)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation",8)
    layout.add_child(row)
    for order in ["사수","재집결","지원","철수","현장 판단"]:
        var btn := Button.new()
        btn.text = order
        btn.custom_minimum_size = Vector2(112,36)
        btn.pressed.connect(_respond_situation.bind(order))
        row.add_child(btn)
        situation_options.append(btn)

func _open_situations() -> void:
    if not sim.started or sim.finished:
        return
    situation_pause_before = sim.paused
    sim.paused = true
    situation_notice = ""
    situation_selected = -1
    _refresh_situations()
    situation_dialog.popup_centered()

func _close_situations() -> void:
    if sim.started and not sim.finished:
        sim.paused = situation_pause_before
    _refresh_hud()

func _refresh_situations() -> void:
    situation_list.clear()
    situation_ids.clear()
    for report in sim.open_situations():
        situation_ids.append(int(report["id"]))
        situation_list.add_item("%s  |  %.0f초 남음" % [report["title"],maxf(0.0,float(report["expires"])-sim.battle_time)*sim.operation_scale()])
    if situation_ids.is_empty():
        situation_selected = -1
        situation_detail.text = "현재 대응할 긴급 보고가 없습니다.\n보고는 장수의 실제 상태를 기반으로 지연 수신됩니다.\n"+situation_notice
    else:
        var index: int = situation_ids.find(situation_selected)
        if index < 0: index = 0
        situation_list.select(index)
        _select_situation(index)
    for btn in situation_options:
        btn.disabled = situation_selected < 0 or (btn.text != "현장 판단" and (sim.turn < 6 or sim.command_points <= 0))

func _select_situation(index: int) -> void:
    if index < 0 or index >= situation_ids.size():
        return
    situation_selected = situation_ids[index]
    for report in sim.open_situations():
        if int(report["id"]) != situation_selected:
            continue
        var context: String = ""
        match str(report["kind"]):
            "포위 위험": context = "지원군을 보내 퇴로를 확보하거나 철수로 병력을 보존하십시오."
            "전열 붕괴 위험": context = "재집결은 응집과 피로 회복에 유리하나 전선을 양보할 수 있습니다."
            "군량 부족": context = "철수 또는 재집결로 생존을 도모하십시오. 사수는 소모를 계속 감수합니다."
            "명령 이탈": context = "독자 판단을 허용하거나 긴급 사수 지시로 작전을 수정할 수 있습니다."
            _: context = "지정 위치 사수 또는 가까운 아군의 지원을 선택하십시오."
        var officer: Dictionary=sim.find_unit(int(report["unit_id"]))
        var mind: Dictionary=officer.get("mind",{})
        situation_detail.text = "%s\n%s\n장수 건의: %s · 현재 %s\n긴급 지휘력 %d/4 · 전령 전달 · 6턴 이전에는 관찰만 가능\n%s" % [report["title"],context,str(report.get("proposal","없음")),str(mind.get("mood","미확인")),sim.command_points,situation_notice]
        break

func _respond_situation(order: String) -> void:
    if situation_selected < 0:
        return
    if sim.respond_situation(situation_selected,order):
        situation_notice = "대응 기록: "+order
    else:
        situation_notice = "지시 불가: 지휘력·중복 전령·지원 가능 부대를 확인하십시오."
    _refresh_situations()
    _refresh_hud()

func _primary_button(btn: Button) -> void:
    btn.add_theme_stylebox_override("normal",_ui_box(COL_ACTIVE))
    btn.add_theme_stylebox_override("hover",_ui_box(Color("#be503c")))
    btn.add_theme_stylebox_override("pressed",_ui_box(Color("#853022")))

func _map_plate(value: String,p: Vector2,accent: Color,fs: int) -> void:
    var pixel_font: int = clampi(roundi(float(fs)*camera_zoom),12,14)
    var w: float = korean_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixel_font).x+14.0
    var origin: Vector2 = MAP_SIZE*0.5-camera_center*camera_zoom
    map_layer.draw_set_transform(origin+p*camera_zoom,0.0,Vector2.ONE)
    var rect := Rect2(Vector2(-w*0.5,-12),Vector2(w,21))
    var world_rect:=Rect2(p+rect.position/camera_zoom,rect.size/camera_zoom)
    var view:=Rect2(camera_center-MAP_SIZE*0.5/camera_zoom,MAP_SIZE/camera_zoom)
    var blocked: bool=not view.encloses(world_rect)
    for prior in map_label_areas:
        if prior.grow(3.0/camera_zoom).intersects(world_rect): blocked=true
    if blocked:
        map_layer.draw_set_transform(origin,0.0,Vector2.ONE*camera_zoom)
        return
    map_label_areas.append(world_rect)
    map_layer.draw_rect(rect,Color(0.07,0.10,0.09,0.86))
    map_layer.draw_rect(Rect2(rect.position,Vector2(2,21)),accent)
    _draw_string(value,Vector2(-w*0.5+7,3),pixel_font,COL_TEXT)
    map_layer.draw_set_transform(origin,0.0,Vector2.ONE*camera_zoom)

func _refresh_visibility() -> void:
    # Only an indication of the same actual player visibility used for unit disclosure.
    # Cached low-resolution mask; no simulation advantage from rendering.
    var image := Image.create_empty(90,57,false,Image.FORMAT_RGBA8)
    for y in range(57):
        for x in range(90):
            var p: Vector2 = Vector2((float(x)+0.5)/90.0,(float(y)+0.5)/57.0)*sim.field_size
            var visible_now: bool = sim.player_can_see(p)
            image.set_pixel(x,y,Color(0.025,0.045,0.045,0.0 if visible_now else 0.43))
    visibility_texture = ImageTexture.create_from_image(image)
    visibility_stamp = sim.battle_time

# More visible soldiers per actual manpower, with separate ranks and spacing.
# Contact simulation retains twelve authoritative tactical slots per detachment.
func _visual_slots(unit: Dictionary) -> Array[Vector2]:
    if sim.six_armies:
        # Visual detail uses the same formation geometry; combat still uses authoritative slots.
        var count: int=clampi(ceili(float(unit["troops"])/65.0),1,72)
        return sim.representative_slots(unit,count)
    var result: Array[Vector2] = []
    var count: int = clampi(ceili(float(unit["troops"])/3.0),1,64)
    var front: Vector2 = unit["facing"]
    if front.length_squared() < 0.01: front = Vector2.RIGHT
    front = front.normalized()
    var side: Vector2 = front.orthogonal()
    var files: int = mini(count,8)
    if str(unit["formation"]) == "종대": files = mini(count,4)
    elif str(unit["formation"]) == "방진": files = maxi(1,ceili(sqrt(float(count))))
    var ranks: int = ceili(float(count)/float(files))
    var spacing: float = 13.5 if str(unit["type"]) == "기병" else 11.5
    var center: Vector2 = unit["pos"]
    for i in range(count):
        var rank: int = floori(float(i)/float(files))
        var width: int = mini(files,count-rank*files)
        var file: int = i%files
        var lateral: float = (float(file)-float(width-1)*0.5)*spacing
        var depth: float = (float(rank)-float(ranks-1)*0.5)*spacing*0.95
        result.append(center+side*lateral-front*depth)
    return result

func _draw_march_dust(view: Rect2) -> void:
    if dust_texture == null or camera_zoom < 0.60: return
    for puff in sim.dust_effects:
        var p: Vector2 = puff["pos"]
        if not view.grow(50.0).has_point(p): continue
        if fog_enabled and not sim.finished and int(puff["side"])!=0 and not sim.player_can_see(p): continue
        var age: float = clampf((sim.battle_time-float(puff["time"]))/WarSim.DUST_LIFE,0.0,1.0)
        var radius: float = float(puff["radius"])*(0.70+age*1.35)
        var direction: Vector2 = puff["dir"]
        p -= direction*age*16.0
        p += direction.orthogonal()*float(puff["phase"])*age*6.0
        var opacity: float = (1.0-age)*(1.0-age)*0.68
        map_layer.draw_texture_rect(dust_texture,Rect2(p-Vector2(radius,radius*0.67),Vector2(radius*2.0,radius*1.34)),false,Color(1.0,0.96,0.86,opacity))

func _scenery_tile(tile: int,rect: Rect2,tint: Color=Color.WHITE) -> void:
    var source:=Rect2((tile%3)*256,floori(float(tile)/3.0)*256,256,256)
    map_layer.draw_texture_rect_region(SCENERY_ART,rect,source,tint)

func _draw_river_detail() -> void:
    var top: float = maxf(0.0,camera_center.y-MAP_SIZE.y*0.5/camera_zoom)
    var bottom: float = minf(sim.field_size.y,camera_center.y+MAP_SIZE.y*0.5/camera_zoom)
    # Fine animated surface streaks stay within the existing river collision boundary.
    for y in range(int(top/12.0)*12,int(bottom)+12,12):
        if sim.near_crossing(float(y)): continue
        var rx: float=sim.river_x(float(y))
        for lane in range(4):
            var offset: float=-19.0+float(lane)*12.0
            var shift: float=sin(float(y)*0.21+float(lane)*3.7+render_clock*1.4)*4.5
            var q:=Vector2(rx+offset,float(y)+shift)
            var alpha: float=0.08+0.11*(0.5+0.5*sin(float(y)*0.13+lane+render_clock*2.1))
            var points:=PackedVector2Array([q,q+Vector2(2,3),q+Vector2(1,7)])
            map_layer.draw_polyline(points,Color(0.78,0.90,0.84,alpha),0.8,true)
        for bank in [-1.0,1.0]:
            var q:=Vector2(rx+bank*24.0,float(y))
            var next:=Vector2(sim.river_x(float(y)+8.0)+bank*24.0,float(y)+8.0)
            map_layer.draw_line(q,next,Color(0.87,0.90,0.76,0.14+0.12*sin(float(y)*0.19+render_clock)),1.3,true)

func _draw_bridge(p: Vector2) -> void:
    # Texture aligns the walkable deck to the existing 76-unit north/south opening.
    # Rails, supports and shadows are visual only, not new collision objects.
    map_layer.draw_texture_rect(BRIDGE_HQ,Rect2(p-Vector2(58,58),Vector2(116,116)),false)

func _draw_cooperation_links() -> void:
    var unit: Dictionary=sim.find_unit(selected_id)
    if unit.is_empty() or not sim.started: return
    if str(unit["mission"]) not in ["전열 엄호","측후방 기동","구원 지원"]: return
    var ally: Dictionary=sim.find_unit(int(unit.get("link_id",-1)))
    if ally.is_empty() or float(ally["troops"])<=0.0: return
    var p: Vector2=unit["pos"]
    var q: Vector2=ally["pos"]
    var k: float=1.0/camera_zoom
    var d: float=p.distance_to(q)
    var direction: Vector2=(q-p).normalized()
    for i in range(0,int(d),int(maxf(14.0,18.0*k))):
        var end: float=minf(float(i)+8.0*k,d)
        map_layer.draw_line(p+direction*float(i),p+direction*end,Color(COL_BLUE,0.65),1.7*k,true)
    var goal: Vector2=unit["goal"]
    map_layer.draw_line(p,goal,Color(COL_GOLD,0.65),1.5*k,true)
    map_layer.draw_arc(goal,9.0*k,0,TAU,24,COL_GOLD,1.5*k,true)

func _bridge_name(y: float) -> String:
    if y<600.0: return "북측 교량"
    if y>1100.0: return "남측 교량"
    return "중앙 교량"

# Display the actual committed crossing for the selected friendly army only.
func _draw_selected_bridge_route() -> void:
    if not sim.started or sim.finished or not sim.long_operation: return
    var unit: Dictionary = sim.find_unit(selected_id)
    if unit.is_empty() or int(unit["side"])!=0 or float(unit["troops"])<=0.0: return
    var bridge: float = float(unit.get("bridge_y",-1.0))
    if bridge<0.0: return
    var p: Vector2 = unit["pos"]
    var k: float = 1.0/camera_zoom
    for point in sim.committed_route_preview(unit):
        var delta: Vector2 = point-p
        var length: float = delta.length()
        if length>0.1:
            var direction: Vector2 = delta/length
            var offset: float = 0.0
            while offset<length:
                map_layer.draw_line(p+direction*offset,p+direction*minf(offset+10.0*k,length),Color(COL_GOLD,0.65),1.8*k,true)
                offset+=19.0*k
        p=point
    var crossing:=Vector2(sim.river_x(bridge),bridge)
    map_layer.draw_arc(crossing,14.0*k,0,TAU,30,COL_GOLD,2.0*k,true)
    _map_plate(_bridge_name(bridge)+" · 도하 예정",crossing+Vector2(0,-22)*k,COL_GOLD,maxi(11,roundi(11.0/camera_zoom)))

func _change_link(partner: int) -> void:
    var unit: Dictionary=sim.find_unit(selected_id)
    if unit.is_empty(): return
    var ok: bool=false
    if not sim.started:
        ok=sim.select_unit_mission(selected_id,str(unit["mission"]),str(unit["policy"]),partner)
    elif sim.turn>=6 and not sim.finished:
        ok=sim.request_order(selected_id,str(unit["mission"]),str(unit["policy"]),partner)
    plan_status.text="협동 대상 지정 완료" if ok and not sim.started else ("협동 대상 변경 전령 파견" if ok else "지정 불가: 자신·전멸 부대 또는 전령 제한")
    _refresh_hud()

func _open_order_map() -> void:
    if not is_instance_valid(order_view) or sim.finished: return
    if order_view.visible: return
    if highlight_active: _stop_highlight("작전 지시를 위해 중지",true)
    if observing_enemy: _show_friendly_roster()
    order_pause_before=sim.paused
    if sim.started: sim.paused=true
    order_view.open(sim.started)

func _return_to_battle() -> void:
    sim.paused=order_pause_before
    var row: int=sim.command_ids(0).find(selected_id)
    if row>=0: unit_list.select(row)
    _select_unit()
    _refresh_hud()
    map_layer.queue_redraw()
    queue_redraw()

func _operation_clock(seconds: float) -> String:
    var whole: int = maxi(0,floori(seconds+0.0001))
    return "%02d:%02d" % [floori(float(whole)/60.0),whole%60]

func _field_art(tile:int,rect:Rect2,tint:Color=Color.WHITE)->void:
    var region:=Rect2(float(tile%4)*256.0,float(floori(float(tile)/4.0))*256.0,256,256)
    map_layer.draw_texture_rect_region(FIELDCRAFT,rect,region,tint)

func _commander_icon(name:String,side:int)->AtlasTexture:
    var icon:=AtlasTexture.new()
    var id: int=PORTRAIT_NAMES.find(name)
    if name in ["왕평","마속","위연","장합"]:
        icon.atlas=PAINTED_ART
        icon.region=_art_region(_portrait_tile(name))
    elif id>=0:
        icon.atlas=GENERAL_PORTRAITS
        icon.region=Rect2((id%4)*288,floori(float(id)/4.0)*288,288,288)
    else:
        icon.atlas=FIELDCRAFT
        var tile:int=3+side
        icon.region=Rect2((tile%4)*256,floori(float(tile)/4.0)*256,256,256)
    return icon

func _number_text(n:int)->String:
    var t:String=str(n)
    return t.substr(0,t.length()-3)+","+t.right(3) if t.length()>3 else t
