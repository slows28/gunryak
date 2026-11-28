extends RefCounted
const Profiles=preload("res://scripts/officer_profiles.gd")
const March = preload("res://scripts/linked_march.gd")
## Model seconds. Orders classify eligibility only. Skills consume real contacts and never issue orders.
const ALL := ["attack","guard","march","support","withdraw"]
const OFFENSE := ["attack"]
const MOBILE := ["attack","march","support"]
const DEFENSE := ["guard","support"]
# trigger, effect, missions, target, radius, strength, duration, cooldown, priority, condition text
const RULES := {
    "shock_contact":["impact","stagger",OFFENSE,"enemy",0,0.14,1.5,4.0,10,"기병이 공격 임무 중 적 대열에 돌격 적중"],
    "single_volley":["arrow_hit","precision",["attack","guard","support"],"enemy",0,1.0,0.9,4.0,10,"궁병이 유효 사거리에서 화살 명중"],
    "break":["melee","break",OFFENSE,"enemy",30,12.0,3.0,22.0,7,"공격 임무로 적 대열과 근접 교전"],
    "onslaught":["melee","attack",OFFENSE,"self",30,0.35,4.0,23.0,5,"공격 임무로 근접전을 지속"],
    "wall":["pressure","guard",DEFENSE,"self",0,0.38,5.0,22.0,8,"방어·엄호 임무 중 적의 공격이 집중"],
    "stand":["morale","stand",ALL,"self",0,1.0,5.0,32.0,11,"사기가 24 이하로 하락"],
    "speed":["moving","stride",MOBILE,"self",0,0.32,5.0,22.0,4,"이동·우회·지원 임무로 행군"],
    "pursuit":["pursuit","pursue",OFFENSE,"self",250,0.42,4.5,24.0,6,"공격 임무 중 관측한 적이 패주하고 추격 경로에 있음"],
    "pincer":["crossfire","attack",OFFENSE,"enemy",0,0.46,4.0,22.0,8,"다른 방향의 아군과 같은 적을 공격"],
    "feint":["bait","feint",OFFENSE,"self",145,0.42,3.2,27.0,7,"자율·공격 임무에서 관측한 적이 접근"],
    "dress":["disorder","reform",ALL,"self",0,19.0,1.0,22.0,8,"부대 응집도가 55 이하로 하락"],
    "drum":["low_allies","rally",ALL,"allies",150,10.0,1.0,26.0,7,"인근 아군의 사기가 72 미만"],
    "bow":["volley","volley",["attack","guard","support"],"enemy",173,0.36,4.0,23.0,5,"궁병이 탄약을 보유하고 실제 사격"],
    "siege":["gate","siege",OFFENSE,"structure",65,0.65,5.0,20.0,6,"공격 임무로 적 방어시설에 접근"],
    "flank":["flank","break",OFFENSE,"enemy",30,15.0,3.0,24.0,8,"공격 임무로 적 측후방에 근접"],
    "ambush":["cover","attack",OFFENSE,"self",0,0.42,4.0,24.0,6,"숲에 숨어 있다가 적과 접촉"],
    "crossing":["ford","stride",MOBILE,"self",110,0.38,5.0,21.0,5,"교량이나 강둑으로 접근해 행군"],
    "bridge_guard":["bridge_guard","guard",DEFENSE,"self",165,0.46,5.0,23.0,8,"교량 근처에서 적의 공격을 받음"],
    "charge":["run","attack",OFFENSE,"self",0,0.38,4.0,23.0,6,"기병이 돌격 가속을 확보"],
    "counter":["defend_hit","attack",DEFENSE,"self",0,0.33,4.0,23.0,7,"방어 임무에서 적의 타격을 받음"]
}
# Skill ID, equipment, skill title, rule and potency. Named items are unique within a campaign.
const CATALOG := {
    "strike":["진철추","강타","onslaught",0.72],
    "square":["방패진도","방진","wall",0.75],
    "dash":["청총마","질주","speed",0.8],
    "inspire":["진군고","고무","drum",1.0],
    "rapid":["신기궁","속사","bow",1.0],
    "harass":["유엽궁","견제","bow",0.8],
    "ambush":["복병도","매복","ambush",1.0],
    "decoy":["맹덕신서","기만","feint",1.0],
    "swift":["경행부","신속","speed",1.05],
    "iron":["현무갑","철벽","wall",1.0],
    "last":["백은갑","결사","stand",1.0],
    "counter":["호위패","역습","counter",1.0],
    "breach":["청룡언월도","파진","break",1.0],
    "fury":["방천화극","맹공","onslaught",1.0],
    "wing":["비익기","측면공격","flank",1.0],
    "link":["손자병법","협공","pincer",1.0],
    "relief":["백룡마","질풍","speed",1.0],
    "rally":["백호병부","재정비","dress",1.0],
    "siege":["공성병법서","공성","siege",1.0],
    "focus":["연노도","집중사격","bow",1.15],
    "screen":["엄호진서","엄호","wall",0.9],
    "charge":["장창기","돌격","charge",1.0],
    "pursue":["절영","추격","pursuit",1.0],
    "enclose":["쌍익도","포위","pincer",1.08],
    "chain":["연환책","연환공격","pincer",1.17],
    "bastion":["장성진도","대방진","wall",1.18],
    "war_drum":["대고","군단고무","drum",1.3],
    "ford":["부교도","도하지원","crossing",1.0],
    "bridge":["보루인","교두보방어","bridge_guard",1.0],
    "surprise":["야행부","기습","ambush",1.18],
    "cascade":["용기창","연쇄돌격","charge",1.23],
    "reshape":["정렬기","전열재편","dress",1.25],
    "reverse":["회군도","역포위","counter",1.23],
    "tiger":["호부대인","호위군세","drum",1.48],
    "thunder":["뇌정전통","신궁연사","bow",1.42],
    "ram":["운제비책","성문분쇄","siege",1.4],
    "pace":["행군절","보조행군","speed",0.55],
    "regroup":["집결인","대열수습","dress",0.55],
    "shield":["수비패","진지엄호","wall",0.6],
}
const SIGNAL := {"stagger":Color("#ca9a75"),"precision":Color("#d8b779"),"break":Color("#d18b69"),"attack":Color("#ce9677"),"guard":Color("#8bb4c2"),"stand":Color("#b2b4c8"),"stride":Color("#a4bc98"),"pursue":Color("#bbaa82"),"feint":Color("#b7a4b8"),"reform":Color("#a2b6b6"),"rally":Color("#d3bd83"),"volley":Color("#b7b394"),"siege":Color("#bd9680")}
const EFFECT_TEXT := {"stagger":"적 한 부대가 잠시 혼란 · 공격 위력 14% 감소","precision":"한 번의 사격 피해 2배 · 추가 손실 최대 20명","break":"상대 응집 감소","attack":"조건을 충족한 공격 피해 증가","guard":"받는 피해·충격 사기 손실 감소","stand":"사기 패주 억제","stride":"이동 속도 증가","pursue":"패주 중인 상대를 향한 이동 가속","feint":"잠시 물러나며 받는 피해 감소","reform":"응집 회복","rally":"인근 아군 사기 회복","volley":"실제 화살 피해 증가","siege":"방어시설 피해 증가"}

