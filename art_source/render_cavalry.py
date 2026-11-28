"""Bake original mounted lancers into an orthographic sprite sheet. Pillow + NumPy."""
from math import cos, sin, pi
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

CELL = 56
ANGLES = (0, pi/4, pi/2, -pi/4, -pi/2)
COATS = ("#94694e", "#847567")
FACTIONS = ("#3e6376", "#954f48")
MANE, HOOF, LEATHER = "#443b34", "#463f3a", "#5b4435"
ARMOR, STEEL, BRASS = "#646f73", "#b7bbb0", "#aa916a"


class Model:
    def __init__(self):
        self.faces = []
        self.colors = []

    def rings(self, rings, color):
        rgb = tuple(bytes.fromhex(color[1:]))
        for a, b in zip(rings, rings[1:]):
            for i in range(len(a)):
                j = (i+1) % len(a)
                self.faces.append([a[i], a[j], b[j], b[i]])
                self.colors.append(rgb)

    def loft(self, sections, color):
        # Cross sections run from tail to nose. Each has a width and a height.
        rings = []
        for x, y, z, width, height in sections:
            rings.append([(x, y+width*cos(i*pi/4), z+height*sin(i*pi/4)) for i in range(8)])
        self.rings(rings, color)

    def limb(self, joints, color):
        rings = []
        for x, y, z, length, width in joints:
            rings.append([(x+length*cos(i*pi/4), y+width*sin(i*pi/4), z) for i in range(8)])
        self.rings(rings, color)

    def rod(self, start, end, radius, color):
        a, b = np.array(start), np.array(end)
        axis = (b-a)/np.linalg.norm(b-a)
        ref = [0, 1, 0] if abs(axis[1]) < .9 else [0, 0, 1]
        u = np.cross(axis, ref)
        u *= radius/np.linalg.norm(u)
        v = np.cross(axis, u)
        self.rings([[p+u*cos(i*pi/2)+v*sin(i*pi/2) for i in range(4)] for p in (a,b)], color)


