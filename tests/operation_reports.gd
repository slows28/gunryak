extends SceneTree
const Sim=preload("res://scripts/war_sim.gd")
const Field=preload("res://scripts/northern_field.gd")
const Front=preload("res://scripts/front_view.gd")
var errors:=0
func check(value: bool,label: String):
    if not value: push_error(label);errors+=1

func _initialize():
    var sim:=Sim.new()
    sim.set_long_operation(true)
    sim.start()
    sim.chapter={"mode":"river","metrics":{}}
    var u:=sim.find_unit(0)
    var west:=Vector2(sim.river_x(850)-90,850)
    u.pos=west
    u.bridge_y=850
    u.bridge_bank=1
    Field.report_progress(sim)
    check(sim.incoming_reports.size()==1,"a courier leaves the approach")
    var letter: Dictionary=sim.incoming_reports[0]
    check(not sim.chapter.has("desk_summary") and letter.kind=="교량 접근" and letter.status=="대기" and not Front.milestones(sim,true).has("report:"+str(letter.id)),"no early journal entry")
    var written: String=letter.objective_account
    u.pos=west+Vector2(210,0)
    u.bridge_crossings=1
    for i in 800:
        sim.battle_time+=0.1
        sim._move_reporting_messengers(0.1)
        if sim.incoming_reports.is_empty(): break
    check("0/2" in sim.chapter.get("desk_summary","") and letter.status=="작전 보고 수신" and letter.pos==west and letter.objective_account==written,"received text is the departure snapshot")
    check(Front.milestones(sim,true).has("report:"+str(letter.id)) and not sim.reply_to_report(letter.id,true),"informational journal entry without a tactical reply")
    sim.battle_time+=8
    Field.report_progress(sim)
    check(sim.incoming_reports.size()==1 and sim.incoming_reports[0].kind=="도하 완료","east-bank contribution")
    Field.report_progress(sim)
    check(sim.incoming_reports.size()==1,"no duplicate courier")
    sim.incoming_reports.clear()
    sim.chapter={"mode":"link","metrics":{}}
    var ally:=sim.find_unit(1)
    u.assigned_link=ally.id
    u.pos=west
    ally.pos=west+Vector2(400,0)
    Field.report_progress(sim)
    check(sim.incoming_reports.back().kind=="합류 대기","separated assigned corps")
    sim.incoming_reports.clear()
    sim.battle_time+=8
    u.joint_partner=ally.id
    u.joint_time=sim.battle_time
    u.linked_hits=3000.0
    u.joint_credit=42.2
    Field.report_progress(sim)
    check(sim.incoming_reports.back().kind=="협공 성립" and ally.name in sim.incoming_reports.back().objective_account and "42명" in sim.incoming_reports.back().objective_account and is_equal_approx(sim.incoming_reports.back().joint_credit,42.2),"credit belongs to the real combat partner")
    sim.incoming_reports.clear()
    sim.battle_time+=8
    Field.report_progress(sim)
    check(sim.incoming_reports.back().kind=="협공 중단","commander reports sustained loss of contact")
    # Controlled combat uses the actual target and slot contact calculation.
    var battle:=Sim.new()
    battle.set_six_armies(true)
    var front:=battle.find_unit(0)
    var bow:=battle.find_unit(1)
    var foe:=battle.find_unit(3)
    for corps in battle.units: corps.pos=Vector2(1900,400)
    front.pos=Vector2(635,880)
    bow.pos=Vector2(520,880)
    foe.pos=Vector2(650,880)
    front.type="보병"
    bow.type="궁병"
    front.facing=Vector2.RIGHT
    bow.facing=Vector2.RIGHT
    foe.facing=Vector2.LEFT
    battle.chapter={"mode":"link","metrics":{}}
    battle._combat(0.1)
    check(front.linked_hits>0 and not front.has("joint_credit"),"incidental support deals damage but gives no mission credit")
    bow.assigned_link=front.id
    battle._combat(0.1)
    check(front.get("joint_credit",0.0)>0 and front.joint_partner==bow.id,"the actual cooperating formation earns objective credit")
    var earned: float=front.get("joint_credit",0)
    bow.pos=Vector2(1900,400)
    battle._combat(0.1)
    check(is_equal_approx(earned,front.get("joint_credit",0.0)),"a selected but absent partner earns no credit")
    print("GUNRYAK_OPERATION_REPORTS_PASS" if errors==0 else "GUNRYAK_OPERATION_REPORTS_FAIL")
    quit(0 if errors==0 else 1)
