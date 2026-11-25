extends RefCounted
const FIELDCRAFT = preload("res://assets/art/fieldcraft.svg")
## Deterministic, continuous terrain art. Gameplay coordinates remain unchanged.
static func battlefield(extent: Vector2, forests: Array[Rect2], hill: Rect2, scenario: int, scale: float = 1.0) -> ImageTexture:
    # Bake higher-resolution wide terrain; retain true world coordinates.
    var bake: float = 0.75 if scale > 1.0 else 1.0
    var w: int = int(extent.x*bake)
    var h: int = int(extent.y*bake)
    var image := Image.create_empty(w,h,false,Image.FORMAT_RGBA8)
    var noise := FastNoiseLite.new()
    noise.seed = 1700+scenario*19
    noise.frequency = 0.008
    noise.fractal_octaves = 4
    var grain := FastNoiseLite.new()
    grain.seed = 48+scenario
    grain.frequency = 0.17
    grain.fractal_octaves = 2
    var dark := Color("#263e2b")
    var middle := Color("#5a7241")
    var light := Color("#a0a366")
    var path := Color("#b99a66")
    var shade := Color("#324437")
    var crest := Color("#aaa583")
    for y in range(h):
        for x in range(w):
            var p := Vector2(x,y)/bake
            var v: float = noise.get_noise_2d(p.x,p.y)*0.5+0.5
            var g: float = grain.get_noise_2d(p.x,p.y)
            var ground: Color = dark.lerp(middle,smoothstep(0.1,0.48,v)).lerp(light,smoothstep(0.50,0.90,v))
            var slope: float = (noise.get_noise_2d(p.x+13.0,p.y+13.0)-noise.get_noise_2d(p.x-13.0,p.y-13.0))*0.60
            ground=ground.lightened(maxf(0.0,-slope)*0.5).darkened(maxf(0.0,slope)*0.7)
            var micro: float = grain.get_noise_2d(p.x*2.1+49.0,p.y*2.1-33.0)
            ground = ground.lightened(maxf(0.0,g)*0.19+maxf(0.0,micro)*0.11).darkened(maxf(0.0,-g)*0.16+maxf(0.0,-micro)*0.08)
            # Road centers match the simulation; edges are worn, not tiled.
            var d: float = INF
            for lane in range(3):
                var cy: float = [131.0,282.0,435.0][lane]*scale
                if scale > 1.0: cy += sin(p.x/220.0+float(lane)*1.6)*48.0+sin(p.x/94.0+float(lane))*19.0
                d = minf(d,absf(p.y-cy))
            var wear: float = 1.0-smoothstep(6.0,22.0 if scale > 1.0 else 15.0,d+g*5.0)
            ground = ground.lerp(path.lightened(g*0.14).darkened(maxf(0.0,-micro)*0.16),wear*0.94)
            if d > 25.0 and micro > 0.44:
                ground = ground.lerp(Color("#9aa96a"),(micro-0.44)*0.24)
            if d < 9.0:
                ground = ground.darkened((1.0-smoothstep(0.7,2.4,absf(d-6.0)))*0.20)
            elif d < 16.0:
                ground = ground.lightened(maxf(0.0,micro)*0.08)
            for forest in forests:
                var n: Vector2 = (p-forest.get_center())/(forest.size*0.5+Vector2(9,9))
                var edge: float = maxf(absf(n.x),absf(n.y))+g*0.09
                var cover: float = 1.0-smoothstep(0.72,1.08,edge)
                ground = ground.lerp(shade.lightened(v*0.12),cover*0.76)
            var hp: Vector2 = (p-hill.get_center())/(hill.size*0.5+Vector2(16,16))
            var r: float = hp.length()+g*0.05
            var elevation: float = pow(maxf(0.0,1.0-r),0.7)
            if elevation > 0.0:
                var hill_shade: float = clampf(0.48-hp.x*0.24-hp.y*0.31+g*0.10,0.0,1.0)
                var rock: Color = shade.lerp(crest,hill_shade)
                ground = ground.lerp(rock,smoothstep(0.0,0.30,elevation)*0.90)
                var band: float = absf(fmod(elevation*8.0,1.0)-0.5)
                if band < 0.045: ground = ground.darkened(0.12)
            if scale > 1.0:
                var rx: float = 1120.0+sin(p.y/225.0)*100.0+sin(p.y/89.0)*34.0
                var bank: float = absf(p.x-rx)
                var bridge: bool = absf(p.y-390.0)<=38.0 or absf(p.y-850.0)<=38.0 or absf(p.y-1300.0)<=38.0
                if bank < 41.0:
                    ground = ground.lerp(Color("#908b70").lightened(maxf(0.0,micro)*0.16),(1.0-smoothstep(28.0,41.0,bank))*0.88)
                if bank < 27.0:
                    var water: Color = Color("#23494f").lerp(Color("#77a8a1"),smoothstep(0.3,0.8,v))
                    water = water.lightened(maxf(0.0,sin(p.y*0.22+p.x*0.09))*0.12)
                    water = water.lerp(Color("#d3d6ae"),(1.0-smoothstep(0.0,3.0,absf(bank-25.0)))*maxf(0.0,g+0.25)*0.34)
                    ground = ground.lerp(water,1.0-smoothstep(24.0,27.0,bank))
                    if bridge:
                        var board: Color = Color("#95795a").lightened(g*0.1)
                        if fmod(p.x,7.0)<1.4: board = board.darkened(0.24)
                        ground = board
            var edge_v: float = minf(minf(float(x)/bake,extent.x-float(x)/bake),minf(float(y)/bake,extent.y-float(y)/bake))
            ground = ground.darkened((1.0-smoothstep(0.0,55.0,edge_v))*0.23)
            image.set_pixel(x,y,ground)
    var rng := RandomNumberGenerator.new()
    rng.seed = 2148+scenario*37
    # Cached grass tufts and pebbles, kept off roads, waterways and forest interiors.
    if scale > 1.0:
        for i in range(5600):
            var point:=Vector2(rng.randf_range(8,extent.x-8),rng.randf_range(8,extent.y-8))
            var road_distance: float=INF
            for lane in range(3):
                var cy: float=[131.0,282.0,435.0][lane]*scale+sin(point.x/220.0+float(lane)*1.6)*48.0+sin(point.x/94.0+float(lane))*19.0
                road_distance=minf(road_distance,absf(point.y-cy))
            var river: float=absf(point.x-(1120.0+sin(point.y/225.0)*100.0+sin(point.y/89.0)*34.0))
            if road_distance < 24.0 or river < 45.0: continue
            var pixel:=Vector2i(point*bake)
            var base: Color=image.get_pixel(pixel.x,pixel.y)
            for j in range(3):
                var xx: int=pixel.x+j-1
                var yy: int=pixel.y-1-((i+j)%2)
                image.set_pixel(xx,yy,base.lightened(0.12+float(j)*0.025))
            image.set_pixel(pixel.x,pixel.y,base.darkened(0.22))
    var tree_images: Array[Image] = []
    var atlas: Image=FIELDCRAFT.get_image()
    if atlas.is_compressed(): atlas.decompress()
    if atlas.get_format()!=Image.FORMAT_RGBA8: atlas.convert(Image.FORMAT_RGBA8)
    for i in range(5):
        var tree: Image=atlas.get_region(Rect2i(256,256,256,256))
        var size: int=roundi((45.0+float(i)*5.0)*bake)
        tree.resize(size,size,Image.INTERPOLATE_LANCZOS)
        if i%2==1: tree.flip_x()
        tree_images.append(tree)
    # Rock ridges belong inside the simulated hill only; leave actual roads open.
    if scale>1.0:
        var rock: Image=atlas.get_region(Rect2i(512,256,256,256))
        rock.resize(roundi(100*bake),roundi(100*bake),Image.INTERPOLATE_LANCZOS)
        for i in range(16):
            var center:Vector2=hill.position+Vector2(rng.randf_range(18,hill.size.x-18),rng.randf_range(18,hill.size.y-18))
            var road_distance:float=INF
            for lane in range(3):
                var cy:float=[131.0,282.0,435.0][lane]*scale+sin(center.x/220.0+float(lane)*1.6)*48.0+sin(center.x/94.0+float(lane))*19.0
                road_distance=minf(road_distance,absf(center.y-cy))
            if road_distance<55.0 or absf(center.x-(1120.0+sin(center.y/225.0)*100.0+sin(center.y/89.0)*34.0))<90.0: continue
            image.blend_rect(rock,Rect2i(0,0,rock.get_width(),rock.get_height()),Vector2i(center*bake)-Vector2i(rock.get_width()/2,rock.get_height()/2))
    # Draw forest clusters as overlapping individual crowns, not rectangular tiles.
    var trees: Array[Dictionary] = []
    for forest in forests:
        var count: int = int(forest.get_area()/610.0)
        for i in range(count):
            var pos := Vector2(rng.randf_range(forest.position.x+5,forest.end.x-5),rng.randf_range(forest.position.y+5,forest.end.y-5))
            if scale > 1.0 and absf(pos.x-(1120.0+sin(pos.y/225.0)*100.0+sin(pos.y/89.0)*34.0)) < 45.0: continue
            var on_road: bool=false
            for lane in range(3):
                var cy:float=[131.0,282.0,435.0][lane]*scale
                if scale>1.0: cy+=sin(pos.x/220.0+float(lane)*1.6)*48.0+sin(pos.x/94.0+float(lane))*19.0
                if absf(pos.y-cy)<34.0: on_road=true
            if not on_road: trees.append({"pos":pos,"tile":rng.randi_range(0,4)})
    trees.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return (a["pos"] as Vector2).y < (b["pos"] as Vector2).y)
    for t in trees:
        var tree: Image = tree_images[int(t["tile"])]
        var center: Vector2 = t["pos"]
        image.blend_rect(tree,Rect2i(0,0,tree.get_width(),tree.get_height()),Vector2i(center*bake)-Vector2i(tree.get_width()/2,int(tree.get_height()*0.70)))
    image.generate_mipmaps()
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

# Soft, irregular translucent texture generated once. It is used only for actual
# soil-contact particles, not baked into terrain or screenshot artwork.
static func dust_cloud() -> ImageTexture:
    var img:=Image.create_empty(64,64,false,Image.FORMAT_RGBA8)
    var noise:=FastNoiseLite.new()
    noise.seed=381
    noise.frequency=0.095
    noise.fractal_octaves=3
    for y in range(64):
        for x in range(64):
            var p:=Vector2(x,y)
            var d: float=(p-Vector2(31.5,31.5)).length()/31.5
            var n: float=noise.get_noise_2d(x,y)*0.5+0.5
            var a: float=pow(maxf(0.0,1.0-d),1.3)*(0.45+0.55*n)
            var c: Color=Color("#baa17d").lerp(Color("#e2c89b"),n)
            c.a=a
            img.set_pixel(x,y,c)
    return ImageTexture.create_from_image(img)
