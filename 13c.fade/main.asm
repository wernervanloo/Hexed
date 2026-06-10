#import "../00.music/music2.asm"
#import "../13b.zoomscroller/movement.asm"

.label firstByte = $e000
.label yPos1     = $e000
.label yPos2     = $e100
.label code      = $e200

.label firstZP   = $40
  .label jmpIrq  = $40
  .label jmpIrqL = $41
  .label jmpIrqH = $42
.label lastZP    = $42

// settings for sinewave
.const sineYLength  = 64

#if AS_SPINDLE_PART

  .label spindleLoadAddress = firstByte
  *=spindleLoadAddress-18-5-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word 0             // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word 0             // cleanup routine
    .word music_play    // location of playroutine call

    .byte 'S'           // declare safe loading under IO
    .byte 'A'           // avoid : load only what is necessary
    .byte 'Z', <firstZP, <lastZP
    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2($080e); sei; lda #$35; sta $01; jmp start
#endif

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

.label fldPhase1   = $ee  // read positions of phases from last part
.label zoomPhase1  = $ef
.label zoomPhase2  = $f0

.macro keepTime() { inc timelow; bne *+4; inc timehigh }

* = code "[CODE]"
start:
{
  sei

  lda $01
  sta restore01
  lda #$35
  sta $01

  ldx nextpart
  inx
  stx finalIrq.nextPartValue

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  #if AS_SPINDLE_PART
    lda fldPhase1
    sta topIrq.FLDPhase1
    lda zoomPhase1
    sta topIrq.zoomPhase1
    lda zoomPhase2
    sta topIrq.zoomPhase2
  #endif

  #if !AS_SPINDLE_PART
    :MusicInitCall()

    lda #$94
    sta $dd00

    lda #$0c
    sta $d020
  #endif
  
  lda #JMP_ABS
  sta jmpIrq

  #if !AS_SPINDLE_PART
    // if we are not running in spindle, we have to open the border before we can turn off the screen
    lda #<irq
    sta jmpIrqL
    lda #>irq
    sta jmpIrqH

    lda #$fa
    sta $d012
  #else
    // in spindle, the border is already open. we can turn off the screen immediately to hide bugs
    lda #<topIrq
    sta jmpIrqL
    lda #>topIrq
    sta jmpIrqH

    lda #$00 
    sta $d012
  #endif
  
  lda #<jmpIrq
  sta $fffe
  lda #>jmpIrq
  sta $ffff

  lda $d011
  and #$7f
  sta $d011
  
  lda #$00
  sta $d015

  lda $dc0d
  lda $dd0d
  asl $d019

  lda restore01: #0
  sta $01

  cli
loop:
  #if !AS_SPINDLE_PART
    jmp *
  #else
    rts
  #endif
}

