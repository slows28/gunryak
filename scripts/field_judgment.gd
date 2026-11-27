extends RefCounted
## A local general weighs an observed opening against danger to a nearby ally.
## These choices change movement and targeting. Damage still requires actual reach.
const GUARD_ORDERS = ["전열 엄호", "궁병 보호", "구원 지원"]
const FIXED_ORDERS = ["지역 사수", "본진 방어", "예비 대기", "철수", "측후방 기동"]
const COMMITTED = ["패주", "후퇴", "재집결", "휴식", "보급 복귀", "탄약 보충", "거리 유지",
    "측면 방어", "매복", "기지 습격", "호위", "책사 호위", "차단", "협동 우회", "방어선 사수"]

static func choose(sim, unit: Dictionary, enemy: Dictionary, action: String) -> Dictionary:
    if enemy.is_empty() or unit["mission"] in FIXED_ORDERS or action in COMMITTED:
        return {}
    if unit["routed"] or unit["rallying"] or unit["troops"]<600 or unit["morale"]<28 or unit["cohesion"]<30:
        return {}
    if sim.battle_time<unit["tactical_until"] or unit["defense_set"] or unit["reserve"]:
        return {}
    var role: String=sim.LinkedMarch.role(unit,sim.battle_time)
    if role=="측후방 기동" or (sim.scenario_id==3 and role not in GUARD_ORDERS): return {}
    var guard: bool=role in GUARD_ORDERS
    var strict: bool=unit["obedience"]=="명령 엄수"
    if strict and not guard and role!="공격": return {}
    var archer: bool=unit["type"]=="궁병"
    if archer and unit["ammo"]<12: return {}
    var p: Vector2=unit["pos"]
    var ep: Vector2=enemy["pos"]
    var distance:=p.distance_to(ep)
    if archer and distance<110: return {}
    var opening:=0.0
    if distance<=(173.0 if archer else 155.0) and not enemy["routed"] and (archer or not sim._river_separates(p,ep)):
        var advantage: float=float(unit["troops"])/maxf(1.0,enemy["troops"])
        opening=clampf((advantage-1.0)*55.0,0,38)+maxf(0,60.0-enemy["cohesion"])*0.85+maxf(0,54.0-enemy["morale"])*0.5
        if unit["personality"]=="공격": opening+=8.0
        if role=="공격": opening+=6.0
    var best_score:=45.0
    var result: Dictionary={}
    var partner: int=sim.LinkedMarch._partner(unit,sim.battle_time)
    for ally in sim.units:
        if ally["side"]!=unit["side"] or ally["id"]==unit["id"] or ally["troops"]<600 or ally["routed"]: continue
        if guard and partner>=0 and ally["id"]!=partner: continue
        var ap: Vector2=ally["pos"]
        var separation:=p.distance_to(ap)
        if separation>195 or sim._river_separates(p,ap): continue
        var threat: Dictionary=sim._observed_threat_to(unit,ally)
        if threat.is_empty(): continue
        var tp: Vector2=threat["pos"]
        var gap:=ap.distance_to(tp)
        if gap>150 or (archer and (p.distance_to(tp)>173 or p.distance_to(tp)<110)): continue
        var score:=float(150.0-gap)*0.4-separation*0.08
        if ally["type"]=="궁병": score+=28.0
        score+=maxf(0,60.0-ally["morale"])*0.65+maxf(0,55.0-ally["cohesion"])*0.5
        if sim.battle_time-float(ally["last_hit"])<2.0: score+=12.0
        if guard: score+=23.0
        if ally["id"]==partner: score+=7.0
        var prior: Dictionary=unit.get("field_choice",{})
        if prior.get("ally",-1)==ally["id"] and prior.get("target",-1)==threat["id"]: score+=6.0
        if score<=best_score: continue
        best_score=score
        var intercept:=ap+ap.direction_to(tp)*clampf(gap*0.5,0.0,65.0)
        var reason: String="%s에 %s 접근 · %s" % [ally["name"],threat["name"],"엄호 사격" if archer else "사이에 진입"]
        result={"action":"아군 보호","reason":reason,"goal":p if archer else intercept,"ally":ally["id"],"target":threat["id"]}
    if opening>best_score and (not strict or role=="공격") and not guard:
        var reason: String="%s %s · 공격 지속" % [enemy["name"],"대형 흐트러짐" if enemy["cohesion"]<55 else ("사기 저하" if enemy["morale"]<54 else "병력 우세")]
        return {"action":"공격 지속","reason":reason,"goal":p if archer else ep,"ally":-1,"target":enemy["id"]}
    return result
