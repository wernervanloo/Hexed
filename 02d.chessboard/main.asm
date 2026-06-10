#import "../00.music/music1.asm"

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.const charOffset = $000

.var sinLength1 = 128
.var sinLength3 = 100
.var sinLength4 = 83

.var sinLength5 = 110
.var sinLength6 = 87

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

.label firstZP   = $6e
.label tempy     = $6e
.label plotColor = $6f
.label low       = $70
.label high      = $71
.label plotZP    = $70 // 82
.label lastZP    = plotZP+82

.macro keepTime() { inc timelow; bne *+4; inc timehigh }

.label charset     = $d000 // virtual
.label screen      = $d400 // virtual
.label charset2    = $d800 // virtual
.label firstByte   = $da00
.label codeUnderIO = $da00
.label code        = $e000


#if AS_SPINDLE_PART
  .label spindleLoadAddress = firstByte
  *=spindleLoadAddress-18-14-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word prepare       // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word cleanup       // cleanup routine
    .word music_play    // location of playroutine call

    .byte 'S'           // declare safe loading under IO
    .byte 'A'           // avoid loading
    .byte 'Z', <firstZP,  <lastZP              // declare 0 page use
    .byte 'I', >screen,   >(screen+$0ff)       // protect the screen (first page only)
    .byte 'I', >charset+charOffset,  >(charset+ charOffset+40*8)     // protect charset
    .byte 'I', >charset2+charOffset, >(charset2+charOffset+40*8)     // protect charset

    .byte 0
    .word spindleLoadAddress    // Load address

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

  lda #$0b
  sta $d020
  lda #$0c
  sta $d021

  ldx nextpart
  inx
  stx irq.nextPartValue

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

    jsr prepare

    :MusicInitCall()
  #endif

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$fa
  sta $d012

  lda $d011
  and #$6f
  sta $d011

  lda #$00
  sta $d015
  
  lda $dc0d
  lda $dd0d
  asl $d019

  lda #$0b
  sta $d022
  lda #$0c
  sta $d023

  #if !AS_SPINDLE_PART
    lda #$94
    sta $dd00
  #endif

  // prepare screen
  ldx #0
  lda #$34
  sta $01
  {
  lda #(charOffset/8)
  {
  loop:
    sta screen,x
    clc
    adc #1
    inx
    cpx #40
    bne loop
  }
  }
  lda #$35
  sta $01
  
  ldx #39
  lda #$07|8
  loop:
    sta $d800,x
    dex
    bpl loop

  #if AS_SPINDLE_PART
    lda restore01: #0
    sta $01
  #endif

  cli

  #if !AS_SPINDLE_PART
mainLoop:
    // simulate handover
    lda nextpart
  wait:
    cmp nextpart
    beq wait
    jsr cleanup
    jmp *
  #else
    rts
  #endif
}

