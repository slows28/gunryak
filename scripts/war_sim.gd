extends RefCounted
## Independent battle model: no UI nodes, textures, or rendering calls.
## Intentionally bounded fixed-step updates; safe for headless simulation tests.

const FIELD_W: float = 900.0
const FIELD_H: float = 570.0
const TURN_SECONDS: float = 18.0
const LAST_TURN: int = 10
const MAX_SECONDS: float = TURN_SECONDS * float(LAST_TURN)
const SUPPLY_RADIUS: float = 182.0
const AI_VISION_RANGE: float = 285.0
const MAX_TROOPS: float = 2000.0

var units: Array[Dictionary] = []
var bases: Array[Dictionary] = []
var commanders: Array[Dictionary] = []
var couriers: Array[Dictionary] = []
var events: Array[String] = []
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

func _init() -> void:
    reset()

func reset() -> void:
    units.clear()
    bases.clear()
    commanders.clear()
    couriers.clear()
    events.clear()
    rng.seed = 20261124
    next_id = 0
    battle_time = 0.0
    step_count = 0
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
    bases.append(_base(0, Vector2(116, 310)))
    bases.append(_base(1, Vector2(781, 310)))
    commanders.append({"side":0, "pos":Vector2(54, 515), "goal":Vector2(54, 515)})
    commanders.append({"side":1, "pos":Vector2(846, 515), "goal":Vector2(846, 515)})
    _log("출전 편성 준비: 장수별 목표와 진형 방침을 확인하세요.")

func _add_unit(side: int, title: String, unit_type: String, disposition: String, ability: float, start: Vector2, mission: String, people: float) -> void:
    var unit: Dictionary = {
        "id": next_id, "side": side, "name": title, "type": unit_type,
        "personality": disposition, "ability": ability,
        "pos": start, "facing": Vector2.RIGHT if side == 0 else Vector2.LEFT,
        "goal": start, "mission": mission,
        "policy": "현장 판단", "formation": "횡대", "next_formation": "",
        "form_remaining": 0.0, "troops": people, "initial_troops": people,
        "morale": 100.0, "out_supply": 0.0, "supplied": true,
        "action": "대기", "reason": "초기 배치", "ai_cooldown": 0.0,
        "charge": 0.0, "last_raid": -999.0, "contact_troops": 0,
        "front_pressure": 0.0, "pushed_distance": 0.0,
        "raid_active": false, "raid_target": Vector2.ZERO, "raid_until": 0.0
    }
    if unit_type == "기병":
        unit["formation"] = "종대"
    next_id += 1
    units.append(unit)

func _base(side: int, at: Vector2) -> Dictionary:
    return {
        "side":side, "pos":at, "target":at, "state":"가동",
        "build_timer":0.0, "last_relocate":-40.0, "alive":true
    }

func _log(message: String) -> void:
    events.append("[%02d턴] %s" % [turn, message])
    if events.size() > 24:
        events.pop_front()

func start() -> void:
    if started or finished:
        return
    started = true
    _log("전투 개시. 장수는 초기 작전에 따라 스스로 판단합니다.")

func select_unit_mission(unit_id: int, mission: String, policy: String) -> bool:
    if started:
        return false
    var unit: Dictionary = find_unit(unit_id)
    if unit.is_empty() or int(unit["side"]) != 0:
        return false
    unit["mission"] = mission
    unit["policy"] = policy
    if policy != "현장 판단":
        unit["formation"] = policy.replace(" 유지", "")
    return true

func find_unit(unit_id: int) -> Dictionary:
    for unit in units:
        if int(unit["id"]) == unit_id:
            return unit
    return {}

func request_order(unit_id: int, mission: String, policy: String) -> bool:
    if not started or finished or turn < 6:
        return false
    var unit: Dictionary = find_unit(unit_id)
    if unit.is_empty() or int(unit["side"]) != 0 or float(unit["troops"]) <= 0.0:
        return false
    # Limit unfinished courier orders; avoids accidental spam and runaway entities.
    for courier in couriers:
        if int(courier["unit_id"]) == unit_id:
            return false
    couriers.append({
        "pos":commanders[0]["pos"], "unit_id":unit_id,
        "mission":mission, "policy":policy
    })
    _log("전령 파견 → %s / %s" % [str(unit["name"]), mission])
    return true

