"""Shared pieces of the Classic Controller and GameCube controller builders.

Both patches rewrite the controller into the Wii Remote + Nunchuk sample KPAD
expects (so the menus work), and in matches switch the player to the game's
dormant GameCube control mode, which reads the GameCube pad data the port still
builds every frame.  See docs/TECHNICAL.md.
"""
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import asm
from ops import Hook
from sig import find_unique

SAMPLE_STB = 0x800A6884          # stb r3,0x36(r30)   data format stored
SAMPLE_ADDI = 0x800A6888         # addi r0,r28,1      next instruction
POINTER_BL = 0x800A6478          # bl <per-sample IR/geometry>
POINTER_B = 0x800A647C           # b  <end of the sample's iteration>

PROBE_ENTRY = 0x800990B8         # WPADProbe, first instruction (stwu r1,-0x10(r1))
RING_COUNT = 0x800A5EC4          # lbz r0,0x10f(r31)  KPAD read: samples waiting in the ring
GETINFO_ENTRY = 0x80099378       # WPADGetInfo, first instruction (stwu r1,-0x10(r1))
GETKPAD_ENTRY = 0x800361B0       # getKPADStatus, first instruction (clrlwi r0,r3,30)
PADCLAMP_ARG = 0x8000E228        # addi r3,r1,8   just before the per-frame bl PADClamp

USA_DOL = None

# Wii Remote / Nunchuk button bits (WPAD)
WM = dict(WM_LEFT=0x0001, WM_RIGHT=0x0002, WM_DOWN=0x0004, WM_UP=0x0008, WM_PLUS=0x0010,
          WM_2=0x0100, WM_1=0x0200, WM_B=0x0400, WM_A=0x0800, WM_MINUS=0x1000,
          WM_Z=0x2000, WM_C=0x4000, WM_HOME=0x8000)
# Classic Controller button bits (WPAD)
CC = dict(CC_UP=0x0001, CC_LEFT=0x0002, CC_ZR=0x0004, CC_X=0x0008, CC_A=0x0010, CC_Y=0x0020,
          CC_B=0x0040, CC_ZL=0x0080, CC_R=0x0200, CC_PLUS=0x0400, CC_HOME=0x0800,
          CC_MINUS=0x1000, CC_L=0x2000, CC_DOWN=0x4000, CC_RIGHT=0x8000)
# GameCube pad button bits (PAD)
PAD = dict(PAD_LEFT=0x0001, PAD_RIGHT=0x0002, PAD_DOWN=0x0004, PAD_UP=0x0008, PAD_Z=0x0010,
           PAD_R=0x0020, PAD_L=0x0040, PAD_A=0x0100, PAD_B=0x0200, PAD_X=0x0400, PAD_Y=0x0800,
           PAD_START=0x1000)

# pointer scale: screen units per 1/1000th of stick travel
PTR_X = 0.00055
PTR_Y = -0.00060


def read(name):
    out = []
    for line in open(os.path.join(HERE, name)).read().split('\n'):
        out.append(read(line.split()[1]) if line.startswith('#include ') else line)
    return '\n'.join(out)


def decode_branch(word, at):
    li = word & 0x03FFFFFC
    if li & 0x02000000:
        li -= 0x04000000
    return (at + li) & 0xFFFFFFFF


def sites(region, dol):
    usa = USA_DOL if region != 'RMAE01' else dol
    out = {}
    for key, (addr, before, after) in dict(stb=(SAMPLE_STB, 12, 6), addi=(SAMPLE_ADDI, 12, 6),
                                           bl=(POINTER_BL, 12, 6), b=(POINTER_B, 12, 6)).items():
        out[key] = addr if region == 'RMAE01' else find_unique(usa, dol, addr, before, after)
    w = {k: struct.unpack('>I', dol.read(a, 4))[0] for k, a in out.items()}
    if w['stb'] != 0x987E0036 or w['addi'] != 0x381C0001:
        raise SystemExit('%s: sample hook sites are 0x%08X 0x%08X' % (region, w['stb'], w['addi']))
    if (w['bl'] >> 26) != 18 or not w['bl'] & 1 or (w['b'] >> 26) != 18 or w['b'] & 1:
        raise SystemExit('%s: pointer hook sites are not bl / b' % region)
    return out, w


