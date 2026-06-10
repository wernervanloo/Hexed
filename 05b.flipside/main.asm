//f -> start prepare
//0 -> prepare.setPointers
//1 -> prepare ready
//2 -> start
//3 -> irq2
//4 -> shiftIrq
//5 -> topirq
//6 -> irq

#import "../00.music/music1.asm"

.var spriteData = LoadBinary("../05a.element54/includes/Sprites.bin")

.const nrRows      = 8
.const displayRows = 4  // nr of sprite rows that are displayed
.const nrColumns   = 7
.const yStart      = $40
.const sinSize     = 256

.const finalPosition = $ff
.const maxYPos       = $30

.var centre = $64+nrColumns*24/2

.const xExpand     = 0
.const yExpand     = 1

.const spriteWidth = 24 + xExpand*24

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

.label firstZP    = $40
  .label sineAddLow = $40
  .label sineAdd    = $41
  .label phaseLow   = $42
  .label sineLow    = $43
  .label sineHigh   = $44
  .label irqJmp     = $45
  .label irqLow     = $46
  .label irqHigh    = $47
  .label yPos       = $48
.label lastZP     = $48

.var black     = $000000  // #000000
.var brown     = $5C4700  // #5C4700
.var pink      = $BB776D  // #BB776D
.var yellow    = $D0DC71  // #D0DC71

.var grey      = $6C6C6C
.var pink2     = $9A6759
.var cyan      = $70A4B2

.var GeniusBlack = $000000
.var GeniusBlue  = $352879
.var GeniusLBlue = $6C5EB5
.var GeniusCyan  = $70A4B2

//.var gfx_old = LoadPicture("./includes/test2.png",    List().add(black, brown, pink,  yellow)) // set black as $d021
//.var gfx     = LoadPicture("./includes/combined2.png", List().add(pink2, grey,  black, cyan)) // set black as $d021
                                                                  //d021 d022  d023  d024
.var gfx     = LoadPicture("./includes/combined4.png", List().add(GeniusBlue, GeniusBlack, GeniusLBlue, GeniusCyan)) // set black as $d021

//.const spriteCol0 = PURPLE
//.const spriteCol1 = LIGHT_BLUE
//.const spriteCol2 = CYAN

.const background = BLUE
.const spriteCol0 = BLACK
.const spriteCol1 = LIGHT_BLUE
.const spriteCol2 = CYAN
.const border     = LIGHT_BLUE


.label firstByte  = $2000
.label sprites2   = $2000  // sprites with size 2 go here, $e00 bytes
.label sprites4   = $3000  // sprites with size 4 go here -> size 4 is divided over banks 0 and 2
.label sprites4b  = $b000
.label sprites6   = $4000  // sprites with size 6 go here
.label sprites8   = $5000  // sprites with size 8 go here
.label sprites10  = $8000  // sprites with size 10 go here
.label sprites12  = $c000  // sprites with size 12 go here
.label sprites12Ori = $a000  // sprites with size 12 are originally at this position

.label screen2a   = $0000  // size 2 is completely in bank 0
.label screen2b   = $0400
.label screen2c   = $0800
.label screen2d   = $0c00
.label screen2e   = $2000
.label screen2f   = $2400
.label screen2g   = $2800
.label screen2h   = $2c00

.label screen4a   = $3000  // size 4 is divided over banks 0 and 2
.label screen4b   = $3400
.label screen4c   = $3800
.label screen4d   = $3c00
.label screen4e   = $b000  // we have to move the correct rows here..
.label screen4f   = $b400
.label screen4g   = $b800
.label screen4h   = $bc00

.label screen6a   = $4000  // size 6 is completely in bank 1
.label screen6b   = $4400
.label screen6c   = $4800
.label screen6d   = $4c00
.label screen6e   = $5000
.label screen6f   = $5400
.label screen6g   = $5800
.label screen6h   = $5c00

.label screen8a   = $6000  // size 8 is completely in bank 1
.label screen8b   = $6400
.label screen8c   = $6800
.label screen8d   = $6c00
.label screen8e   = $7000
.label screen8f   = $7400
.label screen8g   = $7800
.label screen8h   = $7c00

.label screen10a  = $8000  // size 10 is completely in bank 2
.label screen10b  = $8400
.label screen10c  = $8800
.label screen10d  = $8c00
.label screen10e  = $a000
.label screen10f  = $a400
.label screen10g  = $a800
.label screen10h  = $ac00

.label screen12a  = $c000 
.label screen12b  = $c400
.label screen12c  = $c800
.label screen12d  = $cc00
.label screen12e  = $d000
.label screen12f  = $d400
.label screen12g  = $d800
.label screen12h  = $dc00

.label speedCode  = $6000  // the code gets interleaved with spritepointers
.label code       = $9000
.label selfMod    = $7800
.label sidBuffer  = $8fc0

* = sidBuffer "[DATA] sid buffer"
.fill 19,0

