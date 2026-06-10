#import "../00.music/music1.asm"

.label code = $0b00

#if AS_SPINDLE_PART
  .label spindleLoadAddress = code
  *=spindleLoadAddress-18-2-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word 0             // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word 0             // cleanup routine
    .word music_play    // location of playroutine call

    .byte 'S'           // declare safe loading under IO
    .byte 'A'           // avoid : load only what is necessary

    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2(start); jmp start
#endif

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

.macro keepTime() { inc timelow; bne *+4; inc timehigh }

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

  lda #$7f   // disable nmi
  sta $dd0d

  ldx nextpart
  inx
  stx irq.nextPartValue

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  #if !AS_SPINDLE_PART
    :MusicInitCall()
  #endif

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$fa
  sta $d012

  lda $d011
  and #$7f
  sta $d011

  lda #$00
  sta $d015
  
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
  
  // keep border open
  lda $d011
  and #$f7
  sta $d011

  keepTime()

  :MusicPlayCall()
 
  //lda #<irq
  //sta $fffe
  //lda #>irq
  //sta $ffff
  //lda #$fa
  //sta $d012
  //lda $d011
  //and #$7f
  //sta $d011
  
  // reset border
  lda $d011
  and #$7f
  ora #$08
  sta $d011

  // immediately go to the next part when loading is finished..
  lda nextPartValue: #0
  sta nextpart
  
  asl $d019

  pla
  sta $01

  pla
  tay
  pla
  tax
  pla
  rti
}
