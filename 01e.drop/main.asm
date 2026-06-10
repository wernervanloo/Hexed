#import "../00.music/music1.asm"
// don't look at this code.. I should have done opening the border using an NMI..
// I thought it would be easier this way, but ofcourse it wasn't and I made a complete mess..

// ---------------------------------------------
// these are the demo spanning 0 page adresses -
// do not declare them in the Spindle header.. -
// ---------------------------------------------

.const spritePosition = $32-5

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

// ---------------------
// locations in memory -
// ---------------------

#if !AS_SPINDLE_PART
  .label inhD800  = $8000 // for standalone we have to load the inherited $d800 colors somewhere
#endif

.label bitmap     = $4000
.label screen     = $6000
.label sprites    = $6400
.label code       = $6c00

.const KOALA_TEMPLATE = "C64FILE, Bitmap=$0000, ScreenRam=$1f40, ColorRam=$2328, BackgroundColor = $2710"

* = bitmap "[GFX] bitmap without tube" virtual
  .fill 8000, 0
* = screen  "[GFX] screen without tube" virtual
  .fill 1000, 0

// ------------------------------
// load and convert the sprites -
// ------------------------------

.var spritePicture = LoadPicture("./includes/sprites3.png", List().add($000000, $588D43, $9AD284, $ffffff))

.var spritesWide = ceil((spritePicture.width)/24)
.var spritesHigh = ceil((spritePicture.height)/21)

.print ("nr Sprites = " + spritesWide*spritesHigh)

.var spriteData = List(); .for (var i=0; i<spritesWide*spritesHigh*64; i++) { .eval spriteData.add(0) }

// convert to sprites
.for (var charX=0; charX<(spritePicture.width)/8; charX++)
{
  .for (var y=0; y<spritePicture.height; y++)
  {
    // read value
    .var value = spritePicture.getMulticolorByte(charX,y)

    // what sprite is this in the spritemap?
    .var spriteColumn = floor(charX/3)
    .var spriteRow    = floor(y/21)

    // modify the vertical order to simplify multiplexing (do as much as possible during compile time)
    // 4 rows:
    // row 0 = spriterow 0
    // row 1 = spriterow 2
    // row 2 = spriterow 1 (0+1)
    // row 3 = spriterow 3 (2+1)

    // 5 rows:
    // row 0 = spriterow 0
    // row 1 = spriterow 3
    // row 2 = spriterow 1 (0+1)
    // row 3 = spriterow 4 (3+1)
    // row 4 = spriterow 2 (1+1)

    .var spriteRow2   = (spriteRow&$fe) / 2
    .if (mod(spriteRow,2)==0) { .eval spriteRow2 = spriteRow / 2 }
    .if (mod(spriteRow,2)==1) { .eval spriteRow2 = spriteRow2 + floor((spritesHigh+1)/2) } 

    // byte in sprite
    .var spriteByte   = mod(charX, 3) + (3 * mod(y, 21))

    // position in the spritemap
    .var position = (spriteRow2*64) + (spriteColumn*spritesHigh*64) + spriteByte

    // write data at correct position
    .eval spriteData.set(position, value)
  }
}

// ----------------
// spindle header -
// ----------------

#if AS_SPINDLE_PART
  .label spindleLoadAddress = sprites
  *=spindleLoadAddress-18-7-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"            // fileformat magic
    .word prepare           // prepare routine
    .word start             // setup routine
    .word 0                 // irq handler
    .word 0                 // main routine
    .word 0                 // fadeout routine
    .word 0                 // cleanup routine
    .word music_play        // location of playroutine call

    .byte 'S'
    .byte 'I', >(bitmap),     >(bitmap+$1fff)
    .byte 'I', >(screen),     >(screen+$3ff)

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

  #if AS_SPINDLE_PART
    lda $01
  #else
    lda #$35
  #endif

  sta restore01
  lda #$35
  sta $01

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  ldx nextpart
  inx
  stx nextPartValue

  #if !AS_SPINDLE_PART
    lda #0
    sta $d021

    lda #0
    sta timelow
    sta timehigh

    jsr music.init

    jsr prepare

    lda #$94
    sta $dd00
  #endif

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$00
  sta $d012

  lda $d011
  and #$7f
  sta $d011

  lda $dc0d
  lda $dd0d
  asl $d019

  // for standalone, copy the d800 colors to d800 mem
  #if !AS_SPINDLE_PART
    ldx #0
    {
    loop: .for (var page=0; page<4; page++)
      {
        lda inhD800+page*$100,x
        sta $d800+page*$100,x
      }
      inx
      bne loop
    }
  #endif

  lda restore01: #0
  sta $01

  cli
