#import "../00.music/music1.asm"

.var spriteData = LoadBinary("./includes/Sprites.bin")
.const background = BLUE
.const finalPosition = $ff
.const maxYPos       = $30

.label screen    = $f400
.label firstByte = $f5c0
.label sprites   = $f5c0
.label code      = $f800

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

.label firstZP  = $10
.label jmpIrq     = $10
.label jmpIrqLow  = $11
.label jmpIrqHigh = $12
.label yPos       = $13
.label lastZP   = $13

#if AS_SPINDLE_PART
  .label spindleLoadAddress = firstByte
  *=spindleLoadAddress-18-4-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word 0             // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word cleanup       // cleanup routine
    .word music_play    // location of playroutine call

    .byte 'S'           // declare safe loading under IO
    .byte 'Z', <firstZP, <lastZP // declare used ZP adresses

    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2($080e); sei; lda #$35; sta $01; jmp start
#endif

* = code "[CODE] main"
start:
{
  sei

  #if AS_SPINDLE_PART
    lda $01
    sta restore01
  #endif
  lda #$35
  sta $01

  ldx nextpart
  inx
  stx irq.nextPartValue

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  #if !AS_SPINDLE_PART
    lda #$94
    sta $dd00

    // -----------------------------------------------------------------
    // copied from spindle earlysetup to get the same cia timers running
    // -----------------------------------------------------------------

    bit	$d011
    bmi	*-3

    bit	$d011
    bpl	*-3

    lda	#RTI
    sta	$ffff
    ldx	#$ff
    stx	$fffa
    stx	$fffb
    inx
    stx	$dd0e
    stx	$dd04
    stx	$dd05
    lda	#$81
    sta	$dd0d
    lda	#$19
    sta	$dd0e

    ldx	$d012
    inx
  resync:
    cpx	$d012
    bne	*-3
    // at cycle 4 or later
    ldy	#0		 // 4
    sty	$dc07	 // 6
    lda	#62		 // 10
    sta	$dc06	 // 12
    iny			   // 16
    sty	$d01a	 // 18
    dey			   // 22
    dey			   // 24
    sty	$dc02	 // 26
    nop 			 // 30
    nop 			 // 32
    nop 			 // 34
    nop 			 // 36
    nop 			 // 38
    nop 			 // 40
    nop 			 // 42
    nop 			 // 44
    nop	  		 // 46
    lda	#$11	 // 48
    sta	$dc0f  // 50
    txa			   // 54
    inx			   // 56
    inx			   // 58
    cmp	$d012	 // 60	still on the same line?
    bne	resync

    // ----------------------------------
    // cia timers should be running now..
    // ----------------------------------

    :MusicInitCall()
  #endif

  lda #$30  // $00 -> final position. 
            // $0c -> exactly on top of border in normal VICE display
            // $19 -> exactly on top of border in full VICE display
            // $1f -> completely hidden in normal VICE display
            // $2c -> completely hidden in full VICE display <---
            
  sta yPos

  lda #JMP_ABS
  sta jmpIrq
  lda #<irq
  sta jmpIrqLow
  lda #>irq
  sta jmpIrqHigh

  lda #<jmpIrq
  sta $fffe
  lda #>jmpIrq
  sta $ffff

  lda #$f7
  sta $d012

  lda $d011
  and #$7f
  sta $d011

  lda $dc0d
  lda $dd0d
  asl $d019

  ldx #(sprites&$3fc0)/64
  stx screen+$3f8
  inx
  stx screen+$3f9
  inx
  stx screen+$3fa
  inx
  stx screen+$3fb
  inx
  stx screen+$3ff
  inx
  stx screen+$3fe
  inx
  stx screen+$3fd
  inx
  stx screen+$3fc

  #if AS_SPINDLE_PART
    lda restore01: #0
    sta $01
  #endif

  cli
loop:
  #if !AS_SPINDLE_PART
    cmp ($00,x)
    jmp loop
  #else
    rts
  #endif
}

