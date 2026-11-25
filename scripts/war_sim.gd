extends RefCounted
## Independent battle model: no UI nodes, textures, or rendering calls.
## Intentionally bounded fixed-step updates; safe for headless simulation tests.

const GeneralMind = preload("res://scripts/general_mind.gd")
const FIELD_W: float = 900.0
const FIELD_H: float = 570.0
# Compact mode remains available for legacy regression fixtures. The game uses wide mode.
var wide_field: bool = false
var six_armies: bool = false
var long_operation: bool = false
var enemy_strategy_enabled: bool = true
var next_enemy_strategy: float = 0.0
var enemy_replans: int = 0
const OPERATION_SCALE: float = 4.0
const LONG_LIMIT: float = 375.0
const LONG_OBJECTIVE_OPEN: float = 270.0
var field_size: Vector2 = Vector2(FIELD_W,FIELD_H)
var layout_scale: float = 1.0
const TURN_SECONDS: float = 18.0
const LAST_TURN: int = 10
const MAX_SECONDS: float = TURN_SECONDS * float(LAST_TURN)
const SUPPLY_RADIUS: float = 182.0
const AI_VISION_RANGE: float = 285.0
const MAX_TROOPS: float = 5000.0
const ARMY_SCALE: float = 32.0
const LARGE_FORMATIONS = ["횡대","종대","방진","어린진","학익진","봉시진","안행진"]
const OUTPOST_RADIUS: float = 58.0
const OUTPOST_CAPTURE_SECONDS: float = 7.0
const OUTPOST_HOLD_SECONDS: float = 8.0

var units: Array[Dictionary] = []
var bases: Array[Dictionary] = []
var commanders: Array[Dictionary] = []
var couriers: Array[Dictionary] = []
var events: Array[String] = []
var outposts: Array[Dictionary] = []
var scouts: Array[Dictionary] = []
var intelligence: Array[Dictionary] = [{}, {}]
var reserve_next: Array[float] = [18.0, 18.0]
var reserve_limit: Array[int] = [2,2]
var winning_side: int = -1
var convoy: Dictionary = {}
# Enabled by the game; legacy fixtures can opt out to isolate basic mechanics.
var tactical_enabled: bool = false
var command_points: int = 3
var situation_reports: Array[Dictionary] = []
var situation_keys: Dictionary = {}
var situation_serial: int = 0
var tactical_delivered: int = 0
var tactical_refused: int = 0
var last_situation_scan: float = -5.0
var scenario_id: int = 0
var scenario_title: String = "북남 요충지"
var scenario_goal: String = "두 요충지를 동시에 점령하고 유지"
var scenario_limit: float = MAX_SECONDS
var forests: Array[Rect2] = []
var hill: Rect2 = Rect2(400, 213, 108, 89)
var timeline: Array[Dictionary] = []
var visual_effects: Array[Dictionary] = []
var dust_effects: Array[Dictionary] = []
const DUST_LIFE: float = 1.8
const DUST_LIMIT: int = 180
var troop_history: Array[Dictionary] = []
var sample_at: float = 0.0
var mind_sample_at: float = 0.0
var pending_reports: Array[Dictionary] = []
var structures: Array[Dictionary] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var battle_time: float = 0.0
var turn: int = 1
var started: bool = false
var paused: bool = false
var finished: bool = false
var result: String = ""
var next_id: int = 0
var reinforcements_used: Array[int] = [0, 0]
var step_count: int = 0
var intercepted_orders: int = 0
var delivered_orders: int = 0

func _init() -> void:
    reset()

func reset() -> void:
    timeline.clear()
    structures.clear()
    visual_effects.clear()
    dust_effects.clear()
    troop_history.clear()
    sample_at = 0.0
    mind_sample_at=0.0
    pending_reports.clear()
    units.clear()
    bases.clear()
    commanders.clear()
    couriers.clear()
    events.clear()
    outposts.clear()
    scouts.clear()
    intelligence = [{}, {}]
    reserve_next = [18.0, 18.0]
    reserve_limit = [2,2]
    winning_side = -1
    convoy.clear()
    command_points = 3
    situation_reports.clear()
    situation_keys.clear()
    situation_serial = 0
    tactical_delivered = 0
    tactical_refused = 0
    last_situation_scan = -5.0
    rng.seed = 20261124
    next_id = 0
    battle_time = 0.0
    step_count = 0
    next_enemy_strategy=0.0
    enemy_replans=0
    intercepted_orders = 0
    delivered_orders = 0
    turn = 1
    started = false
    paused = false
    finished = false
    result = ""
    reinforcements_used = [0, 0]
    _add_unit(0, "왕평", "보병", "신중", 86.0, Vector2(130, 153), "북측 확보", 145.0)
    _add_unit(0, "마속", "궁병", "균형", 55.0, Vector2(105, 278), "중앙 진격", 108.0)
    _add_unit(0, "위연", "기병", "공격", 79.0, Vector2(133, 431), "남측 우회", 95.0)
    _add_unit(1, "장합", "보병", "신중", 86.0, Vector2(760, 158), "북측 확보", 152.0)
    _add_unit(1, "위군 궁대", "궁병", "균형", 65.0, Vector2(787, 294), "중앙 진격", 102.0)
    _add_unit(1, "위군 기병", "기병", "공격", 66.0, Vector2(755, 437), "남측 우회", 96.0)
    if six_armies:
        _add_unit(0,"강유","궁병","균형",83.0,Vector2(175,215),"북측 확보",120.0)
        _add_unit(0,"관흥","기병","공격",78.0,Vector2(180,375),"남측 우회",110.0)
        _add_unit(0,"장익","보병","신중",82.0,Vector2(80,360),"본진 방어",135.0)
        _add_unit(1,"곽회","보병","신중",83.0,Vector2(715,220),"북측 확보",125.0)
        _add_unit(1,"비요","기병","공격",76.0,Vector2(720,375),"남측 우회",110.0)
        _add_unit(1,"왕쌍","보병","균형",80.0,Vector2(820,360),"본진 방어",135.0)
        reserve_limit = [1,1]
        var manpower: Array[int] = [4500,3500,3200,4800,3300,3200,4000,3800,4500,4100,3600,4200]
        var shapes: Array[String] = ["방진","안행진","봉시진","어린진","안행진","봉시진","학익진","어린진","방진","학익진","봉시진","방진"]
        for i in range(units.size()):
            units[i]["troops"] = float(manpower[i])
            units[i]["initial_troops"] = float(manpower[i])
            units[i]["formation"] = shapes[i]
            units[i]["policy"] = "현장 판단"
    outposts.append({"name":"북측 요충지", "pos":Vector2(435, 148), "owner":-1, "challenger":-1, "progress":0.0, "hold":0.0})
    outposts.append({"name":"남측 관문", "pos":Vector2(470, 423), "owner":-1, "challenger":-1, "progress":0.0, "hold":0.0})
    bases.append(_base(0, Vector2(116, 310)))
    bases.append(_base(1, Vector2(781, 310)))
    commanders.append({"side":0, "pos":Vector2(54, 515), "goal":Vector2(54, 515)})
    commanders.append({"side":1, "pos":Vector2(846, 515), "goal":Vector2(846, 515)})
    scouts.append({"side":0, "pos":Vector2(145, 230), "goal":Vector2(375, 120), "leg":0, "alive":true, "report_timer":0.0, "reports":0})
    scouts.append({"side":1, "pos":Vector2(755, 340), "goal":Vector2(525, 440), "leg":0, "alive":true, "report_timer":0.0, "reports":0})
    _configure_scenario()
    _configure_structures()
    _expand_layout()
    _log("출전 편성 준비: " + scenario_title)

func _add_unit(side: int, title: String, unit_type: String, disposition: String, ability: float, start: Vector2, mission: String, people: float) -> void:
    var unit: Dictionary = {
        "id": next_id, "side": side, "name": title, "type": unit_type,
        "personality": disposition, "ability": ability,
        "pos": start, "facing": Vector2.RIGHT if side == 0 else Vector2.LEFT,
        "goal": start, "mission": mission,
        "policy": "현장 판단", "formation": "횡대", "next_formation": "",
        "form_remaining": 0.0, "form_duration": 1.0, "motion_speed": 0.0, "dust_distance": 0.0, "troops": people, "initial_troops": people,
        "morale": 100.0, "out_supply": 0.0, "supplied": true,
        "action": "대기", "reason": "초기 배치", "ai_cooldown": 0.0,
        "contact_target_id":-1,
        "charge": 0.0, "last_raid": -999.0, "contact_troops": 0,
        "front_pressure": 0.0, "pushed_distance": 0.0,
        "decisions": 0, "reforms_completed": 0, "damage_dealt": 0.0,
        "casualties_taken": 0.0, "supply_guard_time": 0.0,
        "raid_active": false, "raid_target": Vector2.ZERO, "raid_until": 0.0,
        "fatigue": 0.0, "cohesion": 100.0, "rations": 100.0, "ammo": 100.0,
        "rallying": false, "last_morale_event": -100.0, "objective_time": 0.0,
        "flank_hits": 0.0, "shots_used": 0.0, "last_supply_warning": -100.0,
        "leadership":ability, "martial":ability, "intelligence":ability, "judgment":ability, "loyalty":75.0,
        "obedience":"성향 기반", "deviations":0, "last_deviation":-100.0,
        "memory_pos":Vector2.ZERO, "memory_time":-100.0, "memory_id":-1,
        "ambush_ready":0.0, "ambush_until":-1.0, "ambushes":0,
        "charge_dir":Vector2.ZERO, "charge_speed":0.0, "charge_cooldown":0.0, "charges":0,
        "surrounded":false, "encircled_time":0.0, "routed":false, "rout_count":0, "deserted":0.0,
        "general_hp":100.0, "general_state":"건재", "general_risk":0.0, "reserve":false,
        "waypoints":[], "waypoint_index":0, "defense_anchor":Vector2.ZERO, "defense_set":false,
        "supply_priority":1, "deputy_index":0, "active_deputy":false, "last_timeline_action":"대기", "last_visual":-100.0, "last_hit":-100.0, "structure_damage":0.0, "tactical_order":"", "tactical_target":-1, "tactical_anchor":start, "tactical_until":0.0, "initiative_until":0.0, "link_id":-1, "assigned_link":-1, "order_destination":Vector2.ZERO, "has_destination":false, "destination_reached":false, "flank_target":-1, "flank_goal":Vector2.ZERO, "flank_until":0.0, "flank_phase":0, "linked_hits":0.0, "counter_damage":0.0, "flank_damage":0.0, "maneuver_distance":0.0, "support_seconds":0.0, "flank_completed":0, "screened_damage":0.0, "screen_events":0, "ai_role":"", "ai_partner":-1, "ai_role_until":0.0, "ai_replans":0, "bridge_y":-1.0, "bridge_bank":0, "bridge_crossings":0, "blocked_water_steps":0, "guard_intercept_damage":0.0, "guard_intercept_ticks":0, "flank_commits":0, "flank_aborts":0, "flank_recovery":0.0, "flank_contact_at":-100.0
    }
    _set_general_profile(unit)
    unit["mind"]=GeneralMind.initial(unit)
    if unit_type == "기병":
        unit["formation"] = "종대"
    next_id += 1
    units.append(unit)

func _base(side: int, at: Vector2) -> Dictionary:
    return {
        "side":side, "pos":at, "target":at, "state":"가동",
        "build_timer":0.0, "last_relocate":-40.0, "alive":true, "stock":100.0
    }

func _log(message: String) -> void:
    events.append("[%02d턴] %s" % [turn, message])
    if timeline.size() < 1200:
        timeline.append({"time":battle_time,"turn":turn,"message":message})
    if events.size() > 24:
        events.pop_front()

func start() -> void:
    if started or finished:
        return
    if wide_field and not six_armies:
        _deploy_detachments()
    started = true
    _log("전투 개시. " + scenario_goal)

func select_unit_mission(unit_id: int, mission: String, policy: String, partner: int = -1) -> bool:
    if started:
        return false
    var unit: Dictionary = find_unit(unit_id)
    if unit.is_empty() or int(unit["side"]) != 0:
        return false
    if not _valid_partner(unit,partner): return false
    unit["mission"] = mission
    unit["has_destination"]=false
    unit["destination_reached"]=false
    _reset_cooperation(unit,partner)
    _apply_policy(unit, policy)
    if policy.ends_with(" 유지") and policy.replace(" 유지","") in LARGE_FORMATIONS:
        unit["formation"] = policy.replace(" 유지", "")
    return true

func find_unit(unit_id: int) -> Dictionary:
    for unit in units:
        if int(unit["id"]) == unit_id:
            return unit
    return {}

func request_order(unit_id: int, mission: String, policy: String, partner: int = -1, destination: Vector2 = Vector2(-1,-1)) -> bool:
    if not started or finished or turn < 6:
        return false
    var unit: Dictionary = find_unit(unit_id)
    if unit.is_empty() or int(unit["side"]) != 0 or float(unit["troops"]) <= 0.0:
        return false
    if not _valid_partner(unit,partner): return false
    # Limit unfinished courier orders; avoids accidental spam and runaway entities.
    for courier in couriers:
        if int(courier["unit_id"]) == unit_id:
            return false
    couriers.append({
        "pos":commanders[0]["pos"], "unit_id":unit_id,
        "mission":mission, "policy":policy, "side":int(unit["side"]), "partner":partner, "destination":destination
    })
    _log("전령 파견 → %s / %s" % [str(unit["name"]), mission])
    return true

func reposition_commander(forward: bool) -> void:
    if finished:
        return
    commanders[0]["goal"] = layout_point(Vector2(270,346) if forward else Vector2(54,515))
    _log("책사 이동: %s" % ("전진 지휘" if forward else "본진 복귀"))

func step(dt: float) -> void:
    if not started or finished or paused:
        return
    dt = clampf(dt, 0.0, 0.1)
    if dt <= 0.0:
        return
    battle_time += dt
    step_count += 1
    var current_turn: int = int(floor(battle_time / (15.0 if long_operation else TURN_SECONDS))) + 1
    if current_turn != turn:
        turn = current_turn
        _on_new_turn()
    _move_commanders(dt)
    _update_scouts(dt)
    _deliver_intel()
    _update_reserves()
    _update_couriers(dt)
    _supply_logic(dt)
    if long_operation and enemy_strategy_enabled and battle_time>=next_enemy_strategy:
        next_enemy_strategy=battle_time+8.0
        _enemy_strategy()
    # We use a shallow fixed unit pool and never mutate it during these loops.
    for unit in units:
        if float(unit["troops"]) <= 0.0:
            continue
        _update_general_conditions(unit, dt)
        unit["ai_cooldown"] = float(unit["ai_cooldown"]) - dt
        if float(unit["ai_cooldown"]) <= 0.0:
            _decide(unit)
            unit["ai_cooldown"] = 1.4 + (100.0 - _effective_stat(unit, "judgment")) * 0.015
        _formation_transition(unit, dt)
    for unit in units:
        if float(unit["troops"]) > 0.0:
            _move_unit(unit, dt)
    _resolve_frontline(dt)
    _update_structures(dt)
    _update_convoy(dt)
    _update_battle_condition(dt)
    _combat(dt)
    _update_outposts(dt)
    if tactical_enabled:
        _scan_situations()
    _check_victory()
    if battle_time>=mind_sample_at or finished:
        mind_sample_at=battle_time+0.25
        for u in units:
            if not u.has("parent_id"): u["mind"]=GeneralMind.update(u,battle_time)
        _update_response_outcomes()
    _record_presentation()

func _on_new_turn() -> void:
    _log("작전 %d턴 진입" % turn)
    if turn == 6:
        _log("전령 명령 활성화 — 전달 시간은 책사 위치에서 계산")
    if tactical_enabled and turn >= 6:
        command_points = mini(4,command_points+1)

func _move_commanders(dt: float) -> void:
    for c in commanders:
        var p: Vector2 = c["pos"]
        var target: Vector2 = c["goal"]
        c["pos"] = p.move_toward(target, 43.0 * dt)

func _update_couriers(dt: float) -> void:
    for i in range(couriers.size() - 1, -1, -1):
        var letter: Dictionary = couriers[i]
        var target: Dictionary = find_unit(int(letter["unit_id"]))
        if target.is_empty() or float(target["troops"]) <= 0.0:
            _response_delivery(letter,"수신 부대 상실")
            couriers.remove_at(i)
            continue
        var p: Vector2 = letter["pos"]
        var target_pos: Vector2 = target["pos"]
        var route_goal: Vector2 = _courier_route(letter, target_pos)
        letter["pos"] = p.move_toward(route_goal, 140.0 * dt)
        if _courier_intercepted(letter):
            intercepted_orders += 1
            _response_delivery(letter,"전령 차단")
            _log("%s에게 가던 전령이 적에 의해 차단됨" % str(target["name"]))
            couriers.remove_at(i)
            continue
        if (letter["pos"] as Vector2).distance_to(target_pos) < 16.0:
            delivered_orders += 1
            if letter.has("tactical_order"):
                _deliver_tactical(target,letter)
                couriers.remove_at(i)
                continue
            if bool(letter.get("appoint_deputy", false)):
                target["active_deputy"] = true
                target["ai_cooldown"] = 0.0
                _log("%s: %s 지휘 승계 명령 도착" % [str(target["name"]), deputy_name(target)])
                couriers.remove_at(i)
                continue
            target["mission"] = str(letter["mission"])
            var partner: int=int(letter.get("partner",-1))
            _reset_cooperation(target,partner if _valid_partner(target,partner) else -1)
            _apply_policy(target, str(letter["policy"]))
            target["waypoints"].clear()
            target["waypoint_index"] = 0
            target["defense_set"] = false
            var destination: Vector2=letter.get("destination",Vector2(-1,-1))
            target["has_destination"]=destination.x>=0.0 and destination.y>=0.0
            target["order_destination"]=_field_point(destination) if bool(target["has_destination"]) else Vector2.ZERO
            target["destination_reached"]=false
            target["ai_cooldown"] = 0.0
            GeneralMind.order(target,"수령: "+str(letter["mission"]),battle_time)
            _log("%s: 전령 도착 / 새 명령 '%s'" % [str(target["name"]), str(letter["mission"])])
            couriers.remove_at(i)


# An actual enemy must physically meet a courier. Nearby friendly units can
# escort it; no global dice roll or telepathic order delivery.
func _courier_intercepted(letter: Dictionary) -> bool:
    var p: Vector2 = letter["pos"]
    var side: int = int(letter["side"])
    var threatened: bool = false
    for unit in units:
        if float(unit["troops"]) <= 0.0:
            continue
        if int(unit["side"]) != side and not bool(unit["routed"]) and (unit["pos"] as Vector2).distance_to(p) <= 24.0:
            threatened = true
            break
    if not threatened:
        return false
    for escort in units:
        if int(escort["side"]) == side and float(escort["troops"]) > 0.0 and not bool(escort["routed"]):
            if (escort["pos"] as Vector2).distance_to(p) <= 48.0:
                return false
    return true

func _supply_logic(dt: float) -> void:
    for base in bases:
        if not bool(base["alive"]):
            continue
        var side: int = int(base["side"])
        var bp: Vector2 = base["pos"]
        # An observed enemy unit close to an undefended base can disable it.
        for unit in units:
            if int(unit["side"]) != side and float(unit["troops"]) > 0.0 and not bool(unit["routed"]):
                var ep: Vector2 = unit["pos"]
                if ep.distance_to(bp) < 22.0 and not _supply_is_guarded(base):
                    base["alive"] = false
                    base["state"] = "파괴"
                    _log("%s 보급기지 습격 성공" % ("아군" if side == 0 else "적군"))
                    break
        if not bool(base["alive"]):
            continue
        if str(base["state"]) == "이동":
            base["pos"] = bp.move_toward(base["target"], 54.0 * dt)
            if (base["pos"] as Vector2).distance_to(base["target"]) <= 3.0:
                base["state"] = "설치"
                base["build_timer"] = 3.0
        elif str(base["state"]) == "설치":
            base["build_timer"] = float(base["build_timer"]) - dt
            if float(base["build_timer"]) <= 0.0:
                base["state"] = "가동"
                _log("%s 보급기지 재설치 완료" % ("아군" if side == 0 else "적군"))
        elif not bool(base.get("fixed", false)) and battle_time - float(base["last_relocate"]) > 26.0:
            var desired: Vector2 = _best_supply_position(side)
            if bp.distance_to(desired) > 135.0:
                base["target"] = desired
                base["state"] = "이동"
                base["last_relocate"] = battle_time
                _log("%s 보급부대 전선 따라 이동" % ("아군" if side == 0 else "적군"))
    for base in bases:
        if bool(base["alive"]) and str(base["state"]) == "가동":
            base["stock"] = minf(100.0,float(base["stock"])+dt*(1.15 if six_armies else 0.60))
    var supply_queue: Array[Dictionary] = units.duplicate()
    supply_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if int(a["supply_priority"]) != int(b["supply_priority"]):
            return int(a["supply_priority"]) > int(b["supply_priority"])
        if float(a["rations"]) != float(b["rations"]):
            return float(a["rations"]) < float(b["rations"])
        return int(a["id"]) < int(b["id"]))
    for unit in supply_queue:
        if float(unit["troops"]) <= 0.0:
            continue
        var own_base: Dictionary = bases[int(unit["side"])]
        if bool(own_base["alive"]) and (unit["pos"] as Vector2).distance_to(own_base["pos"]) < 75.0:
            unit["supply_guard_time"] = float(unit["supply_guard_time"]) + dt
        var provided: bool = _has_supply(int(unit["side"]), unit["pos"])
        unit["supplied"] = provided
        if provided and float(own_base["stock"]) > 0.1:
            unit["out_supply"] = 0.0
            var share: float = float(unit.get("strength_share",1.0))
            var ration_fill: float = minf(minf(100.0 - float(unit["rations"]), dt * 2.5), float(own_base["stock"])/share)
            unit["rations"] = float(unit["rations"]) + ration_fill
            own_base["stock"] = maxf(0.0, float(own_base["stock"]) - ration_fill*share)
            if str(unit["type"]) == "궁병":
                var ammo_fill: float = minf(minf(100.0 - float(unit["ammo"]), dt * 2.0), float(own_base["stock"])/share)
                unit["ammo"] = float(unit["ammo"]) + ammo_fill
                own_base["stock"] = maxf(0.0, float(own_base["stock"]) - ammo_fill*share)
        else:
            unit["supplied"] = false
            unit["rations"] = maxf(0.0, float(unit["rations"]) - dt * (0.32 if long_operation else (0.44 if wide_field else 0.65)))
            unit["out_supply"] = float(unit["out_supply"]) + dt
            if float(unit["out_supply"]) >= TURN_SECONDS * 3.0:
                unit["morale"] = maxf(0.0, float(unit["morale"]) - dt * 0.15)

