#import "../00.music/music1.asm"

#if !AS_SPINDLE_PART
  .const KOALA_TEMPLATE = "C64FILE, Bitmap=$0000, ScreenRam=$1f40, ColorRam=$2328, BackgroundColor = $2710"
  .var picture = LoadBinary("../01.graphics/bitmap_tube2_fix.kla", KOALA_TEMPLATE)
#endif

.var animation = LoadBinary("./includes/custom.fade")

.label bitmap          = $4000 // inherited
.label screen          = $6000 // inherited
.label firstByte       = $b600
.label code            = $b600
.label anim            = $bc00
.label fadeTable       = $c000

.label screen_original = $0800 // copy original screen colors to this location
.label d800_original   = $fb00 // copy original d800 colors to this location 

#if !AS_SPINDLE_PART
  .label screenOri = $6000 // only standalone
  .label d800      = $6400 // only standalone
#endif

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

// these are the 0 page adresses for the part

.label firstZP      = $20
  .label fadePointer  = $20
  .label fadePointer2 = $21
.label lastZP       = $21

#if AS_SPINDLE_PART
  .label spindleLoadAddress = firstByte
  *=spindleLoadAddress-18-18-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word prepare       // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word 0             // cleanup routine
    .word music_play // location of playroutine call

    .byte 'I', >screen, >(screen+$3ff)   // inherit the bitmap screen  
    .byte 'I', >bitmap, >(bitmap+$1fff)  // inherit the bitmap 
    .byte 'Z', firstZP, lastZP
    .byte 'P', >screen_original, >(screen_original+$3ff)  // we use this memory for the original colors
    .byte 'P', >d800_original,   >(d800_original+$3ff)    // we use this memory for the original colors
    .byte 'P', >fadeTable,       >(fadeTable+$0fff)

    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2(quickstart); quickstart: sei; lda #$35; sta $01; jmp start
#endif


// load fader animation and determine # of steps
// ---------------------------------------------

*=anim "[DATA] Animation"
// determine # of steps in fader
.var maxAnimation = 0

.for (var i=0; i<1000; i++) {
  .var Value = animation.get(i)

  .if (Value == 1) {
    .eval Value = Value
  } else {
    .eval Value =  (Value + 6) * 1.3
  }

  .eval Value = round(Value)

  .byte Value
  .if (Value>maxAnimation) .eval maxAnimation = Value
}
.print ("max animation steps :" + maxAnimation)

* = code "[CODE] main"
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

  #if !AS_SPINDLE_PART
    lda #$94
    sta $dd00

    lda #0
    sta timelow
    sta timehigh

    jsr prepare
 
    :MusicInitCall()
  #endif

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$f9
  sta $d012

  lda #$3a
  sta $d011
  lda #$d8
  sta $d016

  #if !AS_SPINDLE_PART
    lda #BLACK
    sta $d020
    sta $d021
  #endif

  lda $dc0d
  lda $dd0d
  asl $d019

  lda restore01: #0
  sta $01
  cli

  #if !AS_SPINDLE_PART
  loop:
    jmp loop
  #else
    rts
  #endif
}

prepare:
{
  // if not in spindle, we have to copy the bitmap in place that we would inherit from the previous part
  #if !AS_SPINDLE_PART
  {
    ldx #0
  loop:
    .for (var page=0; page<4; page++)
    {
      lda d800+page*$100,x
      sta $d800+page*$100,x

      lda screenOri+page*$100,x
      sta screen+page*$100,x
    }
    inx
    bne loop
  }
  #endif

  ldx #0
  loop2: 
  {
    .for (var page=0; page<4; page++)
    {
      lda screen+page*$100,x
      sta screen_original+page*$100,x

      lda $d800+page*$100,x
      sta d800_original+page*$100,x
    }
    inx
    bne loop2
  }

	jsr Fader.GenerateFadeTableColor  // generate color table for fader
  rts
}