.var xco1 = $93
.var xco2 = $c3-4
.var xco3 = $f3-4-8
.var xco4 = $23-4-8-4

cleanup:
{
waitLoop:
  // wait for a good rasterline before exiting to the next part
  lda $d011
  bmi waitLoop

  // we might just be at the end of raster $ff and continu to check d012..
  // back to the waitloop is d012 is < $10, because this might just have occured!
  lda $d012
  cmp #$10
  bcc waitLoop

  // check $d011 again to be sure
  lda $d011
  bmi waitLoop

  // only continue in the region $10-$80
  lda $d012
  cmp #$80
  bcs waitLoop

  rts
}

setSprites1:
{
  lda #$ff
  sta $d015
  sta $d01d
  lda #$f0
  sta $d01c

  lda #$00
  sta $d017
  lda yPos
  sta $d001
  sta $d003
  sta $d005
  sta $d007
  sta $d009
  sta $d00b
  sta $d00d
  sta $d00f

  lda #$90
  sta $d000
  lda #$c0
  sta $d002
  lda #$f0
  sta $d004
  lda #$20
  sta $d006

  lda #xco1
  sta $d00e
  lda #xco2
  sta $d00c
  lda #xco3
  sta $d00a
  lda #xco4
  sta $d008

  lda #$18
  sta $d010

  rts
}

setSprites2:
{

  lda #RED
  sta $d027
  sta $d028
  sta $d029
  sta $d02a

  lda #YELLOW
  sta $d02b
  lda #YELLOW
  sta $d02c
  sta $d02d
  sta $d02e

  lda #$0a
  sta $d025
  lda #$0f
  sta $d026

  rts
}

.var exitPositions = List().add(rasterCode.exit0, rasterCode.exit1, rasterCode.exit2, rasterCode.exit3, rasterCode.exit4, rasterCode.exit5, rasterCode.exit6, rasterCode.exit7, 
                                rasterCode.exit8, rasterCode.exit9, rasterCode.exit10, rasterCode.exit11, rasterCode.exit12, rasterCode.exit13, rasterCode.exit14, rasterCode.exit15)
exitPos: .lohifill exitPositions.size(), exitPositions.get(i)

