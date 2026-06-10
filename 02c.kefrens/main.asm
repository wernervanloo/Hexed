#import "../00.music/music1.asm"

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

.label firstZP  = $10
.label low      = $10
.label high     = $11
.label plotZP   = $10 // 80
.label lastZP   = plotZP+80

.macro keepTime() { inc timelow; bne *+4; inc timehigh }

.label screen    = $0400 // virtual
.label xcos      = $0500 // virtual
.label d011Table = $0600 // virtual
.label charset   = $0800 // virtual
.label firstByte = $bd00
.label code      = $bd00
.label speedCode = $e400 // virtual

#if AS_SPINDLE_PART
  .label spindleLoadAddress = firstByte
  *=spindleLoadAddress-18-19-3 "Spindle header"
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
    .byte 'Z', <firstZP, <lastZP              // declare 0 page use
    .byte 'P', >screen,  >(screen+$0ff)       // protect the screen (first page only)
    .byte 'P', >xcos,    >xcos                // protect generated memory
    .byte 'P', >d011Table, >(d011Table+$0ff)  // protect d011Tab
    .byte 'P', >charset, >(charset+$1ff)      // protect charset
    .byte 'P', >generatedSpeedCode, >(endGeneratedSpeedCode)  // protect generated memory

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

  lda #$00
  sta $d020
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

  lda #(screen&$3c00)/$400*$10 + (charset&$3800)/$800*2
  sta $d018

  lda #$0b
  sta $d022
  lda #$0c
  sta $d023

  #if !AS_SPINDLE_PART
    lda #$94
    sta $dd00
  #endif

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
    jmp mainLoop
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

  // generate d011 table
  ldx #0
  {
  loop:
    txa
    and #$07
    ora #$18
    sta d011Table,x
    inx
    bne loop
  }

  // generate speed code
  jsr genSpeedCode

  // prepare 0page
  ldx #$00
  lda #<charset+7
  ldy #>charset+7
  {
  loop:
    sta plotZP,x
    inx
    sty plotZP,x
    
    clc
    adc #8
    bcc *+3 ;iny
    inx
    cpx #80
    bne loop
  }

  // prepare screen
  ldx #$27
  {
  loop:
    txa
    sta screen,x
    dex
    bpl loop
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
topIrq:
{
  dec 0            // 10..18
  sta atemp        // 15..23
  lda #39-(10)     // 19..27 <- (earliest cycle)
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

  stx xtemp
  sty ytemp

  bit $ea
  ldx #$00
  clc

  jsr generatedSpeedCode

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$fa
  sta $d012
  asl $d019

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  inc 0
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

  lda #$d8
  sta $d016
  lda #$3c
  sta $dd02

  keepTime()

  :MusicPlayCall()
 
  lda #<topIrq
  sta $fffe
  lda #>topIrq
  sta $ffff
  lda #$36
  sta $d012

  lda $d011
  and #$70
  ora #$10
  sta $d011
  
  asl $d019

  inc wait  // wait 5 seconds before going to the next part
  lda wait: #0
  cmp #240
  bne !+
    lda nextPartValue: #0
    sta nextpart
    jmp endIrq // skip updating the kefrens if we go to the next part
  !:

  jsr updateXPos
endIrq:
  lda restore01: #0
  sta $01

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

.var sinLength1 = 224
.var sinLength2 = 97

updateXPos:
{
  inc phase1
  inc phase1
  inc phase2

  ldx phase1: #0
  cpx #sinLength1
  bcc !+
    ldx #0
    stx phase1
  !:

  ldy phase2: #0
  cpy #sinLength2
  bcc !+
    ldy #0
    sty phase2
  !:

  lda #$34
  sta $01

  .for (var i=0; i<193; i++)
  {
    .var extraOffSet = floor(i/32)*60
    .var offset1 = 256-i+extraOffSet*2
    .var offset2 = 65536-2*i+extraOffSet
    
    .if (mod(floor(i/32),2)==1) { .eval offset1 = 256+i+extraOffSet*2 }
    .if (mod(floor(i/32),2)==1) { .eval offset2 = 65536-i }
    
    lda sine1+mod(offset1, sinLength1),x
    clc
    adc sine2+mod(offset2, sinLength2),y
    ror
    sta xcos+i
  }

  lda #$35
  sta $01
  //rts
}

clearChars:
{
  lda #$00
  .for (var i=0; i<40; i++) { sta charset+7+i*8 }
  rts
}

genSpeedCode:
{
  lda #<generatedSpeedCode
  sta low
  lda #>generatedSpeedCode
  sta high

  ldx #0
genLoop:
  // copy prototype to memory
  ldy #speedCodePrototype.end - speedCodePrototype.start - 1
  copyLoop:
    lda speedCodePrototype,y
    sta (low),y
    dey
    bpl copyLoop

  // write table offsets
  txa
  ldy #speedCodePrototype.d011-speedCodePrototype.start
  sta (low),y
  ldy #speedCodePrototype.xco-speedCodePrototype.start
  sta (low),y

  lda low
  clc
  adc #speedCodePrototype.end - speedCodePrototype.start
  sta low
  bcc !+
    inc high
  !:

  inx
  cpx #193
  bne genLoop

  // write RTS at the end
  lda #RTS
  ldy #0
  sta (low),y

  rts
}

speedCodePrototype:
{
start:
  lda d011: d011Table
  // raster e4, cycle 7
  sta $d011
  ldy xco:  xcos
  ldx div4,y
  lda (plotZP+2,x)
  and andData2,y
  ora oraData2,y
  pha
  lda (plotZP,x)
  and andData1,y
  ora oraData1,y
  sta (plotZP,x)
  pla
  sta (plotZP+2,x)
  end:
}

.align $100
* = * "[DATA] div4 table"
div4:
  .fill 256, floor(i/4)*2
* = * "[DATA] AND table"
andData1:
  .fill 64,[%00000000, %11000000, %11110000, %11111100]
* = * "[DATA] AND table"
andData2:
  .fill 64,[%00111111, %00001111, %00000011, %00000000]
* = * "[DATA] ORA table"
oraData1:
  .fill 64,[%01101110, %00011011, %00000110, %00000001]
* = * "[DATA] ORA table"
oraData2:
  .fill 64,[%01000000, %10010000, %11100100, %10111001]


* = * "[DATA] sine 1"
sine1:
{
  .var sinMin    = 0
  .var sinMax    = 100*2
  .var sinLength = sinLength1
  .var sinAmp    = 0.5 * (sinMax-sinMin)

  .for (var i=0; i<2*sinLength1; i++)
  {
    .byte (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength))
  }
}

* = * "[DATA] sine 2"
sine2:
{
  .var sinMin    = 0
  .var sinMax    = 56*2
  .var sinLength = sinLength2
  .var sinAmp    = 0.5 * (sinMax-sinMin)

  .for (var i=0; i<2*sinLength2; i++)
  {
    .byte (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength))
  }
}

// spindle will put the driver here.. reserve some space for it
* = * + $40 "[DRIVER] will go here"

* = speedCode "[GENERATED] speedcode" virtual
generatedSpeedCode:
.for (var i=0; i<193; i++) { .fill speedCodePrototype.end - speedCodePrototype.start, 0 }
.byte RTS
endGeneratedSpeedCode:

* = xcos "[GENERATED] x coordinates" virtual
.fill 256, 0

* = charset "[GENERATED] charset data" virtual
.fill 40*8,0