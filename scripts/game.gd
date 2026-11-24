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
    _build_interface()
    _refresh_unit_list()
    _select_unit()
    _refresh_hud()
    queue_redraw()

func _build_interface() -> void:
    _label("군략   /   첫 전쟁 시뮬레이션", Vector2(25, 9), Vector2(420, 35), 25, COL_TEXT)
    _label("장수와 진형을 배치하고 전투를 관찰하세요", Vector2(27, 51), Vector2(405, 22), 13, COL_MUTED)
    start_btn = _button("전투 개시", Vector2(446, 25), Vector2(102, 37), _start)
    pause_btn = _button("일시정지", Vector2(554, 25), Vector2(102, 37), _pause)
    speed_btn = _button("속도 ×1", Vector2(662, 25), Vector2(100, 37), _speed)
    _button("초기화", Vector2(768, 25), Vector2(88, 37), _reset)
    status_label = _label("", Vector2(948, 24), Vector2(312, 48), 14, COL_GOLD)
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
    _label("진형 운영 방침", Vector2(958, 362), Vector2(267, 21), 13, COL_MUTED)
    policy_choice = _options(Vector2(956, 384), ["현장 판단", "횡대 유지", "종대 유지", "방진 유지"])
    policy_choice.item_selected.connect(_on_choices_changed)
    apply_btn = _button("작전 적용 / 전령 보내기", Vector2(956, 434), Vector2(295, 39), _apply_order)
    _label("책사 지휘 위치", Vector2(958, 490), Vector2(267, 25), 16, COL_TEXT)
    _button("전선 접근", Vector2(956, 521), Vector2(142, 36), _commander_forward)
    _button("본진 복귀", Vector2(1107, 521), Vector2(144, 36), _commander_back)
    selected_label = _label("", Vector2(957, 577), Vector2(294, 27), 15, COL_GOLD)
    details_label = _label("", Vector2(957, 606), Vector2(293, 57), 13, COL_TEXT)
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
    status_label.text = "%s\n아군 %d  :  적군 %d" % [phase, sim.total_troops(0), sim.total_troops(1)]
    start_btn.disabled = sim.started or sim.finished
    pause_btn.disabled = not sim.started or sim.finished
    pause_btn.text = "재개" if sim.paused else "일시정지"
    apply_btn.disabled = sim.started and (sim.turn < 6 or sim.finished)
    apply_btn.text = "초기 작전 설정" if not sim.started else "전령 보내기 (6턴~)"
    var unit: Dictionary = sim.find_unit(selected_id)
    if not unit.is_empty():
        selected_label.text = "%s   %d명 / 사기 %d" % [str(unit["name"]), int(float(unit["troops"])), int(float(unit["morale"]))]
        details_label.text = "%s · %s\n진형: %s    보급: %s\n%s" % [str(unit["action"]), str(unit["mission"]), str(unit["formation"]), "정상" if bool(unit["supplied"]) else "미보급", str(unit["reason"])]
    var start_line: int = maxi(0, sim.events.size() - 4)
    var lines: String = ""
    for i in range(start_line, sim.events.size()):
        lines += sim.events[i] + "\n"
    event_label.text = lines
    if not sim.started:
        notice_label.text = "① 장수별 작전 설정\n② 전투 개시\n③ 지도에서 아군 클릭 가능"
    elif sim.finished:
        notice_label.text = "전투가 종료됐습니다.\n[초기화]로 재실행할 수 있습니다."
    elif sim.turn < 6:
        notice_label.text = "최초 5턴은 사전 명령 수행.\n이후부터 전령 전달이 가능합니다."
    else:
        notice_label.text = "장수 선택 후 새 작전을 보내면 전령이 실제로 이동합니다."
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
        _draw_string("보급 " + str(base["state"]), p + Vector2(-28, 24), 12, Color("#f6f4e8"))
    for commander in sim.commanders:
        var p: Vector2 = _screen(commander["pos"])
        var accent: Color = COL_BLUE if int(commander["side"]) == 0 else COL_RED
        draw_colored_polygon(PackedVector2Array([p + Vector2(0, -15), p + Vector2(12, 0), p + Vector2(0, 15), p + Vector2(-12, 0)]), accent)
        _draw_string("책사", p + Vector2(-14, -21), 13, COL_TEXT)
        if commander["pos"] != commander["goal"]:
            draw_line(p, _screen(commander["goal"]), Color(accent.r, accent.g, accent.b, 0.6), 1.5)
    for letter in sim.couriers:
        var p: Vector2 = _screen(letter["pos"])
        draw_circle(p, 5.0, COL_GOLD)
        _draw_string("전령", p + Vector2(-14, -11), 12, COL_GOLD)
    for unit in sim.units:
        if float(unit["troops"]) > 0.0:
            _draw_unit(unit)
    draw_rect(map_rect, Color(Color("#cad8d7"), 0.42), false, 1.5)

func _draw_unit(unit: Dictionary) -> void:
    var side: int = int(unit["side"])
    var accent: Color = COL_BLUE if side == 0 else COL_RED
    var p: Vector2 = _screen(unit["pos"])
    var front: Vector2 = unit["facing"]
    if front.length_squared() < 0.5:
        front = Vector2.RIGHT if side == 0 else Vector2.LEFT
    var lateral: Vector2 = Vector2(-front.y, front.x)
    var formation: String = str(unit["formation"])
    var columns: int = 6
    var rows: int = 2
    if formation == "종대":
        columns = 3
        rows = 4
    elif formation == "방진":
        columns = 4
        rows = 3
    var count: int = clampi(int(round(float(unit["troops"]) / float(unit["initial_troops"]) * 12.0)), 1, 12)
    for k in range(count):
        var col: int = k % columns
        var row: int = int(floor(float(k) / float(columns)))
        var local_p: Vector2 = lateral * ((float(col) - float(columns - 1) * 0.5) * 10.0) - front * ((float(row) - float(rows - 1) * 0.5) * 10.5)
        draw_circle(p + local_p, 3.9, accent)
    if side == 0 and int(unit["id"]) == selected_id:
        draw_arc(p, 40.0, 0.0, TAU, 48, COL_GOLD, 2.0)
    var ratio: float = clampf(float(unit["troops"]) / float(unit["initial_troops"]), 0.0, 1.0)
    draw_rect(Rect2(p + Vector2(-25, 24), Vector2(50, 4)), Color("#142630"))
    draw_rect(Rect2(p + Vector2(-25, 24), Vector2(50.0 * ratio, 4)), accent)
    _draw_string("%s %d" % [str(unit["name"]), int(float(unit["troops"]))], p + Vector2(-35, -31), 12, COL_TEXT)
    if str(unit["next_formation"]) != "":
        _draw_string("↻", p + Vector2(30, 1), 15, COL_GOLD)

func _screen(p: Vector2) -> Vector2:
    return MAP_TOP_LEFT + p

func _map_text(value: String, pos: Vector2, shade: Color, font_size: int) -> void:
    _draw_string(value, _screen(pos), font_size, shade)

func _draw_string(value: String, where: Vector2, font_size: int, shade: Color) -> void:
    var fallback: Font = ThemeDB.fallback_font
    if fallback != null:
        draw_string(fallback, where, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shade)