func reposition_commander(forward: bool) -> void:
    if finished:
        return
    commanders[0]["goal"] = Vector2(270, 346) if forward else Vector2(54, 515)
    _log("책사 이동: %s" % ("전진 지휘" if forward else "본진 복귀"))

func step(dt: float) -> void:
    if not started or finished or paused:
        return
    dt = clampf(dt, 0.0, 0.1)
    if dt <= 0.0:
        return
    battle_time += dt
    step_count += 1
    var current_turn: int = int(floor(battle_time / TURN_SECONDS)) + 1
    if current_turn != turn:
        turn = current_turn
        _on_new_turn()
    _move_commanders(dt)
    _update_couriers(dt)
    _supply_logic(dt)
    # We use a shallow fixed unit pool and never mutate it during these loops.
    for unit in units:
        if float(unit["troops"]) <= 0.0:
            continue
        unit["ai_cooldown"] = float(unit["ai_cooldown"]) - dt
        if float(unit["ai_cooldown"]) <= 0.0:
            _decide(unit)
            unit["ai_cooldown"] = 1.7 + (100.0 - float(unit["ability"])) * 0.009
        _formation_transition(unit, dt)
    for unit in units:
        if float(unit["troops"]) > 0.0:
            _move_unit(unit, dt)
    _resolve_frontline(dt)
    _combat(dt)
    _check_victory()

func _on_new_turn() -> void:
    _log("작전 %d턴 진입" % turn)
    if turn == 6:
        _log("전령 명령 활성화 — 전달 시간은 책사 위치에서 계산")
    if turn % 2 == 0 and turn <= 4:
        # Reinforcements only at HQ: finite, bounded, and not generated from outposts.
        for side in range(2):
            if reinforcements_used[side] >= 2:
                continue
            reinforcements_used[side] += 1
            var x: float = 73.0 if side == 0 else 827.0
            var y: float = 275.0 + float(reinforcements_used[side] - 1) * 94.0
            _add_unit(side, "왕실 예비대 %d" % reinforcements_used[side] if side == 0 else "위군 예비대 %d" % reinforcements_used[side], "보병", "균형", 63.0, Vector2(x, y), "중앙 진격", 72.0)
        _log("양측 본진에 예비 보병 도착 (제한된 예비대)")

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
            couriers.remove_at(i)
            continue
        var p: Vector2 = letter["pos"]
        var target_pos: Vector2 = target["pos"]
        letter["pos"] = p.move_toward(target_pos, 140.0 * dt)
        if (letter["pos"] as Vector2).distance_to(target_pos) < 16.0:
            target["mission"] = str(letter["mission"])
            target["policy"] = str(letter["policy"])
            target["ai_cooldown"] = 0.0
            _log("%s: 전령 도착 / 새 명령 '%s'" % [str(target["name"]), str(letter["mission"])])
            couriers.remove_at(i)

func _supply_logic(dt: float) -> void:
    for base in bases:
        if not bool(base["alive"]):
            continue
        var side: int = int(base["side"])
        var bp: Vector2 = base["pos"]
        # An observed enemy unit close to an undefended base can disable it.
        for unit in units:
            if int(unit["side"]) != side and float(unit["troops"]) > 0.0:
                var ep: Vector2 = unit["pos"]
                if ep.distance_to(bp) < 22.0:
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
        elif battle_time - float(base["last_relocate"]) > 26.0:
            var desired: Vector2 = _best_supply_position(side)
            if bp.distance_to(desired) > 135.0:
                base["target"] = desired
                base["state"] = "이동"
                base["last_relocate"] = battle_time
                _log("%s 보급부대 전선 따라 이동" % ("아군" if side == 0 else "적군"))
    for unit in units:
        if float(unit["troops"]) <= 0.0:
            continue
        var provided: bool = _has_supply(int(unit["side"]), unit["pos"])
        unit["supplied"] = provided
        if provided:
            unit["out_supply"] = 0.0
        else:
            unit["out_supply"] = float(unit["out_supply"]) + dt
            if float(unit["out_supply"]) >= TURN_SECONDS * 3.0:
                unit["morale"] = maxf(0.0, float(unit["morale"]) - dt * 0.15)

func _has_supply(side: int, position: Vector2) -> bool:
    for base in bases:
        if int(base["side"]) == side and bool(base["alive"]) and str(base["state"]) == "가동":
            var bp: Vector2 = base["pos"]
            if bp.distance_to(position) <= SUPPLY_RADIUS:
                return true
    return false

