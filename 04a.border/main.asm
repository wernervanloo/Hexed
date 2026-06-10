#import "../00.music/music1.asm"

.const playback  = true
.const debug     = false
.const magic     = $63// $57
.const storeFrames = 40

.const startColor         = BLACK
.const endBorderColor     = LIGHT_BLUE
.const endBackgroundColor = BLUE

.label sidBuffer = $3000  // store writes to SID

.label firstByte = $3500
.label code      = $3500
.label screen    = $3800
.label sprites   = $3c00
.label data      = $3c40

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

.label firstZP    = $20
.label jmpIrq       = $20
.label jmpIrqLow    = $21
.label jmpIrqHigh   = $22
.label lastZP     = $22
.macro keepTime() { inc timelow; bne *+4; inc timehigh }

#if AS_SPINDLE_PART
  .label spindleLoadAddress = firstByte
  *=spindleLoadAddress-18-10-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word 0             // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word 0             // cleanup routine
    .word music_play    // location of playroutine call

    .byte 'S'                      // declare safe loading under IO
    .byte 'P', >(sidBuffer), >(sidBuffer+storeFrames*$19)  // protect sidbuffer
    .byte 'Z', <firstZP, <lastZP   // declare zp use
    .byte 'I', >($f000), >($ffff)  // fake 'inherit' data from greetings, so we will not load element54 yet and have censorscroll do that

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

  #if AS_SPINDLE_PART
    lda $01
    sta restore01
  #endif

  lda #$35
  sta $01

  lda #0
  sta ghostbyte

  ldx nextpart
  inx
  stx finalIrq.nextPartValue

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  lda #startColor
  sta $d020
  sta $d021

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
  #endif

  lda #$4c
  sta jmpIrq
  lda #<irq
  sta jmpIrqLow
  lda #>irq
  sta jmpIrqHigh

  lda #<jmpIrq
  sta $fffe
  lda #>jmpIrq
  sta $ffff
  lda #$f9
  sta $d012

  lda $d011
  and #$7f
  sta $d011
  lda #$d8  // multicolor to keep illegal screenmode
  sta $d016

  lda $dc0d
  lda $dd0d
  asl $d019

  #if AS_SPINDLE_PART
    lda restore01: #0
    sta $01
  #endif

  cli
loop:
  .if (playback) { jsr record }

  #if !AS_SPINDLE_PART
    mainLoop:
      cmp ($00,x)
      nop
      jmp mainLoop
  #else
    rts
  #endif
}

record:
{
  lda recording: #0
  bne record

  // wait until the first IRQ before we start recording
  lda recordFrames: #0  // this is also the # of frames we have to record
  beq record

  // start recording
  lda #1
  sta recording

  lda #<sidBuffer
  sta to
  sta playMusic.playBack.from
  lda #>sidBuffer
  sta to+1
  sta playMusic.playBack.from+1

  // swap in RAM under IO
  lda $01
  sta restore01
  lda #$34
  sta $01

  // set up buffer with an improbable value
  ldx #$18
  lda #magic
  {
  loop:
    sta $d400,x
    dex
    bpl loop
  }

recordLoop:
  // play a frame
  jsr playMusic.playDirect

  // store into sidBuffer
  ldx #$18
  storeLoop:
    lda $d400,x
    sta to: sidBuffer,x
    dex
    bpl storeLoop

  // advance the buffer
  lda to
  clc
  adc #$19
  sta to
  bcc !+
    inc to+1
  !:

  inc playMusic.recordedFrames

  dec recordFrames
  lda recordFrames
  bne recordLoop

  //lda #$00
  sta recording // end recording

  // restore IO
  lda restore01: #0
  sta $01

  rts
}

