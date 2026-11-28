extends RefCounted
## A mounted corps that has actually reached its objective judges local contacts
## from that station. The same observation and movement rules serve both sides.
const MISSIONS = ["공격","자유 재량","중앙 진격","남측 우회","북측 확보","측후방 기동","지정 위치 이동","지역 사수"]
const OVERRIDES = ["후퇴","패주","재집결","휴식","보급 복귀","탄약 보충","전술 철수","전술 재집결","긴급 지원","긴급 방어","포위 이탈","계획 경유","본진 수비","보급 호위","거점 차단","거점 엄호 사격"]

static func station(sim, unit: Dictionary) -> Vector2:
    if unit["type"]!="기병" or unit["mission"] not in MISSIONS or unit["reserve"] or unit["defense_set"]: return Vector2.INF
    if sim.scenario_id==3 or unit["routed"] or unit["rallying"] or sim.battle_time<unit["tactical_until"]: return Vector2.INF
    if sim.LinkedMarch.role(unit,sim.battle_time) in sim.FieldJudgment.GUARD_ORDERS: return Vector2.INF
    if unit["assigned_link"]>=0:
        var partner: Dictionary=sim.find_unit(unit["assigned_link"])
        if partner.get("type","")!="보병": return Vector2.INF
    var p: Vector2=unit["pos"]
    if unit.has("mounted_anchor"): return unit["mounted_anchor"]
    if unit["has_destination"]:
        var pin: Vector2=unit.get("rally_station",{}).get("point",unit["order_destination"])
        return pin if p.distance_to(pin)<=sim.OUTPOST_RADIUS and not sim._river_separates(p,pin) else Vector2.INF
    for post in sim.outposts+sim.terrain_posts:
        if post["owner"]==unit["side"] and p.distance_to(post["pos"])<=sim.OUTPOST_RADIUS and not sim._river_separates(p,post["pos"]):
            return post["pos"]
    return Vector2.INF

static func contacts(sim, unit: Dictionary, anchor: Vector2) -> Array[Dictionary]:
    var foes: Array[Dictionary]=[]
    if anchor==Vector2.INF: return foes
    for foe in sim.units:
        if foe["routed"] or not sim._locally_observed(unit,foe): continue
        var ep: Vector2=foe["pos"]
        if anchor.distance_to(ep)>225.0: continue
        foes.append(foe)
    return foes

static func decide(sim, unit: Dictionary, anchor: Vector2, observed: Array[Dictionary]) -> Dictionary:
    var p: Vector2=unit["pos"]
    var back := {"action":"기병 대기","goal":anchor if p.distance_to(anchor)>12.0 else p,"reason":"선점 지역 유지 · 보병 합류 대기"}
    if observed.is_empty():
        if unit.has("mounted_anchor") and p.distance_to(anchor)>18.0:
            back["reason"]="교전 상대를 놓쳐 선점 지역으로 복귀"
            return back
        return {}
    if unit["mission"] in ["지역 사수","지정 위치 이동"] or unit["cohesion"]<40.0 or unit["morale"]<40.0:
        back["reason"]="지정 지역에서 대열을 유지하며 접근하는 적을 경계"
        return back
    if sim.battle_time<unit["flank_recovery"]:
        back["reason"]="기병 재정비 · 선점 지역 복귀"
        return back
    var foes: Array[Dictionary]=[]
    var strength:=0.0
    for foe in observed:
        if sim._river_separates(anchor,foe["pos"]): continue
        foes.append(foe)
        strength+=float(foe["troops"])
    if foes.is_empty():
        back["reason"]="건너편에 적 관측 · 선점한 강변 경계"
        return back
    var judgment: float=sim._effective_stat(unit,"judgment")/100.0
    var best_score:=lerpf(57.0,26.0,judgment)
    var target: Dictionary={}
    var front: Dictionary={}
    var engaged:=false
    for ally in sim.units:
        if ally["side"]!=unit["side"] or ally["type"]!="보병" or ally["troops"]<600 or ally["routed"] or ally["rallying"]: continue
        if unit["assigned_link"]>=0 and ally["id"]!=unit["assigned_link"]: continue
        var ap: Vector2=ally["pos"]
        if anchor.distance_to(ap)>250.0 or sim._river_separates(anchor,ap): continue
        for foe in foes:
            var continuing: bool=unit.has("mounted_anchor") and unit.get("mounted_partner",-1)==ally["id"] and unit["flank_phase"]==2 and unit["flank_target"]==foe["id"] and sim.battle_time-unit["flank_contact_at"]<=6.0
            if not continuing and not sim._in_melee(ally,foe): continue
            engaged=true
            var balance: float=(float(unit["troops"])+float(ally["troops"])*0.8)/maxf(strength,1.0)
            if balance<0.72: continue
            var ep: Vector2=foe["pos"]
            var opening:=26.0+clampf((balance-1.0)*23.0,-12.0,18.0)
            opening+=maxf(0.0,80.0-foe["cohesion"])*0.55+maxf(0.0,65.0-foe["morale"])*0.35
            opening+=10.0 if (ep.direction_to(p)).dot(foe["facing"])<0.25 else 0.0
            opening += 16.0 * (sim.charge_ground_factor(sim.terrain_at(ep)) - 1.0)
            if foe["formation"]=="방진" and foe["next_formation"]=="": opening-=12.0
            if unit.has("mounted_anchor") and unit["flank_target"]==foe["id"]: opening+=8.0
            if opening<=best_score: continue
            best_score=opening
            target=foe
            front=ally
    if not target.is_empty():
        var order: Dictionary=sim._flank_order(unit,front,target,true)
        if order.is_empty():
            back["reason"]="우회로를 확보할 수 없어 보병 전선 경계"
            return back
        if order["action"]=="협동 우회" and unit["flank_target"]==target["id"]:
            var cue: String="전열 흐트러짐" if target["cohesion"]<60.0 else ("사기 저하" if target["morale"]<55.0 else "보병과 교전 중")
            order["reason"]="%s군 %s · %s군과 측면 기동" % [target["name"],cue,front["name"]]
        order["target"]=target["id"]
        order["ally"]=front["id"]
        return order
    # A genuinely isolated, visibly broken opponent does not require the foot
    # to arrive first. Healthy defenders and support outside sight grant no opening.
    if foes.size()==1 and not engaged and unit["mission"]!="측후방 기동" and unit["assigned_link"]<0:
        var foe:=foes.front() as Dictionary
        var ratio: float=float(unit["troops"])/maxf(1.0,strength)
        if ratio>1.8 and foe["cohesion"]<lerpf(32.0,51.0,judgment) and anchor.distance_to(foe["pos"])<155.0 and sim._detour_goal(unit,p,foe["pos"])==foe["pos"]:
            return {"action":"공격 지속","reason":"고립된 "+str(foe["name"])+"군의 흐트러진 대열을 발견","target":foe["id"],"goal":foe["pos"]}
    if engaged: back["reason"]="보병 교전 확인 · 돌격할 틈을 기다림"
    return back
