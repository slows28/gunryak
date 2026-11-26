extends RefCounted
## Short, dry impacts. Each take has its own timing and texture.
const COMBAT = {
    "근접": [preload("res://assets/audio/shield_1.wav"), preload("res://assets/audio/shield_2.wav"), preload("res://assets/audio/shield_3.wav"), preload("res://assets/audio/shield_4.wav")],
    "화살": [preload("res://assets/audio/volley_1.wav"), preload("res://assets/audio/volley_2.wav"), preload("res://assets/audio/volley_3.wav")],
    "돌격": [preload("res://assets/audio/charge_1.wav"), preload("res://assets/audio/charge_2.wav")],
    "질주": [preload("res://assets/audio/hooves_1.wav"), preload("res://assets/audio/hooves_2.wav"), preload("res://assets/audio/hooves_3.wav")],
}
const SPACING_MS = {"근접": 640, "화살": 340, "돌격": 510, "질주": 620}
const DISPATCH = preload("res://assets/audio/dispatch_1.wav")
const HQ_ALARM = preload("res://assets/audio/alarm_1.wav")
const END = preload("res://assets/audio/end_1.wav")
