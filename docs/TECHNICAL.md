# Technical notes

How the two patches work, where they hook, and how one set of data becomes a
patched `main.dol`, a Gecko code list and a Riivolution patch. For installing
and playing, see the [README](../README.md).

Addresses below are the **USA** `main.dol` (`RMAE01`) unless noted; the table at
the end lists the other releases.

## One data set, three outputs

Every patch is a list of operations on one release's `main.dol`:

| Operation | Static (`main.dol`) | Gecko | Riivolution |
| --- | --- | --- | --- |
| **Hook**: replace one instruction with a branch to a routine that runs the displaced instruction and branches back | branch + trampoline in the injected section | `C2` code | `<memory>` (branch + trampoline) |

`tools/prebuilt/<feature>_<disc id>.json` holds those operations, including the
retail instruction expected at every site. `tools/ops.py` turns them into each
format, `tools/patcher.py` applies them (and refuses a `main.dol` whose sites do
not match, so already-modified or foreign dumps are never touched), and
`tools/build.py` writes `codes/` and `riivolution/`. `tools/check.py` fails if
the committed files drift from the data; `tools/verify.py` checks the data
against real retail DOLs for every combination of patches.

**Hooks are self-contained.** A routine carries everything it needs and reaches
game code through absolute addresses (`lis`/`addi`/`mtctr`/`bctrl`), never a
relative `bl`. `tools/check.py` rejects any relative branch that leaves its
routine. Routines hold no variables of their own; the static build parks them in
one new text section at `0x80001820` (the Wii's boot-time scratch area; the
game's own code starts at `0x80004000` and nothing in the retail DOLs addresses
`0x80001800-0x80003000`). The patched disc is the supported install: the Gecko
code lists clash with the code handler Dolphin and USB loaders put at
`0x80001800`.

## The key fact: the GameCube controls are still in the game

New Play Control! Mario Power Tennis is the GameCube game with Wii Remote
controls added on top, and the GameCube control path was never removed:

- Every frame the game's controller update (`0x8000D4A0`) fills four
  `PADStatus` records, the structure `PADRead` returns on a GameCube. It fills
  them from the Wii Remotes instead: A, B, 1, 2, + and − become pad buttons, and
  the Nunchuk stick (or the D-pad) becomes the control stick. Then it calls
  `PADClamp` and turns the records into the game's controller data
  (`stPadData`), exactly as the GameCube game did.
- The match code, in the dynamically loaded `rso/tennis.rso` module, decides
  every frame how each player is controlled:
  `mode = (KPADStatus.dev_type == Nunchuk) + 1`, which gives 1 (Wii Remote) or
  2 (Wii Remote + Nunchuk). Both places that compute it
  (`GAMECONTROL::inputProcess` and `PLAYER::checkRemoconPlayer`; `tennis.rso`
  exports its symbols) read the status through `getKPADStatus` (`0x800361B0`).
- **Mode 0 is the original GameCube controls.** The player then runs the
  GameCube game's own movement and shot code, which reads `stPadData`. In the
  Wii release mode 0 is unreachable, because the formula never yields 0.

So the patches do not imitate swings. They get the real controller into
`PADStatus` and switch the player to mode 0, and from then on the game plays like
the GameCube original. Every shot type, the Power Shots, lunges and dives are
handled by Camelot's own code.

## GameCube controller (`gc`)