// all screens for each size
.var screens2    = List().add(screen2a,  screen2b,  screen2c,  screen2d,  screen2e,  screen2f,  screen2g,  screen2h)
.var screens4    = List().add(screen4a,  screen4b,  screen4c,  screen4d,  screen4e,  screen4f,  screen4g,  screen4h)
.var screens6    = List().add(screen6a,  screen6b,  screen6c,  screen6d,  screen6e,  screen6f,  screen6g,  screen6h)
.var screens8    = List().add(screen8a,  screen8b,  screen8c,  screen8d,  screen8e,  screen8f,  screen8g,  screen8h)
.var screens10   = List().add(screen10a, screen10b, screen10c, screen10d, screen10e, screen10f, screen10g, screen10h)
.var screens12   = List().add(screen12a, screen12b, screen12c, screen12d, screen12e, screen12f, screen12g, screen12h)

.var screens     = List().add(screens2, screens4, screens6, screens8, screens10, screens12) // list of lists

.var spriteStart = List().add(sprites2, sprites4, sprites6, sprites8, sprites10, sprites12)

// positions for element54 sprites
.var spritePositions = List().add($41c0,$45c0,$49c0,$4dc0,$51c0,$55c0,$59c0,$5dc0)

// occupy virtual memory
.var ghostbytes=List().add(0,0,0,0)

.for (var s=0; s<screens.size(); s++)
{
  .var screensNow = screens.get(s)
  .for (var t=0; t<screensNow.size(); t++)
  {
    .var screen = screensNow.get(t)
    * = screen+$3f8 "[SPRITE POINTERS]" virtual
      .fill 7,0

      // do not occupy the ghostbytes for now..
      //.var bank = (screen&$c000)/$4000
      //.if (ghostbytes.get(bank)==0)
      //{
      //  .eval ghostbytes.set(bank,1)
      //  * = bank*$4000+$3fff "[GHOSTBYTE]" virtual
      //    .byte 0
      //}

  }
}

// convert to sprites
.for (var size=1; size<=6; size++)
{
  // make list of sprite data for each size
  .var spriteData = List()
  .for (var i=0; i<nrRows*nrColumns*64; i++) { .eval spriteData.add(0) }

  .for (var row=0; row<nrRows; row++)   // loop over rows
  {
    .var first = 0 - row  // row 0 : first byte at y=0
                          // row 1 : first byte at y=20 (-1)
                          // row 2 : first byte at y=19 (-2)
                          // etc
    .if (yExpand==1) { .eval first = 0 }

    .for (var col=0; col<nrColumns; col++) // loop over columns
    {
      .for (var x=0; x<3; x++)     // loop over X
      {
        .var maxY = 20+yExpand

        .for (var y=0; y<maxY; y++)  // loop over Y, only 20 pixelsrows per sprite
        {
          .var value = gfx.getMulticolorByte(col*3 + x, row*(20+yExpand)+y)

          .var y2    = first + y
          .if (y2<0) { .eval y2 = y2 + 21 }

          .var pos   = x+y2*3 + col*64 + row*nrColumns*64
          .eval spriteData.set(pos, value)
        }
      }
    }
  }

  // now shrink the sprites to the correct size.
  .for (var row=0; row<nrRows; row++)
  {
    .for (var sprite=0; sprite<nrColumns; sprite++)
    {
      .for (var y=0; y<21; y++)
      {
        .var pos = y*3 + sprite*64 + row*nrColumns*64
        .var byte1 = spriteData.get(pos+0)
        .var byte2 = spriteData.get(pos+1)
        .var byte3 = spriteData.get(pos+2)
        .var data   = (byte1<<16)+(byte2<<8)+byte3  // convert data in 24 bit number
        .var result = 0                             // result

        .var skipPixels   = 12/(size*2)
        .var currentPixel = skipPixels/2      // first pixel to read from original sprite
        .var emptyPixel   = (12-(size*2))/2   // first pixel to plot in zoomed sprite

        .for (var p=0; p<(size*2); p++)
        {
          // get pixel
          .var x = 2*floor(currentPixel)
          .var pixels  = (data>>(22-x))&$3
          .eval result = (result<<2)+pixels

          .eval currentPixel = currentPixel + skipPixels
        }
        .for (var p=0; p<emptyPixel; p++)
        {
          .eval result = result<<2
        }

        .eval byte1 = (result>>16)&255
        .eval byte2 = (result>>8)&255
        .eval byte3 = (result)&255
        .eval spriteData.set(pos+0, byte1)
        .eval spriteData.set(pos+1, byte2)
        .eval spriteData.set(pos+2, byte3)
      }
    }
  }

  // dump sprites in memory
  .for (var row=0; row<nrRows; row++)
  {
    .var pos = spriteStart.get(size-1)

    .if (pos == sprites12) 
    { 
      * = pos+row*8*64 "[GFX] spritedata" virtual
      .fill nrColumns*64, spriteData.get(i+row*nrColumns*64)

      .eval pos = sprites12Ori 
    }

    * = pos+row*8*64 "[GFX] spritedata"
    .fill nrColumns*64, spriteData.get(i+row*nrColumns*64)

    .if (pos==sprites4)
    {
      .var pos2=sprites4b+row*8*64
      .print (pos2)

      * = pos2 "[GFX] spritedata"
      .fill nrColumns*64, spriteData.get(i+row*nrColumns*64)      
    }

  }
}


