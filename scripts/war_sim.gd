extends RefCounted
const FormationDrill = preload("res://scripts/formation_drill.gd")
## Independent battle model: no UI nodes, textures, or rendering calls.
## Intentionally bounded fixed-step updates; safe for headless simulation tests.

const FieldJudgment = preload("res://scripts/field_judgment.gd")
const RallyOrders = preload("res://scripts/rally_orders.gd")
const MountedVanguard = preload("res://scripts/mounted_vanguard.gd")
const BreakContact = preload("res://scripts/break_contact.gd")
const LinkedMarch = preload("res://scripts/linked_march.gd")
const GeneralMind = preload("res://scripts/general_mind.gd")
const FieldGeometry=preload("res://scripts/field_geometry.gd")
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
signal messenger_arrived(report_id: int, sender: String, message: String)

const COURIER_TURN: int = 5
const TURN_SECONDS: float = 18.0
const LAST_TURN: int = 10
const MAX_SECONDS: float = TURN_SECONDS * float(LAST_TURN)
const BASE_BUILD_SECONDS: float = 3.0
const RAID_SECONDS: float = 6.0
const HQ_CAPTURE_SECONDS: float = 12.0
const RAID_RADIUS: float = 46.0
const GUARD_RADIUS: float = 76.0
const HQ_APPROACH_RADIUS: float = 280.0
var next_supply_survey: float=0.0
const MARCH_LEG := 320.0
const MORALE_NEWS_DISTANCE := 280.0
const Skills=preload("res://scripts/field_skills.gd")
const NorthernField=preload("res://scripts/northern_field.gd")
var chapter: Dictionary={}
const FIELD_CORPS := 10
const LOSSES_PER_FALLEN := 65
var fallen_marks: Array[Dictionary] = []
var terrain_posts: Array[Dictionary] = []
const AI_VISION_RANGE: float = 285.0
const MAX_TROOPS: float = 5000.0
const ARMY_SCALE: float = 32.0
const LARGE_FORMATIONS = ["횡대","종대","방진","어린진","학익진","봉시진","안행진"]
const OUTPOST_RADIUS: float = 58.0
const OUTPOST_CAPTURE_SECONDS: float = 7.0
const OUTPOST_HOLD_SECONDS: float = 8.0

var units: Array[Dictionary] = []
var supply_crews: Array[Dictionary] = []
var bases: Array[Dictionary] = []
var headquarters: Array[Dictionary] = []
var temporary_sites: Array[Dictionary] = []
const HQ_MOVE_INTERVAL := 5
var next_hq_day := HQ_MOVE_INTERVAL
var commanders: Array[Dictionary] = []
var couriers: Array[Dictionary] = []
var events: Array[String] = []
var field_notices: Array[Dictionary]=[]
var notice_sequence:=0
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
var incoming_reports: Array[Dictionary] = []
var relief_riders: Array[Dictionary]=[]
var situation_serial: int = 0
var urgent_deliveries:=0
var tactical_delivered: int = 0
var tactical_refused: int = 0
var last_situation_scan: float = -5.0
const TRAINING_SCENARIO = FieldGeometry.TRAINING_SCENARIO
var scenario_id: int = 0
var scenario_title: String = "북남 요충지"
var scenario_goal: String = "두 요충지를 동시에 점령하고 유지"
var scenario_limit: float = MAX_SECONDS
var forests: Array[Rect2] = []
var marshes: Array = []
var reedbeds: Array = []
var hill: Rect2 = Rect2(400, 213, 108, 89)
var timeline: Array[Dictionary] = []
var visual_effects: Array[Dictionary] = []
var front_shifts: Dictionary = {}
var combat_contacts: Dictionary = {}
var rear_responses: Dictionary = {}
var combat_history: Array[Dictionary] = []
const COMBAT_HISTORY_SECONDS: float = 2.0
var dust_effects: Array[Dictionary] = []
const DUST_LIFE: float = 1.8
const DUST_LIMIT: int = 420
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
var result_detail: String = ""
var next_id: int = 0
var reinforcements_used: Array[int] = [0, 0]
var step_count: int = 0
var intercepted_orders: int = 0
var delivered_orders: int = 0
var map_dispatches: Dictionary = {}
var march_plans: Dictionary = {}
var march_sequence: int = 0

func _init() -> void:
    reset()

func reset() -> void:
    chapter.clear()
    timeline.clear()
    structures.clear()
    visual_effects.clear()
    front_shifts.clear()
    combat_contacts.clear()
    rear_responses.clear()
    fallen_marks.clear()
    combat_history.clear()
    dust_effects.clear()
    troop_history.clear()
    sample_at = 0.0
    mind_sample_at=0.0
    pending_reports.clear()
    units.clear()
    bases.clear()
    next_supply_survey=0.0
    commanders.clear()
    couriers.clear()
    map_dispatches.clear()
    march_plans.clear()
    march_sequence=0
    events.clear()
    field_notices.clear()
    notice_sequence=0
    outposts.clear()
    temporary_sites.clear()
    next_hq_day = HQ_MOVE_INTERVAL
    scouts.clear()
    intelligence = [{}, {}]
    reserve_next = [18.0, 18.0]
    reserve_limit = [2,2]
    winning_side = -1
    convoy.clear()
    command_points = 3
    situation_reports.clear()
    incoming_reports.clear()
    relief_riders.clear()
    situation_keys.clear()
    situation_serial = 0
    urgent_deliveries=0
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
    result_detail = ""
    reinforcements_used = [0, 0]
    _add_unit(0, "왕평", "보병", "신중", 86.0, Vector2(130, 153), "북측 확보", 145.0)
    _add_unit(0, "마속", "궁병", "균형", 55.0, Vector2(105, 278), "중앙 진격", 108.0)
    _add_unit(0, "위연", "기병", "공격", 79.0, Vector2(133, 431), "남측 우회", 95.0)
    _add_unit(1, "장합", "보병", "신중", 86.0, Vector2(760, 158), "북측 확보", 152.0)
    _add_unit(1, "손례", "궁병", "균형", 65.0, Vector2(787, 294), "중앙 진격", 102.0)
    _add_unit(1, "대릉", "기병", "공격", 66.0, Vector2(755, 437), "남측 우회", 96.0)
    if six_armies:
        _add_unit(0,"강유","궁병","균형",83.0,Vector2(175,215),"북측 확보",120.0)
        _add_unit(0,"관흥","기병","공격",78.0,Vector2(180,375),"남측 우회",110.0)
        _add_unit(0,"장익","보병","신중",82.0,Vector2(80,360),"본진 방어",135.0)
        _add_unit(1,"곽회","보병","신중",83.0,Vector2(715,220),"북측 확보",125.0)
        _add_unit(1,"비요","기병","공격",76.0,Vector2(720,375),"남측 우회",110.0)
        _add_unit(1,"왕쌍","보병","균형",80.0,Vector2(820,360),"본진 방어",135.0)
        _add_unit(0,"장포","보병","공격",79.0,Vector2(116,64),"북측 확보",3900)
        _add_unit(0,"진도","보병","신중",80.0,Vector2(65,211),"중앙 진격",3700)
        _add_unit(0,"등지","궁병","균형",77.0,Vector2(74,462),"남측 우회",3400)
        _add_unit(0,"오반","기병","공격",78.0,Vector2(182,501),"남측 우회",3500)
        _add_unit(1,"문빙","보병","신중",80.0,Vector2(786,64),"북측 확보",4000)
        _add_unit(1,"서황","보병","공격",82.0,Vector2(834,212),"중앙 진격",3800)
        _add_unit(1,"학소","궁병","신중",79.0,Vector2(826,462),"남측 우회",3500)
        _add_unit(1,"조진","기병","균형",79.0,Vector2(718,501),"남측 우회",3600)
        reserve_limit = [1,1]
        var manpower: Array[int] = [4500,3500,3200,4800,3300,3200,4000,3800,4500,4100,3600,4200,3900,3700,3400,3500,4000,3800,3500,3600]
        var shapes: Array[String] = ["방진","안행진","봉시진","어린진","안행진","봉시진","학익진","어린진","방진","학익진","봉시진","방진","방진","어린진","안행진","봉시진","방진","어린진","안행진","봉시진"]
        for i in range(units.size()):
            if long_operation and scenario_id in [0, 1, 2, 3] and units[i]["side"] == 1:
                manpower[i] = mini(int(MAX_TROOPS), manpower[i] + 600)
            units[i]["troops"] = float(manpower[i])
            units[i]["initial_troops"] = float(manpower[i])
            units[i]["formation"] = shapes[i]
            units[i]["policy"] = "현장 판단"
    outposts.append({"name":"북측 접근로", "pos":Vector2(435, 148), "owner":-1, "challenger":-1, "progress":0.0, "hold":0.0})
    outposts.append({"name":"남측 접근로", "pos":Vector2(470, 423), "owner":-1, "challenger":-1, "progress":0.0, "hold":0.0})
    bases.append(_base(0, Vector2(116, 310)))
    bases.append(_base(1, Vector2(781, 310)))
    scouts.append({"side":0, "pos":Vector2(145, 230), "goal":Vector2(375, 120), "leg":0, "alive":true, "report_timer":0.0, "reports":0})
    scouts.append({"side":1, "pos":Vector2(755, 340), "goal":Vector2(525, 440), "leg":0, "alive":true, "report_timer":0.0, "reports":0})
    _configure_scenario()
    _configure_structures()
    _expand_layout()
    _map_terrain_posts()
    supply_crews.clear()
    headquarters.clear()
    for side in range(2):
        var home := layout_point(Vector2(65,285) if side == 0 else Vector2(835,285))
        headquarters.append({"side":side,"pos":home,"occupation":0.0,"occupied":false})
        commanders.append({"side":side,"pos":home,"goal":home})
        var origin: Vector2=bases[side]["pos"]
        supply_crews.append({"side":side,"pos":origin,"goal":origin,"state":"대기","strength":100.0,
            "id":-2-side,"type":"보병","bridge_y":-1.0,"bridge_bank":0,"bridge_crossings":0,"blocked_water_steps":0})
    for unit in units:
        if unit["mission"] == "본진 방어" and unit["defense_set"]:
            unit["hq_defense_offset"] = Vector2(unit["defense_anchor"]) - _home_point(unit["side"])
    _log("출전 편성 준비: " + scenario_title)

func _add_unit(side: int, title: String, unit_type: String, disposition: String, ability: float, start: Vector2, mission: String, people: float) -> void:
    var unit: Dictionary = {
        "id": next_id, "side": side, "name": title, "type": unit_type,
        "personality": disposition, "ability": ability,
        "pos": start, "facing": Vector2.RIGHT if side == 0 else Vector2.LEFT,
        "goal": start, "mission": mission,
        "policy": "현장 판단", "formation": "횡대", "next_formation": "",
        "form_remaining": 0.0, "form_duration": 1.0, "motion_speed": 0.0, "stride_step": 0.0, "stride_distance": 0.0, "walking_step": Vector2.ZERO, "dust_distance": 0.0, "troops": people, "initial_troops": people,
        "morale": 100.0, "out_supply": 0.0, "supplied": true,
        "action": "대기", "reason": "초기 배치", "ai_cooldown": 0.0,
        "contact_target_id":-1, "brace_stops":0, "rear_losses":0.0, "last_arrow_hit":-100.0,
        "charge": 0.0, "last_raid": -999.0, "contact_troops": 0,
        "front_pressure": 0.0, "pushed_distance": 0.0,
        "decisions": 0, "reforms_completed": 0, "damage_dealt": 0.0,
        "casualties_taken": 0.0, "supply_guard_time": 0.0,
        "supply_mark":start, "raid_active": false, "raid_base": -1, "raid_target": Vector2.ZERO, "raid_until": 0.0,
        "fatigue": 0.0, "cohesion": 100.0, "rations": 100.0, "ammo": 100.0,
        "rallying": false, "last_morale_event": -100.0, "objective_time": 0.0,
        "flank_hits": 0.0, "shots_used": 0.0, "last_supply_warning": -100.0,
        "leadership":ability, "martial":ability, "intelligence":ability, "judgment":ability, "loyalty":75.0,
        "obedience":"성향 기반", "deviations":0, "last_deviation":-100.0,
        "memory_pos":Vector2.ZERO, "memory_time":-100.0, "memory_id":-1,
        "ambush_ready":0.0, "ambush_until":-1.0, "ambushes":0,
        "charge_dir":Vector2.ZERO, "charge_speed":0.0, "charge_cooldown":0.0, "charges":0, "charge_recoil":Vector2.ZERO,
        "surrounded":false, "encircled_time":0.0, "routed":false, "rout_count":0, "deserted":0.0,
        "general_hp":100.0, "general_state":"건재", "general_risk":0.0, "reserve":false,
        "waypoints":[], "waypoint_index":0, "defense_anchor":Vector2.ZERO, "defense_set":false,
        "deputy_index":0, "active_deputy":false, "last_timeline_action":"대기", "last_visual":-100.0, "last_hit":-100.0, "structure_damage":0.0, "tactical_order":"", "tactical_target":-1, "tactical_anchor":start, "tactical_until":0.0, "initiative_until":0.0, "link_id":-1, "assigned_link":-1, "order_destination":Vector2.ZERO, "has_destination":false, "destination_reached":false, "flank_target":-1, "flank_goal":Vector2.ZERO, "flank_until":0.0, "flank_phase":0, "linked_hits":0.0, "counter_damage":0.0, "flank_damage":0.0, "maneuver_distance":0.0, "support_seconds":0.0, "flank_completed":0, "screened_damage":0.0, "screen_events":0, "ai_role":"", "ai_partner":-1, "ai_role_until":0.0, "ai_replans":0, "bridge_y":-1.0, "bridge_bank":0, "bridge_crossings":0, "blocked_water_steps":0, "guard_intercept_damage":0.0, "guard_intercept_ticks":0, "flank_commits":0, "flank_aborts":0, "flank_recovery":0.0, "flank_contact_at":-100.0
    }
    _set_general_profile(unit)
    unit["mind"]=GeneralMind.initial(unit)
    if unit_type == "기병":
        unit["formation"] = "종대"
    next_id += 1
    units.append(unit)

func _base(side: int, at: Vector2) -> Dictionary:
    return {
        "side":side, "pos":at, "state":"가동",
        "build_timer":0.0, "alive":true, "raid_work":0.0, "raid_rate":0, "raid_elapsed":0.0
    }

func _field_notice(message: String, point: Vector2, unit_id: int=-1) -> void:
    notice_sequence+=1
    field_notices.append({"key":"news:%d" % notice_sequence,"label":message,"point":point,"time":operation_elapsed(),"unit_id":unit_id})
    if field_notices.size()>80: field_notices.pop_front()
    _log(message)

func _site_notice(side: int, message: String, point: Vector2) -> void:
    if side==0 or player_can_see(point): _field_notice(message,point)
    else: _log(message)

func _log(message: String) -> void:
    events.append("[%02d일차] %s" % [turn, message])
    if timeline.size() < 1200:
        timeline.append({"time":battle_time,"turn":turn,"message":message})
    if events.size() > 24:
        events.pop_front()

func start() -> void:
    if started or finished:
        return
    if wide_field and not six_armies:
        _deploy_detachments()
    for crew in supply_crews:
        crew["pos"]=bases[crew["side"]]["pos"]
        crew["goal"]=crew["pos"]
    if bases[0]["state"]=="착공 예정":
        supply_crews[0]["state"]="구축"
        bases[0]["state"]="설치"
        bases[0]["build_timer"]=BASE_BUILD_SECONDS
    if long_operation: _pair_opening_ranks()
    for unit in units: unit["supply_mark"]=unit["pos"]
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
    if unit.erase("rally_origin"): RallyOrders.refresh(self)
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
    if not started or finished or turn < COURIER_TURN or commander_captured(0):
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

func step(dt: float) -> void:
    if not started or finished or paused:
        return
    dt = clampf(dt, 0.0, 0.1)
    if dt <= 0.0:
        return
    battle_time += dt
    step_count += 1
    var current_turn: int = int(floor(battle_time / turn_duration())) + 1
    if current_turn != turn:
        turn = current_turn
        _on_new_turn()
    _update_command_recovery()
    _update_scouts(dt)
    _deliver_intel()
    _update_reserves()
    _update_couriers(dt)
    _supply_logic(dt)
    if long_operation and battle_time>=next_enemy_strategy:
        next_enemy_strategy=battle_time+8.0
        if enemy_strategy_enabled and not commander_captured(1): _enemy_strategy()
        if not commander_captured(0): _plan_local_roles(0)
    # We use a shallow fixed unit pool and never mutate it during these loops.
    for unit in units:
        if float(unit["troops"]) <= 0.0:
            if unit.erase("rally_origin"): RallyOrders.refresh(self)
            continue
        if unit.has("skill_ids"): Skills.tick(self,unit)
        _update_general_conditions(unit, dt)
        unit["ai_cooldown"] = float(unit["ai_cooldown"]) - dt
        if float(unit["ai_cooldown"]) <= 0.0:
            _decide(unit)
            unit["ai_cooldown"] = 1.4 + (100.0 - _effective_stat(unit, "judgment")) * 0.015
        _formation_transition(unit, dt)
    if six_armies: march_plans=LinkedMarch.plan(self,march_plans,dt)
    var departures: Dictionary = {}
    for unit in units:
        if float(unit["troops"]) > 0.0:
            departures[unit["id"]] = unit["pos"]
            _move_unit(unit, dt)
    _resolve_frontline(dt)
    # Count ground actually gained by the feet. A line can stop or push a body
    # after its movement order has been executed.
    for unit in units:
        if not departures.has(unit["id"]): continue
        var start: Vector2 = departures[unit["id"]]
        var walking: Vector2 = unit["walking_step"]
        var net: Vector2 = unit["pos"] - start
        var walked := clampf(net.dot(walking.normalized()), 0.0, walking.length())
        if unit.get("skill_step_share",0.0)>0.0:
            unit["field_skill"]["stat"]["effect"]+=walked*unit["skill_step_share"]
        unit["stride_step"] = walked
        unit["stride_distance"] += walked
        if six_armies: _emit_march_dust(unit, start, walking.normalized() * walked)
    _update_structures(dt)
    _update_convoy(dt)
    _update_battle_condition(dt)
    _combat(dt)
    _update_outposts(dt)
    _update_headquarters(dt)
    if tactical_enabled:
        _move_reporting_messengers(dt)
        _move_relief_riders(dt)
        _scan_situations()
    _check_victory()
    if battle_time>=mind_sample_at or finished:
        mind_sample_at=battle_time+0.25
        for u in units:
            if not u.has("parent_id"): u["mind"]=GeneralMind.update(u,battle_time)
        _update_response_outcomes()
    _record_presentation()

func _on_new_turn() -> void:
    _log("작전 %d일차 진입" % turn)
    if turn == COURIER_TURN and not commander_captured(0):
        _log("전령 명령 활성화 — 전달 시간은 책사 위치에서 계산")
    if tactical_enabled and turn >= COURIER_TURN and not commander_captured(0):
        command_points = mini(4,command_points+1)

func _update_couriers(dt: float) -> void:
    for i in range(couriers.size() - 1, -1, -1):
        var letter: Dictionary = couriers[i]
        var target: Dictionary = find_unit(int(letter["unit_id"]))
        if target.is_empty() or float(target["troops"]) <= 0.0:
            _resolve_map_dispatch(letter,"수신 부대 상실")
            _response_delivery(letter,"수신 부대 상실")
            couriers.remove_at(i)
            continue
        var p: Vector2 = letter["pos"]
        var target_pos: Vector2 = target["pos"]
        var arrived: bool
        if letter.has("reply_id") or letter.get("reply_support",false):
            arrived = _advance_rider(letter,target_pos,dt)
        else:
            var route_goal: Vector2 = _courier_route(letter, target_pos)
            letter["pos"] = p.move_toward(route_goal, 140.0 * dt)
            arrived = (letter["pos"] as Vector2).distance_to(target_pos) < 16.0
        if _courier_intercepted(letter):
            intercepted_orders += 1
            _resolve_map_dispatch(letter,"차단")
            _response_delivery(letter,"전령 차단")
            _site_notice(letter["side"],"%s에게 가던 전령이 차단됨" % str(target["name"]),letter["pos"])
            couriers.remove_at(i)
            continue
        if arrived:
            delivered_orders += 1
            if letter.has("verdict"):
                _response_delivery(letter,"회신 도착")
                GeneralMind.order(target,letter["verdict"]+" 회신 수령",battle_time)
                if not letter.has("tactical_order"):
                    couriers.remove_at(i)
                    continue
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
            if target["mission"]=="자유 재량":
                target["tactical_order"]=""
                target["tactical_until"]=0.0
                target["initiative_until"]=0.0
            var partner: int=int(letter.get("partner",-1))
            _reset_cooperation(target,partner if _valid_partner(target,partner) else -1)
            _apply_policy(target, str(letter["policy"]))
            target["waypoints"].clear()
            target["waypoint_index"] = 0
            target["defense_set"] = false
            var destination: Vector2=letter.get("destination",Vector2(-1,-1))
            if target["mission"]=="본진 방어" and letter.get("map_dispatch",false):
                destination=_home_point(target["side"])
            target["has_destination"]=destination.x>=0.0 and destination.y>=0.0
            target["order_destination"]=_field_point(destination) if bool(target["has_destination"]) else Vector2.ZERO
            target["destination_reached"]=false
            _received_rally_pin(target,letter.get("map_dispatch",false))
            target["ai_cooldown"] = 0.0
            GeneralMind.order(target,"수령: "+str(letter["mission"]),battle_time)
            _resolve_map_dispatch(letter,"도착")
            _site_notice(letter["side"],"%s · 전령 도착 / %s" % [target["name"],letter["mission"]],target["pos"])
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
    if started:
        for crew in supply_crews: _update_supply_crew(crew,dt)
    for base in bases:
        if not base["alive"]: continue
        _update_base_raid(base,dt)
        if not base["alive"]: continue
        if base["state"]=="설치":
            var crew: Dictionary=supply_crews[base["side"]]
            if crew["state"]!="구축" or not (crew["pos"] as Vector2).is_equal_approx(base["pos"]): continue
            base["build_timer"]=maxf(0.0,float(base["build_timer"])-dt)
            if base["build_timer"]<0.00001:
                base["build_timer"]=0.0
                base["state"]="가동"
                crew["state"]="대기"
                if base.get("forward",false):
                    for unit in units:
                        if unit["side"]==base["side"] and Vector2(unit["pos"]).distance_to(base["pos"])<=MARCH_LEG:
                            unit["supply_mark"]=base["pos"]
                _morale_news(base["side"],base["pos"],14.0,"보급기지 완공")
                _site_notice(base["side"],_camp_side(base["side"])+" 보급기지 완공 · 배급 시작, 인근 사기 회복",base["pos"])
    if started and battle_time>=next_supply_survey:
        next_supply_survey=battle_time+1.0
        for side in range(2): _extend_supply(side)
    for unit in units:
        if unit["troops"]<=0: continue
        _deliver_rations(unit,dt)
        for base in bases:
            if base["side"]==unit["side"] and base["alive"] and (unit["pos"] as Vector2).distance_squared_to(base["pos"])<75.0*75.0:
                unit["supply_guard_time"]+=dt
                break

