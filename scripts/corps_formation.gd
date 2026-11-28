extends RefCounted
## A general chooses how the soldiers form up around the corps' assigned point.
## Only the player's deployment control can change that point before the battle.
const Profiles = preload("res://scripts/officer_profiles.gd")

static func prepare(sim, unit: Dictionary) -> void:
    if sim.started or not sim.long_operation or unit.reserve or unit.troops <= 0: return
    var plan: Dictionary = sim.opening_letters.get(unit.id,{})
    var mission: String = plan.get("mission",unit.mission)
    var ground: String = sim.terrain_at(unit.pos)
    var practiced: bool = Profiles.formation_rating(unit) >= 75
    var shape := "횡대"
    var reason := "넓은 전열 유지"
    if ground == "교량" or mission == "철수":
        shape = "종대"
        reason = "통행 폭에 맞춰 대열 축소" if ground=="교량" else "철수로 확보"
    elif unit.type == "기병":
        var open: bool = ground in ["도로","평지"] and mission not in ["지역 사수","본진 방어","예비 대기"]
        shape = "봉시진" if practiced and open else "종대"
        reason = "열린 지면에서 돌격 준비" if shape=="봉시진" else "기동 대열 유지"
    elif unit.type == "궁병":
        shape = "안행진" if practiced else "횡대"
        reason = "사격선 분산" if practiced else "익숙한 사격 대열 유지"
    elif mission in ["지역 사수","본진 방어","예비 대기"]:
        shape = "방진"
        reason = "거점 방어 준비"
    elif mission == "공격" and practiced:
        shape = "어린진"
        reason = "공격 선두에 병력 집중"
    unit.formation = shape
    unit.formation_reason = reason
    unit.next_formation = ""
    unit.form_remaining = 0.0
    unit.erase("drill")
    unit.erase("dressed_files")

static func prepare_all(sim) -> void:
    for unit in sim.units: prepare(sim,unit)