topIrq:
{
  sta atemp
  stx xtemp
  sty ytemp

  lda $01
  sta restore01

  lda #$35
  sta $01

  lda #0
  sta $d015

  lda #background
  sta $d021
  sta $d025
  sta $d026
  sta $d027
  sta $d028
  sta $d029
  sta $d02a
  sta $d02b
  sta $d02c
  sta $d02d
  sta $d02e

  lda nextPartValue: #0
  sta nextpart

  inc timelow
  bne !+
    inc timehigh
  !:

  :MusicPlayCall()

  lda #<irq
  sta jmpIrqLow
  lda #>irq
  sta jmpIrqHigh
  lda #$f7
  sta $d012

  lda $d011
  and #$7f
  ora #$08
  sta $d011

  asl $d019

  lda restore01: #0
  sta $01

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

irq:
{
  sta atemp
  stx xtemp

  lda $01
  sta restore01
  lda #$35
  sta $01

  jsr setSprites2

  lda $d011 // open border
  and #$f7
  sta $d011
 
  lda #$3f
  sta $dd02

  lda #(screen&$3c00)/$400*$10
  sta $d018

  lda #<shiftIrq
  sta jmpIrqLow
  lda #>shiftIrq
  sta jmpIrqHigh

  // ------------------------------
  // go to next step in animation -
  // ------------------------------

  inc step
  ldx step: #0
  lda bounceAnim,x
  cmp #$80
  bne !+
    lda nextPartValue: #0
    sta topIrq.nextPartValue
    dec step
    lda #finalPosition
  !: 
  sta yPos
  sta $d012
  asl
  
  // if yPos <  $100, carry is set
  // if yPos >= $100, carry is clear

  lda $d011
  and #$6f  // close screen
  bcs !+
    ora #$80
  !: sta $d011

  // restore NOP in rastercode
  // -------------------------

  ldx previousExit: #0
  lda exitPos.lo,x
  sta setNOP
  lda exitPos.hi,x
  sta setNOP+1

  lda #NOP
  sta setNOP: rasterCode.exit0

  // set rts in rastercode
  // ---------------------
  lda #maxYPos
  sec
  sbc yPos

  cmp #exitPositions.size()
  bcs skipRTS

  tax
  lda exitPos.lo,x
  sta setRTS
  lda exitPos.hi,x
  sta setRTS+1
  stx previousExit

  lda #RTS
  sta setRTS: rasterCode.exit0
skipRTS:

  jsr setSprites1

  asl $d019

  lda restore01: #0
  sta $01

  lda atemp: #0
  ldx xtemp: #0
  rti
}

.align $100
shiftIrq:
{
  // Jitter correction. Put earliest cycle in parenthesis.
  // (10 with no sprites, 19 with all sprites, ...)
  // Length of clockslide can be increased if more jitter
  // is expected, e.g. due to NMIs.

  dec 0
  sta atemp     // 15..23
  //lda $01
  //sta restore01

  // normally 9 cycles before we get here.. (dec 0, sta atemp)
  // but now jmp + 5 + 4 = 12 cycles.. = +3
  lda #39-(13)     // 19..27 <- (earliest cycle)
  sec              // 21..29
  sbc $dc06        // 23..31, A becomes 0..8
  //and #$07         // protection
  //sta *+4          // 27..35
  //bpl *+2          // 31..39

  sta *+6
  cmp #10
  bcc *+2

  lda #$a9         // 34
  lda #$a9         // 36
  lda #$a9         // 38
  lda $eaa5        // 40
                   // at cycle 34+(10) = 44

  stx xtemp
  sty ytemp

  nop

  jsr wait36
  jsr wait30
  dec $dbff
  bit $ea
  nop

  // leftmost sprite (d00e) 3,7,8,11,14,16
  // 2nd sprite             8,10,15
  // 3rd sprite             9,11,15,16
  // 4th sprite             3,7,8,11+2,13+2,15

  nop
  nop
  nop
  nop
  
  jsr rasterCode

  lda #<topIrq
  sta jmpIrqLow
  lda #>topIrq
  sta jmpIrqHigh
  lda #$37
  sta $d012

  lda $d011
  and #$7f
  ora #$88
  sta $d011

  asl $d019

  lda #0
  sta nextpart

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  inc 0
  rti
}

rasterCode:
{
  inc $dbff
  inc $dbff
  inc $dbff
  inc $dbff
  inc $dbff
  inc $dbff
  inc $dbff
exit0:  nop

  // row 3
  lda #xco1-2
  sta $d00e
  lda #xco4-2
  sta $d008
  inc $dbff
  inc $dbff
  inc $dbff
  inc $dbff
  dec $dbff
exit1:  nop

  // row 4
  lda #xco1
  sta $d00e
  lda #xco4
  sta $d008
  inc $dbff
  inc $dbff
  inc $dbff
  nop
  nop
  lda rasterbar+4
  sta $d021
exit2: nop

  // row 5
  inc $dbff
  dec $dbff
  inc $dbff
  inc $dbff
  inc $dbff
  nop
  nop
  lda rasterbar+5
  sta $d021
exit3: nop

  // row 6
  inc $dbff
  dec $dbff
  inc $dbff
  inc $dbff
  inc $dbff
  nop
  nop
  lda rasterbar+6
  sta $d021
exit4: nop

  // row 7
  lda #xco1-2
  sta $d00e
  lda #xco4-2
  sta $d008
  inc $dbff
  inc $dbff
  inc $dbff
  nop
  nop
  lda rasterbar+7
  sta $d021
exit5: nop

  // row 8
  lda #xco2-2
  sta $d00c
  inc $dbff
  inc $dbff
  inc $dbff
  inc $dbff
  nop
  nop
  lda rasterbar+8
  sta $d021
exit6: nop

  // row 9
  lda #xco1
  sta $d00e
  lda #xco2
  sta $d00c
  lda #xco3-2
  sta $d00a
  lda #xco4
  sta $d008
  inc $dbff
  nop
  nop
  lda rasterbar+9
  sta $d021
exit7: nop

  // row 10
  lda #xco2-2
  sta $d00c
  lda #xco3
  sta $d00a
  inc $dbff
  inc $dbff
  inc $dbff
  nop
  nop
  lda rasterbar+10
  sta $d021
exit8: nop

  // row 11
  lda #xco1-2
  sta $d00e
  lda #xco2
  sta $d00c
  lda #xco3-2
  sta $d00a
  lda #xco4+2
  sta $d008
  inc $dbff
  nop
  nop
  lda rasterbar+11
  sta $d021
exit9: nop

  // row 12
  lda #xco1
  sta $d00e
  lda #xco3
  sta $d00a
  lda #xco4
  sta $d008
  inc $dbff
  inc $dbff
  nop
  nop
  lda rasterbar+12
  sta $d021
exit10: nop

  // row 13
  lda #xco4+2
  sta $d008
  inc $dbff
  inc $dbff
  inc $dbff
  inc $dbff
  nop
  nop
  lda rasterbar+13
  sta $d021
exit11: nop

  // row 14
  lda #xco1-2
  sta $d00e
  lda #xco4
  sta $d008
  inc $dbff
  inc $dbff
  inc $dbff
  nop
  nop
  lda rasterbar+14
  sta $d021
exit12: nop

  // row 15
  lda #xco1
  sta $d00e
  lda #xco2-2
  sta $d00c
  lda #xco3-2
  sta $d00a
  lda #xco4-2
  sta $d008
  inc $dbff
  nop
  nop
  lda rasterbar+15
  sta $d021
exit13: nop

  // row 16
  lda #xco1-2
  sta $d00e
  lda #xco2
  sta $d00c
  lda #xco4
  sta $d008
  inc $dbff
  inc $dbff
  nop
  nop
  lda rasterbar+16
  sta $d021
exit14: nop

  // row 17
  lda #xco1
  sta $d00e
  lda #xco3
  sta $d00a
  inc $dbff
  inc $dbff
  inc $dbff
  inc $dbff

  lda rasterbar+17
  sta $d021
exit15: nop

  rts
}
  
rasterbar:
.var c0 = BLUE
.var c1 = LIGHT_BLUE
  .byte c0,c0,c0,c0,c0,c0,c0
  .byte c0,c0,c0,c0,c0,c1,c0
  .byte c1,c0,c1,c1,c1,c1,c1

wait36:
  inc $dbff
wait30:
  inc $dbff
wait24:
  inc $dbff
  inc $dbff
  rts

* = * "[DATA] bounce in"
.var startPosition   = $130
.var position        = startPosition

.var startSpeed      = 0
.var speed           = startSpeed

.const maxBounces    = 4
.var bounces         = 0
.var yPositions = List()

.while (bounces < maxBounces)
{
  // update speed
  .eval speed = speed - 0.1

  // update position
  .eval position = position + speed

  // bounce?
  .if (position < $ff)
  {
    .var overshoot = finalPosition-position
    .eval position = finalPosition+overshoot

    // flip speed and remove energy
    .eval speed = -0.66 * speed

    // one more bounce..
    .eval bounces = bounces + 1
  }
  // store positions
  .eval yPositions.add(round(position)&$ff)
}
.eval yPositions.add(finalPosition)
.eval yPositions.add(finalPosition)

.print ("positions" + yPositions)

bounceAnim:
  .fill yPositions.size(), yPositions.get(i)
  .byte $80  // end of animation

* = sprites "[GFX] sprites"
.fill spriteData.getSize(), spriteData.get(i)
