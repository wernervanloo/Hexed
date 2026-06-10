#import "../00.music/music2.asm"

// 312 rasterlines 
// 312/32 = 9.75
// -> go for 10 blocks of 31 rasters high, first and last can be 32 high.
// 32 * 8*31 + 32 = 312
// this will also look almost square since pixels are a little taller than wide

.const border     = BLACK
.const background = BLACK
.const col0       = BLACK      // starting color
.const offset     = 7

.var offsetLine   = 10
.var maxFade      = 32+14
.const endFade    = 9*offsetLine+maxFade

.const firstHeight = 32
.const blockHeight = 31
.const lastHeight  = 32

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

.label firstZP  = $e0
  .label atemp  = $e0
  .label xtemp  = $e1
  .label ytemp  = $e2
  .label temp01 = $e3
  .label jmpIrq = $e4 // $e4,$e6,$e6
.label lastZP   = $e6

#if AS_SPINDLE_PART
  .label firstByte = $0600
  .label sprites   = $0600
  .label code2     = $073f
  .label code      = $0800
  .label screen    = $0400  // spritepointers at 27f8
#else
  .label firstByte = $2600
  .label sprites   = $2600
  .label code2     = $273f
  .label code      = $2800
  .label screen    = $2400  // spritepointers at 27f8
#endif

#if AS_SPINDLE_PART
  .label spindleLoadAddress = firstByte
  *=spindleLoadAddress-18-10-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"                 // fileformat magic
    .word 0                      // prepare routine
    .word start                  // setup routine
    .word 0                      // irq handler
    .word 0                      // main routine
    .word 0                      // fadeout routine
    .word 0                      // cleanup routine
    .word music_play             // location of playroutine call

    .byte 'I', >$6000, >$cfff    // 'fake inherit' : do not load later parts yet
    .byte 'I', >$fc00, >$ffff    // 'fake inherit' : do not load $fc00-$ffff yet
    .byte 'S'                    // declare safe loading under IO
    .byte 'Z', firstZP, lastZP   // declare used zp adresses

    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2(quickstart); quickstart: sei; lda #$35; sta $01; jmp start
#endif

* = code "[CODE] main"
col0Colors:
  .fill 10,0
col1Colors:
  .fill 10,0
col2Colors:
  .fill 10,0

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

  ldx nextpart
  inx
  stx exitIrq.nextPartValue

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

    lda #$94
    sta $dd00

    :MusicInitCall()
  #endif

  lda #border
  sta $d020
  .if (border!=background) { lda #background }
  sta $d021

  lda #JMP_ABS
  sta jmpIrq
  lda #<firstFrameIrq
  sta jmpIrq+1
  lda #>firstFrameIrq
  sta jmpIrq+2

  lda #<jmpIrq
  sta $fffe
  lda #>jmpIrq
  sta $ffff

  lda #$f9
  sta $d012

  lda #$d8   // select illegal screenmode
  sta $d016

  lda $d011
  ora #$50
  and #$7f
  sta $d011

  lda $dc0d
  lda $dd0d
  asl $d019

  cli

  ldx #0
  loop:
    lda #BLUE
    sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $db00,x
    inx
    bne loop

  #if AS_SPINDLE_PART
    lda restore01: #0
    sta $01
    rts
  #else
  mainLoop:
    cmp ($00,x)
    bit $ea
    jmp mainLoop
  #endif
}

firstFrameIrq:
{
  jsr startIrq

  lda #(screen&$c000)/$4000|$3c
  sta $dd02

  lda #(screen&$3c00)/$400*16+(($0000&$3800)/$800*2)
  sta $d018

  lda #<irq
  sta jmpIrq+1
  lda #>irq
  sta jmpIrq+2
  lda #$f9
  sta $d012

  jsr playMusic
}
endIrq:
{
  asl $d019
  lda atemp
  ldx xtemp
  ldy ytemp
  inc 0
  rti
}

startIrq:
{
  dec 0
  sta atemp

  lda #39-(19-1)     // 19..27 <- (earliest cycle)
  sec              // 21..29
  sbc $dc06        // 23..31, A becomes 0..8
  and #$0f
  sta *+4          // 27..35
  bpl *+2          // 31..39
  lda #$a9         // 34
  lda #$a9         // 36
  lda #$a9         // 38
  lda #$a9         // 38
  lda #$a9         // 38
  lda #$a9         // 38
  lda $eaa5        // 40
                   // at cycle 34+(10) = 44

  stx xtemp
  sty ytemp
  rts
}

