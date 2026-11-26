extends RefCounted
## Tactical display model. The sector dashboard never changes battle state.
## All opponent data is subject to the player's current observation rules.

enum BowPhase { IDLE, LIFT, DRAW, RELEASE, LOWER }

const VOLLEY_RELEASE: float=0.24
const VOLLEY_RECOVERY: float=0.46

static func bow_phase(age: float) -> BowPhase:
    if age<0.0 or age>=VOLLEY_RECOVERY: return BowPhase.IDLE
    if age<0.08: return BowPhase.LIFT
    if age<VOLLEY_RELEASE: return BowPhase.DRAW
    if age<VOLLEY_RELEASE+0.075: return BowPhase.RELEASE
    return BowPhase.LOWER

static func volley_lane_delay(lane: int) -> float:
    return float(lane)*0.038

static func arrow_age(volley_age: float, lane: int) -> float:
    return volley_age-volley_lane_delay(lane)-VOLLEY_RELEASE

static func arrow_position(origin: Vector2, target: Vector2, progress: float, rise: float) -> Vector2:
    return origin.lerp(target,progress)+Vector2(0,-4.0*rise*progress*(1.0-progress))

static func sector_for(p: Vector2, extent: Vector2) -> int:
    return clampi(floori(p.y/maxf(1.0,extent.y/3.0)),0,2)

static func observes_unit(sim, unit: Dictionary, limited: bool) -> bool:
    if int(unit["side"]) == 0 or not limited or sim.finished: return true
    var concealed: bool=sim.terrain_at(unit["pos"])=="숲" or float(unit.get("ambush_ready",0.0))>=3.0
    return sim.player_can_see(unit["pos"],concealed)

static func summarize(sim,limited: bool) -> Array[Dictionary]:
    var sectors: Array[Dictionary]=[]
    for index in range(3):
        sectors.append({"name":["북부 전선","중앙 전선","남부 전선"][index],"own":0,"enemy":0,"own_count":0,"enemy_count":0,"contacts":0,"pressure":0.0,"focus":Vector2(sim.field_size.x*0.5,sim.field_size.y*(float(index)+0.5)/3.0),"sum":Vector2.ZERO,"weight":0})
    for u in sim.units:
        if float(u["troops"])<=0.0: continue
        var own: bool=int(u["side"])==0
        if not observes_unit(sim,u,limited): continue
        var sector: Dictionary=sectors[sector_for(u["pos"],sim.field_size)]
        var people: int=roundi(float(u["troops"]))
        if own:
            sector["own"]+=people
            sector["own_count"]+=1
            sector["pressure"]=maxf(float(sector["pressure"]),float(u.get("front_pressure",0.0)))
        else:
            sector["enemy"]+=people
            sector["enemy_count"]+=1
        if int(u.get("contact_target_id",-1))>=0:
            var target: Dictionary=sim.find_unit(int(u["contact_target_id"]))
            if not target.is_empty() and observes_unit(sim,target,limited):
                sector["contacts"]+=1
                sector["sum"]+=(u["pos"] as Vector2).lerp(target["pos"],0.5)*3.0
                sector["weight"]+=3
        if own:
            sector["sum"]+=u["pos"]
            sector["weight"]+=1
    for sector in sectors:
        if int(sector["weight"])>0: sector["focus"]=(sector["sum"] as Vector2)/float(sector["weight"])
        if int(sector["contacts"])>0:
            sector["state"]="아군 압박" if float(sector["pressure"])>=0.35 else "교전 중"
        elif int(sector["own_count"])>0 and int(sector["enemy_count"])>0:
            sector["state"]="대치"
        elif int(sector["own_count"])>0:
            sector["state"]="아군 기동"
        elif int(sector["enemy_count"])>0:
            sector["state"]="적군 기동"
        else:
            sector["state"]="관측 없음" if limited else "부대 없음"
    return sectors

# Find the nearest actual contact anchor only among the target of this attack.
# No visual attack on an unobserved enemy, no extra damage.
static func local_target(point: Vector2, anchors: Array[Vector2], reach: float) -> Vector2:
    var best: float=reach*reach
    var result:=Vector2.INF
    for q in anchors:
        var d: float=point.distance_squared_to(q)
        if d<=best:
            best=d
            result=q
    return result

static func advance_toward_contact(point: Vector2,target: Vector2,phase: float,kind: String) -> Vector2:
    if target==Vector2.INF or kind=="궁병": return point
    var gap: float=point.distance_to(target)
    if gap<0.1: return point
    # Move just the representative foot position within the existing melee frontage.
    var travel: float=clampf(gap-9.0,0.0,9.0)*clampf(phase,0.0,1.0)
    return point.move_toward(target,travel)


