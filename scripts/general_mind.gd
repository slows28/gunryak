extends RefCounted
## General's psychological state, independent of rank-and-file morale.
## Deterministic character model. No random speech or hidden enemy data.
# Fictional character tuning, not historical personality assessments.
static func traits(u: Dictionary) -> Dictionary:
    var t: Dictionary={"style":str(u["personality"]),"composure":65.0,"initiative":55.0,"discipline":float(u["loyalty"])}
    match str(u["name"]):
        "왕평": t.merge({"style":"신중한 수비가","composure":88.0,"initiative":35.0},true)
        "마속": t.merge({"style":"이론 중심 전략가","composure":43.0,"initiative":69.0},true)
        "위연": t.merge({"style":"독립적인 공격가","composure":72.0,"initiative":94.0},true)
        "강유": t.merge({"style":"유연한 분석가","composure":82.0,"initiative":72.0},true)
        "관흥": t.merge({"style":"용맹한 선봉장","composure":55.0,"initiative":85.0},true)
        "장익": t.merge({"style":"책임감 있는 지원가","composure":84.0,"initiative":39.0},true)
    return t

# Bounded decision thresholds, not direct attack/defense bonuses.
static func initiative_threshold(u: Dictionary) -> float:
    var m: Dictionary=u.get("mind",{})
    var t: Dictionary=traits(u)
    return clampf(1.30+(float(m.get("stress",25.0))-25.0)*0.003-(float(m.get("confidence",65.0))-65.0)*0.003-(float(t["initiative"])-55.0)*0.0015,1.12,1.55)

static func confidence_to_refuse(u: Dictionary) -> float:
    var m: Dictionary=u.get("mind",{})
    return clampf(float(u["loyalty"])*0.65+float(m.get("trust",u["loyalty"]))*0.35,0.0,100.0)

static func initial(u: Dictionary) -> Dictionary:
    var personality: String=str(u["personality"])
    return {"confidence":72.0 if personality=="공격" else 60.0,"stress":18.0 if personality=="신중" else 12.0,"trust":float(u["loyalty"]),"mood":"전투 준비","concern":"초기 작전 확인","thought":"출전 준비 중","action":"대기","reason":"초기 배치","observed":"아직 적을 관측하지 못함","decision_at":0.0,"changed_at":0.0,"mood_at":0.0,"damage":0.0,"loss":0.0,"last_loss":0.0,"last_order":"초기 작전","order_at":0.0,"history":[],"proposal":"","proposal_at":-100.0,"profile":traits(u)}

static func record(u: Dictionary, enemy: Dictionary, action: String, reason: String, now: float) -> Dictionary:
    var m: Dictionary=u.get("mind",initial(u))
    var changed: bool=str(m["action"])!=action or str(m["reason"])!=reason
    m["action"]=action
    m["reason"]=reason
    m["decision_at"]=now
    var observed: String="현재 시야 내 적 없음"
    if not enemy.is_empty():
        var origin: Vector2=u["pos"]
        observed="%s · 거리 %d · 관측 병력 %d" % [str(enemy["name"]),roundi(origin.distance_to(enemy["pos"])),roundi(float(enemy["troops"]))]
    elif float(u.get("memory_time",-100.0))>=now-16.0:
        observed="최근 정찰 또는 마지막 관측 위치 참고"
    m["observed"]=observed
    var proposal: String=""
    if bool(u["routed"]): proposal="재집결"
    elif bool(u["surrounded"]): proposal="지원"
    elif float(u["cohesion"])<42.0 or float(u["morale"])<45.0: proposal="재집결"
    elif float(u["rations"])<24.0: proposal="지원"
    elif str(u["type"])=="궁병" and float(u["ammo"])<20.0: proposal="재집결"
    elif action in ["방어","거점 방어","방어선 사수"] and float(u["front_pressure"])>0.60: proposal="사수"
    if proposal!=str(m.get("proposal","")):
        m["proposal"]=proposal
        m["proposal_at"]=now
        if not proposal.is_empty(): append(m,now,"건의",proposal+" 요청 / "+reason)
    if changed:
        m["changed_at"]=now
        append(m,now,"판단",action+" / "+reason)
    return m