func _supply_is_guarded(base: Dictionary) -> bool:
    for guard in units:
        if int(guard["side"]) == int(base["side"]) and float(guard["troops"]) > 18.0 and not bool(guard["routed"]):
            if (guard["pos"] as Vector2).distance_to(base["pos"]) <= 76.0:
                return true
    return false

func _supply_under_threat(side: int) -> bool:
    var base: Dictionary = bases[side]
    if not bool(base["alive"]):
        return false
    for enemy in units:
        if int(enemy["side"]) != side and float(enemy["troops"]) > 0.0:
            if (enemy["pos"] as Vector2).distance_to(base["pos"]) <= 165.0:
                return true
    return false

func _has_supply(side: int, position: Vector2) -> bool:
    for base in bases:
        if int(base["side"]) == side and bool(base["alive"]) and str(base["state"]) == "가동":
            var bp: Vector2 = base["pos"]
            if bp.distance_to(position) <= (SUPPLY_RADIUS*1.6 if six_armies else SUPPLY_RADIUS):
                return true
    return false

func _best_supply_position(side: int) -> Vector2:
    var focus: Vector2 = layout_point(Vector2(170,275) if side == 0 else Vector2(730,275))
    var strength: float = 0.0
    for unit in units:
        if int(unit["side"]) == side and float(unit["troops"]) > 0.0:
            focus += (unit["pos"] as Vector2) * (float(unit["troops"]) / 100.0)
            strength += float(unit["troops"]) / 100.0
    focus /= 1.0 + strength
    var direction: float = -1.0 if side == 0 else 1.0
    var suggested: Vector2 = Vector2(clampf(focus.x + 105.0 * direction, 75.0, field_size.x - 75.0), clampf(focus.y, 95.0, field_size.y - 75.0))
    var candidates: Array[Vector2] = [suggested, suggested + Vector2(0, -68), suggested + Vector2(0, 68)]
    var winning: Vector2 = suggested
    var best_score: float = -100000.0
    for candidate in candidates:
        candidate = _field_point(candidate)
        var score: float = -120.0 if six_armies and terrain_at(candidate) == "하천" else 0.0
        for unit in units:
            if float(unit["troops"]) <= 0.0:
                continue
            var d: float = (unit["pos"] as Vector2).distance_to(candidate)
            if int(unit["side"]) == side:
                score += float(unit["troops"]) * (1.0 if d <= (SUPPLY_RADIUS*1.6 if six_armies else SUPPLY_RADIUS) else 0.0)
            elif d < 190.0:
                score -= (190.0 - d) * 1.2
        if score > best_score:
            best_score = score
            winning = candidate
    return winning

func _nearest_enemy(unit: Dictionary) -> Dictionary:
    var nearest: Dictionary = {}
    var nearest_d: float = 100000.0
    var p: Vector2 = unit["pos"]
    for enemy in units:
        if int(enemy["side"]) == int(unit["side"]) or float(enemy["troops"]) <= 0.0:
            continue
        var d: float = (enemy["pos"] as Vector2).distance_to(p)
        if d < nearest_d:
            nearest = enemy
            nearest_d = d
    return nearest

func _nearest_visible_enemy(unit: Dictionary) -> Dictionary:
    var nearest: Dictionary = {}
    var nearest_distance: float = AI_VISION_RANGE * 1.25
    var position: Vector2 = unit["pos"]
    for enemy in units:
        if int(enemy["side"]) == int(unit["side"]) or float(enemy["troops"]) <= 0.0:
            continue
        var distance: float = position.distance_to(enemy["pos"])
        var vision: float = AI_VISION_RANGE * (0.85 + _effective_stat(unit, "intelligence") * 0.002)
        if _in_forest(enemy["pos"]):
            vision *= 0.68
            if float(enemy["ambush_ready"]) >= 3.0:
                vision *= 0.48
        if terrain_at(position) == "고지":
            vision *= 1.15
        if distance < minf(nearest_distance, vision):
            nearest_distance = distance
            nearest = enemy
    return nearest

func _can_see_base(unit: Dictionary, target_base: Dictionary) -> bool:
    if not bool(target_base["alive"]):
        return false
    var p: Vector2 = unit["pos"]
    var b: Vector2 = target_base["pos"]
    return p.distance_to(b) < 210.0

func _decide(unit: Dictionary) -> void:
    var nearest: Dictionary = _nearest_visible_enemy(unit)
    var side: int = int(unit["side"])
    var pos: Vector2 = unit["pos"]
    unit["decisions"] = int(unit["decisions"]) + 1
    var personality: String = str(unit["personality"])
    var ability: float = _effective_stat(unit, "judgment")
    var troops: float = float(unit["troops"])
    var morale: float = float(unit["morale"])
    var goal: Vector2 = _mission_point(side, str(unit["mission"]))
    var objective: Dictionary = _assigned_outpost(unit)
    var action: String = "진격"
    var reason: String = "초기 목표를 향해 이동"
    var enemy_distance: float = 9999.0
    var relative_strength: float = 1.0
    if not nearest.is_empty():
        var epos: Vector2 = nearest["pos"]
        enemy_distance = pos.distance_to(epos)
        relative_strength = troops / maxf(20.0, float(nearest["troops"]))
        unit["memory_pos"] = epos
        unit["memory_time"] = battle_time
        unit["memory_id"] = int(nearest["id"])
    else:
        _read_scout_report(unit)
    # Safety overrides: any personality can withdraw if its own formation collapses.
    if bool(unit["routed"]):
        action = "패주"
        reason = "지휘 통제 상실: 생존 병력이 본진으로 도주"
        goal = _home_point(side)
    elif troops < (600.0 if six_armies else 24.0) or morale < 19.0:
        action = "후퇴"
        reason = "붕괴 위험: 전선을 이탈하고 재집결"
        goal = Vector2(86.0*layout_scale if side == 0 else 815.0*layout_scale,pos.y)
    elif bool(unit["rallying"]) or float(unit["cohesion"]) < 30.0:
        if float(unit["cohesion"]) >= 72.0 and float(unit["fatigue"]) < 55.0:
            unit["rallying"] = false
        else:
            unit["rallying"] = true
            action = "재집결"
            reason = "응집력 저하: 아군 후방에서 전열 재정비"
            goal = _rally_point(unit)
    elif float(unit["fatigue"]) > 83.0 and enemy_distance > 105.0:
        action = "휴식"
        reason = "전투 피로 누적: 안전 거리에서 체력 회복"
        goal = pos
    elif str(unit["type"]) == "궁병" and enemy_distance < 110.0:
        # Real spatial withdrawal against observed melee pressure.
        # Retreat target is calculated from the visible opponent only.
        action = "거리 유지"
        reason = "궁병: 근접 위협을 피해 사격 거리를 확보"
        var escape: Vector2 = pos - (nearest["pos"] as Vector2)
        if escape.length_squared() < 0.001:
            escape = Vector2.LEFT if side == 0 else Vector2.RIGHT
        goal = pos + escape.normalized() * minf(110.0, 155.0 - enemy_distance)
        if str(unit["action"]) != "거리 유지":
            _log("%s 궁병이 근접 적을 피해 후방 기동" % str(unit["name"]))
    elif str(unit["type"]) == "궁병" and float(unit["ammo"]) < 12.0 and enemy_distance > 115.0 and bool(bases[side]["alive"]):
        action = "탄약 보충"
        reason = "잔여 화살 부족: 보급기지로 이동"
        goal = bases[side]["pos"]
    elif float(unit["rations"]) < 20.0 and enemy_distance > 125.0 and bool(bases[side]["alive"]):
        action = "보급 복귀"
        reason = "식량 부족: 전투 지속력을 회복"
        goal = bases[side]["pos"]
    elif not nearest.is_empty() and ability >= 70.0 and enemy_distance < 85.0 and _flank_threat(unit, nearest):
        action = "측면 방어"
        reason = "측후면 위협을 확인하고 전열을 재정렬"
        goal = pos
    elif _can_prepare_ambush(unit, nearest):
        action = "매복"
        reason = "숲에서 은폐하고 적의 접근을 기다림"
        goal = pos
    elif str(unit["type"]) == "보병" and personality == "신중" and ability >= 70.0 and not nearest.is_empty() and str(nearest["type"]) == "기병" and enemy_distance < 178.0:
        action = "방어"
        reason = "신중한 장수: 관측된 적 기병에 방진으로 대응"
        goal = pos
    elif str(unit["type"]) == "보병" and personality == "신중" and ability >= 80.0 and enemy_distance < 150.0 and relative_strength > 1.22 and str(unit["action"]) == "방어":
        action = "반격"
        reason = "적의 병력이 약해진 틈을 확인하고 제한 반격"
        goal = nearest["pos"]
    elif str(unit["type"]) == "보병" and personality == "신중" and _supply_under_threat(side) and pos.distance_to(bases[side]["pos"]) < 260.0 and enemy_distance >= 110.0:
        action = "보급 호위"
        reason = "보급기지에 접근하는 적을 발견해 수비"
        goal = bases[side]["pos"]
    elif str(unit["type"]) == "기병" and personality == "공격" and ability >= 72.0 and morale > 52.0 and relative_strength >= 0.75 and enemy_distance >= 92.0 and enemy_distance < 245.0:
        # Waypoint is built from an enemy we can actually SEE, not the full map.
        # Reaching the waypoint commits the unit to a strike on that enemy.
        if str(unit["action"]) == "측면 우회" and pos.distance_to(unit["goal"]) < 27.0:
            action = "돌파"
            reason = "측면 진입 성공: 관측한 적을 향해 돌격"
            goal = nearest["pos"]
        else:
            action = "측면 우회"
            reason = "공격형 장수: 적 정면을 피해 측면으로 기동"
            goal = _flank_waypoint(unit, nearest)
    elif not objective.is_empty() and enemy_distance >= 165.0:
        var site_pos: Vector2 = objective["pos"]
        action = "거점 방어" if int(objective["owner"]) == side else "거점 점령"
        reason = "작전 목표: %s 확보 및 유지" % str(objective["name"])
        goal = site_pos
    elif str(unit["mission"]) == "중앙 진격" and personality != "공격" and enemy_distance >= 165.0 and not _support_target(unit).is_empty():
        var ally: Dictionary = _support_target(unit)
        action = "전열 지원"
        reason = "%s의 전선 압박을 지원" % str(ally["name"])
        goal = (ally["pos"] as Vector2) + (Vector2.LEFT if side == 0 else Vector2.RIGHT) * 52.0
    elif enemy_distance < 165.0 and personality == "신중" and relative_strength < 0.94:
        action = "방어"
        reason = "적군 우세를 감지해 방어 진형 유지"
        if str(unit["action"]) == "방어":
            goal = unit["goal"]
        else:
            goal = pos
    elif enemy_distance < 175.0 and personality == "공격" and morale > 48.0 and relative_strength > 0.65:
        action = "돌파"
        reason = "공격 성향: 적의 약한 부분을 집중 압박"
        goal = nearest["pos"]
    elif enemy_distance < 160.0 and str(unit["type"]) == "궁병":
        action = "거리 유지"
        reason = "궁병: 유효 사거리에서 사격 대기"
        goal = pos
    elif enemy_distance < 165.0:
        action = "교전"
        reason = "전선 접촉: 적 병력과 교전"
        goal = nearest["pos"]
    elif nearest.is_empty() and float(unit["memory_time"]) > battle_time - 16.0 and pos.distance_to(unit["memory_pos"]) > 40.0 and str(unit["mission"]) != "본진 방어":
        action = "정보 확인"
        reason = "마지막 관측 또는 정찰 보고 지점을 확인"
        goal = unit["memory_pos"]
    # Raids persist for a bounded mission window. Prior logic issued a raid,
    # then abandoned it at the very next ~2 s AI tick due to its cooldown.
    # The destination is the last OBSERVED base position, not omniscient tracking.
    var enemy_base: Dictionary = bases[1 - side]
    var raid_allowed: bool = personality == "공격" and ability > 60.0 and action not in ["후퇴", "패주", "재집결", "휴식", "보급 복귀", "탄약 보충", "거점 방어", "매복"]
    if raid_allowed and bool(unit["raid_active"]) and battle_time < float(unit["raid_until"]) and bool(enemy_base["alive"]):
        if _can_see_base(unit, enemy_base):
            unit["raid_target"] = enemy_base["pos"]
        action = "기지 습격"
        reason = "보급기지 습격 지속: 마지막 관측 지점을 추적"
        goal = unit["raid_target"]
    elif raid_allowed and _can_see_base(unit, enemy_base) and battle_time - float(unit["last_raid"]) > 12.0:
        unit["raid_active"] = true
        unit["last_raid"] = battle_time
        unit["raid_until"] = battle_time + 10.0
        unit["raid_target"] = enemy_base["pos"]
        action = "기지 습격"
        reason = "적 보급기지를 발견하여 우회 공격"
        goal = unit["raid_target"]
    else:
        unit["raid_active"] = false
    # Skill affects tactical execution via choices rather than raw troop strength.
    if enemy_distance < 150.0 and ability < 65.0 and not bool(unit["raid_active"]) and action in ["교전", "돌파", "방어", "진격"] and rng.randf() < 0.13:
        action = "진격" if personality != "신중" else "방어"
        reason = "불확실한 전황 판단으로 대응이 지연됨"
        goal = _mission_point(side, str(unit["mission"])) if action == "진격" else pos
    var compliant: Dictionary = _enforce_orders(unit, action, reason, goal, enemy_distance)
    action = str(compliant["action"])
    reason = str(compliant["reason"])
    goal = compliant["goal"]
    if scenario_id == 3 and not convoy.is_empty() and action not in ["후퇴","패주","재집결","휴식","보급 복귀","탄약 보충","거리 유지","측면 방어"] and enemy_distance > 105.0:
        action = "호위" if side == 0 else "차단"
        reason = "군량 수레 접근"
        goal = (convoy["pos"] as Vector2) + Vector2(34 if side == 0 else 70,0)
        if long_operation:
            # Spread default escorts around the wagon instead of stacking at one point.
            var rank: int = command_ids(side).find(int(unit["id"]))
            if rank >= 0:
                var lane: float = float(rank % 3 - 1) * 70.0
                goal += Vector2(-55.0 if rank >= 3 else 0.0, lane)
            # Leave one living infantry formation with the commander by default.
            # Explicit map destinations and non-default missions take precedence.
            if _escort_rearguard(side) == int(unit["id"]):
                action = "책사 호위"
                reason = "군량 수레와 후방 지휘부를 분리하여 방어"
                goal = (commanders[side]["pos"] as Vector2) + Vector2(42.0 if side == 0 else -42.0,0)
    if wide_field and unit.has("parent_id") and enemy_distance > 165.0 and action not in ["후퇴","패주","재집결","휴식","보급 복귀","탄약 보충","매복"]:
        var parent: Dictionary = find_unit(int(unit["parent_id"]))
        if not parent.is_empty() and float(parent["troops"]) > 0.0 and not bool(parent["routed"]):
            var front: Vector2 = parent["facing"]
            var flank: Vector2 = front.orthogonal()*float(unit["wing"])*64.0
            goal = (parent["goal"] as Vector2)+flank-front*34.0
            if (parent["pos"] as Vector2).distance_to(pos) > 180.0:
                goal = (parent["pos"] as Vector2)+flank-front*34.0
            action = "분견 지원"
            reason = "본대 측면 엄호 및 합류"
    if six_armies and scenario_id != 3 and str(unit["mission"]) == "본진 방어" and action not in ["패주","후퇴","재집결","휴식","탄약 보충","보급 복귀","측면 방어"]:
        var base_pos: Vector2 = bases[side]["pos"]
        if enemy_distance > 110.0 or (not nearest.is_empty() and (nearest["pos"] as Vector2).distance_to(base_pos) > 210.0):
            action = "보급 호위"
            reason = "군단 후방 및 군량 보호"
            goal = base_pos+Vector2(65.0 if side == 0 else -65.0,0)
    if six_armies and str(unit["type"]) == "궁병" and enemy_distance > 165.0 and action in ["진격","거점 점령","거점 방어","전열 지원","명령 수행"] and str(unit["mission"]) not in ["측후방 기동","구원 지원"]:
        var screen: Dictionary = _infantry_screen(unit)
        if not screen.is_empty():
            var screen_pos: Vector2 = screen["pos"]
            var behind: Vector2 = Vector2.LEFT if side == 0 else Vector2.RIGHT
            goal = screen_pos+behind*100.0
            action = "전열 지원"
            reason = "보병 엄호 하에 후방 사격 위치 확보"
    if six_armies and (scenario_id!=3 or str(unit["mission"]) in ["전열 엄호","측후방 기동","구원 지원"]):
        var cooperation: Dictionary = _coordinated_order(unit,nearest,action,reason,goal)
        action=cooperation["action"]
        reason=cooperation["reason"]
        goal=cooperation["goal"]
    if six_armies:
        var directed: Dictionary = _destination_order(unit,nearest,action,reason,goal,enemy_distance)
        action=directed["action"]
        reason=directed["reason"]
        goal=directed["goal"]
    var planned: Dictionary = _apply_planned_route(unit, action, reason, goal, enemy_distance)
    action = str(planned["action"])
    reason = str(planned["reason"])
    goal = planned["goal"]
    if tactical_enabled:
        var response: Dictionary = _tactical_decision(unit,nearest,action,reason,goal,enemy_distance,relative_strength)
        action = response["action"]
        reason = response["reason"]
        goal = response["goal"]
    if action != str(unit["last_timeline_action"]):
        unit["last_timeline_action"] = action
        if int(unit["side"]) == 0 and timeline.size() < 1200:
            timeline.append({"time":battle_time,"turn":turn,"message":"%s: %s — %s" % [str(unit["name"]),action,reason]})
    unit["action"] = action
    unit["reason"] = reason
    unit["goal"] = _field_point(goal)
    unit["mind"]=GeneralMind.record(unit,nearest,action,reason,battle_time)
    var wanted: String = "횡대"
    if action in ["후퇴", "패주", "기지 습격", "돌파", "반격", "재집결", "보급 복귀", "탄약 보충", "전술 철수"]:
        wanted = "종대"
    elif action in ["방어", "보급 호위", "측면 방어", "거점 방어", "방어선 사수", "긴급 방어"]:
        wanted = "방진"
    elif str(unit["type"]) == "기병":
        wanted = "종대"
    if six_armies and action not in ["후퇴","패주","재집결","보급 복귀","탄약 보충","전술 철수"]:
        if wanted == "방진": wanted = "방진"
        elif str(unit["type"]) == "기병": wanted = "봉시진"
        elif str(unit["type"]) == "궁병": wanted = "안행진"
        elif action in ["돌파","반격","교전"]: wanted = "어린진"
        else: wanted = "학익진"
    if six_armies and action in ["지정 지역 사수","예비 대기"] and str(unit["type"])=="보병": wanted="방진"
    if six_armies and action in ["협동 엄호","궁병 보호"] and str(unit["type"])=="보병": wanted="방진"
    if six_armies and action in ["협동 우회","협동 대기"] and str(unit["type"])=="기병": wanted="봉시진"
    if long_operation and float(unit["bridge_y"])>=0.0 and absf(pos.x-river_x(pos.y))<130.0:
        wanted="종대"
    if str(unit["policy"]).ends_with(" 유지") and str(unit["policy"]).replace(" 유지","") in LARGE_FORMATIONS and action != "패주":
        wanted = str(unit["policy"]).replace(" 유지", "")
    # Cancel an obsolete re-formation order before it completes; otherwise
    # a later AI decision can apply a formation the general no longer wants.
    if wanted == str(unit["formation"]):
        unit["next_formation"] = ""
        unit["form_remaining"] = 0.0
    elif wanted != str(unit["next_formation"]):
        unit["next_formation"] = wanted
        unit["form_remaining"] = 2.1 + (100.0 - _effective_stat(unit, "leadership")) * 0.025
        unit["form_duration"] = unit["form_remaining"]


