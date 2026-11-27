"""Write Gunryak's original field arrangements as standard MIDI (no dependencies)."""
from pathlib import Path
from struct import pack

# D minor, with a D-major final cadence for the victory. Each pair is a bass
# note and the melody for that measure; dots sustain the previous note.
PIECES = {
    "road": (92, 24, [("D", "adfa"), ("B", "g.f."), ("F", "ace."), ("C", "g.e."), ("G", "dbg."), ("B", "f.d."), ("A", "eca."), ("D", "d...")]),
    "night": (58, 16, [("D", "a..."), ("G", "g.d."), ("B", "f..."), ("F", "c.a."), ("G", "b..."), ("D", "a.f."), ("A", "e..."), ("D", "d...")]),
    "contact": (112, 32, [("D", "dafg"), ("F", "ac.a"), ("G", "bgdg"), ("A", "e.a."), ("B", "dfga"), ("G", "bd.g"), ("A", "echa"), ("D", "d.a.")]),
    "peril": (96, 16, [("D", "d.ed"), ("E", "f.e."), ("B", "d.fd"), ("A", "h.a."), ("G", "d.b."), ("B", "f.ed"), ("A", "h.e."), ("A", "a...")]),
    "homecoming": (86, 8, [("D", "d.fa"), ("B", "b.ad"), ("F", "c.a."), ("G", "g.b."), ("B", "f.ga"), ("A", "e.h."), ("M", "x.a."), ("M", "d...")]),
    "ashes": (55, 8, [("D", "a..."), ("B", "f.ed"), ("G", "g..."), ("D", "f.d."), ("B", "d..."), ("G", "b.g."), ("A", "e.h."), ("D", "d...")]),
}
# Bass, fifth, third. Upper-case M is the Picardy third.
CHORDS = dict(D=(38,45,53), B=(34,41,50), F=(41,48,57), C=(36,43,52),
              G=(31,38,46), A=(33,40,49), E=(40,46,55), M=(38,45,54))
NOTES = dict(a=69, b=70, c=72, d=74, e=76, f=77, g=67, h=73, x=78)
# Two melodic voices, cello, then plucked or bowed inner voice. GM programs.
VOICES = dict(road=(68,41,42,46), night=(73,41,42,46), contact=(41,60,42,48),
              peril=(70,41,42,48), homecoming=(60,73,42,46), ashes=(42,68,43,48))

def variable(value):
    digits = [value & 127]
    value >>= 7
    while value:
        digits.insert(0, 128 | (value & 127))
        value >>= 7
    return bytes(digits)

def write_score(name, out):
    tempo, bars, phrase = PIECES[name]
    events = []
    def event(beat, *data):
        events.append((round(480*beat), bytes(data)))
    def note(channel, at, pitch, length, strength):
        event(at, 144+channel, pitch, strength)
        event(at+length, 128+channel, pitch, 0)
    for i, pg in enumerate(VOICES[name]):
        event(0, 192+i, pg)
        event(0, 176+i, 10, (73,45,54,77)[i])
        event(0, 176+i, 91, 35)
    for bar in range(bars):
        root, theme = phrase[bar % len(phrase)]
        bass, fifth, third = CHORDS[root]
        beat = bar*4
        section = bar//8
        lead = section % 2 if bars>8 else int(bar in (2,3))
        accents = [65,57,61,54]
        if name in ("homecoming","ashes") and bar==7:
            lead = 0
        for idx, pitch in enumerate(theme):
            if pitch==".": continue
            end = idx+1
            while end<4 and theme[end]==".": end+=1
            reg = -12 if VOICES[name][lead] in (41,42,60,70) else 0
            strength = accents[idx]+(8 if name=="contact" else -5 if name=="night" else 0)
            note(lead, beat+idx+0.016, NOTES[pitch]+reg, end-idx-0.11, strength)
        if name in ("contact","peril"):
            rhythm = (0,0.75,1.5,2,3.0,3.5) if name=="contact" else (0,1.5,2.5)
            for j,t in enumerate(rhythm):
                note(2, beat+t, (bass,fifth,bass+12,fifth)[j%4], 0.39 if name=="contact" else 0.68, 68-j%3*7)
            note(3,beat+0.04,third+12,1.82,51)
            note(3,beat+2.04,fifth+12,1.78,46)
        elif name in ("night","ashes"):
            note(2,beat,bass,3.77,47)
            note(3,beat+.12,third+12,2.6,40)
            if bar%2==0: note(3,beat+2.54,fifth+12,1.29,38)
        else:
            note(2,beat,bass,1.63,63)
            note(2,beat+2,fifth,1.60,53)
            for j,pitch in enumerate((bass+12,third,fifth+12,third+12)):
                note(3,beat+j+.048,pitch,.86,47+(j==0)*5)
        if section%2 or bar%4==2:
            note(1-lead,beat+.09,third+(12 if lead==1 else 0),2.68,47)
        if section>=2 and bar%2==0:
            note(1-lead,beat+3,fifth+12,.78,55)
    track = bytearray(b'\x00\xff\x51\x03' + round(60_000_000/tempo).to_bytes(3,'big'))
    track.extend(b'\x00\xff\x58\x04\x04\x02\x18\x08')
    last = 0
    for tick,data in sorted(events,key=lambda v:v[0]):
        track.extend(variable(tick-last)+data)
        last=tick
    track.extend(variable(480*4*bars-last)+b'\xff\x2f\x00')
    (out/(name+'.mid')).write_bytes(b'MThd'+pack('>IHHH',6,0,1,480)+b'MTrk'+pack('>I',len(track))+track)

if __name__=='__main__':
    for piece in PIECES: write_score(piece, Path(__file__).resolve().parent)
