extends Control
## Lightweight scene to distinguish engine/renderer issues from battle-script issues.
var elapsed: float = 0.0
var display: Label

func _ready() -> void:
    display = Label.new()
    display.position = Vector2(75, 110)
    display.size = Vector2(1020, 240)
    display.add_theme_font_size_override("font_size", 28)
    display.text = "군략 진단 화면: 기본 렌더링 정상"
    add_child(display)

func _process(delta: float) -> void:
    elapsed += minf(delta, 0.1)
    display.text = "군략 기본 화면 테스트\n경과 시간: %.1f초\n이 화면이 10초 이상 유지되면 기본 화면 표시가 동작합니다." % elapsed
