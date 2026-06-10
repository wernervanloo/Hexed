// hammerfist - roze, donkergrijs
// genius     - zwart, blauw
// wvl        - donkergrijs, cyaan
// youth      - oranje, bruin

#import "../00.music/music2.asm"
#import "portraits.asm"

.const findBug          = false

.const border           = DARK_GREY
.const background       = LIGHT_RED

.const nrHandles        = 5
.const handleHeight     = 4 // in charrows
.const debug            = false

// load handle graphics
                                                       // bitpairs $d021,   $d022,   $d023,   $d800
.var handles1 = LoadPicture("./includes/handles4b.png", List().add($68372B, $ffffff, $9A6759, $000000))
.var handles2 = LoadPicture("./includes/handles5.png", List().add($68372B, $ffffff, $9A6759, $000000))

.function convertPNG(handles)
{
  // create the list with unique chars
  .var emptyChar   = List().add($0,$0,$0,$0,$0,$0,$0,$0)  // the empty chars is special
  .var uniqueChars = List().addAll(emptyChar)     // add empty char first
  .var screenData  = List()
  .for (var r=0; r<(handles.height/8); r++)
  {
    .for (var c=0; c<(handles.width/8); c++)
    {      
      // read char
      .var char = List()
      .for (var byte=0; byte<8; byte++)
      {
        .var value = handles.getMulticolorByte(c,r*8+byte)
        .eval char.add(value)
      }

      .var same = 1
      // is this a new char?
      .for (var i=0; i<(uniqueChars.size()/8); i++)
      {
        .eval same = 1
        .for (var byte=0; byte<8; byte++) { .if (uniqueChars.get(i*8+byte)!=char.get(byte)) { .eval same = 0 } }

        // is the char already in the set?
        .if (same==1)
        {
          // yes.. add the char to the screen
          .if (i==0) { .eval i=10 } // special : use $0a as empty character
          .eval screenData.add(i)

          // and break the loop
          .eval i = uniqueChars.size()/8
        }
      }

      // if we didn't find the char, add it
      .if (same==0)
      {
        // add char to the screen
        .eval screenData.add(uniqueChars.size()/8)

        // add char to the charset
        .eval uniqueChars.addAll(char)

        // special : we want character #10 to be empty.
        .if ((uniqueChars.size()/8)==10)
        {
          .eval uniqueChars.addAll(emptyChar) 
        }
      }
    }
  }

  .print ("nrChars : " + uniqueChars.size()/8)

  .var result = List().add(uniqueChars, screenData)
  .return result
}

// ------------------------------------
// convert picture into charset and map
// ------------------------------------

.var handleData1  = convertPNG(handles1)
.var uniqueChars1 = handleData1.get(0)
.var screenData1  = handleData1.get(1)

.var handleData2  = convertPNG(handles2)
.var uniqueChars2 = handleData2.get(0)
.var screenData2  = handleData2.get(1)

.label firstByte      = $4000
.label handleScreen   = $4000
.label code           = handleScreen+nrHandles*handleHeight*40
.label charset1       = $5000
.label charset2       = $5800
.label sprite         = $59c0
//.label handleScreen   = $5c00
.label bitmap1        = $6000 // virtual
.label screen1        = $7c00 // virtual
.label gfx            = $8000 // binary load (separate)
.label picture0Bitmap = gfx

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart  = $02
.label timelow   = $03
.label timehigh  = $04
.label demostate = $05 // mark if we started from this side or not

.label firstZP  = $20
.label yPos      = $20
.label jmpIrq    = $21 // $21,$22,$23
.label lastZP   = $23

#if AS_SPINDLE_PART
  .label spindleLoadAddress = firstByte
  *=spindleLoadAddress-18-19-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word prepare       // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word 0             // cleanup routine
    .word 0             // location of playroutine call

    .byte 'S'                             // declare safe loading under IO
    .byte 'M', <music.play, >music.play
    .byte 'Z', <firstZP, <lastZP          // declare zeropage use
    .byte 'P', >screen1, >(screen1+$3ff)  // declare use of screen
    .byte 'P', >bitmap1, >(bitmap1+$1f40) // declare use of bitmap
    // avoid loading too much
    .byte 'P', >$2000, >$3fff             // do not load $2000-$3fff at first..
    .byte 'I', >$b000, >$efff             // do not load too much

    .byte 0
    .word spindleLoadAddress     // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2($080e); sei; lda #$35; sta $01; jmp start
#endif

