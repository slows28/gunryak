extends RefCounted
## Deterministic, continuous terrain art. Gameplay coordinates remain unchanged.
static func battlefield(extent: Vector2, forests: Array[Rect2], hill: Rect2, scenario: int) -> ImageTexture:
    var w: int = int(extent.x)
    var h: int = int(extent.y)
    var image := Image.create_empty(w,h,false,Image.FORMAT_RGBA8)
    var noise := FastNoiseLite.new()
    noise.seed = 1700+scenario*19
    noise.frequency = 0.008
    noise.fractal_octaves = 4
    var grain := FastNoiseLite.new()
    grain.seed = 48+scenario
    grain.frequency = 0.17
    grain.fractal_octaves = 2
    var dark := Color("#364c40")
    var middle := Color("#63734e")
    var light := Color("#87916a")
    var path := Color("#a99a72")
    var shade := Color("#324437")
    var crest := Color("#aaa583")
    for y in range(h):
        for x in range(w):
            var p := Vector2(x,y)
            var v: float = noise.get_noise_2d(x,y)*0.5+0.5
            var g: float = grain.get_noise_2d(x,y)
            var ground: Color = dark.lerp(middle,smoothstep(0.1,0.48,v)).lerp(light,smoothstep(0.50,0.90,v))
            ground = ground.lightened(maxf(0.0,g)*0.14).darkened(maxf(0.0,-g)*0.12)
            # Road centers match the simulation; edges are worn, not tiled.
            var d: float = minf(absf(float(y)-131.0),minf(absf(float(y)-282.0),absf(float(y)-435.0)))
            var wear: float = 1.0-smoothstep(6.0,15.0,d+g*5.0)
            ground = ground.lerp(path.lightened(g*0.10),wear*0.80)
            if d < 5.0:
                ground = ground.darkened((1.0-smoothstep(0.8,2.8,absf(d-3.3)))*0.12)
            for forest in forests:
                var n: Vector2 = (p-forest.get_center())/(forest.size*0.5+Vector2(9,9))
                var edge: float = maxf(absf(n.x),absf(n.y))+g*0.09
                var cover: float = 1.0-smoothstep(0.72,1.08,edge)
                ground = ground.lerp(shade.lightened(v*0.12),cover*0.76)
            var hp: Vector2 = (p-hill.get_center())/(hill.size*0.5+Vector2(16,16))
            var r: float = hp.length()+g*0.05
            var elevation: float = pow(maxf(0.0,1.0-r),0.7)
            if elevation > 0.0:
                var slope: float = clampf(0.48-hp.x*0.24-hp.y*0.31+g*0.10,0.0,1.0)
                var rock: Color = shade.lerp(crest,slope)
                ground = ground.lerp(rock,smoothstep(0.0,0.30,elevation)*0.90)
                var band: float = absf(fmod(elevation*8.0,1.0)-0.5)
                if band < 0.045: ground = ground.darkened(0.12)
            var edge_v: float = minf(minf(float(x),float(w-x)),minf(float(y),float(h-y)))
            ground = ground.darkened((1.0-smoothstep(0.0,55.0,edge_v))*0.23)
            image.set_pixel(x,y,ground)
    var rng := RandomNumberGenerator.new()
    rng.seed = 2148+scenario*37
    var tree_images: Array[Image] = []
    for i in range(5):
        tree_images.append(_tree(i))
    # Draw forest clusters as overlapping individual crowns, not rectangular tiles.
    var trees: Array[Dictionary] = []
    for forest in forests:
        var count: int = int(forest.get_area()/400.0)
        for i in range(count):
            var pos := Vector2(rng.randf_range(forest.position.x+5,forest.end.x-5),rng.randf_range(forest.position.y+5,forest.end.y-5))
            trees.append({"pos":pos,"tile":rng.randi_range(0,4)})
    trees.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return (a["pos"] as Vector2).y < (b["pos"] as Vector2).y)
    for t in trees:
        var tree: Image = tree_images[int(t["tile"])]
        var center: Vector2 = t["pos"]
        image.blend_rect(tree,Rect2i(0,0,tree.get_width(),tree.get_height()),Vector2i(center)-Vector2i(18,23))
    return ImageTexture.create_from_image(image)

static func _tree(index: int) -> Image:
    var img := Image.create_empty(43,43,false,Image.FORMAT_RGBA8)
    var rng := RandomNumberGenerator.new()
    rng.seed = 77+index*991
    var lobes: Array[Vector2] = []
    var radii: Array[float] = []
    for i in range(8):
        var a: float = float(i)*TAU/8.0
        lobes.append(Vector2(18,17)+Vector2.from_angle(a)*rng.randf_range(4.0,9.0))
        radii.append(rng.randf_range(7.0,11.0))
    for y in range(43):
        for x in range(43):
            var p := Vector2(x,y)
            var shadow: float = 1.0-smoothstep(0.65,1.0,((p-Vector2(24,26))/Vector2(18,12)).length())
            var c := Color(0.08,0.12,0.09,shadow*0.36)
            var cover: float = 0.0
            var detail: float = 0.0
            for j in range(lobes.size()):
                var distance: float = p.distance_to(lobes[j])/radii[j]
                var alpha: float = 1.0-smoothstep(0.8,1.0,distance)
                if alpha > cover:
                    cover = alpha
                    detail = clampf(0.64-(p.x-lobes[j].x)*0.04-(p.y-lobes[j].y)*0.047,0.0,1.0)
            if cover > 0.0:
                var leaf: Color = Color("#243c31").lerp(Color("#788552"),detail)
                leaf = leaf.darkened(rng.randf_range(0.0,0.13))
                leaf.a = cover
                c = c.blend(leaf)
            img.set_pixel(x,y,c)
    return img

static func campaign_map(nodes: Array, owned: Array) -> ImageTexture:
    var image := Image.create_empty(820,570,false,Image.FORMAT_RGBA8)
    var noise := FastNoiseLite.new()
    noise.seed = 924
    noise.frequency = 0.007
    noise.fractal_octaves = 5
    for y in range(570):
        for x in range(820):
            var p := Vector2(x,y)
            var value: float = noise.get_noise_2d(x,y)*0.5+0.5
            var c: Color = Color("#35483e").lerp(Color("#acaa78"),smoothstep(0.16,0.85,value))
            var first: float = INF
            var second: float = INF
            var region: int = 0
            for i in range(nodes.size()):
                var n: Array = nodes[i]["pos"]
                var d: float = p.distance_to(Vector2(n[0],n[1]))
                if d < first:
                    second = first
                    first = d
                    region = i
                elif d < second:
                    second = d
            var tint: Color = Color("#557f82") if region in owned else Color("#987460")
            c = c.lerp(tint,0.32)
            if absf(second-first) < 3.0+value*2.0:
                c = c.darkened(0.38)
            var ridge: float = absf(fmod(value*20.0,1.0)-0.5)
            if ridge < 0.035 and value > 0.49:
                c = c.darkened(0.17)
            var river_y: float = 340.0+sin(float(x)*0.010)*48.0+sin(float(x)*0.022)*16.0
            var river: float = absf(float(y)-river_y)
            if river < 13.0:
                c = c.lerp(Color("#426f78"),(1.0-smoothstep(5.0,13.0,river))*0.96)
            var edge: float = minf(minf(float(x),float(820-x)),minf(float(y),float(570-y)))
            c = c.darkened((1.0-smoothstep(0.0,38.0,edge))*0.24)
            image.set_pixel(x,y,c)
    return ImageTexture.create_from_image(image)
