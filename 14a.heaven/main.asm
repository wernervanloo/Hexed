// scrollway will inherit 2 screens from heaven. one at $f400 and one at $0400
// this part will copy the screen from $f400 to $0400.
// after copying, we can use the screen at $0400 as an 'original' to copy from while scrolling down

.var extraWait = 48

#import "../14c.scrollway/convert_logo.asm"  // outputs uniqueChars and screenData
#import "../00.music/music2.asm"

                                                                    // bitpairs  $d021-3, $d022-b, $d023-7, $d800-1
.var logoTop    = LoadPicture("../14c.scrollway/includes/top.png",    List().add($70A4B2, $444444, $B8C76F, $FFFFFF))
.var logoBottom = LoadPicture("../14c.scrollway/includes/bottom.png", List().add($70A4B2, $444444, $B8C76F, $FFFFFF))

.const border      = WHITE
.const background  = WHITE
.const addD012     = $48

.const switch  = 11       // switch after 11 rows
.var maxRow    = 20        // number of graphic rows

.var logo1 = convertPicture(logoTop)
.var charset1 = logo1.get(0)
.var screen1  = logo1.get(1)

.var logo2 = convertPicture(logoBottom)
.var charset2 = logo2.get(0)
.var screen2  = logo2.get(1)

.var nrRows    = 25        // # of rows with graphics on the screen
.var occupied  = false
.for (var r=24; (r>=0) && (occupied==false); r--)
{
  .eval occupied = false
  .for (var x=0; (x<40) && (occupied == false); x++)
  {
    .var value = screen2.get(r*40+x)
    .if (value !=0 ) { .eval occupied = true } // this row is being used
  }
  .if (occupied == false) { .eval nrRows = nrRows - 1 }
}
.var nrPages = floor((nrRows*40)/256)+1  // count # of pages needed for logo definition

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

.label firstZP   = $10
.label col0     = $10
.label col1     = $11
.label yLow     = $12
.label startRow = $13
.label d012     = $14
.label lastZP    = $14

.label screen        = $0400  // logoScreen gets copied to screen, switch and scrollway inherit this
.label charset1a     = $2000  // this charset gets inherited by switch and scrollway
.label charset2a     = $2800  // this charset gets inherited by switch and scrollway

.label firstByte     = $e800
.label logoCharset2  = $e800  // this charset gets copied to charset1a and charset2a. this will be deleted here.
.label code          = $ec00

.label logoScreen    = $f400  // this screen gets inherited by switch and scrollway
.label logoCharset   = $f800  // this charset gets inherited by switch and scrollway. this is the charset with the top 11 rows of the gfx

#if AS_SPINDLE_PART
  .label spindleLoadAddress = firstByte
  *=spindleLoadAddress-18-10-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word prepare       // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word cleanup       // cleanup routine
    .word music_play    // location of playroutine call

    .byte 'S'
    .byte 'Z',<firstZP,   <lastZP            // declare zeropage use
    .byte 'P',>charset1a, >(charset2a+$7ff)  // protect 2nd charsets
    .byte 'P',>screen,    >(screen+$3e8)     // protect screen for scrollway

    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2($080e); sei; lda #$35; sta $01; jmp start
#endif

* = logoCharset2 "[GFX] charset for 2nd part of logo"
.fill charset2.size(),charset2.get(i)

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

  // only allow jumping to the next part before irq2. a jump to the next part will start with an irq there.
  // if we allow jumping to the next part _after_ irq2, then the next irq will also be 'irq2' and we will miss the charset change
  ldx nextpart
  inx
  stx stopIrq.resetState.endState.nextPartValue

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  #if !AS_SPINDLE_PART
    jsr prepare

    lda #$94
    sta $dd00

    :MusicInitCall()
  #endif

  lda #WHITE
  sta col0
  lda #WHITE
  sta col1
  lda #0
  sta yLow
  sta startRow

  lda #<irq2
  sta $fffe
  lda #>irq2
  sta $ffff
  lda #$fb
  sta $d012

  lda #<rasterNMI2
  sta $fffa
  lda #>rasterNMI2
  sta $fffb
  //lda #RTI  // we can't use this trick because of switching out IO when exiting the nmi
  //sta $dd0c

  lda #border
  sta $d020
  lda #background
  sta $d021

  lda #$0b
  sta $d022
  lda #$07
  sta $d023

  lda $d011
  and #$70   // 24 row mode, start at the top
  sta $d011

  lda $dc0d
  lda $dd0d
  asl $d019

  #if AS_SPINDLE_PART
    lda restore01: #0
    sta $01
  #endif

  cli

  lda waitScreenOff: #0
  beq *-2

  ldx #0
  {
  lda #$01|$08
  loop:
    .for (var i=0; i<4; i++)
    {
      sta $d800+i*256,x
    }
    inx
    bne loop
  }

  // write colors to part of the screen occupied by scroller
  // we can write these directly.. it does not matter for scrolling down the gate that these are here
  {
  bigloop:

    ldx startX: #10
    ldy w:      #20-1
    lda #CYAN
    loop:
      sta write: $d800+14*40,x
      inx
      dey
      bpl loop
    
    lda write
    clc
    adc #40
    sta write
    bcc !+
      inc write+1
    !:
    // increase width by 2
    inc w
    inc w

    // decrease start x
    dec startX
    bpl bigloop
  }

