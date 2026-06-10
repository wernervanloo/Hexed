#import "../00.music/music2.asm"

// possible updates :
// - i think we can remove 1 block from d012table? but we have to make it wrap around for the rasterbar check

// unpossible updates
// - improve Y zoom code : can we save 2 more blocks?  -> I tested this.. the memory for extra code needed for BRR is bigger than memory saved by removing the table 
// - buffers    : can we move the buffers into 1 page? -> not worthwile.. this would cost an ORA in the speedcode.. also, we already moved one buffer in the page of some other data

// - speedcode  : can we write the value of column directly into ldx BufferLeft2,y?
//                this can save a ldy column: #0   <- i don't know anymore what I meant with this..

// updated:
// - saved 1 block for each shiftTable (the 2nd block was not needed by doing AND #3)
// - update BRR : maybe we don't need all those tables, can we do it with CPX like Quiss? -> YES! 6.5 block saved

.const debug        = false
.const borderColor  = $c
.const brr          = 1
.const minWidth     = 120
.const maxWidth     = 200

// settings for sprite cover
.const spritePos    = $f8
.const spriteRows   = 8

// settings for sinewave
.const sineXLength  = 64
.const sineYLength  = 64

// color settings
.const topColor     = $0
.const middleColor  = $b
.const bottomColor  = $c

.const romfont = false

#import "brr.asm"                                 // import functions to calculate the zoom steps
.var brrXZoom = getSteps(40)
.var brrYZoom = List().add(8,4,12,2,10,6,15,0,9,5,13,3,11,7,14,1)

#import "zoomscroll_calc_shadow_bottom.asm"       // import code to generate all the data for the top scroller
#import "zoomscroll_calc_shadow_top.asm"          // import code to generate all the data for the bottom scroller

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

.macro keepTime() { inc timelow; bne *+4; inc timehigh }
.label fldPhase = $43 // inherit the phase for the fld from fadein

.label firstZP       = $e0
  .label low         = $e0
  .label high        = $e1
  .label d011Low     = $e2
  .label d011High    = $e3
  .label d012Low     = $e4
  .label d012High    = $e5
  .label d012HighP   = $e6

  .label scroll2Invisible = $e9 // scroller 2 too low (FLD'ed off the screen)

  .label scroll1Low  = $ea
  .label scroll1High = $eb
  .label scroll2Low  = $ec
  .label scroll2High = $ed

  .label fldPhase1   = $ee  // store for handover of positions to loader
  .label zoomPhase1  = $ef
  .label zoomPhase2  = $f0
.label lastZP        = $f0

.label firstByte         = $2040
.label mapData1          = $2040  //..$3cb7

.label screen0           = $4000  //..$404f
.label coverSprite       = $4080  //..$40bf
.label shiftTable1       = $4100  //..$4204
// here is almost a free block!!
.label d011Table         = $4300  //..$43f8

.label screen1           = $4400  //..$444f
.label shiftTable2       = $4500  //..$4604
// here is almost a block free
.label buffer1           = $4700  //..$4780

.label screen2           = $4800  //..$484f
.label d012Table         = $4900  //..$4af8
.label conversionTable1a = $4b00  //..$4bff

.label screen3           = $4c00  //..$4c4f
.label zoomTableY        = $4c50  //..$4e80
.label conversionTable1b = $4f00  //..$4fff

.label screen4           = $5000  //..$504f
.label tables            = $5080  // 80 bytes. holds d011/d012 values for irqs
.label buffer2           = $5100  //..$5180
.label sineX             = $5180  // 64 bytes
.label sineY             = $51c0  // 64 bytes
.label conversionTable1c = $5200  //..$52ff
.label conversionTable1d = $5300  //..$53ff

.label screen5           = $5400  //..$544f
.label sineYStart        = $5480  
.label columnTable       = $5500  //..$569c
.label charWidth         = $56c0  //..$56ff 46 bytes 
// here is a free block!

.label screen6           = $5800
.label yPos1             = $5900  // this is the Y movement data for top scroll
.label yPos2             = $5a00  // this is the Y movement data for bottom scroll
// here is a free block!

.label screen7           = $5c00
// do not use the rest of screen 7..

.label charset0          = $6000
.label charset1          = $6800
.label charset2          = $7000
.label charset3          = $7800

.label conversionTables2 = $8000

#import "movement.asm"  // calculate Y movement for the scrollers

// the resulting data we need for the zoomer is :
// - startPositions           : table with start x position for each char                              =      64 bytes
// - widthsScroller           : table with width of each char                                          =      64 bytes
// - 4*convertToUniqueColumns : conversion table from column# to uniqueColumn# (equal columns removed) =    $600 bytes
// - 4*protoMaps              : holds the column data for all 4 quadrants                              =   $1b00 bytes
// - charsets 

#if AS_SPINDLE_PART
  .label spindleLoadAddress = firstByte
  *=spindleLoadAddress-18-4-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word prepare       // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word 0             // cleanup routine
    .word music_play    // location of playroutine call

    .byte 'Z', <firstZP, <lastZP
    .byte 'S'                   // declare safe loading under IO

    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2(start); jmp start
#endif


.var conversionTables1Positions = List().add(conversionTable1a, conversionTable1b, conversionTable1c, conversionTable1d)

// copy conversion tables into memory
.for (var shift=0; shift<4; shift++)
{
  * = conversionTables1Positions.get(shift) "[DATA] conversion tables for shadow down"
  
  .for (var shadow=0; shadow<9; shadow++)
  {
    .var table = protoCharToChar1b.get(shadow + shift*9)
    .fill table.size(), table.get(i)
  }
}

* = conversionTables2 "[DATA] conversion tables for shadow up"

// copy conversion tables into memory
.for (var shift=0; shift<4; shift++)
{
  .if (shift>0 ) { .align $100 }
  
  .for (var shadow=0; shadow<9; shadow++)
  {
    .var table = protoCharToChar1.get(shadow + shift*9)
    .fill table.size(), table.get(i)
  }
}

// generates the x zoom tables.
// format:
// data for column 0. 81 bytes for size 120-200 (including 200)
// data for column 1. 81 bytes..
// data for column 2. 81 bytes..
// = 243 bytes, then align to next page

