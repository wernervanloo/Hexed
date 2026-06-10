#import "../00.music/music1.asm"

.var textFile   = LoadBinary("text.bin")
.var timingFile = LoadBinary("timing.bin")

.var textData   = List()
.var timingData = List()

.for (var i=0; i<textFile.getSize(); i++)
{
  .var char = textFile.uget(i)
  .var timing = timingFile.uget(i )
  .eval timing = timing/1.0
  .if (timing <= 1) { .eval timing = 1}

  .if ((char == $20) || (char == $2e)) { .eval char = char }  // space bar or .
  else
  {
    .if (char == $0d) { .eval char = $ff }  // enter
    else
    {
      .if (char >= $40) { .eval char = char - $40 }
    }
  }

  .eval textData.add(char)
  .eval timingData.add(timing)
}

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

// deze worden alleen een keer uitgelezen
.label cursorFlash   = $cd
.label cursorX       = $d3
  .label cursorLow   = $d4
  .label cursorHigh  = $d5
.label cursorY       = $d6
.label d800Low       = $d7
.label d800High      = $d8

.label code = $fb00



#if AS_SPINDLE_PART
  .label spindleLoadAddress = code
  *=spindleLoadAddress-18-10-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word prepare       // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word 0             // cleanup routine
    .word 0             // location of playroutine call

    .byte 'M', <music.play, >music.play
    .byte 'S'
    .byte 'Z', <cursorFlash,<cursorFlash
    .byte 'Z', <cursorX,    <cursorY
    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2($080e); sei; lda #$35; sta $01; jmp start
#endif

* = code "[CODE]"
#import "sfx.asm"

start:
{
  sei

  #if AS_SPINDLE_PART
    lda $01
    sta restore01
  #endif
  lda #$35
  sta $01

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  #if !AS_SPINDLE_PART
    jsr prepare
  #endif

  //lda #0
  //jsr music.init

  jsr sfx.init

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$fa
  sta $d012

  lda $d011
  and #$7f
  sta $d011

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
  jsr determineCursorColor
  
  // now determine the cursor position..
  lda cursorLow
  clc
  adc #40
  bcc !+
    inc cursorHigh
  !:

  sta cursorLow
  sta d800Low

  lda cursorHigh
  and #3
  ora #$d8
  sta d800High

  // now advance two lines
  jsr writeChar.advanceLine
  jsr writeChar.advanceLine

  // print ready
loopReady:
  ldx i: #0
  lda ready,x
  beq end
    jsr writeChar
    inc i
    bne loopReady
end:
  jsr writeChar.advanceLine
  rts
}

ready:
.text "ready."
.byte 0

determineCursorColor:
{
  // we cannot read the cursor color from $0286, since it is overwritten by Spindle.. (booooh!)
  // instead, we will backtrack on the previous line, and read $d800 colors. if we find a different color
  // we will assume that THIS is the cursor color..

  lda #0 // cursorX  start at the start of the row, not in the middle
  sta cursorLow
  
  lda #0
  sta cursorHigh

  ldx cursorY
  beq finished
    nextrow:
      lda cursorLow
      clc
      adc #40
      sta cursorLow
      bcc !+
        inc cursorHigh
      !:
      dex
    bne nextrow
  finished:

  lda cursorHigh
  and #3
  ora #$04
  sta cursorHigh

  // now search for RUN
  // ------------------

  // go to the previous line
  lda cursorLow
  sec
  sbc #40
  sta cursorLow
  bcs !+
    dec cursorHigh
  !:

  // do not go off the screen
  lda cursorHigh
  cmp #$04
  bcs !+
    lda #0
    sta cursorLow
    lda #$04
    sta cursorHigh
  !:

  // calc d800
  lda cursorLow
  sta d800Low
  lda cursorHigh
  and #3
  ora #$d8
  sta d800High

  // read backup cursor color
  ldy #0
  lda (d800Low),y
  sta cursorColor

  // now find the word 'RUN' or R shift-U
loop:
  lda (cursorLow),y
  cmp #$12   // R
  bne notRun
     // is the next character U?
     iny
     lda (cursorLow),y
     and #$bf
     cmp #$15  // U or shift-U?
     bne notRun2
     
     // good enough.. we'll take this position ;-)
     lda (d800Low),y
     and #$0f
     sta cursorColor
     bpl done


notRun:
  iny
notRun2:
  cpy #40
  bne loop
done:
  rts
}

cursorColor:
.byte 255