loop:
  #if !AS_SPINDLE_PART
    cmp ($00,x)
    //inc $d020
    jmp loop
  #else
    rts
  #endif
}

prepare:
{
  ldx #0
  {
  loop:
    .for (var i=0; i<8; i++)
    {
      .if (i<4) { lda logoCharset2+i*256,x }
      else      { .if (i==4) { lda #0 } }
      sta charset1a+i*256,x
      sta charset2a+i*256,x
    }

    .for (var i=0; i<4; i++)
    {
      .if (i<nrPages) { lda logoScreen+i*256,x } // picture occupies until $06a8 (i think..)
      else            { lda #0 }
      sta screen+i*256,x

      // clear the screen we copied from, we will scroll down again later.
      lda #0
      sta logoScreen+i*256,x
    }

    inx
    bne loop
  }

  rts
}

cleanup:
{
  // wait until invisible rasterline
wait:
  lda $d012
  cmp #4
  bcs wait   // stay in the wait loop until rasterline < 4
  lda $d011
  bmi wait   // stay in the loop if we are at the bottom of the screen (rasterline $100-$103)
  rts
}

scrollDown:
{
  inc startRow
  // only copy the first couple of rows to make it quicker

  lda startRow
  cmp #8
  bcs copyAll
 
  copyFirst:
  {
  ldx #39
  loop:
    .for (var r=5; r>=0; r--)  // start at maxRow-2. if there are 2 rows, we only have to copy row 0 down.
    {
      lda logoScreen+r*40,x
      sta logoScreen+r*40+40,x
    }
    lda from: screen+maxRow*40,x
    sta logoScreen,x
    dex
    bpl loop
    jmp continue
  }

  // copy all the rows..
copyAll:
  {
  // for the last rows, only copy the 10 leftmost and 10 rightmost columns..
  ldx #9
  loop2:
  {
    .for (var r=maxRow-2; r>=13; r--)
    {
      lda logoScreen+r*40,x
      sta logoScreen+r*40+40,x
      lda logoScreen+r*40+30,x
      sta logoScreen+r*40+40+30,x
    }
    dex
    bpl loop2
  }

  // for the upper rows, copy all 40 columns
  ldx #39
  loop:
    .for (var r=12; r>=0; r--)  // start at maxRow-2. if there are 2 rows, we only have to copy row 0 down.
    {
      lda logoScreen+r*40,x
      sta logoScreen+r*40+40,x
    }
    lda from: screen+maxRow*40,x
    sta logoScreen,x
    dex
    bpl loop
  }
  
continue:
  lda copyAll.from
  sec
  sbc #40
  sta copyAll.from
  sta copyFirst.from
  lda copyAll.from+1
  sbc #0
  sta copyAll.from+1
  sta copyFirst.from+1

  rts
}

// this irq set ups the correct NMI for fading the background
setupIrq:
{
  sta atemp
 
  dec 0

  .var waitCycles = 4*63-1  
  lda cycles: #<waitCycles
  sta $dd04
  lda #>waitCycles
  sta $dd05

  // go to irq next

  lda #<irq1
  sta $fffe
  lda #>irq1
  sta $ffff

  lda d012
  sta $d012

  lda $0400 // just a marker

  lda $d012
  cmp $d012
  bne !+
    nop
    nop
  !:

  asl $d019

  lda stopIrq.state
  cmp #2
  bne !+

  lda #<irq1a
  sta $fffe
  lda #>irq1a
  sta $ffff

  lda #%10010001
  sta $dd0e  // enable timer

  lda #$81   // activate nmi
  bit $dd0d
  sta $dd0d

  lda d012
  sec
  sbc #$1
  sta $d012

  jmp continue
!:
  inc $dbff
  inc $dbff
  nop
  lda #%10010001
  sta $dd0e  // enable timer

  lda #$81   // activate nmi
  bit $dd0d
  sta $dd0d
continue:

  lda #0
  sta nextpart

  inc 0
  lda atemp: #0
  rti
}

// one raster of the new color, 3 rasters of the old color
rasterNMI1:
{
  dec 0
  sta atemp

  lda col1: #$0e
  sta $d020
  sta $d021

  inc $dbff
  inc $dbff
  inc $dbff
  inc $dbff
  inc $dbff
  inc $dbff
  inc $dbff
  lda $dd0d
  nop
  nop

  lda col0: #$03
  sta $d021
  sta $d020

  lda atemp: #0
  inc 0
  rti
}

// two rasters of the new color, 2 rasters of the old color
rasterNMI2:
{
  sta atemp
  dec 0

  lda col0: #$0e
  sta $d020
  sta $d021

  eor eorValue: #($0e^$03)
  sta col0

  lda $dd0d
  lda atemp: #0
  inc 0
  rti
}

// this is the irq below the logo, switching to the first charset of the scroller
// ------------------------------------------------------------------------------
irq1:
{
  sta atemp
  lda $01
  sta restore01
  lda #$35
  sta $01

  lda #<copyIrq
  sta $fffe
  lda #>copyIrq
  sta $ffff

  lda #((logoScreen&$3c00)/$400*$10)+((logoCharset2&$3800)/$800*2)
  sta $d018
  lda #((logoCharset2&$c000)/$4000)|$3c
  sta $dd02  

  lda $d011
  and #$7f
  sta $d011

  lda $d012
  clc
  adc #addD012
  sta $d012

  asl $d019

  lda restore01: #0
  sta $01
  lda atemp: #0
  rti
}

// this is the irq below the logo, switching to the first charset of the scroller
// ------------------------------------------------------------------------------
irq11:
{
  sta atemp
  lda $01
  sta restore01
  lda #$35
  sta $01

  lda #<copyIrq
  sta $fffe
  lda #>copyIrq
  sta $ffff
  
  lda $d011
  and #$7f
  sta $d011

  inc $dbff

  lda #((logoScreen&$3c00)/$400*$10)+((logoCharset2&$3800)/$800*2)
  sta $d018
  lda #((logoCharset2&$c000)/$4000)|$3c
  sta $dd02  

  lda $d012
  clc
  adc #addD012
  sta $d012

  asl $d019

  lda restore01: #0
  sta $01
  lda atemp: #0
  rti
}

// this is the irq below the logo, switching to the first charset of the scroller
// ------------------------------------------------------------------------------
irq1a:
{
  sta atemp
  stx xtemp
  sty ytemp

  lda $01
  sta restore01
  lda #$35
  sta $01

  lda #$7f
  sta $dd0d

  lda rasterNMI2.col0
  eor rasterNMI2.eorValue
  sta rasterNMI2.col0

  lda #<copyIrq
  sta $fffe
  lda #>copyIrq
  sta $ffff

  lda $d011
  and #$7f
  sta $d011

  nop
  nop
  inc $dbff

  ldx col0
  ldy #((logoCharset2&$c000)/$4000)|$3c

  lda #((logoScreen&$3c00)/$400*$10)+((logoCharset2&$3800)/$800*2)
  sta $d018
  sty $dd02

  stx $d021
  stx $d020

  lda #$81   // activate nmi
  bit $dd0d
  sta $dd0d

  lda $d012
  clc
  adc #addD012
  sta $d012

  asl $d019

  lda restore01: #0
  sta $01
  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

// this is the irq below the logo, switching to the first charset of the scroller
// ------------------------------------------------------------------------------
irq1b:
{
  sta atemp
  lda $01
  sta restore01
  lda #$35
  sta $01

  lda #<copyIrq
  sta $fffe
  lda #>copyIrq
  sta $ffff

  lda $d011
  and #$7f
  sta $d011

  asl $d019

  lda #((logoScreen&$3c00)/$400*$10)+((logoCharset2&$3800)/$800*2)
  sta $d018
  lda #((logoCharset2&$c000)/$4000)|$3c
  sta $dd02  

  lda $d012
  clc
  adc #addD012
  sta $d012

  lda restore01: #0
  sta $01
  lda atemp: #0
  rti
}

// this irq will copy the screen down if necessary
copyIrq:
{
  sta atemp
  stx xtemp
  sty ytemp

  lda #<irq2
  sta $fffe
  lda #>irq2
  sta $ffff

  lda #$fb
  sta $d012
  lda $d011
  and #$7f
  sta $d011

  asl $d019

  cli

  // this is where we copy the screen down
  lda irq2.waitScroll
  bne skipAll

  // if we did not scroll the correct number of rows yet, continue
  lda ready: #0
  beq continue

  // if we did scroll the correct number of rows, scroll an additional 3 pixels to match up with scrollway
  lda yLow
  cmp #3
  beq skipAll

continue:
  ldx phase: #0
  lda yAdds,x
  bpl !+
    // we reached the end of the scroll down
    lda #1
    sta ready
    jmp skipAll
  !:
  clc
  adc yLow
  sta yLow

  cmp #8
  bcc !+
    and #7
    sta yLow
    cli
    jsr scrollDown
  !:

  inc phase
  
  // this is the old code, where scrolling depends on the state of the background
  // we fine tuned the frames where we have to copy the gate down to the frames with a fixed background color
  // the result is a fixed scroll down speed, while we might want a variable one..

  /*
  // calculate the state we are in
  lda stopIrq.state
  asl
  asl
  ora stopIrq.wait
  eor #$03

  sec
  sbc #2
  and #$0f
  eor #$0f
  sta scrollState
  eor #$0f
  lsr
  sta yLow

  lda scrollState: #0
  cmp #$f
  bne !+
    jsr scrollDown
    beq skipAll
  !:
  */

skipAll:

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

// this irq is near the lower border
// ---------------------------------

irq2:
{
  sta atemp
  stx xtemp
  sty ytemp

  lda $01
  sta restore01
  lda #$35
  sta $01

  // wait until scrolling the gates
  lda waitScroll: #100+extraWait
  beq !+
    dec waitScroll
  !:

  // stay in white until your eyes adjust

  lda waitWhite: #60+extraWait
  beq fade
  
  dec waitWhite

  lda #<irq11
  sta $fffe
  lda #>irq11
  sta $ffff

  lda yLow
  clc
  adc #$2f+switch*8
  sta $d012

  lda yLow
  ora #$10
  sta $d011

  //lda $d011
  //and #$7f
  //sta $d011

  jmp endIrq

fade:
  lda #<stopIrq
  sta $fffe
  lda #>stopIrq
  sta $ffff  

  lda yLow
  clc
  adc #$29
  sta $d012

  lda $d011
  and #$7f
  ora #$80
  sta $d011

endIrq:
  lda #$d8
  sta $d016

  lda #((logoScreen&$3c00)/$400*$10)+((logoCharset&$3800)/$800*2)
  sta $d018
  lda #((logoCharset&$c000)/$4000)|$3c
  sta $dd02  

  lda #1
  sta start.waitScreenOff
  
  inc timelow
  bne !+
    inc timehigh
  !:

  asl $d019
  
  cli
  :MusicPlayCall()  

  lda restore01: #0
  sta $01

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

// this IRQ stops the NMI
stopIrq:
{
  sta atemp
  stx xtemp

  lda $01
  sta restore01
  lda #$35
  sta $01

  lda #$7f   // disable nmi
  sta $dd0d

  // what should the background color be?
  // 0 = one fixed color (no NMI)
  // 1 = 3 rasters of color 0, 1 raster of color 1l
  // 3 = 1 raster of color 0, 3 rasters of color 1


fade:
  lda wait: #5
  beq nextState

  dec wait
  jmp continue

nextState:
  lda #3
  sta wait

  lda state
  clc
  adc incstate: #1
  sta state
  cmp #4
  bcc !+
  resetState: {
    lda #0
    sta state
    
    // check if the fade has ended
    inc colorPhase
    ldx colorPhase
    lda colorRamp+1,x
    bpl !+
    endState: {
      // mark that the fade is done and we keep the single background color
      lda #1
      sta fadeDone

      dec colorPhase

      lda copyIrq.ready  // also wait until the movement is ready..
      
      beq !+
        lda yLow
        cmp #3
        bne !+
          * = * "[CODE] wait.."
          // also wait until we passed frame $1da0..
          lda timehigh
          cmp #$1d
          bcc !+ // not yet
          beq checkLow
          bcs goNextPart // already too late..
          checkLow:
          lda timelow
          cmp #$a0
          bcc !+         // not yet..
          goNextPart:
            lda nextPartValue: #0
            sta nextpart
    }
  }
  !:
continue:
  // if the fade is done, skip to one single background color
  lda fadeDone: #0
  bne oneBackgroundColor

  ldx colorPhase: #0
  lda colorRamp,x
  sta col0
  lda colorRamp+1,x
  sta col1
  
  lda state: #0
  bne checkState1
oneBackgroundColor:
  {
    // one fixed background color
    lda #<irq1b
    sta $fffe
    lda #>irq1b
    sta $ffff

    lda startRow
    asl
    asl
    asl
    clc
    adc yLow
    clc
    adc #$2f
    sec
    sbc #(maxRow+1-switch)*8
    bcs !+
      lda #$00
    !:

    cmp #$2f
    bcs !+
      lda #$2f
    !:
    sta $d012

    lda col0
    sta $d020
    sta $d021

    jmp endIrq
  }

checkState1:
  cmp #1
  bne checkState2
  {
    lda #<setupIrq
    sta $fffe
    lda #>setupIrq
    sta $ffff  

    lda yLow
    clc
    adc #$00
    sta $d012

    lda #<rasterNMI1
    sta $fffa
    lda #>rasterNMI1
    sta $fffb

    lda col0
    sta rasterNMI1.col0
    lda col1
    sta rasterNMI1.col1
    
    .var waitCycles = 4*63-1  
    lda #<waitCycles
    sta setupIrq.cycles

    jmp endIrq
  }
checkState2:
  cmp #2
  bne checkState3
  {
    lda #<setupIrq
    sta $fffe
    lda #>setupIrq
    sta $ffff  

    lda yLow
    and #3
    clc
    adc #$04
    sta $d012

    lda #<rasterNMI2
    sta $fffa
    lda #>rasterNMI2
    sta $fffb

    lda col0
    sta rasterNMI2.col0
    eor col1
    sta rasterNMI2.eorValue

    .var waitCycles = 2*63-1  
    lda #<waitCycles
    sta setupIrq.cycles

    jmp endIrq
  }
checkState3:
{
  lda #<setupIrq
  sta $fffe
  lda #>setupIrq
  sta $ffff  

  lda yLow
  clc
  adc #$00
  sta $d012

  lda #<rasterNMI1
  sta $fffa
  lda #>rasterNMI1
  sta $fffb

  lda col1
  sta rasterNMI1.col0
  lda col0
  sta rasterNMI1.col1

  .var waitCycles = 4*63-1  
  lda #<waitCycles
  sta setupIrq.cycles
}

endIrq:

  // calculate where the split should happen
  lda startRow
  asl
  asl
  asl
  clc
  adc yLow
  clc
  adc #$2f
  sec
  sbc #(maxRow+1-switch)*8
  bcs !+
    lda #$00
  !:

  cmp #$2f
  bcs !+
    lda #$27
    clc
    adc yLow
  !:

  sta d012

  lda yLow
  ora #$10
  sta $d011
  //lda $d011
  //and #$7f
  //sta $d011

  asl $d019
  lda restore01: #0
  sta $01
  lda atemp: #0
  ldx xtemp: #0
  rti
}

colorRamp:
.byte $1,$1,$1,$1,$7,$d,$f,$3,$3, $80 // end fade with negative value

* = * "[DATA] y speed"
yAdds: 
.var startPosition = 0
.var speed         = 0
.var position      = startPosition

.var Position  = 0
.var previousPosition = 0
.var maxPos    = maxRow*8+8+3
.var Speed     = 0
.var centre    = (Position+maxPos)/2
.var radius    = -(maxPos-Position)/2
.var frames    = 140

.var Positions = List()
.var y

.for (var i=0; i<frames+1; i++)
{
  .var value = round(centre + radius*cos(toRadians((180*i/frames))))
  .eval Positions.add(value)

  // calculate differences
  .byte value - previousPosition
  .eval previousPosition = value
}
.byte $80 // mark end




* = logoScreen "[GFX] screen for logo"
.fill min(screen1.size(),switch*40), screen1.get(i)       // first # of rows of the picture
.fill screen2.size()-switch*40,screen2.get(i+switch*40)   // second # of rows of the picture

* = logoCharset "[GFX] charset for logo"
.fill charset1.size(),charset1.get(i)
.fill $58,$55 // test how many chars possible

* = screen "[GEN] screen gets copied here to be inherited by scrollway" virtual
.fill 1000,0

* = charset1a "[GEN] charset gets copied here to be inherited by scrollway" virtual
.fill 256*8,0

* = charset2a "[GEN] charset gets copied here to be inherited by scrollway" virtual
.fill 256*8,0