# Fold the engaged files into a ragged contact line. Ranks behind the
# contact feed forward, the leading rank buckles, and the shoulders spread.
static func contact_displacement(local: Vector2, front: Dictionary) -> Vector2:
    var axis: Vector2=front["axis"]
    var tangent: Vector2=axis.orthogonal()
    var relative: Vector2=local-front["edge"]
    var depth: float=relative.dot(axis)
    var across: float=relative.dot(tangent)
    var width: float=front["width"]
    var weight: float=smoothstep(-37.0,-6.0,depth)*(1.0-smoothstep(width*0.36,width,absf(across)))
    if weight<=0.0: return Vector2.ZERO
    var fold: float=sin(across*0.15+float(front["phase"]))
    var indent: float=3.5+float(front["pressure"])*13.0
    var axial: float=clampf(-depth*0.70+float(front["reach"])-indent+fold*6.0,-21.0,20.0)
    var spill: float=(clampf(across/12.0,-1.0,1.0)*7.5+fold*3.5)
    return (axis*axial+tangent*spill)*weight*float(front["strength"])


# Only observed milestones are eligible for a player's next-highlight command.
# This samples state, never changes it or skips fixed simulation steps.
static func milestones(sim,limited: bool) -> Dictionary:
    var found: Dictionary={}
    for u in sim.units:
        if int(u["side"])!=0: continue
        var id: int=int(u["id"])
        var p: Vector2=u["pos"]
        if bool(u["routed"]):
            found["rout:"+str(id)]={"label":str(u["name"])+" 군단 패주","point":p,"unit_id":id}
        if float(u["troops"])<=0.0:
            found["loss:"+str(id)]={"label":str(u["name"])+" 군단 전멸","point":p,"unit_id":id}
        if str(u["general_state"])!="건재":
            found["officer:"+str(id)+":"+str(u["general_state"])]={"label":str(u["name"])+" 장수 "+str(u["general_state"]),"point":p,"unit_id":id}
        var target: Dictionary=sim.find_unit(int(u.get("contact_target_id",-1)))
        if float(u["troops"])>0.0 and not target.is_empty() and observes_unit(sim,target,limited):
            var contact_key: String="contact:%d:%d" % [id,int(target["id"])]
            found[contact_key]={"label":"%s · %s 교전 개시" % [str(u["name"]),str(target["name"])],"point":p.lerp(target["pos"],0.5),"unit_id":id}
    for site in sim.outposts:
        if limited and not sim.player_can_see(site["pos"]): continue
        var owner: int=int(site["owner"])
        if owner>=0:
            found["site:"+str(site["name"])+":"+str(owner)]={"label":str(site["name"])+" · "+("아군 확보" if owner==0 else "적군 확보"),"point":site["pos"]}
    for report in sim.open_situations():
        found["report:"+str(report["id"])]={"label":str(report["title"]),"point":report["pos"],"unit_id":int(report["unit_id"])}
    return found

# Mission locations are public. Live enemy control and gate condition require observation.
static func objective_targets(sim, limited: bool) -> Array[Dictionary]:
    var rows: Array[Dictionary]=[]
    if sim.scenario_id==2:
        var home: Dictionary=sim.bases[0]
        var state: String=str(home["state"])
        if state=="설치": state="구축 %d초" % ceili(home["build_timer"]*sim.operation_scale())
        if home["raid_rate"]>0: state="파괴까지 %d초" % sim.raid_seconds_left(home)
        rows.append({"name":"첫 보급기지","pos":home["pos"],"state":state,"alert":home["raid_rate"]>0 or not home["alive"]})
        return rows
    if sim.scenario_id==3:
        var convoy: Dictionary=sim.convoy
        if convoy.is_empty(): return rows
        var cargo: Dictionary=sim.convoy_status()
        rows.append({"name":"군량 수레","pos":convoy["pos"],"state":"%s · 내구도 %d%%" % [cargo["state"],ceili(convoy["hp"])],"alert":cargo["state"] in ["파괴","교전 정체","호위 대기"]})
        rows.append({"name":"도착점","pos":convoy["goal"],"state":"이동 %d%%" % floori(cargo["progress"]*100.0),"alert":false})
        return rows
    if sim.scenario_id in [4,sim.TRAINING_SCENARIO]:
        var gate: Dictionary=sim.structures[0]
        var center: Vector2=(gate["rect"] as Rect2).get_center()
        var state: String="미확인"
        if not limited or sim.finished or sim.player_can_see(center):
            state="돌파" if gate["hp"]<=0 else "내구도 %d%%" % ceili(100.0*gate["hp"]/gate["max_hp"])
        rows.append({"name":gate["name"],"pos":center,"state":state,"alert":false})
    var sites: int=sim.outposts.size() if sim.scenario_id==0 else 1
    for index in range(sites):
        var site: Dictionary=sim.outposts[index]
        var state: String="미확인"
        var alert:=false
        if not limited or sim.finished or sim.player_can_see(site["pos"]):
            state="미점령"
            if site.get("contested",false):
                state="경합 · 유지 중단"
                alert=true
            elif site["challenger"]>=0:
                state="%s 점령 %d%%" % ["아군" if site["challenger"]==0 else "적군",floori(100.0*site["progress"]/sim.capture_duration())]
                alert=site["challenger"]==1
            elif site["owner"]>=0:
                var required:=roundi(sim.objective_hold_duration()*sim.operation_scale())
                var held:=mini(required,floori(site["hold"]*sim.operation_scale()+0.00001))
                state="%s %d/%d초" % ["아군" if site["owner"]==0 else "적군",held,required]
                alert=site["owner"]==1
        rows.append({"name":site["name"],"pos":site["pos"],"state":state,"alert":alert})
    return rows