# A visible target's facing determines the offset, so the cavalry really travels
# to one flank. A cautious commander never calls this maneuver.
func _flank_waypoint(unit: Dictionary, enemy: Dictionary) -> Vector2:
    var enemy_facing: Vector2 = enemy["facing"]
    if enemy_facing.length_squared() <= 0.1:
        enemy_facing = Vector2.LEFT if int(enemy["side"]) == 1 else Vector2.RIGHT
    enemy_facing = enemy_facing.normalized()
    var lateral: Vector2 = Vector2(-enemy_facing.y, enemy_facing.x)
    var offset: Vector2 = (unit["pos"] as Vector2) - (enemy["pos"] as Vector2)
    var side_sign: float = 1.0 if lateral.dot(offset) >= 0.0 else -1.0
    if absf(lateral.dot(offset)) < 4.0:
        side_sign = 1.0 if int(unit["id"]) % 2 == 0 else -1.0
    return _field_point((enemy["pos"] as Vector2) + lateral * side_sign * 83.0 + enemy_facing * 24.0)

func _mission_point(side: int, mission: String) -> Vector2:
    var x: float = 680.0 if side == 0 else 220.0
    match mission:
        "북측 확보": return layout_point(Vector2(x,145.0))
        "남측 우회": return layout_point(Vector2(x,432.0))
        "본진 방어": return layout_point(Vector2(125.0,285.0) if side == 0 else Vector2(775.0,285.0))
        _: return layout_point(Vector2(x,287.0))

func _formation_transition(unit: Dictionary, dt: float) -> void:
    if str(unit["next_formation"]) == "":
        return
    unit["form_remaining"] = float(unit["form_remaining"]) - dt
    if float(unit["form_remaining"]) <= 0.0:
        unit["formation"] = str(unit["next_formation"])
        unit["next_formation"] = ""
        unit["form_remaining"] = 0.0
        unit["reforms_completed"] = int(unit["reforms_completed"]) + 1

func _move_unit(unit: Dictionary, dt: float) -> void:
    var pos: Vector2 = unit["pos"]
    var goal: Vector2 = unit["goal"]
    var enemy: Dictionary = _nearest_visible_enemy(unit)
    if not enemy.is_empty() and str(unit["action"]) not in ["후퇴", "기지 습격", "방어", "거리 유지", "측면 우회", "보급 호위", "재집결", "휴식", "탄약 보충", "보급 복귀", "거점 점령", "거점 방어", "측면 방어", "전열 지원", "패주", "매복", "정보 확인", "명령 수행", "계획 경유", "방어선 사수", "긴급 방어", "전술 철수", "긴급 지원", "전술 재집결","협동 우회","협동 엄호","구원 지원","협동 대기","지정 위치 이동","지정 지역 사수","예비 대기","궁병 보호"]:
        var distance: float = pos.distance_to(enemy["pos"])
        var range_goal: float = 143.0 if str(unit["type"]) == "궁병" else 32.0
        if distance <= range_goal:
            goal = pos
            unit["goal"] = pos
    var rate: float = 54.0
    match str(unit["type"]):
        "기병": rate = 100.0
        "궁병": rate = 48.0
    match str(unit["formation"]):
        "종대": rate *= 1.10
        "방진": rate *= 0.65
        "어린진": rate *= 0.90
        "학익진": rate *= 0.78
        "봉시진": rate *= 1.12
        "안행진": rate *= 0.91
    if str(unit["next_formation"]) != "":
        rate *= 0.55
    if wide_field and (enemy.is_empty() or pos.distance_to(enemy["pos"]) > 220.0):
        rate *= 1.35
    rate *= _terrain_movement_multiplier(unit, pos)
    rate *= 1.0 - 0.28 * float(unit["fatigue"]) / 100.0
    rate *= 0.65 + 0.35 * float(unit["cohesion"]) / 100.0
    if bool(unit["routed"]):
        rate *= 1.18
        if bool(unit["surrounded"]):
            rate *= 0.55
    if str(unit["type"]) == "기병":
        unit["charge_cooldown"] = maxf(0.0, float(unit["charge_cooldown"]) - dt)
    var actual_move: Vector2 = Vector2.ZERO
    if pos.distance_to(goal) > 2.0:
        if long_operation:
            goal = _committed_bridge_route(unit,pos,goal)
        elif wide_field and (enemy.is_empty() or pos.distance_to(enemy["pos"]) > 180.0):
            goal = _crossing_route(pos,goal)
        if not structures.is_empty() and (str(unit["type"]) == "기병" or bool(unit["routed"])):
            goal = _detour_goal(unit,pos,goal)
        var new_pos: Vector2 = pos.move_toward(goal, rate * dt)
        var legal:Vector2=_structure_move(unit,pos,_field_point(new_pos))
        if long_operation: legal=_land_motion(unit,pos,legal)
        unit["pos"]=legal
        var moved: Vector2 = (unit["pos"] as Vector2) - pos
        actual_move = moved
        if moved.length_squared() > 0.03:
            unit["fatigue"] = minf(100.0, float(unit["fatigue"]) + moved.length() * (0.030 if str(unit["type"]) == "기병" else 0.042) * (0.48 if wide_field else 1.0))
            unit["facing"] = moved.normalized()
    unit["motion_speed"] = actual_move.length()/maxf(dt,0.001)
    if six_armies:
        if str(unit["action"])=="협동 우회": unit["maneuver_distance"]+=actual_move.length()
        if str(unit["action"]) in ["협동 엄호","구원 지원","궁병 보호"]:
            var ally: Dictionary=find_unit(int(unit["link_id"]))
            if not ally.is_empty() and float(ally["troops"])>0.0 and (unit["pos"] as Vector2).distance_to(ally["pos"])<=150.0:
                unit["support_seconds"]+=dt
    if six_armies: _emit_march_dust(unit,pos,actual_move)
    if str(unit["type"]) == "기병":
        _update_charge(unit, actual_move, dt)
    if not enemy.is_empty() and pos.distance_to(enemy["pos"]) < 168.0 and str(unit["action"]) not in ["후퇴", "패주", "재집결", "측면 우회", "기지 습격", "보급 복귀", "탄약 보충", "매복","협동 우회","협동 엄호"]:
        var front: Vector2 = (enemy["pos"] as Vector2) - (unit["pos"] as Vector2)
        if front.length_squared() > 1.0:
            unit["facing"] = (unit["facing"] as Vector2).lerp(front.normalized(), minf(1.0, dt * 2.0)).normalized()


# M2-1: Keep formation bodies separate. This applies to friends and enemies.
# M2-2: A contact line shifts toward the weaker side, based on the soldiers
# actually in each formation, morale and how well a unit resists front pressure.
func _body_distance(a: Dictionary, b: Dictionary) -> float:
    if six_armies:
        var direction: Vector2 = ((b["pos"] as Vector2)-(a["pos"] as Vector2)).normalized()
        if direction.length_squared()<0.01: direction=Vector2.RIGHT
        return _formation_extent(a,direction)+_formation_extent(b,-direction)+5.0
    if str(a["type"]) == "궁병" or str(b["type"]) == "궁병":
        return 25.0
    return 34.0

func _frontline_power(unit: Dictionary, enemy: Dictionary, direction: Vector2) -> float:
    var factor: float = 1.0
    if six_armies: factor *= tactical_matchup(unit,enemy,false)
    var formation_factor: float = 1.0
    match str(unit["formation"]):
        "횡대": formation_factor = 1.06
        "종대": formation_factor = 0.77
        "방진": formation_factor = 1.28
        "어린진": formation_factor = 1.19
        "학익진": formation_factor = 1.10
        "봉시진": formation_factor = 1.18
        "안행진": formation_factor = 0.85
    factor *= formation_factor
    if str(unit["type"]) == "기병":
        factor *= 1.16 if str(enemy["formation"]) != "방진" else 0.70
        if _in_forest(unit["pos"]):
            factor *= 0.70
    if str(unit["action"]) == "돌파":
        factor *= 1.12
    var facing: Vector2 = unit["facing"]
    if facing.length_squared() > 0.5 and facing.normalized().dot(direction) > 0.45:
        factor *= 1.06
    return maxf(1.0, float(unit["troops"]) * (0.25 + 0.75 * float(unit["morale"]) / 100.0) * factor * (0.55 + 0.45 * float(unit["cohesion"]) / 100.0) * (1.0 - 0.25 * float(unit["fatigue"]) / 100.0))

func _resolve_frontline(dt: float) -> void:
    for unit in units:
        unit["front_pressure"] = 0.0
    for i in range(units.size()):
        var a: Dictionary = units[i]
        if float(a["troops"]) <= 0.0:
            continue
        for j in range(i + 1, units.size()):
            var b: Dictionary = units[j]
            if float(b["troops"]) <= 0.0:
                continue
            var ap: Vector2 = a["pos"]
            var bp: Vector2 = b["pos"]
            var delta: Vector2 = bp - ap
            var distance: float = delta.length()
            var threshold: float = _body_distance(a, b)
            if distance >= threshold + 7.0:
                continue
            var direction: Vector2 = delta / distance if distance > 0.0001 else (Vector2.RIGHT if int(a["side"]) == 0 else Vector2.LEFT)
            if distance < threshold:
                # Geometric separation prevents passing through the other unit.
                var overlap: float = threshold - distance
                var next_a:Vector2=_field_point(ap-direction*overlap*0.5)
                var next_b:Vector2=_field_point(bp+direction*overlap*0.5)
                a["pos"]=_land_motion(a,ap,next_a) if long_operation else next_a
                b["pos"]=_land_motion(b,bp,next_b) if long_operation else next_b
            if int(a["side"]) == int(b["side"]):
                continue
            # Ranged detachments can be pursued but do not push a melee line.
            if str(a["type"]) == "궁병" or str(b["type"]) == "궁병":
                continue
            var strength_a: float = _frontline_power(a, b, direction)
            var strength_b: float = _frontline_power(b, a, -direction)
            var advantage: float = (strength_a - strength_b) / maxf(1.0, strength_a + strength_b)
            if absf(advantage) <= 0.035:
                continue
            var shift: float = clampf(advantage * 24.0 * dt, -1.6, 1.6)
            var current_a:Vector2=a["pos"]
            var current_b:Vector2=b["pos"]
            var pushed_a:Vector2=_field_point(current_a+direction*shift)
            var pushed_b:Vector2=_field_point(current_b+direction*shift)
            a["pos"]=_land_motion(a,current_a,pushed_a) if long_operation else pushed_a
            b["pos"]=_land_motion(b,current_b,pushed_b) if long_operation else pushed_b
            var losing_unit: Dictionary = b if shift > 0.0 else a
            losing_unit["front_pressure"] = maxf(float(losing_unit["front_pressure"]), absf(advantage))
            losing_unit["pushed_distance"] = float(losing_unit["pushed_distance"]) + absf(shift)
            # Gradual cohesion loss rather than an instant attrition dice roll.
            losing_unit["morale"] = maxf(0.0, float(losing_unit["morale"]) - absf(shift) * 0.035)
            if float(losing_unit["pushed_distance"]) > 18.0 and str(losing_unit["action"]) != "후퇴":
                # Counter resets keep one event from spamming the battle log.
                losing_unit["pushed_distance"] = 0.0
                _log("%s 전선이 압박으로 밀립니다." % str(losing_unit["name"]))

func _field_point(p: Vector2) -> Vector2:
    return Vector2(clampf(p.x, 18.0, field_size.x - 18.0), clampf(p.y, 22.0, field_size.y - 18.0))


# Terrain layout is the same geometry used by game.gd's tactical map.
func terrain_at(p: Vector2) -> String:
    if wide_field and absf(p.x-river_x(p.y)) < 27.0:
        return "교량" if near_crossing(p.y) else "하천"
    if _in_forest(p):
        return "숲"
    if hill.has_point(p):
        return "고지"
    for lane in range(3):
        if absf(p.y-road_y(p.x,lane)) <= (16.0 if wide_field else 10.0):
            return "도로"
    return "평지"

func _terrain_movement_multiplier(unit: Dictionary, p: Vector2) -> float:
    match terrain_at(p):
        "교량": return 1.08
        "하천": return 0.34 if str(unit["type"]) == "기병" else 0.48
        "도로":
            return 1.23
        "숲":
            match str(unit["type"]):
                "기병": return 0.53
                "궁병": return 0.77
                _: return 0.83
        "고지":
            return 0.82
    return 1.0

func _in_forest(p: Vector2) -> bool:
    for region in forests:
        if region.has_point(p):
            return true
    return false


# A unit is not a single point for contact resolution. These are its actual
# tactical slots, shared with the renderer. More exposed ranks can join
# the engagement; a marching column cannot magically attack with six files.
func formation_slots(unit: Dictionary) -> Array[Vector2]:
    var slots: Array[Vector2] = []
    var front: Vector2 = unit["facing"]
    if front.length_squared() < 0.1:
        front = Vector2.RIGHT if int(unit["side"]) == 0 else Vector2.LEFT
    front = front.normalized()
    var lateral: Vector2 = Vector2(-front.y, front.x)
    var files: int = 6
    var ranks: int = 2
    match str(unit["formation"]):
        "종대":
            files = 3
            ranks = 4
        "방진":
            files = 4
            ranks = 3
    var count: int = clampi(int(round(float(unit["troops"]) / maxf(1.0, float(unit["initial_troops"])) * 12.0)), 0, 12)
    if six_armies:
        var size: int = clampi(ceili(float(unit["troops"])/180.0),1,24)
        var points: Array[Vector2] = army_slots(unit,size,12.0)
        if str(unit["next_formation"]) != "" and not points.is_empty():
            var next: Array[Vector2] = army_slots(unit,size,12.0,str(unit["next_formation"]))
            var t: float = smoothstep(0.0,1.0,1.0-float(unit["form_remaining"])/maxf(0.1,float(unit.get("form_duration",3.0))))
            for i in range(points.size()):
                points[i]=points[i].lerp(next[i],t)
                if long_operation: points[i]=_dry_formation_slot(unit["pos"],points[i])
        return points
    var center: Vector2 = unit["pos"]
    for k in range(count):
        var file: int = k % files
        var rank: int = int(floor(float(k) / float(files)))
        var offset: Vector2 = lateral * ((float(file) - float(files - 1) * 0.5) * 10.0) - front * ((float(rank) - float(ranks - 1) * 0.5) * 10.5)
        slots.append(center + offset)
    return slots

# Number of soldiers able to reach the opposing formation from their REAL slots.
# Broad-phase culling keeps repeated headless regression fast.
func formation_contacts(attacker: Dictionary, defender: Dictionary, weapon_reach: float) -> int:
    if (attacker["pos"] as Vector2).distance_to(defender["pos"]) > weapon_reach + (190.0 if six_armies else 75.0):
        return 0
    var attacking_slots: Array[Vector2] = formation_slots(attacker)
    var defending_slots: Array[Vector2] = formation_slots(defender)
    var engaged: int = 0
    var threshold_squared: float = weapon_reach * weapon_reach
    for soldier in attacking_slots:
        for opposing_soldier in defending_slots:
            if soldier.distance_squared_to(opposing_soldier) <= threshold_squared:
                engaged += 1
                break
    return engaged

# Representative contact point, evaluated only when a visual event is emitted.
# Authoritative contacts and damage remain unchanged.
# Display-only front rank anchors use the same formation positions as contact calculations.
func representative_slots(unit: Dictionary,count: int) -> Array[Vector2]:
    var anchors: Array[Vector2]=formation_slots(unit)
    var result: Array[Vector2]=[]
    if anchors.is_empty() or count<=0: return result
    var front: Vector2=(unit["facing"] as Vector2).normalized()
    if front.length_squared()<0.1: front=Vector2.RIGHT if int(unit["side"])==0 else Vector2.LEFT
    var lateral: Vector2=front.orthogonal()
    for i in range(count):
        var anchor: Vector2=anchors[i%anchors.size()]
        var layer: int=floori(float(i)/float(anchors.size()))
        var spread: float=4.4 if str(unit["type"])=="기병" else 3.8
        var offset: Vector2=Vector2.ZERO
        if layer==1: offset=-front*spread+lateral*spread
        elif layer==2: offset=front*spread-lateral*spread
        elif layer>=3: offset=Vector2.from_angle(float(i)*2.39996)*spread
        var point: Vector2=_field_point(anchor+offset)
        if long_operation: point=_dry_formation_slot(unit["pos"],point)
        result.append(point)
    return result

func visual_contact_pair(attacker: Dictionary,defender: Dictionary) -> Array[Vector2]:
    var left: Array[Vector2]=formation_slots(attacker)
    var right: Array[Vector2]=formation_slots(defender)
    var pair: Array[Vector2]=[attacker["pos"],defender["pos"]]
    var best: float=INF
    for p in left:
        for q in right:
            var distance: float=p.distance_squared_to(q)
            if distance<best:
                best=distance
                pair[0]=p
                pair[1]=q
    return pair

