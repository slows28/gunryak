extends SceneTree

const WarSim = preload("res://scripts/war_sim.gd")
var failures: int=0

func _initialize() -> void:
    _bows()
    _charge_and_rear()
    _targeting()
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
