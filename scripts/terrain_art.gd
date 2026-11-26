extends RefCounted
const FieldGeometry=preload("res://scripts/field_geometry.gd")
const PAINTED_GROUND = preload("res://assets/art/painted_atlas.webp")
const VALLEY_DETAILS = preload("res://assets/art/valley_details.webp")
const TIMBER_CROSSING = preload("res://assets/art/timber_crossing.webp")
const CROSSING_SIZE := Vector2i(118,89)
const HARVEST_FIELDS = preload("res://assets/art/harvest_fields.webp")
const VALLEY_TREES = preload("res://assets/art/valley_trees.webp")
const TREE_CELL := 192
const TREE_FOOT := Vector2(86,146)/192.0
const TREE_SIZES := [66.0,60.0,73.0,70.0,64.0]
## Deterministic, continuous terrain art. Gameplay coordinates remain unchanged.
static func battlefield(extent: Vector2, forests: Array[Rect2], hill: Rect2, scenario: int, scale: float = 1.0, layers: Dictionary = {}) -> ImageTexture:
    # Bake higher-resolution wide terrain; retain true world coordinates.
    # Native world-pixel density for the zoomed battlefield. Mipmaps serve overview.
    var bake: float = 1.0
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
    # Grade one continuous field painting to the light and soil of each scenario.
    var grades := [Color(0.89,0.98,1.04),Color(0.88,0.95,1.04),Color(1.02,0.96,0.94),Color(0.84,0.98,1.10),Color(1.0,0.92,0.92)]
    var washes := [Color("#697956"),Color("#838373"),Color("#a08d65"),Color("#647e70"),Color("#99816d")]
    var grade: Color=grades[clampi(scenario,0,4)]
    var wash: Color=washes[clampi(scenario,0,4)]
    var path := Color("#b59970")
    var shade := Color("#364636")
    var crest := Color("#b6ad8d")
    var fields: Image=HARVEST_FIELDS.get_image()
    if fields.is_compressed(): fields.decompress()
    if scenario in [1,3]: fields.flip_x()
    if scenario in [2,4]: fields.flip_y()
    fields.resize(w,h,Image.INTERPOLATE_BILINEAR)
    var source: Image=PAINTED_GROUND.get_image()
    if source.is_compressed(): source.decompress()
    if source.get_format()!=Image.FORMAT_RGBA8: source.convert(Image.FORMAT_RGBA8)
    var dirt_art: Image=source.get_region(Rect2i(136,520,112,112))
    var forest_art: Image=source.get_region(Rect2i(264,520,112,112))
    var hill_art: Image=source.get_region(Rect2i(392,520,112,112))
    # Macro illumination is sampled once on a coarse mesh, not millions of extra noise calls.
    # It is an artistic height cue only: the simulation still uses its real hill/forest geometry.
    var relief:=FastNoiseLite.new()
    relief.seed=1901+scenario*71
    relief.frequency=0.0029
    relief.fractal_octaves=3
    var relief_stride: int=32
    var relief_columns: int=ceili(extent.x/relief_stride)+2
    var relief_rows: int=ceili(extent.y/relief_stride)+2
    var lighting:=PackedFloat32Array()
    lighting.resize(relief_columns*relief_rows)
    for gy in range(relief_rows):
        for gx in range(relief_columns):
            var q:=Vector2(gx*relief_stride,gy*relief_stride)
            var h0:float=relief.get_noise_2d(q.x-22.0,q.y-30.0)
            var h1:float=relief.get_noise_2d(q.x+22.0,q.y+30.0)
            lighting[gy*relief_columns+gx]=clampf((h0-h1)*2.2,-0.42,0.38)
    var forest_bounds: Array[Rect2]=[]
    for forest in forests: forest_bounds.append(forest.grow(35.0))
    var roads: Array[PackedFloat32Array]=[]
    var rivers:=PackedFloat32Array()
    rivers.resize(h)
    for yy in range(h):
        var wy:float=float(yy)/bake
        rivers[yy]=FieldGeometry.river_x(wy)
    for lane in range(3):
        var row:=PackedFloat32Array()
        row.resize(w)
        for xx in range(w):
            var wx:float=float(xx)/bake
            row[xx]=FieldGeometry.road_y(wx,lane,scale,scenario)
        roads.append(row)
    var crossings := PackedFloat32Array([390.0,850.0,1300.0])
    for y in range(h):
        var crossing_x: float=INF
        if scale>1.0:
            for crossing_y in crossings:
                if absf(float(y)/bake-crossing_y)<55.0:
                    crossing_x=FieldGeometry.river_x(crossing_y)
                    break
        var grid_y: float=float(y)/float(relief_stride)
        var iy: int=floori(grid_y)
        var ty: float=grid_y-float(iy)
        var shade_row:=PackedFloat32Array()
        shade_row.resize(relief_columns)
        for gx in range(relief_columns):
            shade_row[gx]=lerpf(lighting[iy*relief_columns+gx],lighting[(iy+1)*relief_columns+gx],ty)
        for x in range(w):
            var p := Vector2(x,y)/bake
            var v: float = noise.get_noise_2d(p.x,p.y)*0.5+0.5
            var g: float = grain.get_noise_2d(p.x,p.y)
            var ground: Color=(fields.get_pixel(x,y)*grade).lerp(wash,0.15)
            var uv:=Vector2i(_mirror_sample(roundi(p.x*0.68+v*20.0),112),_mirror_sample(roundi(p.y*0.68+v*14.0),112))
            var micro: float = grain.get_noise_2d(p.x*2.1+49.0,p.y*2.1-33.0)
            var grid_x: float=float(x)/float(relief_stride)
            var ix: int=floori(grid_x)
            var relief_light: float=lerpf(shade_row[ix],shade_row[ix+1],grid_x-float(ix))
            ground=ground.lightened(maxf(0.0,relief_light)*0.12).darkened(maxf(0.0,-relief_light)*0.19)
            # Road centers match the simulation; edges are worn, not tiled.
            var d: float = INF
            for lane in range(3):
                d = minf(d,absf(p.y-roads[lane][x]))
            var apron: float=1.0-smoothstep(50.0,142.0,absf(p.x-crossing_x)) if d<50 and is_finite(crossing_x) else 0.0
            var road_edge: float=22.0 if scale>1.0 else 15.0
            var wear: float=1.0-smoothstep(6.0+25.0*apron,road_edge+18.0*apron,d+g*5.0)
            if wear>0.0:
                var dirt:Color=path.lerp(dirt_art.get_pixelv(uv),0.40)
                ground = ground.lerp(dirt.lightened(g*0.09),wear*0.98)
            if d > 25.0 and micro > 0.32:
                ground = ground.lerp(Color("#9aa96a"),(micro-0.32)*0.34)
            if d>25.0 and g < -0.25:
                ground=ground.lerp(Color("#62543a"),(-g-0.25)*0.19)
            if d < 12.0:
                var rut: float = 1.0-smoothstep(0.8,3.0,absf(d-7.0+g*1.5))
                ground = ground.darkened(rut*0.20)
                ground = ground.lightened((1.0-smoothstep(0.6,2.0,absf(d-10.0)))*0.13)
            elif d < 16.0:
                ground = ground.lightened(maxf(0.0,micro)*0.08)
            for index in range(forests.size()):
                if not forest_bounds[index].has_point(p): continue
                var forest: Rect2=forests[index]
                var n: Vector2 = (p-forest.get_center())/(forest.size*0.5+Vector2(9,9))
                var edge: float = lerpf(maxf(absf(n.x),absf(n.y)),n.length(),0.45)+g*0.12
                var cover: float = 1.0-smoothstep(0.72,1.08,edge)
                if cover>0.0:
                    var forest_color:Color=shade.lerp(forest_art.get_pixelv(uv),0.72)
                    ground = ground.lerp(forest_color,cover*0.82*(1.0-wear))
            var hp: Vector2 = (p-hill.get_center())/(hill.size*0.5+Vector2(16,16))
            var r: float = hp.length()+g*0.05
            var elevation: float = pow(1.0-r,0.7) if r<1.0 else 0.0
            if elevation > 0.0:
                var hill_shade: float = clampf(0.48-hp.x*0.24-hp.y*0.31+g*0.10,0.0,1.0)
                var rock: Color = shade.lerp(crest,hill_shade).lerp(hill_art.get_pixelv(uv),0.37)
                rock=rock.lightened(maxf(0.0,relief_light)*0.30).darkened(maxf(0.0,-relief_light)*0.45)
                ground = ground.lerp(rock,smoothstep(0.0,0.30,elevation)*0.90*(1.0-wear))
                # Broken slope faces rather than artificial concentric contour bands.
                var ridge: float=absf(sin(hp.x*11.0+hp.y*4.0+g*0.55))
                ground=ground.darkened((1.0-smoothstep(0.02,0.24,ridge))*elevation*0.16)
            if scale > 1.0:
                var rx: float = rivers[y]
                var bank: float = absf(p.x-rx)
                if bank < 49.0:
                    var silt: Color=Color("#726c4e").lerp(Color("#b8af87"),clampf(0.40+g*0.8+micro*0.34,0.0,1.0))
                    ground=ground.lerp(silt,(1.0-smoothstep(26.0,47.0,bank+g*4.0))*0.84*(1.0-wear))
                if bank < 27.0:
                    # The deeper channel shifts to the outside of the bend.
                    var outside_bend: float=signf(p.x-rx)*sin(p.y/120.0+0.6)
                    var shelf: float=clampf(12.0-outside_bend*7.0+(v-0.5)*17.0,4.0,23.0)
                    var depth: float=smoothstep(-1.0,shelf+7.0,27.0-bank+g*2.4)
                    var shoal: Color=Color("#87957a").lerp(dirt_art.get_pixelv(uv),0.23)
                    var water: Color=shoal.lerp(Color("#65978c"),smoothstep(0.0,0.50,depth)).lerp(Color("#396669"),smoothstep(0.23,1.0,depth))
                    var ripple: float=sin(p.y*0.24+p.x*0.09+v*5.0)
                    water=water.lightened(maxf(0.0,ripple)*0.035+maxf(0.0,micro)*(0.025+0.23*(1.0-depth))+(v-0.4)*0.09)
                    ground=ground.lerp(water,1.0-smoothstep(24.0,27.0,bank))
            var edge_v: float = minf(minf(float(x)/bake,extent.x-float(x)/bake),minf(float(y)/bake,extent.y-float(y)/bake))
            ground = ground.darkened((1.0-smoothstep(0.0,55.0,edge_v))*0.23)
            image.set_pixel(x,y,ground)
    if scale > 1.0:
        for basin: Rect2 in FieldGeometry.MARSHES[scenario]:
            var area:=Rect2i(basin).intersection(Rect2i(0,0,w,h))
            for yy in range(area.position.y,area.end.y):
                for xx in range(area.position.x,area.end.x):
                    var edge: float=FieldGeometry.basin_radius(Vector2(xx,yy),basin)
                    if edge>=1.0: continue
                    var reed: float=noise.get_noise_2d(xx,yy*1.8)
                    var water: float=smoothstep(-0.28,0.32,reed+0.16*sin(xx*0.05+yy*0.16))
                    var pigment:=Color("#6c7850").lerp(Color("#74958c"),water)
                    var cover: float=(1.0-smoothstep(0.68,1.0,edge))*0.82
                    image.set_pixel(xx,yy,image.get_pixel(xx,yy).lerp(pigment,cover))
        for bed: Rect2 in FieldGeometry.REEDBEDS[scenario]:
            _paint_reedbed(image, bed, noise)
    var rng := RandomNumberGenerator.new()
    rng.seed = 2148+scenario*37
    # Cached grass tufts and pebbles, kept off roads, waterways and forest interiors.
    if scale > 1.0:
        for i in range(22000):
            var point:=Vector2(rng.randf_range(8,extent.x-8),rng.randf_range(8,extent.y-8))
            var road_distance: float=INF
            for lane in range(3):
                var cy: float=FieldGeometry.road_y(point.x,lane,scale,scenario)
                road_distance=minf(road_distance,absf(point.y-cy))
            var river: float=absf(point.x-(1120.0+sin(point.y/225.0)*100.0+sin(point.y/89.0)*34.0))
            if road_distance < 24.0 or river < 45.0: continue
            var pixel:=Vector2i(point*bake)
            var base: Color=image.get_pixel(pixel.x,pixel.y)
            # Tiny rooted strokes, not scattered rectangular vegetation stamps.
            var leaf: Color=base.lerp(Color("#c4bb7d"),0.12+rng.randf()*0.19)
            var blade: int=2+rng.randi_range(0,2)
            for j in range(blade):
                var xx: int=pixel.x+floori(float(j)/2.0)-1
                var yy: int=pixel.y-j
                image.set_pixel(xx,yy,leaf.darkened(float(j)*0.045))
            image.set_pixel(pixel.x,pixel.y,base.darkened(0.25))
    var tree_images: Array[Image] = []
    var canopy: Image=VALLEY_TREES.get_image()
    if canopy.is_compressed(): canopy.decompress()
    if canopy.get_format()!=Image.FORMAT_RGBA8: canopy.convert(Image.FORMAT_RGBA8)
    for i in range(TREE_SIZES.size()):
        tree_images.append(canopy.get_region(Rect2i(i*TREE_CELL,0,TREE_CELL,TREE_CELL)))
    # Rock ridges belong inside the simulated hill only; leave actual roads open.
    if scale>1.0:
        var scenery: Image=VALLEY_DETAILS.get_image()
        if scenery.is_compressed(): scenery.decompress()
        if scenery.get_format()!=Image.FORMAT_RGBA8: scenery.convert(Image.FORMAT_RGBA8)
        var ridge: Image=scenery.get_region(Rect2i(0,0,256,256))
        var outcrops: Array[Image]=[]
        for width in [73,89,107,122]:
            var patch: Image=ridge.duplicate()
            var size: int=roundi(width*bake)
            patch.resize(size,size,Image.INTERPOLATE_LANCZOS)
            if width%2==0: patch.flip_x()
            outcrops.append(patch)
        for i in range(16):
            var center:Vector2=hill.position+Vector2(rng.randf_range(18,hill.size.x-18),rng.randf_range(18,hill.size.y-18))
            var road_distance:float=INF
            for lane in range(3):
                var cy:float=FieldGeometry.road_y(center.x,lane,scale,scenario)
                road_distance=minf(road_distance,absf(center.y-cy))
            if road_distance<55.0 or absf(center.x-(1120.0+sin(center.y/225.0)*100.0+sin(center.y/89.0)*34.0))<90.0: continue
            var rock: Image=outcrops[i%outcrops.size()]
            image.blend_rect(rock,Rect2i(0,0,rock.get_width(),rock.get_height()),Vector2i(center*bake)-Vector2i(rock.get_width()/2,rock.get_height()/2))
        # Bake scattered brush and talus into the same terrain cache.
        var details: Array[Image]=[]
        for kind in range(3):
            var tile: Image=scenery.get_region(Rect2i(kind*256,0,256,256))
            for variant in range(3):
                var patch: Image=tile.duplicate()
                var width: float=11.0+variant*7.0 if kind==2 else 19.0+variant*10.0
                var size: int=roundi((width+(12.0 if kind==0 else 0.0))*bake)
                patch.resize(size,size,Image.INTERPOLATE_LANCZOS)
                if variant==1: patch.flip_x()
                details.append(patch)
        var decor: Array[Dictionary]=[]
        for i in range(2600):
            var p:=Vector2(rng.randf_range(40,extent.x-40),rng.randf_range(40,extent.y-40))
            var bank: float=absf(p.x-(1120.0+sin(p.y/225.0)*100.0+sin(p.y/89.0)*34.0))
            var road_distance: float=INF
            for lane in range(3):
                var cy:float=FieldGeometry.road_y(p.x,lane,scale,scenario)
                road_distance=minf(road_distance,absf(p.y-cy))
            if road_distance<43.0 or bank<54.0: continue
            var kind: int=2
            var density: float=noise.get_noise_2d(p.x*1.4+100,p.y*1.4-80)
            if density < -0.04 and i%6!=0: continue
            if bank<105.0 or hill.has_point(p): kind=0 if i%3==0 else 1
            elif i%9==0 and density>0.22: kind=1
            var tile_index: int=kind*3+rng.randi_range(0,2)
            # Leave open stubble between patches. Retain the tree layout when thinning brush.
            if kind==2 and (i%3!=0 or density<0.10): continue
            decor.append({"pos":p,"tile":tile_index})
        decor.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return (a["pos"] as Vector2).y<(b["pos"] as Vector2).y)
        for item in decor:
            var patch: Image=details[int(item["tile"])]
            var center: Vector2=item["pos"]
            image.blend_rect(patch,Rect2i(Vector2i.ZERO,patch.get_size()),Vector2i(center*bake)-Vector2i(patch.get_width()/2,patch.get_height()/2))
    # Draw forest clusters as overlapping individual crowns, not rectangular tiles.
    var trees: Array[Dictionary] = []
    for forest in forests:
        var count: int = int(forest.get_area()/510.0)
        for i in range(count):
            var pos := Vector2(rng.randf_range(forest.position.x+5,forest.end.x-5),rng.randf_range(forest.position.y+5,forest.end.y-5))
            if scale > 1.0 and absf(pos.x-(1120.0+sin(pos.y/225.0)*100.0+sin(pos.y/89.0)*34.0)) < 45.0: continue
            var on_road: bool=false
            for lane in range(3):
                var cy:float=FieldGeometry.road_y(pos.x,lane,scale,scenario)
                if absf(pos.y-cy)<34.0: on_road=true
            if not on_road:
                var tile: int=rng.randi_range(0,TREE_SIZES.size()-1)
                var spread: float=0.86+0.016*posmod(floori(pos.x+pos.y*3.0),17)
                trees.append({"pos":pos,"tile":tile,"size":roundi(TREE_SIZES[tile]*spread)})
    trees.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return (a["pos"] as Vector2).y < (b["pos"] as Vector2).y)
    # Keep a distinct tree layer when requested. The original fully baked path
    # remains available to existing callers (e.g. static terrain tests).
    if bool(layers.get("separate_trees",false)):
        var textures: Array[ImageTexture]=[]
        for tree in tree_images:
            tree.generate_mipmaps()
            textures.append(ImageTexture.create_from_image(tree))
        layers["trees"]=trees
        layers["textures"]=textures
    else:
        var variants := {}
        for t in trees:
            var key := Vector2i(int(t["tile"]),int(t["size"]))
            if not variants.has(key):
                var scaled: Image=tree_images[key.x].duplicate()
                scaled.resize(key.y,key.y,Image.INTERPOLATE_LANCZOS)
                variants[key]=scaled
            var tree: Image=variants[key]
            var origin: Vector2=Vector2(t["pos"])*bake-Vector2(tree.get_size())*TREE_FOOT
            image.blend_rect(tree,Rect2i(Vector2i.ZERO,tree.get_size()),Vector2i(origin))
    # Riverbanks retain exact simulation boundary; gravel and reeds lie outside it.
    if scale>1.0:
        for i in range(4600):
            var wy: float=rng.randf_range(12,extent.y-12)
            if absf(wy-390.0)<46.0 or absf(wy-850.0)<46.0 or absf(wy-1300.0)<46.0: continue
            var bank: float=-1.0 if i%2==0 else 1.0
            var rx: float=1120.0+sin(wy/225.0)*100.0+sin(wy/89.0)*34.0
            var wx: float=rx+bank*rng.randf_range(31.0,50.0)
            var px: int=roundi(wx*bake)
            var py: int=roundi(wy*bake)
            var stone: Color=image.get_pixel(px,py).lerp(Color("#c1baa0"),rng.randf_range(0.16,0.53))
            image.set_pixel(px,py,stone)
            image.set_pixel(px+1,py,stone.darkened(0.28))
            if i%4==0:
                image.set_pixel(px,py-1,stone.lightened(0.15))
                image.set_pixel(px+1,py-2,Color("#778a55"))
        # The minimap and static terrain callers both sample this image.
        var deck: Image=TIMBER_CROSSING.get_image()
        if deck.is_compressed(): deck.decompress()
        if deck.get_format()!=Image.FORMAT_RGBA8: deck.convert(Image.FORMAT_RGBA8)
        deck.resize(CROSSING_SIZE.x,CROSSING_SIZE.y,Image.INTERPOLATE_LANCZOS)
        for crossing_y in crossings:
            var center:=Vector2(FieldGeometry.river_x(crossing_y),crossing_y)
            var origin:=Vector2i((center-Vector2(CROSSING_SIZE)*0.5)*bake)
            image.blend_rect(deck,Rect2i(Vector2i.ZERO,deck.get_size()),origin)
    image.generate_mipmaps()
    return ImageTexture.create_from_image(image)