* = code "[CODE]"
start:
{
  sei

  #if !AS_SPINDLE_PART
    lda #$1f
    sta nextpart
  #endif

  #if AS_SPINDLE_PART
    lda $01
    sta restore01
  #endif

  lda #$35
  sta $01

  lda #0
  sta timelow
  sta timehigh
  jsr music.init

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

    jsr prepare
  #endif

  lda #0
  sta $7fff

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  lda #<jmpIrq
  sta $fffe
  lda #>jmpIrq
  sta $ffff

  lda #JMP_ABS
  sta jmpIrq
  lda #<startUpIrq
  sta jmpIrq+1
  lda #>startUpIrq
  sta jmpIrq+2

  lda #$fa
  sta $d012

  lda $d011
  and #$78
  sta $d011

  lda #$d0
  sta $d016

  lda $d021
  sta topIrq.setBackground
  //lda #border
  //sta $d020
  //lda #background
  //sta $d021

  //lda #WHITE
  //sta $d022
  //lda #PURPLE
  //sta $d023

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
    cmp ($00,x)
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
    lda #$00
    lda #$ff
    .for (var i=0; i<$18; i++) { sta bitmap1+i*$100,x } // clear bitmap
    lda #background
    .for (var i=0; i<4;   i++) { sta $d800+i*$100,x   } // clear colors
    lda #0                                              // empty char
    .for (var i=$18; i<$1c; i++) { sta bitmap1+i*$100,x } // clear bitmap with 0 to avoid bugs
    .for (var i=0; i<4;   i++) { sta screen1+i*$100,x } // clear screenRam
    inx
    bne loop
  } 
  
  // test handles..
  ldx #$7f
  {
  lda #BLACK|8
  loop:
    sta $d800+20*40,x
    sta $d800+$380,x
    dex
    bpl loop
  }

  // fix bug on vice 3.6
  ldx #$3f
  lda #background+background*16
  {
    loop:
    sta $dbc0,x
    dex
    bpl loop
  }

  rts
}

plotHandle:
{
  // x = position
  // y = handle

  lda handlePositionsL,y
  sta loop.from1
  lda handlePositionsH,y
  sta loop.from1+1

  lda loop.from1
  clc
  adc #40
  sta loop.from2
  lda loop.from1+1
  adc #0
  sta loop.from2+1

  lda loop.from2
  clc
  adc #40
  sta loop.from3
  lda loop.from2+1
  adc #0
  sta loop.from3+1

  lda loop.from3
  clc
  adc #40
  sta loop.from4
  lda loop.from3+1
  adc #0
  sta loop.from4+1

  ldy #0  // index into the screen
  loop:
  {
    // should this column be empty?
    cpx #40
    bcc !+  // only indexes 0..39 are ok
    {
      lda #(charset1&$7ff)/8  // empty char
      sta screen1+20*40,y
      sta screen1+21*40,y
      sta screen1+22*40,y
      sta screen1+23*40,y
      inx
      iny
      cpy #40
      bne loop
      jmp done
    }
    !:
    
    lda from1: handleScreen+0*40,x
    sta screen1+20*40,y
    lda from2: handleScreen+1*40,x
    sta screen1+21*40,y
    lda from3: handleScreen+2*40,x
    sta screen1+22*40,y
    lda from4: handleScreen+3*40,x
    sta screen1+23*40,y
    inx
    iny
    cpy #40
    bne loop
  }
  done:
rts
}

handlePositionsL: .for (var i=0; i<nrHandles; i++) { .byte <(handleScreen+i*handleHeight*40) }
handlePositionsH: .for (var i=0; i<nrHandles; i++) { .byte >(handleScreen+i*handleHeight*40) }

// copy the bitmap data column wise
// x is the start column
copyBitmap:
{
  sta bitmap
  stx column
  lda pictureOffset,y
  sta offset
  lda colorsFromL,y
  sta copyColors.from1
  lda colorsFromH,y
  sta copyColors.from1+1
  lda d800FromL,y
  sta copyColors.from2
  lda d800FromH,y
  sta copyColors.from2+1

  lda #0               // start by copying the first bitmap column
  sta bitmapColumn

loop:
  // what column of the picture should we plot here?
  // example : if we want to plot at column = 8, we should plot column -8 at bitmapcolumn 0
  lda bitmapColumn
  sec
  sbc column

  // skip this column if the column that has to be plot <0 or >=width
  bmi skip
  cmp #width
  bcs skip

  // determine address to copy from
  tax
  lda pictureFromL,x
  sta copyLoop.from
  lda pictureFromH,x
  clc
  adc offset: #0
  sta copyLoop.from+1

  // determine bitmap address to copy to
  lda bitmapColumn
  asl
  asl
  asl
  //clc
  //adc #<bitmap1  // this is 0 ofcourse..
  sta copyLoop.to

  lda bitmap: #>bitmap1
  adc #0
  sta copyLoop.to+1
  
  lda copyLoop.to
  clc
  adc #$40
  sta copyLoop.to
  lda copyLoop.to+1
  adc #1
  sta copyLoop.to+1

  ldx #0
  rowLoop:
    // copy 8 bytes
    ldy #7
    copyLoop: {
    !:
      lda from: picture1Bitmap,x
      sta to:   bitmap1,y
      inx
      dey
      bpl !-
    }

    // copy the next row
    lda copyLoop.to
    clc
    adc #<320
    sta copyLoop.to
    lda copyLoop.to+1
    adc #>320
    sta copyLoop.to+1

    cpx #height*8
    bne rowLoop

skip:
  // next column
  inc bitmapColumn
  
  // everything copied?
  lda bitmapColumn
  cmp #40
  bne loop

copyColors:
{
  lda #<screen1+40
  sta to1
  lda #>screen1+40
  sta to1+1

  lda #<$d800+40
  sta to2
  lda #>$d800+40
  sta to2+1 

  ldy #height-1
  rowLoop:
    ldx #width-1
    loop:
      lda from1: picture0Bitmap+width*height*8,x
      sta to1:   screen1+40,x
      lda from2: picture0Bitmap+width*height*9,x
      sta to2:   $d800+40,x
      dex
      bpl loop

  // copy next row..
  lda from1
  clc
  adc #width
  sta from1
  bcc !+
    inc from1+1
  !:

  lda from2
  clc
  adc #width
  sta from2
  bcc !+
    inc from2+1
  !:

  lda to1
  clc
  adc #40
  sta to1
  bcc !+
    inc to1+1
  !:

  lda to2
  clc
  adc #40
  sta to2
  bcc !+
    inc to2+1
  !:

  dey
  bpl rowLoop
}
  rts

column:       .byte 0
bitmapColumn: .byte 0
}

