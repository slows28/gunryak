extends RefCounted
# Demo campaign: all strategic effects are carried into actual battle setup.
const GeneralMind = preload("res://scripts/general_mind.gd")
const Profiles=preload("res://scripts/officer_profiles.gd")
const SAVE_PATH = "user://gunryak_demo_v1.json"
const NODES = [
    {"name":"한중","pos":[100,300],"links":[1,2],"scenario":0,"story":"촉군의 출발지. 보급을 정비한다."},
    {"name":"기산 관문","pos":[280,180],"links":[0,3],"scenario":0,"story":"북벌의 첫 관문. 두 길을 동시에 장악한다."},
    {"name":"진창 고지","pos":[280,410],"links":[0,3,4],"scenario":1,"story":"험한 고지에서 위군의 방어선을 돌파한다."},
    {"name":"가정","pos":[510,180],"links":[1,2,5],"scenario":2,"story":"위군의 반격에 맞서 본진을 지킨다."},
    {"name":"보급 회랑","pos":[510,410],"links":[2,5],"scenario":3,"story":"군량 수레를 전선까지 호위한다."},
    {"name":"천수","pos":[720,295],"links":[3,4],"scenario":4,"story":"적의 핵심 진지를 돌파하는 마지막 작전."}
]
const EXTRA_SLOTS = [9,10,11,12]
const NEW_CORPS = {"active":EXTRA_SLOTS,"troops":[3900,3700,3400,3500],
    "formations":["방진","어린진","안행진","봉시진"],"types":["보병","보병","궁병","기병"]}
const OFFICERS = [
    {"name":"왕평","personality":"신중","stats":Profiles.DATA["왕평"][1],"specialty":"방진"},
    {"name":"마속","personality":"균형","stats":Profiles.DATA["마속"][1],"specialty":"정찰"},
    {"name":"위연","personality":"공격","stats":Profiles.DATA["위연"][1],"specialty":"돌격"},
    {"name":"강유","personality":"균형","stats":Profiles.DATA["강유"][1],"specialty":"정찰"},
    {"name":"관흥","personality":"공격","stats":Profiles.DATA["관흥"][1],"specialty":"돌격"},
    {"name":"장익","personality":"신중","stats":Profiles.DATA["장익"][1],"specialty":"방진"},
    {"name":"요화","personality":"신중","stats":Profiles.DATA["요화"][1],"specialty":"방진"},
    {"name":"마대","personality":"공격","stats":Profiles.DATA["마대"][1],"specialty":"돌격"},
    {"name":"오의","personality":"균형","stats":Profiles.DATA["오의"][1],"specialty":"정찰"},
    {"name":"장포","personality":"공격","stats":Profiles.DATA["장포"][1],"specialty":"방진"},
    {"name":"진도","personality":"신중","stats":Profiles.DATA["진도"][1],"specialty":"방진"},
    {"name":"등지","personality":"균형","stats":Profiles.DATA["등지"][1],"specialty":"정찰"},
    {"name":"오반","personality":"공격","stats":Profiles.DATA["오반"][1],"specialty":"돌격"}
]
var state: Dictionary = {}
var six_armies: bool = false
var save_path: String = SAVE_PATH
func _init() -> void:
    reset()

func reset() -> void:
    var people: Array = []
    for i in range(OFFICERS.size() if six_armies else 6):
        people.append({"recruited":(i<6 or i in EXTRA_SLOTS) if six_armies else i<3,"hp":100,"dead":false,"xp":0})
    state = {"version":1,"turn":1,"gold":220,"food":260,"pool":180,"position":0,"owned":[0],"garrison":[0,100,108,115,102,125],"roster":people,"active":[0,1,2],"troops":[145,108,95],"types":["보병","궁병","기병"],"history":[],"victories":0,"defeats":0,"complete":false,"failed":false,"pending":-1,"difficulty":1}
    if six_armies:
        state["version"] = 4
        state["active"] = [0,1,2,3,4,5]
        state["troops"] = [4500,3500,3200,4000,3800,4500]
        state["formations"] = ["방진","안행진","봉시진","학익진","봉시진","방진"]
        state["types"] = ["보병","궁병","기병","궁병","기병","보병"]
        for key in NEW_CORPS: state[key].append_array(NEW_CORPS[key])
        state["gold"] = 340
        state["food"] = 340
        state["pool"] = 10000

func set_six_armies(enabled: bool) -> void:
    six_armies = enabled
    save_path = "user://gunryak_demo_v3.json" if enabled else SAVE_PATH
    reset()

func available(index: int) -> bool:
    if index < 0 or index >= NODES.size() or state["complete"] or state["failed"]:
        return false
    for owned in state["owned"]:
        if index in NODES[int(owned)]["links"] and index not in state["owned"]:
            return true
    return false

func recruit(index: int) -> bool:
    if index < 0 or index >= state["roster"].size() or state["pending"] >= 0:
        return false
    var person: Dictionary = state["roster"][index]
    if person["recruited"] or int(state["gold"]) < 55:
        return false
    state["gold"] -= 55
    person["recruited"] = true
    return true

