#import "../00.music/music1.asm"

#if AS_SPINDLE_PART
  .label code = $0a00
#else
  .label code = $0a00
#endif

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
    .word cleanup       // cleanup routine
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

* = code "[CODE]"
start:
{
  sei

  lda $01
  sta restore01
  lda #$35
  sta $01

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
  sta $d011

  lda $dc0d
  lda $dd0d
  asl $d019

  lda restore01: #0
  sta $01

  cli
loop:
  #if !AS_SPINDLE_PART
    jmp *
  #else
    rts
  #endif
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

irq:
{
  sta atemp
  stx xtemp
  sty ytemp

  lda $01
  sta restore01
  lda #$35
  sta $01

  inc timelow
  bne !+
    inc timehigh
  !:

  :MusicPlayCall()
 
  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$fa
  sta $d012
  lda $d011
  and #$7f
  sta $d011
  
  // immediately go to the next part when loading is finished..
  lda nextPartValue: #0
  sta nextpart
  
  asl $d019

  lda restore01: #0
  sta $01

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