/*
.align $100
* = * "[DATA] zoomtable X"
zoomTableX:
{
  .var xSteps = 40
  .var steps = getSteps(xSteps)

  forLoop: .for (var s=0; s<40;s++)
  {
    .if ((>(*+81)) != (>(*))) { * = ((>*)+1)*$100 "[DATA] zoomtable X" }
    start:

    .if (brr==0)
    {
      .for (var h=120; h<=200; h++)
      {
        .var stepSize = h/40   // if the width is 120, we have to make 40 steps of 3 pixels
        .var x = stepSize * s  // x value for this step
        .byte round(x)
      }
    }

    .if (brr==1)
    {    
      .for (var w=120; w<=200; w++)
      {
        .var integerStepSize = floor(w/xSteps)     // calculate the integer part of the steps
        .var remainder = w-xSteps*integerStepSize  // calculate the missing width if only using the integerStepSize

        .var extra = 0
        // count number of extra pixels to add
        .for (var i=0; i<s; i++)
        {
          .if (steps.get(i) < remainder)
          {
            .eval extra = extra+1
          }
        }

        .byte s*integerStepSize + extra
      }
    } // if brr==1
  } // forLoop
} // zoomTableX

*/

convertToUniqueColumn1:  * = * "[DATA] convert to unique column1";  .fill columns1.size(),  columns1.get(i)
convertToUniqueColumn2:  * = * "[DATA] convert to unique column2";  .fill columns2.size(),  columns2.get(i)
convertToUniqueColumn1b: * = * "[DATA] convert to unique column1b"; .fill columns1b.size(), columns1b.get(i)
convertToUniqueColumn2b: * = * "[DATA] convert to unique column2b"; .fill columns2b.size(), columns2b.get(i)

* = * "[CODE] main"
start:
  sei
  lda #$35
  sta $01

  ldx nextpart
  inx
  stx scroller1.resetScroller.nextPartValue

  lda fldPhase
  sta updatePositions.index

  #if !AS_SPINDLE_PART
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

    lda #$94
    sta $dd00

    lda #0
    sta timelow
    sta timehigh

    :MusicInitCall()
  #endif

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  lda #1
  sta resetIrq.bottomScrollOff
  sta scroll2Invisible

  lda #>d011Table
  sta d011High
  lda #>d012Table
  sta d012High

  #if !AS_SPINDLE_PART
    jsr prepare

    lda #borderColor
    sta $d020
    lda #middleColor
    sta $d021
  #endif

  lda #$03
  sta $d022
  lda #$0e
  sta $d023

  // select empty screen to hide bugs
  lda #($10*((screen7&$3c00)/$400)+$2*(charset0&$3800)/$800)
  sta $d018
  lda #$3d   // switch to correct bank with empty ghostbyte before setting $ffff
  sta $dd02
  
  .if (romfont)
  {
    lda #$c8
    sta $d016
  }
  else
  {
    lda #$d8
    sta $d016
  }

  lda #<scrolltext1
  sta scroll1Low
  lda #>scrolltext1
  sta scroll1High

  lda #<scrolltext2
  sta scroll2Low
  lda #>scrolltext2
  sta scroll2High

  lda #<startUpIrq
  sta $fffe
  lda #>startUpIrq
  sta $ffff
  lda #$fa
  sta $d012

  lda $d011
  and #$7f
  sta $d011

  lda #$7f
  sta $dc0d               //disable timer interrupts which can be generated by the two CIA chips
  sta $dd0d               //the kernal uses such an interrupt to flash the cursor and scan the keyboard, so we better
                          //stop it.
  lda $dc0d               //by reading this two registers we negate any pending CIA irqs.
  lda $dd0d               //if we don't do this, a pending CIA irq might occur after we finish setting up our irq.
                          //we don't want that to happen.

  jsr setSprites

  cli
  #if !AS_SPINDLE_PART
  mainLoop:
    .if (debug) { inc $d020 }
    jmp mainLoop
  #else
    rts
  #endif

prepare:
{
  ldx #19

loop:
  lda #BLUE|8
  .for (var r=0; r<2; r++) { sta $d800+r*40,x}
  lda #YELLOW|8
  .for (var r=0; r<2; r++) { sta $d814+r*40,x}

  dex
  bpl loop

  jsr calcYZoom      // todo : remove this.. can we preseed the tables?

  rts
}

.var d018Values1 = List()
.var d018Values2 = List()

.var screens = List().add(screen0, screen1, screen2, screen3, screen4, screen5, screen6, screen7)

.for (var r=0; r<8; r++)
{
  .var screen = screens.get(r)

  .eval d018Values1.add($10*((screen&$3c00)/$400)+$2*(charset0&$3800)/$800)
  .eval d018Values1.add($10*((screen&$3c00)/$400)+$2*(charset1&$3800)/$800)

  .eval d018Values2.add($10*((screen&$3c00)/$400)+$2*(charset2&$3800)/$800)
  .eval d018Values2.add($10*((screen&$3c00)/$400)+$2*(charset3&$3800)/$800)
}

setSprites:
{
  lda #$7f
  sta $d015
  lda #$18
  sta $d000
  lda #$48
  sta $d002
  lda #$78
  sta $d004
  lda #$a8
  sta $d006
  lda #$d8
  sta $d008
  lda #$08
  sta $d00a
  lda #$38
  sta $d00c

  lda #$60
  sta $d010
  lda #$00
  sta $d017 // no y stretch
  sta $d01b // priority
  lda #$ff
  sta $d01c // multicolor
  sta $d01d // x stretch

  lda #middleColor
  sta $d025
  lda #bottomColor
  sta $d026

  lda #spritePos
  sta $d001
  sta $d003
  sta $d005
  sta $d007
  sta $d009
  sta $d00b
  sta $d00d

  ldx #6
loop:
  lda #(coverSprite&$3fff)/64
  .for (var s=0; s<screens.size(); s++)
  {
    .var screen = screens.get(s)
    sta screen+$3f8,x
  }
  dex
  bpl loop
  rts
}

topIrq:
{
  dec 0
  sta atemp
  stx xtemp
  sty ytemp

  lda #<fldIrq
  sta $fffe
  lda #>fldIrq
  sta $ffff
  lda #$2f
  sta $d012
  lda #$1f
  //and #$7f
  sta $d011
  asl $d019

  lda #topColor
  sta $d021 

  .if (debug) { inc $d020 }

  keepTime()

  .if (debug) { inc $d020 }
  :MusicPlayCall()

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  inc 0
  rti
}

.const Wait = $80
.const End  = $ff

