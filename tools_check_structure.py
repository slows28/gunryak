"""Static project/scene/source reference checks (does NOT execute Godot).
Run with: python tools_check_structure.py from the project root.
"""
from pathlib import Path
import re
from collections import Counter
ROOT = Path(__file__).resolve().parent


def check(condition: bool, description: str):
    if not condition:
        raise AssertionError(description)
    print('PASS:',description)


def balanced(source: str, label: str):
    # String/comment aware delimiter check; not a GDScript syntax parser.
    stack = []
    quote = None
    escaped = False
    comment = False
    matches = {')':'(', ']':'[', '}':'{'}
    for n, ch in enumerate(source):
        if ch == '\n':
            comment = False
        if comment:
            continue
        if quote:
            if escaped:
                escaped=False
            elif ch=='\\':
                escaped=True
            elif ch==quote:
                quote=None
            continue
        if ch=='#':
            comment=True
            continue
        if ch in ('"',"'"):
            quote=ch
        elif ch in '([{':
            stack.append((ch,n))
        elif ch in ')]}':
            if not stack or stack[-1][0]!=matches[ch]:
                raise AssertionError(f'{label}: unmatched bracket near index {n}')
            stack.pop()
    check(not stack and not quote,f'{label}: balanced delimiters and strings')


def run():
    files=[p for p in ROOT.rglob('*') if p.is_file()]
    check((ROOT/'project.godot').exists(),'Godot project file exists')
    check((ROOT/'main.tscn').exists(),'main scene exists')
    check((ROOT/'scripts'/'war_sim.gd').exists(),'war simulation code exists')
    check((ROOT/'tests'/'smoke.gd').exists(),'headless test suite exists')
    check(not any('.godot' in f.relative_to(ROOT).parts for f in files),'Godot generated cache not packaged')
    for f in files:
        if f.suffix not in ('.gd','.tscn','.godot'):
            continue
        source=f.read_text('utf-8')
        if f.suffix=='.gd':
            balanced(source,f.relative_to(ROOT).as_posix())
            funcs=re.findall(r'^func\s+(\w+)\s*\(',source,re.M)
            dup=[name for name,n in Counter(funcs).items() if n>1]
            check(not dup,f'{f.name}: no duplicate functions')
        refs=re.findall(r'(?:(?:res):\/\/)([\w./-]+\.(?:gd|tscn|svg))',source)
        for ref in refs:
            check((ROOT/ref).is_file(),f'{f.name} resource reference {ref}')
    p=(ROOT/'project.godot').read_text('utf8')
    check('gl_compatibility' in p,'GL compatibility renderer configured')
    check('d3d12' not in p.lower(),'no hard-coded D3D12 renderer')
    sim=(ROOT/'scripts'/'war_sim.gd').read_text('utf8')
    for needle in ('func validate_state()', 'func _nearest_visible_enemy(', 'func _formation_transition(', 'func _update_couriers(', 'func _supply_logic('):
        check(needle in sim,f'model feature: {needle}')
    print('GUNRYAK_STATIC_PASS - no Godot interpreter was run')

if __name__=='__main__': run()