irq:
{
  pha
  txa
  pha
  tya
  pha

  // open border
  lda $d011
  and #$77
  sta $d011

  lda #$3d
  sta $dd02
  lda #((screen&$3c00)/$400)*$10+((bitmap&$2000)/$2000)*8
  sta $d018

  lda #$f9
  sta $d012

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff

  inc timelow
  bne !+
    inc timehigh
  !:

  :MusicPlayCall()

  // reset border
  lda $d011
  ora #$08
  and #$7f
  sta $d011

  asl $d019

  jsr script

  lda Fader.IsRunning
  beq noFader

  dec wait
  lda wait: #0
  beq !+
    lda #2
    sta wait
    lda Fader.Busy
    bne noFader

    cli
    jsr Fader.Run
  !:

  lda Fader.hasEnded
  beq !+
    // go to the next part
    lda nextPartValue: #0
    sta nextpart
  !:

noFader:
  pla
  tay
  pla
  tax
  pla
  rti
}

.var Wait      = $00
.var Fade      = $01
.var WaitFrame = $02
.var End       = $ff

script:
{
  lda waitFrame: #0
  beq !+
    lda timehigh
    cmp waitFrameHi: #0
    bcc stillWaiting
    beq checkLow
    bcs go
  checkLow:
    lda timelow
    cmp waitFrameLo: #0
    bcc stillWaiting
  go:
    // we reached (or passed) the correct frame #
    lda #0
    sta waitFrame
    rts

  !:
  lda wait: #0
  beq advanceScript
  dec wait

stillWaiting:
  rts

advanceScript:
  ldx scriptPointer: #0
  lda scriptData,x
  cmp #WaitFrame
  bne testWait
  {
    lda #1
    sta script.waitFrame
    inx
    lda scriptData+1
    sta script.waitFrameHi
    inx
    lda scriptData+2
    sta script.waitFrameLo
    inx
    stx scriptPointer
    rts
  }

testWait:
  cmp #Wait
  bne testFade
  {
    inx
    lda scriptData,x
    sta wait
    inx
    stx scriptPointer
  }
  rts

testFade:
  cmp #Fade
  bne testEnd
  {
    lda #1
    sta Fader.IsRunning
    inx
    stx scriptPointer
    rts
  }

testEnd:
  cmp #End
  bne endScript
  {
  }
endScript:
  rts
}

scriptData:
  #if AS_SPINDLE_PART
    .byte WaitFrame, $06,$20
  #endif

  .byte Fade
  .byte Wait,100
  .byte End

