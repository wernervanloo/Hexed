#import "../00.music/music1.asm"

.const KOALA_TEMPLATE = "C64FILE, Bitmap=$0000, ScreenRam=$1f40, ColorRam=$2328, BackgroundColor = $2710"
.var updateBitmap = false  // update to 2nd bitmap here?

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

.label bitmap        = $2000  // the bitmap with logo from basic fade is here
.label bitmapScreen  = $0800  // the bitmap with logo from basic fade is here
.label bitmap2       = $4000  // copy the bitmap here...
.label bitmapScreen2 = $6000  // copy the bitmap here...
.label code          = $e240

#if AS_SPINDLE_PART
  .label spindleLoadAddress = code
  *=spindleLoadAddress-18-11-3 "Spindle header"
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
    .byte 'A'           // avoid loading
    .byte 'I', >(bitmap),       >(bitmap+$1fff)            // inherit previous bitmap
    .byte 'I', >(bitmapScreen), >(bitmapScreen+$3ff)       // inherit previous screen
    .byte 'P', >(bitmap2),      >(bitmapScreen2+$3ff)      // protect the new bitmap

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

  #if !AS_SPINDLE_PART
    :MusicInitCall()

    jsr prepare
  #endif

  ldx nextpart
  inx
  stx irq.nextPartValue

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
  // copy bitmap from bank 0 to bank 1
  ldx #0
  {
  loop:
    .for (var page=0; page<32; page++)
    {
      lda bitmap+page*$100,x
      sta bitmap2+page*$100,x
    }
    .for (var page=0; page<4; page++)
    {
      lda bitmapScreen+page*$100,x
      sta bitmapScreen2+page*$100,x    
    }
    inx
    beq end
    jmp loop
    end:
  }

  .if (updateBitmap == true)
  {
    // copy middle column to bitmap
    ldy #24       // rows to copy
    rowLoop:
      ldx #(8*8)-1  // bytes per row to copy
      loop:
        lda readFrom: newBitmapData,x
        sta writeTo:  bitmap2+16*8,x
        dex
        bpl loop
      
      lda readFrom
      clc
      adc #8*8
      sta readFrom
      bcc !+
        inc readFrom+1
      !:

      lda writeTo
      clc
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
        sta writeTo: bitmapScreen2+16,x
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

  inc timelow
  bne !+
    inc timehigh
  !:

  :MusicPlayCall()
 
  lda nextPartValue: #0
  sta nextpart

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

  lda restore01: #0
  sta $01

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

// --------------------------------------------------------
// put column data into memory for the bitmap with the tube
// --------------------------------------------------------

.var picture = LoadBinary("../01.graphics/bitmap_tube2_fix.kla", KOALA_TEMPLATE)

* = * "[GFX] middle column for bitmap"
newBitmapData:
.if (updateBitmap == true)
{
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
}

* = * "[GFX] middle column for screen"
newScreenData:
.if (updateBitmap == true)
{
  .for (var row=0; row<25; row++)
  {
    .for (var col=0; col<8; col++)
    {
      .var pos = (row*40)+(col+16)
      .byte picture.getScreenRam(pos)
    }
  }
}