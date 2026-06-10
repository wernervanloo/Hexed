#import "../00.music/music1.asm"
#import "convert.asm"   // convert gfx into usable format
#import "convert2.asm"  // convert start gfx into usable format

#if AS_SPINDLE_PART
  .const showRestecp   = true   // if true, show only the restecp gfx and do not start scrolling until everything has loaded..
#else
  .const showRestecp   = false   // if true, show only the restecp gfx and do not start scrolling until everything has loaded..
#endif

.const debug         = false
.const sinSizeDiffed = 128
.const sinSize1      = 50
.const nrCharRows    = 26
.const nrRow         = 25  // # of rows on the screen
.const nrColumns     = 40  // # of columns on the screen

.var startSpeed = 3; .if (showRestecp) { .eval startSpeed = 0 }

// idea:

// free up 0page by modifying calcBytes:
// sta (zp1a+x*8),y  -> sta $xx00,y
// this will save (8*4)*8 = 256 cycles = +- 5 rasters
// but will cost 8*4 = 32 bytes
// frees up 13 bytes in prepare
// costs 32 bytes modifying the high bytes
// -> total cost = 64-13 = 51 bytes, 256-32 = 224

// info for linking: during fadeout, $2000-$9fff can be used to load the next part

.var background = BLACK

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

// pointers to write 32 chars (total $100)
.label firstZP   = $0c
  .label from    = $0c
  .label from2   = $0d
  .label xtemp2  = $0e
  .label ytemp2  = $0f
  .label zp1a    = $10
  .label zp1b    = $12
  .label zp1c    = $14
  .label zp1d    = $16
  .label zp2a    = $18
  .label zp2b    = $1a
  .label zp2c    = $1c
  .label zp2d    = $1e
  .label zp3a    = $20
  .label zp3b    = $22
  .label zp3c    = $24
  .label zp3d    = $26
  .label zp4a    = $28
  .label zp4b    = $2a
  .label zp4c    = $2c
  .label zp4d    = $2e
  .label zp5a    = $30
  .label zp5b    = $32
  .label zp5c    = $34
  .label zp5d    = $36
  .label zp6a    = $38
  .label zp6b    = $3a
  .label zp6c    = $3c
  .label zp6d    = $3e
  .label zp7a    = $40
  .label zp7b    = $42
  .label zp7c    = $44
  .label zp7d    = $46
  .label zp8a    = $48
  .label zp8b    = $4a
  .label zp8c    = $4c
  .label zp8d    = $4e
  .label sineZeropage = $50             // nrColumns-1+nrRow-1 bytes
  .label store8       = sineZeropage+64 // store bytes for 8 chars -> 9 chars * 8 bytes = 72 bytes
  .label startRow     = store8+72
.label lastZP = startRow

.label shiftLeft1   = $0400  // generated at startup
.label d021Table    = $0700  // color tables get copied here
.label d023Table    = $0800  // ..

.label gfxData      = $2000  // compressed data during the part
.label gfxData2     = $2000  // graham data at start of the part (showRestecp=true)

#if AS_SPINDLE_PART
  .label d021TableOri = $5400
  .label d023TableOri = $5500
#else
  .label d021TableOri = $c800
  .label d023TableOri = $c900
#endif

.var firstByte      = $a000
.label sineXDiffed  = $a000
.label code         = $a100

.label charset1     = $c800
.label charset2     = $d000
.label charset3     = $d800
.label charset4     = $e000
.label charset5     = $e800
.label charset6     = $f000
.label charset7     = $f800 // watch out! only 4 pages..
.label screen       = $fc00
.label jmpirq       = $fff0

#if AS_SPINDLE_PART
  .label spindleLoadAddress = firstByte
  *=spindleLoadAddress-18-15-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"            // fileformat magic
    .word prepare           // prepare routine
    .word start             // setup routine
    .word 0                 // irq handler
    .word 0                 // main routine
    .word 0                 // fadeout routine
    .word 0                 // cleanup routine
    .word music_play        // location of playroutine call

    .byte 'Z', <firstZP,    <lastZP
    .byte 'P', >shiftLeft1,    >(d023Table+$ff)   // protect shift tables
    .byte 'I', >charset1,      >(charset7+$3ff)   // inherit the graphics from 000.prepare or 000.message
    .byte 'I', >(screen+$100), >(screen+$3f8)     // protec the screen by a fake inherit
    .byte 'I', >d021Table,     >(d023Table+$ff)   // inherit colors from 000.prepare or 000.message

    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2($080e); sei; lda #$35; sta$01; jmp start
#endif


.var gfxPositions = List(); .for (var i=0; i<8*16; i++) { .eval gfxPositions.add(gfxData+i*$100) }

