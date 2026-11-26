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
    var report_mark: Label
    var commander: Label
    var strength: Label
    var action: Label
    var mood: Label
    var note_kind: Label
    var note: Label
    var rule: ColorRect
    var portrait_name: String

    func _init() -> void:
        theme_type_variation = &"CorpsCard"
        toggle_mode = true
        ink(Rect2(8,8,50,53),Color("#b19b74"))
        portrait = TextureRect.new()
        portrait.position = Vector2(9,9)
        portrait.size = Vector2(48,51)
        portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(portrait)
        report_mark = line(Rect2(9,45,48,16),11,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER)
        report_mark.text = "보고"
        var stamp := StyleBoxFlat.new()
        stamp.bg_color = Color("#8d3d2e")
        report_mark.add_theme_stylebox_override("normal",stamp)
        report_mark.hide()
        commander = line(Rect2(66,4,57,26),19,Color.WHITE)
        strength = line(Rect2(123,6,70,22),14,Color.WHITE,HORIZONTAL_ALIGNMENT_RIGHT)
        action = line(Rect2(66,31,73,25),15,Color.WHITE)
        mood = line(Rect2(141,32,52,24),12,Color.WHITE,HORIZONTAL_ALIGNMENT_RIGHT)
        rule = ink(Rect2(8,66,185,1),Color.WHITE)
        note_kind = line(Rect2(9,69,31,22),12,Color.WHITE)
        note = line(Rect2(43,69,150,22),13,Color.WHITE)

    func present(officer: String, troops: String, activity: String, feeling: String,
            mood_color: Color, kind: String, message: String, selected: bool) -> void:
        set_pressed_no_signal(selected)
        commander.text = officer
        strength.text = troops
        action.text = activity
        mood.text = feeling
        note_kind.text = kind
        note.text = message
        var primary := Color("#292c24") if selected else Color("#f5ecdb")
        var secondary := Color("#484b3d") if selected else Color("#c5cebe")
        commander.modulate = primary
        strength.modulate = secondary
        action.modulate = primary
        mood.modulate = Color("#4c4634") if selected else mood_color
        rule.color = Color("#a99c7e") if selected else Color("#43514c")
        note_kind.modulate = Color("#694c26") if selected else Color("#e0bb7e")
        note.modulate = primary if kind!="판단" else secondary
        accessibility_name = "%s, %s, %s, %s. %s, %s" % [officer,troops,activity,feeling,kind,message]

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

    func present(row: Dictionary, own_text: String, enemy_text: String, limited: bool, selected: bool) -> void:
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