func _combat(dt: float) -> void:
    # Precompute strikes before taking losses. Both sides resolve simultaneously.
    var damage_entries: Array[Dictionary] = []
    var targets: Dictionary = {}
    for unit in units:
        unit["contact_troops"] = 0
        unit["contact_target_id"]=-1
        if six_armies and float(unit["troops"])>0.0 and not bool(unit["routed"]):
            targets[int(unit["id"])]=_combat_target(unit)
    for unit in units:
        if float(unit["troops"]) <= 0.0:
            continue
        if bool(unit["routed"]):
            continue
        var enemy: Dictionary = targets.get(int(unit["id"]),{}) if six_armies else _combat_target(unit)
        if enemy.is_empty():
            continue
        var pos: Vector2 = unit["pos"]
        var ep: Vector2 = enemy["pos"]
        var distance: float = pos.distance_to(ep)
        var unit_type: String = str(unit["type"])
        var reach: float = 173.0 if unit_type == "궁병" else 30.0
        if long_operation and unit_type!="궁병" and _river_separates(pos,ep): continue
        var contacts: int = formation_contacts(unit, enemy, reach)
        if contacts == 0:
            continue
        unit["contact_troops"] = contacts
        var attack: float = 0.0
        match unit_type:
            "보병": attack = 2.4
            "궁병": attack = 1.8
            "기병": attack = 2.6

        if unit_type == "궁병":
            if float(unit["ammo"]) <= 0.0:
                continue
            var ammo_used: float = minf(float(unit["ammo"]), dt * (0.60 if long_operation else 0.85))
            unit["ammo"] = maxf(0.0, float(unit["ammo"]) - ammo_used)
            unit["shots_used"] = float(unit["shots_used"]) + ammo_used
            # Close fighting degrades bow effectiveness; cover blocks some shots.
            attack *= 0.55 if distance < 56.0 else 1.0
            if _in_forest(ep):
                attack *= 0.72
            if terrain_at(pos) == "고지" and terrain_at(ep) != "고지":
                attack *= 1.23
        else:
            # Physical contact frontage, not a free formation-specific stat buff.
            attack *= clampf(float(contacts) / (14.0 if six_armies else 8.0), 0.35, 1.50)
            if terrain_at(pos) == "고지" and terrain_at(ep) != "고지":
                attack *= 1.11

        unit["contact_target_id"]=int(enemy["id"])
        var direction: Vector2 = (pos - ep).normalized()
        var facing: Vector2 = enemy["facing"]
        if facing.length_squared() < 0.1:
            facing = Vector2.LEFT if int(enemy["side"]) == 1 else Vector2.RIGHT
        facing = facing.normalized()
        var lateral: Vector2 = Vector2(-facing.y, facing.x)
        var rear: bool = direction.dot(facing) < -0.30
        var flank: bool = absf(direction.dot(lateral)) > 0.70
        var exposure: float = 1.28 if rear else (1.14 if flank else 1.0)
        if str(enemy["formation"]) == "방진":
            exposure *= 0.80
            if enemy.get("specialty","") == "방진":
                exposure *= 0.92
        elif str(enemy["formation"]) == "종대" and (flank or rear):
            exposure *= 1.30
        if str(enemy["next_formation"]) != "":
            # An incomplete formation exposes gaps until the real transition ends.
            exposure *= 1.24
        if str(unit["next_formation"]) != "":
            attack *= 0.78
        var shock: float = 0.0
        if unit_type == "기병" and distance < 70.0 and float(unit["charge_cooldown"]) <= 0.0:
            shock = _charge_impact(unit, enemy)
            if shock > 0.0:
                unit["charges"] = int(unit["charges"]) + 1
                unit["charge_cooldown"] = 4.5
                unit["charge"] = 0.0
                unit["charge_speed"] = 0.0
                _log("%s: 기병 충격 돌격" % str(unit["name"]))
        var ambush: bool = false
        if float(unit["ambush_ready"]) >= 3.0 and distance <= 110.0 and _in_forest(pos):
            unit["ambush_ready"] = 0.0
            unit["ambush_until"] = battle_time + 3.0
            unit["ambushes"] = int(unit["ambushes"]) + 1
            _log("%s: 매복 기습 개시" % str(unit["name"]))
            ambush = true
        if battle_time < float(unit["ambush_until"]):
            attack *= 1.35
        if bool(enemy["surrounded"]):
            exposure *= 1.12
        if bool(enemy["routed"]):
            exposure *= 1.28
        attack *= 0.90 + _effective_stat(unit, "martial") * 0.002
        if unit.get("specialty","") == "돌격" and unit_type == "기병":
            attack *= 1.08

        var supply_factor: float = 0.76 if float(unit["out_supply"]) >= TURN_SECONDS * 3.0 else 1.0
        supply_factor *= 0.65 + 0.35 * float(unit["rations"]) / 100.0
        attack *= (1.0 - 0.30 * float(unit["fatigue"]) / 100.0) * (0.55 + 0.45 * float(unit["cohesion"]) / 100.0)
        unit["fatigue"] = minf(100.0, float(unit["fatigue"]) + dt * 0.60)
        var counter: float = tactical_matchup(unit,enemy,flank or rear) if six_armies else 1.0
        var link: bool = six_armies and _has_combined_arms(unit,enemy,targets)
        attack *= counter*(1.15 if link else 1.0)
        var guard: Dictionary = _physical_screen(enemy,unit) if six_armies else {}
        var damage: float = attack * (float(unit["troops"]) / maxf(1.0, float(unit["initial_troops"]))) * (float(unit["morale"]) / 100.0) * exposure * supply_factor * dt
        if wide_field:
            damage *= float(unit.get("strength_share",1.0))
            if terrain_at(pos) == "하천": damage *= 0.68
            if terrain_at(ep) == "하천": damage *= 1.18
        if six_armies:
            damage *= clampf(float(unit["initial_troops"])/3800.0,0.20,1.5)*ARMY_SCALE
            match str(unit["formation"]):
                "어린진": damage *= 1.14 if unit_type != "궁병" else 0.95
                "학익진": damage *= 1.20 if flank or rear else 0.93
                "봉시진": damage *= 1.20 if unit_type == "기병" else 1.03
                "안행진": damage *= 1.22 if unit_type == "궁병" else 0.85
                "방진": damage *= 0.84
            shock *= ARMY_SCALE
        if long_operation:
            damage *= 0.75
            shock *= 0.85
        if wide_field: shock *= float(unit.get("strength_share",1.0))
        if not guard.is_empty():
            var saved: float=damage*0.25+shock*0.60
            damage*=0.75
            shock*=0.40
            guard["screened_damage"]+=saved
            guard["screen_events"]+=1
        var guarding:bool=long_operation and unit_type!="궁병" and _guarding_archer_in_contact(enemy,unit)
        damage_entries.append({"guarding":guarding, "target":int(enemy["id"]), "source":int(unit["id"]), "damage":maxf(0.0, damage + shock), "flank":flank or rear, "shock":shock, "ambush":ambush, "counter":counter, "linked":link})
        if shock > 0.0 or battle_time - float(unit["last_visual"]) >= (0.9 if unit_type == "궁병" else 0.55):
            unit["last_visual"] = battle_time
            var contact_pair: Array[Vector2]=visual_contact_pair(unit,enemy)
            visual_effects.append({"from":pos,"to":ep,"visual_from":contact_pair[0],"visual_to":contact_pair[1],"side":int(unit["side"]),"kind":"돌격" if shock > 0.0 else ("화살" if unit_type == "궁병" else "근접"),"time":battle_time})
            if visual_effects.size() > 100:
                visual_effects.pop_front()
    for entry in damage_entries:
        var defender: Dictionary = find_unit(int(entry["target"]))
        if defender.is_empty() or float(defender["troops"]) <= 0.0:
            continue
        var actual_damage: float = minf(float(defender["troops"]), float(entry["damage"]))
        defender["troops"] = maxf(0.0, float(defender["troops"]) - actual_damage)
        defender["casualties_taken"] = float(defender["casualties_taken"]) + actual_damage
        if bool(entry.get("guarding",false)) and actual_damage>0.0:
            defender["guard_intercept_damage"]+=actual_damage
            defender["guard_intercept_ticks"]+=1
        if actual_damage > 0.0:
            defender["last_hit"] = battle_time
        var shock_damage: float = float(entry["shock"])/(ARMY_SCALE if six_armies else 1.0)
        var pressure_damage: float = actual_damage/(ARMY_SCALE if six_armies else 1.0)
        if shock_damage > 0.0 or bool(entry["ambush"]):
            defender["morale"] = maxf(0.0, float(defender["morale"]) - shock_damage * 1.1 - (6.0 if bool(entry["ambush"]) else 0.0))
            defender["cohesion"] = maxf(0.0, float(defender["cohesion"]) - shock_damage * 1.6)
        _general_exposure(defender, pressure_damage, bool(entry["flank"]), shock_damage)
        defender["cohesion"] = maxf(0.0, float(defender["cohesion"]) - pressure_damage * (0.85 if bool(entry["flank"]) else 0.38))
        if bool(entry["flank"]):
            defender["flank_hits"] = float(defender["flank_hits"]) + actual_damage
        var source: Dictionary = find_unit(int(entry["source"]))
        if not source.is_empty():
            source["damage_dealt"] = float(source["damage_dealt"]) + actual_damage
            if six_armies:
                if bool(entry["linked"]): source["linked_hits"] += actual_damage
                if float(entry["counter"])>1.01: source["counter_damage"] += actual_damage
                if bool(entry["flank"]): source["flank_damage"] += actual_damage
        var morale_loss: float = 0.11 if bool(entry["flank"]) else 0.07
        defender["morale"] = maxf(0.0, float(defender["morale"]) - pressure_damage * morale_loss)
        if float(defender["troops"]) <= 0.0:
            _log("%s 전멸" % str(defender["name"]))
            for ally in units:
                if int(ally["side"]) == int(defender["side"]) and float(ally["troops"]) > 0.0 and (ally["pos"] as Vector2).distance_to(defender["pos"]) < 180.0:
                    ally["morale"] = maxf(0.0, float(ally["morale"]) - 12.0)


# Neutral strategic positions are optional field objectives. An uncontested unit
# must actually stand within range long enough to establish control; a contested
# point neither changes hands nor accumulates victory hold time.
func _update_outposts(dt: float) -> void:
    for site in outposts:
        var blue: bool = false
        var red: bool = false
        for unit in units:
            if float(unit["troops"]) <= 0.0 or bool(unit["routed"]):
                continue
            if (unit["pos"] as Vector2).distance_to(site["pos"]) <= OUTPOST_RADIUS:
                if int(unit["side"]) == 0:
                    blue = true
                else:
                    red = true
        if blue == red:
            site["hold"] = 0.0
            site["challenger"] = -1
            site["progress"] = 0.0
            continue
        var faction: int = 0 if blue else 1
        for unit in units:
            if int(unit["side"]) == faction and float(unit["troops"]) > 0.0 and not bool(unit["routed"]) and (unit["pos"] as Vector2).distance_to(site["pos"]) <= OUTPOST_RADIUS:
                unit["objective_time"] = float(unit["objective_time"]) + dt
        if int(site["owner"]) == faction:
            site["hold"] = float(site["hold"]) + dt
            site["progress"] = 0.0
            continue
        site["hold"] = 0.0
        if int(site["challenger"]) != faction:
            site["challenger"] = faction
            site["progress"] = 0.0
        site["progress"] = float(site["progress"]) + dt
        if float(site["progress"]) >= capture_duration():
            site["owner"] = faction
            site["hold"] = 0.0
            site["challenger"] = -1
            site["progress"] = 0.0
            _log("%s: %s 점령" % [str(site["name"]), "아군" if faction == 0 else "적군"])

func _objective_winner() -> int:
    if long_operation and battle_time < LONG_OBJECTIVE_OPEN: return -1
    if outposts.size() < 2 or turn < (6 if wide_field else 3):
        return -1
    if scenario_id == 1:
        if six_armies and battle_time < 125.0: return -1
        var central: Dictionary = outposts[0]
        if int(central["owner"]) >= 0 and float(central["hold"]) >= (45.0 if long_operation else (30.0 if wide_field else 18.0)):
            return int(central["owner"])
        return -1
    if scenario_id in [2,3]:
        return -1
    if scenario_id == 4:
        if not structures.is_empty() and float(structures[0]["hp"]) <= 0.0 and int(outposts[0]["owner"]) == 0 and float(outposts[0]["hold"]) >= (30.0 if long_operation else 12.0):
            return 0
        return -1
    if six_armies and scenario_id == 0:
        var secured: Array[int] = [0,0]
        for site in outposts:
            var faction: int = int(site["owner"])
            if faction >= 0 and float(site["hold"]) >= (45.0 if long_operation else OUTPOST_HOLD_SECONDS): secured[faction] += 1
        for faction in range(2):
            if secured[faction] >= 2: return faction
        return -1
    var owner: int = int(outposts[0]["owner"])
    if owner < 0:
        return -1
    for site in outposts:
        if int(site["owner"]) != owner or float(site["hold"]) < OUTPOST_HOLD_SECONDS:
            return -1
    return owner

# Game-play-facing audit: three independent generals' actual decisions, reforms
# and losses, with no fabricated kill counts or hidden information.
func battle_report() -> Array[String]:
    var rows: Array[String] = []
    rows.append("전투 결산 · %s" % (result if finished else "진행 중"))
    for unit in units:
        if int(unit["side"]) != 0 or not int(unit["id"]) in command_ids(0):
            continue
        var report: Dictionary = corps_report(int(unit["id"]))
        rows.append("%s[%s] | 판단 %d · 피해 %d · 손실 %d · 이탈 %d · 공적 %d" %
            [str(unit["name"]),str(unit["general_state"]),int(report["decisions"]),roundi(report["damage_dealt"]),roundi(report["casualties_taken"]),roundi(report["deserted"]),int(report["merit"])])
    return rows

func _check_victory() -> void:
    if finished:
        return
    if scenario_id == 3 and not convoy.is_empty():
        if float(convoy["hp"]) <= 0.0:
            _finish("군량 수레 파괴 — 패배")
            return
        if (convoy["pos"] as Vector2).distance_to(convoy["goal"]) < 12.0:
            _finish("군량 수레 호위 성공 — 아군 승리")
            return
    var winner: int = _objective_winner()
    if winner == 0 and scenario_id == 4:
        _finish("천수 돌파 성공 — 아군 승리")
        return
    if winner >= 0:
        _finish(("양측 요충지 확보 — 아군 승리" if winner == 0 else "적 요충지 장악 — 패배") if scenario_id == 0 else ("중앙 고지 확보 — 아군 승리" if winner == 0 else "적 중앙 고지 장악 — 패배"))
        return

    for unit in units:
        if float(unit["troops"]) <= 0.0 or bool(unit["routed"]):
            continue
        var side: int = int(unit["side"])
        var unit_pos: Vector2 = unit["pos"]
        var enemy_commander: Dictionary = commanders[1 - side]
        if unit_pos.distance_to(enemy_commander["pos"]) < 26.0:
            if commander_guard_count(1-side) == 0:
                _finish("책사 포획 성공 — 아군 승리" if side == 0 else "아군 책사 포획 — 패배")
                return
    var side_alive: Array[int] = [0, 0]
    for unit in units:
        if float(unit["troops"]) > 0.0 and not bool(unit["routed"]):
            side_alive[int(unit["side"])] += 1
    if side_alive[0] == 0:
        if reinforcements_used[0] >= reserve_limit[0]:
            _finish("아군 전투부대 전멸 또는 패주 — 패배")
    elif side_alive[1] == 0:
        if reinforcements_used[1] >= reserve_limit[1]:
            _finish("적 전투부대 전멸 또는 패주 — 승리")
    if not finished and scenario_id == 2 and not bool(bases[0]["alive"]):
        _finish("아군 보급기지 상실 — 패배")
    if not finished and scenario_id == 2 and battle_time >= scenario_limit:
        _finish("보급기지 방어 성공 — 아군 승리")
    if not finished and battle_time >= scenario_limit and scenario_id in [3,4]:
        _finish("작전 제한 시간 초과 — 패배")
    if not finished and battle_time >= scenario_limit and six_armies and scenario_id == 0:
        var control: Array[int] = [0,0]
        for site in outposts:
            var faction: int = int(site["owner"])
            if faction >= 0: control[faction] += 1
        if control[0] != control[1]:
            _finish("작전 종료 — 거점 우세: %s" % ("아군" if control[0]>control[1] else "적군"))
            return
    if not finished and battle_time >= scenario_limit:
        var blue: float = 0.0
        var red: float = 0.0
        for unit in units:
            if bool(unit["routed"]):
                continue
            if int(unit["side"]) == 0:
                blue += float(unit["troops"])
            else:
                red += float(unit["troops"])
        _finish("시간 종료 — 전력 우세: %s" % ("아군" if blue >= red else "적군"))

func _finish(msg: String) -> void:
    if finished:
        return
    result = msg
    winning_side = 1 if "패배" in msg or msg.ends_with("적군") else 0
    finished = true
    _update_response_outcomes()
    _log("전투 종료: %s" % msg)

func validate_state() -> Array[String]:
    var problems: Array[String] = []
    if is_nan(battle_time) or is_inf(battle_time) or battle_time < 0.0:
        problems.append("invalid elapsed time")
    if units.size() > 16:
        problems.append("unit pool exceeds bounded demo limit")
    if intercepted_orders < 0 or delivered_orders < 0:
        problems.append("invalid courier counters")
    for site in outposts:
        var owner: int = int(site["owner"])
        if owner < -1 or owner > 1 or float(site["hold"]) < 0.0 or float(site["progress"]) < 0.0:
            problems.append("invalid outpost control: %s" % str(site["name"]))
    for unit in units:
        var p: Vector2 = unit["pos"]
        if is_nan(p.x) or is_nan(p.y) or is_inf(p.x) or is_inf(p.y):
            problems.append("unit position is not finite: %s" % str(unit["name"]))
        elif p.x < 0.0 or p.x > field_size.x or p.y < 0.0 or p.y > field_size.y:
            problems.append("unit out of bounds: %s" % str(unit["name"]))
        var troops: float = float(unit["troops"])
        if is_nan(troops) or is_inf(troops) or troops < 0.0 or troops > MAX_TROOPS:
            problems.append("invalid troops: %s" % str(unit["name"]))
        var morale: float = float(unit["morale"])
        if is_nan(morale) or is_inf(morale) or morale < 0.0 or morale > 100.0:
            problems.append("invalid morale: %s" % str(unit["name"]))
        if float(unit["form_remaining"]) < 0.0:
            problems.append("negative formation time: %s" % str(unit["name"]))
        if is_nan(float(unit["front_pressure"])) or is_inf(float(unit["front_pressure"])):
            problems.append("invalid frontline pressure: %s" % str(unit["name"]))
        if bool(unit["raid_active"]):
            var target: Vector2 = unit["raid_target"]
            if is_nan(target.x) or is_nan(target.y) or is_inf(target.x) or is_inf(target.y):
                problems.append("invalid raid target: %s" % str(unit["name"]))
            if is_nan(float(unit["raid_until"])) or is_inf(float(unit["raid_until"])):
                problems.append("invalid raid expiration: %s" % str(unit["name"]))
    for base in bases:
        var p: Vector2 = base["pos"]
        if is_nan(p.x) or is_nan(p.y) or is_inf(p.x) or is_inf(p.y):
            problems.append("supply base position is not finite")
        if float(base["build_timer"]) < -0.2:
            problems.append("invalid supply construction timer")
    return problems

func total_troops(side: int) -> int:
    var strength: float = 0.0
    for unit in units:
        if int(unit["side"]) == side:
            strength += float(unit["troops"])
    return int(round(strength))

# M4: tactical decisions use assigned mission and observed conditions.
func _assigned_outpost(unit: Dictionary) -> Dictionary:
    var mission: String = str(unit["mission"])
    if outposts.size() < 2:
        return {}
    if six_armies and scenario_id == 0 and mission == "중앙 진격" and outposts.size() >= 3:
        return outposts[2]
    if scenario_id in [1,4] and mission == "중앙 진격":
        return outposts[0]
    if mission == "북측 확보":
        return outposts[0]
    if mission == "남측 우회":
        return outposts[1]
    return {}

func _rally_point(unit: Dictionary) -> Vector2:
    var p: Vector2 = unit["pos"]
    var side: int = int(unit["side"])
    var rear: Vector2 = Vector2.LEFT if side == 0 else Vector2.RIGHT
    var base: Dictionary = bases[side]
    if bool(base["alive"]):
        return _field_point(p.move_toward(base["pos"], 100.0))
    return _field_point(p + rear * 100.0)

func _flank_threat(unit: Dictionary, enemy: Dictionary) -> bool:
    var offset: Vector2 = (enemy["pos"] as Vector2) - (unit["pos"] as Vector2)
    return offset.length_squared() > 1.0 and offset.normalized().dot(unit["facing"]) < 0.10

func _support_target(unit: Dictionary) -> Dictionary:
    var best: Dictionary = {}
    var p: Vector2 = unit["pos"]
    var score: float = 0.18
    for ally in units:
        if int(ally["side"]) != int(unit["side"]) or int(ally["id"]) == int(unit["id"]) or float(ally["troops"]) <= 0.0:
            continue
        if p.distance_to(ally["pos"]) > 210.0:
            continue
        var pressure: float = float(ally["front_pressure"])
        if pressure > score:
            best = ally
            score = pressure
    return best

func _update_battle_condition(dt: float) -> void:
    for unit in units:
        if float(unit["troops"]) <= 0.0:
            continue
        var p: Vector2 = unit["pos"]
        var enemy: Dictionary = _nearest_visible_enemy(unit)
        var safe: bool = enemy.is_empty() or p.distance_to(enemy["pos"]) > 110.0
        var recovery: bool = str(unit["action"]) in ["재집결", "휴식", "방어", "거점 방어", "거리 유지", "긴급 방어", "전술 재집결","지정 지역 사수","예비 대기","협동 대기"]
        if safe and recovery:
            unit["fatigue"] = maxf(0.0, float(unit["fatigue"]) - dt * 2.1)
            unit["cohesion"] = minf(100.0, float(unit["cohesion"]) + dt * (2.6 if bool(unit["supplied"]) else 1.1) * (0.55 + _effective_stat(unit, "leadership") * 0.006))
        elif safe:
            unit["cohesion"] = minf(100.0, float(unit["cohesion"]) + dt * 0.25)
        unit["cohesion"] = maxf(0.0, float(unit["cohesion"]) - dt * float(unit["front_pressure"]) * 0.65)
        var commander: Dictionary = commanders[int(unit["side"])]
        if safe and p.distance_to(commander["pos"]) < 125.0 and float(unit["rations"]) > 20.0:
            unit["morale"] = minf(100.0, float(unit["morale"]) + dt * 0.75)
        if float(unit["rations"]) < 20.0:
            unit["morale"] = maxf(0.0, float(unit["morale"]) - dt * 0.35)

func _combat_target(unit: Dictionary) -> Dictionary:
    var nearest: Dictionary = _nearest_visible_enemy(unit)
    if six_armies and not nearest.is_empty():
        if long_operation and int(unit["flank_phase"])==2 and str(unit["action"])=="돌파":
            var assigned:Dictionary=find_unit(int(unit["flank_target"]))
            if not assigned.is_empty() and _locally_observed(unit,assigned) and formation_contacts(unit,assigned,30.0)>0:
                return assigned
        return _tactical_target(unit,nearest)
    if nearest.is_empty() or str(unit["type"]) != "궁병" or _effective_stat(unit, "intelligence") < 70.0:
        return nearest
    var p: Vector2 = unit["pos"]
    var best: Dictionary = nearest
    var best_score: float = -1000.0
    for enemy in units:
        if int(enemy["side"]) == int(unit["side"]) or float(enemy["troops"]) <= 0.0:
            continue
        var d: float = p.distance_to(enemy["pos"])
        if d > 173.0 or (_in_forest(enemy["pos"]) and d > AI_VISION_RANGE * 0.68):
            continue
        var score: float = 100.0 - d * 0.45
        if str(enemy["formation"]) == "종대":
            score += 14.0
        if str(enemy["next_formation"]) != "":
            score += 24.0
        if _in_forest(enemy["pos"]):
            score -= 24.0
        if score > best_score:
            best_score = score
            best = enemy
    return best

func _courier_route(letter: Dictionary, target: Vector2) -> Vector2:
    var p: Vector2 = letter["pos"]
    if p.distance_to(target) < 65.0:
        return target
    var direction: Vector2 = (target - p).normalized()
    var lateral: Vector2 = Vector2(-direction.y, direction.x)
    var straight: Vector2 = p.move_toward(target, 90.0)
    var candidates: Array[Vector2] = [straight, _field_point(straight + lateral * 70.0), _field_point(straight - lateral * 70.0)]
    var best: Vector2 = straight
    var best_score: float = -100000.0
    for candidate in candidates:
        var score: float = -candidate.distance_to(target) * 0.35
        for unit in units:
            if float(unit["troops"]) <= 0.0:
                continue
            var d: float = (unit["pos"] as Vector2).distance_to(candidate)
            if int(unit["side"]) != int(letter["side"]) and (unit["pos"] as Vector2).distance_to(p) < 135.0:
                score -= maxf(0.0, 85.0 - d) * 2.1
            elif int(unit["side"]) == int(letter["side"]):
                score += maxf(0.0, 58.0 - d) * 0.30
        if score > best_score:
            best_score = score
            best = candidate
    return best