loop:
  #if !AS_SPINDLE_PART
    jmp loop
  #else
    rts
  #endif
}

nextPartValue:
.byte 0

prepare:
{
  rts
}

setSprites:
{
  // if ypos is too high, turn off sprites 
  lda yposHigh
  bne !+
    lda d015: #$ff
    sta $d015
  !:

  .var pos = $18 + 16*8

  // sprite column
  lda #pos
  sta $d000
  sta $d002
  lda #pos+$18
  sta $d004
  sta $d006
  lda #pos+$30
  sta $d008
  sta $d00a

  lda #0
  sta $d010

  // background sprites
  lda #pos
  sta $d00c
  lda #pos+$10
  sta $d00e
  
  lda #$ff
  sta $d01c
  lda #$c0
  sta $d017
  sta $d01d

  lda col1: #$d     //a
  sta $d027
  sta $d028
  sta $d029
  sta $d02a
  sta $d02b
  sta $d02c
  lda col0: #$5     //9
  sta $d025
  lda col2: #$1     //7
  sta $d026

  lda #$00
  sta $d02d
  sta $d02e
}
setSprites2:
{
  lda yposLow
  sta $d00d   // 64
  sta $d00f   // 128

  // column sprites
  lda yposLow
  sta $d001   // 1
  sta $d005   // 4
  sta $d009   // 16
  clc
  adc #21
  sta $d003   // 2
  sta $d007   // 8
  sta $d00b   // 32

  ldx #(sprites/64)
  stx screen+$3f8
  ldx #(sprites/64)+floor((spritesHigh+1)/2)
  stx screen+$3f9

  ldx #(sprites/64)+spritesHigh
  stx screen+$3fa
  ldx #(sprites/64)+spritesHigh+floor((spritesHigh+1)/2)
  stx screen+$3fb

  ldx #(sprites/64)+2*spritesHigh
  stx screen+$3fc
  ldx #(sprites/64)+2*spritesHigh+floor((spritesHigh+1)/2)
  stx screen+$3fd

  ldx #(backGroundSprite/64)
  stx screen+$3fe
  stx screen+$3ff

  rts
}

yspeedLowLow: .byte $00
yspeedLow:    .byte $00
yspeedHigh:   .byte $00
yposLowLow:   .byte $00
yposLow:      .byte $30  // start in lower border
yposHigh:     .byte $01  // at position $130

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

  lda #$00  // turn off sprites
  sta $d015
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
  
  lda #$32
  sta $d001
  sta $d003
  sta $d005
  sta $d007
  sta $d009
  sta $d00b
  sta $d00d
  sta $d00f

  lda #$3a
  sta $d011
  lda #$d8
  sta $d016

  lda #$3d
  sta $dd02

  lda #((screen&$3c00)/$400)*$10+((bitmap&$2000)/$2000)*8
  sta $d018

  inc timelow
  bne !+
    inc timehigh
  !:

  :MusicPlayCall()
 
  lda #irqReset
  sta $fffe
  lda #>irqReset
  sta $ffff
  
  jsr script
  jsr colors

  // accellerate down... 
  lda drop: #0
  bne *+5; jmp notFinished

  lda yspeedLowLow
  clc
  adc #32
  sta yspeedLowLow

  lda yspeedLow
  adc #0
  sta yspeedLow

  lda yspeedHigh
  adc #0
  sta yspeedHigh

  // add to speed...

  lda yposLowLow
  clc
  adc yspeedLowLow
  sta yposLowLow

  lda yposLow
  adc yspeedLow
  sta yposLow

  lda yposHigh
  adc yspeedHigh
  sta yposHigh

  // bounce?

  lda bounce: #0
  bne bounced
  {
    lda yposLow
    cmp #86
    bcc bounced

    lda yspeedHigh
    eor #$ff
    sta yspeedHigh

    lda yspeedLow
    eor #$ff
    sta yspeedLow

    lda yspeedLowLow
    eor #$ff
    sta yspeedLowLow

    inc bounce
  }
