# hook: getKPADStatus(chan), its final `blr` (r3 = the status, r0 = chan * 0x84).
#
# Same idea as gc_mode.s: the match code in tennis.rso picks how each player is
# controlled from the status this returns,
#     mode = (status->dev_type == Nunchuk) + 1        1 = Wii Remote, 2 = + Nunchuk
# and mode 0, the original GameCube controls, is unreachable in the Wii release.
# A Classic Controller is rewritten into a Nunchuk sample (cc_sample.s), so the game
# turns its buttons and left stick into GameCube pad data on its own; what is left is
# to give that player mode 0.  When the caller is one of the two mode computations
#     lbz r3,0x5c(r3) ; addi r0,r3,-1 ; cntlzw r0,r0 ; srwi r3,r0,5 ; addi rD,r3,1
# and WPADProbe says a Classic Controller is attached to the channel, return past
# the five instructions with rD = 0.  Scratch: everything volatile (it is a return).
    mflr    12
    lwz     11, 0(12)
    lis     10, 0x8863
    ori     10, 10, 0x005C              # lbz r3,0x5c(r3)
    cmpw    11, 10
    bne     9f
    lwz     11, 4(12)
    lis     10, 0x3803
    ori     10, 10, 0xFFFF              # addi r0,r3,-1
    cmpw    11, 10
    bne     9f
    lwz     11, 8(12)
    lis     10, 0x7C00
    ori     10, 10, 0x0034              # cntlzw r0,r0
    cmpw    11, 10
    bne     9f
    lwz     11, 12(12)
    lis     10, 0x5403
    ori     10, 10, 0xD97E              # srwi r3,r0,5
    cmpw    11, 10
    bne     9f
    lwz     11, 16(12)
    li      9, 0
    lis     10, 0x3803
    ori     10, 10, 0x0001              # addi r0,r3,1
    cmpw    11, 10
    beq     1f
    li      9, 3
    lis     10, 0x3863
    ori     10, 10, 0x0001              # addi r3,r3,1
    cmpw    11, 10
    bne     9f
1:  stwu    1, -0x20(1)
    stw     12, 0x08(1)                 # the caller's return address
    stw     3, 0x0c(1)                  # the status
    stw     9, 0x10(1)                  # which register gets the mode
    li      11, 0x84
    divwu   3, 0, 11                    # the channel
    addi    4, 1, 0x14
    li      0, 0
    stw     0, 0x14(1)
    lis     12, PROBE@ha
    addi    12, 12, PROBE@l
    mtctr   12
    bctrl                               # WPADProbe(chan, &type)
    lwz     12, 0x08(1)
    cmpwi   3, 0
    bne     2f                          # no controller
    lwz     0, 0x14(1)
    cmpwi   0, 2
    bne     2f                          # not a Classic Controller
    lwz     9, 0x10(1)
    addi    1, 1, 0x20
    addi    12, 12, 20
    mtlr    12                          # return past the mode computation
    cmpwi   9, 0
    li      3, 0
    bnelr                               # rD = r3
    li      0, 0
    blr                                 # rD = r0
2:  lwz     3, 0x0c(1)
    addi    1, 1, 0x20
    mtlr    12
9:  blr                                 # displaced instruction