static func title(id: String) -> String:
    return Profiles.DATA[id][2] if Profiles.DATA.has(id) else CATALOG[id][1]

static func rule_for(id: String) -> Array:
    return RULES[Profiles.DATA[id][3] if Profiles.DATA.has(id) else CATALOG[id][2]]

static func describe_signature(officer: String) -> String:
    var rule:=rule_for(officer)
    var power:=float(rule[5])*float(Profiles.DATA[officer][4])
    var seconds:=int(minf(rule[6],3.0)*4)
    var effect: String=EFFECT_TEXT[rule[1]]
    match rule[1]:
        "break": effect="적 응집 −%d" % roundi(power)
        "attack","volley": effect="%d초간 해당 공격 피해 +%d%%" % [seconds,roundi(power*100)]
        "guard","feint": effect="%d초간 받는 피해 −%d%%" % [seconds,roundi(power*100)]
        "stride","pursue": effect="%d초간 이동 속도 +%d%%" % [seconds,roundi(power*100)]
        "stand": effect="%d초간 사기 패주 억제" % seconds
        "rally": effect="주변 아군 사기 +%d" % roundi(power)
        "reform": effect="자군 응집 +%d" % roundi(power)
        "siege": effect="%d초간 시설 피해 +%d%%" % [seconds,roundi(power*100)]
        "stagger": effect="적 한 부대 6초 혼란 · 공격 위력 −14%"
        "precision": effect="이번 사격 최대 2배 · 추가 손실 최대 20명"
    return "발동   %s\n효과   %s" % [rule[9],effect]