bounced:

  // ---------
  // finished?
  // ---------

  lda yposHigh
  beq notFinished
  {
    lda yposLow
    cmp #$30
    bcc notFinished
    {
      lda #$00
      sta yposHigh
      lda #$32
      sta yposLow

      lda runOnce: #0
      bne notFinished
      {
        // go to the next part..
        lda nextPartValue
        sta nextpart

        inc runOnce

        lda #0
        sta $d015
        sta setSprites.d015

      }
    }
  }
notFinished:

  lda appear: #0
  beq continue

  ldx step: #0
  lda moveUp,x
  sta appear  // end move up if we get at the final position.. magic.
  clc
  adc #spritePosition
  sta yposLow
  lda #0
  adc #0
  sta yposHigh
  inc step

continue:

  // calculate a good place to start the first IRQ..
  lda #$f0     // assume $f0 as a start..
  ldx yposHigh
  bne !+       // go with the first assumption
    lda #$2e-5
!:
  //lda #$2e-5
  sta $d012
  lda $d011
  and #$7f
  sta $d011

  asl $d019

  // update bitmap?
  lda update: #0
  beq !+
  {
    lda #0
    sta update
    cli
    jsr updateBitmap
  }
!:
  pla
  sta $01

  pla
  tay
  pla
  tax
  pla
  rti
}

irqReset:
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

  lda #0
  sta waitingForBorder  // mark that we are waiting to open the border

  lda #<irqMultiplex
  sta $fffe
  lda #>irqMultiplex
  sta $ffff

  // set y position here
  jsr setSprites

  lda yposHigh
  beq !+
  lda yposLow
  cmp #$32-21
  bcc !+

  lda $d015
  and #$ff-2-8-32  // turn off sprites 2,4,6
  sta $d015
  jmp cont

!:
  lda setSprites.d015   // sprites high enough, turn all of them on..
  sta $d015
cont:

  lda #24

  jsr setNextD012
  
  asl $d019

  cmp #$80           // if d012 >=$100, then we have to force the border
  bcs forceBorder
  lda yposHigh       // if we are too far even (rasterline > $100), then the next IRQ is set to $000.. so check yposHigh aswell..
  bne forceBorder

  cpx #242
  bcc !+
    forceBorder:
    // the next irq is late for opening the border, so do a waitloop here..
    jsr openBorder.forceBorderOpen
  !:

  pla
  sta $01
  pla
  tay
  pla
  tax
  pla
  rti
}

waitingForBorder: .byte 0

irqMultiplex:
{
  pha
  txa
  pha

  lda $01
  pha

  lda #<irqMultiplex2
  sta $fffe
  lda #>irqMultiplex2
  sta $ffff

  lda #24+21
  jsr setNextD012
  jsr moveSpritesDown

  asl $d019

  inc screen+$3f8
  inc screen+$3fa
  inc screen+$3fc

  jmp endIrq
}

setNextD012:
{
  // calculate next $d012 trigger
  {
    clc
    adc yposLow
    sta $d012
    tax

    lda yposHigh
    adc #0
    bne !+
      lda $d011
      and #$7f
      jmp setd011
    !:
      // is a next irq necessary?
      cpx #$30
      bcs abortIrq
      lda $d011
      ora #$80
    setd011:
      sta $d011
      sta d011Value
  }

  // are we above $f6? then move to $ff to avoid messing with openborder wait
  cpx #$f4
  bcc !+
    ldx #$ff
    stx $d012
  !:
  rts

abortIrq:
  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$00
  sta $d012
  lda $d011
  and #$7f
  sta $d011
  sta d011Value
  rts
}

