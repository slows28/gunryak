extends RefCounted
## Cached procedural battle Foley. The samples never affect simulation or damage.
static func build() -> Dictionary:
    var sounds: Dictionary={}
    for kind in ["근접","화살","돌격"]:
        var rng:=RandomNumberGenerator.new()
        rng.seed=173 if kind=="근접" else (281 if kind=="화살" else 912)
        var rate: int=22050
        var duration: float=0.46 if kind=="돌격" else (0.30 if kind=="화살" else 0.34)
        var count: int=roundi(duration*rate)
        var data:=PackedByteArray()
        data.resize(count*2)
        var low: float=0.0
        for i in range(count):
            var t: float=float(i)/rate
            var noise: float=rng.randf_range(-1.0,1.0)
            low=lerpf(low,noise,0.11)
            var high: float=noise-low
            var waveform: float=0.0
            match kind:
                "근접":
                    # Short metal transient plus decaying irregular resonances.
                    var ring: float=sin(TAU*713.0*t)+0.6*sin(TAU*1119.0*t)+0.32*sin(TAU*1643.0*t)
                    waveform=high*exp(-t*65.0)*0.52+ring*exp(-t*19.0)*0.27+low*exp(-t*27.0)*0.18
                "화살":
                    var release: float=sin(TAU*(165.0*t-58.0*t*t))*exp(-t*30.0)*0.30
                    var sweep: float=sin(PI*clampf(t/duration,0.0,1.0))
                    waveform=release+high*sweep*exp(-t*5.0)*0.56
                _:
                    # Staggered low hoof impacts and contact, not a UI beep.
                    for strike in range(4):
                        var d: float=t-float(strike)*0.072
                        if d<0.0: continue
                        waveform+=(sin(TAU*(82.0*d-26.0*d*d))*0.35+low*0.48+high*0.10)*exp(-d*36.0)
            var envelope: float=minf(1.0,t*220.0)*minf(1.0,(duration-t)*55.0)
            data.encode_s16(i*2,roundi(clampf(waveform*envelope*24000.0,-32767.0,32767.0)))
        var wav:=AudioStreamWAV.new()
        wav.format=AudioStreamWAV.FORMAT_16_BITS
        wav.mix_rate=rate
        wav.data=data
        sounds[kind]=wav
    return sounds