prepare:
{
  // clear chars -> hide by making the border smaller
  /*
  ldx #$7f
  lda #$00
  {
  loop:
    sta charset,x
    sta charset+$80,x
    sta charset+$100,x
    dex
    bpl loop
  }
  */

  // prepare 0page
  ldx #$00
  lda #<charset+charOffset+7
  ldy #>charset+charOffset+7
  {
  loop:
    sta plotZP,x
    inx
    sty plotZP,x
    
    clc
    adc #8
    bcc *+3 ;iny
    inx
    cpx #82
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

.align $100
chessIrq:
{
  dec 0            // 10..18
  sta irq.atemp        // 15..23

  lda #39-10       // 19..27 <- (earliest cycle)
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

  sty tempy
  stx irq.xtemp

  nop

  ldy height:    #$10
  ldx #0

loop:
  clc
  lda $d012
  adc #$1
  and #$07
  ora #$10
  sta $d011

  // do we have to switch?
  cpy #0
  bne keepChecker
    
    lda yLow:   #0
    adc addLow: #0
    sta yLow

    lda addHigh: #$10
    adc #0
    tay

    inc $dbff
    dey
    nop
    nop
   
    inx
    cpx #$c1

    lda $d018
    eor #((charset&$3800)/$800*2)^((charset2&$3800)/$800*2)
    sta $d018

    bcc loop
    jmp irq.enter

keepChecker:
  inc $dbff
  inc $dbff
  inc $dbff
  inc $dbff
  dey
  bit $ea
  inc $dbff
  inx
  cpx #$c1
  bne loop
end:
  jmp irq.enter
}

irq:
{
  dec 0
  sta atemp
  stx xtemp
  sty tempy
enter:

  inc 0
  lda $01
  sta restore01
  lda #$35
  sta $01

  lda #$c8
  sta $d016
  lda #((screen&$c000)/$4000)|$3c
  sta $dd02
  
  keepTime()

  :MusicPlayCall()
 
  lda #<chessIrq
  sta $fffe
  lda #>chessIrq
  sta $ffff
  lda #$36
  sta $d012

  lda $d011
  and #$70
  ora #$10
  sta $d011
  
  asl $d019

  // wait 5 seconds before going to the next part
  inc wait
  lda wait: #0
  cmp #240
  bne !+
    lda nextPartValue: #0
    sta nextpart
  !:

  lda #$34
  sta $01
  {
    jsr move
    jsr plotChessBoard
  }
  lda #$35
  sta $01

  lda d018: #0
  sta $d018

  lda restore01: #0
  sta $01

  lda atemp: #0
  ldx xtemp: #0
  ldy tempy
  rti
}

* = codeUnderIO "[CODE] code under IO"

move:
{
  inc phase
  ldx phase: #0

  cpx #sinLength1
  bcc !+
    ldx #0
    stx phase
  !:

  lda sineLow,x
  sta chessIrq.addLow
  sta plotChessBoard.addLow
  
  lda sineHigh,x
  sta chessIrq.addHigh
  sta plotChessBoard.width

  // set middle position for up+down
  inc phaseX1
  ldx phaseX1: #0
  cpx #sinLength5
  bcc !+
    ldx #0
    stx phaseX1
  !:
  inc phaseX2
  ldy phaseX2: #34
  cpy #sinLength6
  bcc !+
    ldy #0
    sty phaseX2
  !:

  lda sineY1,x
  clc
  adc sineY2,y
  ror
  sta chessIrq.height
  lda #$80
  sta chessIrq.yLow

  // set middle position for left+right

  inc phaseX3
  ldx phaseX3: #60
  cpx #sinLength3
  bcc !+
    ldx #0
    stx phaseX3
  !:
  inc phaseX4
  ldy phaseX4: #44
  cpy #sinLength4
  bcc !+
    ldy #0
    sty phaseX4
  !:

  lda sineX1,x
  clc
  adc sineX2,y
  ror
  sta plotChessBoard.startWidth
  lda #$80
  sta plotChessBoard.widthLow

  // move left+right

  // -standard position is at the top left
  // -if we want to move it to the right, say 40 pixels, follow this algorithm
  // 
  // -do we need to move right > width pixels?
  //  loop:
  //  -no->exit
  //  -yes:
  //   -invert start color
  //   -subtract width from xpos
  //   -loop

  // set start color and start charset

  lda #0
  sta plotColor

  lda #(screen&$3c00)/$400*$10 + (charset&$3800)/$800*2
  sta irq.d018

loop:
  lda plotChessBoard.startWidth
  cmp plotChessBoard.width
  bcc moveUpDown
    bne !+
      // if equal, compare the low part
      lda plotChessBoard.widthLow
      cmp plotChessBoard.addLow
      bcc moveUpDown
    !:
    lda plotChessBoard.widthLow
    sec
    sbc plotChessBoard.addLow
    sta plotChessBoard.widthLow
    lda plotChessBoard.startWidth
    sbc plotChessBoard.width
    sta plotChessBoard.startWidth
    lda plotColor
    eor #$ff
    sta plotColor
    jmp loop

  // move up+down

moveUpDown:
  lda chessIrq.height
  cmp chessIrq.addHigh
  bcc end
    bne !+
      // if equal, compare the low part
      lda chessIrq.yLow
      cmp chessIrq.addLow
      bcc end 
    !:
    lda chessIrq.yLow
    sec
    sbc chessIrq.addLow
    sta chessIrq.yLow
    lda chessIrq.height
    sbc chessIrq.addHigh
    sta chessIrq.height

    lda irq.d018
    eor #((charset&$3800)/$800*2)^((charset2&$3800)/$800*2)
    sta irq.d018

    jmp moveUpDown
end:
  rts
}

plotChessBoard:
{
  lda width
  sec
  sbc #8
  sta width

  ldx #0      // start at char 0
  ldy startWidth: #0   // # of pixels still to plot with current color

  lda plotColor

loop:
  //lda plotColor     // load current color
  cpy #8            // do we have to switch now?
  bcs !+
    eor plotData,y  // calculate byte to plot
    sta (plotZP,x)  // plot byte

    lda widthLow: #0
    //clc           // carry is already clear by bcs
    adc addLow: #0
    sta widthLow

    tya
    adc width: #0
    {
      tay
    
      lda plotColor   // load current color
      eor #$ff        // reverse and store it
      sta plotColor

      jmp continue2   // checkers here are alway > 8 pixels.. so skip the check

      //cmp #8       // if the next checker ends beyond this char
      //bcs continue // , we can continue immediately 
      
      tay          // draw the next checker in the same char
      lda (plotZP,x)
      jmp loop   
    }    
    bne continue

  !:
  // do not switch yet
  sta (plotZP,x)    // plot byte
  tya               // subtract 8 pixels
continue:
  sec
  sbc #8
  tay

  // store plot color in the next char
  lda plotColor

continue2:
  inx              // next char
  inx

  sta (plotZP,x)

  cpx #80
  bne loop

  .for (var i=0; i<40; i++)
  {
    lda charset+charOffset+7+i*8
    eor #$ff
    sta charset2+charOffset+7+i*8
  }
  rts
}

plotData:
  .byte %11111111  // switch after 0 pixels
  .byte %01111111, %00111111, %00011111, %00001111, %00000111, %00000011, %00000001

.var sine = List()
{
  .var sinMin    = 16
  .var sinMax    = 80
  .var sinLength = sinLength1
  .var sinAmp    = 0.5 * (sinMax-sinMin)

  .for (var i=0; i<512; i++)
  {
    .eval sine.add( (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength)) )
  }
}

sineLow:
  .fill 255, 256*(sine.get(i) - floor(sine.get(i)))
sineHigh:
  .fill 255, floor(sine.get(i))

* = * "[DATA] sine x1"
sineX1:
{
  .var sinMin    = 80-40
  .var sinMax    = 80+40
  .var sinLength = sinLength3
  .var sinAmp    = 0.5 * (sinMax-sinMin) * 2

  .for (var i=0; i<sinLength; i++)
  {
    .byte ( (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength)) )
  }  
}
* = * "[DATA] sine x2"
sineX2:
{
  .var sinMin    = 80-40
  .var sinMax    = 80+40
  .var sinLength = sinLength4
  .var sinAmp    = 0.5 * (sinMax-sinMin) * 2

  .for (var i=0; i<sinLength; i++)
  {
    .byte ( (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength)) )
  }  
}

* = * "[DATA] sine y1"
sineY1:
{
  .var sinMin    = 60-60
  .var sinMax    = 60+60
  .var sinLength = sinLength5
  .var sinAmp    = 0.5 * (sinMax-sinMin) * 2

  .for (var i=0; i<sinLength; i++)
  {
    .byte ( (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength)) )
  }  
}
* = * "[DATA] sine y2"
sineY2:
{
  .var sinMin    = 40-40
  .var sinMax    = 40+40
  .var sinLength = sinLength6
  .var sinAmp    = 0.5 * (sinMax-sinMin) * 2

  .for (var i=0; i<sinLength; i++)
  {
    .byte ( (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength)) )
  }  
}

* = charset+charOffset  "[GENERATED] charset data" virtual
.fill 40*8,0
* = charset2+charOffset "[GENERATED] charset data" virtual
.fill 40*8,0