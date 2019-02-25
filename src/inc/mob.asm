
.STRUCT Mob
;===============================================================================
; The data-structure for a mob (Movable Object Block);
; the game's interactive objects and enemies.
;     
        type                    DB      ; object type index number      ;IX+$00
        Xsubpixel               DB      ; sub-pixel X position          ;IX+$01
        X                       DW      ; X position (px)               ;IX+$02
        Ysubpixel               DB      ; sub-pixel Y position          ;IX+$04
        Y                       DW      ; Y position (px)               'IX+$05
        Xspeed                  DW      ; - in px, signed               ;IX+$07
        Xdirection              DB      ; $FF for left, else $00        ;IX+$09
        Yspeed                  DW      ; - in px, signed               ;IX+$0A
        Ydirection              DB      ; $FF for up, else $00          ;IX+$0C
        width                   DB      ; - in px                       ;IX+$0D
        height                  DB      ; - in px                       ;IX+$0E
        spriteLayout            DW      ; address of sprite layout      ;IX+$0F
        unknown11               DB    
        unknown12               DB    
        unknown13               DB    
        unknown14               DB    
        unknown15               DB    
        unknown16               DB    
        unknown17               DB    
        flags                   DB      ; various mob flags
        ;-----------------------------------------------------------------------
        ;unknown0               
        ;unknown1               
        ;unknown2               
        ;unknown3               
        ;underwater                     ;4 - underwater flag
        ;noCollision                    ;5 - mob adheres to the floor or not
        ;unknown6               
        ;unknown7               
        ;
        unknown19               DB      ;unused?
.ENDST