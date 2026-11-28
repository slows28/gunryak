extends RefCounted
const Legacy=preload("res://scripts/campaign.gd")
const Field=preload("res://scripts/northern_field.gd")
const Skills=preload("res://scripts/field_skills.gd")
const EXTRA := ["조운","황충","유봉","향총","나헌","양의","부첨","동윤","윤상","이엄","고상","장남"]
const EXTRA_SPECIALTIES := ["돌격","정찰","돌격","방진","방진","정찰","방진","정찰","정찰","방진","돌격","돌격"]
const TYPES := ["보병","궁병","기병","궁병","기병","보병","보병","보병","궁병","기병","기병","보병"]
const SHAPES := ["방진","안행진","봉시진","학익진","봉시진","방진","방진","어린진","안행진","봉시진","봉시진","횡대"]
const TROOPS := [4500,3500,3200,4000,3800,4500,3900,3700,3400,3500,3600,3800]
var officers: Array=Legacy.OFFICERS.duplicate(true)
var state: Dictionary={}
var save_path: String="user://gunryak_northern_v1.json"
var save_error: String=""

func _init() -> void:
    for i in EXTRA.size():
        var officer: String=EXTRA[i]
        var entry: Array=Skills.Profiles.DATA[officer]
        var aggression: int=entry[0][1]
        officers.append({"name":officer,"stats":entry[1],"specialty":EXTRA_SPECIALTIES[i],
            "personality":"공격" if aggression>=66 else ("신중" if aggression<=40 else "균형")})
    reset()

func reset() -> void:
    state={"version":1,"stage":1,"turn":1,"active":[0,1,2,3,4,5,9,10,11,12,13,6],"types":TYPES.duplicate(),"items":["pace","regroup","shield"],"gear":{},"claimed":[],"reward":0,"pending":-1,"complete":false,"history":[],"difficulty":1}

func preparing() -> bool:
    return state["pending"]<0 and state["reward"]==0 and not state["complete"]

func assign(slot: int,officer: int) -> bool:
    if not preparing() or slot<0 or slot>=TYPES.size() or officer<0 or officer>=officers.size(): return false
    var old: int=state["active"].find(officer)
    if old>=0: state["active"][old]=state["active"][slot]
    state["active"][slot]=officer
    return true

func equip(officer: int,id: String) -> bool:
    if not preparing() or officer<0 or officer>=officers.size(): return false
    if id!="" and id not in state["items"]: return false
    var key:=str(officer)
    if id!="":
        var former: Variant=state["gear"].find_key(id)
        if former!=null: state["gear"].erase(former)
        state["gear"][key]=id
    else: state["gear"].erase(key)
    return true

func prepare(target: int,sim) -> bool:
    if not preparing() or target!=state["stage"] or not sim.long_operation: return false
    if not save(): return false
    sim.started=false
    sim.set_scenario(Field.CHAPTERS[target-1][1])
    Field.deploy(sim,target)
    for i in range(2):
        sim._add_unit(0,"후군",TYPES[10+i],"균형",80.0,Vector2(460,590+i*450),"중앙 진격" if i==0 else "본진 방어",TROOPS[10+i])
    var ids: Array[int]=sim.command_ids(0)
    for i in ids.size():
        var u: Dictionary=sim.find_unit(ids[i])
        var idx: int=state["active"][i]
        var general: Dictionary=officers[idx]
        u["name"]=general["name"]
        u["personality"]=general["personality"]
        u["specialty"]=general["specialty"]
        u["ability"]=general["stats"][0]
        for j in 5: u[["leadership","martial","intelligence","judgment","loyalty"][j]]=general["stats"][j]
        u["deployment"]=Skills.Profiles.DEPLOYMENT[u.name]
        u["type"]=state["types"][i]
        u["troops"]=float(TROOPS[i])
        u["initial_troops"]=u["troops"]
        u["formation"]=SHAPES[i] if u["type"]==TYPES[i] else {"보병":"횡대","궁병":"안행진","기병":"봉시진"}[u["type"]]
        u["mind"]=Legacy.GeneralMind.initial(u)
        Skills.attach(u,u["name"],state["gear"].get(str(idx),""))
    for u in sim.units:
        if u["side"]!=1: continue
        u["troops"]=clampf(u["troops"]*[0.88,1.03,1.16][state["difficulty"]],3000,5000)
        u["initial_troops"]=u["troops"]
        Skills.attach(u,u["name"],["","counter","wing","rally"][mini(3,target/4)])
    Field.opening_orders(sim)
    sim.Deployment.arrange(sim)
    sim.chapter["enemy_initial"]=sim.total_troops(1)
    state["pending"]=target
    return true

