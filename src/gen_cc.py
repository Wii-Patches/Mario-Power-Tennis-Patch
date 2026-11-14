"""Build the Classic Controller feature for one region (src/cc_*.s, src/pointer.s)."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_common as g
from layout import CC_BASE, CC_END
from ops import Feature

USA_DOL = None

# the displaced `bl`, as an absolute call so the routine works wherever a code handler puts it
CALL = '    lis     12, IR_CALL@ha\n    addi    12, 12, IR_CALL@l\n    mtctr   12\n    bctrl\n'


def build(region, dol):
    g.USA_DOL = USA_DOL
    at, w = g.sites(region, dol)
    consts = dict(g.WM, **g.CC)
    ops, cur = [], CC_BASE
    h, size = g.hook(at['stb'], w['stb'], cur, g.read('cc_sample.s'), {}, consts,
                     'KPAD sampling callback: Classic Controller sample -> Wii Remote + Nunchuk sample')
    ops.append(h)
    cur += size
    target = g.decode_branch(w['bl'], at['bl'])
    h, size = g.hook(at['bl'], w['bl'], cur, g.pointer_source(1, CALL), {'IR_CALL': target}, consts,
                     'KPAD read loop: pointer from the right stick')
    ops.append(h)
    cur += size
    ex, ew = g.cc_extra_sites(region, dol)
    h, size = g.hook(ex['kpad_ret'], ew['kpad_ret'], cur, g.read('cc_mode.s'), {'PROBE': ex['probe']}, consts,
                     'getKPADStatus: a player with a Classic Controller gets the original GameCube controls')
    ops.append(h)
    cur += size
    if cur > CC_END:
        raise SystemExit('cc code overflows its window: 0x%X > 0x%X' % (cur, CC_END))
    return Feature('cc', 'Classic Controller', region, ops)