pictureFromL:  .for (var c=0; c<width; c++) { .byte <(c*height*8) }
pictureFromH:  .for (var c=0; c<width; c++) { .byte >(c*height*8) }
pictureOffset: .byte >picture0Bitmap, >picture1Bitmap, >picture2Bitmap, >picture3Bitmap
colorsFromL:   .byte <picture0Bitmap+width*height*8, <picture1Bitmap+width*height*8, <picture2Bitmap+width*height*8, <picture3Bitmap+width*height*8
colorsFromH:   .byte >picture0Bitmap+width*height*8, >picture1Bitmap+width*height*8, >picture2Bitmap+width*height*8, >picture3Bitmap+width*height*8
d800FromL:     .byte <picture0Bitmap+width*height*9, <picture1Bitmap+width*height*9, <picture2Bitmap+width*height*9, <picture3Bitmap+width*height*9
d800FromH:     .byte >picture0Bitmap+width*height*9, >picture1Bitmap+width*height*9, >picture2Bitmap+width*height*9, >picture3Bitmap+width*height*9

topIrq:
{
  pha
  txa
  pha
  tya
  pha
  lda $01
  pha

  lda #$35
  sta $01

  .if (debug) { inc $d020 }

  // select correct charset
  lda #(bitmap1&$2000)/$2000*8+(screen1&$3c00)/$400*$10
  sta $d018

  lda setBorder: #border
  sta $d020
  lda setBackground: #background
  sta $d021
  sta $d027
  sta $d028
  sta $d029
  sta $d02a

  lda yPos
  sta $d001
  sta $d003
  sta $d005
  lda #$3f-27
  sta $d007

  lda #<dmaIrq
  sta jmpIrq+1
  lda #>dmaIrq
  sta jmpIrq+2

  lda $d011
  and #$7f
  sta $d011

  lda #$2f
  sta $d012
  asl $d019

  // hide grey vic bug
  lda #$00
  sta bitmap1+$7
  sta bitmap1+$f
  sta bitmap1+$17
  sta bitmap1+$ff // this causes a bug on my real c64, but not on other computers. I have no idea why. 
  cli
  
  // scroll handles
  lda handleD016: #0
  ora #$f8
  clc
  adc #2
  bcc !+
    dec position
  !:
  and #$7
  ora #$d0
  sta handleD016
  sta stableIrq.d016

  // do we have to fade?

  // plot handle at correct position
  ldx position: #40
  ldy handle:   #0

  .if (debug) { inc $d020 }
  jsr plotHandle
  .if (debug) { dec $d020; dec $d020 }

  pla
  sta $01
  pla
  tay
  pla
  tax
  pla
  
  rti
}

plexIrq2:
{
  dec 0
  pha

  // d017 has to be cleared after cycle 16 and set again before cycle 56

  lda #$00
  sta $d017
  lda #$07
  sta $d017

  lda $d001
  clc
  adc #43
  sta $d001
  sta $d003
  sta $d005

  lda #<backgroundIrq
  sta jmpIrq+1
  lda #>backgroundIrq
  sta jmpIrq+2
  lda #$2e+18*8
  sta $d012

  lda $d011
  and #$7f
  sta $d011

  asl $d019

  pla
  inc 0
  rti
}

