extends SceneTree
## A mounted patrol crosses the map, observes a working depot and begins a raid.
## In the withdrawal case the guard reinforces only after dismantling has begun.
const Sim = preload("res://scripts/war_sim.gd")
const SEED := 137

func _initialize() -> void:
    var continued := run_patrol(false)
    var withdrew := run_patrol(true)
    quit(0 if continued and withdrew else 1)

func run_patrol(withdraw: bool) -> bool:
    var sim = Sim.new()
    sim.set_long_operation(true)
    sim.set_scenario(Sim.TRAINING_SCENARIO)
    sim.rng.seed = SEED
    sim.enemy_strategy_enabled = false
    for unit in sim.units:
        if unit.id not in [2,3]: unit.troops = 0.0
    sim.reserve_limit.assign([0,0])

    var rider: Dictionary = sim.find_unit(2)
    var guard: Dictionary = sim.find_unit(3)
    guard.pos = Vector2(2460,330)
    guard.goal = guard.pos
    guard.action = "방어"
    guard.ai_cooldown = 999
    var depot: Dictionary = sim.bases[1]
    depot.pos = Vector2(2000,855)
    var response := "철수" if withdraw else "강행"
    if not sim.place_unit(2,Vector2(790,855)) or not sim.issue_map_order(2,sim.StandingOrders.RAID,Vector2(805,855),-1,response):
        push_error("Could not prepare the patrol replay.")
        return false
    sim.start()

    var observed := false
    var reinforced := false
    var returned := false
    var walked := 0.0
    for tick in 1600:
        var previous: Vector2 = rider.pos
        sim.step(0.1)
        walked += previous.distance_to(rider.pos)
        if not observed and rider.has("search_position"):
            observed = true
            print("OBSERVED ",response," day=",sim.turn," range=",snappedf(Vector2(rider.pos).distance_to(depot.pos),0.1))
        if withdraw and observed and not reinforced and depot.raid_work > 0.0:
            guard.pos = depot.pos + Vector2(40,-20)
            guard.goal = guard.pos
            reinforced = true
        returned = reinforced and rider.get("raid_withdrawing",false) and Vector2(rider.pos).distance_to(sim.headquarters[0].pos) < 80.0
        if returned or not depot.alive or sim.finished: break
    var outcome: bool = depot.alive and returned if withdraw else not depot.alive
    var passed := observed and walked > 950.0 and outcome
    print("RAID_RUN ",response," travel=",roundi(walked)," day=",sim.turn," action=",rider.action," base=",depot.state," returned=",returned," passed=",passed)
    return passed
