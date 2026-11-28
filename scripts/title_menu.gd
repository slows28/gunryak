extends Control

const North = preload("res://scripts/northern_campaign.gd")
const Legacy = preload("res://scripts/campaign.gd")
const Field = preload("res://scripts/northern_field.gd")
const ART = preload("res://assets/art/title_art.webp")
const INK = Color("#192324")
const PAPER = Color("#f2ead8")
const BRASS = Color("#d4ba85")

var game
var home: Control
var practice: Control
var heading: Label
var detail: Label
var primary: Button
var reload_record: Button
var new_record: Button
var practice_entry: Button
var drill: Button
var difficulty: OptionButton
var audio: Button
var confirm: Control
var confirm_title: Label
var confirm_detail: Label
var proceed: Button
var cancel: Button
var footer: Control
var previous_focus: Control
var previous_page: Control
var next_action: Callable
var record_available := false
var record_north := true
var return_caption := ""

func _ready() -> void:
    game=get_parent()
    size=Vector2(1280,800)
    var paper:=ColorRect.new()
    paper.color=INK
    paper.size=size
    add_child(paper)
    var art:=TextureRect.new()
    art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    art.texture=ART
    art.position=Vector2(516,0)
    art.size=Vector2(764,800)
    art.mouse_filter=Control.MOUSE_FILTER_IGNORE
    art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
    add_child(art)
    var wash:=GradientTexture2D.new()
    wash.gradient=Gradient.new()
    wash.gradient.colors=PackedColorArray([INK,Color(INK,0)])
    var edge:=TextureRect.new()
    edge.texture=wash
    edge.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    edge.position=art.position
    edge.size=Vector2(245,800)
    add_child(edge)
    game._label("삼국지 군단 지휘",Vector2(76,85),Vector2(450,32),19,BRASS,self)
    game._label("군략",Vector2(70,110),Vector2(450,126),88,PAPER,self)
    home=Control.new()
    practice=Control.new()
    for page: Control in [home,practice]:
        page.position=Vector2(76,290)
        page.size=Vector2(455,330)
        add_child(page)
    heading=game._label("",Vector2.ZERO,Vector2(450,42),27,PAPER,home)
    detail=game._label("",Vector2(0,51),Vector2(455,35),16,BRASS,home)
    primary=button(home,"",0,110,444,_primary,true)
    new_record=button(home,"새 북벌 시작",0,172,215,_new_game)
    reload_record=button(home,"저장 기록 열기",229,172,215,_load_record)
    practice_entry=button(home,"단독 전투 · 지형 시험장",0,230,444,show_practice)
    game._label("단독 전투",Vector2.ZERO,Vector2(450,42),27,PAPER,practice)
    game._label("난이도와 시야",Vector2(0,66),Vector2(134,40),16,BRASS,practice)
    var levels: Array[String]=["입문 · 전체 관전 가능","보통 · 아군 정찰","어려움 · 아군 정찰"]
    difficulty=game._options(Vector2(135,66),levels,practice)
    difficulty.size=Vector2(309,40)
    difficulty.select(1)
    drill=button(practice,"야전 시작",0,128,215,_standalone.bind(0),true)
    button(practice,"지형 시험장",229,128,215,_standalone.bind(game.sim.TRAINING_SCENARIO))
    button(practice,"야전 브리핑",0,187,215,_standalone.bind(0,true))
    button(practice,"뒤로",229,187,215,leave_practice)
    var rule:=ColorRect.new()
    rule.color=Color("#49504a")
    rule.position=Vector2(76,663)
    rule.size=Vector2(444,1)
    add_child(rule)
    footer=Control.new()
    footer.position=Vector2(76,685)
    footer.size=Vector2(444,49)
    add_child(footer)
    var help:=button(footer,"조작 안내",0,0,141,game._open_demo_help)
    audio=button(footer,"",151,0,142,game._toggle_sound)
    var quit:=button(footer,"종료",303,0,141,_quit_from_menu)
    for utility: Button in [help,audio,quit]:
        utility.flat=true
    confirm=Control.new()
    confirm.position=home.position
    confirm.size=home.size
    add_child(confirm)
    confirm_title=game._label("",Vector2.ZERO,Vector2(450,42),27,PAPER,confirm)
    confirm_detail=game._label("",Vector2(0,54),Vector2(455,100),17,BRASS,confirm)
    confirm_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    cancel=button(confirm,"취소",0,182,215,cancel_confirmation)
    proceed=button(confirm,"",229,182,215,func(): next_action.call(),true)
    refresh("")