#if AS_SPINDLE_PART
  .label spindleLoadAddress = firstByte // $2000
  *=spindleLoadAddress-18-18-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word prepare       // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine  -> this part is not allowed to have a main routine
    .word fadeout       // fadeout routine
    .word cleanup       // cleanup routine
    .word music_play    // location of playroutine call

    .byte 'Z', <firstZP, <lastZP
    .byte 'P', >($c000), >($cfff) // spritedata goes here
    .byte 'P', >($d300), >($d4ff) // declaration of spritepointer (and sid buffer) use
    .byte 'P', >($d700), >($d7ff) // declaration of spritepointer use
    .byte 'P', >($db00), >($dbff) // declaration of spritepointer use
    .byte 'P', >($df00), >($dfff) // declaration of spritepointer use

    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2(start); jmp start
#endif
 
* = code "[DATA] sprite sizes"
spriteSizeTab:
{
  .for (var size=0; size<=nrColumns*12; size++)  // size is the total width in multicolor pixels
  {
    .var spriteSize = 0
    // we can make sizes 0 to and _including_ 14 with sprite size 0
    // floor((14-1)/14) = floor(13/14) = 0

    .if (size>0)         { .eval spriteSize = (floor((size-1)/14) ) }
    .if (spriteSize > 5) { .eval spriteSize = 5                     }

    .byte spriteSize // the size ranges from 0 to 5. 0 being 2 multicolor pixes, 5 being 12 multicolor pixels
  }
}
// here are the sprite sizes for the backside
* = spriteSizeTab+128 "[DATA] sprite sizes (backside)"
spriteSizeTab2:
{
  .for (var size=0; size<=nrColumns*12; size++)  // size is the total width in multicolor pixels
  {
    .var spriteSize = 0
    .if (size>0) { .eval spriteSize = (floor((size-1)/14)) }
    .byte spriteSize+displayRows*6 // the size ranges from 0 to 5. 0 being 2 multicolor pixes, 5 being 12 multicolor pixels
  }
}

* = * "[CODE]"
start:
{
  sei
  lda #$35
  sta $01

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

    jsr prepare

    :MusicInitCall()

    lda #border
    sta $d020
    lda #background
    sta $d021
  #endif

  lda #0
  sta sineAdd
  sta sineAddLow
  sta $bfff

  lda #JMP_ABS
  sta irqJmp
  lda #<irq2
  sta irqLow
  lda #>irq2
  sta irqHigh

  lda #<irqJmp
  sta $fffe
  lda #>irqJmp
  sta $ffff
  lda #$f7
  sta $d012
  lda $d011
  and #$7f
  sta $d011

  lda $dc0d
  lda $dd0d
  asl $d019
  cli

  #if !AS_SPINDLE_PART
    loop:
      // simulate disk change with space bar
      lda $dc01
      and #$10
      beq simulateDiskSwap
      jmp loop
  
simulateDiskSwap:
  jsr fadeout
  bcc *-3
  jsr cleanup
  jmp *
  #else
    rts
  #endif
}

prepare:
{
  // copy sprites at a000 to c000
  ldx #0
  {
  loop:
    .for (var i=0; i<16; i++)
    {
      lda $a000+i*$100,x
      sta $c000+i*$100,x
    }
    inx
    bne loop
  }

  // backup sid
  ldx #6
  {
  loop:
    lda $0ff8,x
    sta backup0ff8,x
    dex
    bpl loop
  }

  // write the spritepointers
  jsr setPointers

  rts
}

fadeout:
{
  // the code gets here if the 2nd diskside has been detected..

  lda ready: #0              // are we ready to continue?
  bne !+
  // script has not advanced enough to continue.. return with carry clear
  clc
  rts
!:
  // the script has advanced enough to continue..
  lda #1
  sta playMusic.fadeSid      // mark to fade out the sid
  sec                        // signal Spindle that we are fading out and Spindle can load
  rts
}

cleanup:
{
  // wait until we faded out the picture..
  lda ready: #0
  beq cleanup
  lda #background
  sta $d021
  rts
}

.align $100
irq:
{
  // Jitter correction. Put earliest cycle in parenthesis.
  // (10 with no sprites, 19 with all sprites, ...)
  // Length of clockslide can be increased if more jitter
  // is expected, e.g. due to NMIs.

  sta atemp        // 15..23
  lda $01
  sta restore01

  lda #39-(12)     // 19..27 <- (earliest cycle)
  sec              // 21..29
  sbc $dc06        // 23..31, A becomes 0..8
  sta *+6          // 27..35
  cmp #10
  bcc *+2          // 31..39
  lda #$a9         // 34
  lda #$a9         // 36
  lda #$a9         // 38
  lda $eaa5        // 40
                   // at cycle 34+(10) = 44

  stx xtemp
  sty ytemp

  // backing up takes 8*7 = 56 cycles
  .for (var i=0; i<7; i++)
  {
    lda pointers0ff8+i
    sta $0ff8+i

    lda $03f8+i
    sta backup03f8+i

    lda pointers03f8+i
    sta $03f8+i
  }

  nop
  bit $ea

  lda #<irq2
  sta irqLow
  lda #>irq2
  sta irqHigh

  lda #$1b
  sta $d011

  lda #$f7
  sta $d012

  jsr speedCode

  asl $d019

  .for (var i=0; i<7; i++)
  {
    lda backup0ff8+i
    sta $0ff8+i

    lda backup03f8+i
    sta $03f8+i
  }

  jsr script  // script modifies d418, place before inc 0

  lda restore01: #0
  sta $01

  cli

  jsr incSkew
  jsr selfMod

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0

  rti
}