func conclude(sim) -> bool:
    var target: int=state["pending"]
    if target<1 or not sim.finished: return false
    state["pending"]=-1
    state["turn"]+=1
    state["history"].append(sim.scenario_title+" · "+sim.result)
    if sim.winning_side==0:
        if target==Field.CHAPTERS.size(): state["complete"]=true
        elif target not in state["claimed"]: state["reward"]=target
    return true

func choices() -> Array:
    var n: int=state["reward"]
    return [] if n<=0 else Field.CHAPTERS[n-1][6].duplicate()

func claim(id: String) -> bool:
    var stage: int=state["reward"]
    if id not in choices() or stage in state["claimed"] or id in state["items"]: return false
    var old:=state.duplicate(true)
    state["items"].append(id)
    state["claimed"].append(stage)
    state["reward"]=0
    state["stage"]=stage+1
    if not save():
        state=old
        return false
    return true

func save() -> bool:
    if state["pending"]>=0: return false
    save_error=""
    var tmp:=save_path+".tmp"
    var file:=FileAccess.open(tmp,FileAccess.WRITE)
    if file!=null:
        file.store_string(JSON.stringify(state))
        file.flush()
        var code:=file.get_error()
        file.close()
        if code==OK and DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp),ProjectSettings.globalize_path(save_path))==OK: return true
    save_error="북벌 기록을 저장할 수 없습니다."
    return false

func load_save() -> bool:
    if not FileAccess.file_exists(save_path): return false
    var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(save_path))
    if not parsed is Dictionary: return false
    for key in state:
        if not parsed.has(key) or typeof(parsed[key])!=typeof(state[key]) and not (state[key] is int and parsed[key] is float): return false
    for key in ["stage","reward","turn","difficulty","pending","version"]:
        if parsed[key]!=int(parsed[key]): return false
        parsed[key]=int(parsed[key])
    if parsed.version!=1 or parsed.stage!=int(parsed.stage) or parsed.stage<1 or parsed.stage>13 or parsed.pending!=-1 or parsed.difficulty not in [0,1,2] or parsed.active.size()!=12 or parsed.types.size()!=12: return false
    if parsed.reward!=0 and (parsed.reward!=parsed.stage or parsed.stage==13): return false
    if parsed.complete and (parsed.stage!=13 or parsed.reward!=0): return false
    if parsed.claimed.size()!=int(parsed.stage)-1 or parsed["items"].size()!=3+parsed.claimed.size(): return false
    var distinct: Dictionary={}
    for value in parsed["items"]:
        if not Skills.CATALOG.has(value) or distinct.has(value): return false
        distinct[value]=true
    for id in ["pace","regroup","shield"]:
        if id not in distinct: return false
    for i in parsed.claimed.size():
        if parsed.claimed[i]!=i+1: return false
        var count:=0
        for id in Field.CHAPTERS[i][6]:
            if id in distinct: count+=1
        if count!=1: return false
        parsed.claimed[i]=i+1
    distinct.clear()
    for i in parsed.active.size():
        var idx: Variant=parsed.active[i]
        if not (idx is float or idx is int) or idx!=int(idx) or idx<0 or idx>=officers.size() or distinct.has(int(idx)) or parsed.types[i] not in ["보병","기병","궁병"]: return false
        distinct[int(idx)]=true
        parsed.active[i]=int(idx)
    distinct.clear()
    for key in parsed.gear:
        var id: Variant=parsed.gear[key]
        if not key.is_valid_int() or str(int(key))!=key or int(key)<0 or int(key)>=officers.size() or id not in parsed["items"] or distinct.has(id): return false
        distinct[id]=true
    state=parsed
    return true
