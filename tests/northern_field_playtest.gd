extends SceneTree
## Run a real battle at normal difficulty. Optional relief orders are carried by live couriers.
const North=preload("res://scripts/northern_campaign.gd")
const Sim=preload("res://scripts/war_sim.gd")

func _initialize() -> void:
    var args:=OS.get_cmdline_user_args()
    var n:=int(args[0]) if not args.is_empty() else 1
    var options:=args.slice(1)
    var plan: String="brief"
    var seed_text: String="game"
    var seen_options: Dictionary={}
    for token in options:
        var key: String="seed" if token.begins_with("seed=") else token
        var valid: bool=not seen_options.has(key)
        if token in ["assault","rush","split","wings","paired","relay","vanguard","recapture"]:
            valid=valid and plan=="brief"
            plan=token
        elif token.begins_with("seed="):
            seed_text=token.trim_prefix("seed=")
            valid=valid and (seed_text=="game" or seed_text.is_valid_int())
        elif token not in ["equipped","relief","receipts","watch","garrison"]:
            valid=false
        if not valid:
            push_error("Unknown, duplicate or incompatible option: "+token)
            quit(2)
            return
        seen_options[key]=true
    var equipped: bool=options.has("equipped")
    var relief: bool=options.has("relief")
    var receipts: bool=options.has("receipts")
    var watch: bool=options.has("watch")
    var garrison: bool=options.has("garrison")
    if (plan=="relay" and n!=11) or (plan=="recapture" and n!=3) or n<1 or n>North.Field.CHAPTERS.size() or ((watch or garrison) and n!=11) or (watch and garrison) or (relief and n not in [7,13]) or (receipts and n not in [10,11]):
        push_error("Use -- CHAPTER [assault | rush | split | wings | paired | relay (11) | vanguard | recapture (3)] [seed=game|INTEGER] [equipped] [relief (7/13) | receipts (10/11)] [watch | garrison (11)]")
        quit(2)
        return
    var campaign:=North.new()
    campaign.save_path="user://north-playtest-%d-%s-%s.json" % [n,"-".join(options),equipped]
    # A legal inventory obtained by choosing the first reward at each preceding chapter.
    for prior in range(1,n):
        campaign.state.reward=prior
        if not campaign.claim(campaign.choices()[0]):
            quit(1)
            return
    campaign.equip(0,"pace")
    campaign.equip(2,"shield")
    campaign.equip(3,"regroup")
    if equipped:
        var kit: Dictionary={1:"inspire",2:"breach",3:"iron",4:"ford",5:"siege",9:"strike",10:"tiger",11:"ambush",12:"charge",13:"cascade",6:"link"}
        for officer: int in kit:
            if kit[officer] in campaign.state["items"] and not campaign.equip(officer,kit[officer]):
                push_error("Illegal item assignment")
                quit(1)
                return
    var sim:=Sim.new()
    sim.set_long_operation(true)
    sim.tactical_enabled=true
    if not campaign.prepare(n,sim):
        quit(1)
        return
    var start_blue:=sim.total_troops(0)
    var start_red:=sim.total_troops(1)
    if seed_text!="game": sim.rng.seed=int(seed_text)
    if plan!="brief":
        var objective: Vector2=sim.outposts[0].pos
        var gate: bool=sim.chapter.mode in ["siege","capital"]
        var ids:=sim.command_ids(0)
        for i in ids.size():
            var id:=ids[i]
            var unit:=sim.find_unit(id)
            var target:=objective
            var intent: String="공격"
            if plan=="split" and i%2==1: target=sim.outposts[1].pos
            if plan=="assault" and gate and unit.type=="보병":
                var wall: Rect2=sim.structures[0].rect
                target=Vector2(wall.position.x-13,wall.get_center().y)
            elif unit.type=="궁병":
                target+=Vector2(-90,0)
                intent="지역 사수"
            elif plan=="wings" and unit.type=="기병":
                target=objective+Vector2(60,220)
                intent="측후방 기동"
            if plan=="recapture":
                intent="지역 사수"
                target=objective+Vector2(-195-28*(i%3),-108+54*(i%5))
            var partner: int=-1
            if plan in ["paired","relay"] and unit.type=="궁병":
                var nearest:=INF
                for friend_id in ids:
                    var ally:=sim.find_unit(friend_id)
                    if ally.type!="보병": continue
                    var gap: float=Vector2(ally.pos).distance_squared_to(unit.pos)
                    if gap<nearest:
                        partner=friend_id
                        nearest=gap
            if plan=="vanguard" and i==1:
                partner=ids[0]
                intent="전열 엄호"
                target=objective
            if not sim.issue_map_order(id,intent,target,partner):
                push_error("Illegal opening order for "+unit.name)
                quit(1)
                return
    var guard_id: int=-1
    if garrison:
        guard_id=sim.home_relief_candidate()
        if guard_id<0 or not sim.issue_map_order(guard_id,"본진 방어",sim.headquarters[0]["pos"]):
            push_error("Opening assignment failed")
            quit(1)
            return
        print("GARRISON ",sim.find_unit(guard_id).name," day 1")
    sim.start()
    var dispatched: Dictionary={}
    var wing_orders: Dictionary={}
    var receipt_orders: Dictionary={}
    while not sim.finished and sim.step_count<3800:
        sim.step(0.1)
        if sim.turn<sim.COURIER_TURN or sim.step_count%20!=0 or sim.finished: continue
        if watch and guard_id<0 and (sim.home_approach_seen() or sim.headquarters[0].occupation>0):
            var candidate:=sim.home_relief_candidate()
            if candidate>=0 and sim.issue_map_order(candidate,"본진 방어",sim.headquarters[0]["pos"]):
                guard_id=candidate
                print("WATCH_ORDER ",sim.find_unit(guard_id).name," at ",sim.operation_elapsed())
        if plan=="relay":
            var confirmed:=0.0
            for letter in sim.chapter.get("receipts",{}).values(): confirmed+=float(letter.get("joint_credit",0.0))
            if confirmed>=120.0:
                for id in sim.command_ids(0):
                    if dispatched.has(id): continue
                    var dest: Vector2=sim.outposts[0].pos
                    if sim.find_unit(id).type=="궁병": dest+=Vector2(-32,-18)
                    if sim.issue_map_order(id,"지역 사수",dest): dispatched[id]=true
        if plan=="recapture" and sim.player_can_see(sim.outposts[0].pos) and sim.outposts[0].owner==1:
            for id in sim.command_ids(0):
                if dispatched.has(id): continue
                if sim.issue_map_order(id,"공격",sim.outposts[0].pos): dispatched[id]=true
        if plan=="wings":
            for id in sim.command_ids(0):
                var wing:=sim.find_unit(id)
                if wing_orders.has(id) or wing.type!="기병" or wing.routed: continue
                if wing.pos.distance_to(sim.outposts[0].pos+Vector2(60,220))>160: continue
                if sim.issue_map_order(id,"공격",sim.outposts[0].pos): wing_orders[id]=true
        if receipts:
            for letter in sim.chapter.get("receipts",{}).values():
                var id: int=letter.unit_id
                if id==guard_id or receipt_orders.has(id): continue
                if not (letter.get("east_bank",false) or letter.get("joint_credit",0.0)>0.0): continue
                var mission: String="지역 사수" if n==10 else "공격"
                if sim.issue_map_order(id,mission,sim.outposts[0].pos):
                    receipt_orders[id]=[letter.sender,letter.kind,sim.turn,mission]
        if not relief: continue
        if sim.chapter.mode not in ["siege","capital"] or sim.structures[0].hp>0: continue
        var inside: Vector2=sim.outposts[0].pos
        for id in sim.command_ids(0):
            if dispatched.has(id): continue
            var u:=sim.find_unit(id)
            if u.troops<600 or u.routed: continue
            var dest:=inside
            if u.type=="궁병": dest+=Vector2(-28,-18)
            if sim.issue_map_order(id,"지역 사수",dest): dispatched[id]=true
    if guard_id>=0: print("GUARD_RESULT ",sim.find_unit(guard_id).name," ",sim.map_dispatches.get(guard_id,{})," ",sim.headquarters_state(0))
    if receipts: print("COUNCIL_ORDERS ",JSON.stringify(receipt_orders.values()))
    var uses: Dictionary={}
    var sites: Array=[]
    for u in sim.units:
        if u.side!=0: continue
        for key in u.get("skill_stats",{}):
            uses[key]=uses.get(key,0)+int(u.skill_stats[key].uses)
    for site in sim.outposts: sites.append({"name":site.name,"owner":site.owner,"held":roundi(site.hold*sim.operation_scale())})
    print("CHAPTER_RUN ",JSON.stringify({"chapter":n,"plan":plan,"seed":seed_text,"details":sim.result_detail,"wing_orders":wing_orders.size(),"relay_orders":dispatched.size() if plan=="relay" else 0,"post_breach_orders":dispatched.size() if relief else 0,"recapture_orders":dispatched.size() if plan=="recapture" else 0,"gear":"earned" if equipped else "starters","title":sim.scenario_title,"elapsed":roundi(sim.operation_elapsed()),"blue_start":start_blue,"red_start":start_red,"blue":sim.total_troops(0),"red":sim.total_troops(1),"winner":sim.winning_side,"why":sim.result,"uses":uses,"sites":sites,"gate_hp":roundi(sim.structures[0].hp) if sim.chapter.mode in ["siege","capital"] else -1}))
    quit(0 if sim.finished and sim.validate_state().is_empty() else 1)
