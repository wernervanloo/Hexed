#import "../00.music/music1.asm"
//.var logo  = LoadPicture("./includes/element54.png",  List().add($3828B4, $72CCD7, $AAFA7C, $9A40C8))
//.var logoCol1   = PURPLE       // d800 color
//.var logoCol2   = CYAN         // d022 color
//.var logoCol3   = LIGHT_GREEN  // d023 color

//.var logo  = LoadPicture("./includes/ELEMENT_54.png", List().add($352879, $FFFFFF, $70A4B2, $000000))
.var logo  = LoadPicture("./includes/hexed.png", List().add($352879, $FFFFFF, $70A4B2, $000000))
                                                       // bitpairs $d021,   $d022,   $d023,   $d800
.var logoCol1   = BLACK        // d800 color
.var logoCol2   = WHITE        // d022 color
.var logoCol3   = CYAN         // d023 color

.var border     = BLUE         // d020 color
.var background = BLUE         // d021 color

.const maxOffset = 64+64
.var sinLengthY  = 80

.label firstByte = $d000
.label charset   = $d000
.label sprites   = $d580
.label screen1   = $e400
.label code      = $e800

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

.label firstZP       = $d0
  .label tempx       = $d0
  .label tempy       = $d1
  .label tempx2      = $d2
  .label d016Logo1   = $d3
  .label ypos        = $d4
  .label jmpIrq      = $d5 // d5,d6,d7
  .label rasterLow   = $d8
  .label rasterHigh  = $d9
  .label dummyZP     = $da
  .label tempx3      = $db
  .label tempy3      = $dc
  .label tempa3      = $de
.label lastZP        = $de

#if AS_SPINDLE_PART
  .label spindleLoadAddress = firstByte

  *=spindleLoadAddress-18-9-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"                 // fileformat magic
    .word prepare                // prepare routine
    .word start                  // setup routine
    .word 0                      // irq handler
    .word 0                      // main routine
    .word 0                      // fadeout routine
    .word cleanup                // cleanup routine
    .word music_play             // location of playroutine call

    .byte 'Z', <firstZP,   <lastZP
    .byte 'P', >screen1,   >(screen1+$3ff)
    .byte 'I', >$8400,     >$8800 // do not load too much
    //.byte 'A'                  // avoid. load only what is needed

    .byte 0
    .word spindleLoadAddress     // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2($080e); sei; lda #$35; sta $01; jmp start
#endif

// ------------------------------------
// convert picture into charset and map
// ------------------------------------