.align $100
dmaIrq:
{
  // Jitter correction. Put earliest cycle in parenthesis.
  // (10 with no sprites, 19 with all sprites, ...)
  // Length of clockslide can be increased if more jitter
  // is expected, e.g. due to NMIs.

  dec 0            // 10..18
  sta atemp        // 15..23
  lda #39-(14)     // 19..27 <- (earliest cycle)
  sec              // 21..29
  sbc $dc06        // 23..31, A becomes 0..8
  sta branch       // 27..35
  cmp #10
  bcc branch: *+2  // 31..39
  lda #$a9         // 34
  lda #$a9         // 36
  lda #$a9         // 38
  lda $eaa5        // 40
                   // at cycle 34+(10) = 44

  // raster 47 cycle 45
  stx xtemp

  // do we have to FLD 8 rasterlines?
  lda fld: #1
  beq skipFLD

  // we have to FLD 8 lines..
  // first FLD 4 lines
  lda #$39+4
  sta $d011

  nop
  nop
  // wait >2 rasterlines.. cycles to wait = 5*x + 6
  ldx #30
  {
  loop:
    dex
    bpl loop
  }

  lda #$39  // set $d011 back to FLD another 4 lines
  sta $d011

  // wait until rasterline 55 cycle 52.. cycles to wait = 5*x + 6
  ldx #56
  {
  loop:
    dex
    bpl loop
  }
  bit $ea
  nop
  nop

skipFLD:
  // line 47/55, cycle 54  (56,36)

  // start at 24,25,..40, 0+FLD, .. 40+FLD

  nop        
  sec

  // rasterline 48, cycle 4
dmaDelay:
  bcs *             // 12
  lda #$a9  //0
  lda #$a9  //2
  lda #$a9  //4
  lda #$a9  //6
  lda #$a9  //8
  lda #$a9  //10
  lda #$a9  //12
  lda #$a9  //14
  lda #$a9  //16
  lda #$a9  //18
  lda #$a9  //20
  lda #$a9  //22
  lda #$a9  //24
  lda #$a9  //26
  lda #$a9  //28
  lda #$a9  //30
  lda #$a9  //32
  lda #$a9  //34
  lda #$a9  //36
  lda #$24  //38
  nop       //40   40 = 2 cycles

  lda #$38  // enable screen and shift the display
  sta $d011
  inc $d011
  
  lda bitmapBackground: #0
  sta $d021
  lda #<plexIrq1
  sta jmpIrq+1
  lda #>plexIrq1
  sta jmpIrq+2
  lda #$30+38-8
  sta $d012
  lda $d011
  and #$7f
  sta $d011

  lda #$ff
  sta bitmap1+$ff

  lda xOffset: #0
  asl $d019

  lda atemp: #0
  ldx xtemp: #0
  inc 0
  rti
}

plexIrq1:
{
  dec 0
  pha

  lda #$00
  sta $d017
  lda #$07
  sta $d017

  lda yPos
  cmp #$3f
  adc #43
  sta $d001
  sta $d003
  sta $d005

  lda #<plexIrq2
  sta jmpIrq+1
  lda #>plexIrq2
  sta jmpIrq+2
  lda #$30+2*40+2-8
  sta $d012

  lda #$00
  sta $d017
  lda #$07
  sta $d017

  lda $d011
  and #$7f
  sta $d011

  asl $d019

  pla
  inc 0
  rti
}

// this undoes the dma delay and FLD of the first IRQ
// to undo the dma delay, we have to 
// - stabilize the irq
// - get vic-ii to idle state (by fld)
// - trigger a new badline
.align $100
stableIrq:
{
  // Jitter correction. Put earliest cycle in parenthesis.
  // (10 with no sprites, 19 with all sprites, ...)
  // Length of clockslide can be increased if more jitter
  // is expected, e.g. due to NMIs.

  dec 0            // 10..18
  sta atemp        // 15..23
  lda #39-(10)     // 19..27 <- (earliest cycle)
  sec              // 21..29
  sbc $dc06        // 23..31, A becomes 0..8
  sta branch       // 27..35
  cmp #10
  bcc branch: *+2  // 31..39
  lda #$a9         // 34
  lda #$a9         // 36
  lda #$a9         // 38
  lda $eaa5        // 40
                   // at cycle 34+(10) = 44

  stx xtemp
  sty ytemp

  // force fld condition to get vic-ii in idle state
  lda #$1d
  sta $d011
  
  // select correct charset
  lda d018Value: #(charset1&$3800)/$800*2+(screen1&$3c00)/$400*$10
  sta $d018

  // hide bug
  lda bitmap1+$7ff
  pha
  lda charset2+$7ff
  pha
  lda bitmap1+$18ff  // bug on my 64, but not on any other computer wtf.
  pha
    
  lda #$ff
  sta bitmap1+$7ff
  lda #$00
  sta charset2+$7ff
  sta bitmap1+$18ff

  lda d016: #$d0   // stop x scroll
  sta $d016

  // wait until we are in the idle state
  bit $ea
  ldx #36; dex;  bpl *-1

  // do we have to FLD 8 rasterlines?
  lda dmaIrq.fld
  bne skipFLD

  // we have to FLD 8 lines..
  // first FLD 4 lines
  lda #$39
  sta $d011

  // wait >2 rasterlines.. cycles to wait = 5*x + 6
  ldx #40
  {
  loop:
    dex
    bpl loop
  }
  // line 197 (c5), cycle 24

  lda #$3d  // set $d011 back to FLD another 4 lines
  sta $d011

  // wait until rasterline 55 cycle 52.. cycles to wait = 5*x + 6
  ldx #55
  {
  loop:
    dex
    bpl loop
  }
  nop
  nop
  nop
  // line 50, cycle 24

skipFLD:

  // line 194, cycle 52
  lda dmaIrq.xOffset   
  cmp #40
  beq skip2
  adc #1
  sta dmaDelay+1

  //lda dmaIrq.xOffset
  //cmp #40
  //beq skip
  //sta dmaDelay+1
  //nop
dmaDelay:
  bne *             // 12
  lda #$a9  //0
  lda #$a9  //2
  lda #$a9  //4
  lda #$a9  //6
  lda #$a9  //8
  lda #$a9  //10
  lda #$a9  //12
  lda #$a9  //14
  lda #$a9  //16
  lda #$a9  //18
  lda #$a9  //20
  lda #$a9  //22
  lda #$a9  //24
  lda #$a9  //26
  lda #$a9  //28
  lda #$a9  //30
  lda #$a9  //32
  lda #$a9  //34
  lda #$a9  //36
  lda #$24  //38
  nop       //40   40 = 2 cycles
skip2:
  lda #$1b  // shift the display back to stable, go to charset mode
  sta $d011
  inc $d011
  
skip:
  lda setBackground: #background
  sta $d021

  ldx handleFadeStep: #0

  lda selectRamp1: col1Ramp,x
  sta $d023
  lda selectRamp2: col2Ramp,x
  sta $d022

  // restore bitmap
  pla
  sta bitmap1+$18ff
  pla
  sta charset2+$7ff
  pla
  sta bitmap1+$7ff

  // step the fade?
  lda rampStops,x
  bne skipFade
    lda wait: #1
    beq !+
      dec wait
      bpl skipFade
    !:
      lda #2
      sta wait
      inc handleFadeStep
  skipFade:

  lda #<irq
  sta jmpIrq+1
  lda #>irq
  sta jmpIrq+2
  lda #$fa
  sta $d012

  asl $d019

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  inc 0
  rti
}