fldIrq: // first start this at raster $2f
{
  dec 0
  sta atemp

  asl $d019

  lda nrLines: #0
  cmp #7
  lda $d012  // we need the $d012 value in both branches.
  bcs setIrq
  
  // we can set d011 now and end the fld
  sec
  adc nrLines
  and #$07
  ora #$18
  sta $d011

  lda #<irq0
  sta $fffe
  lda #>irq0
  sta $ffff
  lda d012Tab1
  sta $d012

  lda atemp: #0
  inc 0
  rti

setIrq:
  // calc rasterline to trigger next irq
  // clc  // carry is alway set.. so abuse it
  adc #5  // add 5 instead of 6 because carry is set
  sta $d012

  //clc   // carry is now clear
  adc #1
  and #$07
  ora #$18
  sta $d011  // set $d011 to do an FLD

  lda nrLines // 6 lines less to fld..
  // we want to subtract 6, normally sec, sbc #6
  // but we abuse that carry is clear and sbc #5
  sbc #5
  sta nrLines

  lda atemp
  inc 0
  rti
}

.macro genIrq(i, nextIrq, color)
{
  dec 0
  sta atemp

  lda d011Tab1+i
  sta $d011

  lda #<nextIrq
  sta $fffe
  lda #>nextIrq
  sta $ffff

  lda d012Tab1+i
  sta $d012

  inc $dbff
  .if ((d018Values1.get(i) - d018Values1.get(i-1)) == 2) { inc $d018 }
  else {
    lda #d018Values1.get(i)
    sta $d018 
  }
  .if (color>=0)
  {
    lda #color
    sta $d021
  }

  .var color2 = topRasterBar.get(i-1)
  .if (color2>=0)
  {
    .if ((i>=2) && (color2==topRasterBar.get(i-2)))
    {
      // color doesnt change, do nothing
    } else 
    {
      lda #color2
      sta $d022
    }
  }

  asl $d019

  lda atemp: #0
  inc 0
  rti
}

.var topRasterBar    = List().add($d, $3, $d, $3, $3, $a, $3, $a, $a, $4, $a, $4, $4, $4)

irq0:  genIrq(1,  irq1,           -1)
irq1:  genIrq(2,  irq2,           -1)
irq2:  genIrq(3,  irq3,           -1)
irq3:  genIrq(4,  irq4,           -1)
irq4:  genIrq(5,  irq5,           -1)
irq5:  genIrq(6,  irq6,           -1)
irq6:  genIrq(7,  irq7,           -1)
irq7:  genIrq(8,  irq8,           -1)
irq8:  genIrq(9,  irq9,           -1)
irq9:  genIrq(10, irq10,          -1)
irq10: genIrq(11, irq11, middleColor)
irq11: genIrq(12, irq12,          -1)
irq12: genIrq(13, irq13,          -1)
irq13: genIrq(14, irq14,          -1)

irq14:
{
  .var i=15
  dec 0
  sta atemp

  lda d011Tab1+i
  sta $d011

  lda #<resetIrq
  sta $fffe
  lda #>resetIrq
  sta $ffff
  lda d012Tab1+14
  clc
  adc #5
  sta $d012
  asl $d019

  .if ((d018Values1.get(i) - d018Values1.get(i-1)) == 2) { inc $d018 }
  else {
    lda #d018Values1.get(i)
    sta $d018 
  }

  lda atemp: #0
  inc 0
  rti
}

resetIrq:
{
  dec 0
  sta atemp

  // reset for second scroller

  lda bottomScrollOff: #0   // scroller 2 NOT turned off
  ora scroll2Invisible      // and NOT invisible?
  beq gotoScroll2           // then go to the irq's for scroll 2

  // go directly to the irq that opens the border
  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$fa
  sta $d012

  asl $d019

  lda #$03
  sta $d022

  // stay in the last screen

  cli
  jsr update
  lda atemp
  inc 0
  rti

gotoScroll2:  
  lda #<fldIrq2
  sta $fffe
  lda #>fldIrq2
  sta $ffff

  lda d012Tab1+14
  clc
  adc #8
  sta $d012

  asl $d019

  lda #$03
  sta $d022
  lda #d018Values2.get(0)
  sta $d018

  lda atemp: #0
  inc 0
  rti
}

fldIrq2:
{
  dec 0
  sta atemp

  asl $d019

  lda nrLines: #0
  cmp #7
  lda $d012  // we need the $d012 value in both branches.
  bcs setIrq
  
  // we can set d011 now and end the fld
  sec
  adc nrLines
  and #$07
  ora #$18
  sta $d011
  
  lda #$03  // reset color
  sta $d022

  // reset for second scroller
  lda #d018Values2.get(0)
  sta $d018
  
  lda d012Tab2+0
  cmp #$f8
  bcc continue
  {
    lda atemp
    pha
    jmp breakIrq
  }
continue:
  sta $d012

  lda #<irq0b
  sta $fffe
  lda #>irq0b
  sta $ffff

  lda atemp: #0
  inc 0
  rti

setIrq:
  // calc rasterline to trigger next irq
  // clc  // carry is alway set.. so abuse it
  adc #5  // add 5 instead of 6 because carry is set
  sta $d012

  //clc   // carry is now clear
  adc #1
  and #$07
  ora #$18
  sta $d011  // set $d011 to do an FLD

  lda nrLines // 6 lines less to fld..
  // we want to subtract 6, normally sec, sbc #6
  // but we abuse that carry is clear and sbc #5
  sbc #5
  sta nrLines

  lda #$03  // reset color
  sta $d022

  // reset for second scroller
  lda #d018Values2.get(0)
  sta $d018

  lda atemp
  inc 0
  rti
}

.macro genIrq2(i, nextIrq, color)
{
  dec 0
  pha

  lda d011Tab2+i
  sta $d011

  asl $d019

  lda d012Tab2+i
  sta $d012
  // the last badline possible is in raster $f7. if the next irq is at raster f7, it's still useful to trigger it
  cmp #$f8

  lda #<nextIrq
  sta $fffe
  lda #>nextIrq
  sta $ffff

  bit $ea

  .if ((d018Values2.get(i) - d018Values2.get(i-1)) == 2) { inc $d018 }
  else {
    lda #d018Values2.get(i)
    sta $d018 
  }
  .if (color>=0)
  {
    lda #color
    sta $d021
  }

  .var color2 = bottomRasterBar.get(i-1)
  .if (color2>=0)
  {
    .if ((i>=2) && (color2==bottomRasterBar.get(i-2)))
    {
      // color doesnt change, do nothing
    } else 
    {
      lda #color2
      sta $d022
    }
  }

  bcc !+
    jmp breakIrq 
  !:
  pla
  inc 0
  rti
}

.var bottomRasterBar = List().add($4, $4, $4, $a, $4, $a, $a, $3, $a, $3, $3, $d, $3, $d)

