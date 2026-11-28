"""Bake the foot and bow ranks with the mounted atlas camera and palette."""
from math import cos, sin, pi
from pathlib import Path
import numpy as np
from PIL import Image
from render_cavalry import ANGLES, ARMOR, BRASS, CELL, FACTIONS, HOOF, LEATHER, STEEL, Model, render

SKIN = "#bc9975"
WOOD = "#987952"


def bow_kit(m, pose, chest, lean):
    # The grip rises before the draw. The nock reaches the cheek on the
    # draw frame and leaves with the actual volley in the game.
    shooting = pose in (5,6,7,8)
    reach = {5:5.8,6:8,7:8,8:5.5}.get(pose,3.1)
    z = chest+{5:1.8,6:3.3,7:3.2,8:.7}.get(pose,-4)
    grip = (lean+reach,-2.9,z)
    hand = (lean+{5:2.4,6:-.8,7:-2.6,8:.9}.get(pose,1.5),.3,z+.4)
    # Recurved wood, a visible open inside curve and a single taut string.
    upper, lower = [], []
    for sign,nodes in ((1,upper),(-1,lower)):
        for rise,shift in ((0,0),(3.2,1.6),(7.4,-1.6),(9.8,-4.8),(10.8,-4.1)):
            x = grip[0]+shift + (0 if shooting else sign*rise*.44)
            nodes.append((x,grip[1],z+sign*rise))
        for a,b in zip(nodes,nodes[1:]): m.rod(a,b,.83,WOOD)
    nock = (hand[0],grip[1],hand[2]) if pose==6 else (upper[-1][0],grip[1],z)
    for tip in (upper[-1],lower[-1]): m.rod(tip,nock,.24,"#ae9e83")
    if pose==6: m.rod(nock,(grip[0]+4,grip[1],z),.38,"#ba9e75")
    m.rod((-3.5,1.8,12),(-3.8,3.2,25.3),1.6,LEATHER)
    for offset in (-.7,.6):
        m.rod((-3.8+offset,3.2,24.8),(-4.2+offset,3.8,28.4),.42,WOOD)
    return grip,hand


def infantry_kit(m, pose, chest, lean, cloth):
    # Shield stays in the front hand during the thrust; recovery and recoil
    # pull it across the torso. The spear and shield have separate arms.
    engaged = pose>=5
    raised = pose in (5,7,8,10)
    grip = (lean+(3.4 if raised else 2.2),-3.1,chest-2+(1 if raised else 0))
    center = np.array(grip)+[1.35,0,0]
    normal = np.array([.77,.64,0])
    across = np.array([-.64,.77,0])
    rim = [(-1.8,6),(2,6),(4.2,3.6),(4,-2.6),(2,-5.1),(0,-6.6),(-2,-5.1),(-4,-2.6),(-4.2,3.6)]
    def face(scale, depth):
        return [center+across*(w*scale)+[0,0,h*scale]+normal*depth for w,h in rim]
    shield = "#795b44" if cloth==FACTIONS[0] else "#774d3a"
    m.rings([face(.94,-.65),face(1,0),face(.89,.55)],BRASS)
    m.rings([face(.89,.55),face(.32,1.15),face(.03,1.3)],shield)
    m.rod(center+normal*1.22+[0,0,-4.8],center+normal*1.22+[0,0,4.8],.5,BRASS)
    hand = (lean+{5:-1.9,6:5.4,7:0,8:-.9,9:2.8,10:.6}.get(pose,1.5),3.3,chest-1.4)
    shaft = np.array([17.7,.9,1.2 if pose==6 else 4.5]) if engaged else np.array([6.2,.4,17.7])
    hand = np.array(hand)
    m.rod(hand-shaft*.65,hand+shaft*.87,.54,WOOD)
    m.rod(hand+shaft*.87,hand+shaft*1.10,.82,STEEL)
    return grip,hand