func _camp_side(side: int) -> String:
    return "아군" if side==0 else "적군"

# The corps can still be seen and struck while it rests or is disordered.
func _can_attack_troops(unit: Dictionary) -> bool:
    return unit["troops"] > 0.0 and not unit["routed"] and unit["action"] not in ["휴식","사기 혼란","수레 공격"]

func _nearby_corps(side: int, center: Vector2, radius: float, attacking: bool = false) -> int:
    var count:=0
    for unit in units:
        if unit["side"]!=side or unit["troops"]<=0 or unit["routed"]: continue
        if attacking and not _can_attack_troops(unit): continue
        var point: Vector2=unit["pos"]
        if point.distance_squared_to(center)>radius*radius: continue
        if long_operation and _river_separates(point,center): continue
        count+=1
    return count

func _update_base_raid(base: Dictionary, dt: float) -> void:
    var side: int=base["side"]
    var raiders:=_nearby_corps(1-side,base["pos"],RAID_RADIUS,true)
    var rate:=mini(2,raiders)
    if rate>0 and _nearby_corps(side,base["pos"],GUARD_RADIUS)>0: rate=0
    if base["raid_rate"]==0 and rate>0: _site_notice(side,_camp_side(side)+" 보급기지 급습",base["pos"])
    base["raid_rate"]=rate
    if rate==0:
        base["raid_work"]=0.0
        base["raid_elapsed"]=0.0
        return
    base["raid_elapsed"]+=minf(dt,maxf(0.0,RAID_SECONDS-base["raid_work"])/rate)
    base["raid_work"]+=dt*rate
    if base["raid_work"]>=RAID_SECONDS-0.00001:
        base["alive"]=false
        base["state"]="파괴"
        _morale_news(side,base["pos"],-25.0,"보급기지 상실")
        base["raiders_at_loss"]=raiders
        base["raid_rate"]=0
        if supply_crews[side]["state"]=="구축" and (supply_crews[side]["pos"] as Vector2).is_equal_approx(base["pos"]):
            supply_crews[side]["state"]="대기"
        if side==0 or player_can_see(base["pos"]):
            _field_notice(_camp_side(side)+" 보급기지 상실 · 인근 군단 사기 하락",base["pos"])

func raid_seconds_left(base: Dictionary) -> int:
    if base["raid_rate"]<=0: return 0
    return ceili(maxf(0.0,RAID_SECONDS-base["raid_work"])*operation_scale()/float(base["raid_rate"])-0.00001)

func supply_caption(base: Dictionary) -> String:
    var kind: String="보급기지"
    if base["raid_rate"]>0: return "%s 급습 · 파괴까지 %d초" % [kind,raid_seconds_left(base)]
    if base["state"]=="설치": return "%s 구축 · %d초" % [kind,ceili(float(base["build_timer"])*operation_scale())]
    if base["state"]=="착공 예정": return "기지 예정지"
    return kind

func crew_caption(side: int) -> String:
    var crew: Dictionary = supply_crews[side]
    match str(crew["state"]):
        "구축":
            for base in bases:
                if base["side"] == side and base["alive"] and base["state"] == "설치" and crew["pos"] == base["pos"]:
                    return "기지 구축 %d초" % ceili(float(base["build_timer"]) * operation_scale())
        "이동": return "후속 기지로 이동" if crew.get("extending",false) else "현장 복귀"
        "회피": return "보급부대 대피"
        "괴멸":
            if not crew.has("reassemble_at"): return "보급부대 괴멸"
            var left := ceili(maxf(0.0,float(crew["reassemble_at"]) - battle_time) * operation_scale())
            return "보급대 재편 %d초" % left if left > 0 else "본진 안전 대기"
    return "보급부대 대기"

# Each shipment has an origin and a travel time. A closer depot improves
# frequency; crossing the former supply-circle boundary has no effect.
func _deliver_rations(unit: Dictionary, dt: float) -> void:
    unit["rations"]=maxf(0.0,unit["rations"]-dt*(0.32 if long_operation else 0.65))
    var depot_id: int=unit.get("shipment_from",-1)
    if depot_id<0 or not bases[depot_id]["alive"] or bases[depot_id]["state"]!="가동":
        var origin:=_nearest_base(unit["side"],unit["pos"],true)
        unit["supplied"]=not origin.is_empty()
        unit["shipment_from"]=-1
        if origin.is_empty():
            unit["out_supply"]+=dt
            if unit["out_supply"]>=TURN_SECONDS*3: unit["morale"]=maxf(0.0,unit["morale"]-dt*0.15)
            return
        var from: Vector2=origin["pos"]
        var target: Vector2=unit["pos"]
        var length:=from.distance_to(target)
        if long_operation and _river_separates(from,target):
            var y:=_choose_crossing(unit,from,target)
            var bridge:=Vector2(river_x(y),y)
            length=from.distance_to(bridge)+bridge.distance_to(target)
        unit["shipment_from"]=bases.find(origin)
        unit["delivery_left"]=4.0+length/48.0
    unit["out_supply"]=0.0
    unit["delivery_left"]-=dt
    if unit["delivery_left"]>0.0: return
    unit["shipment_from"]=-1
    unit["deliveries"]=int(unit.get("deliveries",0))+1
    if unit["rations"]<25 or unit["routed"]:
        unit["morale"]=minf(100.0,unit["morale"]+3.0)
        unit["morale_news"]="구호 배급 도착"
    unit["rations"]=minf(100.0,unit["rations"]+12.0)
    if unit["type"]=="궁병": unit["ammo"]=minf(100.0,unit["ammo"]+12.0)

func _morale_news(side: int, at: Vector2, change: float, cause: String) -> void:
    for unit in units:
        if unit["side"]!=side or unit["troops"]<=0: continue
        if at.distance_to(unit["pos"])>MORALE_NEWS_DISTANCE: continue
        unit["morale"]=clampf(unit["morale"]+change,0,100)
        unit["morale_news"]=cause

func _nearest_base(side: int, point: Vector2, operational: bool=false) -> Dictionary:
    var best: Dictionary={}
    var distance:=INF
    for base in bases:
        if base["side"]!=side or not base["alive"] or (operational and base["state"]!="가동"): continue
        var d:=point.distance_squared_to(base["pos"])
        if d<distance:
            best=base
            distance=d
    return best

func _buildable_ground(point: Vector2) -> bool:
    if terrain_at(point) in ["하천","교량","습지"]: return false
    for structure in structures:
        if structure["hp"]>0 and (structure["rect"] as Rect2).grow(8.0).has_point(point): return false
    return true

func _supply_demand(side: int) -> Array[Dictionary]:
    var demand: Array[Dictionary] = []
    for unit in units:
        if unit["side"]!=side or unit["troops"]<=0 or unit["routed"] or unit["reserve"]: continue
        if unit["mission"]=="철수" or unit["action"] in ["패주","후퇴","전술 철수","재집결"]: continue
        var point: Vector2=unit["pos"]
        var depot:=_nearest_base(side,point,true)
        var marched:=point.distance_to(unit["supply_mark"])
        if depot.is_empty() or (marched>=MARCH_LEG and point.distance_to(depot["pos"])>=MARCH_LEG):
            demand.append(unit)
    return demand

func _extend_supply(side: int) -> void:
    var crew: Dictionary = supply_crews[side]
    if crew["strength"] <= 0 or crew["state"] not in ["대기","이동"]: return
    if crew["state"] == "이동" and not crew.get("extending", false):
        var rebuilding: int=crew.get("rebuild",-1)
        if rebuilding<0 or _can_rebuild(bases[rebuilding]): return
        crew["state"]="대기"
        crew.erase("rebuild")
    for base in bases:
        if base["side"] == side and base["alive"] and base["state"] == "설치" and _safe_crew_site(side,base["pos"]):
            crew["goal"] = base["pos"]
            crew["state"] = "이동"
            crew["extending"] = false
            return
    for i in range(bases.size()-1,-1,-1):
        var lost:=bases[i]
        if lost["side"]!=side or not _can_rebuild(lost): continue
        crew["state"]="이동"
        crew["goal"]=lost["pos"]
        crew["extending"]=false
        crew["rebuild"]=i
        return
    var demand := _supply_demand(side)
    var leg := MARCH_LEG
    if crew["state"] == "이동":
        if _safe_crew_site(side,crew["goal"]):
            for unit in demand:
                if _on_supply_march(crew,unit): return
        crew["state"] = "대기"
        crew["goal"] = crew["pos"]
        crew["extending"] = false
    var site := Vector2.INF
    var best := -INF
    for lead in demand:
        var point: Vector2 = lead["pos"]
        var source := _nearest_base(side,point,true)
        var departure: Vector2 = source.get("pos", crew["pos"])
        var back := point.direction_to(departure)
        if back.is_zero_approx(): back = -Vector2(lead["facing"])
        # First choice is the actual march. Where the ground or enemy rules it
        # out, the crew can still cover that frontage from a nearby dry site.
        var stop := departure.move_toward(point,leg) if not source.is_empty() else point
        var candidates := [stop, stop + back * leg * 0.22,
            stop + (back + back.orthogonal()) * leg * 0.24,
            stop + (back - back.orthogonal()) * leg * 0.24]
        for candidate: Vector2 in candidates:
            candidate = _field_point(candidate)
            if not source.is_empty() and candidate.distance_to(departure) < leg * 0.64: continue
            if not _safe_crew_site(side,candidate): continue
            var score := 0.0
            for ally in demand:
                if candidate.distance_to(ally["pos"]) <= leg: score += float(ally["troops"])
            score -= point.distance_to(candidate) * 1.2 + Vector2(crew["pos"]).distance_to(candidate) * 0.15
            if score > best:
                best = score
                site = candidate
                crew["departure"]=departure
    if site != Vector2.INF:
        crew["goal"] = site
        crew["state"] = "이동"
        crew["extending"] = true

func _on_supply_march(crew: Dictionary, unit: Dictionary) -> bool:
    var origin: Vector2=crew.get("departure",crew["pos"])
    var stop: Vector2=crew["goal"]
    var front: Vector2=unit["pos"]
    return front.distance_to(stop)<=MARCH_LEG or Geometry2D.get_closest_point_to_segment(stop,origin,front).distance_to(stop)<80.0

func _can_rebuild(base: Dictionary) -> bool:
    if base["alive"] or base["state"] not in ["파괴","구축 중단"]: return false
    if not _safe_crew_site(base["side"],base["pos"]): return false
    for u in units:
        if u["side"]==base["side"] and u["troops"]>0 and Vector2(u["pos"]).distance_to(base["pos"])<=MORALE_NEWS_DISTANCE: return true
    return false

func _safe_crew_site(side: int, point: Vector2) -> bool:
    if not _buildable_ground(point) or _nearby_corps(1-side,point,GUARD_RADIUS)>0: return false
    var enemy_post:=_nearest_base(1-side,point)
    return enemy_post.is_empty() or point.distance_to(enemy_post["pos"])>GUARD_RADIUS

func _update_supply_crew(crew: Dictionary, dt: float) -> void:
    var side: int=crew["side"]
    if crew["strength"] <= 0:
        if not crew.has("reassemble_at") or battle_time < float(crew["reassemble_at"]): return
        var home: Dictionary = headquarters[side]
        if home["occupied"] or _nearby_corps(1-side,home["pos"],GUARD_RADIUS) > 0: return
        crew.erase("reassemble_at")
        crew.erase("rebuild")
        crew["pos"] = home["pos"]
        crew["goal"] = home["pos"]
        crew["bridge_y"] = -1.0
        crew["bridge_bank"] = 0
        crew["extending"] = false
        crew["strength"] = 60.0
        crew["state"] = "대기"
        _site_notice(side,_camp_side(side)+" 본진에서 보급부대 재편",home["pos"])
        return
    var pos: Vector2=crew["pos"]
    var attackers:=0
    var closest: Dictionary={}
    var closest_distance:=INF
    for enemy in units:
        if enemy["side"]==side or not _can_attack_troops(enemy): continue
        var distance:=pos.distance_squared_to(enemy["pos"])
        if distance>RAID_RADIUS*RAID_RADIUS or (long_operation and _river_separates(pos,enemy["pos"])): continue
        attackers+=1
        if distance<closest_distance:
            closest=enemy
            closest_distance=distance
    if attackers>0:
        # Only the small rear guard fights, at physical contact range.
        var loss:=minf(closest["troops"],dt*(0.6 if six_armies else 0.025)*crew["strength"]/100.0)
        _take_combat_loss(closest, loss, pos, true)
        var escorted:=_nearby_corps(side,pos,GUARD_RADIUS)>0
        crew["strength"]=maxf(0.0,crew["strength"]-dt*attackers*(4.0 if escorted else 25.0))
        if crew["strength"]<=0:
            crew["state"]="괴멸"
            if long_operation: crew["reassemble_at"] = battle_time + turn_duration()
            _site_notice(side,_camp_side(side)+" 보급부대 괴멸",pos)
            for b in bases:
                if b["side"]==side and b["alive"] and b["state"]=="설치":
                    b["alive"]=false
                    b["state"]="구축 중단"
            return
        if not escorted:
            var rear:=_nearest_base(side,pos,true)
            var escape: Vector2=pos-closest["pos"]
            if escape.length_squared()<1: escape=Vector2.LEFT if side==0 else Vector2.RIGHT
            crew["goal"]=rear["pos"] if not rear.is_empty() and pos.distance_to(rear["pos"])>GUARD_RADIUS else _field_point(pos+escape.normalized()*GUARD_RADIUS)
            crew["state"]="회피"
    if crew["state"] not in ["이동","회피"]: return
    var site: Vector2=crew["goal"]
    var waypoint:=site
    if long_operation: waypoint=_committed_bridge_route(crew,pos,site)
    elif wide_field: waypoint=_crossing_route(pos,site)
    waypoint=_detour_goal(crew,pos,waypoint)
    var travel:=dt*27.0*_terrain_movement_multiplier(crew,pos)
    var moved:=_structure_move(crew,pos,_field_point(pos.move_toward(waypoint,travel)))
    crew["pos"]=_land_motion(crew,pos,moved) if long_operation else moved
    if not (crew["pos"] as Vector2).is_equal_approx(site): return
    var stale := false
    if crew.get("extending",false):
        stale = true
        for unit in _supply_demand(side):
            if _on_supply_march(crew,unit):
                stale = false
                break
    var rebuilding: int=crew.get("rebuild",-1)
    crew.erase("rebuild")
    if crew["state"]=="회피" or stale or not _safe_crew_site(side,site) or (rebuilding>=0 and not _can_rebuild(bases[rebuilding])):
        crew["state"]="대기"
        return
    crew["state"]="구축"
    crew["extending"]=false
    for b in bases:
        if b["side"]==side and b["alive"] and b["state"]=="설치" and site.is_equal_approx(b["pos"]): return
    var post:=_base(side,site)
    post["forward"]=bases[rebuilding].get("forward",false) if rebuilding>=0 else true
    post["state"]="설치"
    post["build_timer"]=BASE_BUILD_SECONDS
    if rebuilding>=0: bases[rebuilding]=post
    else: bases.append(post)
    _site_notice(side,_camp_side(side)+" 보급부대가 보급기지 구축 시작",site)

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
    var sight := _vision_range(unit)
    var nearest_distance := sight
    var position: Vector2 = unit["pos"]
    for enemy in units:
        if int(enemy["side"]) == int(unit["side"]) or float(enemy["troops"]) <= 0.0:
            continue
        var distance: float = position.distance_to(enemy["pos"])
        if distance < nearest_distance and distance < sight * unit_exposure(enemy):
            nearest_distance = distance
            nearest = enemy
    return nearest

func _can_see_base(unit: Dictionary, target_base: Dictionary) -> bool:
    if target_base.is_empty() or not bool(target_base["alive"]):
        return false
    var p: Vector2 = unit["pos"]
    var b: Vector2 = target_base["pos"]
    return p.distance_to(b) < 210.0 * watch_factor(p,unit["side"])

func _decide(unit: Dictionary) -> void:
    if battle_time<float(unit.get("panic_until",-1.0)):
        unit["action"]="사기 혼란"
        unit["reason"]="사기 붕괴 · 병사 탈주"
        unit["goal"]=unit["pos"]
        return
    if command_confused(unit["side"]) and not unit["routed"]:
        unit["action"]="지휘 혼란"
        unit["reason"]="책사 생포 · 대열을 추스르며 현 위치에서 방어"
        unit["goal"]=unit["pos"]
        return
    var nearest: Dictionary = _nearest_visible_enemy(unit)
    var side: int = int(unit["side"])
    var depot:=_nearest_base(side,unit["pos"],true)
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
    elif str(unit["type"]) == "궁병" and float(unit["ammo"]) < (52.0 if unit["action"] == "탄약 보충" else 12.0) and enemy_distance > 115.0 and not depot.is_empty():
        action = "탄약 보충"
        reason = "잔여 화살 부족: 보급기지로 이동"
        goal = depot["pos"]
    elif float(unit["rations"]) < (55.0 if unit["action"] == "보급 복귀" else 20.0) and enemy_distance > 125.0 and not depot.is_empty():
        action = "보급 복귀"
        reason = "식량 부족: 전투 지속력을 회복"
        goal = depot["pos"]
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
    elif str(unit["type"]) == "보병" and personality == "신중" and not depot.is_empty() and pos.distance_to(depot["pos"]) < 260.0 and enemy_distance >= 110.0 and _nearby_corps(1-side,depot["pos"],165.0)>0:
        action = "보급 호위"
        reason = "보급기지에 접근하는 적을 발견해 수비"
        goal = depot["pos"]
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
    var enemy_base:=_nearest_base(1-side,pos)
    var enemy_crew: Dictionary=supply_crews[1-side]
    var raid_index: int=unit.get("raid_base",-1)
    if unit["raid_active"] and raid_index>=0 and raid_index<bases.size() and battle_time<unit["raid_until"]:
        enemy_base=bases[raid_index]
    var raid_allowed: bool = personality == "공격" and ability > 60.0 and action not in ["후퇴", "패주", "재집결", "휴식", "보급 복귀", "탄약 보충", "거점 방어", "매복"]
    if raid_allowed and bool(unit["raid_active"]) and battle_time < float(unit["raid_until"]) and not enemy_base.is_empty() and enemy_base["alive"]:
        if _can_see_base(unit, enemy_base):
            unit["raid_target"] = enemy_base["pos"]
        action = "기지 습격"
        reason = "보급기지 습격 지속: 마지막 관측 지점을 추적"
        goal = unit["raid_target"]
    elif raid_allowed and unit["type"]=="기병" and enemy_distance>135.0 and enemy_crew["state"] in ["이동","회피"] and pos.distance_to(enemy_crew["pos"])<140.0*watch_factor(pos,side) and not _in_forest(enemy_crew["pos"]) and (not long_operation or not _river_separates(pos,enemy_crew["pos"])):
        action="보급부대 추격"
        reason="노출된 적 수레를 발견해 추격"
        goal=enemy_crew["pos"]
    elif raid_allowed and _can_see_base(unit, enemy_base) and battle_time - float(unit["last_raid"]) > 12.0:
        unit["raid_active"] = true
        unit["raid_base"]=bases.find(enemy_base)
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
        var base_pos: Vector2 = _home_point(side)
        if enemy_distance > 110.0 or (not nearest.is_empty() and (nearest["pos"] as Vector2).distance_to(base_pos) > 210.0):
            action = "본진 수비"
            reason = "본진 점거 차단"
            goal = base_pos+Vector2(65.0 if side == 0 else -65.0,0)
    if six_armies and str(unit["type"]) == "궁병" and enemy_distance > 165.0 and action in ["진격","거점 점령","거점 방어","전열 지원","명령 수행"] and str(unit["mission"]) not in ["측후방 기동","구원 지원"]:
        var screen: Dictionary = _infantry_screen(unit)
        if not screen.is_empty():
            var screen_pos: Vector2 = screen["pos"]
            var behind: Vector2 = -_screen_forward(screen,nearest) if long_operation else -Vector2(screen["facing"]).normalized()
            goal = screen_pos+behind*100.0
            action = "전열 지원"
            reason = "보병 엄호 하에 후방 사격 위치 확보"
    var mounted_anchor:=MountedVanguard.station(self,unit) if long_operation else Vector2.INF
    var mounted_foes:=MountedVanguard.contacts(self,unit,mounted_anchor)
    var on_station:=mounted_anchor!=Vector2.INF and (not mounted_foes.is_empty() or unit.has("mounted_anchor"))
    if not on_station and six_armies and (scenario_id!=3 or LinkedMarch.role(unit,battle_time) in LinkedMarch.COOPERATIVE_MISSIONS):
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
    if long_operation:
        var choice: Dictionary=FieldJudgment.choose(self,unit,nearest,action)
        unit["field_choice"]=choice
        if not choice.is_empty():
            action=choice["action"]
            reason=choice["reason"]
            goal=choice["goal"]
    if long_operation and not nearest.is_empty() and unit["field_choice"].is_empty():
        var station:=_screen_station(unit,nearest,action)
        if not station.is_empty():
            action=station["action"]
            reason=station["reason"]
            goal=station["goal"]
    if scenario_id==2 and side==1 and enemy_distance>165.0 and not unit["routed"] and str(unit["mission"])=="중앙 진격" and action in ["진격","거점 점령","명령 수행"]:
        action="본진 공략"
        reason="적 본진 점거"
        goal=_home_point(0)
    if scenario_id == 3 and side == 1 and not convoy.is_empty() and action in ["차단", "교전", "돌파", "공격 지속"]:
        var wagon: Vector2 = convoy["pos"]
        var gap := pos.distance_to(wagon)
        if gap < 115.0 and gap < enemy_distance and _convoy_access(unit, wagon):
            action = "수레 공격" if gap <= 42.0 else "차단"
            reason = "군량 수레에 접근해 파손" if action == "수레 공격" else "호위 수레의 진로를 막기 위해 접근"
            goal = wagon
    var watch: Dictionary=unit.get("post_watch",{})
    if not watch.is_empty() and battle_time<watch["until"] and not commander_captured(side) and NorthernField._watch_ready(self,unit) and action not in ["후퇴","패주","재집결","휴식","보급 복귀","탄약 보충","사기 혼란","거리 유지","전술 철수"]:
        action="거점 차단" if unit["type"]=="보병" else "거점 엄호 사격"
        reason="%s 인근에서 적 %d개 군단을 거듭 관측" % [outposts[watch["site"]]["name"],watch["count"]]
        goal=watch["station"] if pos.distance_to(watch["station"])>12.0 else pos
        unit["field_choice"]={}
    # An explicit headquarters assignment follows the camp. The commander can
    # meet a local attack but keeps the center of the corps within guard range.
    if unit["mission"]=="본진 방어" and unit["has_destination"] and not unit["routed"] and action not in ["후퇴","패주","재집결","휴식","보급 복귀","탄약 보충","전술 철수","사기 혼란"]:
        var home:=_home_point(side)
        if not nearest.is_empty() and (nearest["pos"] as Vector2).distance_to(home)<=GUARD_RADIUS and not _river_separates(home,nearest["pos"]):
            goal=home+home.direction_to(nearest["pos"])*32.0
            reason="본진 수비선에서 접근한 적을 저지"
        else:
            goal=home
            reason="본진 수비선에 집결" if pos.distance_to(home)>GUARD_RADIUS else "본진에 주둔하며 진입로 경계"
        action="본진 수비"
        unit["field_choice"]={}
    if long_operation:
        var local_order := BreakContact.decision(self,unit)
        if local_order.is_empty(): local_order = RallyOrders.decision(self,unit,nearest,action)
        var mounted_order: Dictionary={}
        if on_station and action not in MountedVanguard.OVERRIDES and local_order.get("action","") not in MountedVanguard.OVERRIDES and not local_order.get("arrival_cover",false):
            mounted_order=MountedVanguard.decide(self,unit,mounted_anchor,mounted_foes)
        if not mounted_order.is_empty():
            local_order=mounted_order
            unit["mounted_anchor"]=mounted_anchor
            unit["mounted_partner"]=mounted_order.get("ally",-1)
            if mounted_order["action"]=="기병 대기":
                unit["flank_target"]=-1
                unit["flank_phase"]=0
        elif unit.erase("mounted_anchor"):
            unit.erase("mounted_partner")
            unit["flank_target"]=-1
            unit["flank_phase"]=0
        unit["rally_covering"]=local_order.get("arrival_cover",false)
        if not local_order.is_empty():
            action = local_order["action"]
            reason = local_order["reason"]
            goal = local_order["goal"]
            unit["field_choice"] = local_order if local_order.has("target") else {}
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
        elif action in ["돌파","반격","교전","공격 지속"]: wanted = "어린진"
        else: wanted = "학익진"
    if six_armies and action in ["지정 지역 사수","예비 대기","전열 유지"] and str(unit["type"])=="보병": wanted="방진"
    if six_armies and action in ["협동 엄호","궁병 보호","아군 보호"] and str(unit["type"])=="보병": wanted="방진"
    if six_armies and action in ["협동 우회","협동 대기"] and str(unit["type"])=="기병": wanted="봉시진"
    if long_operation and float(unit["bridge_y"])>=0.0 and absf(pos.x-river_x(pos.y))<130.0:
        wanted="종대"
    if str(unit["policy"]).ends_with(" 유지") and str(unit["policy"]).replace(" 유지","") in LARGE_FORMATIONS and action != "패주":
        wanted = str(unit["policy"]).replace(" 유지", "")
    _order_formation(unit, wanted)