irqMultiplex2:
{
  pha
  txa
  pha

  lda $01
  pha

  lda #<irqMultiplex3
  sta $fffe
  lda #>irqMultiplex3
  sta $ffff
  
  lda #24+2*21
  jsr setNextD012
  
  asl $d019

  inc screen+$3f9
  inc screen+$3fb
  inc screen+$3fd
  
  jmp endIrq
}

irqMultiplex3:
{
  pha
  txa
  pha

  lda $01
  pha

  lda #<irqMultiplex4
  sta $fffe
  lda #>irqMultiplex4
  sta $ffff
  
  lda #24+3*21
  jsr setNextD012
  jsr moveSpritesDown

  asl $d019

  inc screen+$3f8
  inc screen+$3fa
  inc screen+$3fc

  jmp endIrq
}

irqMultiplex4:
{
  pha
  txa
  pha

  lda $01
  pha

  lda #<irqMultiplex5
  sta $fffe
  lda #>irqMultiplex5
  sta $ffff
  lda #24+4*21
  
  jsr setNextD012
  
  asl $d019

  inc screen+$3f9
  inc screen+$3fb
  inc screen+$3fd  
  
  jmp endIrq
}

irqMultiplex5:
{
  pha
  txa
  pha

  lda $01
  pha

  lda #<irqMultiplex6
  sta $fffe
  lda #>irqMultiplex6
  sta $ffff
  
  lda #24+5*21
  jsr setNextD012
  jsr moveSpritesDown

  asl $d019

  inc screen+$3f8
  inc screen+$3fa
  inc screen+$3fc

  jmp endIrq
}

irqMultiplex6:
{
  pha
  txa
  pha

  lda $01
  pha

  lda #<irqMultiplex7
  sta $fffe
  lda #>irqMultiplex7
  sta $ffff
  lda #24+6*21
  jsr setNextD012
  
  asl $d019
  
  inc screen+$3f9
  inc screen+$3fb
  inc screen+$3fd  
  
  jmp endIrq
}

irqMultiplex7:
{
  pha
  txa
  pha

  lda $01
  pha

  lda #<irqMultiplex8
  sta $fffe
  lda #>irqMultiplex8
  sta $ffff
  
  lda #24+7*21
  jsr setNextD012
  jsr moveSpritesDown

  asl $d019

  inc screen+$3f8
  inc screen+$3fa
  inc screen+$3fc

  jmp endIrq
}

irqMultiplex8:
{
  pha
  txa
  pha

  lda $01
  pha

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$00
  sta $d012
  lda $d011
  and #$7f
  sta $d011
  
  asl $d019
  
  inc screen+$3f9
  inc screen+$3fb
  inc screen+$3fd  
  
  lda waitingForBorder
  bne endIrq
  
  jsr openBorder.forceBorderOpen
  jmp endIrq.skip
}


endIrq:
{
  jsr openBorder
skip:
  pla
  sta $01

  pla
  tax
  pla
  rti
}

moveSpritesDown:
{
  lda $d001
  clc
  adc #42
  sta $d001
  sta $d005
  sta $d009

  sta $d00d
  sta $d00f

  clc
  adc #21
  sta $d003
  sta $d007
  sta $d00b
  rts
}

openBorder:
{
  lda waitingForBorder
  bne dontOpenBorder     // in another routing we are already waiting to open the lower border

  // open the lower border?
  lda $d011
  bmi dontOpenBorder
  lda $d012
  cmp #$f6-21
  bcc dontOpenBorder
forceBorderOpen:

    cli

    // mark that we are waiting to open the borders..
    lda #1
    sta waitingForBorder
   
    // wait for correct rasterline to open lower border
    waitd012:
      lda $d011
      bmi dontOpenBorder
      lda $d012
      cmp #$f8
      bcc waitd012
    
      lda d011Value
      and #$f7
      sta $d011
  dontOpenBorder:
  rts
}

d011Value: .byte 0