# M5: distinct general profiles. Values are prototype design parameters.
func _set_general_profile(unit: Dictionary) -> void:
    var a: float = float(unit["ability"])
    var profile: Array[float] = [a, a, a, a, 75.0]
    match str(unit["name"]):
        "왕평": profile = [92.0, 76.0, 72.0, 88.0, 92.0]
        "마속": profile = [52.0, 47.0, 89.0, 55.0, 58.0]
        "위연": profile = [84.0, 93.0, 69.0, 81.0, 46.0]
        "장합": profile = [89.0, 86.0, 78.0, 86.0, 85.0]
        "강유": profile = [83.0,79.0,88.0,85.0,80.0]
        "관흥": profile = [74.0,87.0,61.0,72.0,85.0]
        "장익": profile = [82.0,72.0,73.0,78.0,90.0]
        "곽회": profile = [85.0,76.0,83.0,86.0,90.0]
        "비요": profile = [74.0,84.0,65.0,75.0,76.0]
        "왕쌍": profile = [77.0,91.0,61.0,68.0,82.0]
    unit["leadership"] = profile[0]
    unit["martial"] = profile[1]
    unit["intelligence"] = profile[2]
    unit["judgment"] = profile[3]
    unit["loyalty"] = profile[4]

func _effective_stat(unit: Dictionary, key: String) -> float:
    if bool(unit["active_deputy"]):
        var profile: Dictionary = _deputy_profile(int(unit["deputy_index"]))
        return float(profile.get(key, unit[key]))
    var factor: float = 1.0
    match str(unit["general_state"]):
        "부상": factor = 0.72
        "전사": factor = 0.45
    return clampf(float(unit[key]) * factor, 0.0, 100.0)

func _apply_policy(unit: Dictionary, policy: String) -> void:
    unit["policy"] = policy
    unit["obedience"] = policy if policy in ["명령 엄수", "재량 위임"] else "성향 기반"

func _home_point(side: int) -> Vector2:
    return layout_point(Vector2(65,285) if side == 0 else Vector2(835,285))

func _enforce_orders(unit: Dictionary, action: String, reason: String, goal: Vector2, enemy_distance: float) -> Dictionary:
    var result_order: Dictionary = {"action":action, "reason":reason, "goal":goal}
    if action in ["패주", "후퇴", "재집결", "휴식", "탄약 보충", "보급 복귀", "거리 유지", "측면 방어"]:
        return result_order
    var objective: Dictionary = _assigned_outpost(unit)
    var ordered_goal: Vector2 = _mission_point(int(unit["side"]), str(unit["mission"]))
    if not objective.is_empty():
        ordered_goal = objective["pos"]
    var obedience: String = str(unit["obedience"])
    var strict: bool = obedience == "명령 엄수" or (obedience == "성향 기반" and float(unit["loyalty"]) >= 85.0)
    var deviating: bool = goal.distance_to(ordered_goal) > 130.0 and action in ["기지 습격", "측면 우회", "전열 지원", "정보 확인", "반격", "진격", "돌파"]
    if str(unit["mission"]) == "본진 방어" and goal.distance_to(ordered_goal) > 90.0:
        deviating = true
    if strict and deviating:
        unit["raid_active"] = false
        return {"action":"명령 수행", "reason":"장수의 명령 준수 방침: 지정 작전으로 복귀", "goal":ordered_goal}
    if deviating and battle_time - float(unit["last_deviation"]) >= 8.0:
        unit["deviations"] = int(unit["deviations"]) + 1
        unit["last_deviation"] = battle_time
        _log("%s: 현장 판단으로 작전 경로 변경" % str(unit["name"]))
    return result_order

# Scouts physically move; shared reports are snapshots, never live enemy tracking.
func _update_scouts(dt: float) -> void:
    for scout in scouts:
        if not bool(scout["alive"]):
            continue
        var side: int = int(scout["side"])
        var p: Vector2 = scout["pos"]
        var threat: Dictionary = {}
        var threat_d: float = 10000.0
        for enemy in units:
            if int(enemy["side"]) == side or float(enemy["troops"]) <= 0.0 or bool(enemy["routed"]):
                continue
            var d: float = p.distance_to(enemy["pos"])
            if d < threat_d:
                threat = enemy
                threat_d = d
        if threat_d < 23.0:
            scout["alive"] = false
            _log("%s 정찰대 차단" % ("아군" if side == 0 else "적군"))
            continue
        scout["report_timer"] = maxf(0.0, float(scout["report_timer"]) - dt)
        if not threat.is_empty() and threat_d < (125.0 if _in_forest(threat["pos"]) else 190.0) and float(scout["report_timer"]) <= 0.0:
            var scout_bonus: float = 0.0
            for ally in units:
                if int(ally["side"]) == side and ally.get("specialty","") == "정찰" and float(ally["troops"]) > 0.0 and not bool(ally["routed"]):
                    scout_bonus = 0.08
                    break
            var confidence: float = clampf(1.0 - threat_d / 320.0 - (0.18 if _in_forest(threat["pos"]) else 0.0)+scout_bonus, 0.30, 0.95)
            var observed_pos: Vector2 = _field_point((threat["pos"] as Vector2) + Vector2(rng.randf_range(-1.0,1.0),rng.randf_range(-1.0,1.0)) * (1.0-confidence) * 40.0)
            pending_reports.append({"side":side,"id":int(threat["id"]),"pos":observed_pos,"time":battle_time,"type":threat["type"],"troops":roundf(float(threat["troops"])/10.0)*10.0,"confidence":confidence,"arrive":battle_time + 2.0 + p.distance_to(commanders[side]["pos"])/130.0})
            scout["reports"] = int(scout["reports"]) + 1
            scout["report_timer"] = 4.0
            if side == 0:
                _log("정찰대: 관측 정보 전달 중")
        var goal: Vector2 = scout["goal"]
        if not threat.is_empty() and threat_d < 65.0:
            goal = _field_point(p + (p - (threat["pos"] as Vector2)).normalized() * 100.0)
        elif p.distance_to(goal) < 12.0:
            scout["leg"] = (int(scout["leg"]) + 1) % 4
            var x: float = 375.0 if side == 0 else 525.0
            var points: Array[Vector2] = [layout_point(Vector2(x,120)),layout_point(Vector2(x,430)),layout_point(Vector2(460,280)),_home_point(side)]
            scout["goal"] = points[int(scout["leg"])]
            goal = scout["goal"]
        scout["pos"] = _field_point(p.move_toward(goal, 82.0 * dt))
    for side in range(2):
        for id in intelligence[side].keys():
            if battle_time - float(intelligence[side][id]["time"]) > 20.0:
                intelligence[side].erase(id)

func _read_scout_report(unit: Dictionary) -> void:
    if _effective_stat(unit, "intelligence") < 50.0:
        return
    var p: Vector2 = unit["pos"]
    var best_time: float = float(unit["memory_time"])
    for id in intelligence[int(unit["side"])]:
        var report: Dictionary = intelligence[int(unit["side"])][id]
        if float(report["time"]) > best_time and float(report.get("confidence", 0.0)) >= 0.40 and p.distance_to(report["pos"]) < 290.0:
            unit["memory_pos"] = report["pos"]
            unit["memory_time"] = report["time"]
            unit["memory_id"] = int(id)
            best_time = float(report["time"])

func _can_prepare_ambush(unit: Dictionary, enemy: Dictionary) -> bool:
    if str(unit["type"]) == "기병" or str(unit["mission"]) == "본진 방어" or not _in_forest(unit["pos"]) or _effective_stat(unit, "intelligence") < 70.0:
        return false
    if battle_time < float(unit["ambush_until"]) + 8.0 and float(unit["ambush_until"]) >= 0.0:
        return false
    if enemy.is_empty():
        return true
    var d: float = (unit["pos"] as Vector2).distance_to(enemy["pos"])
    return d > 105.0 and d < 230.0

func _update_charge(unit: Dictionary, moved: Vector2, dt: float) -> void:
    var speed: float = moved.length() / maxf(dt, 0.001)
    var direction: Vector2 = moved.normalized()
    var old_direction: Vector2 = unit["charge_dir"]
    var eligible: bool = str(unit["action"]) in ["돌파", "교전", "반격", "측면 우회","협동 우회"] and terrain_at(unit["pos"]) not in ["숲","하천","교량"] and not bool(unit["routed"])
    if eligible and speed > 48.0 and float(unit["charge_cooldown"]) <= 0.0:
        if old_direction.length_squared() > 0.5 and direction.dot(old_direction) < 0.82:
            unit["charge"] = float(unit["charge"]) * 0.3
        unit["charge"] = minf(110.0, float(unit["charge"]) + moved.length())
        unit["charge_dir"] = direction
        unit["charge_speed"] = speed
    else:
        unit["charge"] = maxf(0.0, float(unit["charge"]) - dt * 32.0)
        unit["charge_speed"] = maxf(0.0, float(unit["charge_speed"]) - dt * 100.0)

func _charge_impact(unit: Dictionary, enemy: Dictionary) -> float:
    var distance_run: float = float(unit["charge"])
    var target_dir: Vector2 = ((enemy["pos"] as Vector2) - (unit["pos"] as Vector2)).normalized()
    if distance_run < 32.0 or float(unit["charge_speed"]) < 40.0 or target_dir.dot(unit["charge_dir"]) < 0.72:
        return 0.0
    var impact: float = minf(9.0, distance_run * 0.075) * (float(unit["troops"]) / maxf(1.0, float(unit["initial_troops"])))
    impact *= 0.3 if str(enemy["formation"]) == "방진" else 1.0
    if _in_forest(enemy["pos"]):
        impact *= 0.45
    return maxf(0.0, impact)

func _encirclement(unit: Dictionary) -> bool:
    var p: Vector2 = unit["pos"]
    var rear: Vector2 = Vector2.LEFT if int(unit["side"]) == 0 else Vector2.RIGHT
    var bearings: Array[Vector2] = []
    var retreat_blocked: bool = false
    for enemy in units:
        if int(enemy["side"]) == int(unit["side"]) or float(enemy["troops"]) < 12.0 or bool(enemy["routed"]):
            continue
        var offset: Vector2 = (enemy["pos"] as Vector2) - p
        if offset.length() > 95.0 or offset.length_squared() < 1.0:
            continue
        var dir: Vector2 = offset.normalized()
        bearings.append(dir)
        if dir.dot(rear) > 0.55:
            retreat_blocked = true
    if not retreat_blocked:
        return false
    for i in range(bearings.size()):
        for j in range(i + 1, bearings.size()):
            if bearings[i].dot(bearings[j]) < -0.20:
                return true
    return false

func _update_reserves() -> void:
    for side in range(2):
        if reinforcements_used[side] >= reserve_limit[side]:
            continue
        if battle_time < reserve_next[side] and (not long_operation or _operational_armies(side)>0):
            continue
        var active: int = 0
        var ratio: float = 0.0
        var pressure: float = 0.0
        var assigned: Dictionary = {}
        var worst: float = -1.0
        for unit in units:
            if int(unit["side"]) != side or bool(unit["reserve"]) or unit.has("parent_id"):
                continue
            if float(unit["troops"]) > 0.0 and not bool(unit["routed"]):
                active += 1
            ratio += float(unit["troops"]) / maxf(1.0, float(unit["initial_troops"]))
            var stress: float = float(unit["front_pressure"]) + (1.0 - float(unit["cohesion"]) / 100.0)
            if bool(unit["routed"]) or float(unit["troops"]) <= 0.0:
                stress += 1.0
            pressure = maxf(pressure, stress)
            if stress > worst:
                worst = stress
                assigned = unit
        var expected: int = 6 if six_armies else 3
        if active >= expected and ratio > float(expected)*0.72 and pressure < 0.45 and (long_operation or turn < 5):
            continue
        reinforcements_used[side] += 1
        reserve_next[side] = battle_time + 22.0
        var home: Vector2 = _home_point(side)
        home.y += float(reinforcements_used[side] - 1) * 52.0
        var mission: String = str(assigned.get("mission", "중앙 진격"))
        _add_unit(side, ("왕실 예비대 %d" if side == 0 else "위군 예비대 %d") % reinforcements_used[side], "보병", "균형", 63.0, home, mission, 3000.0 if six_armies else 72.0)
        units.back()["reserve"] = true
        _log("%s 예비대 투입: %s" % ["아군" if side == 0 else "적군", mission])

func _update_general_conditions(unit: Dictionary, dt: float) -> void:
    var was_surrounded: bool = bool(unit["surrounded"])
    unit["surrounded"] = _encirclement(unit)
    if bool(unit["surrounded"]):
        unit["encircled_time"] = float(unit["encircled_time"]) + dt
        unit["morale"] = maxf(0.0, float(unit["morale"]) - dt * 0.65)
        unit["cohesion"] = maxf(0.0, float(unit["cohesion"]) - dt * 0.85)
        if not was_surrounded:
            _log("%s: 퇴로 차단 및 다방향 압박" % str(unit["name"]))
    if str(unit["action"]) == "매복" and _in_forest(unit["pos"]):
        unit["ambush_ready"] = minf(6.0, float(unit["ambush_ready"]) + dt)
    elif not _in_forest(unit["pos"]) or battle_time < float(unit["ambush_until"]):
        unit["ambush_ready"] = 0.0
    else:
        unit["ambush_ready"] = maxf(0.0, float(unit["ambush_ready"]) - dt * 0.5)
    var broken: bool = float(unit["morale"]) < 14.0 or (float(unit["cohesion"]) < 14.0 and float(unit["morale"]) < 37.0)
    if broken and not bool(unit["routed"]):
        unit["routed"] = true
        unit["rout_count"] = int(unit["rout_count"]) + 1
        unit["action"] = "패주"
        unit["reason"] = "전열과 사기 붕괴"
        unit["goal"] = _home_point(int(unit["side"]))
        unit["raid_active"] = false
        unit["ai_cooldown"] = 0.0
        _log("%s: 명령 통제 상실 및 패주" % str(unit["name"]))
    if bool(unit["routed"]):
        var lost: float = minf(float(unit["troops"]), dt * (0.45 if bool(unit["surrounded"]) else 0.15)*(ARMY_SCALE if six_armies else 1.0))
        unit["troops"] = maxf(0.0, float(unit["troops"]) - lost)
        unit["deserted"] = float(unit["deserted"]) + lost
        var p: Vector2 = unit["pos"]
        var threat: Dictionary = _nearest_visible_enemy(unit)
        if p.distance_to(_home_point(int(unit["side"]))) < 75.0 and (threat.is_empty() or p.distance_to(threat["pos"]) > 125.0):
            unit["morale"] = minf(100.0, float(unit["morale"]) + dt * (0.8 + _effective_stat(unit, "leadership") * 0.014))
            unit["cohesion"] = minf(100.0, float(unit["cohesion"]) + dt * 1.8)
            if float(unit["morale"]) >= 42.0 and float(unit["cohesion"]) >= 50.0 and float(unit["troops"]) >= (600.0 if six_armies else 24.0):
                unit["routed"] = false
                unit["rallying"] = true
                unit["ai_cooldown"] = 0.0
                _log("%s: 패주 병력 재수습" % str(unit["name"]))

func _general_exposure(unit: Dictionary, damage: float, flank: bool, shock: float) -> void:
    if str(unit["general_state"]) == "전사":
        return
    var danger: float = damage * (1.5 if flank else 0.72) + shock * 0.55
    if bool(unit["surrounded"]):
        danger *= 1.35
    danger *= 1.15 - float(unit["martial"]) * 0.005
    unit["general_risk"] = float(unit["general_risk"]) + danger
    # Deterministic cumulative exposure, avoiding per-frame random death rolls.
    unit["general_hp"] = maxf(0.0, 100.0 - float(unit["general_risk"]) * 1.4)
    if float(unit["general_hp"]) <= 0.0:
        unit["general_state"] = "전사"
        unit["active_deputy"] = true
        unit["morale"] = maxf(0.0, float(unit["morale"]) - 26.0)
        unit["cohesion"] = maxf(0.0, float(unit["cohesion"]) - 20.0)
        _log("%s 전사: %s 지휘 승계" % [str(unit["name"]), str(_deputy_profile(int(unit["deputy_index"]))["name"])])
    elif float(unit["general_hp"]) < 55.0 and str(unit["general_state"]) == "건재":
        unit["general_state"] = "부상"
        unit["morale"] = maxf(0.0, float(unit["morale"]) - 10.0)
        _log("%s 부상: 지휘 효율 저하" % str(unit["name"]))


# M6: pre-battle planning and scenario configuration.
func set_scenario(index: int) -> bool:
    if started and not finished:
        return false
    scenario_id = clampi(index, 0, 4)
    reset()
    return true

func _configure_scenario() -> void:
    scenario_title = "북남 요충지"
    scenario_goal = "두 요충지를 동시에 점령하고 유지"
    scenario_limit = MAX_SECONDS
    forests = [Rect2(325,80,125,90), Rect2(450,360,130,125)]
    hill = Rect2(400,213,108,89)
    if scenario_id == 1:
        scenario_title = "중앙 고지 쟁탈"
        scenario_goal = "중앙 고지를 18초 연속 확보"
        scenario_limit = 150.0
        hill = Rect2(365,205,170,155)
        forests = [Rect2(230,55,140,110),Rect2(560,370,140,120)]
        outposts[0]["name"] = "중앙 고지"
        outposts[0]["pos"] = Vector2(450,280)
        outposts[1]["name"] = "남측 감시점"
        outposts[1]["pos"] = Vector2(470,465)
        for unit in units:
            if str(unit["type"]) == "보병":
                unit["mission"] = "중앙 진격"
    elif scenario_id == 2:
        scenario_title = "보급로 사수"
        scenario_goal = "120초 동안 아군 보급기지 사수"
        scenario_limit = 120.0
        forests = [Rect2(205,95,160,110),Rect2(310,365,150,125)]
        hill = Rect2(510,215,110,95)
        for unit in units:
            if int(unit["side"]) == 0:
                unit["mission"] = "본진 방어" if str(unit["type"]) != "기병" else "남측 우회"
                unit["defense_anchor"] = Vector2(200, float((unit["pos"] as Vector2).y))
                unit["defense_set"] = str(unit["type"]) != "기병"
            else:
                unit["troops"] = minf(MAX_TROOPS,float(unit["troops"]) * 1.20) if six_armies else float(unit["troops"])*1.20
                unit["initial_troops"] = unit["troops"]
        bases[0]["fixed"] = true
    elif scenario_id == 3:
        scenario_title = "군량 수레 호위"
        scenario_goal = "군량 수레를 동쪽 도착점까지 호위"
        scenario_limit = 180.0
        forests = [Rect2(260,70,120,120),Rect2(530,365,130,115)]
        hill = Rect2(430,85,135,90)
        convoy = {"pos":Vector2(100,282),"goal":Vector2(820,282),"hp":100.0}
        for unit in units:
            if int(unit["side"]) == 0:
                unit["mission"] = "중앙 진격"
    elif scenario_id == 4:
        scenario_title = "천수 돌파전"
        scenario_goal = "적 성문을 파괴하고 중앙 거점을 12초 확보"
        scenario_limit = 180.0
        hill = Rect2(390,190,130,130)
        forests = [Rect2(260,70,105,100),Rect2(510,390,105,100)]
        outposts[0]["name"] = "천수 성문 앞"
        outposts[0]["pos"] = Vector2(705,282)
        for unit in units:
            if str(unit["type"]) == "보병": unit["mission"] = "중앙 진격"

func transfer_troops(receiver_id: int, donor_id: int, amount: int) -> bool:
    if started or amount <= 0 or receiver_id == donor_id:
        return false
    var receiver: Dictionary = find_unit(receiver_id)
    var donor: Dictionary = find_unit(donor_id)
    if receiver.is_empty() or donor.is_empty() or int(receiver["side"]) != 0 or int(donor["side"]) != 0:
        return false
    if float(donor["troops"]) - amount < (1000.0 if six_armies else 40.0) or float(receiver["troops"]) + amount > (5000.0 if six_armies else 220.0):
        return false
    receiver["troops"] = float(receiver["troops"]) + amount
    donor["troops"] = float(donor["troops"]) - amount
    receiver["initial_troops"] = receiver["troops"]
    donor["initial_troops"] = donor["troops"]
    return true

func swap_generals(first_id: int, second_id: int) -> bool:
    if started or first_id == second_id:
        return false
    var first: Dictionary = find_unit(first_id)
    var second: Dictionary = find_unit(second_id)
    if first.is_empty() or second.is_empty() or int(first["side"]) != 0 or int(second["side"]) != 0:
        return false
    for key in ["name","personality","ability","leadership","martial","intelligence","judgment","loyalty","deputy_index"]:
        var temporary: Variant = first[key]
        first[key] = second[key]
        second[key] = temporary
    return true

func place_unit(unit_id: int, position: Vector2) -> bool:
    var unit: Dictionary = find_unit(unit_id)
    if started or unit.is_empty() or int(unit["side"]) != 0 or position.x > 270.0*layout_scale or position.x < 35.0:
        return false
    position = _field_point(position)
    for other in units:
        if int(other["id"]) != unit_id and (other["pos"] as Vector2).distance_to(position) < 50.0:
            return false
    unit["pos"] = position
    unit["goal"] = position
    return true

func add_waypoint(unit_id: int, position: Vector2) -> bool:
    var unit: Dictionary = find_unit(unit_id)
    if started or unit.is_empty() or int(unit["side"]) != 0 or unit["waypoints"].size() >= 5:
        return false
    unit["waypoints"].append(_field_point(position))
    return true

func clear_plan(unit_id: int) -> bool:
    var unit: Dictionary = find_unit(unit_id)
    if started or unit.is_empty() or int(unit["side"]) != 0:
        return false
    unit["waypoints"].clear()
    unit["waypoint_index"] = 0
    unit["defense_set"] = false
    return true

func set_defense_line(unit_id: int, position: Vector2) -> bool:
    var unit: Dictionary = find_unit(unit_id)
    if started or unit.is_empty() or int(unit["side"]) != 0:
        return false
    unit["defense_anchor"] = _field_point(position)
    unit["defense_set"] = true
    return true