static func _paint_reedbed(image: Image, bed: Rect2, noise: FastNoiseLite) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = int(bed.position.x + bed.position.y * 271)
    var area := Rect2i(bed)
    for y in range(area.position.y,area.end.y):
        for x in range(area.position.x,area.end.x):
            var edge := FieldGeometry.basin_radius(Vector2(x,y),bed)
            if edge >= 1.0: continue
            var light := smoothstep(-0.5,0.45,noise.get_noise_2d(x,y*1.8))
            var pigment := Color("#746237").lerp(Color("#bfa65e"),light)
            image.set_pixel(x,y,image.get_pixel(x,y).lerp(pigment,0.76*(1.0-smoothstep(0.76,1.0,edge))))
    for i in range(int(bed.get_area()/27.0)):
        var stem := Vector2i(rng.randi_range(area.position.x,area.end.x-1),rng.randi_range(area.position.y,area.end.y-1))
        if FieldGeometry.basin_radius(stem,bed) > 0.94: continue
        var height := rng.randi_range(3,8)
        var straw := image.get_pixelv(stem).lerp(Color("#dec886"),0.6)
        for j in range(height):
            image.set_pixelv(stem+Vector2i(j/3,-j),straw.darkened(0.27*(1.0-float(j)/height)))
        image.set_pixelv(stem+Vector2i(height/3,-height),Color("#aa8853"))

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

static func _mirror_sample(value:int,size:int)->int:
    var i:int=posmod(value,size*2)
    return i if i<size else size*2-1-i
