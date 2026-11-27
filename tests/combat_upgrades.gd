extends SceneTree

const WarSim = preload("res://scripts/war_sim.gd")
var failures: int=0

func _initialize() -> void:
    _bows()
    _charge_and_rear()
    _ordered_charge()
    _running_charge()
    _contact_footwork()
    _planted_feet()
    _melee_crowd()
    _formation_support()
    _change_ranks()
    _aftermath()
    _targeting()
    _rear_pressure()
    _simultaneous_losses()
    print("GUNRYAK_COMBAT_PASS" if failures==0 else "GUNRYAK_COMBAT_FAIL %d" % failures)
    quit(0 if failures==0 else 1)

func _check(value: bool, label: String) -> void:
    if value: print("PASS "+label)
    else:
        failures+=1
        push_error(label)

func _field() -> WarSim:
    var sim := WarSim.new()
    sim.set_long_operation(true)
    sim.forests.clear()
    sim.hill=Rect2()
    for u in sim.units:
        u["troops"]=0.0
    sim.battle_time=10.0
    return sim

func _place(unit: Dictionary, point: Vector2, kind: String, formation: String="횡대") -> Dictionary:
    unit["pos"]=point
    unit["type"]=kind
    unit["formation"]=formation
    unit["facing"]=Vector2.RIGHT if int(unit["side"])==0 else Vector2.LEFT
    unit["troops"]=unit["initial_troops"]
    return unit

func _contact_footwork() -> void:
    var sim := _field()
    var foot := _place(sim.find_unit(0), Vector2(720,750), "보병")
    var enemy := _place(sim.find_unit(3), Vector2(793,750), "보병")
    foot["action"] = "공격 지속"
    foot["goal"] = enemy["pos"]
    foot["contact_target_id"] = enemy["id"]
    foot["mission"] = "공격"
    foot["has_destination"] = true
    foot["order_destination"] = Vector2(793,750)
    var distance: float = foot["pos"].distance_to(enemy["pos"])
    var approach := sim._destination_order(foot,enemy,"방어","",foot["pos"],distance)
    _check(approach["action"] == "교전" and not foot["destination_reached"], "attack orders engage the observed blocker outside the arrival radius")
    var limit := sim._body_distance(foot,enemy)
    foot["pos"] = enemy["pos"] - Vector2.RIGHT * limit
    var start: Vector2 = foot["pos"]
    sim._move_unit(foot,0.1)
    _check(start.distance_to(foot["pos"]) < 0.05, "a file already in contact holds its ground instead of marching into its opponent")
    foot["action"] = "후퇴"
    foot["goal"] = start - Vector2(120,0)
    sim._move_unit(foot,0.1)
    _check(foot["pos"].x < start.x and Vector2(foot["facing"]).dot(Vector2.RIGHT) > 0.96,
        "a withdrawing file can move away while it turns through the reversal")
    var front = preload("res://scripts/front_view.gd")
    var impacts := [{"target":Vector2.ZERO, "direction":Vector2.DOWN, "age":0.085, "radius":18.0}]
    _check(front.hit_reaction(Vector2.ZERO,0,impacts).y > 0.9 and front.hit_reaction(Vector2(28,0),0,impacts) == Vector2.ZERO,
        "only nearby files flinch in the incoming direction")
    var horse := _place(sim.find_unit(2), Vector2(600,750), "기병", "봉시진")
    horse["motion_speed"] = 135.0
    sim._emit_march_dust(horse, horse["pos"]-Vector2(13,0), Vector2(13,0))
    _check(sim.dust_effects.any(func(puff: Dictionary) -> bool: return puff["surface"] == "평지"),
        "galloping cavalry raises dust on dry open ground")
    sim.dust_effects.clear()
    horse["pos"] = Vector2(sim.river_x(850),850)
    horse["troops"] = 100
    sim._emit_march_dust(horse, horse["pos"]-Vector2(8,0), Vector2(8,0))
    _check(sim.dust_effects.is_empty(), "even at a gallop a hoof on the bridge raises no soil")