static func describe(id: String) -> String:
    if not CATALOG.has(id): return "장착 없음"
    var item: Array=CATALOG[id]
    var rule: Array=RULES[item[2]]
    return "%s · %s\n%s → %s\n지속 %.0f초 · 재사용 %.0f초" % [item[0],item[1],rule[9],EFFECT_TEXT[rule[1]],rule[6]*4.0,rule[7]*4.0]

static func mission(u: Dictionary,now: float) -> String:
    if u.get("tactical_until",0.0)>now:
        match u["tactical_order"]:
            "철수","재집결": return "withdraw"
            "사수": return "guard"
            "지원": return "support"
    if u["action"] in ["패주","후퇴","전술 철수"]: return "withdraw"
    var order: String=March.role(u,now)
    if order in ["철수","후퇴"]: return "withdraw"
    if order in ["지역 사수","지정 지역 사수","본진 방어","예비 대기"]: return "guard"
    if order=="궁병 보호": return "guard"
    if order in ["구원 지원","전열 엄호"]: return "support"
    if order in ["지정 위치 이동","측후방 기동","남측 우회"]: return "march"
    if order in ["자유 재량","북측 확보","중앙 진격","남측 확보"]:
        if u["action"] in ["방어","방어선 사수","지정 지역 사수"]: return "guard"
        if u["action"] in ["궁병 보호","전열 유지","거점 방어"]: return "guard"
        if u["action"] in ["구원 지원","전열 지원"]: return "support"
    return "attack"

static func ready(sim,u: Dictionary,rule: Array) -> bool:
    var own: Dictionary=sim.combat_contacts.get(u["id"],{})
    var hurt: bool=sim.battle_time-u["last_hit"]<1.25
    match rule[0]:
        "melee": return not own.is_empty() and own["kind"]!="화살"
        "pressure":
            if not hurt: return false
            var hits:=0
            for hit in sim.combat_contacts.values():
                if hit["defender_id"]==u["id"]: hits+=1
            return hits>=2 or u["front_pressure"]>0.12 or u["cohesion"]<72
        "defend_hit": return hurt
        "morale": return u["morale"]<=24
        "disorder": return u["cohesion"]<=55
        "moving": return not sim.march_plans.has(u["id"]) and u["motion_speed"]>6 and Vector2(u["goal"]).distance_to(u["pos"])>22
        "volley": return u["type"]=="궁병" and u["ammo"]>0 and own.get("kind","")=="화살"
        "run": return u["type"]=="기병" and u["charge"]>32
        "cover": return sim._in_forest(u["pos"]) and not own.is_empty()
        "flank": return own.get("flank",false) and own.get("kind")!="화살"
        "crossfire":
            if own.is_empty(): return false
            for hit in sim.combat_contacts.values():
                if hit["attacker_id"]==u["id"] or hit["defender_id"]!=own["defender_id"]: continue
                if Vector2(own["to"]).direction_to(own["from"]).dot(Vector2(hit["to"]).direction_to(hit["from"]))<0.7: return true
        "low_allies":
            for ally in sim.units:
                if ally["side"]==u["side"] and ally["id"]!=u["id"] and ally["troops"]>0 and ally["morale"]<72 and Vector2(u["pos"]).distance_to(ally["pos"])<=float(rule[4]): return true
        "gate":
            for gate in sim.structures:
                if gate["hp"]>0 and gate["side"]!=u["side"] and Rect2(gate["rect"]).grow(rule[4]).has_point(u["pos"]): return true
        "ford","bridge_guard":
            if rule[0]=="ford" and (sim.march_plans.has(u["id"]) or u["motion_speed"]<=6): return false
            if rule[0]=="bridge_guard" and not hurt: return false
            return absf(u["pos"].x-sim.river_x(u["pos"].y))<float(rule[4]) and sim.near_crossing(u["pos"].y)
        "bait","pursuit":
            var foe: Dictionary=sim._nearest_visible_enemy(u)
            if foe.is_empty() or Vector2(u["pos"]).distance_to(foe["pos"])>float(rule[4]): return false
            if rule[0]=="bait": return not foe["routed"] and u["assigned_link"]<0
            return not sim.march_plans.has(u["id"]) and foe["routed"] and Vector2(u["pos"]).direction_to(foe["pos"]).dot(Vector2(u["pos"]).direction_to(u["goal"]))>0.65
    return false

