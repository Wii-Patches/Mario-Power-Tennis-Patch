# hook: the game's per-frame controller update, the `addi r3,r1,8` that sets up the
# call to PADClamp (r1+8 = PADStatus[4]).
#
# The GameCube game read its controllers with PADRead; this port fills the same four
# PADStatus records from the Wii Remotes instead (KPAD buttons and Nunchuk stick),
# clamps them and turns them into the game's controller data (stPadData) that the
# original GameCube control code still reads.  For every SI port with a GameCube pad
# plugged in, overwrite that channel's record with the pad itself -- every button,
# both sticks and both analog triggers -- exactly as PADRead would have.
#
# SI<n>INBUFH: [31] error, [23] origin (set in every pad answer), [28:16] PAD buttons
# in PADStatus order, [15:8] stick X, [7:0] stick Y; INBUFL: C stick X, C stick Y,
# analog L, analog R.  Scratch: r0, r7-r12 (PADClamp is called right after).
    li      11, 0
    addi    10, 1, 8                    # PADStatus[0]
    lis     9, 0xCD00
1:  lwz     7, 0x6404(9)                # INBUFH
    cmpwi   7, 0
    blt     2f                          # error / no pad
    andis.  0, 7, 0x0080
    beq     2f                          # not a pad answer
    lwz     8, 0x6408(9)                # INBUFL
    srwi    0, 7, 16
    andi.   0, 0, 0x1F7F
    sth     0, 0(10)                    # button
    rlwinm  12, 7, 24, 24, 31
    addi    12, 12, -128                # (not r0: as the base of addi it reads as zero)
    stb     12, 2(10)                   # stickX
    rlwinm  12, 7, 0, 24, 31
    addi    12, 12, -128
    stb     12, 3(10)                   # stickY
    rlwinm  12, 8, 8, 24, 31
    addi    12, 12, -128
    stb     12, 4(10)                   # substickX
    rlwinm  12, 8, 16, 24, 31
    addi    12, 12, -128
    stb     12, 5(10)                   # substickY
    rlwinm  0, 8, 24, 24, 31
    stb     0, 6(10)                    # triggerL
    rlwinm  0, 8, 0, 24, 31
    stb     0, 7(10)                    # triggerR
    li      0, 0
    stb     0, 8(10)                    # analogA
    stb     0, 9(10)                    # analogB
    stb     0, 10(10)                   # err: PAD_ERR_NONE
2:  addi    11, 11, 1
    addi    10, 10, 12
    addi    9, 9, 12
    cmpwi   11, 4
    blt     1b
    addi    3, 1, 8                     # displaced instruction