func _change_ranks() -> void:
    var sim := _field()
    var unit := _place(sim.find_unit(0), Vector2(700,750), "보병")
    sim._order_formation(unit, "종대")
    sim._formation_transition(unit, float(unit["form_duration"]) * 0.52)
    var halfway := sim.formation_slots(unit)
    sim._order_formation(unit, "학익진")
    _check(halfway == sim.formation_slots(unit), "a new formation order starts at the files' occupied positions")
    sim._formation_transition(unit, float(unit["form_duration"]) * 0.35)
    var changed := sim.formation_slots(unit)
    sim._order_formation(unit, "횡대")
    _check(changed == sim.formation_slots(unit), "a reversal returns to the original ranks without snapping")
    sim._formation_transition(unit, 20.0)
    _check(unit["reforms_completed"] == 0, "withdrawing an unfinished formation order does not count as a new formation")
    sim._order_formation(unit, "방진")
    var duration: float = unit["form_duration"]
    sim._formation_transition(unit, duration - 0.001)
    var almost := sim.formation_slots(unit)
    sim._formation_transition(unit, 0.002)
    var settled := sim.formation_slots(unit)
    var shape := sim.army_slots(unit, settled.size(), 12.0, "방진")
    var continuous := true
    for i in range(settled.size()):
        continuous = continuous and almost[i].distance_to(settled[i]) < 0.05 and settled[i] in shape
    _check(continuous and unit["formation"] == "방진", "each file holds its assigned place when the square finishes")

func _bows() -> void:
    var sim := _field()
    var bow: Dictionary=_place(sim.find_unit(1),Vector2(650,800),"궁병")
    var red: Dictionary=_place(sim.find_unit(3),Vector2(780,800),"보병")
    red["routed"]=true
    var ranks: int=clampi(ceili(float(bow["troops"])/180.0),1,24)
    var full: float=sim._bow_effectiveness(bow,ranks,95.0,1.0,false)
    _check(sim._bow_effectiveness(bow,ranks-5,95.0,1.0,false)<full,"archers use only the portion of the formation in reach")
    _check(sim._bow_effectiveness(bow,ranks,190.0,1.0,false)<full,"distant arrows lose effectiveness")
    bow["motion_speed"]=36.0
    _check(sim._bow_effectiveness(bow,ranks,95.0,1.0,false)<full,"moving archers are less effective")
    bow["motion_speed"]=0.0
    _check(sim._bow_effectiveness(bow,ranks,95.0,0.3,false)<full*0.31,"partial ammunition scales the final damage tick")
    var ally: Dictionary=_place(sim.find_unit(0),Vector2(750,800),"보병")
    _check(sim._bow_lane_screened(bow,red,{0:red}),"a friendly formation in active melee limits arrows")
    ally["pos"]=Vector2(750,920)
    _check(not sim._bow_lane_screened(bow,red,{0:red}),"a formation outside the actual firing lane leaves it open")
    var bank: float=sim.river_x(800.0)
    bow["pos"]=Vector2(bank-110.0,800)
    ally["pos"]=Vector2(bank-28.0,800)
    red["pos"]=Vector2(bank+28.0,800)
    _check(sim._river_separates(ally["pos"],red["pos"]) and not sim._bow_lane_screened(bow,red,{0:red}),
        "opposing formations on separate unbridged banks do not screen arrows")
    bow["pos"]=Vector2(650,800)
    red["pos"]=Vector2(780,800)
    ally["pos"]=Vector2(750,920)
    var shots: float=float(bow["shots_used"])
    sim._combat(0.1)
    var hit: Dictionary=sim.combat_contacts.get(1,{})
    _check(hit.get("kind")=="화살" and float(red["last_arrow_hit"])==sim.battle_time and float(bow["shots_used"])>shots,
        "bow modifier pipeline spends real ammunition and registers real incoming arrows")
    var firing: Array[Vector2]=sim.formation_slots(bow)
    var receiving: Array[Vector2]=sim.formation_slots(red)
    var lanes: Array=hit.get("arrow_lanes",[])
    var actual: bool=lanes.size()>=4
    for i in range(0,lanes.size(),2):
        actual=actual and firing.has(lanes[i]) and receiving.has(lanes[i+1]) and lanes[i].distance_to(lanes[i+1])<=173.0
    _check(actual,"multiple arrow effects connect real positions that are in reach")
    var recovery := _field()
    var recovering: Dictionary=_place(recovery.find_unit(0),Vector2(600,900),"보병")
    recovering["action"]="재집결"
    recovering["fatigue"]=40.0
    recovering["cohesion"]=40.0
    recovering["last_arrow_hit"]=recovery.battle_time
    recovery._update_battle_condition(0.1)
    _check(float(recovering["fatigue"])==40.0 and float(recovering["cohesion"])==40.0,
        "recent incoming arrows interrupt regrouping")
    recovery.battle_time+=1.3
    recovery._update_battle_condition(0.1)
    _check(float(recovering["fatigue"])<40.0 and float(recovering["cohesion"])>40.0,
        "regrouping resumes once incoming volleys cease")