func _apply_planned_route(unit: Dictionary, action: String, reason: String, goal: Vector2, enemy_distance: float) -> Dictionary:
    var unchanged: Dictionary = {"action":action,"reason":reason,"goal":goal}
    if action in ["후퇴","패주","재집결","휴식","보급 복귀","탄약 보충","거리 유지","측면 방어"]:
        return unchanged
    var p: Vector2 = unit["pos"]
    var index: int = int(unit["waypoint_index"])
    var points: Array = unit["waypoints"]
    if index < points.size() and p.distance_to(points[index]) <= 22.0:
        index += 1
        unit["waypoint_index"] = index
    if index < points.size() and enemy_distance > 105.0:
        return {"action":"계획 경유","reason":"사전 계획 경유점 %d/%d" % [index+1,points.size()],"goal":points[index]}
    if bool(unit["defense_set"]) and index >= points.size():
        var anchor: Vector2 = unit["defense_anchor"]
        if p.distance_to(anchor) > 28.0:
            return {"action":"방어선 사수","reason":"지정 방어 구역 복귀","goal":anchor}
        return {"action":"방어선 사수","reason":"지정 방어 구역 사수","goal":p}
    return unchanged

func set_supply_priority(unit_id: int, priority: int) -> bool:
    var unit: Dictionary = find_unit(unit_id)
    if unit.is_empty() or int(unit["side"]) != 0 or finished:
        return false
    unit["supply_priority"] = clampi(priority,0,2)
    return true

func _deputy_profile(index: int) -> Dictionary:
    match index:
        1: return {"name":"공격형 부장","leadership":55.0,"martial":76.0,"intelligence":48.0,"judgment":58.0}
        2: return {"name":"책략형 부장","leadership":52.0,"martial":42.0,"intelligence":78.0,"judgment":69.0}
        _: return {"name":"통솔형 부장","leadership":76.0,"martial":53.0,"intelligence":55.0,"judgment":65.0}

func set_deputy(unit_id: int, index: int) -> bool:
    var unit: Dictionary = find_unit(unit_id)
    if started or unit.is_empty() or int(unit["side"]) != 0:
        return false
    unit["deputy_index"] = clampi(index,0,2)
    return true

func deputy_name(unit: Dictionary) -> String:
    return str(_deputy_profile(int(unit["deputy_index"]))["name"])

func _deliver_intel() -> void:
    for i in range(pending_reports.size()-1,-1,-1):
        var report: Dictionary = pending_reports[i]
        if battle_time < float(report["arrive"]):
            continue
        var side: int = int(report["side"])
        var id: int = int(report["id"])
        var old: Dictionary = intelligence[side].get(id,{})
        if old.is_empty() or float(old["time"]) < float(report["time"]):
            intelligence[side][id] = report
            if side == 0:
                _log("정찰 보고 도착: 신뢰도 %d%%" % int(float(report["confidence"])*100.0))
        pending_reports.remove_at(i)

func player_can_see(position: Vector2, concealed: bool = false) -> bool:
    var factor: float = 0.60 if concealed else 1.0
    if (commanders[0]["pos"] as Vector2).distance_to(position) <= 170.0 * factor:
        return true
    for unit in units:
        if int(unit["side"]) != 0 or float(unit["troops"]) <= 0.0 or bool(unit["routed"]):
            continue
        var sight: float = 200.0 * factor * (0.85 + _effective_stat(unit,"intelligence")*0.002)
        if terrain_at(unit["pos"]) == "고지":
            sight *= 1.15
        if (unit["pos"] as Vector2).distance_to(position) <= sight:
            return true
    for scout in scouts:
        if int(scout["side"]) == 0 and bool(scout["alive"]) and (scout["pos"] as Vector2).distance_to(position) <= 145.0 * factor:
            return true
    return false

func timeline_text() -> String:
    var lines: PackedStringArray = []
    for entry in timeline:
        lines.append("%05.1f초 | %02d턴 | %s" % [float(entry["time"])*operation_scale(),int(entry["turn"]),str(entry["message"])])
    return "\n".join(lines)

func request_deputy_takeover(unit_id: int) -> bool:
    var unit: Dictionary = find_unit(unit_id)
    if not started or finished or turn < 6 or unit.is_empty() or int(unit["side"]) != 0 or float(unit["troops"]) <= 0.0 or bool(unit["active_deputy"]):
        return false
    if str(unit["general_state"]) != "부상":
        return false
    for courier in couriers:
        if int(courier["unit_id"]) == unit_id:
            return false
    couriers.append({"pos":commanders[0]["pos"],"unit_id":unit_id,"side":0,"mission":unit["mission"],"policy":unit["policy"],"appoint_deputy":true})
    _log("%s 부대에 부장 지휘 승계 전령 파견" % str(unit["name"]))
    return true

func _record_presentation() -> void:
    for i in range(dust_effects.size()-1,-1,-1):
        if battle_time-float(dust_effects[i]["time"]) >= DUST_LIFE: dust_effects.remove_at(i)
    for i in range(visual_effects.size()-1,-1,-1):
        if battle_time - float(visual_effects[i]["time"]) > 1.2:
            visual_effects.remove_at(i)
    if battle_time >= sample_at or finished:
        troop_history.append({"time":battle_time,"blue":total_troops(0),"red":total_troops(1)})
        sample_at = battle_time + 2.0


# M8: destructible field fortifications in the supply-defense scenario.
func _configure_structures() -> void:
    if scenario_id == 4:
        structures.append({"name":"천수 성문","side":1,"rect":Rect2(640,245,22,76),"hp":105.0,"max_hp":105.0,"kind":"성문"})
        structures.append({"name":"북측 목책","side":1,"rect":Rect2(640,110,14,135),"hp":75.0,"max_hp":75.0,"kind":"목책"})
        structures.append({"name":"남측 목책","side":1,"rect":Rect2(640,321,14,135),"hp":75.0,"max_hp":75.0,"kind":"목책"})
        return
    if scenario_id != 2:
        return
    structures.append({"name":"북쪽 목책","side":0,"rect":Rect2(225,96,14,110),"hp":90.0,"max_hp":90.0,"kind":"목책"})
    structures.append({"name":"중앙 성문","side":0,"rect":Rect2(225,254,20,56),"hp":120.0,"max_hp":120.0,"kind":"성문"})
    structures.append({"name":"남쪽 목책","side":0,"rect":Rect2(225,366,14,106),"hp":90.0,"max_hp":90.0,"kind":"목책"})

func _structure_move(unit: Dictionary, old: Vector2, proposed: Vector2) -> Vector2:
    for structure in structures:
        if float(structure["hp"]) <= 0.0 or int(structure["side"]) == int(unit["side"]):
            continue
        var barrier: Rect2 = (structure["rect"] as Rect2).grow(8.0)
        if barrier.has_point(proposed) and not barrier.has_point(old):
            return old
    return proposed

func _update_structures(dt: float) -> void:
    for structure in structures:
        if float(structure["hp"]) <= 0.0:
            continue
        var center: Vector2 = (structure["rect"] as Rect2).get_center()
        var bounds: Rect2 = (structure["rect"] as Rect2).grow(26.0)
        for unit in units:
            if int(unit["side"]) == int(structure["side"]) or bool(unit["routed"]) or float(unit["troops"]) <= 0.0:
                continue
            if not bounds.has_point(unit["pos"]):
                continue
            var power: float = 5.0 if str(unit["type"]) == "보병" else (2.0 if str(unit["type"]) == "궁병" else 3.0)
            var damage: float = minf(float(structure["hp"]),power*dt*float(unit["troops"])/maxf(1.0,float(unit["initial_troops"])))
            structure["hp"] = maxf(0.0,float(structure["hp"])-damage)
            unit["structure_damage"] = float(unit["structure_damage"])+damage
            if battle_time-float(unit["last_visual"]) >= 0.65:
                unit["last_visual"] = battle_time
                visual_effects.append({"from":unit["pos"],"to":center,"side":unit["side"],"kind":"근접","time":battle_time})
            if float(structure["hp"]) <= 0.0:
                _log(str(structure["name"])+" 파괴: 통행 가능")
                break

func merit(unit: Dictionary) -> int:
    return maxi(0,int(round(float(unit["damage_dealt"])*2.0/(ARMY_SCALE if six_armies else 1.0) + float(unit["objective_time"])*0.8 + float(unit["supply_guard_time"])*0.4 + float(unit["structure_damage"]) - float(unit["deserted"])/(ARMY_SCALE if six_armies else 1.0))))

# Default rear guard is chosen from eligible infantry near the actual commander.
# A deliberate player map order is never silently reassigned to rear guard.
func _escort_rearguard(side: int) -> int:
    var best_id: int = -1
    var best_distance: float = INF
    var origin: Vector2 = commanders[side]["pos"]
    for candidate in units:
        if int(candidate["side"]) != side or str(candidate["type"]) != "보병":
            continue
        if float(candidate["troops"]) <= 0.0 or bool(candidate["routed"]) or bool(candidate["reserve"]):
            continue
        if bool(candidate.get("has_destination",false)) or str(candidate["mission"]) not in ["중앙 진격","본진 방어"]:
            continue
        var distance: float = origin.distance_to(candidate["pos"])
        if distance < best_distance:
            best_distance = distance
            best_id = int(candidate["id"])
    return best_id

func _update_convoy(dt: float) -> void:
    if convoy.is_empty() or float(convoy["hp"]) <= 0.0:
        return
    var p: Vector2 = convoy["pos"]
    var situation: Dictionary = convoy_status()
    var guards: int = int(situation["guards"])
    var attackers: int = int(situation["attackers"])
    if attackers > 0:
        convoy["hp"] = maxf(0.0,float(convoy["hp"])-dt*float(attackers)* (0.8 if guards > 0 else 3.5))
        convoy["blocked_seconds"] = float(convoy.get("blocked_seconds",0.0))+dt
    elif guards == 0:
        convoy["unguarded_seconds"] = float(convoy.get("unguarded_seconds",0.0))+dt
    else:
        convoy["pos"] = p.move_toward(convoy["goal"],dt*(7.5 if long_operation else (25.0 if wide_field else 16.0)))
        convoy["moving_seconds"] = float(convoy.get("moving_seconds",0.0))+dt

# Shared, actual-position rules for the capture check and the player display.
func commander_guard_count(side: int) -> int:
    var count: int = 0
    var origin: Vector2 = commanders[side]["pos"]
    for unit in units:
        if int(unit["side"]) == side and float(unit["troops"]) > 0.0 and not bool(unit["routed"]):
            if (unit["pos"] as Vector2).distance_to(origin) < 76.0:
                count += 1
    return count

func convoy_status() -> Dictionary:
    if convoy.is_empty(): return {}
    var p: Vector2 = convoy["pos"]
    var destination: Vector2 = convoy["goal"]
    var guards: int = 0
    var attackers: int = 0
    for unit in units:
        if float(unit["troops"]) <= 0.0 or bool(unit["routed"]): continue
        var distance: float = p.distance_to(unit["pos"])
        if int(unit["side"]) == 0 and distance < 125.0: guards += 1
        elif int(unit["side"]) == 1 and distance < 65.0: attackers += 1
    var length: float = maxf(1.0,layout_point(Vector2(100,282)).distance_to(destination))
    var progress: float = clampf(1.0-p.distance_to(destination)/length,0.0,1.0)
    var state: String = "파괴" if float(convoy["hp"])<=0.0 else ("도착" if p.distance_to(destination)<12.0 else ("교전 정체" if attackers>0 else ("호위 대기" if guards==0 else ("호위 이동" if started else "출전 준비"))))
    return {"guards":guards,"attackers":attackers,"progress":progress,"remaining":p.distance_to(destination),"state":state}

# Read-only route preview for the selected army. Never picks a new bridge.
func committed_route_preview(unit: Dictionary) -> Array[Vector2]:
    var points: Array[Vector2] = []
    var p: Vector2 = unit["pos"]
    var goal: Vector2 = unit["goal"]
    var bridge: float = float(unit.get("bridge_y",-1.0))
    if long_operation and bridge>=0.0:
        var exit_bank: int = int(unit.get("bridge_bank",0))
        var rx: float = river_x(bridge)
        if exit_bank != 0:
            if (p.x-river_x(p.y))*exit_bank<0.0 and absf(p.x-river_x(p.y))>=35.0:
                points.append(Vector2(rx-exit_bank*64.0,bridge))
            points.append(Vector2(rx+exit_bank*64.0,bridge))
    points.append(goal)
    return points

# Cavalry and withdrawing units bypass barriers using end-point detours.
# Infantry can stay and attack the barrier. This is local steering, not global A*.
func _detour_goal(unit: Dictionary,p: Vector2,goal: Vector2) -> Vector2:
    for structure in structures:
        if float(structure["hp"]) <= 0.0 or int(structure["side"]) == int(unit["side"]):
            continue
        var area: Rect2 = (structure["rect"] as Rect2).grow(15.0)
        var blocked: bool = false
        for i in range(1,9):
            if area.has_point(p.lerp(goal,float(i)/8.0)):
                blocked = true
                break
        if not blocked:
            continue
        var top := Vector2(area.get_center().x,area.position.y-12.0)
        var bottom := Vector2(area.get_center().x,area.end.y+12.0)
        var via: Vector2 = top if p.distance_to(top)+top.distance_to(goal) < p.distance_to(bottom)+bottom.distance_to(goal) else bottom
        if absf(p.y-via.y) > 8.0:
            return _field_point(Vector2(p.x,via.y))
        return _field_point(Vector2(goal.x,via.y))
    return goal

func order_retreat() -> bool:
    if not started or finished:
        return false
    _finish("책사 철수 결정 — 패배")
    return true


# Reports describe allied observations, arrive after a physical-distance delay,
# and expire. A report never grants live information about unseen enemies.
func _scan_situations() -> void:
    if battle_time-last_situation_scan < 2.0:
        return
    last_situation_scan = battle_time
    for report in situation_reports:
        if report["status"] == "대기" and battle_time >= float(report["arrive"]):
            report["status"] = "미대응"
            _log("긴급 보고: "+str(report["title"]))
        if report["status"] == "미대응" and battle_time >= float(report["expires"]):
            report["status"] = "시간 경과"
    for unit in units:
        if int(unit["side"]) != 0 or float(unit["troops"]) <= 0.0 or bool(unit["reserve"]):
            continue
        var kind: String = ""
        if bool(unit["surrounded"]):
            kind = "포위 위험"
        elif float(unit["morale"]) < 45.0 or float(unit["cohesion"]) < 42.0:
            kind = "전열 붕괴 위험"
        elif float(unit["rations"]) < 24.0:
            kind = "군량 부족"
        elif battle_time-float(unit["last_deviation"]) < 3.0:
            kind = "명령 이탈"
        elif float(unit["general_hp"]) < 55.0:
            kind = "장수 부상"
        elif str(unit["type"]) == "궁병" and float(unit["ammo"]) < 20.0:
            kind = "화살 부족"
        elif float(unit["front_pressure"]) > 0.60:
            kind = "전선 압박"
        var proposal: String=str(unit.get("mind",{}).get("proposal",""))
        if kind == "" and proposal=="사수": kind="사수 건의"
        if kind == "":
            continue
        var key: String = "%d:%s" % [unit["id"],kind]
        if battle_time-float(situation_keys.get(key,-100.0)) < 30.0:
            continue
        situation_keys[key] = battle_time
        situation_serial += 1
        var delay: float = 2.0+(unit["pos"] as Vector2).distance_to(commanders[0]["pos"])/150.0
        situation_reports.append({"id":situation_serial,"unit_id":unit["id"],"title":str(unit["name"])+" · "+kind+(" / "+proposal+" 건의" if not proposal.is_empty() else ""),"kind":kind,"proposal":proposal,"pos":unit["pos"],"arrive":battle_time+delay,"expires":battle_time+delay+26.0,"status":"대기"})
        if situation_reports.size() > 80:
            for j in range(situation_reports.size()):
                if str(situation_reports[j]["status"]) not in ["대기","미대응","전령 파견","명령 수령","실행 중"]:
                    situation_reports.remove_at(j)
                    break

# Follow actual courier and tactical execution, rather than treating dispatch as success.
func _response_delivery(letter: Dictionary,status: String) -> void:
    var id: int=int(letter.get("report_id",-1))
    if id<0: return
    for report in situation_reports:
        if int(report["id"])!=id: continue
        report["status"]=status
        report["resolved_at"]=battle_time
        if status=="명령 수령":
            var actor: Dictionary=find_unit(int(letter["unit_id"]))
            if actor.is_empty(): return
            report["received_at"]=battle_time
            report["until"]=float(actor["tactical_until"])
            report["loss_start"]=float(actor["casualties_taken"])
            report["damage_start"]=float(actor["damage_dealt"])
            report["executed"]=false
            report["action_seen"]=""
            report["loss_delta"]=0
            report["damage_delta"]=0
        return

func _update_response_outcomes() -> void:
    for report in situation_reports:
        var status: String=str(report["status"])
        if status=="전령 파견" and finished:
            report["status"]="종전 · 미전달"
            continue
        if status not in ["명령 수령","실행 중"]: continue
        var actor: Dictionary=find_unit(int(report.get("executor",-1)))
        if actor.is_empty():
            report["status"]="수신 부대 상실"
            continue
        if absf(float(actor["tactical_until"])-float(report.get("until",0.0)))>0.01:
            report["status"]="후속 지시로 종료"
            report["resolved_at"]=battle_time
            continue
        var expected: String=str({"지원":"긴급 지원","사수":"긴급 방어","재집결":"전술 재집결","철수":"전술 철수"}.get(str(report.get("response","")),""))
        var actual: String=str(actor["action"])
        if not expected.is_empty() and actual==expected and battle_time<=float(report.get("until",0.0)):
            report["executed"]=true
            report["action_seen"]=actual
            report["status"]="실행 중"
        report["loss_delta"]=roundi(maxf(0.0,float(actor["casualties_taken"])-float(report.get("loss_start",0.0))))
        report["damage_delta"]=roundi(maxf(0.0,float(actor["damage_dealt"])-float(report.get("damage_start",0.0))))
        if float(actor["troops"])<=0.0:
            report["status"]="실행 부대 상실"
        elif finished or battle_time>=float(report.get("until",0.0)):
            report["status"]="실행 종료" if bool(report.get("executed",false)) else "실행 미확인"
            report["resolved_at"]=battle_time

func open_situations() -> Array[Dictionary]:
    var result_reports: Array[Dictionary] = []
    for report in situation_reports:
        if report["status"] == "미대응":
            result_reports.append(report)
    return result_reports

func respond_situation(report_id: int, response: String) -> bool:
    if not tactical_enabled or not started or finished:
        return false
    for report in situation_reports:
        if int(report["id"]) != report_id or report["status"] != "미대응":
            continue
        var id: int = int(report["unit_id"])
        var target: Dictionary = find_unit(id)
        if target.is_empty() or float(target["troops"]) <= 0.0:
            report["status"] = "부대 상실"
            return false
        if response == "현장 판단":
            report["status"] = "재량 유지"
            GeneralMind.acknowledge(target,battle_time)
            _log(str(target["name"])+": 보고 확인, 기존 작전 유지")
            return true
        if response == "지원":
            var best: Dictionary = {}
            var best_score: float = -INF
            for ally in units:
                if int(ally["side"]) != 0 or int(ally["id"]) == id or bool(ally["routed"]) or float(ally["troops"]) < 24.0:
                    continue
                var score: float = float(ally["morale"])-(ally["pos"] as Vector2).distance_to(target["pos"])*0.1
                if score > best_score:
                    best = ally
                    best_score = score
            if best.is_empty() or not request_tactical(int(best["id"]),"지원",id):
                return false
        elif not request_tactical(id,response):
            return false
        report["status"] = "전령 파견"
        var letter: Dictionary=couriers.back()
        letter["report_id"]=report_id
        report["response"]=response
        report["executor"]=int(letter["unit_id"])
        report["sent_at"]=battle_time
        return true
    return false

func request_tactical(unit_id: int, order: String, support_id: int = -1) -> bool:
    if not tactical_enabled or not started or finished or turn < 6 or command_points <= 0:
        return false
    if order not in ["사수","재집결","철수","지원"]:
        return false
    var unit: Dictionary = find_unit(unit_id)
    if unit.is_empty() or int(unit["side"]) != 0 or float(unit["troops"]) <= 0.0:
        return false
    if order == "지원":
        var ally: Dictionary = find_unit(support_id)
        if ally.is_empty() or int(ally["side"]) != 0 or support_id == unit_id:
            return false
    for letter in couriers:
        if int(letter["unit_id"]) == unit_id:
            return false
    command_points -= 1
    couriers.append({"pos":commanders[0]["pos"],"unit_id":unit_id,"side":0,"mission":unit["mission"],"policy":unit["policy"],"tactical_order":order,"support_id":support_id})
    _log("긴급 전령 → %s / %s" % [unit["name"],order])
    return true