func _best_supply_position(side: int) -> Vector2:
    var focus: Vector2 = Vector2(170, 275) if side == 0 else Vector2(730, 275)
    var strength: float = 0.0
    for unit in units:
        if int(unit["side"]) == side and float(unit["troops"]) > 0.0:
            focus += (unit["pos"] as Vector2) * (float(unit["troops"]) / 100.0)
            strength += float(unit["troops"]) / 100.0
    focus /= 1.0 + strength
    var direction: float = -1.0 if side == 0 else 1.0
    var suggested: Vector2 = Vector2(clampf(focus.x + 105.0 * direction, 75.0, FIELD_W - 75.0), clampf(focus.y, 95.0, FIELD_H - 75.0))
    var candidates: Array[Vector2] = [suggested, suggested + Vector2(0, -68), suggested + Vector2(0, 68)]
    var winning: Vector2 = suggested
    var best_score: float = -100000.0
    for candidate in candidates:
        candidate = _field_point(candidate)
        var score: float = 0.0
        for unit in units:
            if float(unit["troops"]) <= 0.0:
                continue
            var d: float = (unit["pos"] as Vector2).distance_to(candidate)
            if int(unit["side"]) == side:
                score += float(unit["troops"]) * (1.0 if d <= SUPPLY_RADIUS else 0.0)
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
    var nearest_distance: float = AI_VISION_RANGE
    var position: Vector2 = unit["pos"]
    for enemy in units:
        if int(enemy["side"]) == int(unit["side"]) or float(enemy["troops"]) <= 0.0:
            continue
        var distance: float = position.distance_to(enemy["pos"])
        if distance < nearest_distance:
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
    var personality: String = str(unit["personality"])
    var ability: float = float(unit["ability"])
    var troops: float = float(unit["troops"])
    var morale: float = float(unit["morale"])
    var goal: Vector2 = _mission_point(side, str(unit["mission"]))
    var action: String = "진격"
    var reason: String = "초기 목표를 향해 이동"
    var enemy_distance: float = 9999.0
    var relative_strength: float = 1.0
    if not nearest.is_empty():
        var epos: Vector2 = nearest["pos"]
        enemy_distance = pos.distance_to(epos)
        relative_strength = troops / maxf(20.0, float(nearest["troops"]))
    # Safety overrides: any personality can withdraw if its own formation collapses.
    if troops < 24.0 or morale < 19.0:
        action = "후퇴"
        reason = "붕괴 위험: 전선을 이탈하고 재집결"
        goal = Vector2(86, pos.y) if side == 0 else Vector2(815, pos.y)
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
    # Raids persist for a bounded mission window. Prior logic issued a raid,
    # then abandoned it at the very next ~2 s AI tick due to its cooldown.
    # The destination is the last OBSERVED base position, not omniscient tracking.
    var enemy_base: Dictionary = bases[1 - side]
    var raid_allowed: bool = personality == "공격" and ability > 60.0 and action != "후퇴"
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
    if enemy_distance < 150.0 and ability < 65.0 and not bool(unit["raid_active"]) and rng.randf() < 0.13:
        action = "진격" if personality != "신중" else "방어"
        reason = "불확실한 전황 판단으로 대응이 지연됨"
        goal = _mission_point(side, str(unit["mission"])) if action == "진격" else pos
    unit["action"] = action
    unit["reason"] = reason
    unit["goal"] = _field_point(goal)
    var wanted: String = "횡대"
    if action in ["후퇴", "기지 습격", "돌파"]:
        wanted = "종대"
    elif action == "방어":
        wanted = "방진"
    elif str(unit["type"]) == "기병":
        wanted = "종대"
    if str(unit["policy"]) != "현장 판단":
        wanted = str(unit["policy"]).replace(" 유지", "")
    # Cancel an obsolete re-formation order before it completes; otherwise
    # a later AI decision can apply a formation the general no longer wants.
    if wanted == str(unit["formation"]):
        unit["next_formation"] = ""
        unit["form_remaining"] = 0.0
    elif wanted != str(unit["next_formation"]):
        unit["next_formation"] = wanted
        unit["form_remaining"] = 2.1 + (100.0 - ability) * 0.014