// put compressed gfx data into memory if we are not starting with the start gfx
.if (showRestecp==false)
{
  // put all compressed graphics in memory
  .for (var p=0; p<gfxPositions.size(); p++)
  {
    .var currentPosition = gfxPositions.get(p)
    .if (currentPosition!=*)
    {
      *=currentPosition "[DATA] gfx compressed data"   // set new memory position
    }

    .fill $100, lstGfx.get(i+p*$100)                   // fill with data
  }
}

// put uncompressed start gfx into the memory
.if (showRestecp)
{
  #if AS_SPINDLE_PART
    * = gfxData2 "[DATA] uncompressed start gfx" virtual
    .fill grahamData.size(), grahamData.get(i)
    .fill 512,$ff
    .fill 512,$ff

  #else
    * = gfxData2 "[DATA] uncompressed start gfx"
    .fill grahamData.size(), grahamData.get(i)
    .fill 512,$ff
    .fill 512,$ff

  #endif
}

* = code "[DATA] d018 table"
d018Tab:  // this table has to be aligned to a page
  .fill 4, (((screen&$3fff)/$400)*16)+((charset1&$3fff)/$800)*2
  .fill 4, (((screen&$3fff)/$400)*16)+((charset2&$3fff)/$800)*2
  .fill 4, (((screen&$3fff)/$400)*16)+((charset3&$3fff)/$800)*2
  .fill 4, (((screen&$3fff)/$400)*16)+((charset4&$3fff)/$800)*2
  .fill 4, (((screen&$3fff)/$400)*16)+((charset5&$3fff)/$800)*2
  .fill 4, (((screen&$3fff)/$400)*16)+((charset6&$3fff)/$800)*2
  .fill 2, (((screen&$3fff)/$400)*16)+((charset7&$3fff)/$800)*2

  .fill 4, (((screen&$3fff)/$400)*16)+((charset1&$3fff)/$800)*2
  .fill 4, (((screen&$3fff)/$400)*16)+((charset2&$3fff)/$800)*2
  .fill 4, (((screen&$3fff)/$400)*16)+((charset3&$3fff)/$800)*2
  .fill 4, (((screen&$3fff)/$400)*16)+((charset4&$3fff)/$800)*2
  .fill 4, (((screen&$3fff)/$400)*16)+((charset5&$3fff)/$800)*2
  .fill 4, (((screen&$3fff)/$400)*16)+((charset6&$3fff)/$800)*2
  .fill 1, (((screen&$3fff)/$400)*16)+((charset7&$3fff)/$800)*2 // we can save 1 byte

* = * "[DATA] other data"
// put these tables here, to avoid a page cross

charRows:
  .byte >(charset7+$200)
  .byte >(charset1+$000),>(charset1+$200),>(charset1+$400),>(charset1+$600)
  .byte >(charset2+$000),>(charset2+$200),>(charset2+$400),>(charset2+$600)
  .byte >(charset3+$000),>(charset3+$200),>(charset3+$400),>(charset3+$600)
  .byte >(charset4+$000),>(charset4+$200),>(charset4+$400),>(charset4+$600)
  .byte >(charset5+$000),>(charset5+$200),>(charset5+$400),>(charset5+$600)
  .byte >(charset6+$000),>(charset6+$200),>(charset6+$400),>(charset6+$600)
  .byte >(charset7+$000)

.var slowDownRows = List()
.eval slowDownRows.add(10)   // pause at atlantis + extend
.eval slowDownRows.add(41)   // pause at triad
.eval slowDownRows.add(83)   // pause at censor
.eval slowDownRows.add(117)  // pause at reflex+shape
.eval slowDownRows.add(146)  // pause at camelot+arise
.eval slowDownRows.add(178)  // pause at nah kolor
.eval slowDownRows.add(221)  // pause at chorus

.eval slowDownRows.add(252)  // pause at fairlight
.eval slowDownRows.add(26)   // pause at bonzai+g*p
.eval slowDownRows.add(61)   // pause at pretzel logic
.eval slowDownRows.add(105)  // pause at offence
.eval slowDownRows.add(130)  // pause at lft
.eval slowDownRows.add(164)  // pause at resource
.eval slowDownRows.add(203)  // pause at booze design
.eval slowDownRows.add(234)  // pause at finnish gold

slowDownRowData:
  .fill slowDownRows.size(), slowDownRows.get(i)
  .byte 0   // 0 = reset

* = * "[CODE] start"
// these are the colors that we will copy into the blacked out colors in the colorTables
lastD021Colors:
  .fill 26,(lstD021.get(256-26+i))*1 + ((lstD022.get(256-26+i))*16)
