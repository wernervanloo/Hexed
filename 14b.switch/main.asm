#import "../00.music/music2.asm"

.const switch  = 11  // switch after 11 rows

#if AS_SPINDLE_PART
  .label code = $0920
#else
  .label code = $0920
#endif

.label screen        = $0400  // gets inherited from heaven and we give it to scrollway
.label charset1a     = $2000  // gets inherited from heaven and we give it to scrollway
.label charset2a     = $2800  // gets inherited from heaven and we give it to scrollway
.label logoScreen    = $f400  // gets inherited from heaven and we give it to scrollway
.label logoCharset   = $f800  // gets inherited from heaven and we give it to scrollway

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
    .word music_play    // location of playroutine call

    .byte 'I', >screen, >(screen+$3ff)               // inherit top part of picture from heaven
    .byte 'I', >charset1a, >(charset2a+$7ff)         // inherit top part of picture from heaven
    .byte 'I', >logoScreen, >(logoCharset+$7ff)      // inherit top part of picture from heaven
    .byte 'S'                                        // declare safe loading under IO
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
  stx irq1.nextPartValue

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  :MusicInitCall()

  lda #<irq1
  sta $fffe
  lda #>irq1
  sta $ffff
  lda #$32+switch*8 //8a
  sta $d012

  lda $d011
  and #$7f
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

prepare:
{
  rts
}

// this is the irq below the logo, switching to the first charset of the scroller
// ------------------------------------------------------------------------------
irq1:
{
  sta atemp

  lda $01
  sta restore01
  lda #$35
  sta $01

  lda #$1b
  sta $d011

  lda #<irq2
  sta $fffe
  lda #>irq2
  sta $ffff

  lda #$fb
  sta $d012
  asl $d019

  lda #((screen&$3c00)/$400*$10)+((charset1a&$3800)/$800*2)
  sta $d018
  lda #$3c
  sta $dd02

  lda nextPartValue: #0
  sta nextpart

  lda restore01: #0
  sta $01
  lda atemp: #0
  rti
}

irq2:
{
  sta atemp
  stx xtemp
  sty ytemp

  lda $01
  sta restore01
  lda #$35
  sta $01

  lda #$d8
  sta $d016
  lda #((logoScreen&$3c00)/$400*$10)+((logoCharset&$3800)/$800)*2
  sta $d018
  lda #$3f
  sta $dd02

  inc timelow
  bne !+
    inc timehigh
  !:

  :MusicPlayCall()
 
  lda #0
  sta nextpart

  lda #<irq1
  sta $fffe
  lda #>irq1
  sta $ffff  
  lda #$32+switch*8 //8a
  sta $d012
  lda $d011
  and #$7f
  sta $d011
  
  asl $d019

  lda restore01: #0
  sta $01

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