resetIrq:
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

  lda #<m1Irq
  sta jmpIrq+1
  lda #>m1Irq
  sta jmpIrq+2
  lda #31+offset
  sta $d012
  asl $d019

  ldx #0
  jsr updateColors

  cli
  jsr playMusic

  pla
  sta $01
  pla
  tay
  pla
  tax
  pla
  rti
}

playMusic:
{
  :MusicPlayCall()
  rts
}

m1Irq:
{
  jsr startIrq

  lda #<m2Irq
  sta jmpIrq+1
  lda #>m2Irq
  sta jmpIrq+2
  lda #31+31+offset
  sta $d012

  ldx #1

  jsr updateColors
  jsr updateY
  jmp endIrq
}

m2Irq:
{
  jsr startIrq

  lda #<m3Irq
  sta jmpIrq+1
  lda #>m3Irq
  sta jmpIrq+2
  lda #31+31+31+offset
  sta $d012

  ldx #2
  jsr updateColors
  jsr updateY
  jmp endIrq
}

m3Irq:
{
  jsr startIrq

  lda #<m4Irq
  sta jmpIrq+1
  lda #>m4Irq
  sta jmpIrq+2
  lda #31+31+31+31+offset
  sta $d012

  ldx #3
  jsr updateColors
  jsr updateY
  jmp endIrq 
}

m4Irq:
{
  jsr startIrq

  lda #<m5Irq
  sta jmpIrq+1
  lda #>m5Irq
  sta jmpIrq+2
  lda #31+31+31+31+31+offset
  sta $d012

  ldx #4
  jsr updateColors
  jmp endIrq
}

m5Irq:
{
  jsr startIrq

  lda #<m6Irq
  sta jmpIrq+1
  lda #>m6Irq
  sta jmpIrq+2
  lda #31+31+31+31+31+31+offset
  sta $d012

  ldx #5
  jsr updateColors
  jsr updateY
  jmp endIrq
}

m6Irq:
{
  jsr startIrq

  lda #<m7Irq
  sta jmpIrq+1
  lda #>m7Irq
  sta jmpIrq+2
  lda #31+31+31+31+31+31+31+offset
  sta $d012

  ldx #6
  jsr updateColors
  jsr updateY
  jmp endIrq
}

m7Irq:
{
  jsr startIrq

  lda #<irq
  sta jmpIrq+1
  lda #>irq
  sta jmpIrq+2
  lda #$f9
  sta $d012

  ldx #7
  jsr updateColors
  jsr updateY
  jmp endIrq
}

irq:
{
  jsr startIrq

  lda $d011
  and #$f7
  sta $d011

  lda #<m8Irq
  sta jmpIrq+1
  lda #>m8Irq
  sta jmpIrq+2
  lda #8*31+offset
  sta $d012

  jmp endIrq
}

m8Irq:
{
  jsr startIrq

  lda #<m9Irq
  sta jmpIrq+1
  lda #>m9Irq
  sta jmpIrq+2
  lda #(9*31+offset)&$ff
  sta $d012

  ldx #8
  jsr updateColors

  lda #$8b
  sta $d011

  jmp endIrq
}

m9Irq:
{
  jsr startIrq

  lda #<resetIrq
  sta jmpIrq+1
  lda #>resetIrq
  sta jmpIrq+2
  lda #0
  sta $d012

  ldx #9
  jsr updateColors

  lda #$0b
  sta $d011

  jsr setSpritesAll

  jsr fade

  lda fade.phase
  cmp #endFade
  bne continue

    lda #<exitIrq
    sta jmpIrq+1
    lda #>exitIrq
    sta jmpIrq+2
    lda #$1b
    sta $d011
    lda #$f9
    sta $d012
continue:

  jmp endIrq
}

exitIrq:
{
  jsr startIrq

  lda #$1b
  sta $d011
  lda #$f9
  sta $d012

  asl $d019

  lda nextPartValue: #0
  sta nextpart

  jsr playMusic

  jmp endIrq
}

updateColors:
{
  inc $dbff
  inc $dbff
  inc $dbff
  inc $dbff
  inc $dbff
  inc $dbff

  lda col0Colors,x
  sta color
  ldy col2Colors,x
  lda col1Colors,x
  tax
  lda color: #0

  sty $d020
  sta $d021
  stx $d027
  sty $d025
  sta $d028
  sta $d029
  stx $d026
  sty $d02a
  sta $d02b
  stx $d02c
  rts
}

updateY:
{
  lda $d001
  clc
  adc #42
setY:
  sta $d001
  sta $d003
  sta $d005
  sta $d007
  sta $d009
  sta $d00b
  rts
}