irq0b:  genIrq2(1,  irq1b,  -1)
irq1b:  genIrq2(2,  irq2b,  -1)
irq2b:  genIrq2(3,  irq3b,  -1)
irq3b:  genIrq2(4,  irq4b,  -1)
irq4b:  genIrq2(5,  irq5b,  -1)
irq5b:  genIrq2(6,  irq6b,  -1)
irq6b:  genIrq2(7,  irq7b,  -1)
irq7b:  genIrq2(8,  irq8b,  -1)
irq8b:  genIrq2(9,  irq9b,  -1)
irq9b:  genIrq2(10, irq10b, -1)
irq10b: genIrq2(11, irq11b, bottomColor)
irq11b: genIrq2(12, irq12b, -1)
irq12b: genIrq2(13, irq13b, -1)
irq13b: genIrq2(14, irq14b, -1)

breakIrq:
{
  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$fa
  sta $d012
  cli
  jsr update

  pla
  inc 0
  rti
}

irq14b:
{
  .var i=15
  dec 0
  sta atemp

  lda d011Tab2+i
  sta $d011

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$fa
  sta $d012
  asl $d019
  inc $dbff

  .if ((d018Values2.get(i) - d018Values2.get(i-1)) == 2) { inc $d018 }
  else {
    lda #d018Values2.get(i)
    sta $d018 
  }

  cli
  jsr update

  lda atemp: #0
  inc 0
  rti
}

update:
{
  stx xtemp
  sty ytemp

  jsr updatePositions

  .if (debug) { inc $d020 }

  jsr calcYZoom

  // calculate : at what rasterline is the $d021 split?
  // question : isn't this the value for the next frame instead?!?

  ldy #0                // 0 - updating d021 in the border is not needed

  // if the bottom scroller is off, do not update $d021 and go to topIrq directly
  lda resetIrq.bottomScrollOff
  beq checkD012  // scroller is on, check where the split should happen

  // the scroller is off.. 

  ldx #middleColor
  lda #$40              // but put the split at rasterline > $137 (so the split never happens)
  bne writeBorderColor  // write values

  // the scroller is on..

checkD012:
  lda scroll2Invisible  // if the scroller is invisible, then we have to keep the middle color
  bne keepMiddleColor

  lda d012Tab2+10
  ldx #bottomColor

  // if the split is between rasterlines $f8-$ff, the split is plotted in the sprite
  // so afterwards, we have to show the bottomColor
  
  cmp #$f8
  bcs writeBorderColor  // between $f8 and $ff? write bottomColor to $d021

  // did an overflow occur? then it's definitely in the border and we have to keep the middleColor and update later

  cmp d012Tab2+0
  bcs writeBorderColor  // the value at d012Tab+10 is higher than at d012Tab+0, so there is no overflow. write middleColor
  
keepMiddleColor:
  // the split should happen at rasterline > $100, so keep the middleColor
  ldx #middleColor
  iny  // enable extra irq to do the d021 split
  lda d012Tab2+10

writeBorderColor:
  sta irq.updateD021Raster
  stx irq.borderColor
  sty irq.updateD021

  // update the cover sprite
  //lda d012Tab2+10
  sec
  sbc #$f8
  tax
  jsr updateCoverSprite

  .if (debug) { inc $d020 }

  // do not plot the scrollers if the part has ended
  // we have to turn the plotting off, otherwise we can not cleanly proceed to the next part
  lda irq.nextPartValue
  bne skip

  jsr speedcode1

  // don't plot the bottom scroller if it's turned off or invisible
  lda resetIrq.bottomScrollOff  // is it turned off?
  ora scroll2Invisible          // or invisible because it is moved too low?
  bne !+

    jsr speedcode2
    jmp skip

!:
  // clear the bottom scroller
  ldx #39
  lda #0
loop:
  sta screen7+40,x
  dex
  bpl loop

skip:
  // calc scroller and x zoom for next frame
  .if (debug) { inc $d020 }
  jsr scroller1
  jsr scroller2

  .if (debug) { inc $d020 }

  jsr calcXZoom1Fast
  jsr calcXZoom2Fast

  .if (debug) 
  { 
    lda #borderColor
    sta $d020
  }

  ldx xtemp: #0
  ldy ytemp: #0
  rts
}

updatePositions:
{
  // move top scroller in Y
  inc index
  ldx index: #startRept1

  // stay in the first repeating movement?
  lda repeat1: #1
  beq skip1
  {
    cpx #endRept1       // check end of the first part of the movement
    bcc skip1
      ldx #startRept1   // reset if necessary
      stx index
  }
skip1:

  cpx #endRept2         // check end of the second part of the movement
  bcc !+
  {
    ldx #startRept2     // reset if necessary
    stx index
  } !:
  stx fldPhase1

  lda yPos1,x
  sta fldIrq.nrLines

  // move bottom scroller in Y
  lda yPos2,x
  sta fldIrq2.nrLines

  rts
}

updateCoverSprite:
{
  // x is pixelrow to switch

  // if x is negative, switch at row 0
  cpx #$80
  bcc !+
    ldx #0
  !:

  lda #$55

  .for (var i=0; i<spriteRows; i++)
  {
    cpx #i
    bne !+
      lda #$ff
    !:
    sta coverSprite+i*3
    sta coverSprite+i*3+1
    sta coverSprite+i*3+2
  }

  rts
}

// this is IRQ to start the part, it will turn the screen off
startUpIrq:
{
  dec 0
  sta atemp
  stx xtemp
  sty ytemp
  
  lda #$90  // open border for 'design'
  sta $d011

  lda #<topIrq
  ldx #>topIrq
  ldy #$37

  sta $fffe
  stx $ffff
  sty $d012

  jsr updatePositions
  jsr calcYZoom1

  lda #$80 // turn screen off to hide bugs in the first frame
  sta $d011

  asl $d019
  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  inc 0
  rti
}

irq:
{
  dec 0
  sta atemp
  stx xtemp
  sty ytemp

  lda #$90  // open border for 'design'
  sta $d011

  lda borderColor: #0
  sta $d021

  // reset y zoomer
  lda #d018Values1.get(0)
  sta $d018
  lda #topRasterBar.get(0)
  sta $d022

  // if we do not have to update d021, go to topIrq directly
  lda updateD021: #0
  bne toRasterIrq

  lda nextPartValue: #0
  sta nextpart

  .if (debug) 
  { 
    lda #borderColor
    sta $d020
  }
toTopIrq:
  lda #<topIrq
  ldx #>topIrq
  ldy #$37
endIrq:
  sta $fffe
  stx $ffff
  sty $d012

  asl $d019
  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  inc 0
  rti

toRasterIrq:
  ldy updateD021Raster: #$10
  cpy #(spritePos+21)
  bcs toRasterIrq2

  // jump to irq where sprites steal cycles
  lda #<rasterIrq
  ldx #>rasterIrq
  bne endIrq

toRasterIrq2:
  cpy #$35        // check if the rasterbar is too low on the screen
  bcs toTopIrq    // if so, jump directly to topIrq instead
  
  // jump to irq without sprites
  lda #<rasterIrq2
  ldx #>rasterIrq2
  bne endIrq
}