func _ordered_charge() -> void:
    var sim := _field()
    var rider := _place(sim.find_unit(2),Vector2(800,750),"기병","횡대")
    var target := _place(sim.find_unit(3),Vector2(840,750),"보병")
    rider.merge({"charge":80.0,"charge_speed":80.0,"charge_dir":Vector2.RIGHT,"cohesion":90.0},true)
    var reference := sim._charge_impact(rider,target)
    rider["formation"] = "봉시진"
    _check(reference>0 and sim._charge_impact(rider,target)>reference*1.1,"an aligned, formed cavalry wedge concentrates the first impact")
    rider["next_formation"] = "횡대"
    _check(is_equal_approx(sim._charge_impact(rider,target),reference),"reforming cavalry loses the wedge impact")
    rider["next_formation"] = ""
    rider["facing"] = Vector2.DOWN
    _check(is_equal_approx(sim._charge_impact(rider,target),reference),"an off-axis charge gets no wedge impact")
    rider["facing"] = Vector2.RIGHT
    rider["cohesion"] = 35.0
    _check(is_equal_approx(sim._charge_impact(rider,target),reference),"a disordered wedge loses the concentrated impact")

func _charge_and_rear() -> void:
    var front: Array[float]=_charge_loss(false)
    var rear: Array[float]=_charge_loss(true)
    _check(front[0]>0.0 and front[0]<rear[0],"a formed square absorbs more of a frontal charge")
    _check(front[1]>rear[1] and rear[2]>0.0 and front[2]==0.0,"rear shock strips more cohesion and records only actual rear casualties")
    _check(front[3]==1.0 and rear[3]==0.0 and front[4]>rear[4] and rear[4]>=3.0,
        "a brace records its stop and opposing charges consume more horse stamina")

func _charge_loss(from_rear: bool) -> Array[float]:
    var sim := _field()
    var cavalry: Dictionary=_place(sim.find_unit(2),Vector2(970,800),"기병")
    var defender: Dictionary=_place(sim.find_unit(3),Vector2(1005,800),"보병","방진")
    defender["facing"]=Vector2.RIGHT if from_rear else Vector2.LEFT
    cavalry["charge"]=63.0
    cavalry["charge_dir"]=Vector2.RIGHT
    cavalry["charge_speed"]=75.0
    sim._combat(0.1)
    return [float(defender["casualties_taken"]),float(defender["cohesion"]),float(defender["rear_losses"]),
        float(defender["brace_stops"]),float(cavalry["fatigue"])]

# Keep the initial orders fixed while the normal movement, frontage and combat
# updates run. Neither the cavalry's speed nor its momentum is seeded.
func _charge_run(y: float, defender_shape: String, gap: float, order: String = "") -> Dictionary:
    var sim := WarSim.new()
    sim.set_long_operation(true)
    sim.set_scenario(WarSim.TRAINING_SCENARIO)
    for unit in sim.units:
        if unit["id"] not in [2, 3]: unit["troops"] = 0.0
    var rider := sim.find_unit(2)
    var foot := sim.find_unit(3)
    rider["pos"] = Vector2(760 - gap, y)
    foot["pos"] = Vector2(760, y)
    rider["facing"] = Vector2.RIGHT
    foot["facing"] = Vector2.LEFT
    rider["formation"] = "봉시진"
    foot["formation"] = defender_shape
    rider["action"] = "공격 지속"
    foot["action"] = "방어"
    for unit in [rider, foot]:
        unit["goal"] = foot["pos"]
        unit["ai_cooldown"] = 12.0
        unit["next_formation"] = ""
        unit["fatigue"] = 0.0
        unit["cohesion"] = 92.0
        unit["morale"] = 92.0
    if not order.is_empty():
        rider["action"] = "대기"
        rider["ai_cooldown"] = 0.0
        _check(sim.issue_map_order(rider["id"], order, foot["pos"]), "accept cavalry map order " + order)
    sim.start()
    var first: Dictionary = {}
    var peak := 0.0
    var at_impact := Vector2.ZERO
    var displacement := 0.0
    for tick in range(65):
        sim.step(0.1)
        peak = maxf(peak, rider["motion_speed"])
        var hit: Dictionary = sim.combat_contacts.get(2, {})
        if first.is_empty() and not hit.is_empty():
            first = hit
            at_impact = foot["pos"]
        elif not first.is_empty() and sim.battle_time - float(first["time"]) <= 0.51:
            displacement = (foot["pos"] as Vector2).distance_to(at_impact)
    return {"first": first, "peak": peak, "hits": rider["charges"], "displacement": displacement}