// create the list with unique chars
.var emptyChar   = List().add(0,0,0,0,0,0,0,0)  // the empty chars is special
.var uniqueChars = List().addAll(emptyChar)     // add empty char first
.var screenData  = List()
.for (var r=0; r<(logo.height/8); r++)
{
  .for (var c=0; c<(logo.width/8); c++)
  {      
    // read char
    .var char = List()
    .for (var byte=0; byte<8; byte++)
    {
      .var value = logo.getMulticolorByte(c,r*8+byte)
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

// ----------------------------
// convert picture into sprites
// ----------------------------

.var spriteData = List()
// loop over the colums
.for (var col=0; col<40; col=col+3)
{
  // then loop over the rows
  .for (var row=0; row<4; row++)
  {
    // loop over rows in the sprite
    .for (var y=0; y<21; y++)
    {
      // loop over columns in the sprites
      .for (var x=0; x<3; x++)
      {
        .var pictureX = col + x
        .var pictureY = row*21 + y

        .var value = 0
        .if ((pictureX<40) && (pictureY>=3)) { .eval value = logo.getMulticolorByte(pictureX, pictureY-3) }
        .eval spriteData.add(value)
      }
    }

    // add 64th byte
    .eval spriteData.add(0)
  }
}

*=code "[DATA] rasterbar data"
rasterbar0:
.fill 128,background
rasterbar1:
.fill 128,background
rasterbar2:
.fill 128,background

* = * "[CODE]"
rasterIrq:
{
  dec dummyZP
  sta tempa3        // 15..23

  // cycle 18,20
  lda #39-(9)     // 19..27 <- (earliest cycle)
  sec              // 21..29
  sbc $dc06        // 23..31, A becomes 0..8
  sta *+6
  cmp #10
  bcc *+2          // 31..39

  .byte NOP_IMM, NOP_IMM
  .byte NOP_IMM, NOP_IMM
  .byte NOP_IMM, NOP_IMM
  .byte NOP_ABS, NOP_ZP, NOP

  stx tempx3
  sty tempy3

grahamRasters:
  // setup
	ldy #$00
  ldx #$13
loop:	
  lda (rasterLow),y
	sta $d020
	sta $d021
	iny
	dex
	bne skip

  lda (rasterLow),y
  sta $d020,x
  sta $d021,x
  iny
  dex
  ldx #$07 // this never happens..

skip:
  // save 2 cycles here 

	tya
	ldy #$06
	dey
	bne *-1
	tay
  bit $ea

	cpy #$80
	bcc loop

  nop
  nop

  lda #background
  sta $d020
  sta $d021

  lda #<irq1
  sta jmpIrq+1
  lda #>irq1
  sta jmpIrq+2

  lda d012: #0
  sta $d012

  asl $d019

  lda tempa3
  ldx tempx3
  ldy tempy3
  rti
}

start:
{
  sei

  #if AS_SPINDLE_PART
    lda $01
    sta restore01
  #endif

  lda #$35
  sta $01

  lda #border
  sta $d020
  lda #background
  sta $d021
  
  lda #JMP_ABS
  sta jmpIrq

  ldx nextpart
  inx
  stx resetIrq.nextPartValue

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
  
    jsr prepare
  #endif

  lda #logoCol2
  sta $d022
  lda #logoCol3
  sta $d023

  lda #$d8
  sta $d016

  lda #<jmpIrq
  sta $fffe
  lda #>jmpIrq
  sta $ffff

  lda #<resetIrq
  sta jmpIrq+1
  lda #>resetIrq
  sta jmpIrq+2

  lda #<rasterbar0
  sta rasterLow
  lda #>rasterbar0
  sta rasterHigh

  lda #$ff
  sta $d012

  lda $d011
  and #$7f
  sta $d011

  lda $dc0d
  lda $dd0d
  asl $d019

  cli

  // quickly set $d800 colors..

  ldx #0
  lda #logoCol1|8
  loop:
    //sta $d800,x
    //sta $d900,x
    sta $da00,x
    sta $db00,x
    inx
    bne loop

  #if AS_SPINDLE_PART
    lda restore01: #0
    sta $01
    rts
  #else
  mainLoop:
    jmp mainLoop

    cmp ($00,x)

    // simulate end of part
    lda nextpart
  wait:
    // wait until part ends
    cmp nextpart
    beq wait
    // wait for cleanup
    jsr cleanup
    jmp *
  #endif
}
  
prepare:
{
  ldx #0
  txa
  loop:
    //sta screen1+$000,x
    sta screen1+$100,x
    sta screen1+$200,x
    sta screen1+$2e8,x
    inx
    bne loop
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

setSpritesAll:
{
  lda #$f0
  sta $d015
  sta $d01c
  lda #$00
  sta $d017
  sta $d01d

  ldx #logoCol3
  stx $d02b
  stx $d02c
  stx $d02d
  stx $d02e

  lda #logoCol2
  sta $d025
  lda #logoCol1
  sta $d026
  rts
}

.macro clipColumn()
{
  tax
  // check if negative..
  cmp #(sprites&$3fc0)/64
  bcs !+
    // if negative -> empty column
    ldx #(sprites&$3fc0)/64
!:
  // check if behind last column
  cmp #(sprites&$3fc0)/64+15*4
  bcc !+
    // if behind last -> empty column
    ldx #(sprites&$3fc0)/64
!:
}

setSprites1:
{
  // set y coordinate

  //lda #$3a
  sta $d009
  sta $d00b
  sta $d00d
  sta $d00f

  // sprites in left or right border?

  //ldy #8
  ldx offset1
  cpx #64
  bcc spritesInLeftBorder
  jmp spritesInRightBorder

spritesInLeftBorder:
    // sprites go to the left border

    lda #$70
    sta $d010

    lda d016Logo1
    and #7
    ora spriteLeftPositions,x
    sta $d008
    clc
    adc #$18
    sta $d00a
    clc
    adc #$18
    sta $d00c
    clc
    adc #$18
      bcc !+
        adc #7
      !:
      cmp #$f8
      bcc !+
        adc #7
      !:
    sta $d00e

    lda spriteLeftColumns,x
    clipColumn()
    stx screen1+$3fc
    clc 
    adc #4
    clipColumn()
    stx screen1+$3fd
    clc 
    adc #4
    clipColumn()
    stx screen1+$3fe
    clc 
    adc #4
    clipColumn()
    stx screen1+$3ff
    rts

spritesInRightBorder:
  lda #$f0
  sta $d010

  lda d016Logo1
  and #7
  ora spriteLeftPositions,x
  sta $d008
  clc
  adc #$18
  sta $d00a
  clc
  adc #$18
  sta $d00c
  clc
  adc #$18
  sta $d00e

    lda spriteLeftColumns,x
    clipColumn()
    stx screen1+$3fc
    clc 
    adc #4
    clipColumn()
    stx screen1+$3fd
    clc 
    adc #4
    clipColumn()
    stx screen1+$3fe
    clc 
    adc #4
    clipColumn()
    stx screen1+$3ff
    rts

  rts
}

// sprite positioning is just nasty since you have the /3 bit.. just use a table for the leftmost sprite
spriteLeftPositions:  .for (var i=0; i<64; i++) { .byte (mod((i+2),3)*8)+$b0 }     // b0->c8->e0->f8+8==0. so $b0 is the minimum value
spriteRightPositions: .for (var i=0; i<64; i++) { .byte (mod((i+0),3)*8)+$38 } 

    // x = $31,$32,$33 -> 2*4, (3*4, 4*4, 5*4)
    // x = $34,$35,$36 -> 1*4, (2*4, 3*4, 4*4)
    // x = $37,$38,$39 -> 0*4, (1*4, 2*4, 3*4)
    // x               -> floor((x-$37)/3)

spriteLeftColumns:
.for (var i=0; i<64; i++)
{
  .var value = (4*floor(($39-i)/3)) + ((sprites&$3fc0)/64)
  .byte $ff&value
}

    // $4f,$50,$51 -> 4*8

spriteRightColumns:
.for (var i=0; i<64; i++)
{                      // $51-$40 = $11
  .var value = (4*floor(($11+24-i)/3)) + ((sprites&$3fc0)/64)
  .byte $ff&value
}

.align $100
irq1:
{
  // Jitter correction. Put earliest cycle in parenthesis.
  // (10 with no sprites, 19 with all sprites, ...)
  // Length of clockslide can be increased if more jitter
  // is expected, e.g. due to NMIs.

  sta atemp        // 15..23
  stx tempx
  ldx d016: #$df

  // cycle 18,20
  lda #39-(20)     // 19..27 <- (earliest cycle)
  sec              // 21..29
  sbc $dc06        // 23..31, A becomes 0..8
  sta *+6
  cmp #10
  bcc bplpos: *+2          // 31..39
  lda #$a9         // 34
  lda #$a9         // 36
  lda #$a9         // 38
  lda $eaa5        // 40
                   // at cycle 34+(10) = 44
  // we would have 15 cycles until needed sta $d011 and have to update :
  // x     (3 cycles)
  // $ffff (6 cycles)

  //ldx bplpos
  //lda #1
  //sta $0400,x
  //nop

  // cycle 43

  lda d016Logo1
  // y gets stored to tempy by rasterCode
  jsr rasterCode

  lda #0
  sta $d015

  lda #<resetIrq
  sta jmpIrq+1
  lda #>resetIrq
  sta jmpIrq+2
  lda #$e8
  sta $d012
  asl $d019

  lda $d011
  and #$7f
  sta $d011

  lda atemp: #0
  ldx tempx
  ldy tempy
  rti
}

rasterCode:
{
  nop
  stx $d016

  sty tempy
  lda #background  // hide bugs in sprite line -1 in the right border
  sta $d027
  lda d016Logo1
  bit $ea
  ldy #$00

  //jsr openBorderBadline
  inc $dbff
  inc $dbff

  jsr openBorderBadLine2
  jsr openBorder
  jsr openBorder
  jsr openBorder
  jsr openBorder
  jsr openBorder
  jsr openBorder

  jsr openBorderBadline
  jsr openBorder
  jsr openBorder
  jsr openBorder
  jsr openBorder
  jsr openBorderMultiplex
  jsr openBorder

  jsr openBorderBadline
  jsr openBorderMultiplex2
  jsr openBorder
  jsr openBorder
  jsr openBorder
  jsr openBorder
  jsr openBorder

  jsr openBorderBadline
  jsr openBorder
  jsr openBorder
  jsr openBorder
  jsr openBorder
  jsr openBorder
  jsr openBorder

  jsr openBorderBadline
  jsr openBorderMultiplex
  jsr openBorder
  jsr openBorder
  jsr openBorder
  jsr openBorder
  jsr openBorderMultiplex2

  jsr openBorderBadline
  jsr openBorder
  jsr openBorder
  jsr openBorder
  jsr openBorderMultiplex
  jsr openBorder
  jsr openBorder

  jsr openBorderBadline
  jsr openBorder
  jsr openBorder
  //jsr openBorder
  //jsr openBorder
  //jsr openBorder
  //jsr openBorder

  //jsr openBorderBadline
  //jsr openBorder
  //jsr openBorder
  //jsr openBorderMultiplex2
  //jsr openBorder
  //jsr openBorder
  //jsr openBorder

  //jsr openBorderBadline
  //jsr openBorder
  //jsr openBorder
  //jsr openBorder
  //jsr openBorder
  //jsr openBorder
  //jsr openBorder

  //jsr openBorderBadline
  //jsr openBorder
  //jsr openBorder
  //jsr openBorder
  //jsr openBorder
  //jsr openBorder
  //jsr openBorder

  //jsr openBorderBadline

  rts
}

openBorder:
  jsr wait32
  sta $d016
  stx $d016
  rts

openBorderBadline:
  jsr wait32
openBorderBadLine2:
  sta $d016
  stx $d016
  sta $d016,y
  stx $d016
  rts

openBorderMultiplex:
  lda $d009
  clc
  adc #21
  sta $d009
  sta $d00b
  sta $d00d
  sta $d00f
  nop
  bit $ea
  lda d016Logo1
  sta $d016
  stx $d016
  rts

openBorderMultiplex2:
  inc screen1+$3fc
  inc screen1+$3fd
  inc screen1+$3fe
  inc screen1+$3ff

  nop
  bit $ea
  lda d016Logo1
  sta $d016
  stx $d016
  rts

wait52:
  nop
wait50:
  inc $dbff
wait44:
  inc $dbff
wait38:
  inc $dbff
wait32:
  inc $dbff
  inc $dbff
  inc $dbff
  nop
  rts

multiplex2:
  nop
  inc $dbff
  inc screen1+$3fc
  inc screen1+$3fc
  inc screen1+$3fc
  inc screen1+$3fc
  rts

resetIrq:
{
  pha
  txa
  pha
  tya
  pha

  inc wait
  lda wait: #0
  cmp #240
  bne !+
    lda nextPartValue: #0     // allow to go to the next part
    sta nextpart
  !:

  // increase frame counter
  inc timelow
  bne !+
    inc timehigh
  !:

  :MusicPlayCall()

  lda #((screen1&$3c00)/$400)*16+((charset&$3800)/$800*2)
  sta $d018
  lda #((screen1&$c000)/$4000)|$3c
  sta $dd02

  jsr setSpritesAll

  jsr moveLogo1

  // set d012 for next irq, depending on y position
  lda ypos
  clc
  adc #$31
  sta rasterIrq.d012
  asl $d019

  // set sprite y positions
  lda ypos
  clc
  adc #$3a-11
  jsr setSprites1

  // set d011 depending on y position
  lda ypos
  clc
  adc #3
  and #7
  ora #$18
  sta $d011

  lda rasterBarFrame: #0
  asl
  tax
  lda barFrames,x
  sta rasterLow
  lda barFrames+1,x
  sta rasterHigh

  dec rasterBarFrame
  bpl !+
    lda #2
    sta rasterBarFrame
  !:

  lda #<rasterIrq
  sta jmpIrq+1
  lda #>rasterIrq
  sta jmpIrq+2
  lda #$20
  sta $d012

  inc phase
  lda phase
  cmp #(endRasterSine-rasterSine)
  bcc !+
    lda #0
    sta phase
  !:

  ldx phase: #1
  ldy rasterSine,x

  ldx #$c
loop:
    lda bar,x
    sta (rasterLow),y
    iny
    dex
    bpl loop

  cli

  jsr plotLogo1

  pla
  tay
  pla
  tax
  pla
  rti
}

bar:
  .byte $6,$b,$4,$e,$3,$d,$1,$d,$3,$e,$4,$b,$6

barFrames:
  .word rasterbar0
  .word rasterbar1
  .word rasterbar2

// positions for current frame + next 2 frames
positionsLogo1:
  .byte 0
d016sLogo1:
  .byte 0
currentPositionLogo1:
  .byte 0

* = * "[CODE] movelogo"
moveLogo1:
{
  // move logo in y

  ldx yStep: #0
  lda #$78
  sta ypos
  //sta oldPlotY
  inc yStep

  clc
  adc #3
  lsr
  lsr
  lsr
  sta oldPlotY

  // fill in data for the lastest frame

  lda xData,x
  sta positionsLogo1+0
  lda xData2,x
  sta d016sLogo1+0
  sta d016Logo1
  ora #$08
  sta irq1.d016

  // read at what offset to plot..
  // remember : 
  // -higher values are moving the logo to the left
  // -lower values are moving the logo to the right

  lda #maxOffset
  sec
  sbc positionsLogo1+0
  sta offset1

  lda positionsLogo1+0
  clc
  adc #39
  sta plotLogo1.offset
  rts
}

plotLogo1:
{
  // what row should be plotted?
  lda ypos
  clc
  adc #3
  lsr
  lsr
  lsr
  tay

  ldx offset: #0

  cpy oldPlotY
  bne plot          // if y position changes, then we HAVE to plot

  cpx oldPlotX
  jmp plot2

  // logo already at the correct position
stop:
  rts

plot:
  .for (var row=0; row<7; row++)
  {
    lda rowTable.lo+row+1,y
    sta loop[row].store
    lda rowTable.hi+row+1,y
    sta loop[row].store+1
  }

  tya
  cpy oldPlotY
  sty oldPlotY
  bcs !+
    clc
    adc #11
  !:
  tay

  lda rowTable.lo,y
  sta store
  lda rowTable.hi,y
  sta store+1

  ldy #39
  lda #0
  clearloop:
    sta store:  screen1,y
    dey
    bpl clearloop

plot2:
  stx oldPlotX

  ldy #39
  loop:
    // plot the rows
    .for (var row=0; row<7; row++)
    {
      lda logoData+row*(64+40+64),x
      sta store: screen1+15*40+row*40,y
    }
    dex
    dey
    bpl loop
  rts
}

oldPlotX: .byte $ff
oldPlotY: .byte $ff
offset1:  .byte 0

rowTable: .lohifill 27, screen1+40*(max(min(i-1,24),0))

// generate fast tables to plot the logo to the screen
* = * "[DATA] data rows for logo"
logoData:
.for (var row=0; row<10; row++)
{
  .fill 64,0                           // start with 40+some empty chars (when the logo is all the way to the right)
  .fill 40, screenData.get(row*40+i)   // fill in the middle with the actual chars that make 
  .fill 64,0                           // and fill up with empty chars when the logo is all the way to the left..
}

* = * "[DATA] sine rasterbar"
rasterSine:
{
  .var sinMin    = 0
  .var sinMax    = $7f-$c
  .var sinLength = 128
  .var sinAmp    = 0.5 * (sinMax-sinMin)
  .fill sinLength, (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength))
}
endRasterSine:

sine:
.var xPositions = List()

.var middle    = (65+(40/2))*8-160
.var sinMin    = middle - 24*8
.var sinMax    = middle + 24*8
.var sinLength = 128
.var sinAmp    = 0.5 * (sinMax-sinMin)

.for (var i=0; i<256; i++)
{
  .var value = (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength))
  .eval xPositions.add(value)
}

* = * "[DATA] movement data"

xData:
  .fill xPositions.size(), floor((xPositions.get(i))/8)
xData2:
  .fill xPositions.size(), xPositions.get(i)&$7^$7|$d0

// --------------------------------
// load graphics data into memory -
// --------------------------------

* = sprites "[GFX] sprites"
.fill 256,0  // first add an empty column
.fill spriteData.size(), spriteData.get(i)
spriteEnd:

* = charset "[GFX] charset"
.fill uniqueChars.size(), uniqueChars.get(i)
charsetEnd:

* = screen1 "[GFX] screen 1" virtual
.fill 1000,0
