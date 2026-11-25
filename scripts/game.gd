extends Control
## 2D tactical screen. Simulation is entirely separate in war_sim.gd.
const WarSim = preload("res://scripts/war_sim.gd")
const MAP_TOP_LEFT: Vector2 = Vector2(24, 101)
const MAP_SIZE: Vector2 = Vector2(900, 570)
const COL_BG: Color = Color("#101b23")
const COL_PANEL: Color = Color("#1d2d37")
const COL_TEXT: Color = Color("#f2f1e7")
const COL_MUTED: Color = Color("#b6c4c5")
const COL_BLUE: Color = Color("#69c5e8")
const COL_RED: Color = Color("#f08873")
const COL_GOLD: Color = Color("#efc878")

var sim = WarSim.new()
var korean_font: SystemFont
var selected_id: int = 0
var step_buffer: float = 0.0
var ui_clock: float = 0.0
var runtime_notice: String = ""
var game_speed: float = 1.0
var ignore_options: bool = false
var status_label: Label
var selected_label: Label
var details_label: Label
var event_label: Label
var notice_label: Label
var unit_list: ItemList
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
var fog_enabled: bool = true
var plan_actions: Array[Button] = []

func _ready() -> void:
    _install_korean_font()
    _build_interface()
    _refresh_unit_list()
    _select_unit()
    _refresh_hud()
    queue_redraw()

# Use a platform Korean-capable system font for both Control text and custom
# CanvasItem.draw_string(). The bundled default font has no Hangul glyphs.
# Linux CI installs fonts-nanum; Windows normally provides Malgun Gothic.
func _install_korean_font() -> void:
    korean_font = SystemFont.new()
    korean_font.font_names = PackedStringArray([
        "NanumGothic", "Malgun Gothic", "Noto Sans CJK KR",
        "Apple SD Gothic Neo", "UnDotum", "Arial Unicode MS"
    ])
    korean_font.allow_system_fallback = true
    var ui_theme := Theme.new()
    ui_theme.default_font = korean_font
    ui_theme.default_font_size = 14
    theme = ui_theme

func _build_interface() -> void:
    _label("군략   /   첫 전쟁 시뮬레이션", Vector2(25, 9), Vector2(420, 35), 25, COL_TEXT)
    _label("장수와 진형을 배치하고 전투를 관찰하세요", Vector2(27, 51), Vector2(405, 22), 13, COL_MUTED)
    start_btn = _button("전투 개시", Vector2(446, 25), Vector2(102, 37), _start)
    pause_btn = _button("일시정지", Vector2(554, 25), Vector2(102, 37), _pause)
    speed_btn = _button("속도 ×1", Vector2(662, 25), Vector2(100, 37), _speed)
    _button("초기화", Vector2(768, 25), Vector2(88, 37), _reset)
    _button("작전실", Vector2(862, 25), Vector2(76, 37), _open_planning)
    status_label = _label("", Vector2(948, 15), Vector2(312, 66), 12, COL_GOLD)
    _label("출전 장수", Vector2(958, 106), Vector2(270, 28), 20, COL_TEXT)
    _label("장수 선택 → 임무·진형 방침 설정", Vector2(958, 136), Vector2(291, 22), 12, COL_MUTED)
    unit_list = ItemList.new()
    unit_list.position = Vector2(956, 167)
    unit_list.size = Vector2(295, 114)
    unit_list.add_theme_font_size_override("font_size", 15)
    add_child(unit_list)
    unit_list.item_selected.connect(_on_unit_selected)
    _label("작전 목표", Vector2(958, 292), Vector2(267, 21), 13, COL_MUTED)
    mission_choice = _options(Vector2(956, 314), ["중앙 진격", "북측 확보", "남측 우회", "본진 방어"])
    mission_choice.item_selected.connect(_on_choices_changed)
    _label("진형 / 명령 운영 방침", Vector2(958, 362), Vector2(267, 21), 13, COL_MUTED)
    policy_choice = _options(Vector2(956, 384), ["현장 판단", "명령 엄수", "재량 위임", "횡대 유지", "종대 유지", "방진 유지"])
    policy_choice.item_selected.connect(_on_choices_changed)
    apply_btn = _button("작전 적용 / 전령 보내기", Vector2(956, 434), Vector2(295, 39), _apply_order)
    _label("책사 지휘 위치", Vector2(958, 490), Vector2(267, 25), 16, COL_TEXT)
    _button("전선 접근", Vector2(956, 521), Vector2(142, 36), _commander_forward)
    _button("본진 복귀", Vector2(1107, 521), Vector2(144, 36), _commander_back)
    selected_label = _label("", Vector2(957, 577), Vector2(294, 27), 15, COL_GOLD)
    details_label = _label("", Vector2(957, 605), Vector2(293, 78), 11, COL_TEXT)
    details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _label("최근 전황", Vector2(27, 693), Vector2(170, 27), 17, COL_TEXT)
    event_label = _label("", Vector2(152, 691), Vector2(735, 102), 12, COL_TEXT)
    event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    notice_label = _label("", Vector2(947, 697), Vector2(303, 93), 13, COL_MUTED)
    notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _build_planning_dialog()

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
    for i in range(mini(3, sim.units.size())):
        var unit: Dictionary = sim.units[i]
        unit_list.add_item("%s  ·  %s / %s" % [str(unit["name"]), str(unit["type"]), str(unit["personality"])])
    unit_list.select(clampi(selected_id, 0, 2))

