# hook: getKPADStatus(chan), the first instruction (`clrlwi r0,r3,30`).
#
# The match code (in the tennis.rso module) decides every frame how each player is
# controlled, from the KPAD status this returns:
#     mode = (status->dev_type == Nunchuk) + 1        1 = Wii Remote, 2 = + Nunchuk
# Mode 0 is the original GameCube control path -- the player is driven by the
# controller data built from PADStatus (see gc_pad.s) -- and is unreachable in the
# Wii release.  Both places that compute the mode follow the call with the same five
# instructions:
#     lbz  r3,0x5c(r3) ; addi r0,r3,-1 ; cntlzw r0,r0 ; srwi r3,r0,5 ; addi rD,r3,1
# (rD = r0 in GAMECONTROL::inputProcess, r3 in PLAYER::checkRemoconPlayer).  When the
# caller is one of those and a GameCube pad answers on the channel's SI port, return
# straight past the five instructions with rD = 0: that player gets the GameCube
# controls.  The module is loaded at a different address every time, so the caller
# is recognised by its instructions, not by an address.
    mflr    12
    lwz     11, 0(12)
    lis     10, 0x8863
    ori     10, 10, 0x005C              # lbz r3,0x5c(r3)
    cmpw    11, 10
    bne     orig
    lwz     11, 4(12)
    lis     10, 0x3803
    ori     10, 10, 0xFFFF              # addi r0,r3,-1
    cmpw    11, 10
    bne     orig
    lwz     11, 8(12)
    lis     10, 0x7C00
    ori     10, 10, 0x0034              # cntlzw r0,r0
    cmpw    11, 10
    bne     orig
    lwz     11, 12(12)
    lis     10, 0x5403
    ori     10, 10, 0xD97E              # srwi r3,r0,5
    cmpw    11, 10
    bne     orig
    lwz     11, 16(12)
    li      9, 0
    lis     10, 0x3803
    ori     10, 10, 0x0001              # addi r0,r3,1
    cmpw    11, 10
    beq     check
    li      9, 3
    lis     10, 0x3863
    ori     10, 10, 0x0001              # addi r3,r3,1
    cmpw    11, 10
    bne     orig
check:
    clrlwi  5, 3, 30
    mulli   5, 5, 12
    lis     6, 0xCD00
    add     6, 6, 5
    lwz     7, 0x6404(6)                # SIC<n>INBUFH
    cmpwi   7, 0
    blt     orig                        # error / no pad
    andis.  0, 7, 0x0080
    beq     orig                        # not a pad answer
    addi    12, 12, 20
    mtlr    12                          # return past the mode computation
    cmpwi   9, 0
    li      3, 0
    bnelr                               # rD = r3
    li      0, 0
    blr                                 # rD = r0
orig:
    clrlwi  0, 3, 30                    # displaced instruction