.const fadeLenght = 14
rampStops:
  .byte  1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
  .byte  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1

col1Ramp: // hammerfist + wvl
  .byte $0,$0,$0,$6,$9,$2,$b,$4,$8,$e,$c,$5,$a,$3,$f
  .byte $f,$3,$a,$5,$c,$e,$8,$4,$b,$2,$9,$6,$0,$0,$0
col1RampGenius:
  .byte $3,$3,$3,$3,$3,$3,$3,$3,$6,$9,$2,$b,$4,$8,$e
  .byte $e,$8,$4,$b,$2,$9,$6,$3,$3,$3,$3,$3,$3,$3,$3
col1RampYouth:
  .byte $9,$9,$9,$9,$2,$b,$4,$8,$e,$c,$5,$a,$3,$f,$7
  .byte $7,$f,$3,$a,$5,$c,$e,$8,$4,$b,$2,$9,$9,$9,$9

col2Ramp: // all except genius
  .byte $6,$9,$2,$b,$4,$8,$e,$c,$5,$a,$3,$f,$7,$d,$1
  .byte $1,$d,$7,$f,$3,$a,$5,$c,$e,$8,$4,$b,$2,$9,$6
col2RampGenius:
  .byte $3,$3,$3,$3,$f,$7,$d,$1,$1,$1,$1,$1,$1,$1,$1
  .byte $1,$1,$1,$1,$1,$1,$1,$1,$d,$7,$f,$3,$3,$3,$3

backgroundIrq:
{
  dec 0
  pha

  lda topIrq.setBackground
  sta $d021
  
  lda #<stableIrq
  sta jmpIrq+1
  lda #>stableIrq
  sta jmpIrq+2
  lda #$2e+19*8
  sta $d012

  lda $d011
  and #$7f
  sta $d011

  asl $d019

  pla
  inc 0
  rti
}

setHideSprites:
{
  ldx #$50
  stx $d001
  stx $d003
  stx $d005  
  stx $d007

  // if FLD == 0, put them on the right
  // if FLD == 1, put them on the left
  cmp #0
  bne setLeft
  setRight:
    lda #$c0
    sta $d000
    lda #$f0
    sta $d002
    lda #$20
    sta $d004
    lda #$04
    sta $d010

    lda #$30
    sta yPos
  
    jmp continue
  setLeft:
    // only put them on the left if xOffset >= 40-width
    lda dmaIrq.xOffset
    cmp #(40-width)
    bcs spritesLeft
    //lda #$00
    //sta $d015
    //rts
    lda #$08
    sta $d015
    jmp setLast

  spritesLeft:
    lda #$18
    sta $d000
    lda #$48
    sta $d002
    lda #$78
    sta $d004
    lda #$00
    sta $d010
    lda #$3f
    sta yPos

continue:

  lda #$07  // use last 3 sprites to hide stuff
  sta $d015
  sta $d017
  sta $d01d
  lda #$00
  sta $d01c

  lda #(sprite&$3fc0)/64
  sta screen1+$3f8
  sta screen1+$3f9
  sta screen1+$3fa
  sta screen1+$3fb

  //lda topIrq.setBackground
  //sta $d027
  //sta $d028
  //sta $d029
  //sta $d02a

  lda #$0f
  sta $d015
setLast:
  ldx #0
  lda dmaIrq.xOffset
  sta $0400

  asl
  asl
  asl
  bcc !+
    inx
  !:

  clc
  adc #$08
  sta $d006
  bcc !+
    inx
  !:
  lda $d016
  and #$07
  ora $d006
  sta $d006

  lda $d010
  and #$07
  
  cpx #$00
  beq !+
    ora #$08
  !:
  sta $d010
  rts
}