func _order_formation(unit: Dictionary, wanted: String) -> void:
    var current: String = unit["formation"]
    var pending: String = unit["next_formation"]
    if pending == wanted or (pending.is_empty() and current == wanted): return
    if not six_armies and wanted == current:
        unit["next_formation"] = ""
        unit["form_remaining"] = 0.0
        return
    var duration := 2.1 + (100.0 - _effective_stat(unit, "leadership")) * 0.025
    if six_armies:
        var count := clampi(ceili(float(unit["troops"]) / 180.0), 1, 24)
        var origins := _occupied_files(unit, count)
        var targets := FormationDrill.match_files(origins, FormationDrill.pattern(wanted, count))
        var longest := 0.0
        for i in range(count): longest = maxf(longest, origins[i].distance_to(targets[i]))
        unit["drill"] = {"shape":wanted, "origins":origins, "targets":targets}
        duration = maxf(0.4, duration * clampf(longest / 2.1, 0.32, 1.5))
    unit["next_formation"] = wanted
    unit["form_remaining"] = duration
    unit["form_duration"] = duration

func _occupied_files(unit: Dictionary, count: int) -> Array[Vector2]:
    var current: String = unit["formation"]
    var wanted: String = unit["next_formation"]
    var drill: Dictionary = unit.get("drill", {})
    var settled: Dictionary = unit.get("dressed_files", {})
    var files := FormationDrill.pattern(current, count)
    if settled.get("shape", "") == current: files = settled["files"]
    if not wanted.is_empty() and drill.get("shape", "") == wanted: files = _sample_drill(unit, drill)
    if files.size() == count: return files
    # Hits can change the size between model steps. Sample surviving files without
    # changing the commander's drill clock when a camera asks for the geometry.
    var surviving := FormationDrill.pattern(current, count).duplicate()
    for i in range(mini(count, files.size())): surviving[i] = files[i]
    return surviving

func _prepare_formation_files(unit: Dictionary) -> void:
    var count := clampi(ceili(float(unit["troops"]) / 180.0), 1, 24)
    var current: String = unit["formation"]
    var wanted: String = unit["next_formation"]
    var drill: Dictionary = unit.get("drill", {})
    var settled: Dictionary = unit.get("dressed_files", {})
    var origins := FormationDrill.pattern(current, count)
    if settled.get("shape", "") == current:
        var files: Array[Vector2] = settled["files"]
        if files.size() != count:
            var surviving: Array[Vector2] = origins.duplicate()
            for i in range(mini(files.size(), count)): surviving[i] = files[i]
            files = FormationDrill.match_files(surviving, origins)
            settled["files"] = files
        origins = files
    if wanted.is_empty(): return
    if drill.get("shape", "") != wanted or drill["targets"].size() != count:
        # A casualty can remove a file mid-order. Reassign from the surviving
        # positions with the remaining time, preserving the occupied ground.
        if drill.get("shape", "") == wanted:
            var existing := _sample_drill(unit, drill)
            origins = origins.duplicate()
            for i in range(mini(existing.size(), count)):
                origins[i] = existing[i]
            unit["form_duration"] = maxf(0.001, unit["form_remaining"])
        drill = {"shape":wanted, "origins":origins, "targets":FormationDrill.match_files(origins, FormationDrill.pattern(wanted,count))}
        unit["drill"] = drill

func _sample_drill(unit: Dictionary, drill: Dictionary) -> Array[Vector2]:
    var progress := 1.0 - float(unit["form_remaining"]) / maxf(0.001, unit["form_duration"])
    return FormationDrill.sample(drill["origins"], drill["targets"], progress)


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
        "본진 방어": return _field_point(_home_point(side) + layout_point(Vector2(60 if side == 0 else -60,0)))
        _: return layout_point(Vector2(x,287.0))

func _formation_transition(unit: Dictionary, dt: float) -> void:
    if six_armies: _prepare_formation_files(unit)
    if str(unit["next_formation"]) == "":
        return
    unit["form_remaining"] = float(unit["form_remaining"]) - dt
    if float(unit["form_remaining"]) <= 0.0:
        if six_armies:
            unit["dressed_files"] = {"shape":unit["next_formation"], "files":unit["drill"]["targets"]}
            unit.erase("drill")
        if unit["formation"] != unit["next_formation"]:
            unit["reforms_completed"] += 1
        unit["formation"] = str(unit["next_formation"])
        unit["next_formation"] = ""
        unit["form_remaining"] = 0.0

func _movement_rate(unit: Dictionary, enemy: Dictionary) -> float:
    var pos: Vector2=unit["pos"]
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
    return rate

func _move_unit(unit: Dictionary, dt: float) -> void:
    unit["walking_step"] = Vector2.ZERO
    if unit.has("skill_ids"): unit["skill_step_share"]=0.0
    var prior_heading: Vector2 = unit["facing"]
    if battle_time<float(unit.get("panic_until",-1.0)) or (command_confused(unit["side"]) and not unit["routed"]):
        unit["motion_speed"]=0.0
        unit["charge"]=0.0
        unit["charge_speed"]=0.0
        return
    var pos: Vector2 = unit["pos"]
    var goal: Vector2 = unit["goal"]
    var enemy: Dictionary = _nearest_visible_enemy(unit)
    var reply: Dictionary = rear_responses.get(unit["id"], {})
    var meeting_contact := false
    if not reply.is_empty() and _can_answer_rear(unit):
        var opponent := find_unit(reply["front"] if reply["front"] >= 0 else reply["rear"])
        if _in_melee(unit, opponent):
            enemy = opponent
            goal = pos
            meeting_contact = true
    var dressing_line: bool=long_operation and not enemy.is_empty() and unit["action"] in ["후열 정렬","엄호 사격","전열 유지","거리 유지","궁병 보호","협동 엄호"]
    if not enemy.is_empty() and not (unit["action"]=="본진 수비" and unit["has_destination"]) and str(unit["action"]) not in ["기병 대기","포위 이탈","거점 차단","거점 엄호 사격","수레 공격", "후퇴", "기지 습격", "방어", "거리 유지", "측면 우회", "보급 호위", "재집결", "휴식", "탄약 보충", "보급 복귀", "거점 점령", "거점 방어", "측면 방어", "전열 지원", "패주", "매복", "정보 확인", "명령 수행", "계획 경유", "방어선 사수", "긴급 방어", "전술 철수", "긴급 지원", "전술 재집결","협동 우회","협동 엄호","구원 지원","협동 대기","지정 위치 이동","지정 지역 사수","예비 대기","궁병 보호","아군 보호","후열 정렬","엄호 사격","전열 유지"]:
        var distance: float = pos.distance_to(enemy["pos"])
        var range_goal: float = 143.0 if str(unit["type"]) == "궁병" else 32.0
        if distance <= range_goal:
            goal = pos
            if not meeting_contact: unit["goal"] = pos
    var march: Dictionary={} if meeting_contact else march_plans.get(unit["id"],{})
    var rate: float
    if march.is_empty():
        rate=_movement_rate(unit,enemy)
    else:
        goal=march["goal"]
        rate=march["pace"]
        if march["phase"]=="도하" and (pos.x-river_x(pos.y))*march["bank"]<0.0:
            unit["bridge_y"]=march["bridge"]
            unit["bridge_bank"]=march["bank"]
    if march.is_empty() and unit.has("skill_ids"):
        var skill: Dictionary=unit["field_skill"]
        if not skill.is_empty() and Skills.mission(unit,battle_time) in skill["missions"]:
            if skill["effect"]=="feint" and not unit.has("mounted_anchor") and not enemy.is_empty() and not meeting_contact and unit["action"]!="포위 이탈":
                goal=_field_point(Vector2(skill["anchor"])+Vector2(enemy["pos"]).direction_to(skill["anchor"])*62.0)
            elif skill["effect"]=="stride" or (skill["effect"]=="pursue" and not enemy.is_empty() and enemy["routed"] and pos.direction_to(goal).dot(pos.direction_to(enemy["pos"]))>0.65):
                rate*=1.0+float(skill["power"])
                unit["skill_step_share"]=float(skill["power"])/(1.0+float(skill["power"]))
    var running_in := false
    if str(unit["type"]) == "기병":
        unit["charge_cooldown"] = maxf(0.0, float(unit["charge_cooldown"]) - dt)
        running_in = march.is_empty() and _can_run_in(unit, enemy, pos, goal)
        if long_operation and running_in:
            rate *= 1.0 + 0.55 * smoothstep(0.0, 80.0, unit["charge"])
    var wheel_heading:=Vector2.ZERO
    var actual_move: Vector2 = Vector2.ZERO
    if pos.distance_to(goal) > (0.001 if not march.is_empty() else 2.0):
        if long_operation:
            if goal==march.get("deck_target",Vector2.INF):
                # Approach the deck on its own bank, then stop at the ordered point.
                if absf(pos.y-goal.y)>10.0 and not on_river_channel(pos):
                    var approach_side: int=1 if pos.x>=river_x(pos.y) else -1
                    goal=Vector2(river_x(goal.y)+approach_side*64.0,goal.y)
            else:
                goal = _committed_bridge_route(unit,pos,goal)
        elif wide_field and (enemy.is_empty() or pos.distance_to(enemy["pos"]) > 180.0):
            goal = _crossing_route(pos,goal)
        if not structures.is_empty() and (str(unit["type"]) == "기병" or bool(unit["routed"])):
            goal = _detour_goal(unit,pos,goal)
        var new_pos: Vector2 = pos.move_toward(goal, rate * dt)
        # A wing wheels out of its approach before accelerating at the front.
        # Use the same bearing for actual movement and the rotating combat files.
        var mounted_wing: bool=unit["type"]=="기병" and unit["flank_target"]>=0 and unit["action"] in ["협동 우회","돌파"]
        if long_operation and mounted_wing and march.is_empty() and not prior_heading.is_zero_approx() and not on_river_channel(pos):
            var course:=pos.direction_to(goal)
            wheel_heading=prior_heading.rotated(clampf(prior_heading.angle_to(course),-2.8*dt,2.8*dt))
            var alignment:=maxf(0.0,wheel_heading.dot(course))
            new_pos=pos+wheel_heading*minf(pos.distance_to(goal),rate*dt*alignment*alignment)
        # Once the files meet, spend only the available forward room. A
        # lateral order or a withdrawal can still slide along or leave the line.
        if long_operation and march.is_empty() and not enemy.is_empty() and unit["type"] != "궁병" and unit["contact_target_id"] == enemy["id"]:
            var normal := pos.direction_to(enemy["pos"])
            var room := maxf(0.0, pos.distance_to(enemy["pos"]) - _body_distance(unit, enemy))
            new_pos -= normal * maxf(0.0, (new_pos - pos).dot(normal) - room)
        var legal:Vector2=_structure_move(unit,pos,_field_point(new_pos))
        if long_operation: legal=_land_motion(unit,pos,legal)
        unit["pos"]=legal
        var moved: Vector2 = (unit["pos"] as Vector2) - pos
        actual_move = moved
        if moved.length_squared() > 0.03:
            unit["fatigue"] = minf(100.0, float(unit["fatigue"]) + moved.length() * (0.030 if str(unit["type"]) == "기병" else 0.042) * (0.48 if wide_field else 1.0))
            if not dressing_line: unit["facing"] = moved.normalized()
    if not march.is_empty() and (march["phase"]=="연계 행군" or pos.distance_to(goal)<5):
        unit["facing"]=march["forward"]
    if unit.has("rally_station") and unit["destination_reached"] and march.is_empty() and unit["action"] in ["지정 지역 사수","예비 대기"]:
        if enemy.is_empty() or pos.distance_to(enemy["pos"])>168.0 or _river_separates(pos,enemy["pos"]):
            unit["facing"]=unit["rally_station"]["forward"]
    unit["motion_speed"] = actual_move.length()/maxf(dt,0.001)
    if six_armies:
        if str(unit["action"])=="협동 우회": unit["maneuver_distance"]+=actual_move.length()
        if str(unit["action"]) in ["협동 엄호","구원 지원","궁병 보호"]:
            var ally: Dictionary=find_unit(int(unit["link_id"]))
            if not ally.is_empty() and float(ally["troops"])>0.0 and (unit["pos"] as Vector2).distance_to(ally["pos"])<=150.0:
                unit["support_seconds"]+=dt
    unit["walking_step"] = actual_move
    if str(unit["type"]) == "기병":
        _update_charge(unit, actual_move, dt, running_in)
    if not enemy.is_empty() and (dressing_line or pos.distance_to(enemy["pos"]) < 168.0) and (dressing_line or str(unit["action"]) not in ["포위 이탈", "후퇴", "패주", "재집결", "측면 우회", "기지 습격", "보급 복귀", "탄약 보충", "매복","협동 우회","협동 엄호"]):
        var front: Vector2 = (enemy["pos"] as Vector2) - (unit["pos"] as Vector2)
        if front.length_squared() > 1.0:
            if dressing_line:
                var heading: Vector2=unit["facing"]
                unit["facing"]=heading.rotated(clampf(heading.angle_to(front),-2.0*dt,2.0*dt)) if not heading.is_zero_approx() else front.normalized()
            else:
                unit["facing"] = (unit["facing"] as Vector2).lerp(front.normalized(),minf(1.0,dt*2.0)).normalized()

    # A pre-aligned column starts on its ordered bearing at deployment.
    var deployed: bool = step_count <= 1 and march.get("phase", "") == "연계 행군"
    if long_operation and not deployed and not prior_heading.is_zero_approx():
        var desired: Vector2 = wheel_heading if not wheel_heading.is_zero_approx() else unit["facing"]
        if meeting_contact or (march.is_empty() and actual_move.is_zero_approx() and not enemy.is_empty() and unit["contact_target_id"] == enemy["id"] and not unit["routed"]):
            desired = pos.direction_to(enemy["pos"])
        var turn_rate := 2.8 if unit["type"] == "기병" else 2.1
        unit["facing"] = prior_heading.rotated(clampf(prior_heading.angle_to(desired), -turn_rate * dt, turn_rate * dt)).normalized()


# M2-1: Keep formation bodies separate. This applies to friends and enemies.
# M2-2: A contact line shifts toward the weaker side, based on the soldiers
# actually in each formation, morale and how well a unit resists front pressure.
func _body_distance(a: Dictionary, b: Dictionary, slots_a: Array[Vector2]=[], slots_b: Array[Vector2]=[]) -> float:
    if six_armies:
        var direction: Vector2 = ((b["pos"] as Vector2)-(a["pos"] as Vector2)).normalized()
        if direction.length_squared()<0.01: direction=Vector2.RIGHT
        if slots_a.is_empty(): slots_a=formation_slots(a)
        if slots_b.is_empty(): slots_b=formation_slots(b)
        var edge_a := _leading_offset(a,slots_a,direction)
        var edge_b := _leading_offset(b,slots_b,-direction)
        var nominal := maxf(10.0,edge_a.dot(direction)+8.0)+maxf(10.0,edge_b.dot(-direction)+8.0)+5.0
        if a["side"] == b["side"] or a["type"] == "궁병" or b["type"] == "궁병": return nominal
        var range_sq: float = Vector2(a["pos"]).distance_squared_to(b["pos"])
        if range_sq > (nominal+12.0)*(nominal+12.0): return nominal
        if (direction*nominal+edge_b-edge_a).length_squared() <= 900.0: return nominal
        # Extremes on opposite wings need not be opposite each other. At the
        # proposed separation check actual file pairs, then close only the gap
        # needed to bring one pair within the model's existing melee reach.
        var tangent := direction.orthogonal()
        var contact_distance := 0.0
        var offset: Vector2 = direction*nominal - (Vector2(b["pos"])-Vector2(a["pos"]))
        for left in slots_a:
            for right in slots_b:
                var gap := right-left+offset
                if gap.length_squared() <= 900.0: return nominal
                var across := gap.dot(tangent)
                if absf(across) >= 29.0: continue
                contact_distance = maxf(contact_distance,nominal-gap.dot(direction)+sqrt(841.0-across*across))
        return minf(nominal, maxf(12.0,contact_distance))
    if str(a["type"]) == "궁병" or str(b["type"]) == "궁병":
        return 25.0
    return 34.0

func _frontline_power(unit: Dictionary, enemy: Dictionary, direction: Vector2) -> float:
    var factor: float = 1.0
    if six_armies: factor *= tactical_matchup(unit,enemy,false)
    factor *= FormationDrill.frontage_factor(unit["formation"])
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

# Move on the simulation clock. Small steps use the same gate and river checks
# as ordinary movement, then the frontage solver separates nearby formations.
func _advance_charge_recoil(unit: Dictionary, dt: float) -> void:
    var remaining: Vector2 = unit["charge_recoil"]
    var travel := minf(remaining.length(), 96.0 * dt)
    unit["charge_recoil"] = remaining.move_toward(Vector2.ZERO, travel)
    var direction := remaining.normalized()
    while travel > 0.001:
        var step_length := minf(6.0, travel)
        var old: Vector2 = unit["pos"]
        var goal := old + direction * step_length
        var legal := _structure_move(unit, old, _field_point(goal))
        unit["pos"] = _land_motion(unit, old, legal)
        if not (unit["pos"] as Vector2).is_equal_approx(goal):
            unit["charge_recoil"] = Vector2.ZERO
            break
        travel -= step_length

# Positions can change several times inside a single push sweep. Reuse exact
# occupied geometry only until that body's center is moved by another pair.
func _collision_profile(u: Dictionary,profiles: Dictionary) -> Dictionary:
    var cached: Dictionary=profiles.get(u["id"],{})
    if not cached.is_empty() and cached["center"]==u["pos"]: return cached
    var center: Vector2=u["pos"]
    var slots:=formation_slots(u)
    var squared:=0.0
    for point in slots: squared=maxf(squared,center.distance_squared_to(point))
    cached={"center":center,"slots":slots,"extent":maxf(10.0,sqrt(squared)+8.0)}
    profiles[u["id"]]=cached
    return cached

