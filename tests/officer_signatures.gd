extends SceneTree
const Sim=preload("res://scripts/war_sim.gd")
const North=preload("res://scripts/northern_campaign.gd")
const Skills=preload("res://scripts/field_skills.gd")
var errors:=0

func check(condition: bool,label_text: String) -> void:
    if not condition: push_error(label_text);errors+=1

func _initialize() -> void:
    var north:=North.new()
    var names: Dictionary={}
    for officer in Skills.Profiles.DATA:
        var row: Array=Skills.Profiles.DATA[officer]
        check(row[0].size()==4 and row[1].size()==5,"complete officer "+officer)
        check(not names.has(row[2]) and Skills.RULES.has(row[3]),"unique supported signature "+officer)
        names[row[2]]=true
    for officer in north.officers:
        check(officer.stats==Skills.Profiles.DATA[officer.name][1],"campaign stats match "+officer.name)
    var field:=Sim.new()
    field.set_long_operation(true)
    north.state.stage=13
    north.save_path="user://signature-test.json"
    check(north.prepare(13,field),"Chang'an deploy")
    for u in field.units:
        check(u.skill_ids.front()==u.name and u.mind.profile.has("cooperation"),"field officer "+u.name)
    var restored:=field.find_unit(0)
    restored.mind.profile.erase("cooperation")
    check(Sim.GeneralMind.profile_for(restored).cooperation==Skills.Profiles.DATA[restored.name][0][2],"previous battle recordings recover missing traits")
    var old_profile: Dictionary=restored.mind.profile
    check(field.swap_generals(0,1) and field.find_unit(1).mind.profile==old_profile and field.find_unit(1).skill_ids[0]==field.find_unit(1).name,"order map transfers personality and signature together")
    direct_contacts()
    eligible_days()
    if "--playtest" in OS.get_cmdline_user_args(): field_trials()
    print("OFFICER_SIGNATURES_PASS" if errors==0 else "OFFICER_SIGNATURES_FAIL %d" % errors)
    quit(0 if errors==0 else 1)

func pair(officer: String,kind: String,with_signature: bool):
    var sim:=Sim.new()
    sim.set_long_operation(true)
    for u in sim.units: u.troops=0.0
    var a:=sim.find_unit(0)
    var b:=sim.find_unit(3)
    for u in [a,b]:
        u.troops=3800.0
        u.initial_troops=3800.0
        u.mission="공격"
        u.action="교전"
        u.formation="횡대"
        u.pos=Vector2(740,560) if u==a else Vector2(764,560)
    a.name=officer
    a.type=kind
    a.charge=100.0
    a.charge_dir=Vector2.RIGHT
    a.charge_speed=120.0
    a.facing=Vector2.RIGHT
    b.facing=Vector2.LEFT
    Skills.attach(a,officer if with_signature else "regroup","")
    sim.battle_time=1.0
    # Select an eligible window for the paired damage comparison.
    while hash([sim.rng.seed,sim.scenario_title,officer,a.id,0])%100>=80: sim.rng.seed+=1
    return sim

func direct_contacts() -> void:
    for officer in ["황충","조운"]:
        var kind: String="궁병" if officer=="황충" else "기병"
        var sim=pair(officer,kind,true)
        var control=pair(officer,kind,false)
        var a: Dictionary=sim.find_unit(0)
        var b: Dictionary=sim.find_unit(3)
        a.tactical_order="철수"
        a.tactical_until=2.0
        check(not Skills.contact(sim,a,b.id,"arrow_hit" if kind=="궁병" else "impact") and not a.has("signature_window"),"withdrawal vetoes signature before rolling")
        a.tactical_until=0.0
        sim._combat(0.1)
        control._combat(0.1)
        check(sim.combat_contacts.has(a.id) and a.skill_stats.get(officer,{}).get("uses",0)==1,officer+" real contact activation")
        if not sim.combat_contacts.has(a.id): continue
        if kind=="궁병":
            var raw: float=control.combat_contacts[a.id].damage
            check(is_equal_approx(sim.combat_contacts[a.id].damage,raw+minf(raw,20)),"one volley bounded by 2x and 20 casualties")
            sim.battle_time+=0.1
            sim._combat(0.1)
            check(sim.combat_contacts[a.id].skill_bonus==0.0 and a.skill_stats[officer].uses==1,"following volley normal")
        else:
            check(b.has("stagger") and a.charges==1,"only impacted enemy receives temporary disorder")
            sim.battle_time+=0.1
            sim._combat(0.1)
            check(sim.combat_contacts[b.id].stagger_saved>0 and a.skill_stats[officer].effect>0,"disorder reduces actual retaliation")
            sim.battle_time+=1.6
            sim._combat(0.1)
            check(sim.combat_contacts[b.id].stagger_saved==0 and a.mission=="공격","disorder expires and order survives")

func eligible_days() -> void:
    var sim=pair("황충","궁병",true)
    var a: Dictionary=sim.find_unit(0)
    Skills.attach(a,"황충","rapid")
    var uses:=0
    for day in 100:
        var before:=uses
        for hour in 30:
            sim.battle_time=day*15.0+hour*0.5
            if Skills.contact(sim,a,3,"arrow_hit"): uses+=1
        check(uses-before<=2,"daily limit including repeated shots")
    check(uses>=115 and uses<=175 and a.skill_ids==["황충","rapid"],"eligible half-day rate and two independent skill slots")
    print("ELIGIBLE_DAYS days=100 uses=%d" % uses)

func field_trials() -> void:
    for stage in [1,7,13]:
        var sim:=Sim.new()
        sim.set_long_operation(true)
        var campaign:=North.new()
        campaign.save_path="user://signature-field-test.json"
        campaign.state.stage=stage
        campaign.assign(1,14)
        check(campaign.prepare(stage,sim),"campaign playtest deployment")
        sim.rng.seed+=stage
        sim.start()
        var daily: Dictionary={}
        var total: Array[int]=[0,0]
        var last: Dictionary={}
        for i in 750:
            sim.step(0.1)
            for u in sim.units:
                var count: int=u.get("skill_stats",{}).get(u.name,{}).get("uses",0)
                if count<=last.get(u.id,0): continue
                var key: String="%d/%d" % [sim.turn,u.id]
                daily[key]=daily.get(key,0)+1
                check(daily[key]<=2,"autonomous daily limit")
                total[u.side]+=1
                last[u.id]=count
        print("FIELD_TRIAL stage=%d days=5 shu=%d wei=%d officers=%d" % [stage,total[0],total[1],last.size()])
        check(total[0]>0 and total[1]>0,"autonomous skill use by both armies")