func _on_unit_selected(index: int) -> void:
    selected_id = index
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
        sim.select_unit_mission(selected_id, mission, policy)
    elif sim.turn >= 6:
        sim.request_order(selected_id, mission, policy)
    _select_unit()
    _refresh_hud()
    queue_redraw()

func _start() -> void:
    map_mode = "선택"
    runtime_notice = ""
    sim.start()
    _refresh_hud()

func _pause() -> void:
    if not sim.started or sim.finished:
        return
    sim.paused = not sim.paused
    _refresh_hud()

func _speed() -> void:
    game_speed = 2.0 if game_speed == 1.0 else 1.0
    speed_btn.text = "속도 ×2" if game_speed == 2.0 else "속도 ×1"

func _reset() -> void:
    sim.reset()
    map_mode = "선택"
    selected_id = 0
    step_buffer = 0.0
    runtime_notice = ""
    _refresh_unit_list()
    _select_unit()
    _refresh_hud()
    queue_redraw()

func _commander_forward() -> void:
    sim.reposition_commander(true)
    _refresh_hud()

func _commander_back() -> void:
    sim.reposition_commander(false)
    _refresh_hud()

func _process(delta: float) -> void:
    if sim.started and not sim.finished and not sim.paused:
        step_buffer += minf(delta, 0.15) * game_speed
        var ticks: int = 0
        while step_buffer >= 0.1 and ticks < 5:
            sim.step(0.1)
            step_buffer -= 0.1
            ticks += 1
            if sim.finished:
                break
        if ticks == 5:
            step_buffer = minf(step_buffer, 0.2)
    # UI is updated at a bounded rate rather than issuing draw work every frame.
    ui_clock += minf(delta, 0.15)
    if ui_clock >= 0.2:
        ui_clock = 0.0
        if sim.started and not sim.finished and runtime_notice == "":
            var problems: Array[String] = sim.validate_state()
            if not problems.is_empty():
                sim.paused = true
                runtime_notice = "전투 계산 중단: " + problems[0]
                push_error(runtime_notice)
        _refresh_hud()
        queue_redraw()

