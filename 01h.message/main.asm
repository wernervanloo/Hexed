#import "../00.music/music1.asm"
.var message = LoadPicture("./includes/bitmap.png")
.const stepSize = 16
.const nrFld    = ceil(200/stepSize)
.const step     = 3

// convert bitmap
.var bitmapData = List()
.for (var b=0; b<8000; b++)
{
  .var row  = floor(b/320)
  .var byte = b&7
  .var col  = (b-(320*row)-byte)/8
  .var y    = row*8+byte
  .var value = message.getSinglecolorByte(col,y)
  .eval bitmapData.add(value)
}

.label screen      = $5c00
.label bitmap      = $6000
.label firstByte   = $6400 // the first $400 bytes are load at the back
.label extraBitmap = $8000
.label code        = $8400

#if AS_SPINDLE_PART
  .label spindleLoadAddress = firstByte
  *=spindleLoadAddress-18-7-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word prepare       // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word 0             // cleanup routine
    .word music_play    // location of playroutine call

    .byte 'S'
    .byte 'P', >screen, >(screen+$3e8) // protect the screen
    .byte 'P', >bitmap, >(bitmap+$3ff) // this is where the first part of the bitmap is copied to

    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2(start); sei; lda #$35; sta $01; jmp start
#endif


// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

* = code "[CODE]"
start:
{
  sei

  #if AS_SPINDLE_PART
    lda $01
    sta restore01
  #else
    lda #0
    sta timelow
    sta timehigh
    lda #BLACK
    sta $d020
  #endif

  lda #$35
  sta $01

  inc nextpart // preload immediately
  ldx nextpart
  inx
  stx irq.nextPartValue

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d
  
  :MusicInitCall()

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$fa
  sta $d012

  lda $d011
  and #$6f
  ora #$20
  sta $d011

  #if !AS_SPINDLE_PART
    lda #$94
    sta $dd00

    jsr prepare
  #endif
  
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

prepare:
{
  ldx #0
  {
  loop:
    .for (var i=0; i<4; i++)
    {
      lda extraBitmap+i*$100,x
      sta bitmap+i*$100,x
    }
    inx
    bne loop
  }

  ldx #39
  {
  loop:
    lda #$76
    .for (var i= 0; i<4; i++)  { sta screen+i*40,x }
    .for (var i= 6; i<10; i++) { sta screen+i*40,x }
    .for (var i=12; i<16; i++) { sta screen+i*40,x }
    .for (var i=18; i<22; i++) { sta screen+i*40,x }
    sta screen+24*40,x

    lda #$36
    sta screen+4*40,x
    sta screen+5*40,x
    sta screen+10*40,x
    sta screen+11*40,x
    sta screen+16*40,x
    sta screen+17*40,x
    sta screen+22*40,x
    sta screen+23*40,x
    dex
    bpl loop
  }
  rts
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

  lda #(bitmap&$2000)/$2000*8 + ((screen&$3c00)/$400)*$10
  sta $d018
  lda #((bitmap&$c000)/$4000)|$3c
  sta $dd02

  lda #$c8
  sta $d016
  
  // let all the rows bounce at the same time
  lda #$32
  sta fldIrq.startPos
  // set standard only one fld
  lda #0
  sta fldIrq.nrLines
  sta fld1
  sta fldIrq.addLines
  lda #$ff
  sta fld1+1
  sta fld1+nrFld

  lda moveIn:   #1
  ora bounceIn: #1
  bne fadeIn
  jmp fadeOut
fadeIn:
  {
    lda moveIn
    beq !+
      // move the picture in
      ldx phase: #0
      inc phase
      lda movement,x
      cmp #$ff  // end of movement?
      bne !+
        lda #0
        sta moveIn
        dec phase
      !:
      sta fldIrq.nrLines
      sta fld1
      sta fldIrq.addLines

    lda phase2: #0
    clc
    adc add: #1
    cmp #((bounceEnd-bounce))
    bne !+
      ldx #0
      stx add
      stx bounceIn
    !:
    sta phase2
    tax

    .for (var i=1; i<10; i++)
    {
      lda bounce+(nrFld-i)*step,x
      sta fld1+i
    }

    // reset FLD irq 
    lda #1
    sta fldIrq.fldNr

    jmp end
  }
fadeOut:
  .var fadeOutLength = moveOutEnd - moveOut
  lda wait
  sec
  sbc #fadeOutLength
  bcs end

    ldx phase3: #((moveOutEnd-moveOut-1))
    lda moveOut,x
    sta fldIrq.nrLines
    sta fld1
    lda #$ff
    sta fld1+1

    cpx #0
    beq end
      dec phase3

end:
  inc timelow
  bne !+
    inc timehigh
  !:

  :MusicPlayCall()
 
  lda #<fldIrq
  sta $fffe
  lda #>fldIrq
  sta $ffff
  lda #$32
  sta $d012
  lda #$33
  sta $d011
  
  lda wait: #250
  beq ready
    dec wait
    jmp continue

  ready:
    lda nextPartValue: #0
    sta nextpart
  continue:

  asl $d019

  lda restore01: #0
  sta $01

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

fld1: .fill nrFld+1, 0

fldIrq: // first start this at raster $2f
{
  dec 0
  sta atemp
  stx xtemp

  lda nrLines: #20
  cmp #7
  lda $d012  // we need the $d012 value in both branches.
  bcs setIrq
  
  // we can set d011 now and end the fld
  sec
  adc nrLines
  and #$07
  ora #$30
  sta $d011
checkNext:
  ldx fldNr: #1
  // is there a next FLD?
  lda fld1,x
  cmp #$ff
  beq endAllFLD // no.. end all FLD's

  // where should the next FLD be at?

  lda startPos: #$2f
  clc
  adc addLines: #0   // previous FLD lines

  // test if the first FLD already makes the screen invisible..
  bcs endAllFLD  // if invisible, end all FLD's
  cmp #$f8
  bcs endAllFLD  // if invisible, end all FLD's

  // add where the next FLD should start
  clc
  adc #stepSize
  sta startPos

  // is the position where this FLD should start invisible?
  bcs endAllFLD  // if invisible, end all FLD's
  cmp #$f8
  bcs endAllFLD

  // we got here, so the next FLD starts at a visible spot
  sta $d012

  // next FLD
  inc fldNr

  lda fld1,x
  sta nrLines
  sta addLines

  // is the next FLD a 0 line FLD?
  bne endIrq    // no.. go to it.
  beq endIrq
  beq checkNext // check the next FLD

endAllFLD:
  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$08
  sta $d012
  lda $d011
  ora #$80
  sta $d011

endIrq:
  asl $d019

  lda atemp: #0
  ldx xtemp: #0
  inc 0
  rti

setIrq:
  // calc rasterline to trigger next irq
  // clc  // carry is alway set.. so abuse it
  adc #5  // add 5 instead of 6 because carry is set
  bcs endAllFLD
  //cmp #$f8
  //bcs endAllFLD

  sta $d012

  clc
  adc #1
  and #$07
  ora #$30
  sta $d011  // set $d011 to do an FLD

  lda nrLines // 6 lines less to fld..
  // we want to subtract 6, normally sec, sbc #6
  // but we abuse that carry is clear and sbc #5
  sbc #5
  sta nrLines

  jmp endIrq
}

* = * "[DATA] y movement for fade in and fade out"
.var framesUntilBounce = 0
movement:
{
  .var positions     = List()

  .var startPosition = 200
  .var maxBounce     = 2
  .var startSpeed    = 0
  .var endPosition   = 0
  .var a             = -0.3
  .var bounces       = 0
  .var position      = startPosition
  .var speed         = startSpeed

  .while (bounces<maxBounce)
  {
    .eval speed = speed + a
    .eval position = position + speed

    .if (position < endPosition)
    {
      .if (bounces == 0) { .eval framesUntilBounce = positions.size() }
      .eval speed     = speed * -0.3
      .var overShoot = endPosition - position
      .eval position  = endPosition + overShoot * 0.5
      .eval bounces   = bounces + 1

      .if (bounces == maxBounce) { .eval position = endPosition }
    }

    .eval positions.add(round(position))
  }
  .print (positions)
  .fill positions.size(), positions.get(i)
  .byte $ff
}
movementEnd:




.var positions     = List()
.var startPosition = 0
{
  .var maxBounce     = 2
  .var startSpeed    = 2
  .var endPosition   = 0
  .var a             = -0.21
  .var bounces       = 0
  .var position      = startPosition
  .var speed         = startSpeed

  .while (bounces<maxBounce)
  {
    .eval speed = speed + a
    .eval position = position + speed

    .if (position < endPosition)
    {
      .eval speed     = speed * -0.6
      .var overShoot = endPosition - position
      .eval position  = endPosition + overShoot * 0.5
      .eval bounces   = bounces + 1

      .if (bounces == maxBounce) { .eval position = endPosition }
    }

    .eval positions.add(round(position))
  }
}

fromBounce: .byte framesUntilBounce

bounce:
* = * "[DATA] bounce"
  .fill framesUntilBounce+nrFld*step,0
  .fill positions.size(), positions.get(i)
bounceEnd:
  .fill nrFld*step,0


* = * "[DATA] y movement for fade in and fade out"
moveOut:
{
  .var startPosition = 200
  .var endPosition   = 0
  .var position      = startPosition
  .var nrFrames      = 40

  // given the startPosition, end Position and speed, what is the equation for this parabola?
  // x=x0+v0*t+0.5*a*t*t 
  // x(t) = xo + v0*t + 0.5*a*t*t
  // v(t) = v0 + a*t
  // v(nrFrames) = 0 = v0 + a*nrFrames

  // a = (0-v0) / nrFrames

  // x(t) = xo + v0*t + 0.5*a*t*t
  // 0    = startP + v0*nrFrames + 0.5*(0-v0) * nrFrames
  // v0*nrFrames + 0.5(0-v0) * nrFrames = -startP
  // v0*F + -0.5*v0*F = -startP
  // v0 = -2* startP / F

  .var startSpeed = -2 * startPosition / nrFrames
  .var a          = -startSpeed / nrFrames

  .for (var i=0; i<nrFrames; i++)
  {
    .var position = startPosition + startSpeed*i + 0.5*a*i*i
    .byte round(position)
  }
}
moveOutEnd:

* = extraBitmap "[GFX] first 4 pages of bitmap"
.var eorValue = $00
.fill $140, bitmapData.get(i)^eorValue
.fill $2c0, bitmapData.get(i+$140)^eorValue

* = screen "[GEN] screen, generated" virtual
.fill 1000,$10

* = bitmap+$400 "[GFX] message"
.fill bitmapData.size()-$400, bitmapData.get(i+$400)^eorValue
