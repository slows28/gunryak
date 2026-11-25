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
    status_label.text = "%s\n아군 %d : 적군 %d\n전령 이동 %d · 도착 %d · 차단 %d" % [phase, sim.total_troops(0), sim.total_troops(1), sim.couriers.size(), sim.delivered_orders, sim.intercepted_orders]
    start_btn.disabled = sim.started or sim.finished
    pause_btn.disabled = not sim.started or sim.finished
    pause_btn.text = "재개" if sim.paused else "일시정지"
    apply_btn.disabled = sim.started and (sim.turn < 6 or sim.finished)
    apply_btn.text = "초기 작전 설정" if not sim.started else "전령 보내기 (6턴~)"
    var unit: Dictionary = sim.find_unit(selected_id)
    if not unit.is_empty():
        selected_label.text = "%s [%s] %d명 / 사기 %d" % [str(unit["name"]), str(unit["general_state"]), int(float(unit["troops"])), int(float(unit["morale"]))]
        var ammo_text: String = " · 화살 %d" % int(unit.get("ammo", 100.0)) if str(unit["type"]) == "궁병" else ""
        details_label.text = "통솔 %d · 무력 %d · 지력 %d · 판단 %d\n%s / %s · 응집 %d · 피로 %d\n식량 %d%s · %s\n%s" % [int(unit["leadership"]), int(unit["martial"]), int(unit["intelligence"]), int(unit["judgment"]), str(unit["action"]), str(unit["formation"]), int(unit["cohesion"]), int(unit["fatigue"]), int(unit["rations"]), ammo_text, "포위" if bool(unit["surrounded"]) else str(unit["obedience"]), str(unit["reason"])]
    var start_line: int = maxi(0, sim.events.size() - 4)
    var lines: String = ""
    for i in range(start_line, sim.events.size()):
        lines += sim.events[i] + "\n"
    if sim.finished:
        lines = ""
        for report_line in sim.battle_report():
            lines += report_line + "\n"
    event_label.text = lines
    if not sim.started:
        notice_label.text = "① 장수별 작전 설정\n② 전투 개시\n③ 지도에서 아군 클릭 가능"
    elif sim.finished:
        notice_label.text = "장수별 결산은 아래 전황 창\n[초기화]로 재실행 가능합니다."
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
    draw_rect(Rect2(_screen(Vector2(325, 80)), Vector2(125, 90)), Color(Color("#335443"), 0.72))
    draw_rect(Rect2(_screen(Vector2(450, 360)), Vector2(130, 125)), Color(Color("#335443"), 0.72))
    draw_rect(Rect2(_screen(Vector2(400, 213)), Vector2(108, 89)), Color(Color("#817b61"), 0.45))
    draw_circle(_screen(Vector2(52, 285)), 32.0, Color(Color("#72c0d4"), 0.13))
    draw_circle(_screen(Vector2(844, 285)), 32.0, Color(Color("#f08a70"), 0.13))
    draw_rect(Rect2(_screen(Vector2(20, 252)), Vector2(60, 67)), Color(Color("#3b91b2"), 0.4))
    draw_rect(Rect2(_screen(Vector2(817, 252)), Vector2(60, 67)), Color(Color("#a45f57"), 0.44))
    _map_text("아군 본진", Vector2(14, 241), COL_BLUE, 13)
    _map_text("적군 본진", Vector2(810, 241), COL_RED, 13)
    _map_text("북쪽 길", Vector2(428, 114), Color("#e6d8ad"), 12)
    _map_text("중앙 고지", Vector2(413, 264), Color("#e6d8ad"), 12)
    _map_text("남쪽 숲", Vector2(490, 397), Color("#d3e4ca"), 12)
    # Capture sites show control, contested progress and victory holds directly.
    for site in sim.outposts:
        var site_pos: Vector2 = _screen(site["pos"])
        var owner: int = int(site["owner"])
        var color: Color = COL_BLUE if owner == 0 else (COL_RED if owner == 1 else COL_GOLD)
        draw_arc(site_pos, WarSim.OUTPOST_RADIUS, 0.0, TAU, 44, Color(color.r, color.g, color.b, 0.24), 1.5)
        draw_colored_polygon(PackedVector2Array([
            site_pos + Vector2(0, -12),
            site_pos + Vector2(9, -3),
            site_pos + Vector2(0, 6),
            site_pos + Vector2(-9, -3)]), color)
        var state: String = "중립" if owner < 0 else ("아군" if owner == 0 else "적군")
        _draw_string(str(site["name"]) + " " + state, site_pos + Vector2(-45, -18), 12, COL_TEXT)
        if int(site["challenger"]) >= 0:
            var progress: float = clampf(float(site["progress"]) / WarSim.OUTPOST_CAPTURE_SECONDS, 0.0, 1.0)
            draw_rect(Rect2(site_pos + Vector2(-30, 11), Vector2(60, 4)), Color("#243138"))
            draw_rect(Rect2(site_pos + Vector2(-30, 11), Vector2(60.0 * progress, 4)), COL_BLUE if int(site["challenger"]) == 0 else COL_RED)
    for base in sim.bases:
        if not bool(base["alive"]):
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
        var p: Vector2 = _screen(commander["pos"])
        var accent: Color = COL_BLUE if int(commander["side"]) == 0 else COL_RED
        draw_colored_polygon(PackedVector2Array([p + Vector2(0, -15), p + Vector2(12, 0), p + Vector2(0, 15), p + Vector2(-12, 0)]), accent)
        _draw_string("책사", p + Vector2(-14, -21), 13, COL_TEXT)
        if commander["pos"] != commander["goal"]:
            draw_line(p, _screen(commander["goal"]), Color(accent.r, accent.g, accent.b, 0.6), 1.5)
    for scout in sim.scouts:
        if not bool(scout["alive"]):
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
        _draw_string("정찰 %.0f초 전" % age, report_p + Vector2(-30, 19), 10, COL_GOLD)
    for letter in sim.couriers:
        var p: Vector2 = _screen(letter["pos"])
        draw_circle(p, 5.0, COL_GOLD)
        _draw_string("전령", p + Vector2(-14, -11), 12, COL_GOLD)
    # Draw real maneuver waypoints so an aggressive flanking decision is visible.
    for unit in sim.units:
        if float(unit["troops"]) > 0.0 and str(unit["action"]) in ["측면 우회", "거점 점령", "거점 방어", "재집결", "전열 지원", "탄약 보충", "보급 복귀", "패주", "정보 확인", "명령 수행"]:
            var start_point: Vector2 = _screen(unit["pos"])
            var flank_waypoint: Vector2 = _screen(unit["goal"])
            draw_line(start_point, flank_waypoint, Color(COL_GOLD, 0.58), 1.4)
            draw_arc(flank_waypoint, 8.0, 0.0, TAU, 24, COL_GOLD, 1.3)
    var label_areas: Array[Rect2] = []
    for unit in sim.units:
        if float(unit["troops"]) > 0.0:
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