func _running_charge() -> void:
    var open := _charge_run(750, "횡대", 175)
    var braced := _charge_run(750, "방진", 175)
    var short_run := _charge_run(750, "횡대", 62)
    var marsh := _charge_run(700, "횡대", 175)
    var ordered := _charge_run(750, "횡대", 175, "공격")
    var hold := _charge_run(750, "횡대", 175, "지역 사수")
    _check(ordered["first"].get("kind") == "돌격" and hold["first"].get("kind") != "돌격",
        "the command map attack builds momentum on approach and a hold order preserves its movement")
    _check(open["peak"] > 145.0 and open["first"].get("kind") == "돌격" and open["hits"] == 1,
        "a cavalry run accelerates into one real impact and cannot rearm inside the melee")
    _check(braced["first"].get("braced", false) and braced["first"]["damage"] < open["first"]["damage"] * 0.4,
        "stationary square catches the first files even when centers are more than 70 apart")
    _check(open["displacement"] > 22.0 and open["displacement"] > braced["displacement"] + 10.0,
        "unbraced ranks physically give way during the first half second")
    _check(short_run["hits"] == 0 and marsh["hits"] == 0, "close melee and entering marsh do not deliver a charge")
    var sim := WarSim.new()
    sim.set_long_operation(true)
    sim.set_scenario(WarSim.TRAINING_SCENARIO)
    var foot := sim.find_unit(3)
    var bank := Vector2(sim.river_x(1100.0) + 29.0, 1100.0)
    foot["pos"] = bank
    foot["charge_recoil"] = Vector2.LEFT * 36
    sim._advance_charge_recoil(foot, 0.5)
    _check(not sim.in_open_water(foot["pos"]) and foot["charge_recoil"] == Vector2.ZERO, "the impact stops at the riverbank")
    var gate: Rect2 = sim.structures[0]["rect"]
    var blue := sim.find_unit(0)
    blue["pos"] = Vector2(gate.position.x - 10, gate.get_center().y)
    blue["charge_recoil"] = Vector2.RIGHT * 36
    sim._advance_charge_recoil(blue, 0.5)
    _check(blue["pos"].x < gate.position.x and blue["charge_recoil"] == Vector2.ZERO, "the impact stops at an intact gate")
    print("CHARGE_RUN grounded ", open["peak"], " impact ", open["first"].get("damage", 0),
        " displacement ", open["displacement"], " braced ", braced["displacement"])

func _targeting() -> void:
    var sim := _field()
    var fighter: Dictionary=_place(sim.find_unit(0),Vector2(970,800),"보병")
    var near: Dictionary=_place(sim.find_unit(3),Vector2(1000,800),"보병")
    var far: Dictionary=_place(sim.find_unit(4),Vector2(1010,800),"보병")
    fighter["contact_target_id"]=int(far["id"])
    _check(sim._combat_target(fighter)==far,"an active melee front retains focus when a slightly closer foe appears")
    far["routed"]=true
    _check(sim._combat_target(fighter)==near,"an active foe takes precedence over pursuing a routed foe")
    near["pos"]=Vector2(1250,800)
    _check(sim._combat_target(fighter)==far,"reachable fallback still pursues when only that foe remains in range")

func _simultaneous_losses() -> void:
    var first: Vector2=_overkill(false)
    var reverse: Vector2=_overkill(true)
    _check(first.x>0.0 and first.y>0.0 and is_equal_approx(first.x+first.y,2.0),
        "two attackers share the real final losses without overkill")
    _check(first.is_equal_approx(reverse),"simultaneous casualty attribution is independent of source order")