func assign(slot: int, index: int) -> bool:
    if slot < 0 or slot >= state["active"].size() or index < 0 or index >= state["roster"].size() or state["pending"] >= 0:
        return false
    var person: Dictionary = state["roster"][index]
    if not person["recruited"] or person["dead"]:
        return false
    var old: int = state["active"].find(index)
    if old >= 0:
        state["active"][old] = state["active"][slot]
    state["active"][slot] = index
    return true

func replenish(slot: int) -> bool:
    if slot < 0 or slot >= state["active"].size() or int(state["gold"]) < 15 or state["pending"] >= 0: return false
    var amount: int = mini(500 if six_armies else 20,(5000 if six_armies else 220)-int(state["troops"][slot]))
    if amount <= 0 or int(state["pool"]) < amount: return false
    state["pool"] -= amount
    state["gold"] -= 15
    state["troops"][slot] += amount
    return true

func set_type(slot: int, kind: String) -> bool:
    if slot < 0 or slot >= state["active"].size() or kind not in ["보병","궁병","기병"] or state["pending"] >= 0:
        return false
    if state["types"][slot] == kind:
        return true
    if int(state["gold"]) < 12:
        return false
    state["gold"] -= 12
    state["types"][slot] = kind
    return true

func rest() -> bool:
    if int(state["food"]) < 25 or state["pending"] >= 0 or state["complete"] or state["failed"]:
        return false
    state["food"] -= 25
    for person in state["roster"]:
        if person["recruited"] and not person["dead"]:
            person["hp"] = mini(100,int(person["hp"])+25)
    strategic_tick(-1)
    return true

func resupply() -> bool:
    if int(state["gold"]) < 25 or state["pending"] >= 0:
        return false
    state["gold"] -= 25
    state["food"] += 45
    return true

func strategic_tick(target: int) -> void:
    state["turn"] += 1
    state["gold"] += 12 + state["owned"].size()*5
    state["food"] += state["owned"].size()*8
    state["pool"] += 600 if six_armies else 15
    for i in range(1,NODES.size()):
        if i not in state["owned"]:
            state["garrison"][i] = mini(155,int(state["garrison"][i])+(3 if i == target else 6))
    # A strategic counterattack can cost an exposed non-capital region.
    if int(state["turn"])%4 == 0 and state["owned"].size() > 1 and not state["complete"]:
        var exposed: int = -1
        for node in state["owned"]:
            if int(node) == 0 or int(node) == target:
                continue
            for neighbor in NODES[int(node)]["links"]:
                if neighbor not in state["owned"] and int(state["garrison"][neighbor]) >= 125:
                    exposed = int(node)
                    break
        if exposed >= 0:
            state["owned"].erase(exposed)
            if int(state["position"]) == exposed:
                state["position"] = 0
            state["history"].append(NODES[exposed]["name"]+" — 위군 반격으로 상실")

func prepare(target: int, sim) -> bool:
    var cost: int = 55 if six_armies else 35
    if not available(target) or state["pending"] >= 0 or int(state["food"]) < cost:
        return false
    for i in range(state["active"].size()):
        if int(state["troops"][i]) < 1 or state["roster"][int(state["active"][i])]["dead"]:
            return false
    sim.reset()
    if not sim.set_scenario(int(NODES[target]["scenario"])):
        return false
    state["food"] -= cost
    state["pending"] = target
    var ids: Array[int] = sim.command_ids(0)
    for i in range(state["active"].size()):
        var u: Dictionary = sim.find_unit(ids[i])
        var idx: int = int(state["active"][i])
        var officer: Dictionary = OFFICERS[idx]
        var person: Dictionary = state["roster"][idx]
        u["name"] = officer["name"]
        u["formation_skill"] = sim.Skills.Profiles.FORMATION_SKILL[u.name]
        u["personality"] = officer["personality"]
        u["type"] = state["types"][i]
        u["formation"] = str(state["formations"][i]) if six_armies else ("종대" if u["type"] == "기병" else "횡대")
        if six_armies: u["policy"] = "현장 판단"
        u["troops"] = float(state["troops"][i])
        u["initial_troops"] = u["troops"]
        u["general_hp"] = float(person["hp"])
        u["general_risk"] = (100.0-float(person["hp"]))/1.4
        u["general_state"] = "부상" if int(person["hp"]) < 55 else "건재"
        var level: int = mini(10,floori(float(person["xp"])/100.0))
        for j in range(5):
            var key: String = ["leadership","martial","intelligence","judgment","loyalty"][j]
            u[key] = minf(100.0,float(officer["stats"][j])+level)
        u["specialty"] = officer["specialty"]
        u["mind"] = GeneralMind.initial(u)
        sim.Skills.attach(u,u["name"],"")
        u["rations"] = clampf(70.0+float(state["food"])*0.12,70.0,100.0)
    var scale: float = float(state["garrison"][target])/100.0 * [0.82,1.0,1.18][int(state["difficulty"])]
    for unit in sim.units:
        if int(unit["side"]) == 1:
            unit["troops"] = clampf(roundf(float(unit["troops"])*scale),3000.0,5000.0) if six_armies else roundf(float(unit["troops"])*scale)
            unit["initial_troops"] = unit["troops"]
    sim.CorpsFormation.prepare_all(sim)
    sim.reserve_limit[0] = mini(1 if six_armies else 2,floori(float(state["pool"])/(3000.0 if six_armies else 72.0)))
    return true