// -------------
// script engine
// -------------

.const Wait          = $80
.const WaitUntil     = $00
.const ChangeColors  = $01
.const StartDrop     = $02
.const End           = $03
.const Update        = $04  // update bitmap
.const StartAppear   = $05  // let the logo appear

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
    bne done
  }
  !:
  cmp #ChangeColors
  bne !+
  {
    lda scriptData+1,x
    sta colors.step
    inx
    jmp done
  }
  !:
  cmp #StartDrop
  bne !+
  {
    lda #1
    sta irq.drop
    bne done
  }
  !:
  cmp #Update
  bne !+
  {
    lda #1
    sta irq.update
    bne done
  }
  !:
  cmp #StartAppear
  bne !+
  {
    lda #1
    sta irq.appear
    bne done
  }
  !:
  cmp #End
  bne !+
  {
    rts
  }
  !:
done:
  inx
  stx scriptPointer
done2:
  rts
}

scriptData:
  #if AS_SPINDLE_PART  
    .byte WaitUntil, $04,$00  // wait until fixed time in the demo for music synching
  #else
    .byte WaitUntil, $00,$7c   // wait 1 second as test in standalone
  #endif

  .byte StartAppear            // move the logo onto the screen
  .byte Wait,100               // wait until it is in position

  .byte Update                 // update the bitmap once the tube is in position
  .byte ChangeColors,1

  .byte WaitUntil, $04,$80
  .byte ChangeColors,34

  .byte WaitUntil,$05,$68
  .byte StartDrop

  // wait some frames until the sprites have completely dropped and we start the bitmap fade
  .byte Wait, 200
  // we will never get here. the drop will start the continue to the next part by itself.
  // bitmapFade will fade for a certrain frame# to continue
  .byte End

col0Tab:
  .byte $ff
  .byte $00,$00,$00,$00,$00,$00,$00
  .byte $09,$09,$09,$09,$09,$09,$09,$06,$00,$00,$00,$00
  .byte $00,$00,$00,$00,$06,$09,$02,$0b,$04,$08,$0e,$0c,$05,$ff

  .byte $00,$00,$00,$00,$00,$00,$00
  .byte $0c,$0e,$08,$04,$0b,$02,$09,$06,$00,$00,$00,$00,$00,$00
  .byte $00,$00,$00,$00,$00,$00,$00,$06,$09,$02,$0b,$04,$08,$0e,$0c,$ff

col1Tab:
  .byte $ff
  .byte $08,$09,$00,$00,$00,$09,$08
  .byte $05,$0c,$0e,$08,$04,$0b,$02,$09,$06,$00,$00,$00
  .byte $00,$00,$06,$09,$02,$0b,$04,$08,$0e,$0c,$05,$0a,$03,$ff

  .byte $08,$09,$00,$00,$00,$09,$08
  .byte $0a,$05,$0c,$0e,$08,$04,$0b,$02,$09,$06,$00,$00,$00,$00
  .byte $00,$00,$00,$00,$06,$09,$02,$0b,$04,$08,$0e,$0c,$05,$0a,$03,$ff

col2Tab:
  .byte $ff
  .byte $05,$04,$06,$00,$06,$04,$05

  .byte $0f,$03,$0a,$05,$0c,$0e,$08,$04,$0b,$02,$09,$06
  .byte $09,$02,$0b,$04,$08,$0e,$0c,$05,$0a,$03,$0f,$07,$0d,$ff

  .byte $05,$04,$06,$00,$06,$04,$05
  .byte $07,$0f,$03,$0a,$05,$0c,$0e,$08,$04,$0b,$02,$09,$06,$00
  .byte $06,$09,$02,$0b,$04,$08,$0e,$0c,$05,$0a,$03,$0f,$07,$0d,$01,$ff

colors:
{
  lda wait: #1
  beq continue
  dec wait
  rts
continue:
  lda #1
  sta wait

  ldx step: #0
  lda col0Tab,x
  bmi end

  sta setSprites.col0
  lda col1Tab,x
  sta setSprites.col1
  lda col2Tab,x
  sta setSprites.col2
  inc step
end:
  rts
}

