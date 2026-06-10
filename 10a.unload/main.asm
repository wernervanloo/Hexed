#if AS_SPINDLE_PART
  .label code = $f000
#else
  .label code = $f000
#endif

#if AS_SPINDLE_PART
  .label spindleLoadAddress = code
  *=spindleLoadAddress-18-8-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word prepare       // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word 0             // cleanup routine
    .word 0             // location of playroutine call

    .byte 'Z', <firstZP, <lastZP
    .byte 'M',0,0       // unload music
    .byte 'S'           // declare safe loading under IO
    .byte 'A'           // avoid : load only what is necessary

    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2($080e); sei; lda #$35; sta $01; jmp start
#endif

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart  = $02
.label timelow   = $03
.label timehigh  = $04
.label demostate = $05 // mark if we started from this side or not

.label firstZP = $e0
.label jmpIrq  = $e0 // $e0,$e1,$e2
.label lastZP  = $e2


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

  #if !AS_SPINDLE_PART
    lda #$94
    sta $dd00
  #endif

  lda #$3f
  sta $dd02 // ghostbyte $7fff, compatible with rotozoomer

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  // use zp IRQ to keep ghostbyte clear
  lda #JMP_ABS
  sta jmpIrq
  lda #<irq
  sta jmpIrq+1
  lda #>irq
  sta jmpIrq+2

  lda #0
  sta $d015

  lda $d016
  and #$f7
  sta $d016
  
  lda #<jmpIrq
  sta $fffe
  lda #>jmpIrq
  sta $ffff

  lda #$fa
  sta $d012

  lda $d011
  and #$7f
  sta $d011

  lda #$1f
  sta nextpart
  
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
  // if carry = clear, we started from this side
  // if carry = set,   we started from the first side -> demostate = 1
  lda #0
  rol
  sta demostate

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

  lda $d011
  and #$f7
  sta $d011
 
  lda #$3f
  sta $dd02 // ghostbyte $7fff, compatible with rotozoomer

  lda #$fa
  sta $d012

  ldx #40
  loop:
    dex 
    bpl loop
  
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