func _resolve_frontline(dt: float) -> void:
    front_shifts.clear()
    for unit in units:
        unit["front_pressure"] = 0.0
        if unit["troops"] > 0 and unit.get("charge_recoil", Vector2.ZERO) != Vector2.ZERO:
            _advance_charge_recoil(unit, dt)
    var profiles: Dictionary={}
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
            var threshold: float
            if six_armies:
                var body_a:=_collision_profile(a,profiles)
                var body_b:=_collision_profile(b,profiles)
                if distance>=float(body_a["extent"])+float(body_b["extent"])+12.0: continue
                threshold=_body_distance(a,b,body_a["slots"],body_b["slots"])
            else: threshold=_body_distance(a,b)
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
            var prior_position: Vector2 = current_b if shift > 0.0 else current_a
            var displacement: Vector2 = (losing_unit["pos"] as Vector2)-prior_position
            if displacement.length_squared()>0.0001:
                if tactical_enabled:
                    losing_unit["report_push"]=Vector2(losing_unit.get("report_push",Vector2.ZERO))+displacement
                    losing_unit["report_opponent"]=a["id"] if shift>0.0 else b["id"]
                var left_id: int = int(a["id"])
                var right_id: int = int(b["id"])
                front_shifts[Vector2i(mini(left_id,right_id),maxi(left_id,right_id))] = {
                    "loser":int(losing_unit["id"]), "direction":displacement.normalized(), "pressure":absf(advantage)}
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
    if on_river_channel(p):
        return "교량" if near_crossing(p.y) else "하천"
    if _in_forest(p):
        return "숲"
    if hill.has_point(p):
        return "고지"
    for lane in range(3):
        if absf(p.y-road_y(p.x,lane)) <= (16.0 if wide_field else 10.0):
            return "도로"
    if FieldGeometry.in_basins(p, marshes): return "습지"
    if FieldGeometry.in_basins(p, reedbeds): return "갈대밭"
    return "평지"

func on_river_channel(p: Vector2) -> bool:
    return wide_field and absf(p.x-river_x(p.y)) < 27.0

func in_open_water(p: Vector2) -> bool:
    return on_river_channel(p) and not near_crossing(p.y)

func terrain_movement_percent(id: int, position: Vector2) -> int:
    var unit := find_unit(id)
    return 100 if unit.is_empty() else roundi(_terrain_movement_multiplier(unit, position)*100.0)

func _terrain_movement_multiplier(unit: Dictionary, p: Vector2) -> float:
    match terrain_at(p):
        "갈대밭": return 0.63 if unit["type"] == "기병" else 0.84
        "습지": return 0.48 if str(unit["type"])=="기병" else 0.66
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

# Observation is a property of the observer's position. Concealment applies
# only when identifying troops, never when inspecting the ground itself.
func terrain_sight_factor(p: Vector2) -> float:
    if wide_field and _in_forest(p): return 0.86
    if hill.has_point(p) and not on_river_channel(p): return 1.15
    if FieldGeometry.in_basins(p, reedbeds): return 0.82
    return 1.0

func terrain_exposure(p: Vector2) -> float:
    if _in_forest(p): return 0.68
    if FieldGeometry.in_basins(p, reedbeds): return 0.72
    return 1.0

func unit_exposure(unit: Dictionary) -> float:
    var exposure := terrain_exposure(unit["pos"])
    if unit.get("ambush_ready",0.0) >= 3.0 and _in_forest(unit["pos"]):
        exposure *= 0.48
    return exposure

# One operation day has a daylight march, dusk, night watch, and dawn.
func night_depth() -> float:
    if not long_operation or not started: return 0.0
    var fraction := fposmod(battle_time, turn_duration()) / turn_duration()
    return smoothstep(0.48,0.58,fraction) * (1.0 - smoothstep(0.86,1.0,fraction))

func day_caption() -> String:
    return "%d일차 · %s" % [turn,"밤" if night_depth() >= 0.5 else "낮"]

const CAMP_LIGHT_RADIUS := 82.0

func watch_factor(point: Vector2, side: int) -> float:
    var dark := night_depth()
    if dark <= 0.0: return 1.0
    var night_range := 0.55
    var home: Dictionary = headquarters[side]
    if not home["occupied"] and point.distance_squared_to(home["pos"]) <= CAMP_LIGHT_RADIUS * CAMP_LIGHT_RADIUS:
        night_range = 0.85
    else:
        for base in bases:
            if base["side"] == side and base["alive"] and base["state"] == "가동" and point.distance_squared_to(base["pos"]) <= CAMP_LIGHT_RADIUS * CAMP_LIGHT_RADIUS:
                night_range = 0.85
                break
    return lerpf(1.0,night_range,dark)

func _vision_range(unit: Dictionary) -> float:
    return AI_VISION_RANGE * (0.85 + _effective_stat(unit, "intelligence") * 0.002) * terrain_sight_factor(unit["pos"]) * watch_factor(unit["pos"],unit["side"])

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
        return army_slots(unit,size,12.0)
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

# Draw smaller files inside each tactical slot, with the actual front
# row first so distant views can draw fewer soldiers in the same formation.
const REPRESENTATIVE_FILE_OFFSETS: Array[Vector2] = [
    Vector2.ZERO, Vector2(-1,-1), Vector2(1,1), Vector2(1,-1), Vector2(-1,1),
    Vector2(-1,0), Vector2(1,0), Vector2(0,-1), Vector2(0,1),
]

func representative_slots(unit: Dictionary,count: int) -> Array[Vector2]:
    var anchors: Array[Vector2]=formation_slots(unit)
    var result: Array[Vector2]=[]
    if anchors.is_empty() or count<=0: return result
    var front: Vector2=(unit["facing"] as Vector2).normalized()
    if front.length_squared()<0.1: front=Vector2.RIGHT if int(unit["side"])==0 else Vector2.LEFT
    var lateral: Vector2=front.orthogonal()
    var spacing: float=4.65 if str(unit["type"])=="기병" else 4.15
    var center: Vector2=unit["pos"]
    var near_river: bool=long_operation and absf(center.x-river_x(center.y))<=150.0
    for i in range(count):
        var anchor: Vector2=anchors[i%anchors.size()]
        var layer: int=floori(float(i)/float(anchors.size()))
        var offset: Vector2
        if layer<REPRESENTATIVE_FILE_OFFSETS.size():
            var file: Vector2=REPRESENTATIVE_FILE_OFFSETS[layer]
            offset=front*file.x+lateral*file.y
        else:
            offset=Vector2.from_angle(float(i)*2.39996)
        var point: Vector2=_field_point(anchor+offset*spacing)
        if near_river: point=_dry_formation_slot(center,point)
        result.append(point)
    return result

# Evaluate the closest actual contact when a combat effect is emitted.
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

func _can_answer_rear(unit: Dictionary) -> bool:
    return unit["type"] == "보병" and _can_attack_troops(unit) and unit["action"] not in [
        "포위 이탈", "후퇴", "재집결", "전술 철수", "전술 재집결", "보급 복귀", "탄약 보충", "거리 유지"]

func _in_melee(unit: Dictionary, other: Dictionary) -> bool:
    if other.is_empty() or other["routed"] or not _locally_observed(unit, other): return false
    var p: Vector2 = unit["pos"]
    var q: Vector2 = other["pos"]
    return not _river_separates(p, q) and _detour_goal(unit, p, q) == q and formation_contacts(unit, other, 30.0) > 0

# A corps learns about a second front from landed melee hits. Keep its main
# heading while its front is occupied. Rotate the whole body for a lone threat.
func _read_melee_pressure() -> Dictionary:
    var incoming: Dictionary = {}
    var threatened: Dictionary = {}
    for hit in combat_contacts.values():
        if hit["kind"] == "화살" or hit["damage"] <= 0.0: continue
        var id: int = hit["defender_id"]
        if hit["rear"] or rear_responses.has(id): threatened[id] = true
        if not incoming.has(id): incoming[id] = []
        incoming[id].append(hit)
    var responses: Dictionary = {}
    for id: int in threatened:
        var unit := find_unit(id)
        if not _can_answer_rear(unit): continue
        var old: Dictionary = rear_responses.get(id, {})
        var rear_id := -1
        var front_id := -1
        var rear_score := -INF
        var front_score := -INF
        var pos: Vector2 = unit["pos"]
        var heading: Vector2 = unit["facing"]
        for hit: Dictionary in incoming[id]:
            var other := find_unit(hit["attacker_id"])
            if not _can_attack_troops(other): continue
            var bearing := pos.direction_to(other["pos"]).dot(heading)
            var turning: bool = old.get("front", -2) == -1 and old.get("rear", -1) == other["id"]
            var behind := bearing < -0.4 or (turning and bearing < 0.8)
            if not behind and bearing <= 0.3: continue
            if not _in_melee(unit, other): continue
            var score: float = -pos.distance_squared_to(other["pos"])
            if behind and (other["id"] == old.get("rear", -1) or score > rear_score):
                rear_id = other["id"]
                rear_score = INF if rear_id == old.get("rear", -1) else score
            elif not behind and (other["id"] == old.get("front", -1) or score > front_score):
                front_id = other["id"]
                front_score = INF if front_id == old.get("front", -1) else score
        if rear_id < 0: continue
        if front_id < 0:
            var opponent := find_unit(old.get("front", unit["contact_target_id"]))
            if not opponent.is_empty() and opponent["id"] != rear_id and pos.direction_to(opponent["pos"]).dot(heading) > 0.3 and _in_melee(unit, opponent):
                front_id = opponent["id"]
        responses[id] = {"front": front_id, "rear": rear_id}
    return responses

func _combat(dt: float) -> void:
    if dt<=0.0: return
    # Precompute strikes before taking losses. Both sides resolve simultaneously.
    var damage_entries: Array[Dictionary] = []
    var targets: Dictionary = {}
    var requested_losses: Dictionary = {}
    rear_responses = _read_melee_pressure() if long_operation else {}
    combat_contacts={}
    while not combat_history.is_empty() and battle_time-float(combat_history.front()["time"])>COMBAT_HISTORY_SECONDS:
        combat_history.pop_front()
    for unit in units:
        if six_armies and _can_attack_troops(unit):
            var reply: Dictionary = rear_responses.get(unit["id"], {})
            if reply.is_empty():
                targets[int(unit["id"])] = _combat_target(unit)
            else:
                # Share the existing strike budget across the two contacts.
                var rear_file: bool = reply["front"] < 0 or (step_count + int(unit["id"])) % 3 == 0
                targets[int(unit["id"])] = find_unit(reply["rear"] if rear_file else reply["front"])
    for unit in units:
        unit["contact_troops"]=0
        unit["contact_target_id"]=-1
        if not _can_attack_troops(unit): continue
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
        var bow: bool=unit_type=="궁병"
        var lane_screened: bool=false
        var attack: float = 0.0
        match unit_type:
            "보병": attack = 2.4
            "궁병": attack = 1.8
            "기병": attack = 2.6

        if bow:
            if float(unit["ammo"])<=0.0: continue
            var ammo_needed: float=dt*(0.60 if long_operation else 0.85)
            var ammo_used: float=minf(float(unit["ammo"]),ammo_needed)
            if long_operation:
                lane_screened=_bow_lane_screened(unit,enemy,targets)
                attack*=_bow_effectiveness(unit,contacts,distance,ammo_used/ammo_needed,lane_screened)
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

        unit["contact_troops"]=contacts
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
        var braced: bool=false
        if unit_type == "기병" and (long_operation or distance < 70.0) and float(unit["charge_cooldown"]) <= 0.0:
            shock = _charge_impact(unit, enemy)
            braced=long_operation and shock>0.0 and _braced_for_charge(enemy,direction)
            if braced: shock*=0.48
            if shock > 0.0:
                unit["charges"] = int(unit["charges"]) + 1
                unit["charge_cooldown"] = 4.5
                unit["charge"] = 0.0
                unit["charge_speed"] = 0.0
                if long_operation:
                    unit["fatigue"]=minf(100.0,float(unit["fatigue"])+(5.0 if braced else 3.0))
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
        if command_confused(unit["side"]): attack *= 0.5
        attack *= 0.90 + _effective_stat(unit, "martial") * 0.002
        if unit.get("specialty","") == "돌격" and unit_type == "기병":
            attack *= 1.08

        var supply_factor: float = 0.76 if float(unit["out_supply"]) >= TURN_SECONDS * 3.0 else 1.0
        supply_factor *= 0.65 + 0.35 * float(unit["rations"]) / 100.0
        attack *= (1.0 - 0.30 * float(unit["fatigue"]) / 100.0) * (0.55 + 0.45 * float(unit["cohesion"]) / 100.0)
        unit["fatigue"] = minf(100.0, float(unit["fatigue"]) + dt * 0.60)
        var counter: float = tactical_matchup(unit,enemy,flank or rear) if six_armies else 1.0
        var partner_id: int=_combined_arms_partner(unit,enemy,targets) if six_armies else -1
        var link: bool=partner_id>=0
        attack *= counter*(1.15 if link else 1.0)
        var guard: Dictionary = _physical_screen(enemy,unit) if six_armies else {}
        var damage: float = attack * (float(unit["troops"]) / maxf(1.0, float(unit["initial_troops"]))) * (float(unit["morale"]) / 100.0) * exposure * supply_factor * dt
        if wide_field:
            damage *= float(unit.get("strength_share",1.0))
            if in_open_water(pos): damage *= 0.68
            if in_open_water(ep): damage *= 1.18
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
        var original_damage:=damage+shock
        var adjusted:=original_damage
        if unit.has("skill_ids"): adjusted=Skills.attack_factor(unit,enemy,bow,adjusted)
        var bonus:=adjusted-original_damage
        var damage_requested:=Skills.absorb(enemy,adjusted) if enemy.has("skill_ids") else adjusted
        if damage_requested<=0.0: continue
        var source_id: int=int(unit["id"])
        var target_id: int=int(enemy["id"])
        var attack_kind: String="돌격" if shock>0.0 else ("화살" if bow else "근접")
        var entry: Dictionary={
            "skill_bonus":bonus*(damage_requested/maxf(0.00001,adjusted)),"skill_saved":adjusted-damage_requested,"defender_id":target_id,"attacker_id":source_id,"damage":damage_requested,"flank":flank or rear,"rear":rear,
            "shock":shock,"braced":braced,"screened":lane_screened or not guard.is_empty(),"linked":link,"partner_id":partner_id,
            "ambush":ambush,"counter":counter,"guarding":guarding,"kind":attack_kind,"contacts":contacts,
            "from":pos,"to":ep,"time":battle_time,"side":unit["side"]
        }
        var visual_time: float = unit["last_visual"]
        if rear_responses.get(source_id, {}).get("front", -1) >= 0:
            visual_time = unit.get("melee_visual_times", {}).get(target_id, -100.0)
        if shock>0.0 or battle_time-visual_time>=(0.9 if bow else 0.55):
            var pair: Array[Vector2]=visual_contact_pair(unit,enemy)
            entry["visual_from"]=pair[0]
            entry["visual_to"]=pair[1]
            if bow and long_operation: entry["arrow_lanes"]=_bow_visual_lanes(unit,enemy,pair)
        damage_entries.append(entry)
        requested_losses[target_id]=float(requested_losses.get(target_id,0.0))+damage_requested
    # A shared casualty budget allocates simultaneous losses in proportion to
    # each attack. Unit array order cannot claim all of a nearly broken unit.
    for target_id in requested_losses:
        var capacity: float=float(find_unit(target_id)["troops"])
        requested_losses[target_id]=minf(1.0,capacity/float(requested_losses[target_id]))
    for entry in damage_entries:
        var defender: Dictionary=find_unit(int(entry["defender_id"]))
        var remaining: float=float(defender["troops"])
        if remaining<=0.0: continue
        var allocation: float=float(requested_losses[entry["defender_id"]])
        var actual_damage: float=minf(remaining,float(entry["damage"])*allocation)
        if remaining-actual_damage<0.000001: actual_damage=remaining
        if entry["skill_bonus"]>0.0:
            var officer: Dictionary=find_unit(entry["attacker_id"])
            officer["field_skill"]["stat"]["effect"]+=float(entry["skill_bonus"])*allocation
        if entry["skill_saved"]>0.0: defender["field_skill"]["stat"]["effect"]+=minf(remaining,float(entry["skill_saved"])*allocation)
        entry["damage"]=actual_damage
        combat_contacts[int(entry["attacker_id"])]=entry
        _take_combat_loss(defender, actual_damage, entry["from"], entry["kind"] != "화살")
        if bool(entry.get("guarding",false)) and actual_damage>0.0:
            defender["guard_intercept_damage"]+=actual_damage
            defender["guard_intercept_ticks"]+=1
        defender["last_hit"]=battle_time
        if entry["kind"]=="화살": defender["last_arrow_hit"]=battle_time
        if bool(entry["braced"]): defender["brace_stops"]+=1
        if bool(entry["rear"]): defender["rear_losses"]+=actual_damage
        var shock_damage: float=float(entry["shock"])*allocation/(ARMY_SCALE if six_armies else 1.0)
        var pressure_damage: float = actual_damage/(ARMY_SCALE if six_armies else 1.0)
        if long_operation and shock_damage > 0.0 and not entry["braced"]:
            var axis: Vector2 = (entry["from"] as Vector2).direction_to(entry["to"])
            var recoil := axis * minf(36.0, shock_damage * 3.4)
            defender["charge_recoil"] = defender.get("charge_recoil", Vector2.ZERO) + recoil
            entry["recoil"] = recoil
        if shock_damage > 0.0 or bool(entry["ambush"]):
            defender["morale"] = maxf(0.0, float(defender["morale"]) - (shock_damage * 1.1 + (6.0 if bool(entry["ambush"]) else 0.0))*(1.0-float(defender.get("field_skill",{}).get("power",0.0)) if defender.get("field_skill",{}).get("effect","")=="guard" else 1.0))
            defender["cohesion"] = maxf(0.0, float(defender["cohesion"]) - shock_damage * 1.6)
        _general_exposure(defender, pressure_damage, bool(entry["flank"]), shock_damage)
        var disarray: float=0.85 if bool(entry["flank"]) else 0.38
        if long_operation and bool(entry["rear"]): disarray=1.06
        defender["cohesion"]=maxf(0.0,float(defender["cohesion"])-pressure_damage*disarray)
        if bool(entry["flank"]):
            defender["flank_hits"] = float(defender["flank_hits"]) + actual_damage
        var source: Dictionary = find_unit(int(entry["attacker_id"]))
        if not source.is_empty():
            source["damage_dealt"] = float(source["damage_dealt"]) + actual_damage
            if entry.has("visual_from"):
                source["last_visual"]=battle_time
                if entry["kind"] != "화살":
                    if not source.has("melee_visual_times"): source["melee_visual_times"] = {}
                    source["melee_visual_times"][entry["defender_id"]] = battle_time
                visual_effects.append(entry)
                if visual_effects.size()>100: visual_effects.pop_front()
            if six_armies:
                if bool(entry["linked"]):
                    source["linked_hits"] += actual_damage
                    if chapter.get("mode","")=="link" and source["side"]==0 and actual_damage>0 and _working_pair(source,find_unit(entry["partner_id"])):
                        source["joint_credit"]=float(source.get("joint_credit",0.0))+actual_damage
                        source["joint_partner"]=entry["partner_id"]
                        source["joint_time"]=battle_time
                if float(entry["counter"])>1.01: source["counter_damage"] += actual_damage
                if bool(entry["flank"]): source["flank_damage"] += actual_damage
        var morale_loss: float = 0.11 if bool(entry["flank"]) else 0.07
        defender["morale"] = maxf(0.0, float(defender["morale"]) - pressure_damage * morale_loss)
        if float(defender["troops"]) <= 0.0:
            _morale_news(1-defender["side"],defender["pos"],18.0,"적 군단 전멸")
            _log("%s 전멸" % str(defender["name"]))
            for ally in units:
                if int(ally["side"]) == int(defender["side"]) and float(ally["troops"]) > 0.0 and (ally["pos"] as Vector2).distance_to(defender["pos"]) < 180.0:
                    ally["morale"] = maxf(0.0, float(ally["morale"]) - 12.0)
    if not combat_contacts.is_empty():
        combat_history.append({"time":battle_time,"contacts":combat_contacts.values()})

# Place one representative body when real, accumulated battle losses cross a threshold.
# Sample the victim's formation before removing the last file of a destroyed unit.
func _take_combat_loss(unit: Dictionary, damage: float, origin: Vector2, melee: bool) -> void:
    var previous: float = unit["casualties_taken"]
    var total := previous + damage
    var first := floori(previous / LOSSES_PER_FALLEN)
    var last := floori(total / LOSSES_PER_FALLEN)
    if last > first:
        var slots := formation_slots(unit)
        if slots.is_empty(): slots.append(unit["pos"])
        if melee:
            slots.sort_custom(func(a: Vector2, b: Vector2): return a.distance_squared_to(origin) < b.distance_squared_to(origin))
        var available := ceili(slots.size() * 0.5) if melee else slots.size()
        for number in range(first, last):
            var index: int = number * 37 + int(unit["id"]) * 13
            var angle := fmod(index * 2.39996, TAU)
            var point := slots[index % available] + Vector2.from_angle(angle) * (2.0 + index % 6)
            if long_operation: point = _dry_formation_slot(unit["pos"], point)
            if in_open_water(point): point = unit["pos"]
            if in_open_water(point): continue
            fallen_marks.append({"point": _field_point(point), "side": unit["side"], "kind": unit["type"],
                "pose": number % 3, "angle": angle, "time": battle_time})
    unit["casualties_taken"] = total
    unit["troops"] = maxf(0.0, float(unit["troops"]) - damage)

func _bow_effectiveness(unit: Dictionary, contacts: int, distance: float, ammo_fraction: float, screened: bool) -> float:
    var full_ranks: int=clampi(ceili(float(unit["troops"])/180.0),1,24) if six_armies else 12
    var frontage: float=lerpf(0.52,1.0,clampf(float(contacts)/full_ranks,0.0,1.0))
    var range_factor: float=lerpf(1.0,0.76,smoothstep(90.0,220.0,distance))
    var movement: float=lerpf(1.0,0.80,smoothstep(8.0,42.0,float(unit["motion_speed"])))
    return frontage*range_factor*movement*ammo_fraction*(0.76 if screened else 1.0)

