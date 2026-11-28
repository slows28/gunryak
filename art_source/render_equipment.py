"""Paint the little bronze inventory seals on a 32 px grid."""
from pathlib import Path
from PIL import Image, ImageDraw

S = 4
UNIT = 32
GOLD, LIGHT, WOOD, JADE = "#c9a15c", "#f1d89d", "#874b39", "#84a498"
canvas = Image.new("RGBA", (8*UNIT*S, UNIT*S))
for tile in range(8):
    im = Image.new("RGBA", (UNIT*S, UNIT*S))
    d = ImageDraw.Draw(im)
    def pts(coords):
        return [(x*S, y*S) for x,y in coords]
    def poly(coords,fill):
        d.polygon(pts(coords),fill)
    def line(coords,fill,width=1):
        d.line(pts(coords),fill,width=int(S*width),joint="curve")
    def oval(x,y,w,h,fill):
        d.ellipse((x*S,y*S,(x+w)*S,(y+h)*S),fill)
    poly([(5,1),(26,1),(30,5),(30,26),(26,30),(5,30),(1,26),(1,5)],GOLD)
    poly([(5,3),(26,3),(28,5),(28,26),(26,28),(5,28),(3,26),(3,5)],"#273b3b")
    if tile == 0:  # blade and tassel
        line([(7,26),(23,7)],WOOD,2.5)
        poly([(13,17),(18,9),(25,5),(23,11),(15,19)],LIGHT)
        line([(10,16),(17,21)],GOLD,2)
        line([(9,22),(5,21),(6,25)],"#b85c41",2)
    elif tile == 1:  # lamellar coat
        poly([(9,7),(13,6),(16,10),(19,6),(23,7),(26,13),(22,15),(22,24),(16,27),(10,24),(10,15),(6,13)],JADE)
        for y in (12,16,20,24):
            line([(11,y-1),(16,y+1),(21,y-1)],GOLD)
        line([(16,10),(16,23)],LIGHT)
    elif tile == 2:  # saddled horse
        poly([(6,25),(9,21),(11,14),(16,8),(20,8),(20,4),(23,7),(24,5),(24,12),(26,16),(23,19),(18,16),(17,22),(19,25)],LIGHT)
        line([(8,20),(10,13),(15,8),(19,6)],GOLD,2)
        line([(19,13),(24,15),(22,19)],WOOD)
        oval(20,11,2,2,"#1c292a")
    elif tile == 3:  # drum, rope and two beaters
        poly([(6,13),(24,13),(23,22),(18,25),(10,24),(7,21)],WOOD)
        oval(6,9,19,8,GOLD)
        oval(8,10,15,4,LIGHT)
        line([(7,16),(11,22),(14,17),(18,23),(23,16)],GOLD)
        line([(9,5),(19,10)],LIGHT,1.5)
    elif tile == 4:  # bow and arrow
        line([(7,6),(15,8),(20,12),(23,18),(24,25)],GOLD,2)
        line([(7,6),(24,25)],JADE)
        line([(7,24),(23,7)],LIGHT)
        poly([(19,7),(25,5),(23,11)],LIGHT)
    elif tile == 5:  # bamboo book
        for i in range(6):
            x=6+i*3
            y=9-(i//3)
            poly([(x,y),(x+2,y-1),(x+2,y+14),(x,y+15)],LIGHT if i%2 else GOLD)
        for y in (12,19): line([(6,y+1),(23,y-1)],WOOD)
    elif tile == 6:  # unit standard
        line([(10,26),(10,5)],GOLD,2)
        poly([(11,6),(24,7),(22,13),(24,16),(11,17)],WOOD)
        line([(13,8),(20,9),(19,13),(13,14),(13,8)],LIGHT)
    else:  # officer's seal
        oval(11,7,10,8,GOLD)
        poly([(9,13),(21,12),(25,17),(15,21),(6,18)],LIGHT)
        poly([(6,18),(15,21),(25,17),(25,22),(15,26),(6,22)],WOOD)
    canvas.alpha_composite(im,(tile*UNIT*S,0))
path = Path(__file__).resolve().parents[1] / "assets/art/equipment_seals.png"
canvas.resize((8*UNIT,UNIT),Image.Resampling.LANCZOS).save(path)
