# hook: KPAD sampling callback, the `addi r0,r28,1` after the data format is stored
# (r28 = ring index, r29 = channel, r30 = the sample).
#
# If a GameCube pad answers on the SI port with the same number as the channel,
# its state is merged into the Wii Remote + Nunchuk sample the game was written
# for.  The SI hardware keeps the pad's answer in SIC<n>INBUFH/L (0xCD006404 +
# 12*n, +4): INBUFH [31] error, [23] a real pad's answer, [29:16] buttons,
# [15:8] stick X, [7:0] stick Y; INBUFL cstick X, cstick Y, L, R.
#
# This sample is what KPAD (and so the menus) sees: the control stick is the
# Nunchuk stick, and the buttons map to the Wii Remote buttons the menus use:
#
#   A  B            A  B
#   X  Y            1  2
#   Start           +
#   Z               -
#   L  R            Z  C
#   D-pad           D-pad
#   C stick         the pointer (only while it is moved)
#
# In a match the player is switched to the game's GameCube controls instead
# (gc_mode.s, gc_pad.s), which read the pad directly.
    .set    CHAN, 29
    .set    SMP, 30
#include gc_convert.s
    addi    0, 28, 1                    # displaced instruction
