extends RefCounted
## Follow a moving formation slot with a turn and a stride on the ground.
## Keys use the same file/layer identity as the representative soldier renderer.
static func advance(sim, unit: Dictionary, slots: Array[Vector2], core: int, old: Dictionary, dt: float) -> Dictionary:
    var start := PackedVector2Array()
    var end := PackedVector2Array()
    var heading := PackedFloat32Array()
    var from_heading := PackedFloat32Array()
    var walked := PackedFloat32Array()
    var center: Vector2=unit["pos"]
    var facing: float=Vector2(unit["facing"]).angle()
    var previous: PackedVector2Array=old.get("end",PackedVector2Array())
    var old_core: int=old.get("core",0)
    var continuous: bool=old.get("tick",-2)==sim.step_count-1
    var advance_distance:=center.distance_to(old.get("center",center))
    var near_water: bool=absf(center.x-sim.river_x(center.y))<160.0
    for i in slots.size():
        @warning_ignore("integer_division")
        var layer: int=i/core
        var file: int=i%core
        var idx: int=layer*old_core+file
        var goal:=slots[i]
        var p:=goal
        var next:=goal
        var before:=facing
        var angle:=facing
        var distance:=0.0
        if continuous and file<old_core and idx<previous.size():
            p=previous[idx]
            before=old["heading"][idx]
            var gap:=p.distance_to(goal)
            var bearing:=p.angle_to_point(goal) if gap>1.8 else facing
            var cadence:=float((file*5+layer*3+int(unit["id"]))%11)/10.0
            angle=rotate_toward(before,bearing,lerpf(3.2,4.4,cadence)*dt)
            next=p
            if gap>0.75:
                # A rider facing across the route reins in. An outside file can
                # lengthen its stride, without snapping to a rotated slot.
                var aligned:=maxf(0.0,cos(angle_difference(angle,bearing)))
                var catch_up:=smoothstep(10.0,36.0,gap)
                var pace: float=advance_distance*(1.0+0.22*catch_up)+lerpf(27.0,44.0,cadence)*dt
                next+=Vector2.from_angle(angle)*minf(pace,gap)*aligned
            next=sim._field_point(next)
            if near_water and sim.in_open_water(next):
                var bank: Vector2=sim._dry_formation_slot(center,next)
                next=bank if p.distance_to(bank)<=p.distance_to(next) and not sim.in_open_water(bank) else p
            distance=float(old["walked"][idx])+p.distance_to(next)
        start.append(p)
        end.append(next)
        from_heading.append(before)
        heading.append(angle)
        walked.append(distance)
    return {"start":start,"end":end,"heading":heading,"from_heading":from_heading,"walked":walked,
        "center":center,"tick":sim.step_count,"core":core}