func _refresh_hud() -> void:
    var phase: String = "전투 준비"
    if sim.finished:
        phase = "종료  " + sim.result
    elif sim.paused:
        phase = "일시정지"
    elif sim.started:
        phase = "작전 %d턴  /  %.0f초" % [sim.turn, sim.battle_time]
    var enemy_text: String = "미확인" if fog_enabled and not sim.finished else str(sim.total_troops(1))
    status_label.text = "%s | %s\n아군 %d : 적군 %s\n전령 이동 %d · 도착 %d · 차단 %d" % [phase, sim.scenario_title, sim.total_troops(0), enemy_text, sim.couriers.size(), sim.delivered_orders, sim.intercepted_orders]
    start_btn.disabled = sim.started or sim.finished
    pause_btn.disabled = not sim.started or sim.finished
    pause_btn.text = "재개" if sim.paused else "일시정지"
    apply_btn.disabled = sim.started and (sim.turn < 6 or sim.finished)
    apply_btn.text = "초기 작전 설정" if not sim.started else "전령 보내기 (6턴~)"
    var unit: Dictionary = sim.find_unit(selected_id)
    if not unit.is_empty():
        var leader_state: String = "부장 지휘" if bool(unit["active_deputy"]) else str(unit["general_state"])
        selected_label.text = "%s [%s] %d명 / 사기 %d" % [str(unit["name"]), leader_state, int(float(unit["troops"])), int(float(unit["morale"]))]
        var ammo_text: String = " · 화살 %d" % int(unit.get("ammo", 100.0)) if str(unit["type"]) == "궁병" else ""
        details_label.text = "통솔 %d · 무력 %d · 지력 %d · 판단 %d\n%s / %s · 응집 %d · 피로 %d\n식량 %d%s · %s\n%s" % [int(unit["leadership"]), int(unit["martial"]), int(unit["intelligence"]), int(unit["judgment"]), str(unit["action"]), str(unit["formation"]), int(unit["cohesion"]), int(unit["fatigue"]), int(unit["rations"]), ammo_text, "포위" if bool(unit["surrounded"]) else str(unit["obedience"]), str(unit["reason"])]
    var start_line: int = maxi(0, sim.events.size() - 4)
    var lines: String = ""
    for i in range(start_line, sim.events.size()):
        if not fog_enabled or sim.finished or _public_event(sim.events[i]):
            lines += sim.events[i] + "\n"
    if sim.finished:
        lines = ""
        for report_line in sim.battle_report():
            lines += report_line + "\n"
    event_label.text = lines
    if not sim.started:
        notice_label.text = sim.scenario_goal + "\n작전실: 병력·부장·배치·경유점\n지도 모드: " + map_mode
    elif sim.finished:
        notice_label.text = "작전실 → 전투 타임라인\n장수별 결산은 아래 전황 창\n[초기화]로 재실행"
    elif sim.turn < 6:
        notice_label.text = "최초 5턴은 사전 명령 수행.\n이후부터 전령 전달이 가능합니다."
    else:
        notice_label.text = "장수 선택 후 전령 파견\n실제 전장 이동 중 차단될 수 있습니다."
    if runtime_notice != "":
        notice_label.text = runtime_notice

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var mouse_pos: Vector2 = event.position
        if not Rect2(MAP_TOP_LEFT, MAP_SIZE).has_point(mouse_pos):
            return
        if not sim.started and map_mode != "선택":
            var field_pos: Vector2 = mouse_pos - MAP_TOP_LEFT
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
        for i in range(mini(3, sim.units.size())):
            var unit: Dictionary = sim.units[i]
            var p: Vector2 = MAP_TOP_LEFT + (unit["pos"] as Vector2)
            if mouse_pos.distance_to(p) < 47.0:
                selected_id = i
                unit_list.select(i)
                _select_unit()
                accept_event()
                return