updateBitmap:
{
  // copy middle column to bitmap
  ldy #24       // rows to copy
  rowLoop:
    ldx #(8*8)-1  // bytes per row to copy
    loop:
      lda readFrom: newBitmapData,x
      sta writeTo:  bitmap+16*8,x
      dex
      bpl loop
    
    lda readFrom
    clc
    adc #8*8
    sta readFrom
    bcc !+
      inc readFrom+1
      clc
    !:

    lda writeTo
    adc #$40
    sta writeTo
    lda writeTo+1
    adc #1
    sta writeTo+1

    dey
    bpl rowLoop

  // copy colors to bitmap
  {
  ldy #0
  rowLoop:
    ldx #0
    loop:
      lda newScreenData,y
      sta writeTo: screen+16,x
      iny
      inx
      cpx #8
      bne loop

    lda writeTo
    clc
    adc #40
    sta writeTo
    bcc !+
      inc writeTo+1
    !:
    cpy #25*8
    bne rowLoop
  }

  // copy d800 colors to bitmap
  {
    ldy #0
    rowLoop:
      ldx #0
      loop:
        lda newD800Data,y
        sta writeTo: $d800+16,x
        iny
        inx
        cpx #8
        bne loop

      lda writeTo
      clc
      adc #40
      sta writeTo
      bcc !+
        inc writeTo+1
      !:
      cpy #25*8
      bne rowLoop
  }

  rts
}

* = * "[DATA] move up data"
moveUp:
{
  .var startPosition = spritePosition
  .var maxPosition   = $130
  .var speed         = 0
  .var acceleration  = 0.125  // same acceleration as down motion
  .var position = startPosition
  .var positions = List()

  .while (position < maxPosition)
  {
    .eval positions.add(round(min(position, maxPosition))-startPosition)
    .eval speed = speed + acceleration
    .eval position = position + speed
  }
  .print (positions)

  .for (var i=positions.size()-1; i>=0; i--) { .byte positions.get(i) }
}

.var picture = LoadBinary("../01.graphics/bitmap_tube2_fix.kla", KOALA_TEMPLATE)

* = * "[GFX] middle column for d800"
newD800Data:
.for (var row=0; row<25; row++)
{
  .for (var col=0; col<8; col++)
  {
    .var pos = (row*40)+(col+16)
    .byte picture.getColorRam(pos)
  }
}

* = * "[GFX] middle column for bitmap"
newBitmapData:
.for (var row=0; row<25; row++)
{
  .for (var col=0; col<8; col++)
  {
    .for (var byte=0; byte<8; byte++)
    {
      .var pos = (row*320)+((col+16)*8)+byte
      .byte picture.getBitmap(pos)
    }
  }
}

* = * "[GFX] middle column for screen"
newScreenData:
.for (var row=0; row<25; row++)
{
  .for (var col=0; col<8; col++)
  {
    .var pos = (row*40)+(col+16)
    .byte picture.getScreenRam(pos)
  }
}

// -----------------------------
// put sprite data into memory -
// -----------------------------

* = sprites "[GFX] spritemap"
  .fill spriteData.size(), spriteData.get(i)
backGroundSprite:
  .fill 64,$aa

// ------------------------------
// load the bitmap without tube -
// only for standalone..        -
// ------------------------------

#if !AS_SPINDLE_PART

  .var pictureLogo = LoadBinary("../01.graphics/bitmap_fix.kla", KOALA_TEMPLATE)

  // put the bitmap with logo at the position in memory where we would inherit it from the previous part

  * = bitmap "[INHERIT] bitmap"
  .fill pictureLogo.getBitmapSize(),pictureLogo.getBitmap(i)

  * = screen "[INHERIT] screen colors"
  .fill pictureLogo.getScreenRamSize(),pictureLogo.getScreenRam(i)

  * = inhD800 "[INHERIT] d800 colors"
  .fill pictureLogo.getColorRamSize(),pictureLogo.getColorRam(i)
#endif