static func attach(u: Dictionary,innate: String,gear: String) -> void:
    u["skill_ids"]=[innate]
    if gear!="" and gear!=innate: u["skill_ids"].append(gear)
    u.erase("signature_window")
    u.erase("skill_scan")
    u["skill_ready"]={}
    u["skill_stats"]={}
    u["field_skill"]={}

# One reproducible draw per eligible half-day, shared by scans and on-hit triggers.
# Passing time in camp does not consume an opportunity. Do not advance the battle RNG.
static func _opportunity(sim,u: Dictionary) -> bool:
    var half:=int(floor(sim.battle_time/(sim.turn_duration()*0.5)))
    if u.get("signature_window",-1)==half: return false
    u["signature_window"]=half
    var seed_value: int=sim.signature_seed if sim.signature_seed!=0 else sim.rng.seed
    var sample:=hash([seed_value,sim.scenario_title,u["name"],u["id"],half])%100
    return sample < (80 if half%2==0 else 65)

static func contact(sim,u: Dictionary,target: int,trigger: String) -> bool:
    var id: String=u["name"]
    if not Profiles.DATA.has(id) or id not in u.get("skill_ids",[]): return false
    var rule:=rule_for(id)
    if rule[0]!=trigger or u["routed"] or u["active_deputy"] or u["general_state"]=="전사" or sim.command_confused(u["side"]): return false
    if u["skill_ready"].get(id,0.0)>sim.battle_time or mission(u,sim.battle_time) not in rule[2]: return false
    var active: Dictionary=u["field_skill"]
    if active.get("end",-1.0)>sim.battle_time and active["priority"]>=rule[8]: return false
    if not _opportunity(sim,u): return false
    _activate(sim,u,id,target)
    return true

static func tick(sim,u: Dictionary) -> void:
    if u["routed"] or u["general_state"]=="전사" or u["active_deputy"] or sim.command_confused(u["side"]):
        u["field_skill"]={}
        return
    var active: Dictionary=u["field_skill"]
    var task:=mission(u,sim.battle_time)
    if not active.is_empty() and (sim.battle_time>=active["end"] or task not in active["missions"]):
        active.clear()
    if u.get("skill_scan",0.0)>sim.battle_time: return
    u["skill_scan"]=sim.battle_time+0.5
    var chosen: String=""
    var priority: int=0 if active.is_empty() else active["priority"]
    var ids: Array=u["skill_ids"]
    var gear_first: bool=ids.size()==2 and Profiles.DATA.has(ids[0]) and rule_for(ids[1])[8]>rule_for(ids[0])[8]
    for i in ids.size():
        var id: String=ids[1-i if gear_first else i]
        var rule:=rule_for(id)
        if priority>=int(rule[8]) or u["skill_ready"].get(id,0.0)>sim.battle_time or task not in rule[2]: continue
        if rule[0] in ["impact","arrow_hit"]: continue
        if ready(sim,u,rule) and (not Profiles.DATA.has(id) or _opportunity(sim,u)):
            chosen=id
            priority=rule[8]
    if chosen.is_empty(): return
    var target: int=sim.combat_contacts.get(u["id"],{}).get("defender_id",-1)
    _activate(sim,u,chosen,target)