func conclude(sim) -> bool:
    var target: int = int(state["pending"])
    if target < 0 or not sim.finished:
        return false
    var won: bool = sim.winning_side == 0
    var ids: Array[int] = sim.command_ids(0)
    for i in range(state["active"].size()):
        var unit: Dictionary = sim.find_unit(ids[i])
        var idx: int = int(state["active"][i])
        var person: Dictionary = state["roster"][idx]
        person["hp"] = int(unit["general_hp"])
        person["dead"] = str(unit["general_state"]) == "전사"
        var corps: Dictionary = sim.corps_report(ids[i])
        person["xp"] += int(corps["merit"])
        state["troops"][i] = maxi(0,floori(float(corps["troops"])))
        if six_armies and str(unit["policy"]).ends_with(" 유지"):
            var shape: String = str(unit["policy"]).replace(" 유지","")
            if shape in ["횡대","종대","방진","어린진","학익진","봉시진","안행진"]: state["formations"][i] = shape
    state["pool"] = maxi(0,int(state["pool"])-sim.reinforcements_used[0]*(3000 if six_armies else 72))
    if won:
        if target not in state["owned"]:
            state["owned"].append(target)
        state["position"] = target
        state["gold"] += 70
        state["food"] += 40
        state["victories"] += 1
        state["complete"] = target == 5
    else:
        state["defeats"] += 1
        if int(state["position"]) != 0:
            state["owned"].erase(state["position"])
            state["position"] = 0
        state["gold"] += 20
        state["failed"] = int(state["defeats"]) >= 3
    state["history"].append(NODES[target]["name"]+" — "+sim.result)
    state["pending"] = -1
    strategic_tick(target)
    return true

func save() -> bool:
    if int(state["pending"]) >= 0:
        return false
    var file := FileAccess.open(save_path,FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(state))
    return true

func load_save() -> bool:
    if not FileAccess.file_exists(save_path):
        return false
    var file := FileAccess.open(save_path,FileAccess.READ)
    if file == null:
        return false
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return false
    var data: Dictionary = parsed
    for key in state:
        if not data.has(key):
            return false
    if six_armies and data["version"]==3:
        if not data["roster"] is Array or data["roster"].size()!=9: return false
        for key in ["active","troops","types","formations"]:
            if not data[key] is Array or data[key].size()!=6: return false
        for key in NEW_CORPS: data[key].append_array(NEW_CORPS[key])
        for id in EXTRA_SLOTS:
            data["roster"].append({"recruited":true,"hp":100,"dead":false,"xp":0})
        data["version"]=4
    var slots: int = 10 if six_armies else 3
    if int(data["version"]) != (4 if six_armies else 1) or data["roster"].size() != (OFFICERS.size() if six_armies else 6) or data["active"].size() != slots or data["troops"].size() != slots or data["types"].size() != slots or data["garrison"].size() != 6 or int(data["pending"]) != -1:
        return false
    for key in ["gold","food","pool","turn","victories","defeats","position","difficulty"]:
        if not (data[key] is int or data[key] is float):
            return false
        data[key] = int(data[key])
        if int(data[key]) < 0:
            return false
    if int(data["difficulty"]) > 2 or int(data["position"]) >= NODES.size():
        return false
    for key in ["owned","active","troops","garrison"]:
        for i in range(data[key].size()):
            data[key][i] = int(data[key][i])
    for person in data["roster"]:
        person["hp"] = int(person["hp"])
        person["xp"] = int(person["xp"])
    for idx in data["active"]:
        if int(idx) < 0 or int(idx) >= data["roster"].size():
            return false
    for idx in data["owned"]:
        if int(idx) < 0 or int(idx) >= NODES.size():
            return false
    for value in data["troops"]:
        if int(value) < 0 or int(value) > (5000 if six_armies else 220):
            return false
    if six_armies:
        if not data["formations"] is Array or data["formations"].size()!=slots: return false
        for shape in data["formations"]:
            if not shape in ["횡대","종대","방진","어린진","학익진","봉시진","안행진"]: return false
    data["pending"] = -1
    state = data
    return true

func set_formation(slot: int,shape: String) -> bool:
    if not six_armies or slot<0 or slot>=state["active"].size() or state["pending"]>=0 or not shape in ["횡대","종대","방진","어린진","학익진","봉시진","안행진"]: return false
    state["formations"][slot]=shape
    return true