// irq to reset screen colors
topIrq:
{
  dec 0
  sta atemp
  stx xtemp
  sty ytemp

  lda #$00
  sta $d021

  lda #$3f  // switch to bank 3 in order to use ghostbyte $ffff
  sta $dd02

  lda #<rasterIrq1
  sta jmpIrqL
  lda #>rasterIrq1
  sta jmpIrqH
  
  lda $d011  // turn the screen off to hide bugs
  and #$6f
  ora #$08
  sta $d011

  // the rasters aren't anywhere close, so this is a safe spot to calculate the positions and setup the irq's

  ldx FLDPhase1: #startRept2
  cpx #endRept2
  bcc !+
  {
    ldx #startRept2
    stx FLDPhase1
  }
  !:
  lda yPos1,x    // this is the number of lines the top scroller has been FLD'ed down
  sta fld1
  lda yPos2,x
  sta fld2

  // zoom scroller 1
  ldx zoomPhase1: #0
  cpx #sineYLength
  bcc !+
  {
    ldx #0
    stx zoomPhase1
  }
  !:
  lda sineY,x  // this is the position of the bar (11/16)
  sta zoom1
  lda sineY2,x // this is the full zoom size
  sta zoom1a

  // zoom scroller 2
  ldx zoomPhase2: #0
  cpx #sineYLength
  bcc !+
  {
    ldx #0
    stx zoomPhase2
  }
  !:
  lda sineY,x
  sta zoom2

  // calculate position of top raster
  lda fld1
  clc
  adc #$2f  // start raster is $30, but the rasterbar is drawn 1 pixel lower than this to stabilize the timing
  adc zoom1
  sta pos1

  /*
  ldx go1: #0 // wait until first rasterbar has dropped
  bne !+
    stx up1
    stx down1
  !:

  ldx up1: #0
  bne checkDown  // we already noticed the raster going up
    // try to determine if we start to move down
    cmp pos1old
    bcs !+  // still moving down
      inc up1  // mark that we saw it moving up
      bne !+
checkDown:
  ldx down1: #0
  bne !+     // already checked
    cmp pos1old
    bcc !+   // still moving up
      inc down1
      inc drop1Start // go!
!:
  lda pos1
  sta pos1old
  */

  // if the drop has not started, copy the value to the fixed dropoff point
  ldx dropPhase1: #30
  lda drop,x
  bne !+
  {
    // keep copying the value until the drop started
    lda pos1
    sta pos1fix
  }
  !:

  lda drop,x
  cmp #$ff
  beq !+
    ldy drop1Start: #1
    beq !+
    inc dropPhase1
  !: 

  // we can go to the next part
  cmp #$ff
  bne !+
    sta goFinal
  !:

  clc
  adc pos1fix  // add the fixed position
  sta pos1l
  sta $d012

  // calculate the high byte aswell
  lda #0
  adc #0
  sta pos1h

  // calculate position of bottom raster
  lda fld1
  clc
  adc #$2f
  adc zoom1a
  adc #5
  adc fld2
  adc zoom2
  sta pos2



/*
  ldx up2: #0
  bne checkDown2  // we already noticed the raster going up
    // try to determine if we start to move down
    cmp pos2old
    bcs !+  // still moving down
      inc up2  // mark that we saw it moving up
      bne !+
checkDown2:
  ldx down2: #0
  bne !+     // already checked
    cmp pos2old
    bcc !+   // still moving up
      inc down2
      inc drop2Start // go!
!:
  lda pos2
  sta pos2old
*/

  // if the drop has not started, copy the value to the fixed dropoff point
  ldx dropPhase2: #50
  lda drop,x
  bne !+
  {
    // keep copying the value until the drop started
    lda pos2
    sta pos2fix
  }
  !:

  lda drop,x
  cmp #$ff
  beq !+
    ldy drop2Start: #1
    beq !+

    inc dropPhase2
  !: 
  
  /*
  // start 2nd drop
  cmp #$ff
  bne !+
    ldx #1
    sta go1
  !:
  */

  clc
  adc pos2fix  // add the fixed position
  sta pos2l

  // calculate the high byte aswell
  lda #0
  adc #0
  sta pos2h

  // next step
  inc FLDPhase1
  inc zoomPhase1
  inc zoomPhase2

  jsr playMusic

  // now double check the position of the next rasterbar
  lda pos1l
  ldx pos1h

  // is the rasterbar outside of the screen?
  cpx #$02
  bcs skipBar  // x is negative above the screen (position >= $200, skip it)
  cpx #$01
  bne checkTop
  cmp #$2c
  bcs skipBar  // position >= $12c, bar is invisible, skip it.
  jmp openBorderBar // the bar is below the openborderirq.. merge them
checkTop:
  // is the bar near the openborder area?
  cmp #$f4
  bcs openBorderBar  // go to the special irq that draws the raster and opens the border

visible:
  // the bar is visible, we are OK..
  sta $d012


endIrq:
  asl $d019

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  inc 0
  rti


// go here if we do not draw the next bar at all
skipBar:
  lda goFinal: #0
  beq !+

    lda #<finalIrq
    sta jmpIrqL
    lda #>finalIrq
    sta jmpIrqH
    lda #$fa
    sta $d012
    lda $d011
    and #$7f
    sta $d011
    jmp endIrq
  !:
  lda #<irq
  sta jmpIrqL
  lda #>irq
  sta jmpIrqH
  lda #$fa
  sta $d012
  lda $d011
  and #$7f
  sta $d011
  jmp endIrq

openBorderBar:
  clc        // the bar is drawn 1 rasterline below the $d012 value
  adc #$01
  sta rasterIrq2b.d012

  lda #<rasterIrq2b
  sta jmpIrqL
  lda #>rasterIrq2b
  sta jmpIrqH
  lda #$f0
  sta $d012

  lda #$0b
  sta rasterIrq2b.waitLoop.color

  jmp endIrq
}

playMusic:
{
  keepTime()
  :MusicPlayCall()

  rts
}

fld1:   .byte 0
fld2:   .byte 0
zoom1:  .byte 0
zoom1a: .byte 0
zoom2:  .byte 0

pos1:    .byte 0   // the calculatad position
pos1old: .byte 0   // previous position
pos1fix: .byte 0   // the fixed position when the drop starts
pos1l:   .byte 0
pos1h:   .byte 0

pos2:    .byte 0   // the calculated position
pos2old: .byte 0   // previous position
pos2fix: .byte 0   // the fixed position when the drop starts
pos2l:   .byte 0
pos2h:   .byte 0