func _overkill(reverse: bool) -> Vector2:
    var sim := _field()
    var left: Dictionary=_place(sim.find_unit(0),Vector2(970,795),"궁병")
    var right: Dictionary=_place(sim.find_unit(1),Vector2(970,805),"궁병")
    var enemy: Dictionary=_place(sim.find_unit(3),Vector2(1060,800),"보병")
    enemy["troops"]=2.0
    enemy["routed"]=true
    if reverse: sim.units.reverse()
    sim._combat(0.1)
    _check(is_zero_approx(float(enemy["troops"])) and is_equal_approx(float(enemy["casualties_taken"]),2.0),
        "last defender applies the same loss as the sum of all attackers")
    return Vector2(left["damage_dealt"],right["damage_dealt"])

func _aftermath() -> void:
    var sim := _field()
    var unit := _place(sim.find_unit(0),Vector2(720,750),"보병")
    var enemy := _place(sim.find_unit(3),Vector2(755,750),"보병")
    sim._order_formation(unit,"방진")
    unit.troops-=400
    var state := unit.duplicate(true)
    var slots := sim.formation_slots(unit)
    sim.visual_contact_pair(unit,enemy)
    _check(not slots.is_empty() and state==unit,"rendering a depleted forming corps cannot rewrite its occupied files or clock")
    enemy.action="휴식"
    for tick in range(25):
        sim._combat(0.1)
    _check(enemy.damage_dealt==0 and enemy.casualties_taken>0,"a resting corps can suffer hits but does not launch attacks")
    sim._take_combat_loss(enemy,130.0,unit.pos,true)
    var fallen := sim.fallen_marks.duplicate(true)
    enemy.pos+=Vector2(300,0)
    enemy.routed=true
    sim._update_general_conditions(enemy,0.1)
    _check(fallen.size()>=2 and sim.fallen_marks==fallen,"fallen remain at the hit location as survivors retreat and desert")
    sim.reset()
    _check(sim.fallen_marks.is_empty(),"starting another operation clears the previous battlefield")

func _rear_pressure() -> void:
    var sim := _field()
    var unit := _place(sim.find_unit(0),Vector2(760,790),"보병","방진")
    var front := _place(sim.find_unit(3),Vector2(812,790),"보병","방진")
    var rear := _place(sim.find_unit(4),Vector2(706,790),"보병","방진")
    rear["facing"] = Vector2.RIGHT
    unit["contact_target_id"] = front["id"]
    unit["action"] = "지정 지역 사수"
    unit["goal"] = Vector2(900,790)
    var hits := {}
    var strokes := {}
    for i in range(36):
        sim.battle_time += 0.1
        sim.step_count += 1
        sim._combat(0.1)
        var hit: Dictionary = sim.combat_contacts.get(unit["id"], {})
        if hit.is_empty(): continue
        var id: int = hit["defender_id"]
        hits[id] = hits.get(id,0) + 1
        if hit.has("visual_from"): strokes[id] = true
    _check(hits.get(front["id"],0) == 24 and hits.get(rear["id"],0) == 12,
        "two-sided infantry contact shares 36 strikes between both real opponents")
    _check(strokes.has(front["id"]) and strokes.has(rear["id"]), "both lines receive actual attack animation events")
    var position: Vector2 = unit["pos"]
    var goal: Vector2 = unit["goal"]
    sim._move_unit(unit,0.1)
    _check(unit["pos"] == position and unit["goal"] == goal and unit["facing"].dot(Vector2.RIGHT)>0.99,
        "dual contact holds the corps heading and preserves the player's destination")
    front["troops"] = 0.0
    sim._combat(0.1)
    var heading: Vector2 = unit["facing"]
    sim._move_unit(unit,0.1)
    _check(sim.rear_responses[unit["id"]]["front"] == -1 and absf(heading.angle_to(unit["facing"])) > 0.1 and absf(heading.angle_to(unit["facing"])) <= 0.211,
        "an unopposed rear hit starts a bounded pivot towards the attacker")
    unit["action"] = "후퇴"
    unit["goal"] = position + Vector2(0,100)
    sim._move_unit(unit,0.1)
    sim._combat(0.1)
    _check(not sim.rear_responses.has(unit["id"]) and unit["pos"] != position, "withdrawal proceeds even after a rear hit")
    unit["action"] = "방어"
    unit["facing"] = Vector2.RIGHT
    rear["pos"] = position - Vector2(180,0)
    sim._combat(0.1)
    _check(not sim.rear_responses.has(unit["id"]), "an attacker that leaves contact cannot hold the corps")
    rear["type"] = "궁병"
    rear["pos"] = position - Vector2(100,0)
    for i in range(2): sim._combat(0.1)
    _check(sim.combat_contacts.get(rear["id"],{}).get("kind","") == "화살" and not sim.rear_responses.has(unit["id"]),
        "arrows from behind do not invent a rear melee")

