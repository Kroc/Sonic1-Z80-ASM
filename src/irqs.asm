.INC    "inc/vars.asm"

.SECTION    "!rst_reset"                                                ;$0000
;===============================================================================
rst_reset:                                                              ;$0000
;===============================================================================
        di                              ; disable interrupts
        im      1                       ; set the interrupt mode to 1 --
                                        ; $0038 will be called at 50/60Hz

@wait:  ; wait for the scanline to reach 176 (no idea why)
        in      A,      [SMS_PORTS_SCANLINE]
        cp      176
        jr      nz,     @wait

        jp      init
        ;
.ENDS

.SECTION    "!rst_playMusic"                                            ;$0018
;===============================================================================
rst_playMusic:                                                          ;$0018
;===============================================================================
; in    A       music ID
;-------------------------------------------------------------------------------
        jp      call_playMusic
        ;
.ENDS

.SECTION    "!rst_muteSound"                                            ;$0020
;===============================================================================
rst_muteSound:                                                          ;$0020
;===============================================================================
        jp      call_muteSound
        ;
.ENDS

.SECTION    "!rst_playSFX"                                              ;$0028
;===============================================================================
rst_playSFX:                                                            ;$0028
;===============================================================================
; in    A       sfx ID
;-------------------------------------------------------------------------------
        jp      call_playSFX
        ;
.ENDS

.SECTION    "!irq"                                                      ;$0038
;===============================================================================
irq:                                                                    ;$0038
;===============================================================================
; Every 1/50th (PAL) or 1/60th (NTSC) of a second, an interrupt is generated
; and control passes here. there's only a small amount of space between this
; routine and the pause handler, so we just jump to the routine proper
;-------------------------------------------------------------------------------
        jp      interruptHandler
        ;
.ENDS

.SECTION    "!nmi_pause"                                                ;$0066
;===============================================================================
nmi_pause:                                                              ;$0066
;===============================================================================
; pressing the PAUSE button causes an interrupt and jumps to $0066.
;
; in    IY      address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        di      ; disable interrupts
        push    AF

        ; level time HUD / lightning flags
        ld      A,      [IY+Vars.timeLightningFlags]
        ; flip bit 3 (the pause bit)
        xor     %00001000
        ; save it back
        ld      [IY+Vars.timeLightningFlags],   A

        pop     AF
        ei      ; enable interrupts

        ret
        ;
.ENDS