| Routine | Site | Job |
| --- | --- | --- |
| `gc_pad.s` | `addi r3,r1,8` before `bl PADClamp` (`0x8000E228`) | For each SI port with a pad, overwrite that channel's `PADStatus` with the pad itself: every button, both sticks, both analog triggers |
| `gc_mode.s` | `getKPADStatus` entry (`0x800361B0`) | If the caller is one of the two mode computations and a pad answers on the channel's SI port, return past them with mode 0 |
| `gc_sample.s` + `gc_convert.s` | KPAD sampling callback, `addi r0,r28,1` (`0x800A6888`) | Rewrite the sample into a Wii Remote + Nunchuk sample, so the menus (which only read KPAD) work with the pad |
| `gc_synth.s` | KPAD read, `lbz r0,0x10f(r31)` (`0x800A5EC4`) | With no Wii Remote nothing fills the KPAD ring: make the sample from the pad here, and fire the connect callback once |
| `gc_probe.s` | `WPADProbe` entry (`0x800990B8`) | Report the channel as "connected, Nunchuk" while a pad answers |
| `gc_info.s` | `WPADGetInfo` entry (`0x80099378`) | Answer at once for a pad-only channel. `WPADGetInfo` asks the remote for its status and sleeps until it answers; the game calls it when a match starts, so without this the game hangs on the way into every match |
| `pointer.s` | KPAD read loop, the `b` after the IR call (`0x800A647C`) | While the C stick is moved, put the pointer where it points |

The pad is read straight from the SI hardware (`SIC<n>INBUFH/L` at
`0xCD006404 + 12*n`). The game links the GameCube `PAD` library and calls
`PADInit` at boot, which turns SI polling on, so no poller is needed. Channel
*n* is driven by GameCube port *n*+1.

## Classic Controller (`cc`)

| Routine | Site | Job |
| --- | --- | --- |
| `cc_sample.s` | KPAD sampling callback, `stb r3,0x36(r30)` (`0x800A6884`) | Rewrite a Classic Controller sample into a Wii Remote + Nunchuk sample. The buttons are chosen so that the game's own Wii Remote → `PADStatus` conversion produces the GameCube buttons (table in the source) |
| `cc_mode.s` | `getKPADStatus`'s `blr` (`0x800361C4`) | If the caller is a mode computation and `WPADProbe` reports a Classic Controller on the channel, return past it with mode 0 |
| `pointer.s` | KPAD read loop, the IR call (`0x800A6478`) | While the right stick is moved, put the pointer where it points |

The two features never hook the same instruction (the GameCube mode hook sits on
`getKPADStatus`'s first instruction, the Classic one on its last), so either can
be applied alone or both together.

## Testing

`lab/` has the Dolphin harness: a private user folder per run, a GameCube pad
or a Wii Remote on Dolphin's named-pipe input, frame dumps, and memory reads
over Dolphin's GDB stub. Dolphin answers a break with `T05`, an empty packet and
`T05` again, so a client has to drain all three before it sends commands.
`tennis.rso` loads at a different address on each boot; find it by searching
RAM for a known function's bytes.

Verified in Dolphin: with only a GameCube pad and no Wii Remote, the game boots,
the menus work, a match starts, and the player moves, serves and returns with the
GameCube controls. The same works with a Classic Controller. Not yet tested on a
console.

## Sites by release

| Hook | USA (`RMAE01`) | Europe (`RMAP01`) | Japan (`RMAJ01`) | Displaced instruction |
| --- | --- | --- | --- | --- |
| CC sample | `0x800A6884` | `0x800A6884` | `0x800A4E50` | `stb r3,0x36(r30)` |
| CC pointer | `0x800A6478` | `0x800A6478` | `0x800A4A44` | `bl <ir>` |
| CC mode | `0x800361C4` | `0x800361C4` | `0x80035A20` | `blr` |
| GC sample | `0x800A6888` | `0x800A6888` | `0x800A4E54` | `addi r0,r28,1` |
| GC pointer | `0x800A647C` | `0x800A647C` | `0x800A4A48` | `b <loop_end>` |
| GC synth | `0x800A5EC4` | `0x800A5EC4` | `0x800A4490` | `lbz r0,0x10f(r31)` |
| GC probe | `0x800990B8` | `0x800990B8` | `0x80097668` | `stwu r1,-0x10(r1)` |
| GC info | `0x80099378` | `0x80099378` | `0x80097928` | `stwu r1,-0x10(r1)` |
| GC mode | `0x800361B0` | `0x800361B0` | `0x80035A0C` | `clrlwi r0,r3,30` |
| GC pad | `0x8000E228` | `0x8000E228` | `0x8000DF0C` | `addi r3,r1,8` |