func _planted_feet() -> void:
    var motion = preload("res://scripts/infantry_motion.gd")
    var stations: Array[Vector2] = [Vector2.ZERO,Vector2(10,0),Vector2(20,0),Vector2(0,4),Vector2(10,4),Vector2(20,4)]
    var before: Dictionary = motion.plant({},stations,3,Vector2.ZERO,10,0.1,true)
    var compressed: Array[Vector2] = [Vector2(0.5,0),Vector2(10,0),Vector2(0,4.5),Vector2(10,4)]
    var replanted: Dictionary = motion.plant(before,compressed,2,Vector2.ZERO,11,0.1,true)
    _check(replanted.start[2] == Vector2(0,4) and replanted.end[2] == Vector2(0,4),
        "a casualty keeps the remaining files and their planted feet in place")
    compressed[2]=Vector2(20,4)
    var moved: Dictionary = motion.plant(replanted,compressed,2,Vector2.ZERO,12,0.1,true)
    _check(is_equal_approx(moved.start[2].distance_to(moved.end[2]),2.9) and is_equal_approx(moved.walked[2],2.9),
        "a displaced file walks to its new spot at a bounded pace")
    var deterministic := true
    var during := 0
    var guarding := 0
    for person in 60:
        var age: float = motion.swing_age(0,person,12.21,12.0)
        if motion.contact_pose(age) == 3: during+=1
        if motion.contact_pose(age) == 2: guarding+=1
        deterministic = deterministic and age == motion.swing_age(0,person,12.21,12.0)
    _check(deterministic and during>0 and guarding>0 and motion.swing_age(0,2,11.9,12.0)<0.0,
        "only part of a contacted line strikes on a real event and paused frames keep their pose")
    var pair := PackedVector2Array([Vector2(9,-2),Vector2(9,2)])
    _check(motion.opponent_for(Vector2(0,-2),Vector2.RIGHT,pair,0,1,-1)==0 and motion.opponent_for(Vector2(0,2),Vector2.RIGHT,pair,0,1,-1)==1,
        "two adjacent soldiers face opponents in their own lane")
    _check(motion.opponent_for(Vector2(0,-0.2),Vector2.RIGHT,pair,0,1,24)==1,
        "a near tie retains the current opponent")

    var left: Vector2 = motion.stop_at_contact(Vector2.ZERO,Vector2(4,1),Vector2(8,0),Vector2(4,0))
    var right: Vector2 = motion.stop_at_contact(Vector2(8,0),Vector2(4,0),Vector2.ZERO,Vector2(4,1))
    _check(is_equal_approx(right.x-left.x,4.5) and left.y==1.0, "approaching opponents stop at contact and retain lateral movement")
    _check(motion.stop_at_contact(Vector2.ZERO,Vector2(-3,0),Vector2(4,0),Vector2(2,0)) == Vector2(-3,0),
        "separating opponents can leave the contact")

func _melee_crowd() -> void:
    var motion := preload("res://scripts/infantry_motion.gd")
    var view := preload("res://scripts/front_view.gd")
    var a: Array[Vector2] = [Vector2(-28,-14),Vector2(-10,14)]
    var b: Array[Vector2] = [Vector2(10,-10),Vector2(28,20)]
    var patch := view.melee_patch(a,b,Vector2.RIGHT)
    var reverse := view.melee_patch(b,a,Vector2.LEFT)
    _check(patch["center"].is_equal_approx(Vector2(0,2)) and patch["center"].is_equal_approx(reverse["center"]), "both corps use the same contact area from opposite sides")
    var front := {"axis":Vector2.RIGHT,"tangent":Vector2.DOWN,"patch":Vector2.ZERO,"half_width":22.0,"pressure":0.0,"phase":0.4}
    _check(view.melee_displacement(Vector2(-28,0),front,4).x > 15.0 and view.melee_displacement(Vector2(-28,80),front,4) == Vector2.ZERO, "supporting ranks join close combat while a distant wing keeps its ground")
    var feet := PackedVector2Array([Vector2.ZERO,Vector2.ZERO,Vector2(0,1),Vector2(17,0)])
    motion.spread_neighbours(feet,PackedInt32Array([1,2,3,4]))
    _check(feet[0].distance_to(feet[1])>2.0 and feet[1].distance_to(feet[2])>2.0 and feet[3]==Vector2(17,0), "crowded neighbours make space without disturbing an isolated person")
    _check(motion.nearby_opponent(feet[3],feet,motion.bins_for(feet),-1)==3 and motion.nearby_opponent(Vector2(72,0),feet,motion.bins_for(feet),-1)==-1, "local contact follows actual feet and respects reach")