func _draw() -> void:
    draw_rect(Rect2(0, 0, 1280, 800), COL_BG)
    draw_rect(Rect2(0, 0, 1280, 83), COL_PANEL)
    draw_rect(Rect2(939, 91, 322, 585), COL_PANEL)
    draw_rect(Rect2(21, 685, 907, 110), COL_PANEL)
    draw_rect(Rect2(938, 685, 323, 110), COL_PANEL)
    var map_rect: Rect2 = Rect2(MAP_TOP_LEFT, MAP_SIZE)
    draw_rect(map_rect, Color("#52634f"))
    # Roads, hills, and woodlands are visible and influence movement.
    for y in [131.0, 282.0, 435.0]:
        draw_line(_screen(Vector2(5, y)), _screen(Vector2(895, y)), Color(Color("#8e906f"), 0.39), 13.0)
        draw_line(_screen(Vector2(5, y)), _screen(Vector2(895, y)), Color(Color("#c1b393"), 0.34), 2.0)
    for forest in sim.forests:
        draw_rect(Rect2(_screen(forest.position), forest.size), Color(Color("#335443"), 0.72))
    draw_rect(Rect2(_screen(sim.hill.position), sim.hill.size), Color(Color("#817b61"), 0.45))
    if not sim.started:
        draw_rect(Rect2(_screen(Vector2(35,22)),Vector2(235,530)),Color(COL_BLUE,0.07))
        draw_rect(Rect2(_screen(Vector2(35,22)),Vector2(235,530)),Color(COL_BLUE,0.4),false,1.5)
    draw_circle(_screen(Vector2(52, 285)), 32.0, Color(Color("#72c0d4"), 0.13))
    draw_circle(_screen(Vector2(844, 285)), 32.0, Color(Color("#f08a70"), 0.13))
    draw_rect(Rect2(_screen(Vector2(20, 252)), Vector2(60, 67)), Color(Color("#3b91b2"), 0.4))
    draw_rect(Rect2(_screen(Vector2(817, 252)), Vector2(60, 67)), Color(Color("#a45f57"), 0.44))
    _map_text("아군 본진", Vector2(14, 241), COL_BLUE, 13)
    _map_text("적군 본진", Vector2(810, 241), COL_RED, 13)
    _map_text("북쪽 길", Vector2(428, 114), Color("#e6d8ad"), 12)
    _map_text("고지", sim.hill.get_center(), Color("#e6d8ad"), 12)
    for forest in sim.forests:
        _map_text("숲", forest.get_center(), Color("#d3e4ca"), 12)
    # Capture sites show control, contested progress and victory holds directly.
    for site in sim.outposts:
        var site_pos: Vector2 = _screen(site["pos"])
        var known: bool = not fog_enabled or sim.finished or sim.player_can_see(site["pos"])
        var owner: int = int(site["owner"]) if known else -1
        var color: Color = COL_BLUE if owner == 0 else (COL_RED if owner == 1 else COL_GOLD)
        draw_arc(site_pos, WarSim.OUTPOST_RADIUS, 0.0, TAU, 44, Color(color.r, color.g, color.b, 0.24), 1.5)
        draw_colored_polygon(PackedVector2Array([
            site_pos + Vector2(0, -12),
            site_pos + Vector2(9, -3),
            site_pos + Vector2(0, 6),
            site_pos + Vector2(-9, -3)]), color)
        var state: String = ("중립" if owner < 0 else ("아군" if owner == 0 else "적군")) if known else "미확인"
        _draw_string(str(site["name"]) + " " + state, site_pos + Vector2(-45, -18), 12, COL_TEXT)
        if known and int(site["challenger"]) >= 0:
            var progress: float = clampf(float(site["progress"]) / WarSim.OUTPOST_CAPTURE_SECONDS, 0.0, 1.0)
            draw_rect(Rect2(site_pos + Vector2(-30, 11), Vector2(60, 4)), Color("#243138"))
            draw_rect(Rect2(site_pos + Vector2(-30, 11), Vector2(60.0 * progress, 4)), COL_BLUE if int(site["challenger"]) == 0 else COL_RED)
    for base in sim.bases:
        if not bool(base["alive"]):
            continue
        if fog_enabled and not sim.finished and int(base["side"]) != 0 and not sim.player_can_see(base["pos"]):
            continue
        var p: Vector2 = _screen(base["pos"])
        var side: int = int(base["side"])
        var accent: Color = COL_BLUE if side == 0 else COL_RED
        if str(base["state"]) == "가동":
            draw_circle(p, WarSim.SUPPLY_RADIUS, Color(accent.r, accent.g, accent.b, 0.045))
            draw_arc(p, WarSim.SUPPLY_RADIUS, 0.0, TAU, 56, Color(accent.r, accent.g, accent.b, 0.33), 1.5)
        draw_rect(Rect2(p - Vector2(7, 7), Vector2(14, 14)), accent)
        _draw_string("보급 %s · %d" % [str(base["state"]), int(base.get("stock", 100.0))], p + Vector2(-40, 24), 12, Color("#f6f4e8"))
    for commander in sim.commanders:
        if fog_enabled and not sim.finished and int(commander["side"]) != 0 and not sim.player_can_see(commander["pos"]):
            continue
        var p: Vector2 = _screen(commander["pos"])
        var accent: Color = COL_BLUE if int(commander["side"]) == 0 else COL_RED
        draw_colored_polygon(PackedVector2Array([p + Vector2(0, -15), p + Vector2(12, 0), p + Vector2(0, 15), p + Vector2(-12, 0)]), accent)
        _draw_string("책사", p + Vector2(-14, -21), 13, COL_TEXT)
        if commander["pos"] != commander["goal"]:
            draw_line(p, _screen(commander["goal"]), Color(accent.r, accent.g, accent.b, 0.6), 1.5)
    for scout in sim.scouts:
        if not bool(scout["alive"]):
            continue
        if fog_enabled and not sim.finished and int(scout["side"]) != 0 and not sim.player_can_see(scout["pos"]):
            continue
        var scout_p: Vector2 = _screen(scout["pos"])
        var scout_color: Color = COL_BLUE if int(scout["side"]) == 0 else COL_RED
        draw_circle(scout_p, 6.0, scout_color, false, 2.0)
        draw_circle(scout_p, 2.5, scout_color)
        draw_line(scout_p, _screen(scout["goal"]), Color(scout_color, 0.20), 1.0)
        _draw_string("정찰", scout_p + Vector2(-12, -12), 10, scout_color)
    # Allied scout snapshots are displayed as aged reports rather than live positions.
    for id in sim.intelligence[0]:
        var report: Dictionary = sim.intelligence[0][id]
        var report_p: Vector2 = _screen(report["pos"])
        var age: float = maxf(0.0, sim.battle_time - float(report["time"]))
        draw_arc(report_p, 12.0, 0.0, TAU, 24, Color(COL_GOLD, maxf(0.15, 0.65 - age * 0.025)), 1.5)
        _draw_string("정찰 %.0f초 전 · %d%%" % [age,int(float(report.get("confidence",0.0))*100.0)], report_p + Vector2(-30, 19), 10, COL_GOLD)
    for letter in sim.couriers:
        if fog_enabled and not sim.finished and int(letter["side"]) != 0 and not sim.player_can_see(letter["pos"]):
            continue
        var p: Vector2 = _screen(letter["pos"])
        draw_circle(p, 5.0, COL_GOLD)
        _draw_string("전령", p + Vector2(-14, -11), 12, COL_GOLD)
    # Draw real maneuver waypoints so an aggressive flanking decision is visible.
    for unit in sim.units:
        if not _visible_unit(unit):
            continue
        if fog_enabled and not sim.finished and int(unit["side"]) != 0:
            continue
        if float(unit["troops"]) > 0.0 and str(unit["action"]) in ["측면 우회", "거점 점령", "거점 방어", "재집결", "전열 지원", "탄약 보충", "보급 복귀", "패주", "정보 확인", "명령 수행", "계획 경유", "방어선 사수"]:
            var start_point: Vector2 = _screen(unit["pos"])
            var flank_waypoint: Vector2 = _screen(unit["goal"])
            draw_line(start_point, flank_waypoint, Color(COL_GOLD, 0.58), 1.4)
            draw_arc(flank_waypoint, 8.0, 0.0, TAU, 24, COL_GOLD, 1.3)
    if not sim.started:
        var selected: Dictionary = sim.find_unit(selected_id)
        if not selected.is_empty():
            var previous: Vector2 = _screen(selected["pos"])
            var step_number: int = 1
            for waypoint in selected["waypoints"]:
                var point: Vector2 = _screen(waypoint)
                draw_line(previous, point, COL_GOLD, 2.0)
                draw_circle(point, 9.0, COL_GOLD, false, 2.0)
                _draw_string(str(step_number),point+Vector2(-3,4),11,COL_TEXT)
                previous = point
                step_number += 1
            if bool(selected["defense_set"]):
                var anchor: Vector2 = _screen(selected["defense_anchor"])
                draw_arc(anchor, 28.0,0.0,TAU,32,COL_BLUE,2.0)
                _draw_string("사수",anchor+Vector2(-12,4),11,COL_BLUE)
    var label_areas: Array[Rect2] = []
    for unit in sim.units:
        if float(unit["troops"]) > 0.0 and _visible_unit(unit):
            _draw_unit(unit, label_areas)
    draw_rect(map_rect, Color(Color("#cad8d7"), 0.42), false, 1.5)