func button(page: Control, caption: String,x: int,y: int,w: int,action: Callable,accent:=false) -> Button:
    var b: Button=game._button(caption,Vector2(x,y),Vector2(w,49),action,page)
    b.add_theme_font_size_override("font_size",17)
    if accent: game._primary_button(b)
    return b

func refresh(resume: String) -> void:
    return_caption=resume
    var record=North.new()
    if game.campaign is North: record.save_path=game.campaign.save_path
    var found_north:=FileAccess.file_exists(record.save_path)
    record_north=record.load_save()
    record_available=record_north
    var summary: String
    if record_north:
        summary="%02d장  %s" % [record.state.stage,Field.CHAPTERS[record.state.stage-1][0]]
        if record.state.reward: summary+="  ·  전리품 선택"
        elif record.state.complete: summary+="  ·  북벌 완수"
    else:
        record=Legacy.new()
        record.set_six_armies(true)
        record_available=record.load_save()
        if record_available: summary="기존 전역  ·  %d일차" % record.state.turn
    heading.text="북벌 캠페인" if resume=="" else game.sim.scenario_title
    if resume=="편성으로 돌아가기": heading.text="출전 편성"
    detail.text=summary if record_available else "제1장 기산 진출전에서 북벌을 시작합니다."
    if not record_available and found_north: detail.text="기존 북벌 기록을 읽을 수 없습니다."
    if resume!="":
        if game.menu_origin==game.strategy_view:
            detail.text=game.strategy_view.summary.text if game.campaign is North else "전역 편성"
        elif game.menu_origin==game.order_view:
            var count: int=game.order_view.drafts.size()
            detail.text="미확정 지시 %d개" % count if count>0 else "작전 지도 · %d일차" % game.sim.turn
        elif game.sim.finished: detail.text=game.sim.result
        else: detail.text="%d일차  ·  %s 경과" % [game.sim.turn,game._operation_clock(game.sim.operation_elapsed())]
    primary.text=resume if resume!="" else ("캠페인 이어하기" if record_available else "북벌 시작")
    new_record.visible=resume!="" or record_available
    reload_record.visible=resume!="" and record_available
    new_record.size.x=215 if reload_record.visible else 444
    practice_entry.position.y=231 if new_record.visible else 172
    update_sound()
    confirm.hide()
    footer.show()
    practice.hide()
    home.show()
    primary.grab_focus()

func update_sound() -> void:
    audio.text="음향 켜짐" if game.sound_enabled else "음향 꺼짐"

func show_practice() -> void:
    home.hide()
    practice.show()
    drill.grab_focus()

func leave_practice() -> void:
    practice.hide()
    home.show()
    practice_entry.grab_focus()

func _quit_from_menu() -> void:
    if return_caption!="": ask("게임 종료","게임을 종료하면 현재 화면을 닫습니다. 캠페인은 마지막 저장 기록에서 이어집니다.",game._quit_game)
    else: game._quit_game()

func _primary() -> void:
    if return_caption!="": game._resume_from_title()
    elif record_available: _load_record()
    else: _new_game()

func _new_game() -> void:
    var path: String=game.campaign.save_path if game.campaign is North else North.new().save_path
    var replace:=FileAccess.file_exists(path)
    if replace or return_caption!="":
        var message:="현재 화면을 떠나 제1장 기산 진출전부터 시작합니다."
        if replace: message+="\n새 편성을 저장하면 기존 북벌 기록을 덮어씁니다."
        ask("새 북벌 시작",message,game._begin_campaign)
    else: game._begin_campaign()

func _load_record() -> void:
    var load_campaign: Callable=game._continue_campaign.bind(record_north)
    if return_caption!="": ask("기록 불러오기","현재 화면을 떠나 마지막으로 저장한 전역 기록을 엽니다.",load_campaign)
    else: load_campaign.call()

func _standalone(scenario: int, briefing:=false) -> void:
    var start: Callable=game._title_brief if briefing else game._leave_title.bind(scenario)
    if return_caption!="": ask("단독 전투 열기","현재 화면을 떠나 단독 전투의 작전 지도를 엽니다.",start)
    else: start.call()

func ask(caption: String,message: String,action: Callable) -> void:
    next_action=action
    previous_focus=get_viewport().gui_get_focus_owner()
    previous_page=practice if practice.visible else home
    previous_page.hide()
    footer.hide()
    confirm_title.text=caption
    confirm_detail.text=message
    proceed.text=caption
    confirm.show()
    cancel.grab_focus()

func cancel_confirmation() -> void:
    confirm.hide()
    footer.show()
    previous_page.show()
    next_action=Callable()
    if is_instance_valid(previous_focus): previous_focus.grab_focus()