startTopIrq:
{
  sta atemp
  lda $01
  sta restore01
  lda #$35
  sta $01

  lda topIrq.setBorder
  sta $d020
  lda topIrq.setBackground
  sta $d021

    lda #<startUpIrq
    sta jmpIrq+1
    lda #>startUpIrq
    sta jmpIrq+2
    lda #$fa
    sta $d012  

    asl $d019

  lda restore01: #0
  sta $01
  lda atemp: #0
  rti
}
startUpIrq:
{
  pha
  stx xtemp
  sty ytemp

  lda $01
  pha

  lda #$35
  sta $01

  lda #$01
  sta $d011
  
  lda #0
  sta $d015

  //inc $dbff // hide grey dot  
  //lda topIrq.setBackground
  //sta $d021

  inc timelow
  bne !+
    inc timehigh
  !:

  jsr music.play

  lda $d011
  and #$60
  ora #$09
  sta $d011

  jsr script

  lda nextIrqL: #<startTopIrq
  ldx nextIrqH: #>startTopIrq
  ldy nextD012: #$00

  sta jmpIrq+1
  stx jmpIrq+2
  sty $d012

  asl $d019

  pla
  sta $01

  pla
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

irq:
{
  pha
  txa
  pha
  tya
  pha
  lda $01
  pha

  lda #$35
  sta $01

  lda #$11
  sta $d011
  
  inc $dbff // hide grey dot  
  lda topIrq.setBackground
  sta $d021

  inc timelow
  bne !+
    inc timehigh
  !:

  jsr music.play
 
  lda #(charset1&$3800)/$800*2+(screen1&$3c00)/$400*$10
  sta $d018
  lda #(bitmap1&$c000)/$4000|$3c
  sta $dd02

  lda #<topIrq
  sta jmpIrq+1
  lda #>topIrq
  sta jmpIrq+2
  lda #$00
  sta $d012

  lda $d011
  and #$60
  ora #$19
  sta $d011
    
  asl $d019
  
  //lda #8
  //sta step

  // step through the movement
  ldx step: #(tableD016-tableDMA)
  cpx #(tableD016-tableDMA)
  bne !+
    // movement finished = hide handles
    lda #40
    sta topIrq.position
    // stay at this position
    dex
    stx step
  !:
  lda tableDMA,x
  sta dmaIrq.xOffset
  lda #$28
  sec
  sbc tableDMA,x
  sta dmaIrq.dmaDelay+1
  lda tableD016,x
  sta $d016
  lda tableFLD,x
  sta dmaIrq.fld

  // position the hide sprites.. 
  // if FLD == 0, put them on the right
  // if FLD == 1, put them on the left
  jsr setHideSprites

  .if (findBug) { lda #$30; sta step } else { inc step }

  jsr script

  pla
  sta $01
  pla
  tay
  pla
  tax
  pla
  rti
}

.const Wait       = $00  // wait a couple of frames
.const WaitFrame  = $01  // waint until a specific frame
.const Picture    = $02  // change the picture
.const Reset      = $03  // reset movement
.const IncPart    = $04  // increase nextpart :-)
.const FadeHandle = $05  // fadeout handles
.const Colors     = $06  // change colors
.const Colors2    = $07  // change colors (but not handle color)
.const Colors3    = $08  // quick change colors at startup to improve loading speed
.const EndStartUp = $09
.const End        = $ff

script:
  lda waitFrame: #0
  beq !+
    lda timehigh
    cmp waitFrameHi: #0
    bcc stillWaiting
    lda timelow
    cmp waitFrameLo: #0
    bcc stillWaiting

    // we reached (or passed) the correct frame #
    lda #0
    sta waitFrame
    beq advanceScript

  !:
  lda wait: #0
  beq advanceScript
  dec wait

stillWaiting:
  rts

advanceScript:
  ldx scriptPointer: #0
  lda scriptData,x
  cmp #WaitFrame
  bne testWait
  {
    inc waitFrame
    inx
    lda scriptData+1
    sta waitFrameHi
    inx
    lda scriptData+2
    sta waitFrameLo
    inx
    stx scriptPointer
    rts
  }

testWait:
  cmp #Wait
  bne testColors
  {
    inx
    lda scriptData,x
    sta wait
    inx
    stx scriptPointer
    rts
  }

testColors:
{
  cmp #Colors
  bne testColors2
    inx
    lda scriptData,x
    sta topIrq.setBorder
    inx
    lda scriptData,x
    sta topIrq.setBackground
    sta stableIrq.setBackground
    inx
    lda scriptData,x
    sta updateHandle.handleColor
    inx
    stx scriptPointer
    cli
    lda topIrq.setBackground
    jsr updateColors
    jsr updateHandle
    rts
}

testColors2:
{
  cmp #Colors2
  bne testColors3
    inx
    lda scriptData,x
    sta topIrq.setBorder
    inx
    lda scriptData,x
    sta topIrq.setBackground
    sta stableIrq.setBackground
    inx
    stx scriptPointer
    cli
    lda topIrq.setBackground
    jsr updateColors
    rts
}

testColors3:
{
  cmp #Colors3
  bne testStart
    inx
    lda scriptData,x
    sta topIrq.setBorder
    inx
    lda scriptData,x
    sta topIrq.setBackground
    sta stableIrq.setBackground
    inx
    stx scriptPointer
    rts
}

testStart:
{
  cmp #EndStartUp
  bne testPicture
    inx
    stx scriptPointer

    lda #<irq
    sta startUpIrq.nextIrqL
    lda #>irq
    sta startUpIrq.nextIrqH
    lda #$fa
    sta startUpIrq.nextD012
    
    rts  
}

testPicture:
{
  cmp #Picture
  bne testReset
    inx
    ldy scriptData,x  // picture to plot (0 = picture 1)
    sty topIrq.handle
    inx
    lda scriptData,x
    sta dmaIrq.bitmapBackground
    inx
    stx scriptPointer

    // wvl + hammerfist, select col1Ramp

    cpy #1 // genius
    bne !+
      lda #<col1RampGenius
      sta stableIrq.selectRamp1
      lda #>col1RampGenius
      sta stableIrq.selectRamp1+1
      lda #<col2RampGenius
      sta stableIrq.selectRamp2
      lda #>col2RampGenius
      sta stableIrq.selectRamp2+1
    !:

    cpy #2 // youth
    bne !+
      lda #<col1RampYouth
      sta stableIrq.selectRamp1
      lda #>col1RampYouth
      sta stableIrq.selectRamp1+1
      lda #<col2Ramp
      sta stableIrq.selectRamp2
      lda #>col2Ramp
      sta stableIrq.selectRamp2+1
    !:

    cpy #3 // wvl
    bne !+
      lda #<col1Ramp
      sta stableIrq.selectRamp1
      lda #>col1Ramp
      sta stableIrq.selectRamp1+1
    !:

    // special wvl, select charset2
    lda #(charset1&$3800)/$800*2+(screen1&$3c00)/$400*$10

    cpy #3
    bne !+
      lda #(charset2&$3800)/$800*2+(screen1&$3c00)/$400*$10
    !:
    sta stableIrq.d018Value

    // special yoohouth if we started from side2
    cpy #2   // is this youth?
    bne !+
    lda demostate
    bne !+
      // we got here from side 2, show yoohouth instead
      lda #4
      sta topIrq.handle
    !:

    cli

    ldx #0            // x position
    lda #>bitmap1     // bitmap to plot to
    jsr copyBitmap

    rts
}

testReset:
{
  cmp #Reset
  bne testIncPart
    lda #0
    sta irq.step
    lda #$0e                       // reset handle position
    sta topIrq.position
    lda #$d0
    sta topIrq.handleD016
    lda #1                         // start a fade in for the handles
    sta stableIrq.handleFadeStep
    inx
    stx scriptPointer
    rts
}

testIncPart:
{
  cmp #IncPart
  bne testFadeHandle
    ldy nextpart
    iny
    sty nextpart
    iny
    sty testEnd.nextPartValue

    inx
    stx scriptPointer
    rts
}

testFadeHandle:
{
  cmp #FadeHandle
  bne testEnd
    lda #16                        // start a fade in for the handles
    sta stableIrq.handleFadeStep
    inx
    stx scriptPointer
    rts
}

testEnd:
{
  cmp #End
  bne endScript
    lda nextPartValue: #0
    sta nextpart
}

endScript:
  rts

updateColors:
{
  ldx #39-16
  loop:
    .for (var r=0; r<4; r++) { sta $d800+$10+r*40,x }
    .for (var r=4; r<8; r++) { sta $d800+$10+r*40,x }
    .for (var r=8; r<12; r++) { sta $d800+$10+r*40,x }
    sta $d800,x
    dex
    bpl loop

  ldx #39-16
  loop4:
    .for (var r=12; r<16; r++) { sta $d800+$10+r*40,x }
    dex
    bpl loop4

  ldx #39
  loop5:
    .for (var r=16; r<20; r++) { sta $d800+r*40,x }
    sta $dbc0,x // hide bugs in vice 3.6
    dex
    bpl loop5

  rts
}

updateHandle:
{
  // set handle outside color
  ldx #39
  lda handleColor: #RED|8
  {
  loop:
    sta $d800+20*40,x
    sta $d800+21*40,x
    sta $d800+22*40,x
    sta $d800+23*40,x
    dex
    bpl loop
  }

  rts
}

scriptData:

// hammerfist - pink, dgrey
// genius     - black, blue
// wvl        - dgrey, cyan
// youth      - orange, brown

  // border, background, handlecolor
  .byte Colors3, $e,$6
  .byte Colors3, $8,$2
  .byte Colors3, $8,$b
  .byte Colors3, $4,$4
  .byte Colors3, $4,$8
  .byte Colors3, $2,$c
  .byte EndStartUp
  .byte Colors,  $b,$a,$0|8

  .byte Picture,0,0   // set hammerfist with background black
  .byte Wait,19       // wait 19 frames
  .byte Reset         // reset the movement
  .byte Wait,140
  .byte FadeHandle
  .byte Wait,55

  .byte Colors,  $b,$4,$3|8
  .byte Colors2, $b,$2
  .byte Colors2, $b,$9
  .byte Colors2, $6,$0
  .byte Wait,1

  .byte Picture,1,0   // change to genius
  .byte Wait,3
  .byte Reset
  .byte Wait,140
  .byte FadeHandle
  .byte Wait,55

  .byte Colors, $9,$9,$0|8
  .byte Colors2,$9,$2
  .byte Colors2,$9,$4
  .byte Colors2,$9,$8
  .byte Picture,2,0   // change to youth
  .byte Wait,4
  .byte Reset
  .byte Wait,140
  .byte FadeHandle
  .byte Wait,55

  .byte Colors2,$b,$4
  .byte Colors2,$8,$b
  .byte Colors2,$c,$2
  .byte Colors2,$3,$b
  .byte Picture,3,0   // change to wvl
  .byte Wait,4
  .byte Reset
  .byte IncPart       // signal that we can preload
  .byte Wait,139
  .byte FadeHandle
  .byte Wait,59

  .byte End

* = * "[DATA] movement data"
movement:
  .var startPosition =  0
  .var speed         = -6.0
  .var acceleration  =  0.20
  .var endPosition   = (40+width)*8/2
  .var position      = startPosition
  .var positions2    = List()

  .while ((position<=endPosition))
  {
    .eval speed    = speed + acceleration
    .eval position = position + speed
    .eval positions2.add(min(round(position),endPosition))
  }

  // make complete list with mirroring
  .var allPositions = List()
  
  // first add mirrored positions
  .for (var i=0; i<positions2.size(); i++)
  {
    .var value = -1*positions2.get(positions2.size()-1-i)
    .eval allPositions.add(value)
  }

  // add middle position
  .eval allPositions.add(0)

  // add positions2
  .for (var i=0; i<positions2.size(); i++)
  {
    .var value = positions2.get(i)
    .eval allPositions.add(value)
  }

  // modify positions from -endPosition,endPosition to -width*8, 40*8
  .for (var i=0; i<allPositions.size(); i++)
  {
    .var value = allPositions.get(i)+endPosition-width*8-9
    .eval allPositions.set(i, value)
  }

.print (allPositions)
.print (allPositions.size())

tableDMA:
.for (var i=0; i<allPositions.size(); i++)
{
  .var dma = 0
  .var position = allPositions.get(i)
  .if (position >= 0)
  {
    .eval dma = floor (min(position, 320)/8)
  } else
  {
    .eval dma = floor (min(position+320, 320)/8)
  }
  .byte dma
}

tableD016:
.for (var i=0; i<allPositions.size(); i++)
{
  .var position = allPositions.get(i)
  .var d016 = (position & 7)|$d0
  .byte d016
}

tableFLD:
.for (var i=0; i<allPositions.size(); i++)
{
  .var fld = 0
  .var position = allPositions.get(i)
  .if (position >= 0)
  {
    .eval fld = 1
  }
  .byte fld
}


.label picture0Screen = picture0Bitmap+width*height*8
.label picture0Colors = picture0Screen+width*height

.label picture1Bitmap = picture0Colors+width*height
.label picture1Screen = picture1Bitmap+width*height*8
.label picture1Colors = picture1Screen+width*height

.label picture2Bitmap = picture1Colors+width*height
.label picture2Screen = picture2Bitmap+width*height*8
.label picture2Colors = picture2Screen+width*height

.label picture3Bitmap = picture2Colors+width*height
.label picture3Screen = picture3Bitmap+width*height*8
.label picture3Colors = picture3Screen+width*height

// put portraits into memory
#if AS_SPINDLE_PART
  * = picture0Bitmap "[GFX] picture 0 data" virtual
  .fill data0.size(), data0.get(i)

  * = picture1Bitmap "[GFX] picture 1 data" virtual
  .fill data1.size(), data1.get(i)

  * = picture2Bitmap "[GFX] picture 2 data" virtual
  .fill data2.size(), data2.get(i)

  * = picture3Bitmap "[GFX] picture 3 data" virtual
  .fill data3.size(), data3.get(i)
#else
  * = picture0Bitmap "[GFX] picture 0 data"
  .fill data0.size(), data0.get(i)

  * = picture1Bitmap "[GFX] picture 1 data"
  .fill data1.size(), data1.get(i)

  * = picture2Bitmap "[GFX] picture 2 data"
  .fill data2.size(), data2.get(i)

  * = picture3Bitmap "[GFX] picture 3 data"
  .fill data3.size(), data3.get(i)
#endif

// put charset into memory
* = charset1 "[GFX] charset hammerfist, genius, youth"
.fill uniqueChars1.size(), uniqueChars1.get(i)

// put charset into memory
* = charset2 "[GFX] charset wvl (last charset)"
.fill uniqueChars2.size(), uniqueChars2.get(i)

* = handleScreen "[GFX] screendata with handle info"
.fill 3*handleHeight*40, screenData1.get(i+0*handleHeight*40)
.fill 1*handleHeight*40, screenData2.get(i+3*handleHeight*40)
.fill 1*handleHeight*40, screenData1.get(i+4*handleHeight*40)

* = sprite "[GFX] sprite"
.fill 63, 255

// occupy virtual memory
* = bitmap1 "[GFX] bitmap virtual" virtual
.fill 40*25*8,0

* = screen1 "[GFX] screen virtual" virtual
.fill 40*25,0