func _draw_unit(unit: Dictionary, label_areas: Array[Rect2]) -> void:
    var side: int = int(unit["side"])
    var accent: Color = COL_BLUE if side == 0 else COL_RED
    var p: Vector2 = _screen(unit["pos"])
    var unit_type: String = str(unit["type"])
    if bool(unit["routed"]):
        accent = Color(accent, 0.48)
    elif float(unit["ambush_ready"]) >= 3.0:
        accent = Color(accent, 0.64)
    for spot in sim.formation_slots(unit):
        var point: Vector2 = _screen(spot)
        match unit_type:
            "보병":
                draw_rect(Rect2(point - Vector2(3.4, 3.4), Vector2(6.8, 6.8)), accent)
            "궁병":
                draw_colored_polygon(PackedVector2Array([
                    point + Vector2(0.0, -4.9),
                    point + Vector2(4.5, 3.2),
                    point + Vector2(-4.5, 3.2)]), accent)
            "기병":
                draw_circle(point, 4.4, accent)
                draw_circle(point, 1.5, COL_BG)
    if side == 0 and int(unit["id"]) == selected_id:
        draw_arc(p, 39.0, 0.0, TAU, 48, COL_GOLD, 1.8)
    if float(unit.get("front_pressure", 0.0)) > 0.10:
        draw_arc(p, 35.0, 0.0, TAU, 32, COL_RED if side == 0 else COL_BLUE, 2.0)
    var contacts: int = int(unit.get("contact_troops", 0))
    if contacts > 0 and unit_type != "궁병":
        draw_arc(p, 30.0, 0.0, TAU, 32, Color(COL_GOLD, 0.58), 1.8)
    var ratio: float = clampf(float(unit["troops"]) / float(unit["initial_troops"]), 0.0, 1.0)
    draw_rect(Rect2(p + Vector2(-24, 25), Vector2(48, 4)), Color("#142630"))
    draw_rect(Rect2(p + Vector2(-24, 25), Vector2(48.0 * ratio, 4)), accent)
    var cohesion: float = clampf(float(unit.get("cohesion", 100.0)) / 100.0, 0.0, 1.0)
    draw_rect(Rect2(p + Vector2(-24, 31), Vector2(48, 3)), Color("#142630"))
    draw_rect(Rect2(p + Vector2(-24, 31), Vector2(48.0 * cohesion, 3)), Color("#e3c37b"))
    var markers: Array[String] = []
    if bool(unit["routed"]):
        markers.append("패주")
    elif bool(unit["rallying"]):
        markers.append("재집결")
    if bool(unit["surrounded"]):
        markers.append("포위")
    if str(unit["general_state"]) != "건재":
        markers.append(str(unit["general_state"]))
    if str(unit["action"]) == "매복":
        markers.append("매복")
    if float(unit["charge"]) >= 32.0:
        markers.append("돌격")
    if not markers.is_empty():
        _draw_string(" / ".join(markers), p + Vector2(-30, 47), 10, COL_GOLD)

    # Collision-aware name chips; overlapping armies do not stack unreadable labels.
    var label: String = "%s  %d" % [str(unit["name"]), int(float(unit["troops"]))]
    var width: float = 110.0
    var x: float = clampf(p.x - width * 0.5, MAP_TOP_LEFT.x + 3.0, MAP_TOP_LEFT.x + MAP_SIZE.x - width - 3.0)
    var y: float = p.y - 48.0
    var bubble: Rect2 = Rect2(Vector2(x, y), Vector2(width, 17.0))
    for retry in range(12):
        var collides: bool = false
        for prior in label_areas:
            if prior.intersects(bubble.grow(2.0)):
                collides = true
                break
        if not collides:
            break
        bubble.position.y -= 19.0
    bubble.position.y = maxf(MAP_TOP_LEFT.y + 3.0, bubble.position.y)
    label_areas.append(bubble)
    draw_rect(bubble, Color("#13262b"))
    draw_rect(bubble, Color(accent.r, accent.g, accent.b, 0.70), false, 1.0)
    _draw_string(label, bubble.position + Vector2(4.0, 12.7), 11, COL_TEXT)
    if str(unit["next_formation"]) != "":
        _draw_string("↻", p + Vector2(28, 0), 15, COL_GOLD)

