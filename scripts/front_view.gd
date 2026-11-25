extends RefCounted
## Tactical display model. The sector dashboard never changes battle state.
## All opponent data is subject to the player's current observation rules.

static func sector_for(p: Vector2, extent: Vector2) -> int:
    return clampi(floori(p.y/maxf(1.0,extent.y/3.0)),0,2)

static func summarize(sim,limited: bool) -> Array[Dictionary]:
    var sectors: Array[Dictionary]=[]
    for index in range(3):
        sectors.append({"name":["북부 전선","중앙 전선","남부 전선"][index],"own":0,"enemy":0,"own_count":0,"enemy_count":0,"contacts":0,"pressure":0.0,"focus":Vector2(sim.field_size.x*0.5,sim.field_size.y*(float(index)+0.5)/3.0),"sum":Vector2.ZERO,"weight":0})
    for u in sim.units:
        if float(u["troops"])<=0.0: continue
        var own: bool=int(u["side"])==0
        if not own and limited and not sim.player_can_see(u["pos"]): continue
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
            if not target.is_empty() and (not limited or int(target["side"])==0 or sim.player_can_see(target["pos"])):
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


# Only observed milestones are eligible for a player's next-highlight command.
# This samples state, never changes it or skips fixed simulation steps.
static func milestones(sim,limited: bool) -> Dictionary:
    var found: Dictionary={}
    for u in sim.units:
        if int(u["side"])!=0: continue
        var id: int=int(u["id"])
        var p: Vector2=u["pos"]
        if bool(u["routed"]):
            found["rout:"+str(id)]={"label":str(u["name"])+" 군단 패주","point":p}
        if float(u["troops"])<=0.0:
            found["loss:"+str(id)]={"label":str(u["name"])+" 군단 전멸","point":p}
        if str(u["general_state"])!="건재":
            found["officer:"+str(id)+":"+str(u["general_state"])]={"label":str(u["name"])+" 장수 "+str(u["general_state"]),"point":p}
        var target: Dictionary=sim.find_unit(int(u.get("contact_target_id",-1)))
        if float(u["troops"])>0.0 and not target.is_empty() and (not limited or sim.player_can_see(target["pos"])):
            var contact_key: String="contact:%d:%d" % [id,int(target["id"])]
            found[contact_key]={"label":"%s · %s 교전 개시" % [str(u["name"]),str(target["name"])],"point":p.lerp(target["pos"],0.5)}
    for site in sim.outposts:
        if limited and not sim.player_can_see(site["pos"]): continue
        var owner: int=int(site["owner"])
        if owner>=0:
            found["site:"+str(site["name"])+":"+str(owner)]={"label":str(site["name"])+" · "+("아군 확보" if owner==0 else "적군 확보"),"point":site["pos"]}
    for report in sim.open_situations():
        found["report:"+str(report["id"])]={"label":str(report["title"]),"point":report["pos"]}
    return found