func _deliver_tactical(unit: Dictionary, letter: Dictionary) -> void:
    var order: String = letter["tactical_order"]
    # Independent aggressive commanders sometimes reject a withdrawal while
    # they have a viable advantage; strict orders and high loyalty take priority.
    var enemy: Dictionary = _nearest_visible_enemy(unit)
    var advantage: bool = not enemy.is_empty() and float(unit["troops"]) > float(enemy["troops"])*1.15
    if order == "철수" and str(unit["personality"]) == "공격" and str(unit["obedience"]) != "명령 엄수" and (GeneralMind.confidence_to_refuse(unit) if long_operation else float(unit["loyalty"])) < 60.0 and advantage and float(unit["morale"]) > 60.0:
        tactical_refused += 1
        _response_delivery(letter,"명령 거부")
        GeneralMind.order(unit,"거부: 철수 / 현장 우세 판단",battle_time,true)
        _log(str(unit["name"])+": 우세 판단으로 철수 명령 거부")
        return
    tactical_delivered += 1
    GeneralMind.order(unit,"수령: 긴급 "+order,battle_time)
    unit["tactical_order"] = order
    unit["tactical_target"] = int(letter.get("support_id",-1))
    unit["tactical_anchor"] = unit["pos"]
    unit["tactical_until"] = battle_time+24.0
    _response_delivery(letter,"명령 수령")
    unit["ai_cooldown"] = 0.0
    _log(str(unit["name"])+": 긴급 "+order+" 명령 도착")

func _tactical_decision(unit: Dictionary, enemy: Dictionary, action: String, reason: String, goal: Vector2, distance: float, strength: float) -> Dictionary:
    var result_order: Dictionary = {"action":action,"reason":reason,"goal":goal}
    if bool(unit["routed"]) or float(unit["morale"]) < 19.0 or float(unit["troops"]) < (600.0 if six_armies else 24.0):
        return result_order
    if battle_time < float(unit["tactical_until"]):
        var order: String = unit["tactical_order"]
        if order == "철수":
            return {"action":"전술 철수","reason":"전령 명령: 생존 병력 보존","goal":_home_point(int(unit["side"]))}
        if order == "재집결":
            return {"action":"전술 재집결","reason":"전령 명령: 아군 후방에서 재정비","goal":_rally_point(unit)}
        if order == "사수":
            return {"action":"긴급 방어","reason":"전령 명령: 현재 위치 사수","goal":unit["tactical_anchor"]}
        if order == "지원":
            var ally: Dictionary = find_unit(int(unit["tactical_target"]))
            if not ally.is_empty() and float(ally["troops"]) > 0.0:
                return {"action":"긴급 지원","reason":"전령 명령: "+str(ally["name"])+" 지원","goal":(ally["pos"] as Vector2)+Vector2(-32,0)}
    # Autonomous initiative: an aggressive low-loyalty commander may exploit
    # an observed weak enemy, while strict or cautious commanders retain orders.
    if enemy.is_empty() or distance > 180.0 or strength < (GeneralMind.initiative_threshold(unit) if long_operation else 1.30) or float(unit["morale"]) < 65.0 or str(unit["obedience"]) == "명령 엄수" or action in ["후퇴","패주","재집결","휴식","거리 유지","측면 방어","보급 호위","탄약 보충","보급 복귀"]:
        return result_order
    if str(unit["personality"]) == "공격" and float(unit["loyalty"]) < 65.0 and str(unit["mission"]) != "중앙 진격":
        if battle_time >= float(unit["initiative_until"]):
            unit["initiative_until"] = battle_time+12.0
            unit["deviations"] = int(unit["deviations"])+1
            unit["last_deviation"] = battle_time
            _log(str(unit["name"])+": 관측된 약한 적을 독자 추격")
        return {"action":"돌파","reason":"독자 판단: 관측 우세 %.2f / 필요 %.2f" % [strength,GeneralMind.initiative_threshold(unit) if long_operation else 1.30],"goal":enemy["pos"]}
    return result_order

# Scale strategic locations, not soldiers, attack reach or line-of-sight.
func set_wide_field(enabled: bool) -> void:
    wide_field = enabled
    reset()

func layout_point(p: Vector2) -> Vector2:
    return p*layout_scale

func road_y(x: float,lane: int) -> float:
    var y: float = [131.0,282.0,435.0][lane]*layout_scale
    if wide_field:
        y += sin(x/220.0+float(lane)*1.6)*48.0+sin(x/94.0+float(lane))*19.0
    return y

func _expand_layout() -> void:
    layout_scale = 3.0 if wide_field else 1.0
    field_size = Vector2(FIELD_W,FIELD_H)*layout_scale
    if not wide_field: return
    for unit in units:
        for key in ["pos","goal","defense_anchor","tactical_anchor"]:
            unit[key] = layout_point(unit[key])
    for base in bases:
        for key in ["pos","target"]: base[key] = layout_point(base[key])
    for commander in commanders:
        for key in ["pos","goal"]: commander[key] = layout_point(commander[key])
    for scout in scouts:
        for key in ["pos","goal"]: scout[key] = layout_point(scout[key])
    for site in outposts:
        site["pos"] = layout_point(site["pos"])
    if not convoy.is_empty():
        for key in ["pos","goal"]: convoy[key] = layout_point(convoy[key])
    for i in range(forests.size()):
        var old: Rect2 = forests[i]
        var size: Vector2 = old.size*1.75
        forests[i] = Rect2(layout_point(old.get_center())-size*0.5,size)
    # Scenario-specific tactical terrain, shared by pathing, AI vision, movement,
    # battle painting and the separate order map. Bridge and road topology stays fixed.
    match scenario_id:
        0:
            forests.append_array([Rect2(570,520,230,250),Rect2(1830,1130,280,220),Rect2(1110,1270,210,180),Rect2(1920,240,220,190)])
        1:
            # Central plateau: screened north and south approaches, open crest.
            forests.append_array([Rect2(620,200,230,270),Rect2(1660,170,310,250),Rect2(710,1130,280,290),Rect2(1820,1150,350,230)])
        2:
            # Defense: broken cover on approaches to the defensive perimeter;
            # retain a clear deployment and withdrawal corridor behind the wall.
            forests.append_array([Rect2(850,160,180,260),Rect2(890,1040,180,240),Rect2(1510,510,260,240),Rect2(1740,1190,340,260)])
        3:
            # Convoy: cover north and south of the actual road, not on the crossing.
            forests.append_array([Rect2(610,410,270,220),Rect2(610,1080,260,230),Rect2(1430,330,320,260),Rect2(1850,1010,320,270)])
        4:
            # Siege: screened approach, more exposed ground immediately at the gate.
            forests.append_array([Rect2(560,170,310,250),Rect2(600,1210,300,230),Rect2(1420,210,270,240),Rect2(1470,1260,270,220)])
    var hill_size: Vector2 = hill.size*1.8
    hill = Rect2(layout_point(hill.get_center())-hill_size*0.5,hill_size)
    for structure in structures:
        var old: Rect2 = structure["rect"]
        structure["rect"] = Rect2(layout_point(old.position),Vector2(old.size.x,old.size.y*3.0))
    scenario_limit = [360.0,330.0,300.0,390.0,360.0][scenario_id]
    if six_armies and scenario_id == 0:
        outposts.append({"name":"중앙 교량 거점","pos":Vector2(1370,850),"owner":-1,"challenger":-1,"progress":0.0,"hold":0.0})
        scenario_goal = "6턴 이후 세 거점 중 두 곳을 8초 확보"
    if scenario_id == 1:
        scenario_goal = "6턴 이후 중앙 고지 30초 연속 확보"
    elif scenario_id == 2:
        scenario_goal = "300초 동안 아군 보급기지 사수"
    reserve_next = [36.0,36.0]
    if long_operation:
        scenario_limit = 420.0 if scenario_id == 3 else LONG_LIMIT
        reserve_next = [135.0,135.0]
        match scenario_id:
            0: scenario_goal="18분 이후 세 거점 중 두 곳을 3분 연속 확보"
            1: scenario_goal="18분 이후 중앙 고지 3분 연속 확보"
            2: scenario_goal="25분 동안 아군 보급기지 사수"
            3: scenario_goal="28분 이내 군량 수레를 동쪽 도착점까지 호위"
            4: scenario_goal="18분 이후 성문 파괴 및 중앙 거점 2분 확보"

# Wide-field corps are split into actual autonomous detachments, never extra
# fictional soldiers. Main commanders remain IDs 0–5; reserves follow.
func _deploy_detachments() -> void:
    var leaders: Array[Dictionary] = units.duplicate()
    for leader in leaders:
        var total: float = float(leader["troops"])
        if total < 60.0 or bool(leader["reserve"]) or leader.has("parent_id"):
            continue
        var detached: float = floorf(total*0.32)
        var share: float = detached/total
        leader["troops"] = total-detached
        leader["initial_troops"] = leader["troops"]
        leader["strength_share"] = 1.0-share
        var wing: float = -1.0 if int(leader["id"])%2 == 0 else 1.0
        var front: Vector2 = leader["facing"]
        var start_pos: Vector2 = _field_point((leader["pos"] as Vector2)+front.orthogonal()*wing*78.0-front*38.0)
        _add_unit(int(leader["side"]),str(leader["name"])+" 별동대",str(leader["type"]),"균형",float(leader["ability"])*0.85,start_pos,str(leader["mission"]),detached)
        var sub: Dictionary = units.back()
        sub["parent_id"] = int(leader["id"])
        sub["wing"] = wing
        sub["strength_share"] = share
        sub["rations"] = leader["rations"]
        sub["ammo"] = leader["ammo"]
        sub["supply_priority"] = leader["supply_priority"]
        sub["formation"] = leader["formation"]
        sub["policy"] = leader["policy"]
        sub["obedience"] = leader["obedience"]
        sub["specialty"] = leader.get("specialty","")
        for key in ["leadership","martial","intelligence","judgment","loyalty"]:
            sub[key] = maxf(35.0,float(leader[key])*0.86)
    _log("군단 편성: 본대와 별동대 전개")

func corps_report(id: int) -> Dictionary:
    var report: Dictionary = {"troops":0.0,"damage_dealt":0.0,"casualties_taken":0.0,"deserted":0.0,"decisions":0,"merit":0}
    for member in units:
        if int(member["id"]) != id and int(member.get("parent_id",-1)) != id: continue
        for key in ["troops","damage_dealt","casualties_taken","deserted","decisions"]:
            report[key] += member[key]
        report["merit"] += merit(member)
    return report

func river_x(y: float) -> float:
    return 1120.0+sin(y/225.0)*100.0+sin(y/89.0)*34.0

func near_crossing(y: float) -> bool:
    for crossing in [390.0,850.0,1300.0]:
        if absf(y-crossing) <= 38.0: return true
    return false

func _crossing_route(p: Vector2,goal: Vector2) -> Vector2:
    if absf(p.x-river_x(p.y)) < 36.0:
        if six_armies and near_crossing(p.y):
            var direction: float = 1.0 if goal.x > river_x(goal.y) else -1.0
            return Vector2(river_x(p.y)+direction*65.0,p.y)
        return goal
    if (p.x-river_x(p.y))*(goal.x-river_x(goal.y)) >= 0.0: return goal
    var best_y: float = 850.0
    var best_score: float = INF
    for y in [390.0,850.0,1300.0]:
        var crossing := Vector2(river_x(y),y)
        var score: float = p.distance_to(crossing)+crossing.distance_to(goal)
        if score < best_score:
            best_score = score
            best_y = y
    if absf(p.y-best_y) < 30.0: return Vector2(river_x(best_y)+(65.0 if p.x < river_x(p.y) else -65.0),best_y)
    return Vector2(river_x(best_y)+(-58.0 if p.x < river_x(p.y) else 58.0),best_y)

func set_six_armies(enabled: bool) -> void:
    six_armies = enabled
    if enabled: wide_field = true
    reset()

func command_ids(side: int) -> Array[int]:
    var ids: Array[int] = []
    for unit in units:
        if int(unit["side"]) == side and not bool(unit["reserve"]) and not unit.has("parent_id"):
            ids.append(int(unit["id"]))
    return ids

func _infantry_screen(unit: Dictionary) -> Dictionary:
    var best: Dictionary = {}
    var score: float = 380.0
    var p: Vector2 = unit["pos"]
    for ally in units:
        if int(ally["side"]) != int(unit["side"]) or str(ally["type"]) != "보병" or bool(ally["routed"]) or float(ally["troops"]) <= 24.0: continue
        if str(ally["mission"]) == "본진 방어" and str(unit["mission"]) != "본진 방어": continue
        var d: float = p.distance_to(ally["pos"])
        if str(ally["mission"]) == str(unit["mission"]): d *= 0.60
        if d < score:
            score = d
            best = ally
    return best

# Shared formation geometry: both tactical contact slots and rendered soldiers
# derive from the same oriented rank shapes, with a bounded representative count.
func army_slots(unit: Dictionary,count: int,spacing: float,shape_override: String = "") -> Array[Vector2]:
    var points: Array[Vector2] = []
    if count <= 0 or float(unit["troops"]) <= 0.0: return points
    var front: Vector2 = unit["facing"]
    if front.length_squared()<0.01: front=Vector2.RIGHT if int(unit["side"])==0 else Vector2.LEFT
    front=front.normalized()
    var side: Vector2=front.orthogonal()
    var local: Array[Vector2]=[]
    var shape: String=str(unit["formation"]) if shape_override.is_empty() else shape_override
    var width: int=mini(count,8)
    if shape=="종대": width=mini(count,4)
    elif shape=="방진": width=ceili(sqrt(float(count)))
    elif shape in ["어린진","봉시진"]: width=7
    elif shape=="학익진": width=mini(count,10)
    elif shape=="안행진": width=mini(count,9)
    var row: int=0
    while local.size()<count:
        var row_width: int=width
        if shape=="어린진": row_width=mini(7,3+row*2)
        elif shape=="봉시진": row_width=mini(7,1+row*2)
        row_width=mini(row_width,count-local.size())
        for i in range(row_width):
            var lateral: float=float(i)-float(row_width-1)*0.5
            var depth: float=-float(row)
            if shape=="학익진": depth+=absf(lateral)*0.65
            elif shape=="안행진": depth+=lateral*0.45
            local.append(Vector2(depth,lateral))
        row+=1
    var center:=Vector2.ZERO
    for p in local: center+=p
    center/=float(local.size())
    for p in local:
        var q: Vector2=(p-center)*spacing
        var pos:Vector2=(unit["pos"] as Vector2)+front*q.x+side*q.y
        points.append(_dry_formation_slot(unit["pos"],pos) if long_operation else pos)
    return points

func _formation_extent(unit: Dictionary,direction: Vector2) -> float:
    var p: Vector2=unit["pos"]
    var extent: float=10.0
    for slot in formation_slots(unit):
        extent=maxf(extent,(slot-p).dot(direction)+8.0)
    return extent

# Soil classification is deliberately independent of the army's order or animation.
# Only exposed dirt roads produce dust. Grass, forest, hill, river, wooden bridge do not.
func dusty_ground(p: Vector2) -> bool:
    return terrain_at(p) == "도로"

func _emit_march_dust(unit: Dictionary,previous: Vector2,displacement: Vector2) -> void:
    var distance: float = displacement.length()
    if distance < 0.20 or float(unit["troops"]) <= 0.0:
        unit["dust_distance"] = 0.0
        return
    var accumulated: float = float(unit.get("dust_distance",0.0))+distance
    var cavalry: bool = str(unit["type"])=="기병"
    var spacing: float = 7.0 if cavalry else 10.0
    if accumulated < spacing:
        unit["dust_distance"] = accumulated
        return
    unit["dust_distance"] = fmod(accumulated,spacing)
    var forward: Vector2 = displacement.normalized()
    var slots: Array[Vector2] = formation_slots(unit)
    # Sample actual representative feet along the traveled segment, not the target position.
    for i in range(0,slots.size(),3):
        var foot: Vector2 = slots[i]-displacement*0.5
        if not dusty_ground(foot): continue
        var seed_value: float = float(step_count*37+int(unit["id"])*19+i*13)
        var variation: float = sin(seed_value*1.73)
        var radius: float = (17.0 if cavalry else 12.0)*(0.8+absf(variation)*0.5)
        dust_effects.append({"pos":foot,"dir":forward,"time":battle_time,"radius":radius,"side":unit["side"],"phase":variation,"surface":"도로"})
        if dust_effects.size()>DUST_LIMIT: dust_effects.pop_front()

# Contextual counter relations. The numerical factor is a prototype, not an
# automatic victory: range, direction, formation, fatigue and terrain still matter.
func tactical_matchup(attacker: Dictionary,defender: Dictionary,side_attack: bool) -> float:
    var a: String=str(attacker["type"])
    var d: String=str(defender["type"])
    var af: String=str(attacker["formation"])
    var df: String=str(defender["formation"])
    var factor: float=1.0
    if a=="기병" and d=="궁병": factor=1.35
    elif a=="기병" and d=="보병":
        factor=0.65 if df=="방진" and not side_attack else (1.22 if side_attack else 1.04)
    elif a=="보병" and d=="기병":
        factor=1.30 if af=="방진" and not side_attack else 0.91
    elif a=="궁병" and d=="보병":
        factor=1.16 if df!="방진" else 0.84
    elif a=="궁병" and d=="기병":
        factor=0.80 if (attacker["pos"] as Vector2).distance_to(defender["pos"])<95.0 else 1.08
    elif a=="보병" and d=="궁병": factor=1.15
    if a=="기병" and terrain_at(attacker["pos"]) in ["숲","하천","교량"]: factor*=0.72
    if df=="봉시진" and a=="보병" and af=="방진" and not side_attack: factor*=1.12
    return factor

func _has_combined_arms(unit: Dictionary,enemy: Dictionary,targets: Dictionary = {}) -> bool:
    var p: Vector2=unit["pos"]
    var ep: Vector2=enemy["pos"]
    for ally in units:
        if int(ally["side"])!=int(unit["side"]) or int(ally["id"])==int(unit["id"]) or bool(ally["routed"]) or float(ally["troops"])<600.0 or float(ally["cohesion"])<35.0: continue
        if str(ally["type"])==str(unit["type"]) or p.distance_to(ally["pos"])>245.0: continue
        if str(ally["type"])=="궁병" and float(ally["ammo"])<=0.0: continue
        if not targets.is_empty():
            var assigned: Dictionary=targets.get(int(ally["id"]),{})
            if assigned.is_empty() or int(assigned["id"])!=int(enemy["id"]): continue
        var ally_reach: float=173.0 if str(ally["type"])=="궁병" else 30.0
        if formation_contacts(ally,enemy,ally_reach)<=0: continue
        var a: Vector2=(p-ep).normalized()
        var b: Vector2=((ally["pos"] as Vector2)-ep).normalized()
        if str(ally["type"])=="궁병" or str(unit["type"])=="궁병" or a.dot(b)<0.45: return true
    return false

