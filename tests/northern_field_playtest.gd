extends SceneTree
## Run a real battle at normal difficulty. Optional relief orders are carried by live couriers.
const North=preload("res://scripts/northern_campaign.gd")
const Sim=preload("res://scripts/war_sim.gd")

func _initialize() -> void:
    var args:=OS.get_cmdline_user_args()
    var n:=int(args[0]) if not args.is_empty() else 1
    var options:=args.slice(1)
    var assault: bool="assault" in options
    var equipped: bool="equipped" in options
    var relief: bool="relief" in options
    var receipts: bool="receipts" in options
    if n<1 or n>North.Field.CHAPTERS.size() or options.size()!=int(assault)+int(equipped)+int(relief)+int(receipts) or (relief and n not in [7,13]) or (receipts and n not in [10,11]):
        push_error("Use -- CHAPTER [assault] [equipped] [relief (7/13) | receipts (10/11)]")
        quit(2)
        return
    var campaign:=North.new()
    campaign.save_path="user://north-playtest-%d-%s-%s.json" % [n,assault,equipped]
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
    if assault:
        var objective: Vector2=sim.outposts[0].pos
        var gate: bool=sim.chapter.mode in ["siege","capital"]
        for id in sim.command_ids(0):
            var unit:=sim.find_unit(id)
            var target:=objective
            var intent: String="공격"
            if gate and unit.type=="보병":
                var wall: Rect2=sim.structures[0].rect
                target=Vector2(wall.position.x-13,wall.get_center().y)
            elif unit.type=="궁병":
                target=objective+Vector2(-90,0)
                intent="지역 사수"
            if not sim.issue_map_order(id,intent,target):
                push_error("Illegal opening order for "+unit.name)
                quit(1)
                return
    sim.start()
    var dispatched: Dictionary={}
    var receipt_orders: Dictionary={}
    while not sim.finished and sim.step_count<3800:
        sim.step(0.1)
        if sim.turn<sim.COURIER_TURN or sim.step_count%20!=0 or sim.finished: continue
        if receipts:
            for letter in sim.chapter.get("receipts",{}).values():
                var id: int=letter.unit_id
                if receipt_orders.has(id): continue
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
    if receipts: print("COUNCIL_ORDERS ",JSON.stringify(receipt_orders.values()))
    var uses: Dictionary={}
    var sites: Array=[]
    for u in sim.units:
        if u.side!=0: continue
        for key in u.get("skill_stats",{}):
            uses[key]=uses.get(key,0)+int(u.skill_stats[key].uses)
    for site in sim.outposts: sites.append({"name":site.name,"owner":site.owner,"held":roundi(site.hold*sim.operation_scale())})
    print("CHAPTER_RUN ",JSON.stringify({"chapter":n,"plan":"assault" if assault else "brief","post_breach_orders":dispatched.size(),"gear":"earned" if equipped else "starters","title":sim.scenario_title,"elapsed":roundi(sim.operation_elapsed()),"blue_start":start_blue,"red_start":start_red,"blue":sim.total_troops(0),"red":sim.total_troops(1),"winner":sim.winning_side,"why":sim.result,"uses":uses,"sites":sites,"gate_hp":roundi(sim.structures[0].hp) if sim.chapter.mode in ["siege","capital"] else -1}))
    quit(0 if sim.finished and sim.validate_state().is_empty() else 1)