rasterIrq1:
{
  dec 0
  sta atemp
  stx xtemp

  lda #<rasterIrq2
  sta jmpIrqL
  lda #>rasterIrq2
  sta jmpIrqH
  lda pos2l
  sta $d012

  lda $d011
  and #$7f
  sta $d011

  lda #$0b
  sta $d021

  // now double check the position of the next rasterbar
  lda pos2l
  ldx pos2h

  // is the rasterbar outside of the screen?
  cpx #$02
  bcs skipBar  // x is negative above the screen (position >= $200, skip it)
  cpx #$01
  bne checkTop
  cmp #$2c
  bcs skipBar  // position >= $12c, bar is invisible, skip it.
  jmp openBorderBar // the bar is below the openborderirq.. merge them
checkTop:
  // is the bar near the openborder area?
  cmp #$f4
  bcs openBorderBar  // go to the special irq that draws the raster and opens the border

visible:
  // the bar is visible, we are OK..
  sta $d012


endIrq:
  asl $d019

  lda atemp: #0
  ldx xtemp: #0
  inc 0
  rti

// go here if we do not draw the next bar at all
skipBar:
  lda #<irq
  sta jmpIrqL
  lda #>irq
  sta jmpIrqH
  lda #$fa
  sta $d012
  lda $d011
  and #$7f
  sta $d011
  jmp endIrq

openBorderBar:
  clc        // the bar is drawn 1 rasterline below the $d012 value
  adc #$01
  sta rasterIrq2b.d012

  lda #<rasterIrq2b
  sta jmpIrqL
  lda #>rasterIrq2b
  sta jmpIrqH
  lda #$f0
  sta $d012

  lda #$0c
  sta rasterIrq2b.waitLoop.color

  jmp endIrq
}

rasterIrq2:
{
  dec 0
  sta atemp

  lda #<irq
  sta jmpIrqL
  lda #>irq
  sta jmpIrqH
  lda #$fa
  sta $d012

  lda $d011
  and #$7f
  sta $d011

  asl $d019
  
  lda #$0c
  sta $d021

  lda atemp: #0
  inc 0
  rti
}

// this irq draws a rasterbar and opens the lower border..
// use this irq for rasters >= $f8
rasterIrq2b:
{
  sta atemp
  stx xtemp
  sty ytemp

  lda $01
  sta restore01
  lda #$35
  sta $01

  lda #<topIrq
  sta jmpIrqL
  lda #>topIrq
  sta jmpIrqH
  lda #$00
  sta $d012

  ldx d012: #0

  waitLoop:  // this loop is exactly 63 cycles
  {
    // are we at the correct raster to draw the rasterline?
    lda color: #$0c
    cpx $d012
    bne !+
      sta $d021
      jmp continue  // this path has 15 cycles
    !:
    inc $dbff       // this path has 15 cycles
  continue:

    // calculate what $d011 value to write
    lda $d012
    cmp #$f9  // carry is clear when $d012 < $f9 (d011 should be 08), carry is _set_ when $d012 >= $fa (d011 shoule be 00)
    lda #$ff
    adc #0    // carry clear : a = $ff, carry set : a = $00
    and #$08  // carry clear : a = $08, carry set : a = $00
    sta $d011
    // 16 cycles, total 31 cycles

    inc $dbff
    inc $dbff
    bit $ea
    nop
    nop
    // 19 cycles, total 50 cycles
    lda $d012
    clc
    adc #$80
    cmp #($30+$80)
    bcc waitLoop  // 13 cycles, total 63 cycles
  }

  lda $d011
  and #$7f
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
  sty ytemp

  lda $01
  sta restore01
  lda #$35
  sta $01

  lda $d011    // open border
  and #$f7
  sta $d011
 
  lda #<topIrq
  sta jmpIrqL
  lda #>topIrq
  sta jmpIrqH
  lda #$00
  sta $d012

  asl $d019

  // wait for reset border
  lda $d011
  bpl *-3

  lda $d011    // turn the screen off
  and #$6f
  ora #$08
  sta $d011

  lda restore01: #0
  sta $01

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

finalIrq:
{
  sta atemp
  stx xtemp
  sty ytemp

  lda $01
  sta restore01
  lda #$35
  sta $01

  // open border
  lda $d011
  and #$f7
  sta $d011

  lda nextPartValue: #0
  sta nextpart

  lda #<finalIrq
  sta jmpIrqL
  lda #>finalIrq
  sta jmpIrqH
  lda #$fa
  sta $d012

  asl $d019

  jsr playMusic

  // reset border
  lda $d011
  ora #$08
  and #$7f
  sta $d011

  lda restore01: #0
  sta $01
  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

sineY: 
* = * "[DATA] sine (height)"
{
  .var minSize = 48
  .var maxSize = 80
  .var sinMin = minSize-minSize
  .var sinMax = maxSize-minSize
  
  .var sinAmp = 0.5 * (sinMax-sinMin)
  .var sinLength = sineYLength
  .for (var i=0; i<sinLength; i++)
  {
    .var  value = (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength))
    .eval value = 11 * value / 16  // rasterbar is at position 11/16
    .eval value = 11*3 + value     // add the minimum size (11*3 rasters)
    .byte value
  }
}

sineY2: 
* = * "[DATA] sine (height)"
{
  .var minSize = 48
  .var maxSize = 80
  .var sinMin = minSize-minSize
  .var sinMax = maxSize-minSize
  
  .var sinAmp = 0.5 * (sinMax-sinMin)
  .var sinLength = sineYLength
  .for (var i=0; i<sinLength; i++)
  {
    .var  value = (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength))
    .eval value = 16*3 + value     // add the minimum size (16*3 rasters)
    .byte value
  }
}

* = * "[DATA] drop data"
drop:
.fill 50,0
.var position = 0
.var speed = 0

.while (position < 256)
{
  .eval speed = speed + 0.16
  .eval position = position + speed

  .byte min($ff,round(position))
}