# Cooperation uses a friendly anchor and local observation, not an omniscient
# enemy position. A flank waypoint stays committed until reached or timed out.
func _coordinated_order(unit: Dictionary,enemy: Dictionary,action: String,reason: String,goal: Vector2) -> Dictionary:
    var original: Dictionary={"action":action,"reason":reason,"goal":goal}
    var mission: String=str(unit["mission"])
    var tactical_role:bool=long_operation and int(unit["side"])==1 and battle_time<float(unit.get("ai_role_until",0.0)) and str(unit.get("ai_role",""))!=""
    if tactical_role: mission=str(unit["ai_role"])
    if mission not in ["전열 엄호","측후방 기동","구원 지원","궁병 보호"]: return original
    if action in ["후퇴","패주","재집결","휴식","탄약 보충","보급 복귀","거리 유지","측면 방어"]: return original
    var p: Vector2=unit["pos"]
    var ally: Dictionary={}
    var best: float=INF
    for friend in units:
        if int(friend["side"])!=int(unit["side"]) or int(friend["id"])==int(unit["id"]) or bool(friend["routed"]) or float(friend["troops"])<600.0: continue
        if str(friend["mission"]) in ["본진 방어","측후방 기동","전열 엄호","구원 지원"]: continue
        if mission=="전열 엄호" and str(friend["type"])!="보병": continue
        var score: float=p.distance_to(friend["pos"])-float(friend["front_pressure"])*180.0
        if mission=="구원 지원": score-=maxf(0.0,70.0-float(friend["morale"]))*3.0
        if int(friend["id"])==int(unit["link_id"]): score-=65.0
        if score<best:
            best=score
            ally=friend
    var assigned: Dictionary=find_unit(int(unit.get("ai_partner",-1)) if tactical_role else int(unit.get("assigned_link",-1)))
    if not assigned.is_empty() and _valid_partner(unit,int(assigned["id"])):
        ally=assigned
    elif tactical_role:
        return original
    if ally.is_empty():
        unit["link_id"]=-1
        return original
    unit["link_id"]=ally["id"]
    var ap: Vector2=ally["pos"]
    var forward: Vector2=ally["facing"]
    if forward.length_squared()<0.01: forward=Vector2.RIGHT if int(unit["side"])==0 else Vector2.LEFT
    if (mission=="궁병 보호" or mission=="전열 엄호") and str(unit["type"])=="보병" and str(ally["type"])=="궁병":
        var threat:Dictionary=_observed_threat_to(unit,ally)
        if not threat.is_empty():
            var toward:Vector2=((threat["pos"] as Vector2)-ap).normalized()
            var distance_to_threat:float=ap.distance_to(threat["pos"])
            var guard_goal:Vector2=ap+toward*clampf(distance_to_threat*0.5,30.0,90.0)
            return {"action":"궁병 보호","reason":str(ally["name"])+"군으로 접근하는 적을 차단","goal":guard_goal}
        return {"action":"협동 엄호","reason":str(ally["name"])+"군 전방 경계","goal":ap+forward*70.0}
    if mission=="전열 엄호":
        var wing: float=1.0 if int(unit["id"])%2==0 else -1.0
        var support_point: Vector2=ap-forward*108.0+forward.orthogonal()*36.0*wing
        if str(unit["type"])!="궁병": support_point=ap+forward.orthogonal()*95.0*wing-forward*25.0
        return {"action":"협동 엄호","reason":str(ally["name"])+"군 후방·측면 엄호","goal":support_point}
    if mission=="구원 지원":
        return {"action":"구원 지원","reason":str(ally["name"])+"군 압박 완화","goal":ap+forward.orthogonal()*90.0}
    # Prefer the front army's observed opponent if this army can see it too.
    var pinned: Dictionary=find_unit(int(ally.get("memory_id",-1)))
    if not pinned.is_empty() and _locally_observed(unit,pinned):
        enemy=pinned
    var previous: Dictionary=find_unit(int(unit["flank_target"]))
    if not previous.is_empty() and _locally_observed(unit,previous) and (battle_time<float(unit["flank_until"]) or (long_operation and int(unit["flank_phase"])>=1)):
        enemy=previous
    if long_operation and battle_time<float(unit["flank_recovery"]):
        return {"action":"협동 대기","reason":"우회 재정비 후 재기동","goal":_field_point(ap-forward*45.0+forward.orthogonal()*100.0)}
    if enemy.is_empty():
        unit["flank_target"]=-1
        unit["flank_phase"]=0
        var wing: float=1.0 if int(unit["id"])%2==0 else -1.0
        return {"action":"협동 우회","reason":str(ally["name"])+"군과 측면 전개","goal":ap+forward.orthogonal()*165.0*wing}
    var ep: Vector2=enemy["pos"]
    var ef: Vector2=enemy["facing"]
    if ef.length_squared()<0.01: ef=-forward
    var lateral: Vector2=ef.orthogonal()
    if long_operation and int(unit["flank_target"])==int(enemy["id"]) and int(unit["flank_phase"])==2:
        if formation_contacts(unit,enemy,30.0)>0 or formation_contacts(ally,enemy,30.0)>0:
            unit["flank_contact_at"]=battle_time
        if battle_time-float(unit["flank_contact_at"])<=6.0:
            return {"action":"돌파","reason":str(ally["name"])+"군과 협동 공격 지속","goal":ep}
        unit["flank_aborts"]+=1
        unit["flank_recovery"]=battle_time+15.0
        unit["flank_phase"]=0
        unit["flank_target"]=-1
        return {"action":"협동 대기","reason":"정면 연계 상실, 재정비","goal":p}
    if long_operation and int(unit["flank_target"])==int(enemy["id"]) and int(unit["flank_phase"])<2 and battle_time>=float(unit["flank_until"]):
        unit["flank_aborts"]+=1
        unit["flank_recovery"]=battle_time+15.0
        unit["flank_target"]=-1
        unit["flank_phase"]=0
        return {"action":"협동 대기","reason":"우회 시간 초과, 재정비","goal":p}
    if int(unit["flank_target"])!=int(enemy["id"]) or battle_time>=float(unit["flank_until"]):
        var sign_value: float=1.0 if lateral.dot(p-ep)>=0.0 else -1.0
        unit["flank_target"]=enemy["id"]
        unit["flank_goal"]=_field_point(ep+lateral*sign_value*155.0-ef*45.0)
        var maneuver_budget: float = 24.0
        if long_operation:
            # Wide-field travel and a committed bridge can exceed the old fixed timeout.
            var waypoint: Vector2 = unit["flank_goal"]
            var route_distance: float = p.distance_to(waypoint)
            if _river_separates(p,waypoint):
                route_distance += 260.0
            maneuver_budget = clampf(24.0 + route_distance / 18.0, 24.0, 80.0)
        unit["flank_until"]=battle_time+maneuver_budget
        unit["flank_phase"]=0
    if p.distance_to(unit["flank_goal"])<30.0 and int(unit["flank_phase"])==0:
        unit["flank_phase"]=1
        unit["flank_completed"]+=1
        if long_operation:
            # Waiting for the front line has a separate limited synchronization window.
            unit["flank_until"] = maxf(float(unit["flank_until"]),battle_time+30.0)
        _log(str(unit["name"])+": 협동 우회 지점 도달")
    if int(unit["flank_phase"])==1:
        var approach: Vector2=(p-ep).normalized()
        var angle_ok: bool=approach.dot(ef)<0.30
        var pinned_now: bool=formation_contacts(ally,enemy,30.0)>0 and not bool(ally["routed"])
        if not angle_ok:
            if long_operation:
                unit["flank_aborts"]+=1
                unit["flank_recovery"]=battle_time+15.0
                unit["flank_target"]=-1
            unit["flank_phase"]=0
            unit["flank_until"]=0.0
            return {"action":"협동 우회","reason":"적 방향 변화: 측면 위치 재확보","goal":p}
        if not pinned_now:
            return {"action":"협동 대기","reason":str(ally["name"])+"군 정면 접촉을 기다림","goal":p}
        if long_operation:
            unit["flank_phase"]=2
            unit["flank_commits"]+=1
            unit["flank_contact_at"]=battle_time
        return {"action":"돌파","reason":str(ally["name"])+"군 정면 압박에 맞춰 측후방 공격","goal":ep}
    return {"action":"협동 우회","reason":str(ally["name"])+"군과 협동 측면 기동","goal":unit["flank_goal"]}

func _tactical_target(unit: Dictionary,nearest: Dictionary) -> Dictionary:
    var p: Vector2=unit["pos"]
    var reach: float=173.0 if str(unit["type"])=="궁병" else 30.0
    var best: Dictionary=nearest
    var score_best: float=-INF
    for enemy in units:
        if int(enemy["side"])==int(unit["side"]) or float(enemy["troops"])<=0.0: continue
        var ep: Vector2=enemy["pos"]
        var d: float=p.distance_to(ep)
        var vision: float=AI_VISION_RANGE*(0.85+_effective_stat(unit,"intelligence")*0.002)
        if _in_forest(ep):
            vision*=0.68
            if float(enemy["ambush_ready"])>=3.0: vision*=0.48
        if terrain_at(p)=="고지": vision*=1.15
        if d>minf(vision,reach+100.0): continue
        var direction: Vector2=(p-ep).normalized()
        var flank: bool=direction.dot(enemy["facing"])<0.3
        var score: float=110.0-d*0.6+45.0*(tactical_matchup(unit,enemy,flank)-1.0)
        if not _physical_screen(enemy,unit).is_empty(): score-=35.0
        if str(enemy["next_formation"])!="": score+=12.0
        if score<=score_best: continue
        if long_operation and str(unit["type"])!="궁병" and _river_separates(p,ep): continue
        if formation_contacts(unit,enemy,reach)<=0: continue
        score_best=score
        best=enemy
    return best

func _valid_partner(unit: Dictionary,partner: int) -> bool:
    if partner==-1: return true
    var friend: Dictionary=find_unit(partner)
    return not friend.is_empty() and int(friend["id"])!=int(unit["id"]) and int(friend["side"])==int(unit["side"]) and float(friend["troops"])>0.0 and not bool(friend["routed"])

func _reset_cooperation(unit: Dictionary,partner: int) -> void:
    unit["assigned_link"]=partner
    unit["link_id"]=partner
    unit["flank_target"]=-1
    unit["flank_phase"]=0
    unit["flank_until"]=0.0
    unit["flank_recovery"]=0.0
    unit["flank_contact_at"]=-100.0

func _locally_observed(unit: Dictionary,enemy: Dictionary) -> bool:
    if int(unit["side"])==int(enemy["side"]) or float(enemy["troops"])<=0.0: return false
    var p: Vector2=unit["pos"]
    var ep: Vector2=enemy["pos"]
    var vision: float=AI_VISION_RANGE*(0.85+_effective_stat(unit,"intelligence")*0.002)
    if _in_forest(ep):
        vision*=0.68
        if float(enemy["ambush_ready"])>=3.0: vision*=0.48
    if terrain_at(p)=="고지": vision*=1.15
    return p.distance_to(ep)<=vision

# A real healthy infantry line must lie between a melee attacker and its
# archer target. Mere proximity never grants protection.
func _physical_screen(protected: Dictionary,attacker: Dictionary) -> Dictionary:
    if str(protected["type"])!="궁병" or str(attacker["type"])=="궁병": return {}
    var p: Vector2=protected["pos"]
    var a: Vector2=attacker["pos"]
    var axis: Vector2=p-a
    var length: float=axis.length()
    if length<25.0 or length>240.0: return {}
    var direction: Vector2=axis/length
    for guard in units:
        if int(guard["side"])!=int(protected["side"]) or str(guard["type"])!="보병" or bool(guard["routed"]) or float(guard["troops"])<600.0 or float(guard["cohesion"])<40.0: continue
        var offset: Vector2=(guard["pos"] as Vector2)-a
        var projection: float=offset.dot(direction)
        if projection<=5.0 or projection>=length-5.0: continue
        if absf(offset.dot(direction.orthogonal()))>42.0: continue
        if (guard["pos"] as Vector2).distance_to(p)>135.0: continue
        if formation_contacts(guard,attacker,30.0)<=0: continue
        return guard
    return {}

# Public map orders contain an intent, location and optional partner. Formation
# remains under the general's field judgment.
const MAP_MISSIONS = ["지정 위치 이동","공격","지역 사수","전열 엄호","측후방 기동","구원 지원","예비 대기","철수"]
func issue_map_order(id: int,mission: String,destination: Vector2,partner: int=-1) -> bool:
    if mission not in MAP_MISSIONS or finished or not Rect2(Vector2.ZERO,field_size).has_point(destination): return false
    if long_operation and terrain_at(destination)=="하천": return false
    var unit: Dictionary=find_unit(id)
    if unit.is_empty() or int(unit["side"])!=0 or float(unit["troops"])<=0.0 or not _valid_partner(unit,partner): return false
    if started: return request_order(id,mission,"현장 판단",partner,destination)
    if not select_unit_mission(id,mission,"현장 판단",partner): return false
    unit["has_destination"]=true
    unit["order_destination"]=_field_point(destination)
    unit["destination_reached"]=false
    unit["waypoints"].clear()
    unit["waypoint_index"]=0
    unit["defense_set"]=false
    GeneralMind.order(unit,"사전 작전: "+mission,battle_time)
    return true

func _destination_order(unit: Dictionary,enemy: Dictionary,action: String,reason: String,goal: Vector2,distance: float) -> Dictionary:
    var original: Dictionary={"action":action,"reason":reason,"goal":goal}
    if not bool(unit.get("has_destination",false)): return original
    if action in ["패주","후퇴","재집결","휴식","탄약 보충","보급 복귀"]: return original
    var p: Vector2=unit["pos"]
    var dest: Vector2=unit["order_destination"]
    var mission: String=unit["mission"]
    if mission=="철수": return {"action":"전술 철수","reason":"책사의 철수 지시","goal":dest}
    if p.distance_to(dest)<=65.0: unit["destination_reached"]=true
    if not bool(unit["destination_reached"]):
        if distance<85.0 and action in ["거리 유지","측면 방어","교전","돌파","방어"]: return original
        return {"action":"지정 위치 이동","reason":"책사가 지정한 작전 지역으로 이동","goal":dest}
    if mission in ["지역 사수","예비 대기","지정 위치 이동"]:
        return {"action":"예비 대기" if mission=="예비 대기" else "지정 지역 사수","reason":"지정 지역 확보 및 현장 판단","goal":dest if p.distance_to(dest)>55.0 else p}
    if mission=="공격":
        if not enemy.is_empty() and (enemy["pos"] as Vector2).distance_to(dest)<240.0:
            return {"action":"돌파" if str(unit["type"])=="기병" else "교전","reason":"지정 지역 적군 공격","goal":enemy["pos"]}
        return {"action":"지정 지역 사수","reason":"목표 지역 장악","goal":dest if p.distance_to(dest)>55.0 else p}
    return original

# The engine retains its tested fixed-step model. At normal playback the live
# game consumes one model second per four operation seconds. Legacy fixtures
# stay at their original scale and can explicitly opt into long operations.
func set_long_operation(enabled: bool) -> void:
    long_operation=enabled
    if enabled:
        six_armies=true
        wide_field=true
    reset()

func operation_scale() -> float:
    return OPERATION_SCALE if long_operation else 1.0

func operation_elapsed() -> float:
    return battle_time*operation_scale()

func operation_limit() -> float:
    return scenario_limit*operation_scale()

func capture_duration() -> float:
    return 15.0 if long_operation else OUTPOST_CAPTURE_SECONDS

func operation_phase() -> String:
    var seconds: float=operation_elapsed()
    if seconds<240.0: return "정찰 · 행군"
    if seconds<540.0: return "초기 교전"
    if seconds<960.0: return "본격 교전"
    if seconds<1320.0: return "전황 변화"
    return "결전"

func _operational_armies(side: int) -> int:
    var count: int=0
    for unit in units:
        if int(unit["side"])==side and float(unit["troops"])>0.0 and not bool(unit["routed"]): count+=1
    return count

# Red command uses observations shared by the actual nearby anchor and wing,
# never the player's hidden orders or undiscovered enemy positions.
func _observed_threat_to(observer:Dictionary,ally:Dictionary)->Dictionary:
    var best:Dictionary={}
    var score:float=220.0
    for foe in units:
        if not _locally_observed(observer,foe) or bool(foe["routed"]): continue
        if str(foe["type"])=="궁병": continue
        var d:float=(ally["pos"] as Vector2).distance_to(foe["pos"])
        if d<score:
            score=d
            best=foe
    return best

func _enemy_strategy()->void:
    if scenario_id in [2,3]: return
    for unit in units:
        if int(unit["side"])!=1 or float(unit["troops"])<600.0 or bool(unit["routed"]) or bool(unit["reserve"]) or str(unit["mission"])=="본진 방어": continue
        if float(unit["morale"])<40.0 or float(unit["cohesion"])<35.0 or float(unit["rations"])<20.0:
            unit["ai_role_until"]=0.0
            continue
        var old_role:String=str(unit["ai_role"])
        var old_partner:int=int(unit["ai_partner"])
        var role:String=""
        var partner:int=-1
        var best:float=INF
        var p:Vector2=unit["pos"]
        for ally in units:
            if int(ally["side"])!=1 or int(ally["id"])==int(unit["id"]) or float(ally["troops"])<600.0 or bool(ally["routed"]) or str(ally["mission"])=="본진 방어": continue
            var distance:float=p.distance_to(ally["pos"])
            if distance>310.0: continue
            var threat:Dictionary=_observed_threat_to(unit,ally)
            var candidate:String=""
            if str(unit["type"])=="보병" and str(ally["type"])=="궁병" and not threat.is_empty() and str(threat["type"])=="기병":
                candidate="궁병 보호"
            elif str(unit["type"])=="궁병" and str(ally["type"])=="보병" and not threat.is_empty() and float(ally["cohesion"])>35.0:
                candidate="전열 엄호"
            elif str(unit["type"])=="기병" and str(ally["type"])=="보병" and not threat.is_empty() and terrain_at(p) not in ["숲","하천","교량"]:
                if formation_contacts(ally,threat,30.0)>0 and float(unit["morale"])>55.0:
                    candidate="측후방 기동"
            if candidate=="" or (str(ally.get("ai_role",""))=="궁병 보호" and candidate=="전열 엄호"): continue
            var score:float=distance-float(ally["front_pressure"])*90.0
            if old_role==candidate and old_partner==int(ally["id"]): score-=80.0
            if score<best:
                best=score
                role=candidate
                partner=int(ally["id"])
        if role=="":
            if battle_time>=float(unit["ai_role_until"]):
                unit["ai_role"]=""
                unit["ai_partner"]=-1
            continue
        if old_role!=role or old_partner!=partner:
            unit["ai_replans"]+=1
            enemy_replans+=1
            unit["flank_target"]=-1
            unit["flank_phase"]=0
            unit["flank_until"]=0.0
            unit["ai_cooldown"]=0.0
        unit["ai_role"]=role
        unit["ai_partner"]=partner
        unit["ai_role_until"]=battle_time+20.0

# One bridge is selected and retained until the army reaches the far bank.
# Route choice accounts for allied congestion without reading hidden enemies.
func _committed_bridge_route(unit:Dictionary,p:Vector2,goal:Vector2)->Vector2:
    var bank:int=1 if p.x>=river_x(p.y) else -1
    var target_bank:int=1 if goal.x>=river_x(goal.y) else -1
    var distance:float=absf(p.x-river_x(p.y))
    var chosen:float=float(unit["bridge_y"])
    if chosen>=0.0:
        var exit_bank:int=int(unit["bridge_bank"])
        if bank==exit_bank and distance>=55.0:
            unit["bridge_y"]=-1.0
            unit["bridge_bank"]=0
            unit["bridge_crossings"]+=1
            chosen=-1.0
        elif distance<38.0 or target_bank==exit_bank:
            var rx:float=river_x(chosen)
            if bank!=exit_bank and absf(p.y-chosen)>10.0 and distance>=35.0:
                return Vector2(rx-exit_bank*64.0,chosen)
            return Vector2(rx+exit_bank*64.0,chosen)
        else:
            unit["bridge_y"]=-1.0
            unit["bridge_bank"]=0
            chosen=-1.0
    if bank==target_bank:
        if terrain_at(goal)=="하천": return Vector2(river_x(goal.y)+bank*34.0,goal.y)
        return goal
    var best:float=INF
    for y in [390.0,850.0,1300.0]:
        var crossing:=Vector2(river_x(y),y)
        var cost:float=p.distance_to(crossing)+crossing.distance_to(goal)
        for other in units:
            if int(other["id"])==int(unit["id"]) or int(other["side"])!=int(unit["side"]) or float(other["troops"])<=0.0: continue
            if absf(float(other.get("bridge_y",-1.0))-y)<1.0:
                cost+=90.0
        if cost<best:
            best=cost
            chosen=y
    unit["bridge_y"]=chosen
    unit["bridge_bank"]=target_bank
    var rx:float=river_x(chosen)
    return Vector2(rx+bank*64.0,chosen) if absf(p.y-chosen)>10.0 else Vector2(rx+target_bank*64.0,chosen)

func _land_motion(unit:Dictionary,old:Vector2,proposed:Vector2)->Vector2:
    if terrain_at(proposed)!="하천" and not _river_separates(old,proposed): return proposed
    # A unit already displaced into water can escape, but cannot advance deeper.
    if terrain_at(old)=="하천" and absf(proposed.x-river_x(proposed.y))>absf(old.x-river_x(old.y)):
        return proposed
    unit["blocked_water_steps"]+=1
    var bank:float=1.0 if old.x>=river_x(old.y) else -1.0
    var slide:Vector2=_field_point(Vector2(river_x(proposed.y)+bank*maxf(28.0,absf(old.x-river_x(old.y))),proposed.y))
    var bounded:Vector2=old.move_toward(slide,old.distance_to(proposed))
    return bounded if terrain_at(bounded)!="하천" and not _river_separates(old,bounded) else old

# Opposing ground units cannot trade melee strikes over an unbridged channel.
func _river_separates(a:Vector2,b:Vector2)->bool:
    var bank_a:float=a.x-river_x(a.y)
    var bank_b:float=b.x-river_x(b.y)
    if bank_a*bank_b>=0.0: return false
    # Use the approximate intersection with the curving river, not just
    # the midpoint: unequal distances to the bank can bias the midpoint.
    var low:float=0.0
    var high:float=1.0
    for i in range(6):
        var t:float=(low+high)*0.5
        var mid:Vector2=a.lerp(b,t)
        if (mid.x-river_x(mid.y))*bank_a>0.0: low=t
        else: high=t
    return not near_crossing(a.lerp(b,(low+high)*0.5).y)

# Measure damage actually borne by an infantry screen, separately from
# hypothetical damage mitigation. Avoid counting any unrelated melee.
func _guarding_archer_in_contact(guard:Dictionary,attacker:Dictionary)->bool:
    if str(guard["type"])!="보병" or str(attacker["type"])=="궁병": return false
    for archer in units:
        if str(archer["type"])!="궁병" or int(archer["side"])!=int(guard["side"]) or float(archer["troops"])<=0.0 or bool(archer["routed"]): continue
        if (archer["pos"] as Vector2).distance_to(guard["pos"])>135.0: continue
        var screen:Dictionary=_physical_screen(archer,attacker)
        if not screen.is_empty() and int(screen["id"])==int(guard["id"]): return true
    return false

# Keep representative combat and visual soldiers on passable ground near
# the channel. Formation transitions must obey the same terrain constraint.
func _dry_formation_slot(center:Vector2,point:Vector2)->Vector2:
    var center_bank:float=center.x-river_x(center.y)
    if absf(center_bank)>150.0: return point
    var slot_bank:float=point.x-river_x(point.y)
    if absf(slot_bank)>=27.0 and center_bank*slot_bank>=0.0: return point
    if absf(center_bank)<36.0 and near_crossing(center.y):
        var crossing:float=390.0 if center.y<620.0 else (850.0 if center.y<1075.0 else 1300.0)
        return Vector2(point.x,clampf(point.y,crossing-34.0,crossing+34.0))
    if near_crossing(point.y): return point
    var bank:float=1.0 if center_bank>=0.0 else -1.0
    return Vector2(river_x(point.y)+bank*29.0,point.y)