writeChar:
{
  // set cursor flash to invert cursor almost immediately
  ldy #17
  sty cursorFlash

  // special code : go to the next line
  cmp #$ff
  bne !+
    // undo inverted cursor if needed
    lda blinkCursor.inverted
    beq advanceLine // cursor is not inverted, go to the next line directly
    jsr blinkCursor.blink
    jmp advanceLine
  
  !:
  ldy cursorX

  // write the char at the correct position
  sta (cursorLow),y

  // with the correct color
  lda cursorColor
  sta (d800Low),y

  // set cursor to non-inverted
  lda #0
  sta blinkCursor.inverted

  // move cursor to the right
  iny
  cpy #40
  beq advanceLine
advanceCursor:
  sty cursorX
end:
  rts

  // this routines handles moving to the next line
advanceLine:
  // set cursor back on the left
  lda #0
  sta cursorX

  // to the next line
  ldy cursorY
  iny
  sty cursorY

  // moving off the screen?
  cpy #25
  beq offScreen
    lda cursorLow
    clc
    adc #40
    sta cursorLow
    sta d800Low
    bcc !+
      // we are not moving off the screen..
      inc cursorHigh
      inc d800High
    !:
    rts
  
offScreen:
  // move back to the start of this line
  lda #0
  sta cursorX
  // take the last line
  lda #24
  sta cursorY

  // no need to update cursorHigh and d800High
scrollUp:
  lda #1
  sta irq.scrolling

  lda #<$0428
  sta up.rowLoop.readScreen
  sta up.rowLoop.readD800
  lda #<$0400
  sta up.rowLoop.writeScreen
  sta up.rowLoop.writeD800
  lda #>$0428
  sta up.rowLoop.readScreen+1
  sta up.rowLoop.writeScreen+1
  lda #>$d828
  sta up.rowLoop.readD800+1
  sta up.rowLoop.writeD800+1

  ldy #24
  up: {
    screenLoop:
    ldx #39
    rowLoop:
    {
      lda readScreen:  $0428,x
      sta writeScreen: $0400,x
      lda readD800:    $d828,x
      sta writeD800:   $d800,x
      dex
      bpl rowLoop
    }
    
    lda rowLoop.readScreen
    sta rowLoop.writeScreen
    sta rowLoop.writeD800
    clc
    adc #40
    sta rowLoop.readScreen
    sta rowLoop.readD800

    ldx rowLoop.readScreen+1
    stx rowLoop.writeScreen+1
    bcc !+
      inx
      stx rowLoop.readScreen+1
    !:

    ldx rowLoop.readD800+1
    stx rowLoop.writeD800+1
    bcc !+
      inx
      stx rowLoop.readD800+1
    !:

    dey
    bpl screenLoop
  }

  // write empty line at the bottom of the screen
  ldx #39
  lda #$20
  loop:
    sta $07c0,x
    dex
    bpl loop

  lda #0
  sta irq.scrolling
  rts
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

  jsr sfx.play

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$fa
  sta $d012
  lda $d011
  and #$7f
  sta $d011
  
  asl $d019

  lda scrolling: #0
  bne skipCharOut

  lda wait: #timingData.get(0)

  // we need to trigger a sound 8 frames before plotting
  cmp #2
  bne !+
    // do not make a tick for when the demo starts
    ldx textPointer
    lda theMessage,x
    beq !+
      jsr sfx.init
      jsr sfx.trigger
  !:
  
  lda wait
  // check if a key is pressed
  bne skipOutput

    ldx textPointer: #0
    lda timings+1,x
    bne !+
      lda #1  // don't write a 0..
    !:
    sta wait

    lda theMessage,x
    bne !+
      // advance to the next part allowed
      lda #1
      sta nextpart

      lda #0
      jsr music.init

      lda #255
      sta wait

      ldy cursorX
      lda #$a0
      sta (cursorLow),y
      lda cursorColor
      sta (d800Low),y
      
      jmp skipOutput
    !:
      inc textPointer
      
      sta charTemp

      lda charTemp: #0

      cli // writeChar can take some time if the screen has to move up..
      jsr writeChar

skipOutput:  
  dec wait
skipCharOut:

  lda scrolling
  bne !+
  lda nextpart
  bne !+
    jsr blinkCursor
  !:

  // do nothing.. just load everything..

  pla
  sta $01
  pla
  tay
  pla
  tax
  pla
  rti
}

blinkCursor:
{
  // keep cursor blinking?
  inc cursorFlash
  lda cursorFlash
  cmp #20
  bne dontflash
blink:
  lda #0
  sta cursorFlash

  // set inversion
  lda inverted: #0
  eor #1
  sta inverted

  ldy cursorX
invert:
  lda (cursorLow),y
  eor #$80
  sta (cursorLow),y

  lda cursorColor
  sta (d800Low),y
dontflash:
  rts
}

* = * "[DATA] text data"
theMessage:
.fill textData.size(), textData.get(i)
timings:
.fill timingData.size(), timingData.get(i)
.byte 10

.print (textData)