func _mission_point(side: int, mission: String) -> Vector2:
    var x: float = 680.0 if side == 0 else 220.0
    match mission:
        "북측 확보": return Vector2(x, 145.0)
        "남측 우회": return Vector2(x, 432.0)
        "본진 방어": return Vector2(125.0, 285.0) if side == 0 else Vector2(775.0, 285.0)
        _: return Vector2(x, 287.0)

func _formation_transition(unit: Dictionary, dt: float) -> void:
    if str(unit["next_formation"]) == "":
        return
    unit["form_remaining"] = float(unit["form_remaining"]) - dt
    if float(unit["form_remaining"]) <= 0.0:
        unit["formation"] = str(unit["next_formation"])
        unit["next_formation"] = ""
        unit["form_remaining"] = 0.0

func _move_unit(unit: Dictionary, dt: float) -> void:
    var pos: Vector2 = unit["pos"]
    var goal: Vector2 = unit["goal"]
    var enemy: Dictionary = _nearest_visible_enemy(unit)
    if not enemy.is_empty() and str(unit["action"]) not in ["후퇴", "기지 습격", "방어", "거리 유지"]:
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
    if str(unit["next_formation"]) != "":
        rate *= 0.55
    if _in_forest(pos):
        rate *= 0.70
    if pos.distance_to(goal) > 2.0:
        var new_pos: Vector2 = pos.move_toward(goal, rate * dt)
        unit["pos"] = _field_point(new_pos)
        var moved: Vector2 = (unit["pos"] as Vector2) - pos
        if moved.length_squared() > 0.03:
            unit["facing"] = moved.normalized()
            if str(unit["type"]) == "기병":
                unit["charge"] = minf(50.0, float(unit["charge"]) + moved.length())
    if not enemy.is_empty() and pos.distance_to(enemy["pos"]) < 168.0:
        var front: Vector2 = (enemy["pos"] as Vector2) - (unit["pos"] as Vector2)
        if front.length_squared() > 1.0:
            unit["facing"] = (unit["facing"] as Vector2).lerp(front.normalized(), minf(1.0, dt * 2.0)).normalized()


# M2-1: Keep formation bodies separate. This applies to friends and enemies.
# M2-2: A contact line shifts toward the weaker side, based on the soldiers
# actually in each formation, morale and how well a unit resists front pressure.
func _body_distance(a: Dictionary, b: Dictionary) -> float:
    if str(a["type"]) == "궁병" or str(b["type"]) == "궁병":
        return 25.0
    return 34.0

func _frontline_power(unit: Dictionary, enemy: Dictionary, direction: Vector2) -> float:
    var factor: float = 1.0
    match str(unit["formation"]):
        "횡대": factor = 1.06
        "종대": factor = 0.77
        "방진": factor = 1.28
    if str(unit["type"]) == "기병":
        factor *= 1.16 if str(enemy["formation"]) != "방진" else 0.70
        if _in_forest(unit["pos"]):
            factor *= 0.70
    if str(unit["action"]) == "돌파":
        factor *= 1.12
    var facing: Vector2 = unit["facing"]
    if facing.length_squared() > 0.5 and facing.normalized().dot(direction) > 0.45:
        factor *= 1.06
    return maxf(1.0, float(unit["troops"]) * (0.25 + 0.75 * float(unit["morale"]) / 100.0) * factor)

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
                a["pos"] = _field_point(ap - direction * overlap * 0.5)
                b["pos"] = _field_point(bp + direction * overlap * 0.5)
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
            a["pos"] = _field_point((a["pos"] as Vector2) + direction * shift)
            b["pos"] = _field_point((b["pos"] as Vector2) + direction * shift)
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
    return Vector2(clampf(p.x, 18.0, FIELD_W - 18.0), clampf(p.y, 22.0, FIELD_H - 18.0))

func _in_forest(p: Vector2) -> bool:
    return Rect2(325, 80, 125, 90).has_point(p) or Rect2(450, 360, 130, 125).has_point(p)


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
    if (attacker["pos"] as Vector2).distance_to(defender["pos"]) > weapon_reach + 75.0:
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