playMusic:
{
  keepTime()

  // if there are recorded frames, we have to play these back instead
  lda recordedFrames: #0
  beq playDirect

  playBack:
  {
    .if (debug) { lda #7; sta $d020 }

    ldx #$18
    writeLoop:
      lda from: sidBuffer,x
      cmp #magic
      bne store
        ldy modified,x  // if the new value is 'magic', but we did modify the value before, than write it anyway
        beq skip        // sid register has never been modified.. so skip the write
      store:
        sta $d400,x
        sta modified,x  // write to modified buffer, so we can keep track if a register has been modified once..
      skip:
      dex
      bpl writeLoop
  ready:
    dec recordedFrames
    lda from
    clc
    adc #$19
    sta from
    bcc !+
      inc from+1
    !:

    .if (debug) { lda #14; sta $d020 }
  }
  rts
playDirect:
  .if (debug) { lda #8; sta $d020 }
  :MusicPlayCall()
  .if (debug) { lda #14; sta $d020 }

  rts
}

modified:
  .fill $19,0

setSpritesOnce:
{
  lda #$ff
  sta $d01d
  lda #$00
  sta $d01c

  lda #endBorderColor
  sta $d027
  sta $d028
  sta $d029
  sta $d02a
  sta $d02b
  sta $d02c
  sta $d02d
  sta $d02e

  lda #(sprites&$3fc0)/64
  sta screen+$3f8
  sta screen+$3f9
  sta screen+$3fa
  sta screen+$3fb
  sta screen+$3fc
  sta screen+$3fd
  sta screen+$3fe
  sta screen+$3ff
  rts
}
setSpritesY:
{
  lda #$05
  sta $d001
  sta $d003
  sta $d005
  sta $d007
  sta $d009
  sta $d00b
  sta $d00d
  sta $d00f
  rts
}
setSprites:
{
  lda #$fc
  sta $d015
}
setLeftX:
{
  inc step
  ldy step: #0

  ldx #$1c+$e0 // assume all sprites in left border

  lda movementL,y
  bmi !+
    ldx #$18+$e0  // right most sprite has $d010 0
  !:
  cmp #$80
  bcc !+
    // if x coordinate becomes negative, subtract 8
    sbc #8
  !:
  sta $d004

  sec
  sbc #$30
  bcs !+
    sbc #7
  !:
  bmi !+
    lda #$80
  !:
  sta $d006

  sec
  sbc #$30
  bcs !+
    sbc #7
  !:
  bmi !+
    lda #$80
  !:
  sta $d008

  // right sprites

  lda movementR,y
  sta $d00a

  clc
  adc #$30
  bpl !+
    lda #$7f
  !:
  sta $d00c

  clc
  adc #$30
  bpl !+
    lda #$7f
  !:
  sta $d00e

  stx $d010

  lda mode,y
  sta sideborderIrq.mode
  lda d021Color,y

  rts
}

// left most=$1b8, normal border from 
// right most=$188
// center position = $0a0 (-> $188 = $e8) (<- $1b8 = $a0)

setSprites2:
{
  lda #$ff
  sta $d015
  lda #$ff
  sta $d017
}
setLeftX2:
{
  inc setLeftX.step

  ldy setLeftX.step
  cpy movementLength
  bne !+
    dey
    dec setLeftX.step
    // end movement
    lda #1
    sta topBorderIrq.ready
  !:

  ldx #$00  // assume no sprites in left border

  lda movementL,y
  // does the first sprite have a negative position?
  cmp #200
  bcc !+  // if the value is below 200, the position is positive
    sbc #8  // compensate for sprite gap
    ldx #%00001111  // all sprites have a negative position
!:
  sta $d000

  // subtract $30 for the next sprite
  sec
  sbc #$30
  bcs !+
    // if we go negative, correct for sprite gap
    sbc #7
    ldx #%00001110  // 3 sprites have negative position
  !:
  sta $d002

  // subtract $30 for the next sprite
  sec
  sbc #$30
  bcs !+
    // if we go negative, correct for sprite gap
    sbc #7
    ldx #%00001100  // 2 sprites have negative position
  !:
  sta $d004

  // subtract $30 for the next sprite
  sec
  sbc #$30
  bcs !+
    // if we go negative, correct for sprite gap
    sbc #7
    ldx #%00001000  // 1 sprite has negative position
  !:
  sta $d006

  // store d010 value
  stx $d010


  // position sprites on the right side

  ldx #$00 // assume all sprites have a position < $100

  lda movementR,y
  bmi !+
    // if the position is positive, all sprites have a position >= $100
    ldx #$f0
  !:
  sta $d008

  // add $30 for the next sprite
  clc
  adc #$30
  bcc !+
    ldx #$e0  // 3 sprites have a position >= $100
  !:
  sta $d00a

  // add $30 for the next sprite
  clc
  adc #$30
  bcc !+
    ldx #$c0  // 2 sprites have a position >= $100
  !:
  sta $d00c

  // add $30 for the next sprite
  clc
  adc #$30
  bcc !+
    ldx #$80  // 1 sprite has a position >= $100
  !:
  sta $d00e

  txa
  ora $d010
  sta $d010

  lda mode,y
  sta sideborderIrq.mode

  lda d021Color,y

  rts
}

.align $100
sideborderIrq:
{
  dec 0            // 10..18
  sta atemp     // 15..23

  lda #39-(19)     // 19..27 <- (earliest cycle)
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
  // cycle 50

  stx xtemp
  sty ytemp

  ldx #$c8
  stx $d016

  lda #<sideborderIrq
  sta jmpIrqLow
  lda #>sideborderIrq
  sta jmpIrqHigh
  
  lda #$00
  //nop
  nop
  nop
  nop
  // cycle 38

  ldy #0
loop:
    sta $d017 // stretch
    dec $d017
    // cycle 50
    dec $d016
    stx $d016
  
    lda #$f8
    sec
    sbc $d012
    // carry clear if we have to open the border

    lda #$07
    adc #0
    sta $d011

    lda #0
    bit $ea

    dey
    beq continue
    bne loop

continue:
    nop
    nop

loop2:
    sta $d017
    dec $d017

    sta $d016
    stx $d016

    nop
    nop
    nop
    lda #0
    inc $dbff
    dec $dbff
    bit $ea
    iny
    cpy #17
    .if (playback == true) { bne loop2 }

loop3:
    sta $d017-$c8,x  // don't stretch anymore..
    asl $dbff

    sta $d016
    stx $d016

    nop
    nop
    nop
    nop
    lda #0
    inc $dbff
    dec $dbff

    iny
    cpy #36
    .if (playback == true) { bne loop3 }

  lda #$07
  sta $d012

  //inc 0
  jsr playMusic

  //dec 0
  // change mode?
  lda mode: #0
  bne toBorderIrq  // go back to normal irq to save rastertime
  .if (playback==false) { beq !+ }

  // no more recorded frames left? go back to normal irq
  lda playMusic.recordedFrames
  bne !+
  
  toBorderIrq:
    lda #<topBorderIrq
    sta jmpIrqLow
    lda #>topBorderIrq
    sta jmpIrqHigh
    lda #$00
    sta $d012
    lda $d011
    and #$7f
    sta $d011
    lda #endBorderColor
    sta $d020
!:
  asl $d019

  jsr setLeftX
  sta $d021

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  inc 0
  rti
}

// this is the phase when only the upper+lower border is open to save rastertime
topBorderIrq:
{
  dec 0
  sta atemp
  stx xtemp
  sty ytemp

  jsr setSpritesY
  jsr setSprites2
  sta $d021
  lda #$c0
  sta $d016

  lda ready: #0
  beq !+
    // we are finished, go to the final IRQ
    lda #<finalIrq
    sta jmpIrqLow
    lda #>finalIrq
    sta jmpIrqHigh
    lda #$f9
    sta $d012
    lda $d011
    and #$7f
    sta $d011
    jmp endIrq

!:
  lda #<multiplexIrq
  sta jmpIrqLow
  lda #>multiplexIrq
  sta jmpIrqHigh
  lda #6+30
  sta $d012
  lda $d011
  and #$7f
  sta $d011

  lda #$ff
  sta $d017
endIrq:
  asl $d019

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  inc 0
  rti
}

multiplexIrq:
{
  dec 0
  sta atemp

  lda $d001
  clc
  adc #42
  sta $d001
  sta $d003
  sta $d005
  sta $d007
  sta $d009
  sta $d00b
  sta $d00d
  sta $d00f

  lda #<multiplex2Irq
  sta jmpIrqLow
  lda #>multiplex2Irq
  sta jmpIrqHigh
  lda #$6+30+42
  sta $d012
  lda $d011
  and #$7f
  sta $d011

  asl $d019

  lda atemp: #0
  inc 0
  rti
}

multiplex2Irq:
{
  dec 0
  sta atemp

  lda $d001
  clc
  adc #42
  sta $d001
  sta $d003
  sta $d005
  sta $d007
  sta $d009
  sta $d00b
  sta $d00d
  sta $d00f

  lda #<multiplex3Irq
  sta jmpIrqLow
  lda #>multiplex3Irq
  sta jmpIrqHigh
  lda #6+30+2*42
  sta $d012
  lda $d011
  and #$7f
  sta $d011

  asl $d019

  lda atemp: #0
  inc 0
  rti
}

multiplex3Irq:
{
  dec 0
  sta atemp

  lda $d001
  clc
  adc #42
  sta $d001
  sta $d003
  sta $d005
  sta $d007
  sta $d009
  sta $d00b
  sta $d00d
  sta $d00f

  lda #<multiplex4Irq
  sta jmpIrqLow
  lda #>multiplex4Irq
  sta jmpIrqHigh
  lda #6+30+3*42
  sta $d012
  lda $d011
  and #$7f
  sta $d011

  asl $d019

  lda atemp: #0
  inc 0
  rti
}

multiplex4Irq:
{
  dec 0
  sta atemp

  lda $d001
  clc
  adc #42
  sta $d001
  sta $d003
  sta $d005
  sta $d007
  sta $d009
  sta $d00b
  sta $d00d
  sta $d00f

  lda #<multiplex5Irq
  sta jmpIrqLow
  lda #>multiplex5Irq
  sta jmpIrqHigh
  lda #6+30+4*42
  sta $d012
  lda $d011
  and #$7f
  sta $d011

  asl $d019

  lda atemp: #0
  inc 0
  rti
}

multiplex5Irq:
{
  dec 0
  sta atemp

  lda $d001
  clc
  adc #42
  sta $d001
  sta $d003
  sta $d005
  sta $d007
  sta $d009
  sta $d00b
  sta $d00d
  sta $d00f

  lda #<borderIrq
  sta jmpIrqLow
  lda #>borderIrq
  sta jmpIrqHigh
  lda #$f9
  sta $d012
  lda $d011
  and #$7f
  sta $d011

  asl $d019

  lda atemp: #0
  inc 0
  rti
}

// actually open the upper+lower borders
borderIrq:
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

  lda $d001
  clc
  adc #42
  sta $d001
  sta $d003
  sta $d005
  sta $d007
  sta $d009
  sta $d00b
  sta $d00d
  sta $d00f

  jsr playMusic

  // reset border
  lda $d011
  ora #$08
  and #$7f
  sta $d011

  lda #<topBorderIrq
  sta jmpIrqLow
  lda #>topBorderIrq
  sta jmpIrqHigh
  lda #$00
  sta $d012

  asl $d019

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

  // kill sprites
  lda #$00
  sta $d015

  // advance to the next part
  lda nextPartValue: #0
  sta nextpart

  jsr playMusic

  // reset border
  lda $d011
  ora #$08
  and #$7f
  sta $d011

  lda #$f9
  sta $d012

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

  // open border
  lda $d011
  and #$f7
  sta $d011

  lda #(screen&$3c00)/$400*$10
  sta $d018

  lda #((screen&$c000)/$4000)|$3c
  sta $dd02

  jsr playMusic

  // stay in this IRQ until the recording has finished
  lda #<irq
  sta jmpIrqLow
  lda #>irq
  sta jmpIrqHigh
  lda #$f9
  sta $d012

  // order recorder to record 50 frames (but only once..)
  .if (playback)
  {
    lda startRecord: #0
    bne !+
      inc startRecord
      lda #storeFrames
      sta record.recordFrames
    !:

  // recording finished?
  lda record.recordFrames
  bne stayIrq // stay in this IRQ until recording has finished
  }
  {
    // don't go to the sideborder Irq if there are no frames to play
    .if (playback)
    {
      lda playMusic.recordedFrames
      beq stayIrq
    }
    
    // go to sideborderIrq
    lda #<sideborderIrq
    sta jmpIrqLow
    lda #>sideborderIrq
    sta jmpIrqHigh
    lda #$06
    sta $d012

    lda $d012
    cmp #$10
    bcc *-5

    jsr setSpritesY
    jsr setSprites
    jsr setSpritesOnce
  }
  stayIrq:

  // wait until $d011 manipulation
  lda $d011
  bpl *-3

  // border open, but screen off 
  lda $d011
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

* = data "[DATA] movement data"
.var positionsL = List()
.var modes      = List()
.var colors     = List()  // background color

movementL:
.var travel    = $98
.var speedLeft = 0.854
.var bounces   = 0
{
.var startPosition = $b8
.var speed         = 0
.var accel         = 0.1
.var position      = startPosition
.var color         = startColor

  .while ((position>240.5) || (bounces==0))
  {
    .eval position = position + speed
    .if ((position>=($f0+travel)) && (bounces==0))
    {
      .eval speed = speed*-1*speedLeft
      .eval bounces = 1
      .var overshoot = position - ($f0+travel)
      .eval position = position - overshoot - 1
      
      .eval color = endBackgroundColor
    }

    .eval speed    = speed    + accel
    .eval positionsL.add(round(position-1)&$ff)
    .eval colors.add(color)

    .if (position < $e9) { .eval modes.add(0) } // use sideborder mode
    else                 { .eval modes.add(1) } // use normal mode
  }
}
.fill positionsL.size(), positionsL.get(i)

movementLength: .byte *-movementL

mode:      .fill positionsL.size(), modes.get(i); .byte 1
d021Color: .fill colors.size(),     colors.get(i)

.print (modes)

movementR:
{
.eval bounces      = 0
.var startPosition = $188
.var speed         = 0
.var accel         = -0.1
.var position      = startPosition

  .for (var i=0; i<positionsL.size(); i++)
  {
    .eval position = position + speed
    .if ((position<=($150-travel)) && (bounces==0))
    {
      .eval speed = speed*-1*speedLeft
      .eval bounces = 1
      .var overshoot = position - ($150-travel)
      .eval position = position - overshoot + 1
    }

    .eval speed    = speed    + accel
    .byte (round(position-1)&$ff)
  }
}

* = sprites "[GFX] sprites"
  .fill 21,[$ff,$ff,$ff]

* = screen+$3f8 "[GFX] spritepointers" virtual
  .fill 8,0

* = sidBuffer "[GEN] buffer" virtual
.fill storeFrames*$19,0

// force driver below $4000
* = $3f7f "[DRIVER] get the driver to go here"
  .byte 0

// the ghostbyte has to stay virtual, or the driver will be placed after it
* = $3fff "[GFX] ghostbyte" virtual
ghostbyte:
  .byte 0