func _bow_lane_screened(archer: Dictionary, enemy: Dictionary, targets: Dictionary) -> bool:
    var origin: Vector2=archer["pos"]
    var destination: Vector2=enemy["pos"]
    var axis: Vector2=destination-origin
    var span: float=axis.length()
    if span<55.0: return false
    var direction: Vector2=axis/span
    for ally in units:
        if ally["side"]!=archer["side"] or ally["type"]=="궁병" or bool(ally["routed"]): continue
        var attacking: Dictionary=targets.get(int(ally["id"]),{})
        if attacking.is_empty() or attacking["id"]!=enemy["id"]: continue
        var offset: Vector2=(ally["pos"] as Vector2)-origin
        var depth: float=offset.dot(direction)
        if depth<15.0 or depth>span-5.0 or absf(offset.dot(direction.orthogonal()))>28.0: continue
        if _river_separates(ally["pos"],destination): continue
        if formation_contacts(ally,enemy,30.0)>0: return true
    return false

func _braced_for_charge(unit: Dictionary, direction: Vector2) -> bool:
    return unit["type"]=="보병" and unit["formation"]=="방진" and unit["next_formation"]=="" and (
        float(unit["motion_speed"])<8.0 and float(unit["cohesion"])>=62.0 and float(unit["morale"])>=38.0
        and direction.dot(unit["facing"])>=0.42 and not bool(unit["routed"]))

# Choose actual firing files from different parts of the front for the volley
# effect. Only files with a defending slot in range can contribute a lane.
func _bow_visual_lanes(archer: Dictionary, defender: Dictionary, fallback: Array[Vector2]) -> Array[Vector2]:
    var firing: Array[Vector2]=formation_slots(archer)
    var receiving: Array[Vector2]=formation_slots(defender)
    var lanes: Array[Vector2]=[fallback[0],fallback[1]]
    if firing.is_empty() or receiving.is_empty(): return lanes
    var lateral: Vector2=((defender["pos"] as Vector2)-(archer["pos"] as Vector2)).normalized().orthogonal()
    firing.sort_custom(func(a: Vector2,b: Vector2)->bool: return a.dot(lateral)<b.dot(lateral))
    for slot in [firing.front(),firing.back()]:
        if (slot as Vector2).distance_squared_to(fallback[0])<14.0*14.0: continue
        var nearest: Vector2=Vector2.INF
        var distance_squared: float=173.0*173.0
        for target in receiving:
            var d: float=(slot as Vector2).distance_squared_to(target)
            if d<distance_squared:
                nearest=target
                distance_squared=d
        if nearest!=Vector2.INF:
            lanes.append(slot)
            lanes.append(nearest)
    return lanes


# Neutral strategic positions are optional field objectives. An uncontested unit
# must actually stand within range long enough to establish control; a contested
# point neither changes hands nor accumulates victory hold time.
func _update_outposts(dt: float) -> void:
    for site in outposts + terrain_posts:
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
        site["contested"]=blue and red
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
            site["challenger"]=-1
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
            if site.has("terrain_post") and faction==1 and not player_can_see(site["pos"]): continue
            _log("%s: %s 점령" % [str(site["name"]), "아군" if faction == 0 else "적군"])

func objective_hold_duration() -> float:
    match scenario_id:
        1: return 45.0 if long_operation else (30.0 if wide_field else 18.0)
        4,TRAINING_SCENARIO: return 30.0 if long_operation else 12.0
    return 45.0 if long_operation and six_armies else OUTPOST_HOLD_SECONDS

func _secured_site_names(side: int) -> PackedStringArray:
    var names:=PackedStringArray()
    var count:=outposts.size() if scenario_id==0 else 1
    for i in range(count):
        var site: Dictionary=outposts[i]
        if site["owner"]==side and site["hold"]>=objective_hold_duration(): names.append(str(site["name"]))
    return names

func _objective_winner() -> int:
    if long_operation and battle_time < LONG_OBJECTIVE_OPEN: return -1
    if outposts.size() < 2 or turn < (6 if wide_field else 3):
        return -1
    if scenario_id == 1:
        if six_armies and battle_time < 125.0: return -1
        var central: Dictionary = outposts[0]
        if int(central["owner"]) >= 0 and float(central["hold"]) >= objective_hold_duration():
            return int(central["owner"])
        return -1
    if scenario_id in [2,3]:
        return -1
    if scenario_id in [4,TRAINING_SCENARIO]:
        if not structures.is_empty() and float(structures[0]["hp"]) <= 0.0 and int(outposts[0]["owner"]) == 0 and float(outposts[0]["hold"]) >= objective_hold_duration():
            return 0
        return -1
    if six_armies and scenario_id == 0:
        var secured: Array[int] = [0,0]
        for site in outposts:
            var faction: int = int(site["owner"])
            if faction >= 0 and float(site["hold"]) >= objective_hold_duration(): secured[faction] += 1
        for faction in range(2):
            if secured[faction] >= 2: return faction
        return -1
    var owner: int = int(outposts[0]["owner"])
    if owner < 0:
        return -1
    for site in outposts:
        if int(site["owner"]) != owner or float(site["hold"]) < objective_hold_duration():
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

func turn_duration() -> float:
    return 15.0 if long_operation else TURN_SECONDS

func commander_captured(side: int) -> bool:
    return commanders[side].get("captured",false)

func command_confused(side: int) -> bool:
    return battle_time+0.000001<float(commanders[side].get("recover_at",-1.0))

func command_status(side: int) -> String:
    if command_confused(side):
        var seconds:=ceili((float(commanders[side]["recover_at"])-battle_time)*operation_scale()-0.000001)
        return "책사 생포 · 지휘 혼란 %d초" % seconds
    return "책사 생포 · 장수 자율 지휘" if commander_captured(side) else ""

func _update_command_recovery() -> void:
    for c in commanders:
        if not c.has("recover_at") or command_confused(c["side"]): continue
        c.erase("recover_at")
        for u in units:
            if u["side"]==c["side"]: u["ai_cooldown"]=0.0
        _site_notice(c["side"],_camp_side(c["side"])+" 혼란 해소 · 장수 자율 지휘",c["pos"])

func _check_command_capture() -> void:
    for c in commanders:
        var side: int=c["side"]
        if commander_captured(side) or _nearby_corps(1-side,c["pos"],26.0)==0 or commander_guard_count(side)>0: continue
        c["captured"]=true
        c["goal"]=c["pos"]
        c["recover_at"]=battle_time+turn_duration()
        _site_notice(side,_camp_side(side)+" 책사 생포 · 하루 동안 지휘 혼란",c["pos"])
        for i in range(couriers.size()-1,-1,-1):
            var letter: Dictionary=couriers[i]
            if letter["side"]!=side: continue
            _resolve_map_dispatch(letter,"책사 생포")
            _response_delivery(letter,"책사 생포")
            couriers.remove_at(i)
        for u in units:
            if u["side"]!=side: continue
            _reset_cooperation(u,-1)
            u["ai_role_until"]=0.0
            u["tactical_until"]=0.0
            u["has_destination"]=false
            u["defense_set"]=false
            u["waypoints"].clear()
            u["mission"]="중앙 진격"
            u["policy"]="현장 판단"
            u["obedience"]="성향 기반"
            u["ai_cooldown"]=0.0
            if u["troops"]>0 and not u["routed"]: _decide(u)

# The watch samples only an enemy actually sighted on this side of the river.
# Its short memory bridges gaps between sightings without following a hidden raider.
func _scan_home_approach() -> void:
    var home:=headquarters[0]
    if chapter.is_empty() or battle_time<float(home.get("next_watch",0.0)): return
    home["next_watch"]=battle_time+1.0
    var point: Vector2=home["pos"]
    for enemy in units:
        if enemy["side"]!=1 or enemy["troops"]<=0 or enemy["routed"]: continue
        if point.distance_squared_to(enemy["pos"])>HQ_APPROACH_RADIUS*HQ_APPROACH_RADIUS: continue
        if (long_operation and _river_separates(point,enemy["pos"])) or not player_sees_enemy(enemy): continue
        if not home_approach_seen() and battle_time>=float(home.get("next_watch_notice",0.0)) and home["occupation"]==0:
            _field_notice("본진 경계 · 아군이 진입로 인근에서 적을 관측",point)
            home["next_watch_notice"]=battle_time+18.0
        home["watch_until"]=battle_time+3.0
        return

func home_approach_seen() -> bool:
    return battle_time<float(headquarters[0].get("watch_until",-1.0))

func home_guard_roster() -> String:
    var assigned:=PackedStringArray()
    var pending:=PackedStringArray()
    for id in command_ids(0):
        var u:=find_unit(id)
        if u["troops"]>0 and not u["routed"] and u["mission"]=="본진 방어" and u["has_destination"]:
            assigned.append(u["name"])
    for letter in couriers:
        if letter.get("map_dispatch",false) and letter["mission"]=="본진 방어":
            pending.append(find_unit(letter["unit_id"]).get("name","군단"))
    var text:="본진 주둔 %d개 군단" % _nearby_corps(0,_home_point(0),GUARD_RADIUS)
    if not assigned.is_empty(): text+="  ·  전담 "+", ".join(assigned)
    if not pending.is_empty(): text+="  ·  전령 이동 중 "+", ".join(pending)
    return text

func home_relief_candidate(exclude: Dictionary={}) -> int:
    var best:=-1
    var fastest:=INF
    var home:=_home_point(0)
    for id in command_ids(0):
        var u:=find_unit(id)
        if exclude.has(id) or u["troops"]<=0 or u["routed"] or u["reserve"] or has_pending_courier(id): continue
        if u["mission"]=="본진 방어" and u["has_destination"]: continue
        if started:
            if (u["pos"] as Vector2).distance_to(home)<=GUARD_RADIUS and (not long_operation or not _river_separates(u["pos"],home)): continue
            if u["surrounded"] or u["morale"]<38 or u["cohesion"]<35 or u["tactical_until"]>battle_time: continue
            if u["action"] in ["패주","후퇴","재집결","휴식","보급 복귀","탄약 보충","전술 철수","사기 혼란"]: continue
        var travel_time:=_relief_travel_distance(u,home)/_movement_rate(u,_nearest_visible_enemy(u))
        if travel_time<fastest:
            fastest=travel_time
            best=id
    return best

# Occupation is measured at the current headquarters.
func _update_headquarters(dt: float) -> void:
    _scan_home_approach()
    for home in headquarters:
        if home["occupied"]: continue
        var side: int=home["side"]
        var attacked:=_nearby_corps(1-side,home["pos"],RAID_RADIUS)>0
        var exposed:=attacked and _nearby_corps(side,home["pos"],GUARD_RADIUS)==0
        var prior: float=home["occupation"]
        home["occupation"]=minf(HQ_CAPTURE_SECONDS,prior+dt) if exposed else 0.0
        home["occupied"]=home["occupation"]>=HQ_CAPTURE_SECONDS-0.00001
        if side==0 and prior==0.0 and exposed:
            _field_notice("아군 본진 피습 · 수비군 필요",home["pos"])
        elif side==0 and prior>0.0 and not exposed:
            _field_notice("아군 본진 점거 저지",home["pos"])

func headquarters_state(side: int) -> String:
    var home:=headquarters[side]
    if home["occupied"]: return "함락"
    if home["occupation"]>0: return "함락까지 %d초" % ceili((HQ_CAPTURE_SECONDS-home["occupation"])*operation_scale()-0.00001)
    if side==0 and _nearby_corps(side,home["pos"],GUARD_RADIUS)==0: return "주둔군 없음"
    return "수비 중"

func _check_victory() -> void:
    if finished:
        return
    for side in range(2):
        if headquarters[side]["occupied"] and not (side==1 and chapter.get("mode","") in ["capital","siege"]):
            _finish("아군 본진 함락 — 패배" if side==0 else "적 본진 함락 — 아군 승리","%s 본진 · 적이 %d초 연속 점거" % [_camp_side(side),roundi(HQ_CAPTURE_SECONDS*operation_scale())])
            return
    _check_command_capture()
    if not chapter.is_empty():
        NorthernField.victory(self)
        return
    if scenario_id == 3 and not convoy.is_empty():
        if float(convoy["hp"]) <= 0.0:
            _finish("군량 수레 파괴 — 패배","군량 수레 내구도 0%")
            return
        if (convoy["pos"] as Vector2).distance_to(convoy["goal"]) < 12.0:
            _finish("군량 수레 호위 성공 — 아군 승리","동쪽 도착점 도달 · 수레 내구도 %d%%" % ceili(convoy["hp"]))
            return
    var winner: int = _objective_winner()
    var held: String=""
    if winner>=0:
        held="%s · %d초 연속 유지" % [", ".join(_secured_site_names(winner)),roundi(objective_hold_duration()*operation_scale())]
        if scenario_id in [4,TRAINING_SCENARIO]: held="성문 파괴 · "+held
    if scenario_id==TRAINING_SCENARIO:
        if winner==0: _finish("시험장 거점 확보 — 아군 승리",held)
        elif battle_time>=scenario_limit: _finish("훈련 종료 — 제한 시간 내 거점 확보 실패 (패배)",_siege_result_detail())
        return
    if winner == 0 and scenario_id == 4:
        _finish("천수 돌파 성공 — 아군 승리",held)
        return
    if winner >= 0:
        _finish(("양측 요충지 확보 — 아군 승리" if winner == 0 else "적 요충지 장악 — 패배") if scenario_id == 0 else ("중앙 고지 확보 — 아군 승리" if winner == 0 else "적 중앙 고지 장악 — 패배"),held)
        return

    var side_alive: Array[int] = [0, 0]
    for unit in units:
        if float(unit["troops"]) > 0.0 and not bool(unit["routed"]):
            side_alive[int(unit["side"])] += 1
    if side_alive[0] == 0:
        if reinforcements_used[0] >= reserve_limit[0]:
            _finish("아군 전투부대 전멸 또는 패주 — 패배","전투 가능 부대 · 아군 %d / 적군 %d" % side_alive)
    elif side_alive[1] == 0:
        if reinforcements_used[1] >= reserve_limit[1]:
            _finish("적 전투부대 전멸 또는 패주 — 승리","전투 가능 부대 · 아군 %d / 적군 %d" % side_alive)
    if not finished and scenario_id == 2 and battle_time >= scenario_limit:
        _finish("본진 방어 성공 — 아군 승리","아군 본진 사수 · 방어 시간 %d초" % roundi(operation_limit()))
    if not finished and battle_time >= scenario_limit and scenario_id in [3,4]:
        _finish("작전 제한 시간 초과 — 패배",_siege_result_detail() if scenario_id==4 else "수레 이동 %d%% · 도착점까지 %d" % [floori(convoy_status()["progress"]*100.0),ceili(convoy_status()["remaining"])])
    if not finished and battle_time >= scenario_limit and six_armies and scenario_id == 0:
        var control: Array[int] = [0,0]
        for site in outposts:
            var faction: int = int(site["owner"])
            if faction >= 0: control[faction] += 1
        if control[0] != control[1]:
            _finish("작전 종료 — 거점 우세: %s" % ("아군" if control[0]>control[1] else "적군"),"종료 시 점령 거점 · 아군 %d / 적군 %d" % control)
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
        _finish("시간 종료 — 전력 우세: %s" % ("아군" if blue >= red else "적군"),"패주 병력 제외 · 아군 %d명 / 적군 %d명" % [roundi(blue),roundi(red)])

func _siege_result_detail() -> String:
    var gate: Dictionary=structures[0]
    var hold: float=minf(outposts[0]["hold"],objective_hold_duration()) if outposts[0]["owner"]==0 else 0.0
    return "성문 내구도 %d%% · 아군 거점 유지 %d/%d초" % [ceili(100.0*gate["hp"]/gate["max_hp"]),floori(hold*operation_scale()),roundi(objective_hold_duration()*operation_scale())]

func _finish(msg: String, evidence: String="") -> void:
    if finished:
        return
    result = msg
    result_detail = evidence
    winning_side = 1 if "패배" in msg or msg.ends_with("적군") else 0
    finished = true
    _update_response_outcomes()
    _log("전투 종료: %s" % msg)

func validate_state() -> Array[String]:
    var problems: Array[String] = []
    if is_nan(battle_time) or is_inf(battle_time) or battle_time < 0.0:
        problems.append("invalid elapsed time")
    var opening_count:int=FIELD_CORPS*2 if chapter.is_empty() else 12+int(chapter["enemy_count"])
    if units.size() > (opening_count+reserve_limit[0]+reserve_limit[1] if six_armies else 16):
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
    if mission=="자유 재량":
        var best: Dictionary={}
        var cost:=INF
        for post in outposts:
            var owned: bool=post["owner"]==unit["side"]
            var score: float=Vector2(unit["pos"]).distance_to(post["pos"])
            if owned: score+=(-140.0 if unit["personality"]=="신중" else 420.0)
            if score<cost: cost=score; best=post
        return best
    if outposts.size() < 2:
        return {}
    if six_armies and scenario_id == 0 and mission == "중앙 진격" and outposts.size() >= 3:
        return outposts[2]
    if scenario_id in [1,4,TRAINING_SCENARIO] and mission == "중앙 진격":
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
    var base:=_nearest_base(side,p,true)
    if not base.is_empty():
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
        if ally.get("opening_screen",-1)==unit["id"]: continue
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
        if long_operation and battle_time-float(unit["last_arrow_hit"])<1.2: safe=false
        var recovery: bool = str(unit["action"]) in ["재집결", "휴식", "방어", "거점 방어", "거리 유지", "긴급 방어", "전술 재집결","지정 지역 사수","예비 대기","협동 대기"]
        if safe and recovery:
            unit["fatigue"] = maxf(0.0, float(unit["fatigue"]) - dt * 2.1)
            unit["cohesion"] = minf(100.0, float(unit["cohesion"]) + dt * (2.6 if bool(unit["supplied"]) else 1.1) * (0.55 + _effective_stat(unit, "leadership") * 0.006))
        elif safe:
            unit["cohesion"] = minf(100.0, float(unit["cohesion"]) + dt * 0.25)
        unit["cohesion"] = maxf(0.0, float(unit["cohesion"]) - dt * float(unit["front_pressure"]) * 0.65)
        var commander: Dictionary = commanders[int(unit["side"])]
        if not long_operation and safe and not commander_captured(unit["side"]) and p.distance_to(commander["pos"]) < 125.0 and float(unit["rations"]) > 20.0:
            unit["morale"] = minf(100.0, float(unit["morale"]) + dt * 0.75)
        if float(unit["rations"]) < 20.0:
            unit["morale"] = maxf(0.0, float(unit["morale"]) - dt * 0.35)

func _combat_target(unit: Dictionary) -> Dictionary:
    var nearest: Dictionary = _nearest_visible_enemy(unit)
    if six_armies and not nearest.is_empty():
        var choice: Dictionary=unit.get("field_choice",{})
        if not choice.is_empty():
            var priority: Dictionary=find_unit(choice["target"])
            if not priority.is_empty() and not priority["routed"] and _locally_observed(unit,priority):
                if unit["type"]=="궁병" and (unit["pos"] as Vector2).distance_to(priority["pos"])<=173.0: return priority
                if unit["type"]!="궁병" and not _river_separates(unit["pos"],priority["pos"]) and formation_contacts(unit,priority,30.0)>0: return priority
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
    return headquarters[side]["pos"]

func _enforce_orders(unit: Dictionary, action: String, reason: String, goal: Vector2, enemy_distance: float) -> Dictionary:
    var result_order: Dictionary = {"action":action, "reason":reason, "goal":goal}
    if unit["mission"]=="자유 재량": return result_order
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
        var sight := _scout_sight(p,side)
        for enemy in units:
            if int(enemy["side"]) == side or float(enemy["troops"]) <= 0.0 or bool(enemy["routed"]):
                continue
            var d: float = p.distance_to(enemy["pos"])
            if d < threat_d and d < sight * unit_exposure(enemy):
                threat = enemy
                threat_d = d
        if threat_d < 23.0:
            scout["alive"] = false
            _log("%s 정찰대 차단" % ("아군" if side == 0 else "적군"))
            continue
        scout["report_timer"] = maxf(0.0, float(scout["report_timer"]) - dt)
        if not threat.is_empty() and float(scout["report_timer"]) <= 0.0:
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

func _can_run_in(unit: Dictionary, enemy: Dictionary, pos: Vector2, goal: Vector2) -> bool:
    if enemy.is_empty() or unit["routed"] or unit["charge_cooldown"] > 0 or unit["contact_troops"] > 0: return false
    # A map attack first uses "지정 위치 이동" until the destination is secured.
    if unit["action"] in ["지정 위치 이동", "명령 수행", "진격"]:
        if unit["mission"] != "공격" or not unit["has_destination"]: return false
        if (unit["order_destination"] as Vector2).distance_to(enemy["pos"]) >= 240.0: return false
    elif unit["action"] not in ["돌파", "교전", "반격", "공격 지속", "측면 우회", "협동 우회"]:
        return false
    if terrain_at(pos) not in ["평지", "도로", "고지"]: return false
    return pos.direction_to(goal).dot(pos.direction_to(enemy["pos"])) >= 0.72

func _update_charge(unit: Dictionary, moved: Vector2, dt: float, running_in: bool) -> void:
    var speed := moved.length() / maxf(dt, 0.001)
    if not running_in or speed <= 48.0 or terrain_at(unit["pos"]) not in ["평지", "도로", "고지"]:
        unit["charge"] = 0.0
        unit["charge_speed"] = 0.0
        return
    var direction := moved.normalized()
    if direction.dot(unit["charge_dir"]) < 0.82:
        unit["charge"] = 0.0
    unit["charge"] = minf(110.0, float(unit["charge"]) + moved.length())
    unit["charge_dir"] = direction
    unit["charge_speed"] = speed

func _charge_impact(unit: Dictionary, enemy: Dictionary) -> float:
    var distance_run: float = float(unit["charge"])
    var target_dir: Vector2 = ((enemy["pos"] as Vector2) - (unit["pos"] as Vector2)).normalized()
    if distance_run < 32.0 or float(unit["charge_speed"]) < 40.0 or target_dir.dot(unit["charge_dir"]) < 0.72:
        return 0.0
    if long_operation and not structures.is_empty() and _detour_goal(unit, unit["pos"], enemy["pos"]) != enemy["pos"]:
        return 0.0
    var impact: float = minf(9.0, distance_run * 0.075) * (float(unit["troops"]) / maxf(1.0, float(unit["initial_troops"])))
    if long_operation:
        impact *= lerpf(1.0, 1.4, smoothstep(72.0, 150.0, unit["charge_speed"]))
    if six_armies and unit["formation"] == "봉시진" and unit["next_formation"] == "":
        var alignment: float = Vector2(unit["facing"]).dot(target_dir)
        impact *= 1.0+0.16*smoothstep(0.72,0.96,alignment)*smoothstep(40.0,90.0,unit["cohesion"])
    impact *= 0.3 if str(enemy["formation"]) == "방진" else 1.0
    if _in_forest(enemy["pos"]):
        impact *= 0.45
    return maxf(0.0, impact)