func _combat(dt: float) -> void:
    # Precompute strikes before taking losses. Both sides resolve simultaneously.
    var damage_entries: Array[Dictionary] = []
    for unit in units:
        unit["contact_troops"] = 0
    for unit in units:
        if float(unit["troops"]) <= 0.0:
            continue
        var enemy: Dictionary = _nearest_visible_enemy(unit)
        if enemy.is_empty():
            continue
        var pos: Vector2 = unit["pos"]
        var ep: Vector2 = enemy["pos"]
        var distance: float = pos.distance_to(ep)
        var unit_type: String = str(unit["type"])
        var reach: float = 173.0 if unit_type == "궁병" else 30.0
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
            # Close fighting degrades bow effectiveness; cover blocks some shots.
            attack *= 0.55 if distance < 56.0 else 1.0
            if _in_forest(ep):
                attack *= 0.84
        else:
            # Physical contact frontage, not a free formation-specific stat buff.
            attack *= clampf(float(contacts) / 8.0, 0.35, 1.50)

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
        elif str(enemy["formation"]) == "종대" and (flank or rear):
            exposure *= 1.30
        if unit_type == "기병" and float(unit["charge"]) > 14.0 and distance < 70.0:
            # Formed squares physically resist mounted shock on contact.
            attack *= 0.68 if str(enemy["formation"]) == "방진" else 1.45
            unit["charge"] = 0.0

        var supply_factor: float = 0.76 if float(unit["out_supply"]) >= TURN_SECONDS * 3.0 else 1.0
        var damage: float = attack * (float(unit["troops"]) / maxf(1.0, float(unit["initial_troops"]))) * (float(unit["morale"]) / 100.0) * exposure * supply_factor * dt
        damage_entries.append({"target":int(enemy["id"]), "damage":maxf(0.0, damage), "flank":flank or rear})
    for entry in damage_entries:
        var defender: Dictionary = find_unit(int(entry["target"]))
        if defender.is_empty() or float(defender["troops"]) <= 0.0:
            continue
        defender["troops"] = maxf(0.0, float(defender["troops"]) - float(entry["damage"]))
        var morale_loss: float = 0.11 if bool(entry["flank"]) else 0.07
        defender["morale"] = maxf(0.0, float(defender["morale"]) - float(entry["damage"]) * morale_loss)
        if float(defender["troops"]) <= 0.0:
            _log("%s 전멸" % str(defender["name"]))

func _check_victory() -> void:
    for unit in units:
        if float(unit["troops"]) <= 0.0:
            continue
        var side: int = int(unit["side"])
        var unit_pos: Vector2 = unit["pos"]
        var enemy_commander: Dictionary = commanders[1 - side]
        if unit_pos.distance_to(enemy_commander["pos"]) < 26.0:
            var defended: bool = false
            for guard in units:
                if int(guard["side"]) == 1 - side and float(guard["troops"]) > 0.0:
                    if (guard["pos"] as Vector2).distance_to(enemy_commander["pos"]) < 76.0:
                        defended = true
                        break
            if not defended:
                _finish("책사 포획 성공 — 아군 승리" if side == 0 else "아군 책사 포획 — 패배")
                return
    var side_alive: Array[int] = [0, 0]
    for unit in units:
        if float(unit["troops"]) > 0.0:
            side_alive[int(unit["side"])] += 1
    if side_alive[0] == 0:
        _finish("아군 전투부대 전멸 — 패배")
    elif side_alive[1] == 0:
        _finish("적 전투부대 전멸 — 승리")
    elif battle_time >= MAX_SECONDS:
        var blue: float = 0.0
        var red: float = 0.0
        for unit in units:
            if int(unit["side"]) == 0:
                blue += float(unit["troops"])
            else:
                red += float(unit["troops"])
        _finish("시간 종료 — 전력 우세: %s" % ("아군" if blue >= red else "적군"))

func _finish(msg: String) -> void:
    if finished:
        return
    result = msg
    finished = true
    _log("전투 종료: %s" % msg)

func validate_state() -> Array[String]:
    var problems: Array[String] = []
    if is_nan(battle_time) or is_inf(battle_time) or battle_time < 0.0:
        problems.append("invalid elapsed time")
    if units.size() > 16:
        problems.append("unit pool exceeds bounded demo limit")
    for unit in units:
        var p: Vector2 = unit["pos"]
        if is_nan(p.x) or is_nan(p.y) or is_inf(p.x) or is_inf(p.y):
            problems.append("unit position is not finite: %s" % str(unit["name"]))
        elif p.x < 0.0 or p.x > FIELD_W or p.y < 0.0 or p.y > FIELD_H:
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