// this IRQ is for the rasters where sprites steal cycles
rasterIrq:
{
  dec 0
  sta atemp

  lda #<topIrq
  sta $fffe
  lda #>topIrq
  sta $ffff

  lda $d011
  ora #$80
  sta $d011

  nop

  lda #bottomColor
  sta $d021

  lda #$37
  sta $d012

  asl $d019

  lda atemp: #0
  inc 0
  rti
}

// this IRQ is for the rasters without sprites stealing cycles
rasterIrq2:
{
  dec 0
  sta atemp

  lda #<topIrq
  sta $fffe
  lda #>topIrq
  sta $ffff

  lda $d011
  ora #$80
  sta $d011
  lda #$37
  sta $d012

  asl $d019
  //nop
  //nop

  lda #bottomColor
  sta $d021

  lda atemp: #0
  inc 0
  rti
}

* = * "[CODE] scroll 1"
scroller1:
{
  .if (debug)
  {
    lda $dc01
    and #$10
    beq skipAdvance
  }

  // scroll it
  lda scrollLow: #0
  clc
  adc #$0
  sta scrollLow
  lda calcXZoom1Fast.scrollHigh
  adc scrollSpeed: #2             // this is in multicolor pixels/frame
  sta calcXZoom1Fast.scrollHigh
skipAdvance:
  lda calcXZoom1Fast.scrollHigh
  // determine if a new column needs to be added
  lsr
  lsr
  cmp oldColumn: #0
  bne addColumn
  rts
addColumn:
  sta oldColumn
setColumn:
  ldy currentColumn: #0
  cpy maxColumn:     #0
  beq nextChar

  // write column into buffer
  ldx bufferpos: #$3f

  // read the unique column to write
  lda readUnique1b: convertToUniqueColumn1b,y
  sta bufferLeft1,x
  lda readUnique2b: convertToUniqueColumn2b,y
  sta bufferRight1,x
  
  // next position in the buffer
  lda #$3f
  inx
  sax bufferpos

  inc currentColumn
  bne end
  inc readUnique1b+1
  inc readUnique2b+1

end:
  rts  

nextChar:
  inc scroll1Low
  bne !+
    inc scroll1High
  !:

  ldy #0
  lda (scroll1Low),y
  bpl setChar

  cmp #$80           // scroll speed 2?
  bne !+
  {
    lda #2
    sta scroller1.scrollSpeed
    bne nextChar  
  } !:

  cmp #$81           // scroll speed 3?
  bne !+
  {
    lda #3
    sta scroller1.scrollSpeed
    bne nextChar  
  } !:

  cmp #$82           // scroll speed 4?
  bne !+
  {
    lda #4
    sta scroller1.scrollSpeed
    bne nextChar  
  } !:

  cmp #$83           // turn on zoom of scroll1?
  bne !+
  {
    lda calcYZoom1.zoom1
    bne zoomAlreadyOn
    // turn on zoom of top scroller
    lda #1
    sta calcYZoom1.zoom1 

    // start at biggest size
    lda #16
    sta calcYZoom1.index
    lda #16+32+1
    sta calcXZoom1Fast.index
  zoomAlreadyOn:
    bne nextChar
  } !:

  cmp #$84           // turn on scroll2?
  bne !+
  {
    lda #0
    sta resetIrq.bottomScrollOff   // turn on scroller 2
    beq nextChar
  } !:

  cmp #$85
  bne !+
  {
    lda #0
    sta updatePositions.repeat1             // go the next part of movement
    beq nextChar
  }!:

  cmp #$ff        // reset scroller?
  bne setChar     // no, go to the next char
  resetScroller: {
    lda nextPartValue: #0
    sta irq.nextPartValue

    lda #<scrolltext1
    sta scroll1Low
    lda #>scrolltext1
    sta scroll1High

    lda (scroll1Low),y
  }
setChar:
  tay

  lda charStartHigh,y
  clc
  adc #>convertToUniqueColumn1b
  sta readUnique1b+1

  lda charStartHigh,y
  clc
  adc #>convertToUniqueColumn2b
  sta readUnique2b+1
  sta readUnique3b+1

  lda charStart,y
  sta currentColumn
  clc
  adc charWidth,y
  sta maxColumn

  // fix left column in buffer right
  ldx bufferpos
  dex
  bpl !+
  ldx #$3f
!:
  ldy currentColumn
  beq !+
    dey
  !:
  lda readUnique3b: convertToUniqueColumn2b,y
  sta bufferRight1,x

  jmp setColumn
}

* = * "[CODE] scroll 2"
scroller2:
{
  .if (debug)
  {
    lda $dc01
    and #$10
    beq skipAdvance
  }

  lda resetIrq.bottomScrollOff
  beq scroll
  rts
scroll:
  // scroll it
  lda scrollLow: #0
  clc
  adc #$0
  sta scrollLow
  lda calcXZoom2Fast.scrollHigh
  adc #2         // this is in multicolor pixels/frame
  sta calcXZoom2Fast.scrollHigh
skipAdvance:
  lda calcXZoom2Fast.scrollHigh
  // determine if a new column needs to be added
  lsr
  lsr
  cmp oldColumn: #0
  bne addColumn
  rts
addColumn:
  sta oldColumn
setColumn:
  ldy currentColumn: #0
  cpy maxColumn:     #0
  beq nextChar

  // write column into buffer
  ldx bufferpos: #$3f
  lda readUnique1: convertToUniqueColumn1,y
  sta bufferLeft2,x
  lda readUnique2: convertToUniqueColumn2,y
  sta bufferRight2,x
  
  // next position in the buffer
  lda #$3f
  inx
  sax bufferpos

  inc currentColumn
  bne end
  inc readUnique1+1
  inc readUnique2+1
end:
  rts  

nextChar:
  inc scroll2Low
  bne !+
    inc scroll2High
  !:

  ldy #0
  lda (scroll2Low),y

  cmp #$ff        // reset scroller?
  bne setChar

  lda #<scrolltext2
  sta scroll2Low
  lda #>scrolltext2
  sta scroll2High

  lda (scroll2Low),y
setChar:
  tay

  lda charStartHigh,y
  clc
  adc #>convertToUniqueColumn1
  sta readUnique1+1

  lda charStartHigh,y
  clc
  adc #>convertToUniqueColumn2
  sta readUnique2+1
  sta readUnique3+1

  lda charStart,y
  sta currentColumn
  clc
  adc charWidth,y
  sta maxColumn

  // fix left column in buffer right
  ldx bufferpos
  dex
  bpl !+
  ldx #$3f
!:
  ldy currentColumn
  beq !+
    dey
  !:
  lda readUnique3: convertToUniqueColumn2,y
  sta bufferRight2,x

  jmp setColumn
}

  // normally 160 multicolor pixels are visible
  // when maximally zoomed in, there are 3 multicolor pixels per char
  // so a minimal value of 40*3 = 120 multicolor pixels
  // when maximally zoomed out, there are 5 multicolor pixels per char
  // so a mximale value of 40*5 = 200 multicolor pixels
  // to store all combinations would cost (200-120)*40 = 3200 bytes


