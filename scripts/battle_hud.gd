extends RefCounted
## Compact, keyboard-accessible readouts for the fixed-size battlefield HUD.

class ReadoutButton extends Button:
    func line(bounds: Rect2, font_size: int, shade: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
        var label := Label.new()
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        label.position = bounds.position
        label.size = bounds.size
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.horizontal_alignment = align
        label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        label.add_theme_font_size_override("font_size",font_size)
        label.add_theme_color_override("font_color",Color.WHITE)
        label.modulate = shade
        add_child(label)
        return label

    func ink(bounds: Rect2, shade: Color) -> ColorRect:
        var shape := ColorRect.new()
        shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
        shape.position = bounds.position
        shape.size = bounds.size
        shape.color = shade
        add_child(shape)
        return shape

class CorpsCard extends ReadoutButton:
    var portrait: TextureRect
    signal report_requested(report_id: int)
    var report_link: Button
    var report_id: int = -1
    var troop_type: Label
    var commander: Label
    var strength: Label
    var action: Label
    var dispatch: Label
    var portrait_name: String

    func _init() -> void:
        theme_type_variation = &"CorpsCard"
        toggle_mode = true
        ink(Rect2(5,4,36,36),Color("#a48e65"))
        portrait = TextureRect.new()
        portrait.position = Vector2(6,5)
        portrait.size = Vector2(34,34)
        portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(portrait)
        report_link = Button.new()
        report_link.position = Vector2(5,4)
        report_link.size = Vector2(36,36)
        report_link.flat = true
        report_link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        report_link.tooltip_text = "이 장수의 야전 보고 열기"
        var clear := StyleBoxEmpty.new()
        for state in [&"normal",&"hover",&"pressed"]:
            report_link.add_theme_stylebox_override(state,clear)
        add_child(report_link)
        report_link.pressed.connect(func(): report_requested.emit(report_id))
        var report_mark := line(Rect2(0,0,36,16),11,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER)
        report_mark.reparent(report_link,false)
        report_mark.position = Vector2(0,20)
        report_mark.text = "보고 ›"
        var stamp := StyleBoxFlat.new()
        stamp.bg_color = Color("#8d3d2e")
        report_mark.add_theme_stylebox_override("normal",stamp)
        report_link.hide()
        commander = line(Rect2(47,1,1,22),16,Color.WHITE)
        strength = line(Rect2(0,2,1,20),13,Color.WHITE,HORIZONTAL_ALIGNMENT_RIGHT)
        troop_type = line(Rect2(47,22,32,19),12,Color.WHITE)
        action = line(Rect2(83,22,1,19),13,Color.WHITE)
        dispatch = line(Rect2(0,22,1,19),12,Color.WHITE,HORIZONTAL_ALIGNMENT_RIGHT)
        resized.connect(_fit_lines)
        _fit_lines()

    func _fit_lines() -> void:
        var right := size.x-8.0
        strength.position.x=right-66.0
        strength.size.x=66.0
        commander.size.x=maxf(1.0,strength.position.x-commander.position.x-2.0)
        dispatch.position.x=right-28.0
        dispatch.size.x=28.0
        action.size.x=maxf(1.0,(dispatch.position.x-3.0 if dispatch.visible else right)-action.position.x)

    func present(officer: String, arm: String, troops: String, activity: String, feeling: String,
            mood_color: Color, kind: String, message: String, selected: bool) -> void:
        set_pressed_no_signal(selected)
        commander.text = officer
        troop_type.text = arm
        strength.text = troops
        action.text = activity
        dispatch.text = kind if kind=="전령" else ""
        dispatch.visible = not dispatch.text.is_empty()
        _fit_lines()
        var primary := Color("#292c24") if selected else Color("#f5ecdb")
        commander.modulate = primary
        strength.modulate = Color("#484b3d") if selected else Color("#c5cebe")
        troop_type.modulate = Color("#58513a") if selected else Color("#d2be93")
        action.modulate = Color("#4c4634") if selected else mood_color
        dispatch.modulate = Color("#694c26") if selected else Color("#e0bb7e")
        accessibility_name = "%s, %s, %s, %s, %s. %s, %s" % [officer,arm,troops,activity,feeling,kind,message]

class SectorCard extends ReadoutButton:
    var front: Label
    var state_band: ColorRect
    var state: Label
    var own: Label
    var enemy: Label
    var own_bar: ColorRect
    var enemy_bar: ColorRect
    const BAR_WIDTH := 239.0

    func _init() -> void:
        theme_type_variation = &"SectorCard"
        toggle_mode = true
        front = line(Rect2(11,0,116,23),16,Color("#f2e9d7"))
        state_band = ink(Rect2(180,3,72,19),Color("#6c5030"))
        state = line(Rect2(180,1,72,22),13,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER)
        own = line(Rect2(12,22,110,18),12,Color("#a9d2d5"))
        enemy = line(Rect2(124,22,127,18),12,Color("#e5b6a6"),HORIZONTAL_ALIGNMENT_RIGHT)
        ink(Rect2(12,42,BAR_WIDTH,2),Color("#43504f"))
        own_bar = ink(Rect2(12,42,0,2),Color("#7ba9ac"))
        enemy_bar = ink(Rect2(12,42,0,2),Color("#bb8374"))

    func present(row: Dictionary, own_text: String, enemy_text: String, limited: bool, selected: bool, detailed: bool) -> void:
        var numbers := selected or detailed
        own.visible = numbers
        enemy.visible = numbers
        front.position.y = 0 if numbers else 10
        state.position.y = 1 if numbers else 11
        state_band.position.y = state.position.y+2
        front.text = row["name"]
        state.text = row["state"]
        state_band.visible = int(row["contacts"])>0
        state_band.color = Color("#883e33") if state.text=="아군 압박" else Color("#68502f")
        state.modulate = Color("#fff0ca") if state_band.visible else Color("#cad3c4")
        state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if state_band.visible else HORIZONTAL_ALIGNMENT_RIGHT
        own.text = "아군  "+own_text
        enemy.text = ("관측 적군  " if limited else "적군  ")+enemy_text
        set_pressed_no_signal(selected)
        var total: int = int(row["own"])+int(row["enemy"])
        var show_ratio: bool = not limited and total>0
        own_bar.visible = show_ratio
        enemy_bar.visible = show_ratio
        if show_ratio:
            var split: float = roundf(BAR_WIDTH*float(row["own"])/float(total))
            own_bar.size.x = split
            enemy_bar.position.x = own_bar.position.x+split
            enemy_bar.size.x = BAR_WIDTH-split
        accessibility_name = "%s, %s, %s, %s" % [front.text,state.text,own.text,enemy.text]