def pointer_source(marker, prologue='', epilogue=''):
    return (prologue + read('pointer.s').replace('MARKER', str(marker)).replace('PTR_X', repr(PTR_X)).replace(
        'PTR_Y', repr(PTR_Y)) + epilogue)


def hook(site, orig, base, source, syms, consts, note):
    words = asm.words(asm.assemble(read('macros.s') + source, base, syms, consts)) + [0]
    return Hook(site, orig, words, base, note=note), (len(words) * 4 + 15) & ~15


def gc_extra_sites(region, dol):
    """Sites only the GameCube patch needs (it also works without a Wii Remote)."""
    usa = USA_DOL if region != 'RMAE01' else dol
    out = {}
    for key, (addr, before, after) in dict(probe=(PROBE_ENTRY, 0, 14), ring=(RING_COUNT, 12, 6),
                                           info=(GETINFO_ENTRY, 0, 24),
                                           pad=(PADCLAMP_ARG, 16, 8)).items():
        out[key] = addr if region == 'RMAE01' else find_unique(usa, dol, addr, before, after)
    out['kpad'] = find_getkpad(dol)
    w = {k: struct.unpack('>I', dol.read(a, 4))[0] for k, a in out.items()}
    want = dict(probe=0x9421FFF0, ring=0x881F010F, info=0x9421FFF0, kpad=0x546007BE, pad=0x38610008)
    for k, v in want.items():
        if w[k] != v:
            raise SystemExit('%s: %s site is 0x%08X, expected 0x%08X' % (region, k, w[k], v))
    return out, w


def wpad_control_blocks(dol, getinfo):
    """The address of WPAD's per-channel control block pointer table, from the
    `lis r3,hi ; ... ; addi r3,r3,lo` pair WPADGetInfo uses to load it."""
    lis, addi = (struct.unpack('>I', dol.read(getinfo + o, 4))[0] for o in (0x2c, 0x34))
    if lis >> 16 != 0x3C60 or addi >> 16 != 0x3863:
        raise SystemExit('WPADGetInfo does not load the control block table where expected')
    lo = addi & 0xFFFF
    return ((lis & 0xFFFF) << 16) + (lo - 0x10000 if lo & 0x8000 else lo)


def find_getkpad(dol):
    """getKPADStatus(chan): `clrlwi r0,r3,30 ; lis r3,hi ; mulli r0,r0,0x84 ; addi r3,r3,lo ;
    add r3,r3,r0 ; blr`.  getKPADStatusRep has the same shape and follows it directly, so
    the first of two back-to-back matches is the one."""
    hits = []
    for off, base, size, idx in dol.secs:
        if idx >= 7:
            continue
        t = bytes(dol.data[off:off + size])
        for i in range(0, size - 24, 4):
            w = struct.unpack('>6I', t[i:i + 24])
            if (w[0] == 0x546007BE and w[1] >> 16 == 0x3C60 and w[2] == 0x1C000084 and w[3] >> 16 == 0x3863
                    and w[4] == 0x7C630214 and w[5] == 0x4E800020):
                hits.append(base + i)
    pairs = [a for a in hits if a + 0x18 in hits]
    if len(pairs) != 1:
        raise SystemExit('getKPADStatus: %d candidates' % len(pairs))
    return pairs[0]


def cc_extra_sites(region, dol):
    """Sites only the Classic Controller patch needs."""
    usa = USA_DOL if region != 'RMAE01' else dol
    kpad = find_getkpad(dol)
    probe = PROBE_ENTRY if region == 'RMAE01' else find_unique(usa, dol, PROBE_ENTRY, 0, 14)
    words = struct.unpack('>6I', dol.read(kpad, 24))
    if words[0] != 0x546007BE or words[2] != 0x1C000084 or words[4] != 0x7C630214 or words[5] != 0x4E800020:
        raise SystemExit('%s: getKPADStatus is not where expected' % region)
    return dict(kpad_ret=kpad + 20, probe=probe), dict(kpad_ret=words[5])