setSprites:
{
  lda #$7f
  sta $d015
  sta $d01c  // multicolor
  .if (yExpand==1)
  {
    sta $d017
  }
  .if (xExpand==1)
  {
    sta $d01d
  }

  lda #yStart
  sta $d001
  sta $d003
  sta $d005
  sta $d007
  sta $d009
  sta $d00b
  sta $d00d

  lda #$00
  .if (yExpand==0)
  {
    sta $d017
  }
  .if (xExpand==0)
  {
    sta $d01d
  }
  
  lda #centre-(spriteWidth/2)
  sta $d006

  lda #$00
  sta $d010
}
setColors:
{
  lda col0
  sta $d025

  lda col1
  sta $d027
  sta $d028
  sta $d029
  sta $d02a
  sta $d02b
  sta $d02c
  sta $d02d

  lda col2
  sta $d026

  rts
}

col0:
  .byte background
col1:
  .byte background
col2:
  .byte background

setPointers:
{
  // set all spritepointers
  lda #$34
  sta $01

  ldx #6
  clc
  loop:
  {
    .for (var size=0; size<=5; size++)
    {
      .var screensNow = screens.get(size)  // get list of screens for this size
      .for (var r=0; r<nrRows; r++)        // for each row
      {
        txa
        adc #((spriteStart.get(size)+r*8*64)&$3fff)/64
        // we use the spritepointers at $ff8.. but those are inside the music!
        // also backup the $3f8 pointers..
        .if ((screensNow.get(r) == $0000) || (screensNow.get(r) == $0c00))
        {
          .if (screensNow.get(r) == $0000)
          {
            sta pointers03f8,x
          }
          .if (screensNow.get(r) == $0c00)
          {
            sta pointers0ff8,x
          }
        } else
        {
          sta screensNow.get(r)+$3f8,x
        }
      }
    }
    dex
    bmi end
    jmp loop
    end:
  }

  // backup sprite pointers
  .for (var i=0; i<7; i++)
  {
    lda screen6a+$3f8+i
    sta pointers43f8+i
  }

  lda #$35
  sta $01

  rts
}

topIrq:  // reset $d021 colors
{
  sta atemp
  stx xtemp
  sty ytemp
  
  lda $01
  sta restore01
  lda #$35
  sta $01

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

  lda #<irq
  sta irqLow
  lda #>irq
  sta irqHigh

  lda #yStart-4
  sta $d012
  lda $d011
  and #$7f
  ora #$08
  sta $d011

  asl $d019

  jsr setSprites

  ldy width: #0

  lda d000Tab,y
  sta $d000
  lda d002Tab,y
  sta $d002
  lda d004Tab,y
  sta $d004

  lda d008Tab,y
  sta $d008
  lda d00aTab,y
  sta $d00a
  lda d00cTab,y
  sta $d00c

  // restore sprite pointers
  .for (var i=0; i<7; i++)
  {
    lda pointers43f8+i
    sta screen6a+$3f8+i
  }

  jsr playMusic
  
  lda ready: #0
  sta cleanup.ready

  lda restore01: #0
  sta $01

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

playMusic:
{
  // no need to keep up with demo time anymore..

  lda fadeSid: #0
  beq musicPlayCall  // normal playing
  
  lda #$34  // we have to fade the sid
  sta $01   // so let's not write to the SID, but catch the writes to our buffer

musicPlayCall:
  :MusicPlayCall()

  lda fadeSid 
  beq continue  // continue normally

  lda waitVolume: #15
  bne !+
    lda volume
    beq !+
    dec volume
    
    lda #15
    sta waitVolume
  !:
  dec waitVolume

  ldx #$18
copySidLoop:
    lda $d400,x
    sta sidBuffer,x
    dex
    bpl copySidLoop

  lda #$35
  sta $01

  // write all the data to the sid now
  ldx #$17
copySidLoop2:
    lda sidBuffer,x
    sta $d400,x
    dex
    bpl copySidLoop2

  // write volume
  lda sidBuffer+$18
  and #$f0
  ora volume: #$0f
  sta $d418

continue:
  rts
}

.var exitPositions = List().add(rasterCode2.exit0, rasterCode2.exit1, rasterCode2.exit2,  rasterCode2.exit3,  rasterCode2.exit4,  rasterCode2.exit5,  rasterCode2.exit6,  rasterCode2.exit7, 
                                rasterCode2.exit8, rasterCode2.exit9, rasterCode2.exit10, rasterCode2.exit11, rasterCode2.exit12, rasterCode2.exit13, rasterCode2.exit14, rasterCode2.exit15)
exitPos: .lohifill exitPositions.size(), exitPositions.get(i)

irq2:
{
  sta atemp
  stx xtemp

  lda $01
  sta restore01
  lda #$35
  sta $01

  jsr setSprites2

  lda #<shiftIrq
  sta irqLow
  lda #>shiftIrq
  sta irqHigh

  lda #0
  sta $d011

  asl $d019

  lda #(screen6a&$3c00)/$400*$10
  sta $d018
  lda #(((spritePositions.get(0))&$c000)/$4000)|$3c
  sta $dd02

  lda #$ff
  ldx fadeout: #0
  beq continue

anim:
  inc step
  ldx step: #0
  lda bounceAnim,x
  cmp #$80
  bne continue

    dec step
    lda #maxYPos
continue:
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
  sta setNOP: rasterCode2.exit0

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
  sta setRTS: rasterCode2.exit0
skipRTS:

  jsr setSprites1

  lda restore01: #0
  sta $01

  lda atemp: #0
  ldx xtemp: #0
  rti
}

.var xco1 = $93
.var xco2 = $c3-4
.var xco3 = $f3-4-8
.var xco4 = $23-4-8-4

setSprites1:
{
  lda #$ff
  sta $d015
  sta $d01d
  lda yPos
  sta $d001
  sta $d003
  sta $d005
  sta $d007
  sta $d009
  sta $d00b
  sta $d00d
  sta $d00f

  lda #$f0
  sta $d01c

  lda #$00
  sta $d017

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

setSprites2:
{
  lda #((spritePositions.get(0))&$3fc0)/64
  sta screen6a+$3f8
  lda #((spritePositions.get(1))&$3fc0)/64
  sta screen6a+$3f9
  lda #((spritePositions.get(2))&$3fc0)/64
  sta screen6a+$3fa
  lda #((spritePositions.get(3))&$3fc0)/64
  sta screen6a+$3fb
  lda #((spritePositions.get(4))&$3fc0)/64
  sta screen6a+$3ff
  lda #((spritePositions.get(5))&$3fc0)/64
  sta screen6a+$3fe
  lda #((spritePositions.get(6))&$3fc0)/64
  sta screen6a+$3fd
  lda #((spritePositions.get(7))&$3fc0)/64
  sta screen6a+$3fc

  rts
}

.if ((>*) != (>(*+30))) { .align $100 }
shiftIrq:
{
  // Jitter correction. Put earliest cycle in parenthesis.
  // (10 with no sprites, 19 with all sprites, ...)
  // Length of clockslide can be increased if more jitter
  // is expected, e.g. due to NMIs.

  sta atemp     // 15..23
  lda $01
  sta restore01

  // normally 9 cycles before we get here..
  // but now jmp + 4 + 3 + 4 = 14 cycles.. = +5

  lda #39-(15)     // 19..27 <- (earliest cycle)
  sec              // 21..29
  sbc $dc06        // 23..31, A becomes 0..8
  sta *+6          // 27..35
  cmp #10          // protection
  bcc *+2          // 31..39
  lda #$a9         // 34
  lda #$a9         // 36
  lda #$a9         // 38
  lda $eaa5        // 40
                   // at cycle 34+(10) = 44

  stx xtemp
  sty ytemp

  jsr wait36
  jsr wait36
  inc $dbff
  bit $ea

  // line 257, cycle 56

  // leftmost sprite (d00e) 3,7,8,11,14,16
  // 2nd sprite             8,10,15
  // 3rd sprite             9,11,15,16
  // 4th sprite             3,7,8,11+2,13+2,15

  nop
  nop

  jsr rasterCode2

  lda #<topIrq
  sta irqLow
  lda #>topIrq
  sta irqHigh
  lda #$00
  sta $d012

  lda $d011
  and #$7f
  ora #$08
  sta $d011

  // make sure the sprites do not get redrawn at the top
  lda #$ff
  sta $d001
  sta $d003
  sta $d005
  sta $d007
  sta $d009
  sta $d00b
  sta $d00d
  sta $d00f

  asl $d019

  lda restore01: #0
  sta $01

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

rasterCode2:
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
wait18:
  inc $dbff
wait12:
  rts

// -------------
// script engine
// -------------

.const Wait          = $80
.const WaitUntil     = $81
.const changeSpeed   = $82
.const setSkew       = $83
.const Ready         = $84  // mark that the script is ready for disk swap
.const WaitFadeOut   = $85
.const WaitSkew0     = $86
.const WaitSize0     = $87
.const WaitAnim      = $88
.const setCols       = $89
.const Anim          = $8a
.const End           = $ff

script:
{
  lda waitUntil: #0
  beq dontWaitUntil
  lda timehigh
  cmp waitHi: #0
  bcc notyet
  lda timelow
  cmp waitLo: #0
  bcs now
notyet:
  rts
now:
  lda #0
  sta waitUntil
dontWaitUntil:

  lda wait: #0
  beq continue
  dec wait
  rts

continue:
  ldx scriptPointer: #0
  lda scriptData,x
  
  cmp #Wait
  bne !+
  {
    lda scriptData+1,x
    sta wait
    inx
    jmp done
  }
  !:
  cmp #WaitUntil
  bne !+
  {
    lda scriptData+1,x
    sta waitHi
    lda scriptData+2,x
    sta waitLo
    inx
    inx
    lda #1
    sta waitUntil
    jmp done
  }
  !:
  cmp #changeSpeed
  bne !+
  {
    lda scriptData+1,x
    sta setOffsets.speedHigh
    lda scriptData+2,x
    sta setOffsets.speedLow
    inx
    inx
    jmp done
  }
  !:
  cmp #setCols
  bne !+
  {
    lda scriptData+1,x
    sta col0
    lda scriptData+2,x
    sta col1
    lda scriptData+3,x
    sta col2
    inx
    inx
    inx
    jmp done
  }
  !:
  cmp #setSkew
  bne !+
  {
    lda scriptData+1,x
    sta incSkew.maxSkew
    inx
    jmp done
  }
  !:
  cmp #Ready
  bne !+
  {
    lda #1
    sta fadeout.ready    
    bne done
  }
  !:
  cmp #WaitFadeOut
  bne !+
  {
    // wait until we have to fadeout..
    lda playMusic.fadeSid
    bne done // allow to continue the script
    rts
  }
  !:
  cmp #WaitSkew0
  bne !+
  {
    lda sineAddLow
    beq done
    rts
  }
  !:
  cmp #WaitSize0
  bne !+
  {
    lda setOffsets.phase
    and #$7f
    bne !+
      inx
      stx scriptPointer
      jmp continue // continue script directly
    !:
    rts
  }
  !:
  cmp #Anim
  bne !+
  {
    lda #1
    sta irq2.fadeout
    bne done
  }
  !:
  cmp #WaitAnim
  bne !+
  {
    lda yPos
    cmp #maxYPos
    beq done
    rts  
  }
  !:
  // no need to check for end. if we do not recognize the command, reset the script
  {
    lda #0
    sta playMusic.volume
    sta $d418

    lda #1
    sta topIrq.ready
    rts
  }
done:
  inx
  stx scriptPointer
done2:
  rts
}

scriptData:
  #if AS_SPINDLE_PART  
    .byte WaitUntil, $01,$00  // wait until fixed time in the demo for music synching
  #else
    .byte WaitUntil, $00,50   // wait 1 second as test in standalone
  #endif

  // only then start the part
  .byte Wait, 25
  .byte changeSpeed, 1, 0  // reveal the picture
  .byte setCols, spriteCol0, spriteCol1, spriteCol2
  .byte Wait, 64-3
  .byte changeSpeed, 0, 0  // hold still
  .byte Wait, 50           // wait 1 second
  .byte changeSpeed, 2, 0  // go to backside
  .byte Wait, 64-2
  .byte changeSpeed, 0, 0  // show backside
  .byte Wait, 50           // wait 1 second
  .byte changeSpeed, 2, 0  // start rotating
  .byte Wait, 100          // wait 2 seconds
  .byte setSkew, 24        // start skewing
  .byte Wait, 100          // wait 2 seconds
  .byte setSkew, 168
  .byte Wait, 100          // wait until about max skew
  .byte Ready              // mark that we will allow fadeout when disk is flipped..

  .byte WaitFadeOut        // wait for fadeout..

  .byte WaitSize0          // wait until size is 0.. (to get a fixed time until the end)
  .byte setSkew, 0         // reduce the skew, until we get to normal rotation
  .byte WaitSkew0          // wait until skew is 0..
  .byte Anim
  .byte WaitSize0          // wait until size is 0..
  .byte setCols, background, background, background
  .byte changeSpeed, 0, 0  // stop
  .byte WaitAnim           // wait until anim has finished

  .byte End

pointers03f8: .fill 7,0
backup03f8:   .fill 7,0
pointers0ff8: .fill 7,0
backup0ff8:   .fill 7,0
pointers43f8: .fill 7,0

waste18:
  nop
waste16:
  nop
waste14:
  nop
waste12:
  rts
dummy:
  .byte 0

* = * "[DATA] bounce in"
.var startPosition   = $ff
.var position        = startPosition

.var startSpeed      = 0
.var speed           = startSpeed

.var yPositions = List()

.while (position < ($100+maxYPos))
{
  // update speed
  .eval speed = speed + 0.1

  // update position
  .eval position = position + speed

  // limit position
  .if (position > ($100+maxYPos)) { .eval position = $100 + maxYPos }

  // store positions
  .eval yPositions.add(round(position)&$ff)
}

.print ("positions" + yPositions)

bounceAnim:
  .fill yPositions.size(), yPositions.get(i)
  .byte $80

sine:
* = * "[DATA] sine"
{
  .var sinMin = -nrColumns*12
  .var sinMax = nrColumns*12
  .var sinAmp = 0.5 * (sinMax-sinMin)

  .for (var i=0; i<sinSize; i++)
  {
    .var value = (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(i*360/sinSize))
    .if (value<0) { .eval value = 128-value}
    .byte value
  }
}

.if ((>*) != (>(*+nrRows*6-1))) { .align $100 }
* = * "[DATA] d018/dd00 tables"
d018Tab:
{
  .for (var row=0; row<nrRows; row++)
  {
    .for (var size=0; size<6; size++)
    {
      // get set of screens for this 
      .var screensNow = screens.get(size)
      // get correct row of this size -> this is the backside, get row+displayRows
      .var screen = screensNow.get(row)
      .var d018dd00 = ((screen&$3c00)/$400)*16+(screen&$c000)/$4000
      .byte d018dd00|$8 // |8 is used to reuse the value to prepare $d016 also
    }
  }
}

.if ((>*) != (>(*+nrColumns*12-1))) { .align $100 }
*=* "[DATA] d000 table"
d000Tab:
{
  .for (var size=0; size<=nrColumns*12; size++)
  {
    /*
    .var hiresSize = size*(2+2*xExpand)      // size in hires pixels
    .var spriteSize = hiresSize/nrColumns    // average size per sprite (in hires pixels)
    .var emptySize = spriteWidth-spriteSize  // average nr of empty pixels in sprite (in hires pixels)

    // for the start position, start with centre and subtract 3.5* the spritesize and the emptysize
    .var x = round(centre-(3.5*spriteSize)-(emptySize/2))
    .byte x
    */

    .var spriteSize = 0                                      // determine how wide the sprites are for this size
    .if (size>0) { .eval spriteSize = (floor((size-1)/14)) } // size 0 = 2 mc pixels, size 5 = 12 mc pixels
    .var emptyPixelsLeft = 12-((spriteSize+1)*2)             // calculate # of empty pixels on the left side   (in _hires_ pixels)
    .var startX = centre-size                                // calculate wanted start position of the graphic (in _hires_ pixels)
    .var startSprite = startX - emptyPixelsLeft              // calculate what the x position of the sprite should be
    .byte startSprite
  }
}

.if ((>*) != (>(*+nrColumns*12-1))) { .align $100 }
*=* "[DATA] d002 table"
d002Tab:
{
  .for (var size=0; size<=nrColumns*12; size++)
  {
    .var hiresSize = size*(2+2*xExpand)     // size in hires pixels
    .var spriteSize = hiresSize/nrColumns   // average size per sprite (in hires pixels)
    .var emptySize = spriteWidth-spriteSize // average nr of empty pixels in sprite (in hires pixels)

    // for the start position, start with centre and subtract 1.5* the spritesize and the emptysize
    .var x = round(centre-(2.5*spriteSize)-(emptySize/2))
    .byte x
  }
}

.if ((>*) != (>(*+nrColumns*12-1))) { .align $100 }
*=* "[DATA] d004 table"
d004Tab:
{
  .for (var size=0; size<=nrColumns*12; size++)
  {
    .var hiresSize = size*(2+2*xExpand)     // size in hires pixels
    .var spriteSize = hiresSize/nrColumns   // average size per sprite (in hires pixels)
    .var emptySize = spriteWidth-spriteSize // average nr of empty pixels in sprite (in hires pixels)

    // for the start position, start with centre and subtract 1.5* the spritesize and the emptysize
    .var x = round(centre-(1.5*spriteSize)-(emptySize/2))
    .byte x
  }
}

.if ((>*) != (>(*+nrColumns*12-1))) { .align $100 }
*=* "[DATA] d008 table"
d008Tab:
{
  .for (var size=0; size<=nrColumns*12; size++)
  {
    .var hiresSize = size*(2+2*xExpand)     // size in hires pixels
    .var spriteSize = hiresSize/nrColumns   // average size per sprite (in hires pixels)
    .var emptySize = spriteWidth-spriteSize // average nr of empty pixels in sprite (in hires pixels)

    // for the start position, start with centre and add 1.5* the spritesize and the emptysize
    .var x = round(centre+(0.5*spriteSize)-(emptySize/2))
    .byte x
  }
}

.if ((>*) != (>(*+nrColumns*12-1))) { .align $100 }
*=* "[DATA] d00a table"
d00aTab:
{
  .for (var size=0; size<=nrColumns*12; size++)
  {
    .var hiresSize = size*(2+2*xExpand)     // size in hires pixels
    .var spriteSize = hiresSize/nrColumns   // average size per sprite (in hires pixels)
    .var emptySize = spriteWidth-spriteSize // average nr of empty pixels in sprite (in hires pixels)

    // for the start position, start with centre and add 1.5* the spritesize and the emptysize
    .var x = round(centre+(1.5*spriteSize)-(emptySize/2))
    
    .byte x
  }
}

.if ((>*) != (>(*+nrColumns*12-1))) { .align $100 }
*=* "[DATA] d00c table"
d00cTab:
{
  .for (var size=0; size<=nrColumns*12; size++)
  {
    /*
    .var hiresSize = size*(2+2*xExpand)     // size in hires pixels
    .var spriteSize = hiresSize/nrColumns   // average size per sprite (in hires pixels)
    .var emptySize = spriteWidth-spriteSize // average nr of empty pixels in sprite (in hires pixels)

    // for the start position, start with centre and add 1.5* the spritesize and the emptysize
    .var x = round(centre+(2.5*spriteSize)-(emptySize/2))
    .byte x
    */

    .var spriteSize = 0                                      // determine how wide the sprites are for this size
    .if (size>0) { .eval spriteSize = (floor((size-1)/14)) } // size 0 = 2 mc pixels, size 5 = 12 mc pixels
    .var emptyPixelsLeft = 12-((spriteSize+1)*2)             // calculate # of empty pixels on the left side   (in _hires_ pixels)
    .var startX = centre+size                                // calculate wanted start position of the graphic (in _hires_ pixels)
    .var startSprite = startX - emptyPixelsLeft - ((spriteSize+1)*4)              // calculate what the x position of the sprite should be
    .byte startSprite
  }
}

.var multiplexed = List()

.macro rasterMacro(line) 
{
  .var v = floor(line/10)     // virtual sprite
  .var r = floor((line*2)/21)

  .if (yExpand==1) 
  { 
    .eval v = floor(line/21) 
    .eval r = floor(line*2/42) 
  }
  .var l = (line*2)-(r*21)

  // -----------------
  // even rasterline -
  // -----------------

  ldy width: #0            // todo: the table is page aligned. instead of ldx # and ldy abs,x, we could store directly into the abs adress
  
  // to do: combine these tables
  ldx spriteSizeTab,y      // extra advantage : y register is not destroyed
  lda d018Tab+v*6,x        // todo : if we distribute the $d018 table over several pages, we can 
                           // change the v*6 to v*$100 and store the width directly in the lowbyte 
                           // this also frees up X _and_ Y register!    
  


  sta $d018
  and #$03
  ora #$3c
  sta $dd02

  ldy width2: #0

  lda d000Tab,y
  sta $d000                // we want this store as late as possible
  lda d002Tab,y
  sta $d002
  lda d004Tab,y

  // ----------------
  // odd rasterline -
  // ----------------

  sta $d004
  lda d008Tab,y
  sta $d008
  lda d00aTab,y
  sta $d00a
  lda d00cTab,y
  sta $d00c
  nop

  // warning : 
  // this part of the code has a changing number of bytes. not good for unrolling the selfmod
  // this is why the changing number of bytes are at the end

  // here we have some spare cycles to :
  // - jump over the sprite pointers OR
  // - multiplex a sprite OR
  // - just waste the cycles

  // first : check if we have to skip the spritepointers by jumping
  // if not : check if we have to do a multiplex
  // if not : waste cycles

  .if (((*&$3ff) > $3b0) && (line != (displayRows*10)-1))
  {
    bit $ea
    //lda xExpand : #rasterBar.get(mod(line, rasterBar.size()))    // we could modify expand-x here.. but this seems to be a cycle too late
    nop

    .var jmpAdress = (*&$fc00)+$3ff
    jmp jmpAdress
    *=jmpAdress "[CODE] speedCode after spritepointers"
    lsr $dbff
    asl $dbff
  } else 
  {
    .var multiplex = 0 // the code did not multiplex yet
    // are all of the sprites in the current row multiplexed yet?
    .if ((r<(displayRows-1)) && (l>1))  // test for r : don't multiplex too many times. test for l : don't multiplex too soon
    {
      // check all 7 sprites, do they need multiplexing?
      .for (var sprite=0; (sprite<7)&&(multiplex==0); sprite++)
      {
        .var already = 0
        .for (var i=0; i<multiplexed.size(); i++)
        {
          .if (r*10+sprite == multiplexed.get(i)) { .eval already = 1 }
        }
        .if (already==0)
        {
          // this sprite is not yet multiplexed.. do it now
          .eval multiplexed.add(r*10+sprite)  // add to the list of sprites that is already multiplexed
          .eval multiplex = 1                 // the code multiplexed in this line

          .if (yExpand==0)
          {
            ldx #yStart+(r+1)*21
          } else {
            ldx #yStart+(r+1)*42
          }

          //lda xExpand : #rasterBar.get(mod(line, rasterBar.size()))    // we could modify expand-x here.. but this seems to be a cycle too late
          lda #0
          .var setY = $d001+sprite*2
          stx setY
          lsr $dbff
          asl $dbff
        }
      }
    } 
    .if (multiplex==0)
    {
      cmp ($00,x)           // take 6 cycles and only 2 bytes
      lda #0
      //lda xExpand : #rasterBar.get(mod(line, rasterBar.size()))    // we could modify expand-x here.. but this seems to be a cycle too late
      lsr $dbff
      asl $dbff
    }
  }
}

* = speedCode "[CODE] speedCode"
rasterCode:
{
  .var lines = displayRows*10
  .if (yExpand == 1) { .eval lines = displayRows*21 }
  rasterFor: .for (var line=0; line<lines; line++)
  {
    callMacro: rasterMacro(line)
  }
  rts
}

incSkew:
{
  lda sineAddLow
  cmp maxSkew: #0
  beq skewReached
  bcc incSkew

  dec sineAddLow
  rts

incSkew:
  inc sineAddLow
skewReached:
  rts
}

* = selfMod "[SPEEDCODE] selfmod"
setOffsets:
{
  // add the speed to current position
  lda phaseLow
  clc
  adc speedLow: #0
  sta phaseLow

  lda phase
  sta $0400
  adc speedHigh: #0
  cmp #sinSize
  bne !+
    lda #0
  !:
  sta phase

  ldy phase: #0

  .var lines = displayRows*10
  .if (yExpand==1) { .eval lines = displayRows*21 }

  .var lenght = 19
  ldx phaseLow
  .for (var line=0; line<lines; line++)
  {
    // avoid clashing with sprite pointers
    .if ((((>*)&3)==3) && (((<*)+lenght) >= $f5))  // is the code in the page where spritepointers are?
    {
      jmp continue
      .align $100
      continue:
    }
    // todo : set start position in abs adress : ldx sine+phase,y  (y start with 0)
    lda sine,y            // read the width for this line
 
    //lda #(mod(line,2))+28   // 10,24 = breedte constant, 13 = bug?!, 14,28 = gap 2
    sta rasterCode.rasterFor[line].callMacro.width
    and #$7f
    sta rasterCode.rasterFor[line].callMacro.width2  
    .if (line==0)
    {
      sta topIrq.width
    }

    // go to next value
    txa
    clc
    adc sineAddLow
    tax
    tya
    adc sineAdd
    tay
  }
  rts
}

.for (var s=0; s<spritePositions.size(); s++)
{
  * = spritePositions.get(s) "[GFX] element54 sprite"
    .fill 64, spriteData.get(s*64+i)
}