* = * "[CODE] fast calcXZoom 1"
calcXZoom1Fast:
{    
  lda calcYZoom1.zoom1
  bne stepZoom
  // do not zoom.. set index to 100% zoom
  ldx sineX
  bpl continue

stepZoom:
  // don't use fixed size.. continue zooming
  
  // are we in startup phase?
  ldy startIndex: #0
  cpy #(sineXStartEnd - sineXStart)
  beq normalZooming  // startup has ended, go to normal zooming
  {
    inc startIndex
    ldx sineXStart,y
    bpl continue
  }
  
normalZooming:
  inc index
  ldy index: #32+16
  cpy #sineXLength
  bcc !+
    ldy #0
    sty index
  !:
  ldx sineX,y
  //ldx #0  // test fixed size
continue:
  cpx #40
  bcs BRRRoutine40_80  // both routines can handle size 40, but the routine for 40_80 is a bit faster
    jmp BRRRoutine0_40

BRRRoutine40_80:
  // BRR routine for sizes 40-80
  ldy scrollHigh: #0

  .for (var c=0; c<40; c++)
  {
    .if (c>0)
    {
      cpx #(brrXZoom.get(c)+41)
      bcc !+
        iny
      !:
    }
    lda columnTable+c*4,y               // add 3 pixels every column (2nd version + c*4)
    //.if (c<22) { ora #<bufferLeft1 }  // read from the correct buffer - columns 0-21 read bufferLeft1, columns 22-39 read bufferRight1
    .if (c>=22) { ora #<bufferRight1 }  // read from the correct buffer - columns 0-21 read bufferLeft1, columns 22-39 read bufferRight1
    sta speedcode1.forLoop[c].column
    //lda shiftTable1+((c*4)&3),y       // read correct shift state  (2nd version + c*4)
    lda shiftTable1,y                   // (c*4)&3 == 0
    sta speedcode1.forLoop[c].shift
  }
  rts

BRRRoutine0_40:
  ldy scrollHigh

  .for (var c=0; c<40; c++)
  {
    .if (c>0)
    {
      cpx #(brrXZoom.get(c)+1)
      bcc !+
        iny
      !:
    }
    lda columnTable+c*3,y              // add 3 pixels every column (2nd version + c*4)
    //.if (c<22) { ora #<bufferLeft1 }  // read from the correct buffer - columns 0-21 read bufferLeft1, columns 22-39 read bufferRight1
    .if (c>=22) { ora #<bufferRight1 }  // read from the correct buffer - columns 0-21 read bufferLeft1, columns 22-39 read bufferRight1
    sta speedcode1.forLoop[c].column
    lda shiftTable1+((c*3)&3),y        // read correct shift state  (2nd version + c*4)
    sta speedcode1.forLoop[c].shift
  }
  rts
}

* = * "[CODE] fast calcXZoom 2"
calcXZoom2Fast:
{
  inc index
  ldy index: #10+20+1
  cpy #sineXLength
  bcc !+
    ldy #0
    sty index
  !:

  ldx sineX,y
  //ldx #0  // test fixed size

  cpx #40
  bcs BRRRoutine40_80  // both routines can handle size 40, but the routine for 40_80 is a bit faster
    jmp BRRRoutine0_40

BRRRoutine40_80:
  // BRR routine for sizes 40-80
  ldy scrollHigh: #0

  .for (var c=0; c<40; c++)
  {
    .if (c>0)
    {
      cpx #(brrXZoom.get(c)+41)
      bcc !+
        iny
      !:
    }
    lda columnTable+c*4,y              // add 3 pixels every column (2nd version + c*4)
    //.if (c<22) { ora #<bufferLeft2 } // read from the correct buffer - columns 0-21 read bufferLeft2, columns 22-39 read bufferRight2
    .if (c>=22) { ora #<bufferRight2 } // read from the correct buffer - columns 0-21 read bufferLeft2, columns 22-39 read bufferRight2
    sta speedcode2.forLoop[c].column
    lda shiftTable2,y                  // lda shiftTable2+((c*4)&3),y, but (c*4)&3 == 0
    sta speedcode2.forLoop[c].shift
  }
  rts

BRRRoutine0_40:
  ldy scrollHigh

  .for (var c=0; c<40; c++)
  {
    .if (c>0)
    {
      cpx #(brrXZoom.get(c)+1)
      bcc !+
        iny
      !:
    }
    lda columnTable+c*3,y              // add 3 pixels every column (2nd version + c*4)
    //.if (c<22) { ora #<bufferLeft2 } // read from the correct buffer - columns 0-21 read bufferLeft2, columns 22-39 read bufferRight2
    .if (c>=22) { ora #<bufferRight2 } // read from the correct buffer - columns 0-21 read bufferLeft2, columns 22-39 read bufferRight2
    sta speedcode2.forLoop[c].column
    lda shiftTable2+((c*3)&3),y        // read correct shift state  (2nd version + c*4)
    sta speedcode2.forLoop[c].shift
  }
  rts
}

calcYZoom:
calcYZoom1:
{
  lda fldIrq.nrLines
  sta d011Low
  sta d012Low

  lda zoom1: #0
  bne stepZoom
  // do not zoom.. set index to 100% zoom
  ldx sineY
  bpl continue2

stepZoom:
  // don't use fixed size.. continue zooming

  // are we in startup phase?
  ldy startIndex: #0
  cpy #(sineYStartEnd - sineYStart)
  beq normalZooming  // startup has ended, go to normal zooming
  {
    inc startIndex
    ldx sineYStart,y
    bne continue2
  }

normalZooming:
  inc index
  ldy index: #16  // start at maximum zoom, we got at the maximum from the startup
  cpy #sineYLength
  bcc !+
    ldy #0
    sty index
  !:
continue:
  sty zoomPhase1
  ldx sineY,y  // x is the size. the size is 48-80, but is transformed to 0-32
continue2:
  //ldx #80-48 // test fixed size
  .for (var step=0; step<15; step++)
  {
    ldy zoomTableY+(step+1)*(80-48+1),x  // read the y value for this step
    lda (d011Low),y
    sta d011Tab1+step+1  // last read is d011Tab1+15
    lda (d012Low),y
    sta d012Tab1+step    // last read is d012Tab1+14
  }

  // set y position for the 2nd scroller
  ldx #0               // high byte of y position of 2nd scroller
  tya                  // height of top scroller
  clc
  adc fldIrq.nrLines   // plus # of fld lines for top scroller

  bcc !+
    clc
    inx
  !:
  
  adc #8               // plus 1 empty line
  
  bcc !+
    clc
    inx
  !:
  
  adc fldIrq2.nrLines  // plus # of fld lines for bottom scroller
  sta d011Low
  sta d012Low

  bcc !+
    clc
    inx
  !:
  stx d012HighP        // bit 9 of $d012 value   todo : is it used?

  // determine if scroller 2 is invisible because it is too low
  // ----------------------------------------------------------

  stx scroll2Invisible    // if bit 9 of $d012 is 1, the scroller surely is invisible
  cmp #($f7-$2f)          // $2f is added when calculating the d012 table, so subtract it for the comparison
  bcc !+
    inc scroll2Invisible  // d012 > $00f8, so it is covered by the sprites
  !:

  //rts
}

calcYZoom2:
{
  inc index
  ldy index: #32+10+20 // out of phase from calcYZoom1

  cpy #sineYLength
  bcc !+
    ldy #0
    sty index
  !:

  sty zoomPhase2

  ldx sineY,y  // x is the size. the size is 48-80, but is transformed to 0-32
  .for (var step=0; step<15; step++)
  {
    ldy zoomTableY+(step+1)*(80-48+1),x  // read the y value for this step
    lda (d011Low),y
    sta d011Tab2+step+1  // last read is d011Tab1+15
    lda (d012Low),y
    sta d012Tab2+step    // last read is d012Tab1+14
  }
  rts
}

// this table tells the speedcode what shadow to apply
.var shadowVersion = List().add(0,0,0,0,
                                1,1,1,1,1,
                                2,2,2,2,
                                3,3,3,3,3,
                                4,4,4,4,     // this is shadow straight up/down
                                5,5,5,5,5,
                                6,6,6,6,
                                7,7,7,7,7,
                                8,8,8,8)

* = * "[CODE] speedcode 1"
speedcode1:
{
  .if (debug) { inc $d020 }
  .var previousShadow = -1

  // speedcode
  forLoop: .for (var c=0; c<40; c++)
  {
    // what shadow version?
    .var shadow = shadowVersion.get(c)

    // new shadow version? adapt low byte accordingly
    .if (shadow != previousShadow)
    {
      .eval previousShadow = shadow

      lda #(shadow * conversionTableLength1)
      sta low
    }

    // and the needed shift for this column
    lda shift: #>conversionTable1a
    sta high

    ldx column: bufferRight1                    // x = what column should we plot?

    .for (var r=0; r<8; r++)
    {
      .var screen = screens.get(r)           // read what screen to plot to

      .if (c<22)  { ldy mapData1+(r*nrUniqueColumns1b),x } // read proto char, depending on the shadow to display
      .if (c>=22) { ldy mapData2+(r*nrUniqueColumns2b),x } // read proto char, depending on the shadow to display

      lda (low),y                            // read the char to plot depening on the shift
      sta screen+c
    }
  }
  rts
}


* = * "[CODE] speedcode 2"
speedcode2:
{
  .if (debug) { inc $d020 }

  .var previousShadow = -1

  // speedcode
  forLoop: .for (var c=0; c<40; c++)
  {
    // what shadow version?
    .var shadow = shadowVersion.get(c)

    // new shadow version? adapt low byte accordingly
    .if (shadow != previousShadow)
    {
      .eval previousShadow = shadow

      lda #(shadow * conversionTableLength1)
      sta low
    }

    // and the needed shift for this column
    lda shift: #>conversionTables2
    sta high

    ldx column: bufferRight2                    // x = what column should we plot?

    .for (var r=0; r<8; r++)
    {
      .if (c<22)  { ldy mapData3+(r*nrUniqueColumns1),x } // read proto char, depending on the shadow to display
      .if (c>=22) { ldy mapData4+(r*nrUniqueColumns2),x } // read proto char, depending on the shadow to display

      lda (low),y                            // read the char to plot depening on the shift

      .var screen = screens.get(r)           // read what screen to plot to
      sta screen+c+40
    }
  }
  rts
}

// A = scroll speed 2
// B = scroll speed 3
// C = scroll speed 4
// D = turn zoom scroll 1 on
// E = turn scroll 2 on

.var  scroll10 = " B it is time to trim the fat.          ADand -=element*54*=- will show the way.        don%t EforgetF to code, pixel and compose  and to beat us at -x2028-           @"
.eval scroll10 = " B we are here to lift the hex.        A-=Delement*54*=- is just 4 no need for more.  don%t EforgetF to code, paint and compose  and to beat us at x2028            @"
.var scroll1 = scroll10

.memblock "[DATA] scrolltext 1"
scrolltext1:
.for (var i=0; i<scroll1.size(); i++) { .byte charToByte(scroll1.charAt(i)) }

.var scroll20 = " [[[[[[[[[[[[[ make it look effortless and...   beat us at x2028           @"
.var scroll2  = scroll20

.memblock "[DATA] scrolltext 2"
scrolltext2:
.for (var i=0; i<scroll2.size(); i++) { .byte charToByte(scroll2.charAt(i)) }


// ----------------------------------------------------------
// the data from here gets sandwiched between the screen data
// ----------------------------------------------------------

* = charset0 "[GFX] charset (top half) shadow down"
.if (romfont)
{
  .var data = LoadBinary("./includes/romfont.bin")
  .for (var ch=0; ch<256; ch++)
  {
    .byte data.get(ch*8 + 0)
    .byte data.get(ch*8 + 1)
    .byte data.get(ch*8 + 2)
    .byte data.get(ch*8 + 3)
    .byte data.get(ch*8 + 3)
    .byte 0,0,0
  }
}
else
{
  .for (var ch=0; ch<(uniqueChars2.size()/8); ch++)
  {
    .byte uniqueChars2.get(ch*8 + 0)
    .byte uniqueChars2.get(ch*8 + 1)
    .byte uniqueChars2.get(ch*8 + 2)
    .byte uniqueChars2.get(ch*8 + 3)
    .byte uniqueChars2.get(ch*8 + 3)
    .byte 0,0,0
  }
}

* = charset1 "[GFX] charset (bottom half) shadow down"
.if (romfont)
{
  .var data = LoadBinary("./includes/romfont.bin")
  .for (var ch=0; ch<256; ch++)
  {
    .byte data.get(ch*8 + 4)
    .byte data.get(ch*8 + 5)
    .byte data.get(ch*8 + 6)
    .byte data.get(ch*8 + 7)
    .byte data.get(ch*8 + 7)
    .byte 0,0,0
  }
}
else
{
  .for (var ch=0; ch<(uniqueChars2.size()/8); ch++)
  {
    .byte uniqueChars2.get(ch*8 + 4)
    .byte uniqueChars2.get(ch*8 + 5)
    .byte uniqueChars2.get(ch*8 + 6)
    .byte uniqueChars2.get(ch*8 + 7)
    .byte uniqueChars2.get(ch*8 + 7)
    .byte 0,0,0
  }
}

* = charset2 "[GFX] charset (top half) shadow up"
.for (var ch=0; ch<(uniqueChars.size()/8); ch++)
{
  .byte uniqueChars.get(ch*8 + 0)
  .byte uniqueChars.get(ch*8 + 1)
  .byte uniqueChars.get(ch*8 + 2)
  .byte uniqueChars.get(ch*8 + 3)
  .byte uniqueChars.get(ch*8 + 3)
  .byte 0,0,0
}

* = charset3 "[GFX] charset (bottom half) shadow up"
.for (var ch=0; ch<(uniqueChars.size()/8); ch++)
{
  .byte uniqueChars.get(ch*8 + 4)
  .byte uniqueChars.get(ch*8 + 5)
  .byte uniqueChars.get(ch*8 + 6)
  .byte uniqueChars.get(ch*8 + 7)
  .byte uniqueChars.get(ch*8 + 7)
  .byte 0,0,0
}

* = mapData1 "[DATA] protochar map 1 shadow down (top scroller, left side of screen)"
  .fill compressedProtoMap1b.size(), compressedProtoMap1b.get(i)

mapData2: * = * "[DATA] protochar map 2 shadow down (top scroller, right side of screen)"
  .fill compressedProtoMap2b.size(), compressedProtoMap2b.get(i)

mapData3: * = * "[DATA] protochar map 2 shadow up (left side of screen)"
  .fill compressedProtoMap1.size(), compressedProtoMap1.get(i)

mapData4: * = * "[DATA] protochar map 2 shadow up (right side of screen)"
  .fill compressedProtoMap2.size(), compressedProtoMap2.get(i)

* = sineY "[DATA] sine (height)"
{
  .var sinMin = 48-48
  .var sinMax = 80-48
  .var sinAmp = 0.5 * (sinMax-sinMin)
  .var sinLength = sineYLength
  .fill sinLength, (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength))
}

#import "sineStart.asm"
* = sineYStart "[DATA] sine (height) startup"
{
  .fill positions.size(), positions.get(i)
}
sineYStartEnd:

sineXStart:
* = * "[DATA] sine (width) startup"
{
  .fill xPositions.size(), xPositions.get(i)
}
sineXStartEnd:

* = sineX "[DATA] sine (width)"
{
  .var sinMin = 120-120
  .var sinMax = 200-120
  .var sinAmp = 0.5 * (sinMax-sinMin)
  .var sinLength = sineXLength
  .fill sinLength, (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength))
}

* = charWidth "[DATA] width of chars"
.fill widthsScroller.size(), widthsScroller.get(i)

* = * "[DATA] char start column"
charStart:
.fill startPositions.size(), <startPositions.get(i)
charStartHigh:
.fill startPositions.size(), >startPositions.get(i)

* = zoomTableY "[DATA zoomtable]"

// this is generated brr steps list : [0,8,4,12,2,10,6,14,1,9,5,13,3,11,7,15], we use a hand modified one in the end

.if (brr==1)
{
  .var ySteps = 16
  .var steps = List().add(8,4,12,2,10,6,15,0,9,5,13,3,11,7,14,1)
  .for (var s=0; s<=ySteps; s++) // loop over all the steps in the zoom
  {
    .for (var h=48; h<=80; h++)
    {
      .var integerStepSize = floor(h/ySteps)       // calculate the integer part of the steps
      .var remainder = h-(ySteps*integerStepSize)  // calculate the missing height if only using the integerStepSize

      .var extra = 0
      // count number of extra pixels to add
      .for (var i=0; i<s; i++)
      {
        .if (steps.get(i) < remainder)
        {
          .eval extra = extra+1
        }
      }

      .byte s*integerStepSize + extra    // // calculate the height at this step
    }
  }
}

* = d011Table "[DATA] d011 table"
.for (var i=0; i<256-8; i++) { .byte (($18+i)&$7)|$18 }

* = d012Table "[DATA] d012 table"
.for (var i=0; i<512-8; i++) { .byte $2f+i }

* = columnTable "[DATA] column table"
.for (var i=0; i<(39*4+256); i++) { .byte floor(i/4) & $3f }

* = shiftTable1 "[DATA] shift table"
.for (var i=0; i<$104; i++) { .byte >(conversionTables1Positions.get(i&3)) }

* = shiftTable2 "[DATA] shift table2"
.for (var i=0; i<$104; i++) { .byte (i&3) + (>conversionTables2) }

// this is a cyclical buffer pointing to columns in the protochar map
* = buffer1 "[GEN] buffer 1"
bufferLeft1:  .fill 64,0
bufferRight1: .fill 64,0

* = buffer2 "[GEN] buffer 2"
bufferLeft2:  .fill 64,0
bufferRight2: .fill 64,0

* = tables "[GEN] irq d011/d012 tables"
d011Tab1: .fill 20,$1b
d012Tab1: .fill 20,0
d011Tab2: .fill 20,$1b
d012Tab2: .fill 20,0

* = coverSprite "[GFX] coversprite"
.fill 3*spriteRows, $55
.fill 3*(21-spriteRows), 0

// ------------------------------------
// from here there is only virtual data
// ------------------------------------

// occupy data for screens
.for (var s=0; s<screens.size(); s++)
{
  .var screen = screens.get(s)
  .if (screen==screen7)
  {
    * = screen "[GFX] screen 7"
    .fill 1000,0
  } else
  {
    * = screen "[GFX] screen" virtual
    .fill 80,0
  }
}