*=* "[CODE] Fader"
Fader:
{
	IsRunning: .byte 0
  Busy:      .byte 0
  PageNr:    .byte 3
  hasEnded:  .byte 0

	Run:
	{
    lda #0
    sta fadePointer   // set low byte of pointer

    inc Busy          // we are still processing this frame..

    jsr fadeSpecial

		lda #3            // fade $400 of colors
		sta PageNr

    // reset all the high bytes for the reads and writes

    lda #>anim            // restore read from anim every frame
    sta readAnim+1
		lda #>screen_original // reset where we read the colors from
		sta screenRead+1
		lda #>screen          // reset where the colors are going to
		sta screenWrite+1
		lda #>d800_original   // reset where we read the $d800 colors
		sta d800Read+1       
		lda #>$d800           // reset where we write the $d800 colors
		sta d800Write+1

    ldx #0
		loop:	
			lda readAnim: anim,x  // read the animation for this char
      //beq loop2             // don't fade this char

      cmp rangeh:     #15      // compare with the current step +8 in the fade
      bcs loop2               // -> do not fade this char yet
			cmp rangel:     #1      // compare with the current step in the fade
      bcc loop2               // -> this char has finished fading

      // this char is in range : fade it

        //sec                        // sec already done by cmp rangel
        sbc rangel                   // subtract the lower bound from the animation
        tay		                       // this gives the fade step (0-7)

        // clear animation to speed things up
        // future..

        lda fadetableaddress: tabp,y  // what table belongs to this fade step? read from the table
        sta fadePointer+1             // set high byte of pointer to fader table

        ldy screenRead:  screen_original,x  // read the target color from the screen
        lda             (fadePointer),y     // load the current color
        sta screenWrite: screen,x           // write the current color to the display screen
        ldy d800Read:    d800_original,x    // read the target color for $d800
        lda             (fadePointer),y     // load the current color
        sta d800Write:   $d800,x            // write to $d800
    
		loop2:	
      inx
		bne loop
		
    // increase all pages by one
		inc screenRead+1
		inc screenWrite+1
		inc d800Read+1
		inc d800Write+1
		inc readAnim+1

    dec PageNr     // all 4 pages done?
    bpl loop
		
    // move the range up by one
		inc rangel
		inc rangeh

		lda rangeh
		cmp checkend: #(round(maxAnimation+0.5)+16)            // is ook de laatste char in gefade?
		bne notCompletelyFinished	

		// the fade has ended completely

		// notify that the complete fade has ended
		lda #0
		sta IsRunning
    lda #1
    sta hasEnded
		
  	// reset range in the animation that gets faded to the start
		lda #1
		sta rangel
		lda #15
		sta rangeh

  notCompletelyFinished:    
    // notify that this frame is finished

    dec Busy	
		rts
  }

  // in screenram there are 2 colors per byte
  // so there are 256 combinations. Each combination has 8 fade steps.
  // f.e. color $11 -> 00,bb,88,cc,55,33,77,11. there are at offsets $11, $111, $211, $311, etc in the table

	GenerateFadeTableColor:
	{ 
    // loop over all color combinations

		ldy #0                   // combination $00
    loop:
      lda msb: #0            // this is the MSB color
      and #$0f
      tax
      lda readMSB: tab,x     // this is the current color of the MSB color for this fade step
      asl
      asl
      asl
      asl
      sta current_msb

			ldx #0                  // this is the LSB color
			loopx:	
				lda readLSB: tab,x    // read the current color for the LSB color
				ora current_msb:#0    // OR with the current color for the MSB color
				sta to: fadeTable,y
				inx
				iny
				cpx #$10
			bne loopx

			inc msb	          // next MSB color

			cpy #0
			bne loop          // loop over all color combinations

      // next stage
			lda readLSB
			clc
			adc #16
			sta readLSB
			sta readMSB
			lda readLSB+1
			adc #$00
			sta readLSB+1
			sta readMSB+1

			inc to+1
			lda to+1
			cmp #>(fadeTable+$1000)     // einde van de tabel?
		bne loop
		rts
	}

fadeSpecial:
{
  ldy #0
  ldx Fader.Run.rangel

// 0,6 -> c,d  frame 5
// 1,6 -> c    frame 6
// 2,6 -> c    frame 7
// 3,6 -> c    frame 8

  {
  .var startFrame = 4
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda specialRamp-(startFrame)+11,x
    sta $d800+0+6*40
    sta d800_original+0+6*40
    
    lda screen_original+0+6*40
    and #$f0
    ora specialRamp-(startFrame)+1,x
    sta screen+0+6*40
    sta screen_original+0+6*40
  !:
  }
  {
  .var startFrame = 5
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda specialRamp-(startFrame)+11,x
    sta $d800+1+6*40
    sta d800_original+1+6*40
  !:  
  }
  {
  .var startFrame = 6
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda specialRamp-(startFrame)+11,x
    sta $d800+2+6*40
    sta d800_original+2+6*40
  !:  
  }
  {
  .var startFrame = 7
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda specialRamp-(startFrame)+11,x
    sta $d800+3+6*40
    sta d800_original+3+6*40
  !:  
  }
  {
  .var startFrame = 8
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+
    lda specialRamp-(startFrame)+11,x

    sta $d800+4+6*40
    sta d800_original+4+6*40

    sta $d800+4+6*40
    sta d800_original+4+6*40
  !:  
  }
  {
  .var startFrame = 9
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda specialRamp-(startFrame)+11,x
    sta $d800+5+6*40
    sta d800_original+5+6*40
    
    lda screen_original+5+6*40
    and #$f0
    ora specialRamp-(startFrame)+1,x
    sta screen+5+6*40
    sta screen_original+5+6*40
  !:
  }
  {
  .var startFrame = 10
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda specialRamp-(startFrame)+11,x
    sta $d800+6+6*40
    sta d800_original+6+6*40
    
    lda screen_original+6+6*40
    and #$f0
    ora specialRamp-(startFrame)+1,x
    sta screen+6+6*40
    sta screen_original+6+6*40
  !:
  }
  {
  .var startFrame = 11
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda specialRamp-(startFrame)+11,x
    sta $d800+7+6*40
    sta d800_original+7+6*40
    
    lda screen_original+7+6*40
    and #$f0
    ora specialRamp-(startFrame)+1,x
    sta screen+7+6*40
    sta screen_original+7+6*40
  !:
  }
  {
  .var startFrame = 12
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda specialRamp-(startFrame)+11,x
    sta $d800+8+6*40
    sta d800_original+8+6*40
    
    lda screen_original+8+6*40
    and #$f0
    ora specialRamp-(startFrame)+1,x
    sta screen+8+6*40
    sta screen_original+8+6*40
  !:
  }
  {
  .var startFrame = 46
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda specialRamp-(startFrame)+13,x // 13 = brown
    sta $d800+8+8*40
    sta d800_original+8+8*40
  !:
  }
  {
  .var startFrame = 48
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda specialRamp-(startFrame)+13,x // 13 = brown
    sta $d800+9+8*40
    sta d800_original+9+8*40
  !:
  }


// 15,1 -> b,d frame 15
// 12,2 -> c,d frame 14
// 13,2 -> c,d frame 15
// 14,2 -> OK 
// 11,3 -> c   frame 14
// 10,5 -> c,d frame 14
 
  cpx #15+4
  bne !+
    sty $d800+15+1*40
    sty d800_original+15+1*40
    lda screen_original+15+1*40
    and #$f0
    sta screen+15+1*40
    sta screen_original+15+1*40    
  !:
  cpx #14+4
  bne !+
    sty $d800+12+2*40
    sty d800_original+12+2*40
    lda screen_original+12+2*40
    and #$f0
    sta screen+12+2*40
    sta screen_original+12+2*40    
  !:
  cpx #15+4
  bne !+
    sty $d800+13+2*40
    sty d800_original+13+2*40
    lda screen_original+13+2*40
    and #$f0
    sta screen+13+2*40
    sta screen_original+13+2*40    
  !:

  cpx #14+4
  bne !+
    sty $d800+11+3*40
    sty d800_original+11+3*40
  !:

  // char 10,5
  cpx #14+4
  bne !+
    sty $d800+10+5*40
    sty d800_original+10+5*40
  !:
  cpx #14+6
  bne !+
    lda screen_original+10+5*40
    and #$f0
    sta screen+10+5*40
    sta screen_original+10+5*40    
  !:

  cpx #14+4
  bne !+
    sty $d800+10+6*40
    sty d800_original+10+6*40
  !:

  {
  // yellow smudge
  .var startFrame = 14
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda specialRamp-(startFrame)+2,x // 2 = yellow
    sta $d800+27+21*40
    sta d800_original+27+21*40
  !:
  }

  // left jacket
  {
  .var startFrame = 38
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda specialRamp-(startFrame)+13,x // 13 = brown
    sta $d800+3+24*40
    sta d800_original+3+24*40
  !:
  }
  {
  .var startFrame = 39
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda specialRamp-(startFrame)+13,x // 13 = brown
    sta $d800+4+23*40
    sta d800_original+4+23*40
  !:
  }
  {
  .var startFrame = 40
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda screen_original+5+23*40
    and #$f0
    ora specialRamp-(startFrame)+13,x // 13 = brown
    sta screen+5+23*40
    sta screen_original+5+23*40
  !:
  }
  {
  .var startFrame = 41
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda specialRamp-(startFrame)+13,x // 13 = brown
    sta $d800+6+22*40
    sta d800_original+6+22*40
  !:
  }
  {
  .var startFrame = 42
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda specialRamp-(startFrame)+13,x // 13 = brown
    sta $d800+7+22*40
    sta d800_original+7+22*40
  !:
  }
  {
  .var startFrame = 43
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda specialRamp-(startFrame)+13,x // 13 = brown
    sta $d800+8+21*40
    sta d800_original+8+21*40
  !:
  }
  {
  .var startFrame = 44
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda specialRamp-(startFrame)+13,x // 13 = brown
    sta $d800+9+20*40
    sta d800_original+9+20*40
  !:
  }
  {
  .var startFrame = 45
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda specialRamp-(startFrame)+13,x // 13 = brown
    sta $d800+10+20*40
    sta d800_original+10+20*40
  !:
  }
  {
  .var startFrame = 46
  cpx #startFrame
  bcc !+
    cpx #startFrame+16
    bcs !+

    lda specialRamp-(startFrame)+9,x  // 9 = orange
    asl
    asl
    asl
    asl
    ora specialRamp-(startFrame)+13,x // 13 = brown
    sta screen+11+19*40
    sta screen_original+11+19*40
  !:
  }
  rts
}

specialRamp:
  .byte $01,$0d,$07,$0f,$03,$0a,$05,$0c,$0e,$08,$04,$0b,$02,$09,$06,$00
  .fill 16,0

	.var fh = >fadeTable
	//tabp2: .byte fh+7, fh+6, fh+5, fh+4, fh+3, fh+2, fh+1, fh+0, fh+0, fh+0               // loop through the stages from bright (fadetable+$700) to dark
	tabp:	 .byte fh+0, fh+1, fh+2, fh+3, fh+4, fh+5, fh+6, fh+7, fh+8, fh+9, fh+10, fh+11, fh+12, fh+13, fh+14, fh+15          // loop through the stages from dark (offset $000) to bright (offset $700)

.align $100
	*=* "[DATA] Color table"
	tab: 
    .byte $0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0  // read this table column wise :
    .byte $0,$6,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0  // f.e. the second column 1 : you get color $1 via $0,$b,$8,$c,...$7,$1
    .byte $0,$9,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$6,$0,$0
    .byte $0,$2,$0,$0,$0,$0,$0,$6,$0,$0,$0,$0,$0,$9,$0,$0
    .byte $0,$b,$0,$0,$0,$0,$0,$9,$0,$0,$0,$0,$0,$2,$0,$6
    .byte $0,$4,$0,$6,$0,$0,$0,$2,$0,$0,$0,$0,$0,$b,$0,$9
    .byte $0,$8,$0,$9,$0,$0,$0,$b,$0,$0,$6,$0,$0,$4,$0,$2
    .byte $0,$e,$0,$2,$0,$6,$0,$4,$0,$0,$9,$0,$0,$8,$0,$b
    .byte $0,$c,$0,$b,$0,$9,$0,$8,$0,$0,$2,$0,$6,$e,$0,$4
    .byte $0,$5,$0,$4,$0,$2,$0,$e,$0,$0,$b,$0,$9,$c,$6,$8
    .byte $0,$a,$0,$8,$0,$b,$0,$c,$6,$0,$4,$0,$2,$5,$9,$e
    .byte $0,$3,$0,$e,$6,$4,$0,$5,$9,$0,$8,$0,$b,$a,$2,$c
    .byte $0,$f,$0,$c,$9,$8,$0,$a,$2,$0,$e,$6,$4,$3,$b,$5
    .byte $0,$7,$6,$5,$2,$e,$6,$3,$b,$0,$c,$9,$8,$f,$4,$a
    .byte $0,$d,$9,$a,$b,$c,$0,$f,$4,$6,$5,$2,$e,$7,$8,$3
    .byte $0,$1,$2,$3,$4,$5,$6,$7,$8,$9,$a,$b,$c,$d,$e,$f	
}

.align $100
*=fadeTable "[DATA] Fade table" virtual
.fill $1000,0



// fill memory with bitmap data for standalone version
// -------------------------------------------------------------

#if !AS_SPINDLE_PART
  * = bitmap "[INHERIT] bitmap"
  .fill picture.getBitmapSize(),picture.getBitmap(i)

  * = screenOri "[STANDALONE] screen colors"
  .fill picture.getScreenRamSize(),picture.getScreenRam(i)

  * = d800 "[STANDALONE] d800 colors"
  .fill picture.getColorRamSize(),picture.getColorRam(i)&$f
#endif

// only declare virtual memory use in Spindle version
#if AS_SPINDLE_PART
  * = bitmap "[GFX, INHERIT] bitmap" virtual
  .fill 8000,0

  * = screen "[GFX, INHERIT] screen" virtual
  .fill 1000,0
#endif

// declare copies of screen and d800 colors
* = screen_original "[GEN] copy of screen colors for fade routine" virtual
  .fill 1000,0

* = d800_original "[GEN] copy of d800 colors for fade routine" virtual
  .fill 1000,0