static func order(u: Dictionary, label: String, now: float, refused: bool=false) -> void:
    var m: Dictionary=u.get("mind",initial(u))
    m["last_order"]=label
    m["order_at"]=now
    m["trust"]=clampf(float(m["trust"])-(5.0 if refused else 0.0),0.0,100.0)
    m["stress"]=clampf(float(m["stress"])+(10.0 if refused else 2.0),0.0,100.0)
    append(m,now,"명령 반응",label)
    u["mind"]=m

static func update(u: Dictionary,now: float) -> Dictionary:
    var m: Dictionary=u.get("mind",initial(u))
    var loss: float=float(u["casualties_taken"])+float(u.get("deserted",0.0))
    var damage: float=float(u["damage_dealt"])
    var initial_troops: float=maxf(1.0,float(u["initial_troops"]))
    var loss_delta: float=maxf(0.0,loss-float(m["loss"]))/initial_troops
    var damage_delta: float=maxf(0.0,damage-float(m["damage"]))/initial_troops
    m["loss"]=loss
    m["damage"]=damage
    m["last_loss"]=loss_delta
    var strength: float=clampf(float(u["troops"])/initial_troops,0.0,1.0)
    var morale: float=float(u["morale"])
    var fatigue: float=float(u["fatigue"])
    var cohesion: float=float(u["cohesion"])
    var surrounded: bool=bool(u["surrounded"])
    var routed: bool=bool(u["routed"])
    var personality: String=str(u["personality"])
    var target_stress: float=12.0+(100.0-morale)*0.30+(100.0-cohesion)*0.19+fatigue*0.19+loss_delta*240.0+(25.0 if surrounded else 0.0)+(28.0 if routed else 0.0)
    var profile: Dictionary=traits(u)
    target_stress+=(65.0-float(profile["composure"]))*0.22
    if personality=="신중": target_stress+=7.0
    if str(u["general_state"])!="건재": target_stress+=12.0
    var target_conf: float=24.0+strength*31.0+morale*0.26+damage_delta*160.0-loss_delta*240.0-(20.0 if surrounded else 0.0)-(25.0 if routed else 0.0)+(10.0 if personality=="공격" else 0.0)
    m["stress"]=lerpf(float(m["stress"]),clampf(target_stress,0.0,100.0),0.24)
    m["confidence"]=lerpf(float(m["confidence"]),clampf(target_conf,0.0,100.0),0.24)
    var mood: String="침착"
    var concern: String="지정 작전과 전열 유지"
    if float(u["troops"])<=0.0:
        mood="지휘 불능"
        concern="군단 전멸"
    elif routed:
        mood="공황"
        concern="병력 수습 및 생존"
    elif surrounded:
        mood="위기감"
        concern="포위 및 퇴로 확보"
    elif float(u["rations"])<25.0:
        mood="불안"
        concern="군량 부족"
    elif str(u["type"])=="궁병" and float(u["ammo"])<20.0:
        mood="초조"
        concern="화살 부족"
    elif float(m["stress"])>=65.0:
        mood="압박"
        concern="전열 붕괴 위험"
    elif float(u["fatigue"])>70.0:
        mood="지침"
        concern="전투 피로 누적"
    elif loss_delta>0.025:
        mood="동요"
        concern="최근 아군 손실 증가"
    elif str(u["action"]) in ["협동 대기","예비 대기"]:
        mood="긴장"
        concern="기회와 연계 부대 대기"
    elif float(m["confidence"])>=76.0 and float(m["stress"])<45.0:
        mood="자신감"
        concern="현재 전력 유지 및 전과 확대"
    elif float(m["stress"])>=40.0:
        mood="긴장"
        concern="전열 및 적의 접근 주시"
    if str(m["mood"])!=mood:
        m["mood"]=mood
        m["mood_at"]=now
        append(m,now,"심리",mood+" / "+concern)
    m["concern"]=concern
    m["thought"]=str(m["reason"])
    return m

static func acknowledge(u: Dictionary,now: float) -> void:
    var m: Dictionary=u.get("mind",initial(u))
    m["trust"]=clampf(float(m["trust"])+2.0,0.0,100.0)
    append(m,now,"명령 반응","보고 확인 / 현장 재량 인정")
    u["mind"]=m

static func append(m: Dictionary,now: float,category: String,message: String) -> void:
    var h: Array=m["history"]
    h.append({"time":now,"category":category,"text":message})
    if h.size()>24: h.pop_front()