func _screen(p: Vector2) -> Vector2:
    return MAP_TOP_LEFT + p

func _map_text(value: String, pos: Vector2, shade: Color, font_size: int) -> void:
    _draw_string(value, _screen(pos), font_size, shade)

func _draw_string(value: String, where: Vector2, font_size: int, shade: Color) -> void:
    if korean_font != null:
        draw_string(korean_font, where, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shade)


func _visible_unit(unit: Dictionary) -> bool:
    return int(unit["side"]) == 0 or not fog_enabled or sim.finished or sim.player_can_see(unit["pos"], sim.terrain_at(unit["pos"]) == "숲" or float(unit["ambush_ready"]) >= 3.0)

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
    plan_scenario = _plan_option(root,"전장 시나리오",["북남 요충지","중앙 고지 쟁탈","보급로 사수"])
    plan_scenario.item_selected.connect(_change_scenario)
    plan_donor = _plan_option(root,"다른 장수 / 병력 제공 부대",["왕평 부대","마속 부대","위연 부대"])
    var troop_row := HBoxContainer.new()
    root.add_child(troop_row)
    _plan_button(troop_row,"병력 10명 받기",_transfer_in)
    _plan_button(troop_row,"병력 10명 보내기",_transfer_out)
    _plan_button(troop_row,"장수 교체",_swap_general)
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
    _plan_button(map_row,"초기 배치",func(): _set_map_mode("배치"))
    _plan_button(map_row,"경유점 추가",func(): _set_map_mode("경유점"))
    _plan_button(map_row,"방어선 지정",func(): _set_map_mode("방어선"))
    _plan_button(map_row,"계획 삭제",_clear_route)
    var mode_row := HBoxContainer.new()
    root.add_child(mode_row)
    _plan_button(mode_row,"지도 선택 모드",func(): _set_map_mode("선택"))
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
    plan_scenario.disabled = sim.started and not sim.finished
    plan_donor.clear()
    for i in range(3):
        var candidate: Dictionary = sim.find_unit(i)
        plan_donor.add_item(str(candidate["name"]) + " 부대",i)
    plan_donor.select((selected_id+1)%3)
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
    if sim.set_scenario(index):
        map_mode = "선택"
        selected_id = 0
        runtime_notice = ""
        _refresh_unit_list()
        _select_unit()
        planning_dialog.hide()
        queue_redraw()

func _transfer_in() -> void:
    if sim.transfer_troops(selected_id,plan_donor.get_selected_id(),10):
        _refresh_plan_status()
        _refresh_hud()
    else:
        plan_status.text = "병력 조정 불가: 최소 40명 / 최대 220명"

func _transfer_out() -> void:
    if sim.transfer_troops(plan_donor.get_selected_id(),selected_id,10):
        _refresh_plan_status()
        _refresh_hud()
    else:
        plan_status.text = "병력 조정 불가: 최소 40명 / 최대 220명"

func _swap_general() -> void:
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
    fog_enabled = value
    _refresh_hud()
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