func _formation_support() -> void:
    var view := preload("res://scripts/front_view.gd")
    var unit := {"formation":"방진","routed":false,"facing":Vector2.RIGHT,"cohesion":90.0,"next_formation":""}
    var square := WarSim.FormationDrill.rank_hold(unit,Vector2.RIGHT,0.0)
    unit["formation"] = "종대"
    var column := WarSim.FormationDrill.rank_hold(unit,Vector2.RIGHT,0.0)
    unit["formation"] = "방진"
    unit["next_formation"] = "횡대"
    _check(square > column and square > WarSim.FormationDrill.rank_hold(unit,Vector2.RIGHT,0.0),
        "an orderly square supports its ranks better than a column or a changing formation")
    unit["next_formation"] = ""
    unit["cohesion"] = 22.0
    _check(WarSim.FormationDrill.rank_hold(unit,Vector2.RIGHT,1.0) < column, "a depleted, pressured formation yields ground")
    var contact := {"axis":Vector2.RIGHT,"tangent":Vector2.DOWN,"patch":Vector2.ZERO,"half_width":22.0,
        "phase":0.4,"pressure":0.0,"hold":square,"back":-32.0,"inverse_depth":1.0/32.0}
    var rear := view.melee_displacement(Vector2(-32,0),contact,4).length()
    var front := view.melee_displacement(Vector2.ZERO,contact,4).length()
    contact["inverse_depth"] = 0.0
    var single := view.melee_displacement(Vector2.ZERO,contact,4).length()
    contact["hold"] = 0.0
    _check(rear < 0.30*view.melee_displacement(Vector2(-32,0),contact,4).length()
        and front > 0.70*view.melee_displacement(Vector2.ZERO,contact,4).length() and is_equal_approx(front,single),
        "rear ranks retain their places while the leading or last surviving rank can still engage")

    contact["hold"] = square
    contact["inverse_depth"] = 1.0/32.0
    contact["reach"] = 8.0
    _check(view.melee_displacement(Vector2.ZERO,contact,4).length()>front
        and view.melee_displacement(Vector2(-32,0),contact,4).length()<front,
        "at a measured contact gap, lead files step in while the held tail remains behind")

    var line := _infantry_duel("횡대")
    var block := _infantry_duel("방진")
    var file := _infantry_duel("종대")
    _check(line["contacts"] > file["contacts"] and line["damage"] > block["damage"],
        "a line brings more files into the same fight and deals more damage than a square")
    _check(block["loss"] < line["loss"] and block["push"] > line["push"] and file["yield"] > block["yield"],
        "the square resists and pushes while the column gives ground in the same encounter")

func _infantry_duel(shape: String) -> Dictionary:
    var sim := _field()
    var own := _place(sim.find_unit(0),Vector2(820,750),"보병",shape)
    var enemy := _place(sim.find_unit(3),Vector2(858,750),"보병","횡대")
    for u: Dictionary in [own,enemy]:
        u["initial_troops"] = 3600.0
        u["troops"] = 3600.0
        u["cohesion"] = 90.0
        u["morale"] = 90.0
        u["fatigue"] = 0.0
        u["specialty"] = ""
    var contacts := 0
    for step in range(30):
        sim.step_count += 1
        sim.battle_time += 0.1
        sim._resolve_frontline(0.1)
        sim._combat(0.1)
        contacts += int(own["contact_troops"])
    return {"contacts":contacts, "damage":own["damage_dealt"], "loss":own["casualties_taken"],
        "push":enemy["pushed_distance"], "yield":own["pushed_distance"]}
