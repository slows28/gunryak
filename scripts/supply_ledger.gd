extends AcceptDialog
## A view of the same stock and queue used by WarSim for each actual ration issue.
var summary:=Label.new()
var grid:=GridContainer.new()
var rows: Dictionary={}
var sim

func _ready() -> void:
    title="보급기지 · 배급 명부"
    ok_button_text="닫기"
    var content:=VBoxContainer.new()
    content.custom_minimum_size=Vector2(530,280)
    content.add_theme_constant_override("separation",12)
    add_child(content)
    summary.add_theme_font_size_override("font_size",18)
    summary.add_theme_color_override("font_color",Color("#f0d7a0"))
    content.add_child(summary)
    var hint:=Label.new()
    hint.text="재고가 부족하면 배급권 안의 우선 군단부터 군량과 화살을 받습니다."
    content.add_child(hint)
    grid.columns=4
    grid.add_theme_constant_override("h_separation",18)
    grid.add_theme_constant_override("v_separation",4)
    content.add_child(grid)

func open_for(model) -> void:
    sim=model
    for child in grid.get_children():
        grid.remove_child(child)
        child.queue_free()
    rows.clear()
    for caption in ["군단","군량 / 화살","위치","배급 순서"]:
        var header:=Label.new()
        header.text=caption
        header.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        header.add_theme_color_override("font_color",Color("#b9cbbc"))
        grid.add_child(header)
    for id in sim.command_ids(0):
        var title_label:=Label.new()
        var stocks:=Label.new()
        var reach:=Label.new()
        var priority:=OptionButton.new()
        for caption in ["후순위","보통","우선"]: priority.add_item(caption)
        priority.item_selected.connect(_set_priority.bind(id))
        for cell in [title_label,stocks,reach,priority]: grid.add_child(cell)
        title_label.text=sim.find_unit(id)["name"]
        rows[id]={"stocks":stocks,"reach":reach,"priority":priority}
    refresh()
    popup_centered()

func refresh() -> void:
    var base: Dictionary=sim.bases[0]
    var state: String=base["state"]
    var note: String=state
    if state=="설치": note="구축 중 · %d초 남음" % ceili(base["build_timer"]*sim.operation_scale())
    elif state=="가동": note="배급 중"
    summary.text="%s    |    창고 재고 %d / 100" % [note,floori(base["stock"])]
    for id in rows:
        var unit: Dictionary=sim.find_unit(id)
        var row: Dictionary=rows[id]
        var ammo: String="%d%%" % roundi(unit["ammo"]) if unit["type"]=="궁병" else "—"
        row["stocks"].text="%d%%  /  %s" % [roundi(unit["rations"]),ammo]
        var inside: bool=(unit["pos"] as Vector2).distance_to(base["pos"])<=sim.supply_radius()
        row["reach"].text="전멸" if unit["troops"]<=0 else ("권역 안" if inside else "권역 밖")
        row["priority"].select(int(unit["supply_priority"]))
        row["priority"].disabled=state!="가동" or sim.finished or unit["troops"]<=0

func _set_priority(priority: int, id: int) -> void:
    if sim.bases[0]["state"]=="가동": sim.set_supply_priority(id,priority)
    refresh()
