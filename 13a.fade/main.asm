#import "../00.music/music2.asm"
#import "../13b.zoomscroller/movement.asm"

.label firstByte = $c000
.label yPos1     = $c000
.label yPos2     = $c100
.label code      = $c200

.label firstZP    = $40
  .label jmpIrq   = $40
  .label jmpIrqL  = $41
  .label jmpIrqH  = $42
  .label fldPhase = $43
.label lastZP     = $43

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
    .word music_play    // location of playroutine call -> this installs the music player

    .byte 'S'           // declare safe loading under IO
    .byte 'Z', <firstZP, <lastZP
    .byte 'A'           // load only what is needed..

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

.macro keepTime() { inc timelow; bne *+4; inc timehigh }

* = code "[CODE]"
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
  stx topIrq.nextPartValue

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  #if !AS_SPINDLE_PART
    lda #$94
    sta $dd00

    :MusicInitCall()
  #endif
  
  lda #$0c
  sta $d020

  lda #JMP_ABS
  sta jmpIrq

  lda #<irq
  sta jmpIrqL
  lda #>irq
  sta jmpIrqH

  lda #$f9
  sta $d012
  
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

  #if AS_SPINDLE_PART
    lda restore01: #0
    sta $01
  #endif

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
  sta atemp
  stx xtemp

  lda $01
  sta restore01
  lda #$35
  sta $01

  lda #$00
  sta $d021

  lda #0    // only switch to zoomscroller at the bottom of the screen
  sta nextpart

  lda #$3f  // switch to bank 3 in order to use ghostbyte $ffff
  sta $dd02

  lda #<rasterIrq1
  sta jmpIrqL
  lda #>rasterIrq1
  sta jmpIrqH

  // the rasters aren't anywhere close, so this is a safe spot to calculate the positions and setup the irq's

  ldx FLDPhase1: #startRept1
  cpx #endRept1
  bcc !+
  {
    ldx #startRept1
    stx FLDPhase1
  }
  !:
  stx fldPhase   // save step position for handover to the zoomscroller
  lda yPos1,x    // this is the number of lines the top scroller has been FLD'ed down
  sta fld1

  // zoom scroller 1
  ldx zoomPhase1: #32
  cpx #sineYLength
  bne !+
  {
    ldx #0
    stx zoomPhase1
  }
  !:
  lda sineY,x  // this is the position of the bar (11/16)
  sta zoom1

  ldx fadeIn: #1
  cpx #0
  bne !+
    ldx #$ff
    stx fadeIn

    lda nextPartValue: #0
    sta rasterIrq1.nextPartValue

    lda #$00
    sta moveLow
    sta moveHigh
    beq !++
  !:

  lda moveIn.lo,x
  sta moveLow
  lda moveIn.hi,x
  sta moveHigh
  !:

  // calculate position of top raster
  ldx #0    // x = high byte of position
  lda fld1
  clc
  adc #$2f  // start raster is $30, but the rasterbar is drawn 1 pixel lower than this to stabilize the timing
  bcc *+4; inx; clc
  adc zoom1
  bcc *+4; inx; clc

  adc moveLow
  sta posLow
  txa
  adc moveHigh
  sta posHigh
  tax

  lda posLow

  //ldx high: #$ff  // set a test position
  //lda low:  #$f9

  // is the rasterbar outside of the screen?
  cpx #$80
  bcs startDirect // the bar starts before this irq.. draw it immediately
  cpx #$02
  bcs skipBar  // x is negative above the screen (position >= $200, skip it)
  cpx #$01
  bne checkTop
  cmp #$2c
  bcs skipBar  // position >= $12c, bar is invisible, skip it.
  jmp openBorderBar // the bar is below the openborderirq.. merge them
checkTop:
  // is the bar near the openborder area?
  cmp #$f8
  bcs openBorderBar  // go to the special irq that draws the raster and opens the border

  // the bar is at the top, is it invisible?
  cmp #$07
  bcs visible // the bar is visible
startDirect:
  // the bar starts before the screen, we should draw the color directly!
  lda #$0b
  sta $d021
  jmp skipBar

visible:
  // the bar is visible, we are OK..
  sta $d012

endIrq:
  // next step
  inc FLDPhase1
  inc fadeIn

  lda $d011  // turn the screen off to hide bugs
  and #$6f
  ora #$08
  sta $d011

  asl $d019

  lda restore01: #0
  sta $01

  lda atemp: #0
  ldx xtemp: #0
  rti

// skip drawing the rasterbar..
skipBar:
  lda #<irq
  sta jmpIrqL
  lda #>irq
  sta jmpIrqH
  lda #$f9
  sta $d012
  jmp endIrq

openBorderBar:
  clc        // the bar is drawn 1 rasterline below the $d012 value
  adc #$01
  sta rasterIrq2.d012

  lda #<rasterIrq2
  sta jmpIrqL
  lda #>rasterIrq2
  sta jmpIrqH
  lda #$f8
  sta $d012
  jmp endIrq
}

fld1:     .byte 0
zoom1:    .byte 0
moveLow:  .byte 0
moveHigh: .byte 0
posLow:   .byte 0
posHigh:  .byte 0

// use this irq for rasters < $f8
rasterIrq1:
{
  dec 0
  sta atemp

  lda #<irq
  sta jmpIrqL
  lda #>irq
  sta jmpIrqH
  lda #$f9
  sta $d012

  lda $d011
  and #$7f
  sta $d011

  asl $d019

  lda #$0b
  sta $d021

  // only go to the next part after drawing the rasterbar
  lda nextPartValue: #0
  sta nextpart

  lda atemp: #0
  inc 0
  rti
}

// this irq draws a rasterbar and opens the lower border..
// use this irq for rasters >= $f8
rasterIrq2:
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
    lda #$0b
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

  // don't go to the next part here..
  lda #0
  sta nextpart

  lda $d011
  and #$7f
  sta $d011

  asl $d019
  
  cli

  jsr playMusic

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

  lda #0       // do not allow to go to the next part in this part of the frame, draw the raster first!
  sta nextpart

  lda $01
  sta restore01
  lda #$35
  sta $01

  lda $d011    // open border
  and #$f7
  sta $d011
 
  jsr playMusic

  lda #<topIrq
  sta jmpIrqL
  lda #>topIrq
  sta jmpIrqH
  lda #$00
  sta $d012

  lda $d011    // turn the screen off
  and #$6f
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

playMusic:
{
  keepTime()
  :MusicPlayCall()

  rts
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

.var values = List()
// calculate fade in movement
.var sinMin = -$40
.var sinMax =  $c0
  
.var sinAmp = 0.5 * (sinMax-sinMin)
.var sinLength = 96
.for (var i=0; i<256; i++)
{
  .var  value = (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i+sinLength/4,sinLength)*360/sinLength))
  .eval value = value * (1-(i/256))*(1-(i/256))
  //.print (value)
  .eval values.add(value)
}

* = * "[DATA] movement"
moveIn:
.lohifill values.size(), values.get(i)
endMoveIn:
