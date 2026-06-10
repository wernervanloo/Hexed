#import "../00.music/music1.asm"
.const KOALA_TEMPLATE = "C64FILE, Bitmap=$0000, ScreenRam=$1f40, ColorRam=$2328, BackgroundColor = $2710"
.var picture   = LoadBinary("../01.graphics/bitmap_fix.kla", KOALA_TEMPLATE)

.var fixedFont = LoadBinary("./includes/upper_fixed.bin")

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

.label firstZP    = $40
  .label temp     = $40
  .label oraValue = $41
  .label low      = $42
  .label high     = $43
.label lastZP     = $43

.label basicScreen     = $0400
.label basicScreen2    = $0800

.label bitmap          = $2000             // this is the bitmap we are looking at..
.label ghostbyte1      = $3fff

.label code            = $4000             // code be here
.label fontCopy        = $6000             // this is the 'optimized' C64 font
.label bitmapScreen    = $6800             // this is where there colors for the basic screen (converted to bitmap) go to
.label basicScreenCopy = $6c00             // a copy of the basic screen, so we can scroll back left again
.label d800Copy        = $7000             // a copy of the basic colors, so we can scroll back left again
.label logoD800        = $7400             // the $d800 colors for the final bitmap
.label logoScreenMSB   = $7800             // the screen colors for the final bitmap, but only the MSB color (shifted to LSB)
.label logoScreenLSB   = $7c00             // the screen colors for the final bitmap, but only the LSB color
.label ghostbyte2      = $7fff

.label logoBitmap      = $8000             // here is the multicolor bitmap that we are going to show in the end
.label speedCode       = $a000


#if AS_SPINDLE_PART
  .label spindleLoadAddress = $3f40
  *=spindleLoadAddress-18-13-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word prepare       // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word 0             // cleanup routine
    .word music_play // location of playroutine call

    .byte 'I', $04, $07 // inherit the basic screen     
    .byte 'Z', firstZP, lastZP
    .byte 'P', $08,$0b                  // declare use of $0800-$0bff
    .byte 'P', >bitmap, >(bitmap+$1fff) // declare use of bitmap $2000-$3fff
    .byte 'S'  // declare safe loading under IO

    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2(start); jmp start
#endif

* = code "[CODE] main"
start:
{
  sei

  lda #$00
  sta ghostbyte1
  sta ghostbyte2
  sta nextpart
  sta timelow
  sta timehigh

  lda #$35
  sta $01

  #if !AS_SPINDLE_PART
    lda #$94
    sta $dd00
  #endif

  lda #((basicScreen&$c000)/$4000)|$3c
  sta $dd02

  lda $d021
  and #$0f
  sta fadeBasicColumn.startD021

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

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

  #endif

  #if !AS_SPINDLE_PART
    jsr prepare

    :MusicInitCall()
  #endif

  lda #<irqStorm
  sta $fffe
  lda #>irqStorm
  sta $ffff
  lda #$fc
  sta $d012
  lda $d011
  and #$7f
  sta $d011

  lda $dc0d
  lda $dd0d
  asl $d019
  cli
loop:
  #if !AS_SPINDLE_PART
    cmp ($00,x)
    jmp loop
  #else
    rts
  #endif
}

scrollScreenRight:
{
  lsr
  bcc scrollScreenRight1
  jmp scrollScreenRight2
}

scrollScreenRight1:
{
  ldx #38
  loop:
  .for (var row=0; row<25; row++)
  {
    lda basicScreen+row*40,x
    sta basicScreen2+1+row*40,x    
  }
  dex
  bmi end
  jmp loop
end:
  lda #$20
  .for (var row=0; row<25; row++) { sta basicScreen2+row*40 }
  rts
}

scrollScreenRight2:
{
  ldx #38
  loop:
  .for (var row=0; row<25; row++)
  {
    lda basicScreen2+row*40,x
    sta basicScreen+1+row*40,x    
  }
  dex
  bmi end
  jmp loop
end:
  lda #$20
  .for (var row=0; row<25; row++) { sta basicScreen+row*40 }
  rts
}

scrollScreenLeft:
{
  lsr
  bcc scrollScreenLeft1
  jmp scrollScreenLeft2
}

scrollScreenLeft1:
{
  ldx #0
  loop:
  .for (var row=0; row<10; row++)
  {
    lda basicScreen+1+row*40,x
    sta basicScreen2+row*40,x    
  }
  inx
  cpx #39
  beq end
  jmp loop
end:
  .for (var row=0; row<10; row++) 
  { 
    lda basicScreenCopy+row*40,y
    sta basicScreen2+39+row*40 
  }
  rts
}

scrollScreenLeft2:
{
  ldx #0
  loop:
  .for (var row=0; row<10; row++)
  {
    lda basicScreen2+1+row*40,x
    sta basicScreen+row*40,x    
  }
  inx
  cpx #39
  beq end
  jmp loop
end:
  .for (var row=0; row<10; row++) 
  { 
    lda basicScreenCopy+row*40,y
    sta basicScreen+39+row*40 
  }
  rts
}

scrollD800Right:
{
  {
  ldx #38
  loop: .for (var row=0; row<5; row++)
  {
    lda $d800+row*40,x
    sta $d801+row*40,x
  }
  dex
  bpl loop
  }
  {
  ldx #38
  loop: .for (var row=5; row<10; row++)
  {
    lda $d800+row*40,x
    sta $d801+row*40,x
  }
  dex
  bpl loop
  }
  {
  ldx #38
  loop: .for (var row=10; row<15; row++)
  {
    lda $d800+row*40,x
    sta $d801+row*40,x
  }
  dex
  bpl loop
  }
  {
  ldx #38
  loop: .for (var row=15; row<20; row++)
  {
    lda $d800+row*40,x
    sta $d801+row*40,x
  }
  dex
  bpl loop
  }
  {
  ldx #38
  loop: .for (var row=20; row<25; row++)
  {
    lda $d800+row*40,x
    sta $d801+row*40,x
  }
  dex
  bpl loop
  }
  rts
}

scrollD800Left:
{
  {
  ldx #0
  loop: .for (var row=0; row<5; row++)
  {
    lda $d801+row*40,x
    sta $d800+row*40,x
  }
  inx
  cpx #39
  bne loop
  }
  {
  ldx #0
  loop: .for (var row=5; row<10; row++)
  {
    lda $d801+row*40,x
    sta $d800+row*40,x
  }
  inx
  cpx #39
  bne loop
  }
  {
  ldx #0
  loop: .for (var row=10; row<15; row++)
  {
    lda $d801+row*40,x
    sta $d800+row*40,x
  }
  inx
  cpx #39
  bne loop
  }
  {
  ldx #0
  loop: .for (var row=15; row<20; row++)
  {
    lda $d801+row*40,x
    sta $d800+row*40,x
  }
  inx
  cpx #39
  bne loop
  }
  {
  ldx #0
  loop: .for (var row=20; row<25; row++)
  {
    lda $d801+row*40,x
    sta $d800+row*40,x
  }
  inx
  cpx #39
  bne loop
  }
  rts
}

copyBitmapScreen:
{
  ldx #0
  loop:
    .for (var page=0; page<4; page++)
    {
      lda bitmapScreen+page*$100,x
      sta basicScreen2+page*$100,x
    }
    inx
    bne loop
  rts
}

prepare:
{
  lda $d020
  sta irq.d020col

  // generate reverse characters
  ldx #0
  {
  loop:
    .for (var page=0; page<4; page++)
    {
      lda fontCopy+page*$100,x
      eor #$ff
      sta fontCopy+(page+4)*$100,x
    }
    inx
    bne loop
  }

  // wait until theMessage has finished before we generate the bitmap!
wait:
  lda nextpart

  #if AS_SPINDLE_PART  // there is no message for standalone
    beq wait
  #endif

  lda #0
  jsr scrollScreenRight1

  lda #$20
  .for (var row=0; row<25; row++) { sta basicScreen2+row*40 }

  // generate reverse characters
  // copy basic screen to backup
  ldx #0
  {
  loop:
    .for (var page=0; page<4; page++)
    {
      lda basicScreen+page*$100,x
      sta basicScreenCopy+page*$100,x

      lda $d800+page*$100,x
      sta d800Copy+page*$100,x
    }
    inx
    bne loop
  }

  // generate bitmap
bigLoop:
  {
    // read char from basic screen and set pointer
    lda #(>fontCopy)>>3
    sta copyLoop.readChar+1
    ldy #0
    lda readScreen: basicScreen,y
    asl
    rol copyLoop.readChar+1
    asl
    rol copyLoop.readChar+1
    asl
    rol copyLoop.readChar+1
    sta copyLoop.readChar

    // copy char to bitmap
    ldy #0
    copyLoop: {
    loop:
      lda readChar: fontCopy,y
      eor #$ff
      // copy it one pixel lower into the bitmap, to fix the badline problem
      iny
      cpy #8
      beq endLoop // do not store the last pixel directly, we have to store it in the next row!
      sta storeBitmap: bitmap,y
      bne loop
    endLoop:
    }

    // now, copy the last pixel line into the top of the next row
    // ----------------------------------------------------------
    
    // hires screen color are $6e
    // we only have bitpair %00 and %11
    // in normal hires, this will show the following colors
    // %00 - determined by low  nybble ($e)
    // %11 - determined by high nybble ($6)
    // however, in multicolor mode (which this line is in)
    // %00 - will be determined by $d021    -> we have to modify this bitpair to bitpair %10, so it reads from the low nybble
    // %11 - will be determined by colorRam -> we have to modify this bitpair to bitpair %01, so it reads from the high nybble
    // eor %10 will do this -> %00 eor %10 = %10, %11 eor %10 = %01
    
    eor #%10101010  
    tay       // remember the last byte

    lda copyLoop.storeBitmap
    clc
    adc #$40
    sta storeBitmap2
    lda copyLoop.storeBitmap+1
    adc #1
    sta storeBitmap2+1
    cmp #>(bitmap+$2000)
    bcs skipWrite

      // do not do this for the last row!!
      sty storeBitmap2: bitmap+320
  skipWrite:

    // advance to the next char
    // ------------------------

    inc readScreen
    bne !+
      inc readScreen+1
    !:

    lda copyLoop.storeBitmap
    clc
    adc #8
    sta copyLoop.storeBitmap
    bcc !+
      inc copyLoop.storeBitmap+1
    !:

    // finished?
    lda readScreen
    cmp #<1000
    bne bigLoop
    lda readScreen+1
    cmp #>(basicScreen+$300)
    bne bigLoop
  }

  // set bitmap colors
  lda $d021
  asl
  asl
  asl
  asl
  sta temp

  ldx #$00
  colorLoop:
    lda $d800,x
    and #$0f
    ora temp
    sta bitmapScreen,x

    lda $d800+$100,x
    and #$0f
    ora temp
    sta bitmapScreen+$100,x

    lda $d800+$200,x
    and #$0f
    ora temp
    sta bitmapScreen+$200,x
    
    lda $d800+$300,x
    and #$0f
    ora temp
    sta bitmapScreen+$300,x
    
    inx
    bne colorLoop

  rts
}

fadeBasicColumn:
{
  // x = column

  // if we are fading to black completely, also clear d800
  lda col2Fade1+1  // read white color
  beq clearColumn
  jmp !+

    clearColumn:
    {
      .for (var row=0; row<25; row++)
      {                  
        sta $d800+row*40,x         // d800 is not used in hires.. so blank it if we are done fading out
        sta basicScreen2+row*40,x  // also clear the screencolors directly..
      }
      rts
    }
!:
  ldy startD021: #0
  lda col2Fade1,y
  asl
  asl
  asl
  asl
  sta oraValue

  .for (var row=0; row<25; row++)
  {
    // wait a minute.. one of these colors is $d021 so it's fixed..

    // the original colors are in bitmapScreen
    lda bitmapScreen+row*40,x  // load the original colors
    and #$0f
    tay                        // LSB color in y
    lda col2Fade1,y  
    ora oraValue
    sta basicScreen2+row*40,x  // and store
  }
  rts
}

fadeBitmapColumn:
{
  // x = column

  .for (var row=0; row<25; row++)
  {
    ldy logoScreenMSB+row*40,x  // read MSB color
    lda col2Fade2,y
    asl
    asl
    asl
    asl
    ldy logoScreenLSB+row*40,x  // add LSB colors
    ora col2Fade2,y
    sta basicScreen2+row*40,x   // and store

    ldy logoD800+row*40,x       // d800 is not used in hires.. so blank it immediately
    lda col2Fade2,y       
    sta $d800+row*40,x
  }
  rts
}

// colors for fading out (original -> screen)
col2Fade1:
  .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

// colors for fading in (original -> screen)
col2Fade2:
  .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

// color ramp for fade out
colorRamp1:
  .byte $0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
  .byte $6,$6,$4,$4,$e,$e,$4,$4,$6,$6
  .byte $0,$6,$9,$2,$b,$4,$8,$e,$c,$5,$a,$3,$f,$7,$d,$1

// color ramp for fade in
colorRamp2:
  .byte $0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
  .byte $0,$6,$9,$2,$b,$4,$8,$e,$c,$5,$a,$3,$f,$7,$d,$1
.var maxRamp2 = $10

.var posInColorRampList = List().add(00,15,03,11,05,09,01,13,06,02,10,04,08,14,07,12)

//posInColorRamp:
//  .byte 00,15,03,11,05,09,01,13,06,02,10,04,08,14,07,12

calcFade1:
{
  clc
  adc #<colorRamp1
  sta low
  lda #>colorRamp1
  adc #0
  sta high
  
  .for (var color=0; color<16; color++)
  {
    ldy #posInColorRampList.get(color)
    lda (low),y
    sta col2Fade1+color
  }
  rts
}

calcFade2:
{
  // first, clip to the colorramp
  cmp #maxRamp2
  bcc !+
    lda #maxRamp2
  !:  

  // prepare to load from the correct position in the ramp
  clc
  adc #<colorRamp2
  sta low
  lda #>colorRamp2
  adc #0
  sta high
  
  .for (var color=0; color<16; color++)
  {
    ldy #posInColorRampList.get(color)
    lda (low),y
    sta col2Fade2+color
  }
  rts
}

// copy one column from the final bitmap to the bitmap that is showing
// this is pretty slow, but probably not worth speeding up..
// we could do a kickass for loop over the rows..

copyColumn:
{
  // first copy the bitmap..
  copyBitmapColumn:
  {
    ldy #>logoBitmap

    txa
    asl
    asl
    asl
    bcc !+
      iny
      clc
    !:
    adc #<logoBitmap
    sta copyRow.copyFrom
    sta copyRow.copyTo
    sty copyRow.copyFrom+1

    tya
    and #$1f
    ora #>bitmap
    sta copyRow.copyTo+1

    lda #24
    sta copyRow.nrRowsToCopy
    
    copyRow:
    {
      ldy #7
      copyLoop:
        lda copyFrom: logoBitmap,y
        sta copyTo:   bitmap,y
        dey
        bpl copyLoop

      // advance one row
      lda copyFrom
      clc
      adc #$40
      sta copyFrom
      sta copyTo

      lda copyFrom+1
      adc #1
      sta copyFrom+1
      and #$1f
      ora #>bitmap
      sta copyTo+1

      dec nrRowsToCopy
      lda nrRowsToCopy: #0
      bpl copyRow
    }
  }

  rts
}

// this IRQ handles the explosion at the beginning to hide changing the font..
irqStorm:
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
  
  lda #$fc
  sta $d012
  lda $d011
  and #$7f
  sta $d011

  lda #<irqStorm
  sta $fffe
  lda #>irqStorm
  sta $ffff
  asl $d019

  jsr playMusic
  jsr script

  // decide 
  lda state: #0
  beq scrollRight
  cmp #1
  beq jerkLeft
  cmp #2
  beq bumpScreen
  jmp goNext

scrollRight:
  {
    lda $d016
    clc
    adc #$01
    and #$07
    ora #$c8
    sta $d016

    // did we wrap back? then switch frame, move d800 quickly and prepare the next buffered frame
    cmp #$c8
    bne end

    lda $d018
    eor #$30   // 28->38->28 loop
    sta $d018 

    jsr scrollD800Right

    // end moving to the right?
    lda frame
    cmp #20
    bne !+
      // go to next state
      inc state
      jmp endIrq
    
    !:
    // buffer next frame
    cli
    lda frame: #1
    jsr scrollScreenRight
    inc frame
end:
    jmp endIrq
  }
jerkLeft:
  {
    ldy speed: #0

    // keep increasing the speed until we hit speed 8
    lda speeds,y
    cmp #8
    beq !+
      inc speed
    !:

    lda $d016
    and #$07  // and 7 for easy determining the wrapstate
    sec
    sbc speeds,y
    and #$07
    ora #$c8
    sta $d016

    // did we wrap back? then switch frame, move d800 quickly and prepare the next buffered frame
    bcs end
    
    lda #41
    sec
    sbc frame
    tax
    tay
  
    jsr speedMoveD800Left

    cli
    
    lda frame: #21
    dec frame

    // end moving to the left?
    lda frame
    cmp #1
    bne end
    
    inc state
  end:
    jmp endIrq

  }
bumpScreen:
  {
    ldx explosion: #0
    lda d011Table,x
    beq goNext

    sta $d011
    lda d016Table,x
    sta $d016

    // this is the moment with the highest change in speed, where a change of font is the least noticable..
    // so, switch to screen with modified font
    lda #((basicScreenCopy)/$400)*$10+((fontCopy&$3800)/$800)*2
    sta $d018
    lda #$3d
    sta $dd02

    inc explosion

    cpx #0
    bne endIrq

    // if we are in the first frame of the explosion, we quickly copy in the bitmap screen and switch 
    cli
    jsr copyBitmapScreen
  }
  
endIrq:
  pla
  sta $01

  pla
  tay
  pla
  tax
  pla
  rti

goNext:
  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$30
  sta $d012

  // change to bitmap mode
  lda #$3a   // 1 pixel higher to undo plotting 1 pixel lower
  sta $d011 
  
  // switch to bitmap
  lda #(((basicScreen2&$3fff)/$400)*$10)+((bitmap&$3fff)/$2000)*8
  sta $d018

  // go to correct bank
  lda #((bitmap&$c000)/$4000)|$3c
  sta $dd02

  lda #$00   // set final bitmap $d021 color
  sta $d021 
  jmp endIrq
}

speeds:
  .byte 1,2,3,4,5,6,7,8

d011Table:
  .byte $18,$14,$18,$1f,$13,$19,$1e,$14,$1f,$11,$1d,$1a,$14,$1b,$1a,$13,0 // 0 = end of bump
d016Table:
  .byte $cf,$c9,$cd,$cf,$c8,$cc,$ce,$c9,$cd,$cb,$ce,$c9,$cd,$cb,$ca,$cb

.align $100
irq:
{
  pha
  lda $01          // we cannot use LFT's way doing inc 0
  pha              // since this IRQ might last > 1 frame, we would be doing inc 0 twice..
  lda #$35
  sta $01

  lda #39-10-5     // 19..27 <- (earliest cycle)
  sec              // 21..29
  sbc $dc06        // 23..31, A becomes 0..8
  sta *+6          // 27..35
  cmp #10
  bcc *+2

  lda #$a9         // 34
  lda #$a9         // 36
  lda #$a9         // 38
  lda $eaa5        // 40
                   // at cycle 34+(10) = 44

  txa
  pha
  tya
  pha

  lda #BLACK
  sta $d021
  jsr waste32
  bit $ea

  ldx width: #0
  lda jsrAdresses.hi,x
  beq skipSplit

  sta loop.rasterCode+1
  lda jsrAdresses.lo,x
  sta loop.rasterCode
  
  inc $dbff
  
  lda #$c8
  ldy #$d8
  bit $ea
  
  ldx #24  // # of charrows to split
  loop: {
    nop
    nop
    nop
    nop
    nop

    jsr rasterCode: charrij40Wide
    dex
    bpl loop
  }

  // hide empty line
  lda d020col: #0
  sta $d021

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$30
  sta $d012
  asl $d019

  jsr playMusic
  jsr script

endIrq:
  cli
  jsr fadeInOut

  pla
  tay
  pla
  tax
  pla
  sta $01
  pla
  rti

skipSplit:
  lda #<irqHideLine
  sta $fffe
  lda #>irqHideLine
  sta $ffff
  lda #$f9
  sta $d012
  asl $d019
  jmp endIrq
}

irqHideLine:
{
  pha
  txa
  pha
  tya
  pha
   
  lda $01
  pha

  lda #$f9
  sta $d012
  asl $d019

  inc $dbff
  inc $dbff
  
  // hide buggy line
  lda $d020
  sta $d021

  jsr playMusic
  jsr script

  // back to normal background color
  lda #BLACK
  sta $d021

  cli
  jsr fadeInOut

  pla
  sta $01
  pla
  tay
  pla
  tax
  pla
  rti
}

playMusic:
  // also keep track of demo frames
  inc timelow
  bne !+
    inc timehigh
  !:
  :MusicPlayCall()  
    rts

.const Wait       = $00
.const WaitFrame  = $01
.const StartSplit = $02
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
  bne testSplit
  {
    inx
    lda scriptData,x
    sta wait
    inx
    stx scriptPointer
    rts
  }

testSplit:
  cmp #StartSplit
  bne testEnd
  {
    lda #0
    sta fadeInOut.pause
    inx
    stx scriptPointer
    rts
  }

testEnd:
  cmp #End
  bne endScript
  {
  }
endScript:
  rts

scriptData:
  .byte WaitFrame,2,8   // wait until frame 2*256+8
  .byte StartSplit      // start splitting
  .byte Wait,32         // wait 32 more frames
  .byte Wait,60
  .byte End

charrij4Wide:
{
  // this doesn't actually split.. but we need every 7th line in multicolor

  sta $d016 // switch back to hires

  nop
  nop

  // write here to split at the first column

  inc $dbff
  inc $dbff
  nop
  nop
  sta $d016
  sta $d016-$d8,y
  jsr waste54
  sta $d016
  sta $d016-$d8,y
  jsr waste54
  sta $d016
  sta $d016-$d8,y
  jsr waste54
  sta $d016
  sta $d016-$d8,y
  jsr waste54
  sta $d016
  sta $d016-$d8,y
  jsr waste54
  sta $d016
  sta $d016-$d8,y
  jsr waste54
  sta $d016
  sta $d016-$d8,y

  inc $dbff
  inc $dbff
  nop
  nop

  sty $d016  // switch back to multicolor for badline

  bit $ea

  rts
}

charrij6Wide:
{
  sta $d016 // switch back to hires

  nop
  nop

  // write here to split at the first column

  inc $dbff
  inc $dbff
  nop
  nop
  sty $d016
  sta $d016-$d8,y
  jsr waste54
  sty $d016
  sta $d016-$d8,y
  jsr waste54
  sty $d016
  sta $d016-$d8,y
  jsr waste54
  sty $d016
  sta $d016-$d8,y
  jsr waste54
  sty $d016
  sta $d016-$d8,y
  jsr waste54
  sty $d016
  sta $d016-$d8,y
  jsr waste54
  sty $d016
  sta $d016-$d8,y

  inc $dbff
  inc $dbff
  nop
  nop

  sty $d016  // switch back to multicolor for badline

  bit $ea

  rts
}

charrij8Wide:
{
  sta $d016 // switch back to hires

  nop
  nop

  // write here to split at the first column

  inc $dbff
  inc $dbff
  bit $ea
  sty $d016
  nop
  sta $d016-$d8,y
  jsr waste52
  sty $d016
  nop
  sta $d016-$d8,y
  jsr waste52
  sty $d016
  nop
  sta $d016-$d8,y
  jsr waste52
  sty $d016
  nop
  sta $d016-$d8,y
  jsr waste52
  sty $d016
  nop
  sta $d016-$d8,y
  jsr waste52
  sty $d016
  nop
  sta $d016-$d8,y
  jsr waste52
  sty $d016
  nop
  sta $d016-$d8,y

  inc $dbff
  inc $dbff
  bit $ea

  sty $d016  // switch back to multicolor for badline

  bit $ea

  rts
}

charrij10Wide:
{
  sta $d016 // switch back to hires

  nop
  nop

  // write here to split at the first column

  inc $dbff
  inc $dbff
  nop
  sty $d016
  nop
  nop
  sta $d016-$d8,y
  jsr waste50
  sty $d016
  nop
  nop
  sta $d016-$d8,y
  jsr waste50
  sty $d016
  nop
  nop
  sta $d016-$d8,y
  jsr waste50
  sty $d016
  nop
  nop
  sta $d016-$d8,y
  jsr waste50
  sty $d016
  nop
  nop
  sta $d016-$d8,y
  jsr waste50
  sty $d016
  nop
  nop
  sta $d016-$d8,y
  jsr waste50
  sty $d016
  nop
  nop
  sta $d016-$d8,y

  inc $dbff
  inc $dbff
  nop

  sty $d016  // switch back to multicolor for badline

  bit $ea

  rts
}

charrij12Wide:
{
  sta $d016 // switch back to hires

  nop
  nop

  // write here to split at the first column

  inc $dbff
  nop
  nop
  bit $ea
  sty $d016
  inc $dbff
  sta $d016-$d8,y
  jsr waste48
  sty $d016
  inc $dbff
  sta $d016-$d8,y
  jsr waste48
  sty $d016
  inc $dbff
  sta $d016-$d8,y
  jsr waste48
  sty $d016
  inc $dbff
  sta $d016-$d8,y
  jsr waste48
  sty $d016
  inc $dbff
  sta $d016-$d8,y
  jsr waste48
  sty $d016
  inc $dbff
  sta $d016-$d8,y
  jsr waste48
  sty $d016
  inc $dbff
  sta $d016-$d8,y

  inc $dbff
  nop
  nop
  bit $ea

  sty $d016  // switch back to multicolor for badline

  bit $ea

  rts
}

charrij14Wide:
{
  sta $d016 // switch back to hires

  nop
  nop

  // write here to split at the first column

  inc $dbff
  nop
  nop
  nop
  sty $d016
  inc $dbff
  nop
  sta $d016-$d8,y
  jsr waste46
  sty $d016
  inc $dbff
  nop
  sta $d016-$d8,y
  jsr waste46
  sty $d016
  inc $dbff
  nop
  sta $d016-$d8,y
  jsr waste46
  sty $d016
  inc $dbff
  nop
  sta $d016-$d8,y
  jsr waste46
  sty $d016
  inc $dbff
  nop
  sta $d016-$d8,y
  jsr waste46
  sty $d016
  inc $dbff
  nop
  sta $d016-$d8,y
  jsr waste46
  sty $d016
  inc $dbff
  nop
  sta $d016-$d8,y

  inc $dbff
  nop
  nop
  nop

  sty $d016  // switch back to multicolor for badline

  bit $ea

  rts
}

charrij16Wide:
{
  sta $d016 // switch back to hires

  nop
  nop

  // write here to split at the first column

  inc $dbff
  nop
  bit $ea
  sty $d016
  inc $dbff
  nop
  nop
  sta $d016-$d8,y
  jsr waste44
  sty $d016
  inc $dbff
  nop
  nop
  sta $d016-$d8,y
  jsr waste44
  sty $d016
  inc $dbff
  nop
  nop
  sta $d016-$d8,y
  jsr waste44
  sty $d016
  inc $dbff
  nop
  nop
  sta $d016-$d8,y
  jsr waste44
  sty $d016
  inc $dbff
  nop
  nop
  sta $d016-$d8,y
  jsr waste44
  sty $d016
  inc $dbff
  nop
  nop
  sta $d016-$d8,y
  jsr waste44
  sty $d016
  inc $dbff
  nop
  nop
  sta $d016-$d8,y

  inc $dbff
  nop
  bit $ea

  sty $d016  // switch back to multicolor for badline

  bit $ea

  rts
}

charrij18Wide:
{
  sta $d016 // switch back to hires

  nop
  nop

  // write here to split at the first column

  inc $dbff
  nop
  nop
  sty $d016
  jsr waste12
  sta $d016-$d8,y
  jsr waste42
  sty $d016
  jsr waste12
  sta $d016-$d8,y
  jsr waste42
  sty $d016
  jsr waste12
  sta $d016-$d8,y
  jsr waste42
  sty $d016
  jsr waste12
  sta $d016-$d8,y
  jsr waste42
  sty $d016
  jsr waste12
  sta $d016-$d8,y
  jsr waste42
  sty $d016
  jsr waste12
  sta $d016-$d8,y
  jsr waste42
  sty $d016
  jsr waste12
  sta $d016-$d8,y

  inc $dbff
  nop
  nop

  sty $d016  // switch back to multicolor for badline

  bit $ea

  rts
}

charrij20Wide:
{
  sta $d016 // switch back to hires

  nop
  nop

  // write here to split at the first column

  inc $dbff
  bit $ea
  sty $d016
  jsr waste14
  sta $d016-$d8,y
  jsr waste40
  sty $d016
  jsr waste14
  sta $d016-$d8,y
  jsr waste40
  sty $d016
  jsr waste14
  sta $d016-$d8,y
  jsr waste40
  sty $d016
  jsr waste14
  sta $d016-$d8,y
  jsr waste40
  sty $d016
  jsr waste14
  sta $d016-$d8,y
  jsr waste40
  sty $d016
  jsr waste14
  sta $d016-$d8,y
  jsr waste40
  sty $d016
  jsr waste14
  sta $d016-$d8,y

  inc $dbff
  bit $ea

  sty $d016  // switch back to multicolor for badline

  bit $ea

  rts
}

charrij22Wide:
{
  sta $d016 // switch back to hires

  nop
  nop

  // write here to split at the first column

  inc $dbff
  nop
  sty $d016
  jsr waste16
  sta $d016-$d8,y
  jsr waste38
  sty $d016
  jsr waste16
  sta $d016-$d8,y
  jsr waste38
  sty $d016
  jsr waste16
  sta $d016-$d8,y
  jsr waste38
  sty $d016
  jsr waste16
  sta $d016-$d8,y
  jsr waste38
  sty $d016
  jsr waste16
  sta $d016-$d8,y
  jsr waste38
  sty $d016
  jsr waste16
  sta $d016-$d8,y
  jsr waste38
  sty $d016
  jsr waste16
  sta $d016-$d8,y

  inc $dbff
  nop

  sty $d016  // switch back to multicolor for badline

  bit $ea

  rts
}

charrij24Wide:
{
  sta $d016 // switch back to hires

  nop
  nop

  // write here to split at the first column

  nop
  nop
  bit $ea
  sty $d016
  jsr waste18
  sta $d016-$d8,y
  jsr waste36
  sty $d016
  jsr waste18
  sta $d016-$d8,y
  jsr waste36
  sty $d016
  jsr waste18
  sta $d016-$d8,y
  jsr waste36
  sty $d016
  jsr waste18
  sta $d016-$d8,y
  jsr waste36
  sty $d016
  jsr waste18
  sta $d016-$d8,y
  jsr waste36
  sty $d016
  jsr waste18
  sta $d016-$d8,y
  jsr waste36
  sty $d016
  jsr waste18
  sta $d016-$d8,y

  nop
  nop
  bit $ea

  sty $d016  // switch back to multicolor for badline

  bit $ea

  rts
}

charrij26Wide:
{
  sta $d016 // switch back to hires

  nop
  nop

  // write here to split at the first column

  nop
  nop
  nop
  sty $d016
  jsr waste20
  sta $d016-$d8,y
  jsr waste34
  sty $d016
  jsr waste20
  sta $d016-$d8,y
  jsr waste34
  sty $d016
  jsr waste20
  sta $d016-$d8,y
  jsr waste34
  sty $d016
  jsr waste20
  sta $d016-$d8,y
  jsr waste34
  sty $d016
  jsr waste20
  sta $d016-$d8,y
  jsr waste34
  sty $d016
  jsr waste20
  sta $d016-$d8,y
  jsr waste34
  sty $d016
  jsr waste20
  sta $d016-$d8,y

  nop
  nop
  nop

  sty $d016  // switch back to multicolor for badline

  bit $ea

  rts
}

charrij28Wide:
{
  sta $d016 // switch back to hires

  nop
  nop

  // write here to split at the first column

  nop
  bit $ea
  sty $d016
  jsr waste22
  sta $d016-$d8,y
  jsr waste32
  sty $d016
  jsr waste22
  sta $d016-$d8,y
  jsr waste32
  sty $d016
  jsr waste22
  sta $d016-$d8,y
  jsr waste32
  sty $d016
  jsr waste22
  sta $d016-$d8,y
  jsr waste32
  sty $d016
  jsr waste22
  sta $d016-$d8,y
  jsr waste32
  sty $d016
  jsr waste22
  sta $d016-$d8,y
  jsr waste32
  sty $d016
  jsr waste22
  sta $d016-$d8,y

  nop
  bit $ea

  sty $d016  // switch back to multicolor for badline

  bit $ea

  rts
}

charrij30Wide:
{
  sta $d016 // switch back to hires

  nop
  nop

  // write here to split at the first column

  nop
  nop
  sty $d016
  jsr waste24
  sta $d016-$d8,y
  jsr waste30
  sty $d016
  jsr waste24
  sta $d016-$d8,y
  jsr waste30
  sty $d016
  jsr waste24
  sta $d016-$d8,y
  jsr waste30
  sty $d016
  jsr waste24
  sta $d016-$d8,y
  jsr waste30
  sty $d016
  jsr waste24
  sta $d016-$d8,y
  jsr waste30
  sty $d016
  jsr waste24
  sta $d016-$d8,y
  jsr waste30
  sty $d016
  jsr waste24
  sta $d016-$d8,y

  nop
  nop

  sty $d016  // switch back to multicolor for badline

  bit $ea

  rts
}

charrij32Wide:
{
  sta $d016 // switch back to hires

  nop
  nop

  // write here to split at the first column

  bit $ea
  sty $d016
  jsr waste26
  sta $d016-$d8,y
  jsr waste28
  sty $d016
  jsr waste26
  sta $d016-$d8,y
  jsr waste28
  sty $d016
  jsr waste26
  sta $d016-$d8,y
  jsr waste28
  sty $d016
  jsr waste26
  sta $d016-$d8,y
  jsr waste28
  sty $d016
  jsr waste26
  sta $d016-$d8,y
  jsr waste28
  sty $d016
  jsr waste26
  sta $d016-$d8,y
  jsr waste28
  sty $d016
  jsr waste26
  sta $d016-$d8,y

  bit $ea

  sty $d016  // switch back to multicolor for badline

  bit $ea

  rts
}

charrij34Wide:
{
  sta $d016 // switch back to hires

  nop
  nop

  // write here to split at the first column

  nop
  sty $d016
  jsr waste28
  sta $d016-$d8,y
  jsr waste26
  sty $d016
  jsr waste28
  sta $d016-$d8,y
  jsr waste26
  sty $d016
  jsr waste28
  sta $d016-$d8,y
  jsr waste26
  sty $d016
  jsr waste28
  sta $d016-$d8,y
  jsr waste26
  sty $d016
  jsr waste28
  sta $d016-$d8,y
  jsr waste26
  sty $d016
  jsr waste28
  sta $d016-$d8,y
  jsr waste26
  sty $d016
  jsr waste28
  sta $d016-$d8,y

  nop

  sty $d016  // switch back to multicolor for badline

  bit $ea

  rts
}

charrij36Wide:
{
  sta $d016 // switch back to hires

  bit $ea

  // write here to split at the first column

  nop
  sty $d016
  jsr waste30
  sta $d016-$d8,y
  jsr waste24
  sty $d016
  jsr waste30
  sta $d016-$d8,y
  jsr waste24
  sty $d016
  jsr waste30
  sta $d016-$d8,y
  jsr waste24
  sty $d016
  jsr waste30
  sta $d016-$d8,y
  jsr waste24
  sty $d016
  jsr waste30
  sta $d016-$d8,y
  jsr waste24
  sty $d016
  jsr waste30
  sta $d016-$d8,y
  jsr waste24
  sty $d016
  jsr waste30
  sta $d016-$d8,y

  nop

  sty $d016  // switch back to multicolor for badline

  nop

  rts
}

charrij38Wide:
{
  sta $d016 // switch back to hires

  nop
  nop

  // write here to split at the first column

  sty $d016
  jsr waste32
  sta $d016-$d8,y
  jsr waste22
  sty $d016
  jsr waste32
  sta $d016-$d8,y
  jsr waste22
  sty $d016
  jsr waste32
  sta $d016-$d8,y
  jsr waste22
  sty $d016
  jsr waste32
  sta $d016-$d8,y
  jsr waste22
  sty $d016
  jsr waste32
  sta $d016-$d8,y
  jsr waste22
  sty $d016
  jsr waste32
  sta $d016-$d8,y
  jsr waste22
  sty $d016
  jsr waste32
  sta $d016-$d8,y

  sty $d016  // switch back to multicolor for badline

  bit $ea

  rts
}

charrij40Wide:
{
  sta $d016 // switch back to hires

  bit $ea

  // write here to split at the first column

  sty $d016
  jsr waste34
  sta $d016-$d8,y
  jsr waste20
  sty $d016
  jsr waste34
  sta $d016-$d8,y
  jsr waste20
  sty $d016
  jsr waste34
  sta $d016-$d8,y
  jsr waste20
  sty $d016
  jsr waste34
  sta $d016-$d8,y
  jsr waste20
  sty $d016
  jsr waste34
  sta $d016-$d8,y
  jsr waste20
  sty $d016
  jsr waste34
  sta $d016-$d8,y
  jsr waste20
  sty $d016
  jsr waste34
  sta $d016-$d8,y

  sty $d016  // switch back to multicolor for badline

  nop

  rts
}

.align $100
.var  adresses = List().add(charrij4Wide,charrij4Wide,charrij6Wide,charrij8Wide,charrij10Wide,charrij12Wide,charrij14Wide)
.eval adresses.add(charrij16Wide,charrij18Wide,charrij20Wide,charrij22Wide,charrij24Wide,charrij26Wide,charrij28Wide)
.eval adresses.add(charrij30Wide,charrij32Wide,charrij34Wide,charrij36Wide,charrij38Wide,charrij40Wide,0,0)

jsrAdresses:
.lohifill adresses.size(), adresses.get(i)

.var   pauseAt = 4
.const noPause = true

fadeInOut:
{
  lda pause: #0
  beq !+
    rts

  !:
  lda busy: #0
  beq !+
    rts
  !:

  inc busy

  lda wait: #10
  beq dontWait
  dec wait
  
  dec busy
  rts

dontWait:
  // 0. fade out basic columns
  // 1. copy bitmap columns
  // 2. fade in bitmap columns

  ldy width: #0
  cpy #21
  bne continue

  lda #2
  sta nextpart
  dec busy
  rts

continue:
  lda step: #0
  cmp #0
  bne !+
    jmp fadeOutColumn
  !:
  cmp #1
  bne !+
    jmp copyBitmapColumn
  !:
  cmp #2
  bne !+
    jmp fadeInColumn
  !:
  cmp #3
  bne !+
    // go to next column
    
    lda #24               
    sta fadeOutColumn.fadeStep1 // reset fadeout for basic screen columns
    lda #2
    sta fadeOutColumn.fadeStep2 // reset fadein during fadeout
    sta fadeInColumn.fadeStep   // reset fadein for bitmap columns

    lda #0
    sta wait
    lda #0                      // go to fadeout
    sta step

    lda width
    sta irq.width
    inc width
    
  !:
  dec busy
  rts

  fadeOutColumn:
  {
    cpy #20
    bcs skip

    sty columns

    lda #0
    sta wait

    lda fadeStep1: #24  // get current fadestep
    jsr calcFade1       // determine which color goes to which color

    lda fadeStep2: #2  
    jsr calcFade2 

    // width = 0 -> fadeout columns 19,20

    // calculate the left column to fade
    lda columns: #0

    eor #$ff
    clc
    adc #20
    tax
    jsr fadeBasicColumn
    
    // calculate the right column to fade
    lda columns
    clc
    adc #20
    tax

    jsr fadeBasicColumn

    // fade out a bit more..
    lda fadeStep1
    sec
    sbc #2
    sta fadeStep1
    bcs !+
      // when fadeout is completed, go to the next step
  skip:
      inc step

      lda width
      clc
      adc #0
      sta irq.width
    !:
    dec busy
    rts
  }

  copyBitmapColumn:
  {
    cpy #20
    bcs skip

    lda #2
    sta wait

    // width = 0 -> copy columns 19,20
    tya
    eor #$ff
    clc
    adc #20
    tax
    jsr copyColumn
    
    lda fadeInOut.width
    clc
    adc #20
    tax

    jsr copyColumn

  skip:
    lda #5
    sta wait
    inc step
  
    dec busy
    rts
  }

  fadeInColumn:
  {
    cpy #21
    bcc !+
      dec busy
      rts
    !:

    dey
    sty columns

    lda fadeStep: #2  // get current fadestep
    jsr calcFade2     // determine which color goes to which color

    lda #0
    sta wait

    // if width == 0, we can't reveal the bitmap yet..
  
    ldy columns: #0
    bmi finish
    
    // for the first reveal, we have to reveal 6 columns in one go..

    .if (noPause == false)
    {
      cpy #pauseAt-1      // if y=0,1,2 do nothing
      bcc finish
      cpy #pauseAt-1
      bne continue
    } else
    {
      cpy #1
      bcc finish
      cpy #1
      bne continue
    }

    // if y==2, reveal the middle columns

    // if InnerOuter&1 == 0, fade in the middle columns
    // if InnerOuter&1 == 1, fade in the outer columns

    lda innerOuter: #0
    .if (noPause == false)
    {
      lsr
      bcs fadeOuter
    }

    fadeInner:
    {
      // reveal the middle columns aswell..
      ldx #18
      jsr fadeBitmapColumn
      inx
      jsr fadeBitmapColumn
      inx
      jsr fadeBitmapColumn
      inx
      jsr fadeBitmapColumn

      inc innerOuter
      .if (noPause == false) { jmp done } else { jmp nextStep }
    }
    fadeOuter:
    {
      // reveal the outer columns aswell..
      ldx #16
      jsr fadeBitmapColumn
      inx
      jsr fadeBitmapColumn
      ldx #22
      jsr fadeBitmapColumn
      inx
      jsr fadeBitmapColumn

      inc innerOuter
      jmp nextStep
    }

  continue:
    lda columns
    eor #$ff
    clc
    adc #20
    tax

    jsr fadeBitmapColumn
    
    lda columns
    clc
    adc #20
    tax

    jsr fadeBitmapColumn
nextStep:
    lda fadeStep
    clc
    adc #2
    sta fadeStep
    cmp #18
    bne !+
finish:
      inc step

      lda columns
      cmp #pauseAt-1
      bne !+

      .if (noPause == false)
      {
        lda #1 // wait until we can reveal the bitmap
        sta pause
      }
    !:
done:
    dec busy
    rts
  }
}

waste54: nop
waste52: nop
waste50: nop
waste48: nop
waste46: nop
waste44: nop
waste42: nop
waste40: nop
waste38: nop
waste36: nop
waste34: nop
waste32: nop
waste30: nop
waste28: nop
waste26: nop
waste24: nop
waste22: nop
waste20: nop
waste18: nop
waste16: nop
waste14: nop
waste12: rts

* = speedCode "[CODE] speedcode d800"
speedMoveD800Left: 
{
  .for (var row=0; row<25; row++)
  {
    .for (var col=0; col<39; col++)
    {
      lda $d800+row*40+col+1
      sta $d800+row*40+col

      lda basicScreen+row*40+col+1
      sta basicScreen+row*40+col

    }
    lda d800Copy+row*40,x
    sta $d800+row*40+39

    lda basicScreenCopy+row*40,x
    sta basicScreen+row*40+39
  }
  rts
}

* = logoBitmap "[GFX] final bitmap"
.fill picture.getBitmapSize(),picture.getBitmap(i)
* = logoScreenLSB "[GFX] final bitmap screen colors (LSB value)"
.fill picture.getScreenRamSize(),picture.getScreenRam(i)&$0f
* = logoScreenMSB "[GFX] final bitmap screen colors (MSB value)"
.fill picture.getScreenRamSize(),(picture.getScreenRam(i)&$f0)>>4
* = logoD800 "[GFX] final bitmap d800 colors"
.fill picture.getColorRamSize(),picture.getColorRam(i)&$f

* = fontCopy "[GFX] font"
.fill fixedFont.getSize(), fixedFont.get(i)
* = * "[GEN] inverse font, generated" virtual
.fill 1024,0

* = basicScreen "[INH] basic screen" virtual
.fill 1000,0

* = basicScreen2 "[GEN] screen for bitmap - generated by part" virtual
.fill 1000,0

* = bitmap "[GEN] bitmap - generated by part" virtual
.fill 8000,0
* = * "[GFX] sprite"
sprite: .fill 63,0

* = bitmapScreen "[GEN] screen for bitmap - generated by part (gets copied to basicScreen2)" virtual
.fill 1000,0

* = basicScreenCopy "[GEN] copy of bitmap screen to add it back when moving left" virtual
.fill 1000,0

* = d800Copy "[GEN] copy of $d800 colors to add it back when moving left"
.fill 1000,0