func _encirclement(unit: Dictionary, observed: Array = []) -> bool:
    var p: Vector2 = unit["pos"]
    var rear: Vector2 = Vector2.LEFT if int(unit["side"]) == 0 else Vector2.RIGHT
    var bearings: Array[Vector2] = []
    var retreat_blocked: bool = false
    for enemy in (units if observed.is_empty() else observed):
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
        var expected: int = FIELD_CORPS if six_armies else 3
        if not chapter.is_empty(): expected=12 if side==0 else int(chapter["enemy_count"])
        if active >= expected and ratio > float(expected)*0.72 and pressure < 0.45 and (long_operation or turn < 5):
            continue
        reinforcements_used[side] += 1
        reserve_next[side] = battle_time + 22.0
        var home: Vector2 = _home_point(side)
        var entrance:=_field_point(home + Vector2(0,float(reinforcements_used[side] - 1) * 52.0))
        if _buildable_ground(entrance): home=entrance
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
    var resolute: bool=not Skills.current(unit,["stand"]).is_empty() if unit.has("skill_ids") else false
    if long_operation and unit["morale"]<=0 and not resolute and not unit.get("demoralized",false):
        unit["demoralized"]=true
        unit["panic_until"]=battle_time+2.5
        _site_notice(unit["side"],str(unit["name"])+" 사기 붕괴 · 혼란과 탈주",unit["pos"])
    elif unit["morale"]>0: unit["demoralized"]=false
    var broken: bool = float(unit["morale"]) < 14.0 or (float(unit["cohesion"]) < 14.0 and float(unit["morale"]) < 37.0)
    if broken and resolute:
        unit["field_skill"]["stat"]["effect"]+=dt*operation_scale()
    if broken and not resolute and not bool(unit["routed"]):
        unit["routed"] = true
        unit["rout_count"] = int(unit["rout_count"]) + 1
        unit["action"] = "패주"
        unit["reason"] = "전열과 사기 붕괴"
        unit["goal"] = _home_point(int(unit["side"]))
        unit["raid_active"] = false
        unit["ai_cooldown"] = 0.0
        _log("%s: 명령 통제 상실 및 패주" % str(unit["name"]))
    if bool(unit["routed"]):
        if battle_time<float(unit.get("panic_until",-1.0)):
            unit["action"]="사기 혼란"
            unit["reason"]="사기 붕괴 · 병사 탈주"
            unit["goal"]=unit["pos"]
        var lost: float = minf(float(unit["troops"]), dt * (0.85 if unit.get("demoralized",false) else (0.45 if bool(unit["surrounded"]) else 0.15))*(ARMY_SCALE if six_armies else 1.0))
        unit["troops"] = maxf(0.0, float(unit["troops"]) - lost)
        unit["deserted"] = float(unit["deserted"]) + lost
        var p: Vector2 = unit["pos"]
        var threat: Dictionary = _nearest_visible_enemy(unit)
        if p.distance_to(_home_point(int(unit["side"]))) < 75.0 and (threat.is_empty() or p.distance_to(threat["pos"]) > 125.0):
            if not long_operation: unit["morale"] = minf(100.0,float(unit["morale"])+dt*(0.8+_effective_stat(unit,"leadership")*0.014))
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
    scenario_id = clampi(index, 0, TRAINING_SCENARIO)
    if scenario_id==TRAINING_SCENARIO: wide_field=true
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
        scenario_title = "본진 사수"
        scenario_goal = "120초 동안 아군 본진 사수"
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
        outposts[0]["name"] = "천수 성문 뒤 진입로"
        outposts[0]["pos"] = Vector2(705,282)
        for unit in units:
            if str(unit["type"]) == "보병": unit["mission"] = "중앙 진격"
    elif scenario_id==TRAINING_SCENARIO:
        scenario_title="지형 시험장"
        scenario_goal="연습 성문을 열고 동쪽 거점 확보"
        hill=Rect2(460,129,150,90)
        forests=[Rect2(175,48,98,90),Rect2(485,345,130,110)]
        outposts[0]["name"]="동쪽 훈련 거점"
        outposts[0]["pos"]=Vector2(709,282)
        outposts[1]["name"]="습지 관측소"
        outposts[1]["pos"]=Vector2(337,238)

# The survey uses actual map locations, including the current supply base.
func training_sites() -> Dictionary:
    if scenario_id!=TRAINING_SCENARIO: return {}
    return {"갈대밭":FieldGeometry.REEDBEDS[scenario_id][0].get_center(),"평지":Vector2(360,615),"도로":Vector2(520,road_y(520,1)),
        "숲":forests[0].get_center(),"고지":hill.get_center(),"습지":FieldGeometry.TRAINING_MARSHES[0].get_center(),
        "하천":Vector2(river_x(612),612),"북측 교량":Vector2(river_x(390),390),
        "중앙 교량":Vector2(river_x(850),850),"남측 교량":Vector2(river_x(1300),1300),
        "성문":(structures[0]["rect"] as Rect2).get_center(),"목책":(structures[1]["rect"] as Rect2).get_center(),
        "보급기지":bases[0]["pos"],"점령 거점":outposts[0]["pos"]}

func field_survey_sites() -> Dictionary:
    if scenario_id == TRAINING_SCENARIO: return training_sites()
    if not wide_field: return {}
    return {"습지": marshes[0].get_center(), "갈대밭": reedbeds[0].get_center(),
        "숲": forests[0].get_center(), "고지": hill.position + hill.size * Vector2(0.15, 0.5)}

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
    var fields:=["name","personality","ability","leadership","martial","intelligence","judgment","loyalty","deputy_index","specialty"]
    if first.has("skill_ids") and second.has("skill_ids"): fields.append_array(["skill_ids","field_skill","skill_stats","skill_ready"])
    for key in fields:
        var temporary: Variant = first[key]
        first[key] = second[key]
        second[key] = temporary
    return true

# These staging points follow the actual scenario geometry. Victory sites stay
# separate so that adding a bridgehead never alters a scenario's win condition.
func _map_terrain_posts() -> void:
    terrain_posts.clear()
    if not wide_field: return
    var lanes := ["북로","중로","남로"]
    for i in range(3):
        var crossing: float=[390.0,850.0,1300.0][i]
        var bridge:=Vector2(river_x(crossing),crossing)
        for bank in [-1,1]:
            _add_terrain_post(lanes[i]+(" 서안" if bank<0 else " 동안"),bridge+Vector2(126*bank,0))
        var stage_x: float=[630.0,2020.0,820.0][i]
        _add_terrain_post(lanes[i]+" 집결지",Vector2(stage_x,road_y(stage_x,i)))
    _add_terrain_post("고지 관측소",hill.get_center())
    for i in range(forests.size()):
        _add_terrain_post("숲길 %d" % (i+1),forests[i].get_center())
    if not reedbeds.is_empty(): _add_terrain_post("갈대길 입구",reedbeds[0].get_center())
    for fort in structures:
        var wall: Rect2=fort["rect"]
        _add_terrain_post(str(fort["name"])+" 접근로",Vector2(wall.position.x-70,wall.get_center().y))

func _add_terrain_post(title: String, near: Vector2) -> void:
    for offset: Vector2 in [Vector2.ZERO,Vector2(0,-70),Vector2(0,70),Vector2(-85,0),Vector2(85,0),Vector2(0,-135),Vector2(0,135)]:
        var point:=_field_point(near+offset)
        if not _buildable_ground(point): continue
        var clear:=true
        for other in outposts+terrain_posts:
            if point.distance_to(other["pos"])<65.0: clear=false; break
        if clear:
            terrain_posts.append({"name":title,"pos":point,"terrain_post":true,"owner":-1,"challenger":-1,"progress":0.0,"hold":0.0})
            return

# Temporary flags are planning references. Only scenario outposts score objectives.
func planning_sites() -> Array[Dictionary]:
    return outposts + terrain_posts + temporary_sites

func headquarters_move_issue() -> String:
    if finished: return "작전이 종료되었습니다."
    if commander_captured(0): return "책사 생포 중에는 본진을 이전할 수 없습니다."
    if not started: return ""
    if turn < next_hq_day: return "%d일차부터 본진을 이전할 수 있습니다." % next_hq_day
    if headquarters[0]["occupation"] > 0 or _nearby_corps(1,_home_point(0),RAID_RADIUS) > 0:
        return "본진 피습 중에는 이전할 수 없습니다."
    return ""

func post_placement_issue(post: String, point: Vector2) -> String:
    if finished: return "작전이 종료되었습니다."
    if post not in ["보급기지","본진","책사","임시 거점"]: return "설치할 대상을 선택하세요."
    var hq := post in ["본진","책사"]
    if hq:
        var unavailable := headquarters_move_issue()
        if not unavailable.is_empty(): return unavailable
    elif started and post == "보급기지": return "개전 전에만 첫 기지를 배치할 수 있습니다."
    elif started and commander_captured(0): return "책사 생포 중에는 거점을 세울 수 없습니다."
    if not point.is_finite() or _field_point(point) != point: return "전장 안의 땅을 선택하세요."
    if not started and post != "임시 거점" and point.x > field_size.x*0.5:
        return "지도 서쪽의 아군 배치 구역을 선택하세요."
    if not _buildable_ground(point): return "하천·다리·습지·구조물을 벗어난 땅을 선택하세요."
    if post == "임시 거점":
        for site in planning_sites():
            if point.distance_to(site["pos"]) < 26.0: return "이미 작전 거점이 있습니다."
    if hq:
        if point.distance_to(_home_point(0)) < 1.0: return "현재 본진 위치입니다."
        if started:
            if _nearby_corps(1,point,GUARD_RADIUS)>0 or point.distance_to(_home_point(1))<=GUARD_RADIUS:
                return "적이 점거한 위치입니다."
            if point.x > field_size.x*0.5 and _nearby_corps(0,point,GUARD_RADIUS)==0:
                return "동쪽에서는 아군 군단 곁에 본진을 세우세요."
    return ""

func place_post(post: String, point: Vector2) -> bool:
    if not post_placement_issue(post,point).is_empty(): return false
    if post == "임시 거점":
        temporary_sites.append({"name":"임시 거점 %d" % (temporary_sites.size()+1),"pos":point})
    elif post in ["본진","책사"]:
        headquarters[0]["pos"] = point
        for key in ["watch_until","next_watch","next_watch_notice"]: headquarters[0].erase(key)
        for dispatch in map_dispatches.values():
            if dispatch["mission"]=="본진 방어": dispatch["destination"]=point
        commanders[0]["pos"] = point
        commanders[0]["goal"] = point
        for unit in units:
            if unit["side"] != 0 or unit["mission"] != "본진 방어": continue
            if unit["has_destination"]: unit["order_destination"]=point
            if unit["defense_set"] and unit.has("hq_defense_offset"):
                unit["defense_anchor"] = _field_point(point + Vector2(unit["hq_defense_offset"]))
            unit["ai_cooldown"] = 0.0
        if started:
            next_hq_day = turn + HQ_MOVE_INTERVAL
            _field_notice("본진·책사 이전 완료 · 다음 이전 %d일차" % next_hq_day,point)
    else:
        var base: Dictionary=bases[0]
        supply_crews[0]["pos"]=point
        supply_crews[0]["goal"]=point
        base["pos"]=point
        base["state"]="착공 예정"
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
    unit.erase("hq_defense_offset")
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
            if side==0:
                var key: String="정찰:%d" % id
                if battle_time-float(situation_keys.get(key,-100.0))>=30.0:
                    situation_keys[key]=battle_time
                    _field_notice("정찰 보고 · 적 위치 관측 / 신뢰도 %d%%" % roundi(report["confidence"]*100.0),report["pos"])
        pending_reports.remove_at(i)

func player_can_see(position: Vector2, concealed: bool = false) -> bool:
    return _player_observes(position, 0.60 if concealed else 1.0)

func player_sees_enemy(unit: Dictionary) -> bool:
    return _player_observes(unit["pos"], unit_exposure(unit))

func _player_observes(position: Vector2, factor: float) -> bool:
    if not commander_captured(0) and _within_watch(commanders[0]["pos"],position,170.0,factor): return true
    for unit in units:
        if unit["side"] == 0 and unit["troops"] > 0 and not unit["routed"] and _within_watch(unit["pos"],position,_corps_watch(unit),factor): return true
    for scout in scouts:
        if scout["side"] == 0 and scout["alive"] and _within_watch(scout["pos"],position,145.0,factor): return true
    return false

func _corps_watch(unit: Dictionary) -> float:
    return 200.0 * (0.85 + _effective_stat(unit,"intelligence") * 0.002)

func _watch_range(origin: Vector2, radius: float) -> float:
    return radius * terrain_sight_factor(origin) * watch_factor(origin,0)

func _within_watch(origin: Vector2, point: Vector2, radius: float, factor: float) -> bool:
    var distance := origin.distance_squared_to(point)
    if distance > pow(radius * factor * 1.5,2.0): return false
    return distance <= pow(_watch_range(origin,radius) * factor,2.0)

func _scout_sight(point: Vector2, side: int) -> float:
    return 190.0 * terrain_sight_factor(point) * watch_factor(point,side)

# The learning overlay uses the same detection distances as autonomous decisions.
func enemy_watch_posts() -> Array[Vector3]:
    var sources: Array[Vector3]=[]
    for unit in units:
        if unit["side"]!=1 or unit["troops"]<=0 or unit["routed"]: continue
        var p: Vector2=unit["pos"]
        sources.append(Vector3(p.x,p.y,_vision_range(unit)))
    for scout in scouts:
        if scout["side"]!=1 or not scout["alive"]: continue
        var p: Vector2=scout["pos"]
        sources.append(Vector3(p.x,p.y,_scout_sight(p,1)))
    return sources

func player_watch_posts() -> Array[Vector3]:
    var sources: Array[Vector3] = []
    if not commander_captured(0):
        var p: Vector2 = commanders[0]["pos"]
        sources.append(Vector3(p.x,p.y,_watch_range(p,170.0)))
    for unit in units:
        if unit["side"] == 0 and unit["troops"] > 0 and not unit["routed"]:
            var p: Vector2 = unit["pos"]
            sources.append(Vector3(p.x,p.y,_watch_range(p,_corps_watch(unit))))
    for scout in scouts:
        if scout["side"] == 0 and scout["alive"]:
            var p: Vector2 = scout["pos"]
            sources.append(Vector3(p.x,p.y,_watch_range(p,145.0)))
    return sources

func timeline_text() -> String:
    var lines: PackedStringArray = []
    for entry in timeline:
        lines.append("%05.1f초 | %02d일차 | %s" % [float(entry["time"])*operation_scale(),int(entry["turn"]),str(entry["message"])])
    return "\n".join(lines)

func request_deputy_takeover(unit_id: int) -> bool:
    var unit: Dictionary = find_unit(unit_id)
    if not started or finished or commander_captured(0) or turn < COURIER_TURN or unit.is_empty() or int(unit["side"]) != 0 or float(unit["troops"]) <= 0.0 or bool(unit["active_deputy"]):
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
    if scenario_id in [4,TRAINING_SCENARIO]:
        structures.append({"name":"연습 성문" if scenario_id==TRAINING_SCENARIO else "천수 성문","side":1,"rect":Rect2(640,245,22,76),"hp":105.0,"max_hp":105.0,"kind":"성문"})
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
            if int(unit["side"]) == int(structure["side"]) or not _can_attack_troops(unit):
                continue
            if not bounds.has_point(unit["pos"]):
                continue
            var power: float = 5.0 if str(unit["type"]) == "보병" else (2.0 if str(unit["type"]) == "궁병" else 3.0)
            var damage: float = minf(float(structure["hp"]),power*dt*float(unit["troops"])/maxf(1.0,float(unit["initial_troops"])))
            if unit.has("skill_ids"):
                var skill:=Skills.current(unit,["siege"])
                if not skill.is_empty():
                    var extra:=minf(float(structure["hp"])-damage,damage*float(skill["power"]))
                    damage+=extra
                    skill["stat"]["effect"]+=extra
            structure["hp"] = maxf(0.0,float(structure["hp"])-damage)
            unit["structure_damage"] = float(unit["structure_damage"])+damage
            if battle_time-float(unit["last_visual"]) >= 0.65:
                unit["last_visual"] = battle_time
                visual_effects.append({"from":unit["pos"],"to":center,"attacker_id":int(unit["id"]),"side":unit["side"],"kind":"근접","time":battle_time})
            if float(structure["hp"]) <= 0.0:
                _log(str(structure["name"])+" 파괴: 통행 가능")
                break

func merit(unit: Dictionary) -> int:
    return maxi(0,int(round(float(unit["damage_dealt"])*2.0/(ARMY_SCALE if six_armies else 1.0) + float(unit["objective_time"])*0.8 + float(unit["supply_guard_time"])*0.4 + float(unit["structure_damage"]) - float(unit["deserted"])/(ARMY_SCALE if six_armies else 1.0))))

# Default rear guard is chosen from eligible infantry near the actual commander.
# A deliberate player map order is never silently reassigned to rear guard.
func _escort_rearguard(side: int) -> int:
    if commander_captured(side): return -1
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
        convoy["hp"] = maxf(0.0,float(convoy["hp"])-dt*float(situation["strikers"])* (0.8 if guards > 0 else 3.5))
        convoy["blocked_seconds"] = float(convoy.get("blocked_seconds",0.0))+dt
    elif guards == 0:
        convoy["unguarded_seconds"] = float(convoy.get("unguarded_seconds",0.0))+dt
    else:
        convoy["pos"] = p.move_toward(convoy["goal"],dt*(7.5 if long_operation else (25.0 if wide_field else 16.0)))
        convoy["moving_seconds"] = float(convoy.get("moving_seconds",0.0))+dt

# Shared, actual-position rules for the capture check and the player display.
func commander_guard_count(side: int) -> int:
    if commander_captured(side): return 0
    var count: int = 0
    var origin: Vector2 = commanders[side]["pos"]
    for unit in units:
        if int(unit["side"]) == side and float(unit["troops"]) > 0.0 and not bool(unit["routed"]):
            if (unit["pos"] as Vector2).distance_to(origin) < 76.0:
                count += 1
    return count

func _convoy_access(unit: Dictionary, wagon: Vector2) -> bool:
    var pos: Vector2 = unit["pos"]
    return (not wide_field or not _river_separates(pos, wagon)) and _detour_goal(unit, pos, wagon) == wagon

func convoy_status() -> Dictionary:
    if convoy.is_empty(): return {}
    var p: Vector2 = convoy["pos"]
    var destination: Vector2 = convoy["goal"]
    var guards: int = 0
    var attackers: int = 0
    var strikers := 0
    for unit in units:
        if float(unit["troops"]) <= 0.0 or bool(unit["routed"]): continue
        var distance: float = p.distance_to(unit["pos"])
        if int(unit["side"]) == 0:
            if distance < 125.0 and _convoy_access(unit, p): guards += 1
        elif distance < 65.0 and unit["action"] in ["차단", "수레 공격"] and _convoy_access(unit, p):
            attackers += 1
            if distance <= 42.0 and unit["action"] == "수레 공격": strikers += 1
    var length: float = maxf(1.0,layout_point(Vector2(100,282)).distance_to(destination))
    var progress: float = clampf(1.0-p.distance_to(destination)/length,0.0,1.0)
    var state: String = "파괴" if float(convoy["hp"])<=0.0 else ("도착" if p.distance_to(destination)<12.0 else ("교전 정체" if attackers>0 else ("호위 대기" if guards==0 else ("호위 이동" if started else "출전 준비"))))
    return {"guards":guards,"attackers":attackers,"strikers":strikers,"progress":progress,"remaining":p.distance_to(destination),"state":state}

# Read-only route preview for the selected army. Never picks a new bridge.
func committed_route_preview(unit: Dictionary) -> Array[Vector2]:
    var points: Array[Vector2] = []
    var p: Vector2 = unit["pos"]
    var goal: Vector2 = unit["goal"]
    var bridge: float = float(unit.get("bridge_y",-1.0))
    if long_operation and bridge>=0.0:
        var exit_bank: int = int(unit.get("bridge_bank",0))
        if exit_bank != 0 and _keep_bridge(p, goal, bridge, exit_bank):
            var next := _bridge_waypoint(p, bridge, exit_bank)
            var exit_point := Vector2(river_x(bridge) + exit_bank * 64.0, bridge)
            if next != exit_point: points.append(next)
            points.append(exit_point)
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
    if not started or finished or commander_captured(0):
        return false
    _finish("책사 철수 결정 — 패배","아군 철수 명령")
    return true


# Reports describe allied observations, arrive after a physical-distance delay,
# and expire. A report never grants live information about unseen enemies.
# The letter keeps the dispatch position. Only its bearer moves towards the strategist.
func _move_reporting_messengers(dt: float) -> void:
    for i in range(incoming_reports.size()-1,-1,-1):
        var report:=incoming_reports[i]
        if not report["urgent"] and commander_captured(report.get("side",0)):
            situation_reports.erase(report)
            incoming_reports.remove_at(i)
            continue
        if battle_time < report["written_at"]+2.0: continue
        var side: int=report.get("side",0)
        var destination: Vector2=headquarters[side]["pos"] if report["urgent"] else commanders[side]["pos"]
        if not _advance_rider(report["rider"],destination,dt): continue
        report["arrive"]=battle_time
        report["expires"]=battle_time+26.0
        report["status"]="작전 보고 수신" if report.has("objective_account") else "미대응"
        report.erase("rider")
        if report.has("objective_account"): NorthernField.receive(self,report)
        incoming_reports.remove_at(i)
        if side==0:
            if report["urgent"]: urgent_deliveries+=1
            _log("%s군 전령 도착 · %s" % [report["sender"],report["kind"]])
            messenger_arrived.emit(report["id"],report["sender"],report["kind"])