static func _activate(sim,u: Dictionary,chosen: String,target: int) -> void:
    var signature:=Profiles.DATA.has(chosen)
    var rule:=rule_for(chosen)
    var power:=float(rule[5])*float(Profiles.DATA[chosen][4] if signature else CATALOG[chosen][3])
    var duration:=minf(rule[6],3.0) if signature else float(rule[6])
    sim.skill_started.emit(u["id"],title(chosen))
    var stat: Dictionary=u["skill_stats"].get(chosen,{"uses":0,"effect":0.0})
    stat["uses"]+=1
    u["skill_stats"][chosen]=stat
    u["skill_ready"][chosen]=sim.battle_time+(4.0 if signature else float(rule[7]))
    u["field_skill"]={"id":chosen,"title":title(chosen),"effect":rule[1],"power":power,"start":sim.battle_time,"end":sim.battle_time+duration,"missions":rule[2],"priority":rule[8],"target":target,"anchor":u["pos"],"stat":stat}
    match rule[1]:
        "break":
            var foe: Dictionary=sim.find_unit(target)
            if not foe.is_empty() and foe["troops"]>0:
                var loss:=minf(foe["cohesion"],power)
                foe["cohesion"]-=loss
                stat["effect"]+=loss
        "reform":
            var amount:=minf(100.0-u["cohesion"],power)
            u["cohesion"]+=amount
            stat["effect"]+=amount
        "rally":
            for ally in sim.units:
                if ally["side"]==u["side"] and ally["troops"]>0 and Vector2(u["pos"]).distance_to(ally["pos"])<=float(rule[4]):
                    var amount:=minf(100.0-ally["morale"],power)
                    ally["morale"]+=amount
                    stat["effect"]+=amount
    u["last_skill_report"]="%s · %s" % [title(chosen),EFFECT_TEXT[rule[1]]]
    if u["side"]==0: sim._field_notice("%s · %s 발동 · %s" % [u["name"],title(chosen),EFFECT_TEXT[rule[1]]],u["pos"],u["id"])

static func current(u: Dictionary,effects: Array) -> Dictionary:
    var skill: Dictionary=u.get("field_skill",{})
    if skill.is_empty() or skill["effect"] not in effects: return {}
    return skill

static func attack_factor(u: Dictionary,foe: Dictionary,bow: bool,damage: float) -> float:
    var skill:=current(u,["attack","volley"])
    if skill.is_empty() or (skill["effect"]=="volley" and not bow) or (skill["target"]>=0 and skill["target"]!=foe["id"]): return damage
    var extra:=damage*float(skill["power"])
    return damage+extra

static func absorb(u: Dictionary,value: float) -> float:
    var skill:=current(u,["guard","feint"])
    if skill.is_empty(): return value
    var saved:=value*float(skill["power"])
    return value-saved


static func effect_stat(id: String,value: float) -> String:
    var effect: String=rule_for(id)[1]
    match effect:
        "stagger": return "혼란으로 억제한 피해 %d" % roundi(value)
        "stand": return "패주 억제 %d초" % roundi(value)
        "pursue","stride": return "추가 이동 %d" % roundi(value)
        "break","reform": return "응집 %d" % roundi(value)
        "rally": return "사기 %d" % roundi(value)
        "guard","feint": return "피해 억제 %d" % roundi(value)
        "siege": return "시설 추가 피해 %d" % roundi(value)
    return "추가 피해 %d" % roundi(value)
