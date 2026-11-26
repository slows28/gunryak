extends SceneTree
const WarSim=preload("res://scripts/war_sim.gd")
var failures:=0

# Shared with graphical captures so the displayed order comes from the same AI.
static func stage(sim) -> void:
    sim.enemy_strategy_enabled=false
    sim.tactical_enabled=true
    for u in sim.units:
        u["troops"]=u["initial_troops"] if u["id"] in [0,1,3] else 0.0
        u["ai_cooldown"]=1000.0
    var general: Dictionary=sim.find_unit(0)
    var ally: Dictionary=sim.find_unit(1)
    var enemy: Dictionary=sim.find_unit(3)
    general["pos"]=Vector2(665,738)
    general["facing"]=Vector2.RIGHT
    ally["pos"]=Vector2(742,796)
    ally["morale"]=38.0
    enemy["pos"]=Vector2(792,766)
    enemy["facing"]=Vector2.LEFT
    enemy["type"]="보병"
    for member in [general,ally,enemy]: member["goal"]=member["pos"]
    sim.issue_map_order(0,"공격",Vector2(1080,720),1)
    sim.start()

static func expose_opening(sim) -> void:
    var ally: Dictionary=sim.find_unit(1)
    ally["pos"]=Vector2(595,815)
    ally["morale"]=90.0
    var enemy: Dictionary=sim.find_unit(3)
    enemy["troops"]=1550.0
    enemy["cohesion"]=38.0
    enemy["morale"]=44.0

func check(ok: bool, label: String) -> void:
    if ok: print("PASS ",label)
    else:
        failures+=1
        push_error(label)

func _initialize() -> void:
    var sim:=WarSim.new()
    sim.set_long_operation(true)
    sim.set_scenario(WarSim.TRAINING_SCENARIO)
    stage(sim)
    var general:=sim.find_unit(0)
    var ally:=sim.find_unit(1)
    var enemy:=sim.find_unit(3)
    general["ai_cooldown"]=0.0
    sim.step(0.1)
    check(general["action"]=="아군 보호" and general["field_choice"].get("ally")==1,"endangered ally interrupts a delivered attack order")
    var gap: float=(ally["pos"] as Vector2).distance_to(enemy["pos"])
    check((general["goal"] as Vector2).distance_to(ally["pos"])<gap and (general["goal"] as Vector2).distance_to(enemy["pos"])<gap,"intercept point lies between the observed threat and friend")
    var old: Vector2=general["pos"]
    var intercept: Vector2=general["goal"]
    sim._move_unit(general,0.1)
    check((general["pos"] as Vector2).distance_to(intercept)<old.distance_to(intercept) and not sim.march_plans.has(0),"protector actually closes on its intercept")
    expose_opening(sim)
    general["ai_cooldown"]=0.0
    sim.step(0.1)
    check(general["action"]=="공격 지속" and general["field_choice"].get("target")==3,"same general and order press the exposed enemy once ally is safe")
    check((general["goal"] as Vector2).distance_to(enemy["pos"])<8.0,"attack uses observed target position")
    general["pos"]=(enemy["pos"] as Vector2)-Vector2(22,0)
    var before: float=general["damage_dealt"]
    sim.step(0.1)
    check(general["damage_dealt"]>before,"pressed attack makes physical contact and deals damage")
    general["tactical_order"]="철수"
    general["tactical_until"]=sim.battle_time+10
    sim._decide(general)
    check(general["field_choice"].is_empty() and general["action"]=="전술 철수","delivered withdrawal overrides initiative")
    general["tactical_until"]=0.0
    enemy["pos"]=Vector2(2150,1350)
    sim._decide(general)
    check(general["field_choice"].is_empty() and general["goal"]==general["order_destination"],"lost observation restores original destination")
    var plans:=sim.LinkedMarch.plan(sim,{},0.1)
    check(plans.has(0),"linked march resumes with the same ally after danger passes")
    if failures==0: print("GUNRYAK_FIELD_JUDGMENT_PASS")
    quit(1 if failures else 0)
