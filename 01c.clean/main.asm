#import "../00.music/music1.asm"

.const KOALA_TEMPLATE = "C64FILE, Bitmap=$0000, ScreenRam=$1f40, ColorRam=$2328, BackgroundColor = $2710"
.var picture   = LoadBinary("../01.graphics/bitmap_fix.kla", KOALA_TEMPLATE)

#if AS_SPINDLE_PART
  .label code = $e040
#else
  .label code = $e040
#endif

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

.label bitmap       = $2000
.label bitmapScreen = $0800

.label bitmapScreenStandalone = $4000

#if AS_SPINDLE_PART
  .label spindleLoadAddress = code
  *=spindleLoadAddress-18-8-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word 0             // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word 0             // cleanup routine
    .word music_play    // location of playroutine call

    .byte 'S'
    .byte 'A'           // avoid loading
    .byte 'I', >(bitmap), >(bitmap+$1fff)
    .byte 'I', >(bitmapScreen), >(bitmapScreen+$3ff)

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

  :MusicInitCall()

  ldx nextpart
  inx
  stx fadeIrq.nextPartValue

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$f9
  sta $d012

  lda $d011
  and #$7f
  sta $d011

  #if !AS_SPINDLE_PART
    lda #$3a
    sta $d011

    lda #$d8
    sta $d016

    lda #(bitmap&$2000)/$2000*8+(bitmapScreen&$3c00)/$400*$10
    sta $d018

    ldx #0
    copyLoop:
    .for (var i=0; i<4; i++)
    {
      lda bitmapScreenStandalone+i*$100,x
      sta bitmapScreen+i*$100,x
    }
    inx
    bne copyLoop

  #endif

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

irq:
{
  sta atemp
  stx xtemp
  sty ytemp

  lda $01
  sta restore01
  lda #$35
  sta $01

  lda #<fadeIrq
  sta $fffe
  lda #>fadeIrq
  sta $ffff
  lda #$00
  sta $d012

  lda $d011
  and #$7f
  sta $d011
  
  // we can modify the last line here.
  lda $d020
  sta $d021

  inc timelow
  bne !+
    inc timehigh
  !:

  :MusicPlayCall()
 

  asl $d019

  lda restore01: #0
  sta $01

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

fadeIrq:
{
  sta atemp
  stx xtemp
  sty ytemp

  // fade border
  ldy nextPartValue: #0
  lda wait: #3
  bne continue
  {
    lda #3
    sta wait
    lda $d020
    and #$0f
    tax
    lda posInColorRamp,x
    bne cont

      sty nextpart
      jmp continue

    cont:
    tax
    dex
    lda colorRamp,x
    sta $d020
  }
continue:
  dec wait

  lda #BLACK
  sta $d021

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$f9
  sta $d012
  lda $d011
  and #$7f
  sta $d011

  asl $d019

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

colorRamp:
  .byte $0,$6,$9,$2,$b,$4,$8,$e,$c,$5,$a,$3,$f,$7,$d,$1
posInColorRamp:
  .byte 00,15,03,11,05,09,01,13,06,02,10,04,08,14,07,12

#if !AS_SPINDLE_PART
  * = bitmap "[GFX] standalone bitmap"
  .fill picture.getBitmapSize(),picture.getBitmap(i)

  * = bitmapScreenStandalone "[GFX] standalone screen"
  .fill picture.getScreenRamSize(),picture.getScreenRam(i)
#endif
