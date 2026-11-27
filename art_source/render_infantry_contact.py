"""Build the close-contact poses using the helmet, armour and shield of the field sprites."""
import math
from copy import deepcopy
from pathlib import Path
import xml.etree.ElementTree as ET

ART = Path(__file__).resolve().parents[1] / "assets" / "art"
SVG = "http://www.w3.org/2000/svg"
XLINK = "http://www.w3.org/1999/xlink"
ET.register_namespace("", SVG)
ET.register_namespace("xlink", XLINK)


def element(parent, tag, **attributes):
    return ET.SubElement(parent, f"{{{SVG}}}{tag}", attributes)


def use(parent, key, transform):
    element(parent, "use", **{f"{{{XLINK}}}href": f"#{key}", "transform": transform})


def path(parent, shape, fill, stroke="#302923", width="1.8"):
    element(parent, "path", d=shape, fill=fill, stroke=stroke, **{
        "stroke-width": width, "stroke-linecap": "round", "stroke-linejoin": "round"})


# Skeleton keys are in atlas pixels. Both soles share the original ground anchor.
# torso x/y/rotation, back and front boot x, shield x/y/rotation, hand x/y, spear angle
SIDE = [
    (-4, 5, -12, 22, 63, 49, 45, -14, 51, 46, -32),  # gather
    ( 8, 9,  23, 13, 75, 65, 46, -31, 75, 49, -12),  # thrust
    ( 3,13,  16, 21, 70, 67, 40, -18, 52, 55, -41),  # shield under load
    (-9,10, -27, 13, 61, 48, 37, -42, 50, 47, -60),  # catch a step
    ( 5, 6,  15, 27, 68, 61, 44, -24, 64, 48, -22),  # fill
    (-1, 3,  -4, 26, 60, 48, 49,  -8, 53, 48, -32),  # recover
]


def spear(group, hand, tip):
    hx, hy = hand
    tx, ty = tip
    length = math.hypot(tx-hx, ty-hy)
    ux, uy = (tx-hx)/length, (ty-hy)/length
    path(group, f"M{hx-ux*21:.1f} {hy-uy*21:.1f} L{tx:.1f} {ty:.1f}", "none", "#523d2c", "3.2")
    bx, by = tx-ux*10, ty-uy*10
    path(group, f"M{tx:.1f} {ty:.1f} L{bx-uy*2.5:.1f} {by+ux*2.5:.1f} "
                f"L{bx-ux*3:.1f} {by-uy*3:.1f} L{bx+uy*2:.1f} {by-ux*2:.1f}Z",
         "#e0d6b8", "#524c42", "1")


def draw_pose(tile, side, facing, pose):
    dx, dy, angle, back, front, sx, sy, shield_angle, hx, hy, aim = SIDE[pose]
    key = f"{side}-{facing}"
    if facing:
        dx *= 0.45
        angle *= 0.45
        back = 26 + (back-26)*0.57
        front = 61 + (front-61)*0.55
        sx = (29 if facing==1 else 23) + (sx-48)*0.38
        sy += 3 if facing==1 else -1
    # Rear sole digs in, lead knee bends over a separately planted boot.
    hip = 47+dx*0.55
    path(tile, f"M{hip-11} {61+dy} L{hip-5} {66+dy} L{back+6} 83 L{back+4} 87 "
               f"L{back-6} 87 L{back-5} 82 L{hip-17} {69+dy}Z", "#453e36")
    path(tile, f"M{hip+3} {60+dy} Q{front+9} {54+dy} {front+3} 76 L{front+1} 82 "
               f"L{front+7} 85 L{front+6} 88 L{front-6} 87 L{front-7} 81 "
               f"L{front-6} {69+dy/2} L{hip-1} {73+dy/2}Z", "#514534")
    body = f"translate({dx} {dy}) rotate({angle} 47 61)"
    use(tile, f"body{key}", body)
    if facing:
        hx=59+dx
        hy=52+dy/2
        tx=hx+(17 if pose==1 else 10)
        ty=hy+(30 if pose in [1,4] else 11) if facing==1 else hy-(45 if pose==1 else 42)
    else:
        rad=math.radians(aim)
        reach=34 if pose==1 else 39
        tx,ty=hx+math.cos(rad)*reach, hy+math.sin(rad)*reach
    if facing==2: spear(tile,(hx,hy),(tx,ty))
    shoulder_x, shoulder_y=57+dx,40+dy
    path(tile, f"M{shoulder_x} {shoulder_y} Q{hx-12} {hy+5} {hx} {hy}", "none", "#352d27","8")
    path(tile, f"M{shoulder_x} {shoulder_y} Q{hx-12} {hy+5} {hx} {hy}", "none", "#b9976d","4.5")
    if facing!=2: spear(tile,(hx,hy),(tx,ty))
    use(tile, f"shield{key}", f"translate({sx} {sy}) rotate({shield_angle}) translate(-28 -50)")


def build():
    source=ET.parse(ART/"soldier_motion.svg").getroot()
    sheet=ET.Element(f"{{{SVG}}}svg", width="2304", height="192", viewBox="0 0 2304 192")
    defs=deepcopy(source[0])
    sheet.append(defs)
    for side in range(2):
        for facing in range(3):
            # First stride frame for this faction and facing. The face and
            # shield shapes vary between side, front and rear views.
            original=source[1+side*54+facing*6]
            key=f"{side}-{facing}"
            shield_start=len(original)-3 if facing==2 else len(original)-5
            body=element(defs,"g",id=f"body{key}")
            for idx in [0,*range(3,13),*range(14,shield_start)]:
                body.append(deepcopy(original[idx]))
            shield=element(defs,"g",id=f"shield{key}")
            for shape in list(original)[shield_start:-2]: shield.append(deepcopy(shape))
            for pose in range(len(SIDE)):
                x=(pose*3+facing)*128
                tile=element(sheet,"g",transform=f"translate({x+16} {side*96})")
                draw_pose(tile,side,facing,pose)
    ET.indent(sheet)
    ET.ElementTree(sheet).write(ART/"infantry_contact.svg",encoding="utf-8",xml_declaration=True)


if __name__=="__main__":
    build()