func _field_rider(position: Vector2, side: int, id: int) -> Dictionary:
    return {"id":id,"side":side,"pos":position,"bridge_y":-1.0,"bridge_bank":0,"bridge_crossings":0,"blocked_water_steps":0}

func _advance_rider(rider: Dictionary, destination: Vector2, dt: float) -> bool:
    var p: Vector2=rider["pos"]
    var waypoint:=destination
    if long_operation: waypoint=_committed_bridge_route(rider,p,destination)
    elif wide_field: waypoint=_crossing_route(p,destination)
    var next:=p.move_toward(waypoint,150.0*dt)
    rider["pos"]=_land_motion(rider,p,next) if long_operation else next
    return (rider["pos"] as Vector2).is_equal_approx(destination)

# Estimate the same bridge trip a messenger or responding unit would take.
func _relief_travel_distance(traveler: Dictionary, destination: Vector2) -> float:
    var p: Vector2 = traveler["pos"]
    var direct := p.distance_to(destination)
    if not long_operation or not _river_separates(p, destination): return direct
    var bridge := _choose_crossing(traveler, p, destination)
    var exit_bank := 1 if destination.x >= river_x(destination.y) else -1
    var entry := _bridge_waypoint(p, bridge, exit_bank)
    var exit_point := Vector2(river_x(bridge) + exit_bank * 64.0, bridge)
    return p.distance_to(entry) + entry.distance_to(exit_point) + exit_point.distance_to(destination)

func _send_relief_request(sender: Dictionary, report: Dictionary) -> void:
    var nearest: Dictionary={}
    var radius: float=480.0 if long_operation else 180.0
    var shortest := INF
    var rider:=_field_rider(sender["pos"],sender["side"],-11-report["id"]*3)
    for ally in units:
        if ally["side"]!=sender["side"] or ally["id"]==sender["id"] or ally.has("parent_id") or ally["troops"]<=0 or ally["reserve"] or ally["routed"]: continue
        if report.has("site"):
            if ally["mission"]=="본진 방어" or ally["defense_set"] or ally["has_destination"] or ally.has("post_watch") or ally["tactical_until"]>battle_time: continue
            if Vector2(ally["pos"]).distance_to(outposts[report["site"]]["pos"])<OUTPOST_RADIUS*2: continue
        if (sender["pos"] as Vector2).distance_to(ally["pos"]) >= radius: continue
        var distance := _relief_travel_distance(rider, ally["pos"])
        if distance < shortest:
            shortest = distance
            nearest = ally
    sender["last_relief_request"]=battle_time
    if nearest.is_empty():
        report["relief_destination"]="인근에 연락 가능한 군단 없음"
        return
    report["relief_destination"]=str(nearest["name"])+"에게 별도 구원 전령 파견"
    relief_riders.append({"rider":rider,"recipient":nearest["id"],"report":report,"returning":false})

func _relief_decision(ally: Dictionary, sender: Dictionary) -> String:
    if sender.is_empty() or sender["troops"]<=0: return "구원 대상 소멸"
    if ally["surrounded"] or ally["routed"] or ally["morale"]<38 or ally["cohesion"]<35: return "자군 전열 재정비"
    if sender.get("local_relief",false) and sender["tactical_until"]>battle_time and sender["tactical_target"]==ally["id"]: return "상대 부대가 이쪽으로 합류 중"
    if command_confused(ally["side"]): return "지휘 혼란으로 현 위치 방어"
    if ally["tactical_until"]>battle_time or has_pending_courier(ally["id"]): return "기존 전령 지시 수행 중"
    if ally["mission"]=="본진 방어" and (ally["has_destination"] or ally["obedience"]=="명령 엄수" or headquarters[ally["side"]]["occupation"]>0):
        return "본진 수비를 우선"
    var threat:=_nearest_visible_enemy(ally)
    var engaged: bool=not threat.is_empty() and (ally["pos"] as Vector2).distance_to(threat["pos"])<130
    if ally["personality"]=="신중" and (engaged or ally["rations"]<35 or ally["morale"]<65):
        return "신중한 판단 · 자군 방어를 우선"
    if engaged and ally["personality"]!="공격" and ally["troops"]<threat["troops"]: return "현재 교전에서 병력 열세"
    return ""

func _move_relief_riders(dt: float) -> void:
    for i in range(relief_riders.size()-1,-1,-1):
        var request:=relief_riders[i]
        var report: Dictionary=request["report"]
        var side: int=report["side"]
        var ally:=find_unit(request["recipient"])
        var returning: bool=request["returning"]
        if not returning and (ally.is_empty() or ally["troops"]<=0):
            request["returning"]=true
            request["answer"]="수신 부대 상실"
            continue
        var dest: Vector2=headquarters[side]["pos"] if returning else ally["pos"]
        var arrived:=_advance_rider(request["rider"],dest,dt)
        if report.has("site") and _courier_intercepted(request["rider"]):
            relief_riders.remove_at(i)
            continue
        if not arrived: continue
        if returning:
            report["relief_answer"]=request["answer"]
            if side==0:
                _field_notice(request["answer"],report["pos"],report["unit_id"])
                messenger_arrived.emit(-1,"구원 회신",request["answer"])
            relief_riders.remove_at(i)
            continue
        var sender:=find_unit(report["unit_id"])
        var reason:=_relief_decision(ally,sender)
        if report.has("site") and battle_time-report["written_at"]>24.0: reason="오래된 전황 보고"
        if report.has("site") and (commander_captured(side) or ally["mission"]=="본진 방어" or ally["defense_set"] or ally["has_destination"] or ally.has("post_watch")): reason="기존 방어 임무 유지"
        var text: String="%s → %s군 구원 " % [ally["name"],report["sender"]]
        if reason.is_empty() and ally.get("mounted_partner",-1)==report["unit_id"] and ally["action"] in ["협동 우회","돌파"]:
            text+="협동 중 · 같은 적에 대한 측면 지원 계속"
        elif reason.is_empty():
            ally["tactical_order"]="지원"
            ally["tactical_target"]=report["unit_id"]
            ally["tactical_until"]=battle_time+24.0
            ally["local_relief"]=true
            ally["ai_cooldown"]=0.0
            text+="수락 · "+str(ally["personality"])+" 성향, 기동 가능"
        else: text+="거절 · "+reason
        GeneralMind.order(ally,text,battle_time)
        request["answer"]=text
        request["returning"]=true

func _scan_situations() -> void:
    if battle_time-last_situation_scan < 2.0:
        return
    var span:=battle_time-maxf(0.0,last_situation_scan)
    last_situation_scan = battle_time
    if chapter.get("mode","") in ["river","link"] and not commander_captured(0):
        NorthernField.report_progress(self)
    for report in situation_reports:
        if report["status"] == "미대응" and battle_time >= float(report["expires"]):
            report["status"] = "시간 경과"
    for unit in units:
        if float(unit["troops"]) <= 0.0 or bool(unit["reserve"]):
            continue
        var push: Vector2=unit.get("report_push",Vector2.ZERO)
        var foe:=find_unit(int(unit.get("report_opponent",-1)))
        var opponent: String=""
        if not foe.is_empty() and _locally_observed(unit,foe): opponent=foe["name"]
        unit["report_push"]=Vector2.ZERO
        unit["report_opponent"]=-1
        var losses: float=unit["casualties_taken"]
        var recent_losses:=maxi(0,roundi(losses-float(unit.get("report_losses",losses))))
        unit["report_losses"]=losses
        var kind: String = ""
        if bool(unit["surrounded"]):
            kind = "포위 위험"
        elif float(unit["morale"]) < 45.0 or float(unit["cohesion"]) < 42.0:
            kind = "전열 붕괴 위험"
        elif push.length()>=4.0:
            kind="전선 압박"
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
        var side: int=unit["side"]
        var urgent:=kind in ["전열 붕괴 위험","포위 위험","전선 압박"]
        if not urgent and (side==1 or commander_captured(side)): continue
        var key: String = "%d:%s" % [unit["id"],kind]
        if battle_time-float(situation_keys.get(key,-100.0)) < 30.0:
            continue
        situation_keys[key] = battle_time
        if proposal.is_empty():
            proposal = "지원" if kind in ["포위 위험","전선 압박"] else ("사수" if kind == "명령 이탈" else "재집결")
        _send_situation(unit,kind,proposal,urgent,push,opponent,recent_losses,span)

func _send_situation(unit: Dictionary,kind: String,proposal: String,urgent: bool,push: Vector2,opponent: String,recent_losses: int,span: float,account: String="") -> void:
    var side: int=unit["side"]
    situation_serial+=1
    var rider:=_field_rider(unit["pos"],side,-10-situation_serial*3)
    var report: Dictionary={"id":situation_serial,"unit_id":unit["id"],"title":str(unit["name"])+" · "+kind+(" / "+proposal+" 건의" if not proposal.is_empty() else ""),
        "kind":kind,"urgent":urgent,"side":side,"proposal":proposal,"pos":unit["pos"],"written_at":battle_time,"rider":rider,
        "sender":str(unit["name"]),"troops":roundi(unit["troops"]),"push":push,"opponent":opponent,
        "losses":recent_losses,"sample_seconds":roundi(span*operation_scale()),"status":"대기","mission":unit["mission"],"action":unit["action"],"reason":unit["reason"],
        "morale":roundi(unit["morale"]),"cohesion":roundi(unit["cohesion"]),"rations":roundi(unit["rations"]),
        "ammo":roundi(unit["ammo"]),"general_hp":roundi(unit["general_hp"]),"pressure":float(unit["front_pressure"])}
    if not account.is_empty():
        report["objective_account"]=account
        if chapter["mode"]=="river": report["east_bank"]=NorthernField.on_east_bank(self,unit)
        else: report["joint_credit"]=unit.get("joint_credit",0.0)
    if side==0:
        if unit.has("last_skill_report"):
            report["skill_report"]=unit["last_skill_report"]
        situation_reports.append(report)
    incoming_reports.append(report)
    if urgent and not unit.has("parent_id") and battle_time-float(unit.get("last_relief_request",-100.0))>=30.0:
        _send_relief_request(unit,report)
    if situation_reports.size() > 80:
        for j in range(situation_reports.size()):
            if str(situation_reports[j]["status"]) not in ["대기","미대응","전령 파견","명령 수령","실행 중"]:
                situation_reports.remove_at(j)
                break

# Follow actual courier and tactical execution, rather than treating dispatch as success.
func _response_delivery(letter: Dictionary,status: String) -> void:
    if letter.has("reply_id") and status not in ["명령 수령","명령 거부"]:
        for report in situation_reports:
            if report["id"] != letter["reply_id"]: continue
            report["reply_status"] = status
            if status == "회신 도착":
                report["reply_at"] = battle_time
                if letter["verdict"] == "불허":
                    report["status"] = "불허 전달"
                    report["resolved_at"] = battle_time
            break
        if status == "회신 도착": return
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
        if finished and report.get("reply_status","") == "이동 중": report["reply_status"] = "종전 · 미전달"
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
            if expected == "긴급 지원" and not report.has("joined_at") and actor["tactical_target"] == report["unit_id"]:
                var recipient := find_unit(report["unit_id"])
                if _support_in_reach(actor, recipient): report["joined_at"] = battle_time
        report["loss_delta"]=roundi(maxf(0.0,float(actor["casualties_taken"])-float(report.get("loss_start",0.0))))
        report["damage_delta"]=roundi(maxf(0.0,float(actor["damage_dealt"])-float(report.get("damage_start",0.0))))
        if float(actor["troops"])<=0.0:
            report["status"]="실행 부대 상실"
        elif finished or battle_time>=float(report.get("until",0.0)):
            report["status"]="실행 종료" if bool(report.get("executed",false)) else "실행 미확인"
            report["resolved_at"]=battle_time

func _support_in_reach(actor: Dictionary, recipient: Dictionary) -> bool:
    if recipient.is_empty() or recipient["troops"] <= 0 or actor["troops"] <= 0 or actor["routed"]: return false
    var p: Vector2 = actor["pos"]
    var q: Vector2 = recipient["pos"]
    if p.distance_squared_to(q) > GUARD_RADIUS * GUARD_RADIUS: return false
    if wide_field and (_river_separates(p, q) or in_open_water(p) or in_open_water(q)): return false
    return _detour_goal(actor, p, q) == q

func open_situations() -> Array[Dictionary]:
    var result_reports: Array[Dictionary] = []
    for report in situation_reports:
        if report["status"] == "미대응":
            result_reports.append(report)
    return result_reports

func has_pending_courier(id: int) -> bool:
    for letter in couriers:
        if int(letter["unit_id"])==id: return true
    return false

func support_for_report(target: Dictionary) -> Dictionary:
    var best: Dictionary={}
    var best_score: float=-INF
    for ally in units:
        if int(ally["side"])!=0 or ally["id"]==target["id"] or bool(ally["routed"]) or float(ally["troops"])<24.0: continue
        if has_pending_courier(int(ally["id"])) or (ally.get("local_relief",false) and ally["tactical_until"]>battle_time): continue
        var score: float=float(ally["morale"])-_relief_travel_distance(ally, target["pos"])*0.1
        if score>best_score:
            best=ally
            best_score=score
    return best

# A reply uses the reporting channel even during the preplanned opening days.
# A support approval sends both the reporter's answer and the helper's order.
func reply_to_report(report_id: int, approved: bool) -> bool:
    if not tactical_enabled or not started or finished or commander_captured(0): return false
    for report in situation_reports:
        if report["id"] != report_id or report["status"] != "미대응": continue
        if battle_time >= float(report["expires"]): return false
        var sender := find_unit(report["unit_id"])
        if sender.is_empty() or sender["troops"] <= 0: return false
        var proposal := str(report.get("proposal",""))
        if proposal not in ["재집결","사수","지원","철수"]: return false
        var actor := sender
        if approved and proposal == "지원":
            actor = support_for_report(sender)
            if actor.is_empty(): return false
        var verdict := "허가" if approved else "불허"
        var response := _field_rider(commanders[0]["pos"],0,-20-report_id*3)
        response.merge({"unit_id":sender["id"],"mission":verdict+" 회신","verdict":verdict,"reply_id":report_id})
        report["verdict"] = verdict
        report["reply_status"] = "이동 중"
        report["response"] = proposal if approved else "기존 임무 유지"
        report["status"] = "전령 파견"
        report["executor"] = actor["id"]
        report["sent_at"] = battle_time
        if approved:
            var instruction := {"report_id":report_id,"tactical_order":proposal,"support_id":sender["id"] if proposal == "지원" else -1}
            if actor == sender:
                response.merge(instruction)
            else:
                instruction.merge(_field_rider(commanders[0]["pos"],0,-21-report_id*3))
                instruction.merge({"unit_id":actor["id"],"mission":proposal,"reply_support":true})
                couriers.append(instruction)
        else:
            response["report_id"] = report_id
        couriers.append(response)
        _log("%s 건의 %s · 회신 출발" % [sender["name"],verdict])
        return true
    return false

func respond_situation(report_id: int, response: String) -> bool:
    if not tactical_enabled or not started or finished or commander_captured(0):
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
            report["resolved_at"] = battle_time
            GeneralMind.acknowledge(target,battle_time)
            _log(str(target["name"])+": 보고 확인, 기존 작전 유지")
            return true
        if response == "지원":
            var best: Dictionary=support_for_report(target)
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
    if not tactical_enabled or not started or finished or commander_captured(0) or turn < COURIER_TURN or command_points <= 0:
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
    if has_pending_courier(unit_id): return false
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
    unit["local_relief"]=false
    unit["tactical_order"] = order
    unit["tactical_target"] = int(letter.get("support_id",-1))
    unit["tactical_anchor"] = unit["pos"]
    unit["tactical_until"] = battle_time+24.0
    _response_delivery(letter,"명령 수령")
    unit["ai_cooldown"] = 0.0
    _log(str(unit["name"])+": 긴급 "+order+" 명령 도착")

# Keep the support slot beside the recipient when its usual side is in the river.
func _relief_position(ally: Dictionary) -> Vector2:
    var center: Vector2 = ally["pos"]
    var offset := Vector2(-32.0 if ally["side"] == 0 else 32.0, 0)
    var goal := _field_point(center + offset)
    if long_operation and in_open_water(goal): return _field_point(center - offset)
    return goal

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
                if long_operation and LinkedMarch._partner(unit,battle_time)==ally["id"] and LinkedMarch.role(unit,battle_time) in FieldJudgment.GUARD_ORDERS and action=="궁병 보호":
                    return {"action":"긴급 지원","reason":str(ally["name"])+"군 구원 · 접근 중인 적 차단","goal":goal}
                return {"action":"긴급 지원","reason":("현지 구원 수락 · " if unit.get("local_relief",false) else "전령 명령: ")+str(ally["name"])+" 지원","goal":_relief_position(ally)}
    if long_operation and LinkedMarch.role(unit,battle_time) in FieldJudgment.GUARD_ORDERS and LinkedMarch._partner(unit,battle_time)>=0:
        return result_order
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
    return FieldGeometry.road_y(x,lane,layout_scale,scenario_id)


func _expand_layout() -> void:
    layout_scale = 3.0 if wide_field else 1.0
    field_size = Vector2(FIELD_W,FIELD_H)*layout_scale
    marshes = FieldGeometry.MARSHES[scenario_id] if wide_field else []
    reedbeds = FieldGeometry.REEDBEDS[scenario_id] if wide_field else []
    if not wide_field: return
    for unit in units:
        for key in ["pos","goal","defense_anchor","tactical_anchor"]:
            unit[key] = layout_point(unit[key])
    for base in bases:
        base["pos"]=layout_point(base["pos"])
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
        TRAINING_SCENARIO:
            forests.append_array([Rect2(440,1070,175,200),Rect2(1750,135,240,180)])
    var hill_size: Vector2 = hill.size*1.8
    hill = Rect2(layout_point(hill.get_center())-hill_size*0.5,hill_size)
    for structure in structures:
        var old: Rect2 = structure["rect"]
        structure["rect"] = Rect2(layout_point(old.position),Vector2(old.size.x,old.size.y*3.0))
    if scenario_id==TRAINING_SCENARIO:
        var gate: Rect2=structures[0]["rect"]
        var align_y: float=road_y(gate.get_center().x,1)-gate.get_center().y
        for structure in structures:
            var rect: Rect2=structure["rect"]
            rect.position.y+=align_y
            structure["rect"]=rect
    scenario_limit = [360.0,330.0,300.0,390.0,360.0,360.0][scenario_id]
    if six_armies and scenario_id == 0:
        outposts.append({"name":"중앙 동쪽 접근로","pos":Vector2(1370,850),"owner":-1,"challenger":-1,"progress":0.0,"hold":0.0})
        scenario_goal = "6일차 이후 세 거점 중 두 곳을 8초 확보"
    if scenario_id == 1:
        scenario_goal = "6일차 이후 중앙 고지 30초 연속 확보"
    elif scenario_id == 2:
        scenario_goal = "300초 동안 아군 본진 사수"
    reserve_next = [36.0,36.0]
    if long_operation:
        scenario_limit = 420.0 if scenario_id == 3 else LONG_LIMIT
        reserve_next = [135.0,135.0]
        match scenario_id:
            0: scenario_goal="18분 이후 세 거점 중 두 곳을 3분 연속 확보"
            1: scenario_goal="18분 이후 중앙 고지 3분 연속 확보"
            2: scenario_goal="25분 동안 아군 본진 사수"
            3: scenario_goal="28분 이내 군량 수레를 동쪽 도착점까지 호위"
            4: scenario_goal="18분 이후 성문 파괴 및 중앙 거점 2분 확보"
            TRAINING_SCENARIO: scenario_goal="18분 이후 연습 성문 파괴 및 동쪽 거점 2분 확보"

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
        sub["formation"] = leader["formation"]
        sub["policy"] = leader["policy"]
        sub["obedience"] = leader["obedience"]
        sub["specialty"] = leader.get("specialty","")
        for key in ["leadership","martial","intelligence","judgment","loyalty"]:
            sub[key] = maxf(35.0,float(leader[key])*0.86)
    _log("군단 편성: 본대와 별동대 전개")

func corps_report(id: int) -> Dictionary:
    var report: Dictionary = {"troops":0.0,"damage_dealt":0.0,"casualties_taken":0.0,"deserted":0.0,"decisions":0,"merit":0,
        "brace_stops":0,"rear_losses":0.0,"rout_count":0}
    for member in units:
        if int(member["id"]) != id and int(member.get("parent_id",-1)) != id: continue
        for key in ["troops","damage_dealt","casualties_taken","deserted","decisions","brace_stops","rear_losses","rout_count"]:
            report[key] += member[key]
        report["merit"] += merit(member)
    return report

func river_x(y: float) -> float:
    return FieldGeometry.river_x(y)

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

# Automatic opening ranks share an existing objective. A delivered player order
# releases the pair through _reset_cooperation, just like a changed manual link.
func _pair_opening_ranks() -> void:
    if not convoy.is_empty(): return
    var claimed: Dictionary={}
    for u in units:
        if int(u["assigned_link"])>=0:
            claimed[u["id"]]=true
            claimed[u["assigned_link"]]=true
    for bow in units:
        if bow["type"]!="궁병" or not _free_opening_rank(bow) or claimed.has(bow["id"]): continue
        var best: Dictionary={}
        var distance:=460.0
        for foot in units:
            if foot["type"]!="보병" or foot["side"]!=bow["side"] or foot["mission"]!=bow["mission"]: continue
            if claimed.has(foot["id"]) or not _free_opening_rank(foot): continue
            var gap: float=Vector2(foot["pos"]).distance_to(bow["pos"])
            if gap<distance and not _river_separates(foot["pos"],bow["pos"]):
                distance=gap
                best=foot
        if not best.is_empty():
            bow["opening_screen"]=best["id"]
            claimed[best["id"]]=true

func _free_opening_rank(unit: Dictionary) -> bool:
    return unit["troops"]>=600 and not unit["routed"] and not unit["reserve"] and not unit["has_destination"] and not unit["defense_set"] and unit["waypoints"].is_empty() and unit.get("march_sequence",0)==0