lastD023Colors:
  .fill 26,(lstD023.get(256-26+i))*1

start:
{
  sei
  lda #$35
  sta $01

  lda #$0
  sta $d020
  sta $d021
  sta $d022
  sta $d023

  // in spindle the color data is copied by 000.prepare  
  #if !AS_SPINDLE_PART
    ldx #0
    copyLoop:
      lda d021TableOri,x
      sta d021Table,x
      lda d023TableOri,x
      sta d023Table,x

      inx
      bne copyLoop
  #endif

  // fff0 -> jmp irq
  lda #$4c
  sta jmpirq

  .if (showRestecp)
  {
    lda #<startUp.startIrq
    sta jmpirq+1
    lda #>startUp.startIrq
    sta jmpirq+2
  } else
  {
    lda #<irq
    sta jmpirq+1
    lda #>irq
    sta jmpirq+2
  }

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  .if (nrColumns==38) { lda #$d7 } else { lda #$d8 }
  sta $d016

  #if !AS_SPINDLE_PART

    .if (showRestecp) { jsr startUp.setupNMI }
    else
    {
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
    } 

    lda #$94
    sta $dd00

    jsr prepare

    :MusicInitCall()

  #endif  

  lda #$3f
  sta $dd02

  lda #<jmpirq
  sta $fffe
  lda #>jmpirq
  sta $ffff

  lda #<nmi
  sta $fffa
  lda #>nmi
  sta $fffb
  lda #RTI
  sta $dd0c

  .var waitCycles = 8*63-1  
  lda #<waitCycles
  sta $dd04
  lda #>waitCycles
  sta $dd05

  lda #$fa
  sta $d012
  lda $d011
  and #$1f
  ora #$40   // illegal mode
  sta $d011

  #if !AS_SPINDLE_PART
    lda $dc0d
    lda $dd0d
    asl $d019
  #endif

  cli

  // now copy the graham data (in spindle, the data is copied by 000.prepare)
  #if !AS_SPINDLE_PART
    .if (showRestecp) { jsr startUp.copy }
  #else
    .if (showRestecp) 
    { 
      lda #0
      sta startRow
      inc startUp.startIrq.ready 
    } // in spindle, the data is already copied
  #endif

  #if !AS_SPINDLE_PART
  loop:
    cmp ($00,x)
    inc $dbff
    jmp loop
  #else
    rts
  #endif
}

scrollSpeeds:
  .byte 2,3,2,2,2,1,2,1,1,1,0,1,0,1
  .fill 10,[0,0,1,0]
scrollSpeeds2:
  .byte 1,0,1,0,1,1,1,2,1,2,2,2,3,2
  .byte 3,$ff

scrollUp:
{
  .var phaseStart    = 0
  .if (showRestecp) { .eval phaseStart = scrollSpeeds2-scrollSpeeds }  // start in slowdown after restecp

  lda slowDown: #0  // a slowdown in progress?
  beq noSlowDown
    ldx phase: #phaseStart
    lda scrollSpeeds,x
    bpl !+
      // end of slowdown, reset it
      lda #0
      sta slowDown
      sta phase
      beq noSlowDown
  !:
    // limit speed for the last logo..
    cmp maxScrollSpeed: #4      // speed too high?
    bcc !+
      lda maxScrollSpeed
    !:
    sta yScrollSpeed
    inc phase
  noSlowDown:

  ldx startRow

  lda irq.yScroll
  sec
  sbc yScrollSpeed: #startSpeed
  sta irq.yScroll
  bcs continue
    and #7
    sta irq.yScroll

    // if we move 8 pixels back up again, we have to advance the colorcycler by one char also
    inc colStart

    // add 1 to startRow
    inx
    cpx #nrCharRows
    bne !+
      ldx #0
    !:
    stx startRow

    inc startCalculate.Row      // row can be value 0..255, no need to clip

    // do we have to fadeout?
    ldy fadeout: #0
    beq continue
    dey
    lda #0
    sta d021Table,y
    sta d023Table,y
    inc fadeout       // keep increasing fadeout to clear the color tables

continue:
  inx
  stx nmi.d018Index       // set irq2 start row
  dex
  ldy colStart: #256-26  // keep track of the top row

  // start the fadeout?
  cpy #25
  bne !+
    lda next.readNew
    sec
    sbc #<slowDownRowData
    cmp #6
    bcc !+
    inc fadeout
  !:
  cpy checkSlowDown: #slowDownRows.get(0)
  bne dontSlowDown
  next: {
    // advance to check the next slowDown
    inc readNew
    lda readNew: slowDownRowData
    bne noReset
      //inc fadeout
      inc nextpart  // signal handover to loader, $2000-$9fff is clear, so better start loading

      lda #1
      sta maxScrollSpeed
      lda #<slowDownRowData
      sta readNew
      lda slowDownRowData
    noReset:
    sta checkSlowDown // write the next value to test

    inc slowDown  // mark that we have to slow down
  }
  dontSlowDown:

  // set charset directly
  lda d018Tab,x
  sta $d018 

  // set first colors directly
  lda d021Table,y
  sta $d021
  lsr
  lsr
  lsr
  lsr
  sta $d022
  lda d023Table,y
  sta $d023

  iny
  sty nmi.colIndex

  // copy colors into tables
  lda fadein: #1
  beq checkFadeOut
  {
    ldy colStart
    dey
    bne !+
    {
      // start at row 0 now.. stop fadein
      sty fadein
      beq checkFadeOut
    }
    !:
    // the first time we get here, y = $e5 = #229
    // we have to fetch the color from 0
    cpy #$e6
    bcc checkFadeOut
    lda lastD021Colors-$e6,y
    sta d021Table,y

    lda lastD023Colors-$e6,y
    sta d023Table,y
  }

  // time for next part?
checkFadeOut:
  lda fadeout         // if fadeout > 0, then the fadeout has started
  beq startCalculate  // fadeout has not started, continue as normal

fade:  {
    lda colStart      // check what is in the top row
    bne !+
    {
      // the top row is the 0th row, so time for the next part
      inc colStart           // make sure we only get 1 pulse
      inc nextpart           // signal handover to the next part (we already started loading)
      inc irq.goFinal        // go to the final IRQ
    }
    !:
    cmp #256-25+1          // if the screen starts with row > -25, then we can stop calculating and start loading
    bcc !+
    {

      // if the first row is 232, then the last row is 0 and we do not have to plot the 25th char row anymore (row 24)
      // 232 -> stop plot 24
      // 233 -> stop plot 23

      sec
      sbc #232

      // 232 -> 0 (we reversed the data in plotterStart table)
      tay
      lda plotterStart.lo,y
      sta writeRTS
      lda plotterStart.hi,y
      sta writeRTS+1

      lda #0
      sta d021Table,y
      sta d023Table,y

      lda #RTS
      sta writeRTS: $ffff

      lda #1
      sta stopCalculating    // stop calculating new chars, so we can load the next part 
    }
    !:

    lda stopCalculating: #0  // can we stop calculating chars (and load over the compressed gfx?)
    bne end
  }
  
  startCalculate:
  {
    // if 4,5,6,7 -> calculate right part
    // if 0,1,2,3 -> calculate left part

    lda irq.yScroll
    cmp #4                  // set carry if value == 4,5,6,7, for switching between left and right

    lda charRows,x
    adc #0                  // add carry to switch between left and right

    cmp lastCalced: #0
    beq end                 // this row was already calculated.. skip it to save rastertime
    sta lastCalced          // remember last page that was calculated

    .if (debug) { inc $d020 }
    ldy Row: #$ff  // was 25
    jmp calcChars
  }
end:
  rts
}


irq2:
{
  // normal timing is with a dec 0 here
  // but.. the irq is triggered to a 0page adresses that jumps here. so 3 of the 5 cycles are already used
  // replace by NOP
  bit $ea
  pha
  lda #39-10        // 19..27 <- (earliest cycle)
  sec              // 21..29
  sbc $dc06        // 23..31, A becomes 0..8
  cmp #10
  sta branch     // 27..35
  bcc branch: *+2    // 31..39
  lda #$a9         // 34
  lda #$a9         // 36
  lda #$a9         // 38
  lda $eaa5

  nop
  nop
  lda #$f9
  sta $d012

  // set up NMI every 8 rasterlines
  {
    // enable timer
    lda #%10010001
    sta $dd0e

    //lda #$91   // activate nmi
    bit $dd0d
    sta $dd0d
  }

  // go to irq next

  lda #<irq
  sta jmpirq+1
  lda #>irq
  sta jmpirq+2

  // we can end the NMI's earlier to increase loading speed
  lda scrollUp.fade.stopCalculating
  beq end

  lda #<endNMIirq
  sta jmpirq+1
  lda #>endNMIirq
  sta jmpirq+2

  lda #$ff
  sec
  sbc scrollUp.colStart


  // the first time we get here, colStart is $e8.
  lda #$ff
  sec
  sbc scrollUp.colStart
  asl
  asl
  asl
  adc #$40
  sta $d012

end:
  asl $d019

  pla
  rti
}

nmi:
{
  sta atemp
  stx xtemp
  sty ytemp               // to zeropage to make d018 write 1 cycle earlier

  // 1c, 1d      -> 3 cycles from bcc
  // 1e, 1f, 20  -> waste 2 extra cycles (5) -> 2 from bcc + bit $ea
  lda $dc06
  cmp #$1e
  bcc !+
    bit $ea
  !:

  ldy colIndex
selfmod:
  // if y equals 0 during fadeout, we can write black and end the NMI's..

  lax d021Table,y          // read d021 + d022 value
  lsr
  lsr
  lsr
  lsr                      // d021 value in x, d022 value to a
  
  ldy d018Index: d018Tab   // read d018 value
  sty $d018

  stx $d021
  sta $d022
  lda colIndex: d023Table
  sta $d023

  inc d018Index
  inc colIndex

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  jmp $dd0c
}

endNMIirq:
{
  sta atemp

  lda #$7f
  sta $dd0d

  lda #<irq
  sta jmpirq+1
  lda #>irq
  sta jmpirq+2

  lda #$fc
  sta $d012
  asl $d019

  lda atemp: #0
  rti
}

irq:
{
  pha

  lda #$7f   // disable nmi
  sta $dd0d

  //lda $d011  // open borders for design
  //and #$f7
  //sta $d011

  txa
  pha
  tya
  pha

  jsr playMusic
jsrToFade:
  .if (showRestecp) { jsr startUp.fadeIn }

  .if (debug) { inc $d020 }
  jsr scrollUp

  lda goFinal: #0
  beq !+
  // go to the final IRQ instead..
  {
    lda #<finalIrq
    sta jmpirq+1
    lda #>finalIrq
    sta jmpirq+2
    lda #$fa
    sta $d012
    lda #$5b // black screen to avoid bugs
    sta $d011
    asl $d019
    jmp end
  }
!:
  lda #<irq2
  sta jmpirq+1
  lda #>irq2
  sta jmpirq+2

  lda yScroll: #7
  //and #7
  ora #$10
  sta $d011
  clc
  adc #$27-8-1  // 8 rasters earlier to set up nmi
  sta $d012

  asl $d019

  cli
  
  .if (debug) { inc $d020 }
  jsr plotter
end:
  .if (debug) { lda #0; sta $d020 }

  pla
  tay
  pla
  tax
  pla
  rti
}

// this IRQ runs after the part has faded out completely, in order to stop the NMI's and load faster
finalIrq:
{
  sta atemp
  stx xtemp
  sty ytemp

  jsr playMusic
  asl $d019

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

playMusic:
{
  // maintain demo time as close as possible to the music play routine
  inc timelow
  bne !+
  inc timehigh
!:

  .if (debug) { inc $d020 }
  // play music first to keep the sound as stable as possible
  :MusicPlayCall()
  rts
}

*=* "[CODE] calcChars"
.var storPos = List().add(0*8,2*8,3*8,4*8,5*8,6*8,7*8,8*8,1*8)  // positions to store the data of the chars
                                                                // we want the left most and right most chars at position 0 and 1
                                                                // to avoid being overwritten by the sinedata
calcChars:
{
  ldx #$34
  stx $01

  // modify high byte to store data
  .for (var i=0; i<32; i++) { sta zp1a+1+i*2 }
  
  and #1
  beq fetchFirst8
  jmp fetchSecond8

fetchFirst8:
  // fetch first 8 chars of data

  .for (var y=0; y<8; y++)
  {
    // copy char 9th char of previous row to storage of char 0
    // and 0th char of previous row to storage of char 8
    // first  8 : chars 0,1, 2, 3, 4, 5, 6, 7,8
    // second 8 : chars 8,9,10,11,12,13,14,15,0

    .if (y>0) { lda store8+storPos.get(0)+y }
    else      { lda gfxPositions.get((y*16)+8),y}
    .if (y>0) { ldx store8+storPos.get(8)+y }
    .if (y>0) { stx store8+storPos.get(0)+y }
                sta store8+storPos.get(8)+y

    // this is the data for the first char.. we don't have to copy the first byte, we can load it directly
    //.if (y>0) 
    //{ 
    //  lda gfxPositions.get(y*16),y 
    //  sta store8+y
    //}

    // this is the data for the rest of the chars. if x AND y are 0, we can load the value directly in the speedcode
    .for (var x=0; x<7; x++)
    {
      .if ((x+y)>0)
      {
        lda gfxPositions.get(((x+1)&15)+y*16),y
        sta store8+storPos.get(x+1)+y
      }
    }
  }

  lda gfxPositions.get(0),y  // load first bytes 
  ldx gfxPositions.get(1),y  // directly to save write+read
  jmp continue

fetchSecond8:
  // fetch second 8 chars of data
  .for (var y=0; y<8; y++)
  {
    .if (y>0) 
    { 
      // every page holds data for the 256 different rows of gfx data
      // there are 128 different pages. pages  0- 7 hold the data for char 0,  8-15 for char 8,
      //                                pages 16-23 for char 1,               24-31 for char 9

      // can we save memory and use the same code for the first and 2nd 8 chars?

      // tya
      // 
      // lda (datafrom),y
      // iny
      // sta store8+

      lda gfxPositions.get((y*16)+8),y
      sta store8+storPos.get(0)+y
    }

    .for (var x=0; x<8; x++)
    {
      .if ((x+y)>0)
      {
        lda gfxPositions.get(((x+1+8)&15)+y*16),y
        sta store8+y+storPos.get(x+1)
      }
    }
  }

  lda gfxPositions.get(0+8),y  // load first bytes 
  ldx gfxPositions.get(1+8),y  // directly to save write+read

continue:
  ldy #0
  loop2: .for (var y=0; y<8; y++)
  {
    .if (y>0) 
    { 
      iny
      lda store8+storPos.get(0)+y
    }   

    .if (y>0) { jsr calc8 } else { jsr calc8+2 } // we can skip the ldx store8, it is loaded directly
  }

  ldx #$35
  stx $01
  rts
}

calc8:
{
  .for (var x=0; x<8; x++) { calc: calcBytes(x) }
  rts
}

.macro calcBytes(x) {
  ldx store8+storPos.get(x+1),y     
  sta (zp1a+x*8),y

  asl
  asl
  ora shiftLeft1,x               // 00112233-> ......00
  sta (zp1b+x*8),y

  asl
  asl
  ora shiftLeft2,x               // 00112233-> ......11
  sta (zp1c+x*8),y

  asl
  asl
  ora shiftLeft3,x               // 00112233-> ......22
  sta (zp1d+x*8),y
  .if (x!=7)
  {
    txa                          // right byte becomes left byte  
  }
}

*=* "[CODE] plotter"
plotter:
{
  // change sinePhase
  lda sineDiffedPhase: #2
  sec
  sbc addDiffedPhase:  #2
  bcs !+
    lda #sinSizeDiffed-1
  !:
  sta sineDiffedPhase
  tay

  // prepare sine data
  // row 0 needs 39 bytes. column 0 is read from sinex, the other 39 are added
  // row 1 needs 1 additional byte
  // so total : 39 + 24 = 63 bytes
  
  .for (var i=(nrColumns-1)+(nrRow-1); i>=2; i--)
  {
    lda sineZeropage+i-2
    sta sineZeropage+i
  }
  .for (var i=0; i<2; i++)
  {
    lda sineXDiffed+mod(i+sinSizeDiffed,sinSizeDiffed),y
    sta sineZeropage+i
  }

  // change first phase
  lda sinePhase1: #2
  sec
  sbc addPhase:   #1
  bcs !+
    lda #sinSize1-1
  !:
  sta sinePhase1
  tay

  // plot screen
  sec
  forloop: .for (var y=0; y<nrRow; y++)
  {
    start:
    // if we are scrolling vertically, X has to be modified. this is OK, it's only one value every row, so 25 times.
    // we could add $40 to X every row, but because the last charset is only half used, that does not work..

    ldx startRow
    lda xTab+y,x  // LAX abs,x does not exist :-(
    tax

    //ldx xValue: #(((y&3)+1)*64) -1 // y=0 -> 00..3f, x=$3f|0  = $3f
                                     // y=1 -> 40..7f, x=$3f|40 = $7f
                                     // y=2 -> 80..bf, x=$3f|80 = $bf
                                     // y=3 -> c0..ff, x=$3f|c0 = $ff

    #if AS_SPINDLE_PART
      lda sineX1+mod(0+y+sinSize1,sinSize1),y
    #else
      lda sineX1+mod(0+y+sinSize1,sinSize1),y
    #endif

    .for (var x=0; x<nrColumns; x++)
    {
      .if (x>0)
      {
        adc sineZeropage+x-1+y
        ora #$c0              // can we add and or at the same time?

        // we could put the bits to select the row at bits 0 and 1
        // but if carry is set, these bits will change also, so we would have to keep setting them and win nothing..
        // we could solve that if there is an add without carry
        // there is the AXS/SBX opcode that substracts without carry, but it only comes with IMM addressing mode..
      }
      
      // ora sets bit 6 and 7. 
      // bits 6 and 7 select the correct row from the charset
      // every charset holds 4 rows (16 char wide gfx * 4 shift = 64 chars per row)
      // so each charset can hold 256/64 = 4 rows
      // the correct chars are written by ANDING bits 6 and 7 with X during the SAX write
      sax screen+y*40+x
    }
  }

  rts
}

plotterStart:
.lohifill nrRow, plotter.forloop[nrRow-1-i].start

// sinus voor x zoom
*=* "[DATA] x sine 1"
sineX1:
{
  .var sinMin  = $00
  .var sinMax  = $18
  .var sinSize = sinSize1
  .var sinAmp  = 0.5 * (sinMax-sinMin)

  .var sineValues = List()

  .for (var i=0; i<sinSize; i++)
  {
    .var value = (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(i*360/sinSize)) - $c
    .eval sineValues.add(round(value)|$c0)
  }

  .fill sinSize,sineValues.get(i)
  .fill min(25,sinSize),sineValues.get(i)
}

startUp: .if (showRestecp)
{
  * = * "[CODE] startcode"
  copy:
  {
    lda #$34  // disable io to copy the charsets
    sta $01

    lda #0
    sta startRow

    // copy graham data
    ldy #6*8+4  // copy 6 charsets+1 empty line
    ldx #0
  loop:
    {
      .var copyTo = charset1
      lda from: gfxData2,x
      sta to:   copyTo,x
    }
    inx
    bne loop
    inc loop.from+1
    inc loop.to+1
    dey
    bne loop

    inc nextpart  // data copied, start loading immediately
    lda #$35
    sta $01

    inc startIrq.ready
    rts
  }
  startIrq:
  {
    dec 0
    sta atemp
    stx xtemp
    sty ytemp

    lda #$fa
    sta $d012

    lda ready: #0
    beq !+
      lda #<irq
      sta jmpirq+1
      lda #>irq
      sta jmpirq+2
    !:

    jsr playMusic

    lda #$fa
    sta $d012
    lda #$50  // illegal mode
    sta $d011
    //lda $d011
    //and #$1f
    //ora #$40   
    //sta $d011

    asl $d019

    lda atemp: #0
    ldx xtemp: #0
    ldy ytemp: #0
    inc 0

    rti
  }

  fadeIn:
  {
    lda ready: #0
    bmi end2
    lda wait: #2
    bne end

    lda #3
    sta wait

    // calculate where to read the color ramp from
    lda #<colorRamp
    clc
    adc step: #0
    sta from
    lda #>colorRamp
    adc #0
    sta from+1

    .var startX = 255-25
    ldx #startX // 230
    loop:
    {
      ldy startPosRamp2-startX,x
      lda (from),y
      asl
      asl
      asl
      asl
      ldy startPosRamp1-startX,x
      ora (from),y
      sta d021Table,x

      ldy startPosRamp3-startX,x
      lda (from),y
      sta d023Table,x

      inx
      cpx #$ff
      bne loop
    }
    inc step
    lda step
    cmp #$11
    bcc end
      lda #$80
      sta ready
  end:
    dec wait
    rts

  end2:
    // wait until loading is finished before the scrolling starts
    inc wait2
    lda wait2: #0
    bne !+

      // start scrolling up
      lda #1
      sta scrollUp.slowDown

      // don't jump to this fadein routine anymore, this code will be destroyed by the scrolling, but that's OK.
      lda #LDA_ABS
      sta irq.jsrToFade
!:
    rts
  }

  .var  htColToPos = Hashtable()
  .eval htColToPos.put( 0, 0)
  .eval htColToPos.put( 1,15)
  .eval htColToPos.put( 2, 3)
  .eval htColToPos.put( 3,11)
  .eval htColToPos.put( 4, 5)
  .eval htColToPos.put( 5, 9)
  .eval htColToPos.put( 6, 1)
  .eval htColToPos.put( 7,13)
  .eval htColToPos.put( 8, 6)
  .eval htColToPos.put( 9, 2)
  .eval htColToPos.put(10,10)
  .eval htColToPos.put(11, 4)
  .eval htColToPos.put(12, 8)
  .eval htColToPos.put(13,14)
  .eval htColToPos.put(14, 7)
  .eval htColToPos.put(15,12)

  startPosRamp1:
  .for (var i=0; i<lstD021b.size(); i++)
  {
    .var col = lstD021b.get(i)  // read the color
    .var pos = htColToPos.get(col)
    .byte pos
  }
  startPosRamp2:
  .for (var i=0; i<lstD022b.size(); i++)
  {
    .var col = lstD022b.get(i)  // read the color
    .var pos = htColToPos.get(col)
    .byte pos
  }
  startPosRamp3:
  .for (var i=0; i<lstD023b.size(); i++)
  {
    .var col = lstD023b.get(i)  // read the color
    .var pos = htColToPos.get(col)
    .byte pos
  }

  colorRamp:
    .fill 16,0
    .byte $0,$6,$9,$2,$b,$4,$8,$e,$c,$5,$a,$3,$f,$7,$d,$1

  setupNMI:
  {
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
    rts
  }
}
// prepare can go here.
prepareCode: 

.if (showRestecp==false)
{ * = * "[CODE] prepare - OK to destroy when running" }
else
{
 * = prepareCode "[CODE] prepare - OK to destroy when running"
}

// prepare code goes here.. it's ok if it get's destroyed during the part
prepare:
{
  // prepare d800
  ldx #0
  lda #background|8
  !:
    sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $db00,x
    inx
  bne !-

  // prepare sine 0page
  ldy #(nrColumns-1)+(24-1)
  {
  loop:
    lda sineXDiffed,y
    sta sineZeropage,y
    dey
    bpl loop
  }

  // generate shift tables
  ldy #0
  {
  loop:
    tya
    lsr
    lsr
    tax
    and #$03
    sta shiftLeft3,y

    txa
    lsr
    lsr
    tax
    and #$03
    sta shiftLeft2,y

    txa
    lsr
    lsr
    //and #$03
    sta shiftLeft1,y
    
    iny
    bne loop
  }

  // prepare zeropage adresses for calcChars
  ldx #62
  
  lda #$f8
  {
  sec
  loop:
    sta zp1a,x
    //sec
    sbc #8
    dex
    dex
    bpl loop
  }

  rts
}

* = d021Table "[DATA] copy of d021 colors" virtual
  .fill 256,0
* = d023Table "[DATA] copy of d023 colors" virtual
  .fill 256,0

// shift tables
*=shiftLeft1     "[DATA] shift table 1" virtual
  .fill 256, (i&%11000000)>>6
shiftLeft2:; *=* "[DATA] shift table 2" virtual
  .fill 256, (i&%00110000)>>4
shiftLeft3:; *=* "[DATA] shift table 3" virtual
  .fill 256, (i&%00001100)>>2

*=sineXDiffed "[DATA] differential sine data"

{
  .var sinMin  = $20
  .var sinMax  = $50  // 28
  .var sinSize = sinSizeDiffed
  .var sinAmp  = 0.5 * (sinMax-sinMin)

  .var sineValues = List()

  .for (var i=0; i<sinSize; i++)
  {
    .var value = (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(i*360/sinSize))
    .eval sineValues.add(round(value)|$c0)
  }
  .eval sineValues.add(sineValues.get(0))  // add the first one again, so we have something to subtract again!

  .fill sinSize,            (((sineValues.get(i+1)-sineValues.get(i))+4)&$3f|$c0)  // or with $c0, subtract 1 so the
  .fill min(40+25,sinSize), (((sineValues.get(i+1)-sineValues.get(i))+4)&$3f|$c0)  // plotter always keeps carry set
}

* = * "[DATA] table for x values for SAX"
xTab:
  .byte $3f,$7f,$bf,$ff
  .byte $3f,$7f,$bf,$ff
  .byte $3f,$7f,$bf,$ff
  .byte $3f,$7f,$bf,$ff
  .byte $3f,$7f,$bf,$ff
  .byte $3f,$7f,$bf,$ff
  .byte $3f,$7f

  .byte $3f,$7f,$bf,$ff
  .byte $3f,$7f,$bf,$ff
  .byte $3f,$7f,$bf,$ff
  .byte $3f,$7f,$bf,$ff
  .byte $3f,$7f,$bf,$ff
  .byte $3f,$7f,$bf,$ff
  .byte $3f,$7f

// fill color data
#if !AS_SPINDLE_PART
* = d021TableOri "[DATA] d021 table"
  .fill lstD021.size()-26, lstD021.get(i) + ((lstD022.get(i))*16)
  .fill 26, 0

* = d023TableOri "[DATA] d022 table"
  .fill lstD023.size()-26, lstD023.get(i)
  .fill 26, 0
#endif

*=charset1 "[GFX generated] charset1" virtual
  .fill $800,$ff
*=charset2 "[GFX generated] charset2" virtual
  .fill $800,$ff
*=charset3 "[GFX generated] charset3" virtual
  .fill $800,$ff
*=charset4 "[GFX generated] charset4" virtual
  .fill $800,$ff
*=charset5 "[GFX generated] charset5" virtual
  .fill $800,$ff
*=charset6 "[GFX generated] charset6" virtual
  .fill $800,$ff
*=charset7 "[GFX generated] charset7" virtual
  .fill $400,$ff
*=screen "[GFX generated] screen" virtual
  .fill 1020,0