def mount(pose, coat, cloth):
    m = Model()
    phase = (pose-1)*pi/2
    trotting = 1 <= pose <= 4
    nod = .6*cos(phase) if trotting else (-.9 if pose==6 else 0)
    # Barrel, flank, chest and a rising neck with a narrower throatlatch.
    m.loft([(-12,0,15,.3,1),(-10,0,16,3.9,4.1),(-7,0,16.5,5.2,5.6),
            (-3,0,16.7,4.7,4.8),(2,0,16.6,4.8,5),(6,0,17.2,4.5,5.7),
            (9,0,17.8,2.8,4.2),(10,0,18,1,2)],coat)
    m.limb([(6,0,17,4.1,3.6),(8,0,21,3.8,3),(9.5,0,24+nod,3,2.3),
            (12,0,26+nod,2.2,1.8)],coat)
    m.loft([(9.7,0,26+nod,.6,1.5),(12,0,26.3+nod,2.2,2.7),
            (14.2,0,25+nod,1.9,2.1),(17.4,0,23.1+nod,1.45,1.3),(18,0,23+nod,.8,.85)],coat)
    m.loft([(16.6,0,23.4+nod,1.35,1.35),(17.9,0,23.1+nod,1.45,1.22),(18.4,0,23.1+nod,.8,.8)],MANE)
    m.limb([(5,0,21.2,1.5,1.5),(6.6,0,24+nod,1.45,1.3),(9.9,0,27.3+nod,1.4,1.1),(11.6,0,28+nod,1,.8)],MANE)
    for side in (-1,1):
        m.limb([(11.7,side*1.25,27.5+nod,1,.65),(11.5,side*1.55,30.7+nod,.16,.12)],coat)
        m.rod((12.8,side*2.1,26+nod),(16.4,side*1.48,23.7+nod),.43,LEATHER)
        m.rod((13,side*2.15,26.25+nod),(13.55,side*2.07,26.3+nod),.36,HOOF)
        for fore in (False,True):
            hip = 6.8 if fore else -7.7
            t = phase + (pi if (side==1)==fore else 0)
            reach = 4.0*cos(t) if trotting else side*(1.8 if fore else 1.45)
            lift = max(0,sin(t))*3.4 if trotting else 0
            knee = hip+(1.1 if fore else 2.6)+reach*.55
            hock = hip+(.1 if fore else -1.5)+reach*.8
            hoof = hip+reach
            y = side*2.85
            m.limb([(hip,y,16.3,3 if not fore else 2,1.75),(knee,y,10.1+lift*.4,1.65,1.25),
                    (hock,y,6.0+lift,1.05,.74),(hoof-.65,y,2.7+lift,.67,.6),
                    (hoof+.35,y,1.45+lift,.92,.74)],coat)
            m.limb([(hoof+.35,y,1.65+lift,1.05,.83),(hoof+.7,y,.55+lift,1.27,.93)],HOOF)
    swish = cos(phase)*1.4 if trotting else 0
    m.limb([(-10.7,0,18.4,1.9,1.35),(-12.8,0,16.6,2,1.6),(-13.5,swish,11.2,1.75,1.35),
            (-15,swish,7.5,1.25,.9),(-16,swish,6,.18,.2)],MANE)
    # Dyed saddle blanket and leather saddle over the barrel.
    m.limb([(-.8,0,16.8,5.2,5.15),(-1,0,17.7,5.35,5.2)],BRASS)
    m.limb([(-1,0,17.5,5.45,5.28),(-1,0,20.2,5.5,4.7),(-1,0,21.75,4.7,2.8)],cloth)
    m.loft([(-4.1,0,21.2,2.8,1.4),(-1.4,0,21.7,3,1.1),(2.4,0,22.2,2.7,1.45)],LEATHER)
    lean = {5:-1.1,6:2.3,7:1,8:-1.6}.get(pose,0)
    x = -1+lean
    for side in (-1,1):
        m.limb([(-1,side*2.2,22.5,2.1,1.65),(1.1,side*4.1,19.6,1.65,1.22),
                (-.3,side*4.7,17.6,1.25,1.05)],cloth)
        m.limb([(-.3,side*4.7,18.2,1.3,1),(-1,side*4.75,14.9,.9,1),(0,side*4.75,14.4,1.8,.94)],HOOF)
    m.limb([(-1,0,21.2,3.3,3.1),(-1,0,23.5,2.7,2.7),(x,0,25.6,2.2,2.55),
            (x,0,28.4,2.15,3.05),(x+.25,0,29.9,1.55,2.2)],ARMOR)
    m.limb([(-1,0,23.1,2.86,2.95),(-1,0,24.1,2.68,2.82)],LEATHER)
    m.limb([(x,0,29.5,1.25,1.5),(x+.35,0,32.1,2.02,1.87),(x,0,33.1,1.7,1.6)],"#b48d6a")
    m.limb([(x-.5,0,31.1,1.8,1.96),(x-.1,0,32.6,2.4,2.3),(x,0,34.5,1.65,1.65),(x,0,35.3,.45,.48)],ARMOR)
    m.limb([(x,0,32.5,2.5,2.38),(x,0,33.05,2.43,2.33)],"#92958a")
    m.loft([(x-3.7,0,34,.28,.55),(x-1.4,0,35.45,.7,.84),(x+.25,0,35.2,.55,.78)],cloth)
    for side in (-1,1):
        shoulder=(x,side*2.8,28.5)
        elbow=(x-.65,side*3.5,25.8)
        hand=(x+2.5+(2 if pose==6 else 0),side*3.65,26.5)
        m.rod(shoulder,elbow,1.48,cloth)
        m.rod(elbow,hand,1.05,ARMOR)
        m.rod(hand,(hand[0]+.7,hand[1],hand[2]),.86,"#b48d6a")
        if side==-1:
            m.rod(hand,(9,side*2.5,23.1+nod),.32,LEATHER)
            m.rod((9,side*2.5,23.1+nod),(16.4,side*1.5,23.6+nod),.32,LEATHER)
        elif coat==COATS[1]:
            tip = (hand[0]+(10 if pose==6 else 4.5),hand[1],hand[2]+(3 if pose==6 else 9))
            m.rod(hand,tip,.78,STEEL)
            m.rod((hand[0]-.8,hand[1],hand[2]+.9),(hand[0]+1.3,hand[1],hand[2]),.65,BRASS)
        else:
            slope = {5:.62,6:.04,7:.35}.get(pose,1.4)
            dx = 18/(1+slope*slope)**.5
            shaft = np.array([dx,.1,dx*slope])
            hand = np.array(hand)
            m.rod(hand-shaft*.54,hand+shaft*.85,.48,"#937854")
            m.rod(hand+shaft*.85,hand+shaft, .7,STEEL)
    return m


def render(model, angle):
    v = np.asarray(model.faces)
    x,y,z = v.transpose(2,0,1)
    horizontal, depth = x*cos(angle)-y*sin(angle), x*sin(angle)+y*cos(angle)
    screen_y = .48*depth-.88*z
    depth = .88*depth+.48*z
    projected = np.stack((horizontal+27.5,screen_y+47),axis=-1)
    normals = np.cross(v[:,1]-v[:,0],v[:,2]-v[:,0])
    normals /= np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-9)
    view_dir = np.array([.88*sin(angle),.88*cos(angle),.48])
    normals *= np.where(normals@view_dir<0,-1,1)[:,None]
    light = np.array([-.42*cos(angle)+.23*sin(angle), .42*sin(angle)+.23*cos(angle), .87])
    shades = .73+.40*np.maximum(0,normals@light)
    colors = np.asarray(np.clip(np.asarray(model.colors)*shades[:,None],0,255),dtype=np.uint8)
    im = Image.new("RGBA",(CELL*2,CELL*2))
    draw = ImageDraw.Draw(im)
    polygons = np.rint(projected*2).astype(int).tolist()
    for i in depth.mean(axis=1).argsort(kind="stable"):
        draw.polygon([tuple(p) for p in polygons[i]], fill=tuple(colors[i]))
    return im.resize((CELL,CELL),Image.Resampling.BOX)


def main():
    atlas = Image.new("RGBA",(CELL*len(ANGLES)*9,CELL*4))
    for side, cloth in enumerate(FACTIONS):
        for coat_id, coat in enumerate(COATS):
            for pose in range(9):
                model = mount(pose,coat,cloth)
                for column, angle in enumerate(ANGLES):
                    atlas.paste(render(model,angle),((pose*5+column)*CELL,(side*2+coat_id)*CELL))
    atlas.save(Path(__file__).resolve().parents[1]/"assets/art/mounted_lancers.png",optimize=True)


if __name__=="__main__":
    main()
