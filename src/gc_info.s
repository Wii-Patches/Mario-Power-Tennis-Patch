# hook: WPADGetInfo, the first instruction (r3 = channel, r4 = the WPADInfo to fill).
# WPADGetInfo asks the remote for its status and sleeps until the answer arrives.
# When the GameCube pad stands in for a controller that is not there (the probe hook
# reports it as connected), no answer ever comes and the calling thread would sleep
# forever -- the game asks at the start of every match.  So if the channel has no
# Wii Remote (WPAD's status for it is -1) and a GameCube pad answers on the matching
# SI port, fill in a plausible WPADInfo (attachment present, full battery) and return
# 0 (success) straight away.
    cmplwi  3, 3
    bgt     orig
    lis     12, WPAD_CB@ha
    addi    12, 12, WPAD_CB@l
    slwi    0, 3, 2
    lwzx    12, 12, 0                   # the channel's WPAD control block
    lwz     0, 0x8bc(12)
    cmpwi   0, -1
    bne     orig                        # a remote is there: ask it
    mulli   5, 3, 12
    lis     6, 0xCD00
    add     6, 6, 5
    lwz     7, 0x6404(6)                # SIC<n>INBUFH
    cmpwi   7, 0
    blt     orig                        # error / no pad
    andis.  0, 7, 0x0080
    beq     orig                        # not a pad response
    cmpwi   4, 0
    beq     done
    li      0, 0
    stw     0, 0x00(4)                  # dpd
    stw     0, 0x04(4)                  # speaker
    stw     0, 0x0c(4)                  # lowBat
    stw     0, 0x10(4)                  # nearempty
    stw     0, 0x14(4)                  # battery, led
    li      0, 1
    stw     0, 0x08(4)                  # attach
    li      0, 4
    stb     0, 0x14(4)                  # battery level 4 (full)
done:
    li      3, 0
    blr
orig:
    stwu    1, -0x10(1)                 # displaced instruction