# The battle line follows the order or a visible opponent. A sideways step to
# separate two formations must not send the rear rank around its own front.
func _screen_forward(anchor: Dictionary, enemy: Dictionary) -> Vector2:
    var p: Vector2=anchor["pos"]
    if not enemy.is_empty() and p.distance_to(enemy["pos"])>8.0:
        return p.direction_to(enemy["pos"])
    var march: Dictionary=march_plans.get(anchor["id"],{})
    if not march.is_empty(): return march["forward"]
    var destination: Vector2=anchor["order_destination"]
    if not anchor["has_destination"]:
        var site:=_assigned_outpost(anchor)
        destination=site["pos"] if not site.is_empty() else _mission_point(anchor["side"],anchor["mission"])
    if p.distance_to(destination)>65: return p.direction_to(destination)
    return Vector2.RIGHT if anchor["side"]==0 else Vector2.LEFT

func _screen_partner(unit: Dictionary) -> Dictionary:
    var id: int=LinkedMarch._partner(unit,battle_time)
    var partner:=find_unit(id)
    if id<0:
        for other in units:
            if other["side"]==unit["side"] and LinkedMarch._partner(other,battle_time)==unit["id"] and other["type"]!=unit["type"] and other["type"] in ["궁병","보병"] and other["troops"]>=600 and not other["routed"]:
                partner=other
                break
    if partner.is_empty() or partner["side"]!=unit["side"] or partner["type"]==unit["type"] or partner["type"] not in ["궁병","보병"]: return {}
    if partner["troops"]<600 or partner["routed"] or partner["rallying"] or Vector2(unit["pos"]).distance_to(partner["pos"])>205: return {}
    if _river_separates(unit["pos"],partner["pos"]): return {}
    return partner

func _screen_station(unit: Dictionary, enemy: Dictionary, action: String) -> Dictionary:
    if unit["type"] not in ["궁병","보병"] or unit["troops"]<600 or unit["routed"] or enemy["routed"] or battle_time<unit["tactical_until"]: return {}
    if action not in ["거점 방어","거점 점령","방어","거리 유지","전열 지원","협동 엄호","궁병 보호","교전","진격","측면 방어","본진 공략"]: return {}
    if unit["has_destination"] and unit["mission"] not in ["전열 엄호","궁병 보호"]: return {}
    var partner:=_screen_partner(unit)
    if partner.is_empty(): return {}
    var archer: bool=unit["type"]=="궁병"
    var bow: Dictionary=unit if archer else partner
    var front: Dictionary=partner if archer else unit
    if bow["ammo"]<12 or front["cohesion"]<40: return {}
    var p: Vector2=front["pos"]
    var rear: Vector2=bow["pos"]
    var foe: Vector2=enemy["pos"]
    var gap:=p.distance_to(foe)
    if gap>210 or _river_separates(p,foe): return {}
    var axis:=p.direction_to(foe)
    if axis.is_zero_approx(): axis=front["facing"]
    var depth: float=(p-rear).dot(axis)
    var lateral: float=absf((p-rear).cross(axis))
    if archer:
        if rear.distance_to(foe)<110 and (depth<24 or lateral>50): return {}
        var point:=p-axis*clampf(151.0-gap,52.0,98.0)
        if in_open_water(point) or _river_separates(rear,point): return {}
        var ready:=depth>=36 and depth<=136 and lateral<=42 and rear.distance_to(foe)<=173.0
        return {"action":"엄호 사격" if ready else "후열 정렬","reason":str(front["name"])+("군 뒤 사격 위치 유지" if ready else "군 뒤 사격 위치로 이동"),"goal":rear if ready else point}
    if depth<26 or lateral>60:
        if rear.distance_to(foe)>140.0: return {}
        var intercept:=rear.lerp(foe,0.5)
        if in_open_water(intercept) or _river_separates(p,intercept): return {}
        return {"action":"궁병 보호","reason":str(bow["name"])+"군의 노출된 사격 위치를 엄호","goal":intercept}
    if action not in ["방어","측면 방어","궁병 보호","협동 엄호"]: return {}
    # A defensive front closes only the gap needed for the rear to fire.
    var step_in:=maxf(0.0,gap-92.0) if rear.distance_to(foe)>173.0 else 0.0
    return {"action":"전열 유지","reason":str(bow["name"])+"군 앞에서 사격선 확보","goal":p+axis*step_in}

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
    var size := clampi(ceili(float(unit["troops"])/180.0),1,24)
    var shape: String = unit["formation"] if shape_override.is_empty() else shape_override
    var local := _occupied_files(unit, count) if shape_override.is_empty() and count == size else FormationDrill.pattern(shape, count)
    for p in local:
        var q := p * spacing
        var pos:Vector2=(unit["pos"] as Vector2)+front*q.x+side*q.y
        points.append(_dry_formation_slot(unit["pos"],pos) if long_operation else pos)
    return points

func _leading_offset(unit: Dictionary, slots: Array[Vector2], direction: Vector2) -> Vector2:
    var center: Vector2 = unit["pos"]
    var leading := Vector2.ZERO if slots.is_empty() else slots[0]-center
    for point in slots:
        var offset := point-center
        if offset.dot(direction) > leading.dot(direction): leading = offset
    return leading

# Soil classification is deliberately independent of the army's order or animation.
# A walking column can lift loose dirt here without already churning the ground.
func dusty_ground(p: Vector2) -> bool:
    return terrain_at(p) == "도로"

func _emit_march_dust(unit: Dictionary,previous: Vector2,displacement: Vector2) -> void:
    var distance: float = displacement.length()
    if distance < 0.20 or float(unit["troops"]) <= 0.0:
        unit["dust_distance"] = 0.0
        return
    var accumulated: float = float(unit.get("dust_distance",0.0))+distance
    var cavalry: bool = str(unit["type"])=="기병"
    var spacing := 5.8 if cavalry else 8.0
    if accumulated < spacing:
        unit["dust_distance"] = accumulated
        return
    unit["dust_distance"] = fmod(accumulated, spacing)
    var forward := displacement.normalized()
    var slots := formation_slots(unit)
    var fast_ground := cavalry and float(unit["motion_speed"]) >= 55.0
    var churned: bool = fast_ground or unit["routed"] or int(unit["contact_troops"]) > 0
    # Each sample represents a different file, spread along the completed step.
    var stride := 2 if cavalry else 3
    for i in range(posmod(step_count, stride), slots.size(), stride):
        var variation := sin(float(step_count * 37 + int(unit["id"]) * 19 + i * 13) * 1.73)
        var foot: Vector2 = previous + (slots[i] - Vector2(unit["pos"])) + displacement * (0.50 + variation * 0.45)
        var surface := terrain_at(foot)
        if surface != "도로" and not (churned and surface in ["평지", "고지"]): continue
        var radius := (22.0 if cavalry else 15.5) * (0.85 + absf(variation) * 0.45)
        dust_effects.append({"pos":foot, "dir":forward, "time":battle_time, "radius":radius, "side":unit["side"],
            "phase":variation, "surface":surface})
        if dust_effects.size() > DUST_LIMIT: dust_effects.pop_front()


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
    return _combined_arms_partner(unit,enemy,targets)>=0

func _working_pair(unit: Dictionary, ally: Dictionary) -> bool:
    return LinkedMarch._partner(unit,battle_time)==ally["id"] or LinkedMarch._partner(ally,battle_time)==unit["id"]

func _combined_arms_partner(unit: Dictionary,enemy: Dictionary,targets: Dictionary) -> int:
    var p: Vector2=unit["pos"]
    var ep: Vector2=enemy["pos"]
    # In Mugong, credit the active partner when several allied corps hit the
    # same target. Incidental combined arms still receives its combat bonus.
    var objective_pair: bool=chapter.get("mode","")=="link" and unit["side"]==0
    var fallback: int=-1
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
        if str(ally["type"])!="궁병" and str(unit["type"])!="궁병" and a.dot(b)>=0.45: continue
        if not objective_pair or _working_pair(unit,ally): return ally["id"]
        if fallback<0: fallback=ally["id"]
    return fallback

# Cooperation uses a friendly anchor and local observation, not an omniscient
# enemy position. A flank waypoint stays committed until reached or timed out.
func _coordinated_order(unit: Dictionary,enemy: Dictionary,action: String,reason: String,goal: Vector2) -> Dictionary:
    var original: Dictionary={"action":action,"reason":reason,"goal":goal}
    var mission: String=str(unit["mission"])
    var tactical_role:bool=long_operation and LinkedMarch.has_field_role(unit,battle_time)
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
    elif tactical_role or unit["assigned_link"]>=0:
        unit["link_id"]=-1
        return original
    if ally.is_empty():
        unit["link_id"]=-1
        return original
    unit["link_id"]=ally["id"]
    var ap: Vector2=ally["pos"]
    var forward: Vector2=ally["facing"]
    if forward.length_squared()<0.01: forward=Vector2.RIGHT if int(unit["side"])==0 else Vector2.LEFT
    if long_operation and mission in ["궁병 보호","전열 엄호"]:
        forward=_screen_forward(ally,enemy)
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
    return _flank_order(unit,ally,enemy)

func _flank_order(unit: Dictionary,ally: Dictionary,enemy: Dictionary,local_sortie: bool=false) -> Dictionary:
    var p: Vector2=unit["pos"]
    var ap: Vector2=ally["pos"]
    var forward: Vector2=ally["facing"]
    if forward.is_zero_approx(): forward=Vector2.RIGHT if unit["side"]==0 else Vector2.LEFT
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
        var wing:=_field_point(ep+lateral*sign_value*155.0-ef*45.0)
        if local_sortie:
            var reachable:=false
            for candidate in [wing,_field_point(ep-lateral*sign_value*155.0-ef*45.0)]:
                if in_open_water(candidate) or _river_separates(p,candidate) or _river_separates(candidate,ep): continue
                if _detour_goal(unit,p,candidate)!=candidate or _detour_goal(unit,candidate,ep)!=ep: continue
                wing=candidate
                reachable=true
                break
            if not reachable: return {}
        unit["flank_target"]=enemy["id"]
        unit["flank_goal"]=wing
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
    var sight := _vision_range(unit)
    var best: Dictionary=nearest
    var score_best: float=-INF
    for enemy in units:
        if int(enemy["side"])==int(unit["side"]) or float(enemy["troops"])<=0.0: continue
        var ep: Vector2=enemy["pos"]
        var d: float=p.distance_to(ep)
        if d > reach + 100.0 or d > sight * unit_exposure(enemy): continue
        var direction: Vector2=(p-ep).normalized()
        var flank: bool=direction.dot(enemy["facing"])<0.3
        var score: float=110.0-d*0.6+45.0*(tactical_matchup(unit,enemy,flank)-1.0)
        if not _physical_screen(enemy,unit).is_empty(): score-=35.0
        if str(enemy["next_formation"])!="": score+=12.0
        if long_operation:
            if bool(enemy["routed"]): score-=24.0
            if int(unit["contact_target_id"])==int(enemy["id"]) and str(unit["type"])!="궁병": score+=13.0
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
    unit.erase("opening_screen")
    unit.erase("mounted_anchor")
    unit.erase("mounted_partner")
    unit.erase("escape_step")
    unit.erase("rally_covering")
    unit["ai_role"]=""
    unit["ai_partner"]=-1
    unit["ai_role_until"]=0.0
    for other in units:
        if other.get("opening_screen",-1)==unit["id"]: other.erase("opening_screen")
    unit["field_choice"]={}
    march_sequence+=1
    unit["march_sequence"]=march_sequence
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
    return p.distance_to(ep) <= _vision_range(unit) * unit_exposure(enemy)

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
const MAP_MISSIONS = ["본진 방어","지정 위치 이동","공격","지역 사수","전열 엄호","측후방 기동","구원 지원","예비 대기","철수","자유 재량"]

func map_order_issue(id: int, mission: String, destination: Vector2, partner: int = -1) -> String:
    if finished: return "전투가 종료되었습니다."
    if commander_captured(0): return "책사 생포 · 장수들이 자율 지휘합니다."
    if mission=="본진 방어":
        destination=_home_point(0)
        partner=-1
    if mission not in MAP_MISSIONS: return "행동을 선택하십시오."
    if mission!="자유 재량" and not Rect2(Vector2.ZERO,field_size).has_point(destination): return "전장 안의 목적지를 선택하십시오."
    if mission!="자유 재량" and long_operation and in_open_water(destination): return "하천에는 지시할 수 없습니다. 교량이나 강둑을 선택하십시오."
    var unit := find_unit(id)
    if unit.is_empty() or int(unit["side"])!=0 or float(unit["troops"])<=0.0:
        return "지시할 수 있는 아군 군단을 선택하십시오."
    if mission=="본진 방어" and (unit["routed"] or unit["reserve"]): return "현재 출전 중인 군단에 수비를 지시하십시오."
    if not _valid_partner(unit,partner): return "현재 협동 대상에 지시를 연결할 수 없습니다."
    if started and turn < COURIER_TURN: return "%d일차부터 전령을 파견할 수 있습니다." % COURIER_TURN
    if started:
        for letter in couriers:
            if int(letter["unit_id"]) == id: return "이 군단에 이미 전령이 이동 중입니다."
    return ""

func issue_map_order(id: int,mission: String,destination: Vector2,partner: int=-1) -> bool:
    if mission=="본진 방어":
        partner=-1
        destination=_home_point(0)
    elif mission=="자유 재량":
        partner=-1
        destination=Vector2(-1,-1)
    if not map_order_issue(id,mission,destination,partner).is_empty(): return false
    var unit: Dictionary=find_unit(id)
    if started:
        if not request_order(id,mission,"현장 판단",partner,destination): return false
        couriers.back()["map_dispatch"] = true
        map_dispatches[id] = {"mission":mission,"status":"이동 중","destination":destination if mission=="자유 재량" else _field_point(destination),"time":operation_elapsed()}
        return true
    if not select_unit_mission(id,mission,"현장 판단",partner): return false
    unit["has_destination"]=mission!="자유 재량"
    unit["order_destination"]=_field_point(destination) if unit["has_destination"] else Vector2.ZERO
    unit["destination_reached"]=false
    unit["waypoints"].clear()
    unit["waypoint_index"]=0
    unit["defense_set"]=false
    _received_rally_pin(unit,true)
    GeneralMind.order(unit,"사전 작전: "+mission,battle_time)
    return true

func _received_rally_pin(unit: Dictionary, is_map_order: bool) -> void:
    unit.erase("rally_origin")
    if long_operation and is_map_order and unit["has_destination"] and unit["mission"] in RallyOrders.MISSIONS:
        unit["rally_origin"] = unit["pos"]
    RallyOrders.refresh(self)

func _resolve_map_dispatch(letter: Dictionary, status: String) -> void:
    if not bool(letter.get("map_dispatch",false)): return
    var dispatch: Dictionary = map_dispatches.get(int(letter["unit_id"]),{})
    if dispatch.is_empty(): return
    dispatch["status"] = status
    dispatch["time"] = operation_elapsed()

# A projection for the planning map. Uses the live route choice's geometry
# and allied traffic, without writing bridge commitments to the unit.
func map_order_crossing(id: int, destination: Vector2) -> float:
    if not wide_field or not long_operation or in_open_water(destination): return -1.0
    var unit := find_unit(id)
    if unit.is_empty(): return -1.0
    var p: Vector2 = unit["pos"]
    var bank: int = 1 if p.x>=river_x(p.y) else -1
    var target_bank: int = 1 if destination.x>=river_x(destination.y) else -1
    if bank == target_bank: return -1.0
    var committed: float = float(unit.get("bridge_y",-1.0))
    if committed >= 0.0 and int(unit["bridge_bank"]) == target_bank:
        return committed
    return _choose_crossing(unit,p,destination)

func _destination_order(unit: Dictionary,enemy: Dictionary,action: String,reason: String,goal: Vector2,distance: float) -> Dictionary:
    var original: Dictionary={"action":action,"reason":reason,"goal":goal}
    if not bool(unit.get("has_destination",false)): return original
    if action in ["패주","후퇴","재집결","휴식","탄약 보충","보급 복귀"]: return original
    var p: Vector2=unit["pos"]
    var dest: Vector2=unit["order_destination"]
    var mission: String=unit["mission"]
    if mission=="철수": return {"action":"전술 철수","reason":"책사의 철수 지시","goal":dest}
    if p.distance_to(dest)<=65.0: unit["destination_reached"]=true
    if action=="거리 유지" and distance<110.0: return original
    if long_operation and mission in FieldJudgment.GUARD_ORDERS and action in ["협동 엄호","궁병 보호","구원 지원"]:
        var partner := find_unit(unit["link_id"])
        if not partner.is_empty() and _valid_partner(unit,partner["id"]):
            var partner_pos: Vector2=partner["pos"]
            # Follow the rendezvous on the march. In the assignment area, or
            # when the partner is under local pressure, stay with the partner.
            if partner_pos.distance_to(dest)<=175.0 or (p.distance_to(partner_pos)<=205.0 and not _observed_threat_to(unit,partner).is_empty()):
                return original
    if mission == "공격" and not enemy.is_empty() and Vector2(enemy["pos"]).distance_to(dest) < 240.0:
        # A defender at the edge of the order area can block the last few
        # steps. Engage the observed target without declaring the area secured.
        if unit["destination_reached"] or (distance < 85.0 and not _river_separates(p, enemy["pos"])):
            return {"action":"돌파" if unit["type"]=="기병" else "교전", "reason":"지정 지역 적군 공격", "goal":enemy["pos"]}
    if not bool(unit["destination_reached"]):
        if distance<85.0 and action in ["거리 유지","측면 방어","교전","돌파","방어"]: return original
        return {"action":"지정 위치 이동","reason":"책사가 지정한 작전 지역으로 이동","goal":dest}
    if mission in ["지역 사수","예비 대기","지정 위치 이동"]:
        return {"action":"예비 대기" if mission=="예비 대기" else "지정 지역 사수","reason":"지정 지역 확보 및 현장 판단","goal":dest if p.distance_to(dest)>55.0 else p}
    if mission=="공격":
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
        if d<score and (not long_operation or not _river_separates(ally["pos"],foe["pos"])):
            score=d
            best=foe
    return best

func _enemy_strategy()->void:
    if scenario_id not in [2,3]: NorthernField.review_pressure(self)
    _plan_local_roles(1)

func _plan_local_roles(side: int)->void:
    for unit in units:
        if unit["assigned_link"]>=0 or unit["has_destination"]: continue
        if (side==0 or scenario_id in [2,3]) and unit["mission"]!="자유 재량": continue
        if int(unit["side"])!=side or float(unit["troops"])<600.0 or bool(unit["routed"]) or bool(unit["reserve"]) or str(unit["mission"])=="본진 방어": continue
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
            if int(ally["side"])!=side or int(ally["id"])==int(unit["id"]) or float(ally["troops"])<600.0 or bool(ally["routed"]) or str(ally["mission"])=="본진 방어": continue
            var distance:float=p.distance_to(ally["pos"])
            if distance>310.0 or _river_separates(p,ally["pos"]): continue
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
            if side==1: enemy_replans+=1
            unit["flank_target"]=-1
            unit["flank_phase"]=0
            unit["flank_until"]=0.0
            unit["ai_cooldown"]=0.0
        unit["ai_role"]=role
        unit["ai_partner"]=partner
        unit["ai_role_until"]=battle_time+20.0

# A near-bank unit can change orders on dry land. Once on the deck it
# finishes the crossing before turning back for a moving destination.
func _on_bridge_deck(p: Vector2, bridge: float) -> bool:
    return on_river_channel(p) and absf(p.y - bridge) <= 38.0

func _keep_bridge(p: Vector2, goal: Vector2, bridge: float, exit_bank: int) -> bool:
    var target_bank := 1 if goal.x >= river_x(goal.y) else -1
    var exit_distance := (p.x - river_x(p.y)) * exit_bank
    if exit_distance >= 0.0:
        # Contact can push a unit along the far shore past the end of the deck.
        return exit_distance < 55.0 and (absf(p.y - bridge) <= 38.0 or on_river_channel(p))
    return target_bank == exit_bank or _on_bridge_deck(p, bridge)

func _bridge_waypoint(p: Vector2, bridge: float, exit_bank: int) -> Vector2:
    var approach_bank := (p.x - river_x(p.y)) * exit_bank < 0.0
    var side := exit_bank
    if approach_bank and absf(p.y - bridge) > 10.0 and not _on_bridge_deck(p, bridge):
        side = -exit_bank
    return Vector2(river_x(bridge) + side * 64.0, bridge)

# One bridge is selected and retained until the army reaches the far bank.
# Route choice accounts for allied congestion without reading hidden enemies.
func _committed_bridge_route(unit:Dictionary,p:Vector2,goal:Vector2)->Vector2:
    var bank:int=1 if p.x>=river_x(p.y) else -1
    var target_bank:int=1 if goal.x>=river_x(goal.y) else -1
    var chosen:float=float(unit["bridge_y"])
    if chosen>=0.0:
        var exit_bank:int=int(unit["bridge_bank"])
        if _keep_bridge(p, goal, chosen, exit_bank):
            return _bridge_waypoint(p, chosen, exit_bank)
        if bank == exit_bank: unit["bridge_crossings"] += 1
        unit["bridge_y"] = -1.0
        unit["bridge_bank"] = 0
    if bank==target_bank:
        if in_open_water(goal): return Vector2(river_x(goal.y)+bank*34.0,goal.y)
        return goal
    chosen=_choose_crossing(unit,p,goal)
    unit["bridge_y"]=chosen
    unit["bridge_bank"]=target_bank
    return _bridge_waypoint(p, chosen, target_bank)

func _choose_crossing(unit: Dictionary, p: Vector2, goal: Vector2) -> float:
    var best:float=INF
    var chosen:float=850.0
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
    return chosen

func _land_motion(unit:Dictionary,old:Vector2,proposed:Vector2)->Vector2:
    if not in_open_water(proposed) and not _river_separates(old,proposed): return proposed
    # A unit already displaced into water can escape, but cannot advance deeper.
    if in_open_water(old) and absf(proposed.x-river_x(proposed.y))>absf(old.x-river_x(old.y)):
        return proposed
    unit["blocked_water_steps"]+=1
    var bank:float=1.0 if old.x>=river_x(old.y) else -1.0
    var slide:Vector2=_field_point(Vector2(river_x(proposed.y)+bank*maxf(28.0,absf(old.x-river_x(old.y))),proposed.y))
    var bounded:Vector2=old.move_toward(slide,old.distance_to(proposed))
    return bounded if not in_open_water(bounded) and not _river_separates(old,bounded) else old

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