def fighter(pose, archer, cloth):
    m = Model()
    walking = 1<=pose<=4
    phase = (pose-1)*pi/2
    ready = pose>=5
    lean = {5:-.6,6:1.8,7:.4,8:-1.8,9:1.1,10:0}.get(pose,0) if not archer else (.65 if ready else 0)
    crouch = (1.1 if ready else 0) + (.5*abs(sin(phase)) if walking else 0)
    hip, chest = 12.3-crouch,22.2-crouch
    for side in (-1,1):
        step = side*(3.4*cos(phase) if walking else (2.3 if ready else 1.3))
        lift = max(0,side*sin(phase))*1.9 if walking else 0
        knee = step*.63 + (1.7 if ready else .9)
        m.limb([(0,side*1.45,hip+1,2,1.6),(knee,side*1.7,6.9+lift,1.5,1.23),
                (step-.3,side*1.8,2.8+lift,.95,1.0)],cloth)
        m.limb([(step,side*1.8,4.6+lift,1.18,1.12),(step,side*1.8,1.5+lift,1.12,1.2),
                (step+.8,side*1.8,.7+lift,1.87,1.2)],HOOF)
    # Split coat and a fitted lamellar cuirass. Archers wear a shorter
    # unarmoured jacket and a cloth head wrap, visible behind the bow.
    m.limb([(-.5,0,hip-2.2,2.95,3.1),(0,0,hip+.8,2.65,3.1),(lean,0,chest,2.15,3.3)],cloth)
    if not archer:
        m.limb([(0,0,hip-.7,3.05,3.38),(0,0,hip+2.0,2.9,3.15),(lean,0,chest-.8,2.6,3.6),(lean,0,chest+1.1,2,2.8)],ARMOR)
        for dz in (3.2,5.7):
            m.limb([(lean*.5,0,hip+dz,2.78,3.31),(lean*.5,0,hip+dz+.35,2.78,3.31)],"#787e77")
    m.limb([(0,0,hip+.8,2.98,3.19),(0,0,hip+1.85,2.91,3.2)],LEATHER)
    m.limb([(lean,0,chest+.2,1.25,1.65),(lean+.55,0,chest+2.0,2.0,1.9),
            (lean+.35,0,chest+5.1,2.2,2.15),(lean,0,chest+6.0,1.9,1.8)],SKIN)
    if archer:
        m.limb([(lean-.4,0,chest+4,2.25,2.1),(lean,0,chest+5.5,2.45,2.3),
                (lean-.2,0,chest+6.4,1.7,1.7)],cloth)
        m.limb([(lean-.9,0,chest+6.1,1.25,1.15),(lean-1.1,0,chest+7.3,.7,.75)],HOOF)
        left,right = bow_kit(m,pose,chest,lean)
    else:
        m.limb([(lean-.85,0,chest+2.9,1.8,2.1),(lean,0,chest+4.9,2.6,2.5),
                (lean,0,chest+6.6,2.05,2),(lean,0,chest+7.8,.6,.6)],ARMOR)
        m.limb([(lean,0,chest+4.9,2.7,2.58),(lean,0,chest+5.5,2.55,2.51)],"#96998b")
        left,right = infantry_kit(m,pose,chest,lean,cloth)
    for side, hand in ((-1,left),(1,right)):
        hand = np.array(hand)
        shoulder = np.array([lean,side*2.85,chest-.3])
        elbow = (hand+shoulder)*.5+np.array([-.7,1.9*side,-1.7])
        m.rod(shoulder,elbow,1.55,cloth)
        m.rod(elbow,hand,1.02,LEATHER)
        m.rod(hand,hand+np.array([.65,0,.4]),.86,SKIN)
    return m


def main():
    atlas = Image.new("RGBA",(CELL*len(ANGLES)*11,CELL*4))
    for side,cloth in enumerate(FACTIONS):
        for kind in range(2):
            for frame in range(11):
                actor = fighter(frame,kind==1,cloth)
                for col,angle in enumerate(ANGLES):
                    atlas.paste(render(actor,angle),((frame*5+col)*CELL,(side*2+kind)*CELL))
    atlas.save(Path(__file__).resolve().parents[1]/"assets/art/foot_troops.png",optimize=True)


if __name__=="__main__":
    main()