setSpritesAll:
{
  lda #$3f
  sta $d015
  sta $d017
  sta $d01c
  sta $d01d

  // 5 = d021 (0)                   - block 0
  // 5 = d027 (1), 1 = d025 (2)     - block 1,2
  // 4 = d025 (2), 2 = d028 (0)     - block 2,3
  // 3 = d029 (0), 3 = d026 (1)     - block 4,5
  // 2 = d026 (1), 4 = d02a (2)     - block 5,6
  // 1 = d025 (2), 5 = d02b (0)     - block 7
  // 5 = d02c (1)

  lda #$40
  sta $d000
  lda #$40+$30  // +$30
  sta $d002
  lda #$40+$60  // +$30
  sta $d004
  lda #$40+$90
  sta $d006
  lda #$40+$c0
  sta $d008
  lda #$40+$f0  // watch out, + $20
  sta $d00a

  lda #$30
  sta $d010

  ldx #sprites/64
  stx screen+$3f8 // sprite 0
  stx screen+$3fd // sprite 4 
  inx
  stx screen+$3f9 // sprite 1
  inx
  stx screen+$3fa // sprite 2
  inx
  stx screen+$3fb // sprite 3
  inx
  stx screen+$3fc // sprite 4
}
setSpritesY:
{
  lda #offset
  jmp updateY.setY
}

fadeLine0:
{
  // check if this lane should be faded
  tax
  bcc skip
  cmp #maxFade
  bcs skip

  lda colorRamp+0,x
  sta col0Colors,y
  lda colorRamp+16,x
  sta col1Colors,y
  lda colorRamp+8,x
  sta col2Colors,y
skip:
  sec
  rts
}

fadeLine1:
{
  // check if this lane should be faded
  tax
  bcc skip
  cmp #maxFade
  bcs skip

  lda colorRamp+16,x
  sta col0Colors,y
  lda colorRamp+8,x
  sta col1Colors,y
  lda colorRamp+0,x
  sta col2Colors,y
skip:
  sec
  rts
}

fadeLine2:
{
  // check if this lane should be faded
  tax
  bcc skip
  cmp #maxFade
  bcs skip

  lda colorRamp+8,x
  sta col0Colors,y
  lda colorRamp+0,x
  sta col1Colors,y
  lda colorRamp+16,x
  sta col2Colors,y

skip:
  sec
  rts
}

* = code2 "[CODE] part 2"

fade:
{
  lda wait: #3
  beq continue
  dec wait
  rts

continue:
  lda #0
  sta wait

  lda phase
  cmp #endFade
  bne go

  rts

  // fade 3 lines..

go:
  inc phase
  ldx phase: #0
  txa
  sec
  sbc #0
  ldy #0
  sec
  .for (var line=0; line<10; line++) 
  { 
    .if (line>0)
    {
      txa
      sbc #offsetLine
      iny
    }
    .if (mod(line,3)==0) { jsr fadeLine0 }
    .if (mod(line,3)==1) { jsr fadeLine1 }
    .if (mod(line,3)==2) { jsr fadeLine2 }
  }
  rts
}

colorRamp:
  .fill 16,0
  .byte $00,$06,$09,$02,$0b,$04,$08,$0e,$0c,$05,$0a,$03,$0f,$07,$0d,$01
  .byte $0d,$07,$0f,$03,$0a,$05,$0c,$0e,$08,$04,$0b,$02,$09,$06
  .fill 16,6

// 5 = d021 (0)                   - block 0
// 5 = d027 (1), 1 = d025 (2)     - block 1,2
// 4 = d025 (2), 2 = d028 (0)     - block 2,3
// 3 = d029 (0), 3 = d026 (1)     - block 4,5
// 2 = d026 (1), 4 = d02a (2)     - block 5,6
// 1 = d025 (2), 5 = d02b (0)     - block 7
// 5 = d02c (1)

// $55 = d025
// $aa = sprite col
// $ff = d026

* = sprites "[GFX] sprites"
.fill 21,[$aa,$aa,$a5]  // 55 = col 2
.byte 0

.fill 21,[$55,$55,$aa]  // col2, col0
.byte 0

.fill 21,[$aa,$af,$ff]  // col0, col1 -> ff = col1
.byte 0

.fill 21,[$ff,$aa,$aa]  // col1, col2
.byte 0

.fill 21,[$5a,$aa,$aa]  // col2, col 0 -> 55 = col2

* = screen+$3f8 "[GFX] spritepointer"
  .fill 8,0
