# Mario Power Tennis Patch

Play **New Play Control! Mario Power Tennis** (Wii) with a **GameCube controller** — using
the controls of the original GameCube game — or with a **Classic Controller**
instead of the Wii Remote motion swings. Works with the USA (`RMAE01`), European
(`RMAP01`) and Japanese (`RMAJ01`) releases, and each patch is optional.

The patches are applied to your own copy of the game: drop a clean `.wbfs` or
`.iso` onto the patcher and play the result on a Wii (USB loader) or in
Dolphin. Nothing from the game is included in this repository.

![Mario Power Tennis](assets/logo.png)

## How it works, in one paragraph

The Wii version is the GameCube game with Wii Remote controls added on top, and
the GameCube controls are still inside it: every frame the game still builds
GameCube pad data, and the match code still has the GameCube control mode, which
the Wii release can never select. The patches put the real controller into that
pad data and switch your player to the GameCube mode. Shots, Power Shots, lunges
and dives are then handled by the game's own GameCube code, so it plays like the
original. The menus get the controller as a Wii Remote + Nunchuk. See
[docs/TECHNICAL.md](docs/TECHNICAL.md) for the details.

## Controls

In matches both controllers use the original GameCube game's controls.

### GameCube controller

| Input | Action |
| --- | --- |
| Control stick | Move · aim · menu navigation |
| A | Topspin · serve · confirm in menus |
| B | Slice · back in menus |
| A + B | Flat shot |
| A then B / B then A | Lob / drop shot |
| Other buttons | As in the GameCube game (Power Shots and the rest) |
| Start | Pause · start the match from the Shot Lesson |
| C stick | Menu pointer, while you move it |

### Classic Controller

The buttons arrive in the game as GameCube buttons:

| Classic Controller | GameCube button |
| --- | --- |
| Left stick, D-pad | Control stick |
| A, B | A, B |
| X, Y | Z |
| L, ZL | L |
| R, ZR | R |
| +, − | Start |
| Right stick | Menu pointer, while you move it |
| HOME | HOME Menu |

With a Classic Controller on a Wii U (vWii) injection, enable *Force Classic
Controller Connected*.

## Installing

### Patch your disc image

You need a clean `.wbfs` or `.iso` of the game. Run the patcher GUI
(needs Python 3 with tkinter and [Wiimms ISO Tool](https://wit.wiimm.de/) (`wit`) on your `PATH`):

```bash
python3 tools/gui.py
```

Tick the patches you want, then drop the image onto the window (or click to
choose it). The patcher checks the disc id, patches `sys/main.dol`, rebuilds the
image in the same format and replaces your file, keeping the original next to
it as `<name>.bak`.

There is a command-line twin:

```bash
python3 tools/patch_disc.py "Mario Power Tennis (USA) (En,Fr,Es).wbfs" --cc --gc
```

### Riivolution and Gecko codes

`riivolution/<disc id>.xml` is a Riivolution patch with one switch per feature,
generated from the same data; put it in your Riivolution folder (or Dolphin's
`Load/Riivolution`). `codes/` has the same patches as Gecko code lists, kept for
reference only: their routines go where Dolphin and USB loaders put their own
code handler, so they do not boot. Patching the disc is the recommended install.

### Which release do I have?

The disc id is the first six characters of the disc (`RMAE01` USA, `RMAP01`
Europe/Australia, `RMAJ01` Japan). `python3 tools/patch_disc.py` and the GUI read
it for you.

## Limits

- The GameCube controller works with **no Wii Remote connected at all**. GameCube
  port 1 is player 1 (port *n* is player *n*, but only port 1 has been tested).
- Without a Wii Remote there is no HOME button (the HOME Menu belongs to the
  remote) and no rumble.
- Plug the GameCube controller in **before** starting the game; hot-plugging is
  not handled.
- The menus are driven by the stick (and the pointer while the C stick / right
  stick moves); they cannot be navigated with the D-pad of the GameCube pad.
- The Classic Controller plugs into a Wii Remote, so that patch needs one.
- Tested in Dolphin with all three releases; not yet tested on a console.

## Repository layout

| Path | What |
| --- | --- |
| `src/` | the PowerPC routines (devkitPPC assembly) and the per-release builders |
| `tools/` | the patcher, GUI, Gecko / Riivolution generators and the checks |
| `tools/prebuilt/` | the patch data the patcher ships (generated from `src/`) |
| `codes/`, `riivolution/` | generated Gecko code lists and Riivolution patches |
| `lab/` | automated Dolphin test harness and GDB stub memory reader |
| `docs/TECHNICAL.md` | how the patches work |

Rebuilding the patch data from source needs devkitPPC and your own `main.dol`
dumps; end users need neither:

```bash
python3 tools/gen_prebuilt.py
python3 tools/build.py
python3 tools/check.py
python3 tools/verify.py
```

## License

MIT, see [LICENSE](LICENSE).

### Modded images

Disc patchers match the first four characters of the game ID (ID4), so mods can change the last two characters. The original disc ID and filename are preserved. Revision and executable patch-site checks still apply; mods that change required code may be incompatible.
