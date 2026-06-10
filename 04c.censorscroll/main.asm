#import "../00.music/music1.asm"
#import "functions.asm"
.const DEBUG = false     // true: show rastertime with $d020
.const testPattern = 0   // 1: show test pattern instead of font

.const startOffset = 100 //100

.var fontGfx = LoadPicture("./includes/reserve_lsb.png")
.var fontMSB = LoadPicture("./includes/reserve_msb.png")

.const screen_width = 40
.const height       = 200
.const nrRibbons    = 16
.const ribbonHeight = 7
.const verbose      = false

.var ribbons = List().add(ribbon0,  ribbon1,  ribbon2,  ribbon3,
                          ribbon4,  ribbon5,  ribbon6,  ribbon7,
                          ribbon8,  ribbon9,  ribbon10, ribbon11,
                          ribbon12, ribbon13, ribbon14, ribbon15).lock()

.var yMin = 255  // top Y position
.var yMax = 0    // bottom Y position

// ------------------------
// create 4 bit pp bitmap -
// ------------------------

.for (var i=0; i<(width*4*height); i++) { .eval bitmap16.add(-1) }

.var wobble_start   = 0
.var wobble_end     = (width*4)/2

.var swirl_start    = wobble_end
.var swirl_end      = width*4

.var wobble_width   = wobble_end - wobble_start
.var swirl_width    = swirl_end - swirl_start

// ---------------------
// calculate movements -
// ---------------------

calcMoves:
{
  .for (var r=0; r<(nrRibbons); r++)
  {
    // lists holding the top and bottom coordinates for the movements
    .var topWobble = 0
    .var botWobble = 0
    .var topSwirl = 0
    .var botSwirl = 0

    .for (var x=0; x<width*4; x++)
    {
      .var skew  = calcSkew(x)

      swirl:
      {
        .var swirlOffset = swirl_width-64
        .var sinSize     = swirl_width
        .var swirlPhaseAdd = sinSize - 2*4
        .var sinMin      = 0
        .var sinMax      = ribbonHeight*nrRibbons+30
        .const yStart    = 14

        .var sinAmp       = 0.5 * (sinMax-sinMin)
        .var yOffset      = yStart                        // go down 8 pixels every new ribbon
        .var phaseOffset1 = (sinSize/2/nrRibbons)*(r)
        .var phaseOffset2 = (sinSize/2/nrRibbons)*(r+1)

        .eval topSwirl = yOffset + (sinMin+sinAmp) + sinAmp*sin(toRadians((x + swirlPhaseAdd + swirlOffset + phaseOffset1)*360/sinSize))
        .eval botSwirl = yOffset + (sinMin+sinAmp) + sinAmp*sin(toRadians((x + swirlPhaseAdd + swirlOffset + phaseOffset2)*360/sinSize))
      }

      wobble:
      {
        .var sinSize   = wobble_width
        .var wobblePhaseAdd = sinSize - 14*4
        .var sinMin    = 0
        .var sinMax    = 40
        .const yStart  = 7

        .var sinAmp      = 0.5 * (sinMax-sinMin)

        .var yOffset1     = ribbonHeight*r + yStart          // go down 8 pixels every new ribbon
        .var phaseOffset1 = (r/(nrRibbons+1))*sinSize/2      // (in pixels), 180 degree phaseshift over all ribbons
        .var yOffset2     = ribbonHeight*(r+1) + yStart      // go down 8 pixels every new ribbon
        .var phaseOffset2 = ((r+1)/(nrRibbons+1))*sinSize/2  // (in pixels), 180 degree phaseshift over all ribbons

        .eval topWobble = yOffset1 + (sinMin+sinAmp) + sinAmp*sin(toRadians((2*x + wobblePhaseAdd + phaseOffset1)*360/sinSize))
        .eval botWobble = yOffset2 + (sinMin+sinAmp) + sinAmp*sin(toRadians((2*x + wobblePhaseAdd + phaseOffset2)*360/sinSize))

        .if ((r==nrRibbons-1) && (x>(swirl_start-16)))
        {
          .eval botWobble = yOffset2 + (sinMin+sinAmp) + sinAmp
        }
      }

      // combine movements
      .var factorWobble = x<wobble_end ? 1 : 0   // this is the amount of wobble that we use
      
      // if we are around the overtake point, we smooth it out
      //  .... wobble_end/start_swirl.....end_swirl/start_wobble.....
      
      .var overtake = 8*4
      .if (x<wobble_start+overtake) { .eval factorWobble = 0.5+x/(2*overtake) }
      .if (x>swirl_end-overtake)    { .eval factorWobble = 0.5+(x-swirl_end)/(2*overtake) }
      .if ((x>swirl_start-overtake) && (x<swirl_start+overtake)) { .eval factorWobble = (swirl_start+overtake-x)/(2*overtake) }

      .var factorSwirl = 1 - factorWobble         // this is the amount of swirl that we use

      .var value1 = topWobble*factorWobble + topSwirl*factorSwirl
      .var value2 = botWobble*factorWobble + botSwirl*factorSwirl

      .eval value1 = round(value1+skew)
      .eval value2 = round(value2+skew)

      .eval yMin = min(yMin, value1)  // keep track of first and last y position
      .eval yMin = min(yMin, value2)  // to compress only the used bitmap rows
      .eval yMax = max(yMax, value1)
      .eval yMax = max(yMax, value2)

      .eval plot(x, r, value1, value2, true)
    } // for x
  } // for ribbon
}

.const background = BLUE
.const sideborder = LIGHT_BLUE

.var bitmapList       = List() // this list holds the bitmapdata for each column
.var bitmapCompressed = List() // this list holds the compressed bitmapdata for each column
.var speedcodeList    = List() // this list holds the speedcode for each column

.label ribbondata         = $3a40  // spindle doesn't seem to want to place the driver below IO, so it places it at $e000

.label firstByte          = $4000
.label colorTableL        = $4000
.label screen             = $0400
.label bitmap             = $2000
.label font               = $d700
.label speedCodePositions = $f800


// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

.macro keepTime() { inc timelow; bne *+4; inc timehigh }

.label firstZP        = $e0
  .label in             = $e0
  .label out            = $e2
  .label scroll         = $e4
  .label scrollH        = $e5
  .label fontPointer    = $e6
  .label fontPointerH   = $e7
  .label columnPointer  = $e8
  .label columnPointerH = $e9
.label lastZP         = $e9

#if AS_SPINDLE_PART
  .label spindleLoadAddress = firstByte // $4000
  *=spindleLoadAddress-18-12-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word prepare       // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word 0             // cleanup routine
    .word music_play    // location of playroutine call

    .byte 'Z', <firstZP, <lastZP
    .byte 'P', >screen, >(screen+$3ff)     // declare we are using $0400-$07ff
    .byte 'P', >bitmap, >(bitmap+$1f40)    // declare we are using the bitmap
    .byte 'P', >ribbondata, >(ribbondata+16*80)

    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2(start); jmp start
#endif

* = ribbondata "[DATA] ribbondata" virtual
.var col = background
ribbon0:  .fill 80,col
ribbon1:  .fill 80,col
ribbon2:  .fill 80,col
ribbon3:  .fill 80,col
ribbon4:  .fill 80,col
ribbon5:  .fill 80,col
ribbon6:  .fill 80,col
ribbon7:  .fill 80,col
ribbon8:  .fill 80,col
ribbon9:  .fill 80,col
ribbon10: .fill 80,col
ribbon11: .fill 80,col
ribbon12: .fill 80,col
ribbon13: .fill 80,col
ribbon14: .fill 80,col
ribbon15: .fill 80,col

* = colorTableL "[DATA] color tables"
  .byte $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f  // MSB = 0 fixed colors
  .byte $0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0c,$0f,$07,$01,$07,$0f,$0c  // MSB = 1 outside rim
  .byte $00,$00,$09,$09,$0b,$0b,$08,$08,$0c,$0c,$05,$05,$0f,$0f,$03,$03  // MSB = 2 inside fill
  .byte $0d,$0d,$03,$03,$0f,$0f,$05,$05,$0c,$0c,$08,$08,$0b,$0b,$09,$09  // MSB = 3 rest inside fill

* = * "[DATA] color tables"
colorTableH:
  .byte $00,$10,$20,$30,$40,$50,$60,$70,$80,$90,$a0,$b0,$c0,$d0,$e0,$f0  // MSB = 0 fixed colors
  .byte $b0,$b0,$b0,$b0,$b0,$b0,$b0,$b0,$b0,$c0,$f0,$70,$10,$70,$f0,$c0  // MSB = 1 outside rim
  .byte $00,$00,$90,$90,$b0,$b0,$80,$80,$c0,$c0,$50,$50,$f0,$f0,$30,$30  // MSB = 2 inside fill
  .byte $d0,$d0,$30,$30,$f0,$f0,$50,$50,$c0,$c0,$80,$80,$b0,$b0,$90,$90  // MSB = 3 rest inside fill

* = * "[DATA] large cycle"
largeCycle:
  .const cycleColors = List().add($99,$bb,$88,$cc,$55,$ff,$33,$dd,$33,$ff,$55,$cc,$88,$bb)
  .const rept = 4
  .for (var i=0; i<cycleColors.size(); i++) 
  { 
    .if (rept == 4)
    {
      .byte cycleColors.get(i)  //  [2,2,3,2],3,3,4,3,4,4
      .byte cycleColors.get(i)
      .byte cycleColors.get(mod(i+1,cycleColors.size()))
      .byte cycleColors.get(i)
    }
    else
    .for (var r=0; r<rept; r++)
    {
      .byte cycleColors.get(i)      
    }
  }
largeCycle2:
  .for (var i=0; i<cycleColors.size(); i++) 
  { 
    .if (rept == 4)
    {
      .byte cycleColors.get(i)  //  [2,2,3,2],3,3,4,3,4,4
      .byte cycleColors.get(i)
      .byte cycleColors.get(mod(i+1,cycleColors.size()))
      .byte cycleColors.get(i)
    }
    else
    .for (var r=0; r<rept; r++)
    {
      .byte cycleColors.get(i)      
    }
  }

// colorramp : 
//   .byte $00,$60,$90,$20,$b0,$40,$80,$e0,$c0,$50,$a0,$30,$f0,$70,$d0,$10

* = * "[CODE] main"
start:
{
  sei
  lda #$35
  sta $01

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  ldx nextpart
  inx
  stx scroller.nextPartValue
  
  lda #(((screen&$3fff)/$400)*16)+((bitmap&$3fff)/$2000)*8
  sta $d018
  #if !AS_SPINDLE_PART
    lda #$94
    sta $dd00
  #endif
  lda #((screen&$c000)/$4000)|$3c
  sta $dd02

  lda #$d0
  sta $d016

  #if !AS_SPINDLE_PART
    jsr prepare
  #endif

  lda #<prepareIrq
  sta $fffe
  lda #>prepareIrq
  sta $ffff

  lda #sideborder
  sta $d020
  lda #background
  sta $d021

  lda #$38
  sta $d011
  lda #$f9
  sta $d012

  :MusicInitCall()

  lda #<scrolltext
  sta scroll
  lda #>scrolltext
  sta scrollH

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
  #endif

  // clear bitmap

  lda #0
  tax
  loop: {
    sta write: bitmap,x
    inx
    bne loop
  }
  ldy loop.write+1
  iny
  sty loop.write+1
  cpy #>(bitmap+$2000)
  bne loop

  rts
}

prepareWhileRunning:
{
  lda running: #0
  beq prepareData
  rts

prepareData:
  inc running

  // ------------------
  // clear ribbondata -
  // ------------------

  ldx #79
  lda #background
  {
  loop:
    .for (var i=0; i<ribbons.size(); i++)
    {
      .var ribbon = ribbons.get(i)
      sta ribbon,x
    }
    dex
    bpl loop
  }

  // -------------------
  // decompress bitmap -
  // -------------------

  decompressLoop:
    ldx column: #(screen_width-1)

    .if (startOffset>0)
    {
      .var addScreens = floor(startOffset/screen_width)
      .var offset2    = mod(startOffset,screen_width)

      cpx #(screen_width-1-offset2)
      bcc !+
        txa
        clc
        adc #(width-(screen_width))
        tax
      !:
      
      .if (addScreens>0)
      {
        txa
        clc
        adc #(width-(addScreens*screen_width))
        bcc !+
          sec
          sbc #width
        !:
        tax
      }

      txa
      cmp #width
      bcc !+
        sec
        sbc #width
      !:
      tax

      txa
      cmp #width
      bcc !+
        sec
        sbc #width
      !:
      tax
    } else
    {
      cpx #(screen_width-1)
      bcc !+
        txa
        clc
        adc #(width-(screen_width))
        tax
      !:      
    }

    {
      lda #$34
      sta $01

      lda compressedDataPositionsLo,x
      sta in
      lda compressedDataPositionsHi,x
      sta in+1

      jsr decompress2

      lda #$35
      sta $01
    }

    lda column
    
    jsr relocate
    
    dec column
  bpl decompressLoop

  // set test colors
  ldx #0
  lda #background | (background << 4)
  loop:
    sta screen,x
    sta screen+$100,x
    sta screen+$200,x
    sta screen+$300,x
    sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $db00,x
    inx
    bne loop
  
  inc running  // mark prepare is ready
  rts
}

.align $100
dmaDelayIrq:
{
  dec 0            // 10..18
  sta restoreA     // 15..23
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

  lda d011Write3: #$34 // avoid badline at offset 7 (fld it)
  sta $d011
  nop

  bit $ea

  // we are at cycle 56

  lda #$28          
  sec
  sbc offsetX: #0+mod(startOffset,screen_width)   // 0 = 15 cycles
  sta dmaDelay

  bcs dmaDelay: *             // 12
  lda #$a9  //0
  lda #$a9  //2
  lda #$a9  //4
  lda #$a9  //6
  lda #$a9  //8
  lda #$a9  //10
  lda #$a9  //12
  lda #$a9  //14
  lda #$a9  //16
  lda #$a9  //18
  lda #$a9  //20
  lda #$a9  //22
  lda #$a9  //24
  lda #$a9  //26
  lda #$a9  //28
  lda #$a9  //30
  lda #$a9  //32
  lda #$a9  //34
  lda #$a9  //36
  lda #$24  //38
  nop       //40   40 = 2 cycles

  lda d011Write:  #$38
  sta $d011
  lda d011Write2: #$39
  sta $d011

  lda scrollX: #$d3
  sta $d016

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$e2-18
  sta $d012
  asl $d019

  inc 0

  lda restoreA: #0
  rti
}

irq:
{
  sta restoreA
  stx restoreX
  sty restoreY

  lda #0
  sta decompressNeeded
  sta newRibbonColumnNeeded

  // move bitmap, softscroll
  lda dmaDelayIrq.scrollX
  ora #$f8 // or with $f8 to detect easily when it overflows 8 pixels
  clc
  adc scrollSpeed: #4
          // this counteracts the scrolling caused by the colorcycle, 
          // because this scrolls the bitmap to the right while the colorcycler scrolls to the left 
          // (the colorcycler scrolls at a fixed speed of 8 pixels or 1 char/frame)
          // a higher number (ie 7) will result in a visually low scroll speed. 
          // 8 makes the scroll stop.
          // a low number will result in a visually high scroll speed
  and #$07
  ora #$d0
  sta dmaDelayIrq.scrollX
  
  bcs copyBitmapColumn

  // if we get here, we need to copy a new column into the ribbons

  // if we do not have to copy in a new bitmap column, we have to copy in new colors
  // -> if the hardware $d016 scroll speed is 0, a new column of ribbon gfx is needed each frame (because it scrolls at speed 8)
  // -> if the hardware $d016 scroll speed is 8, we always see the same ribbon data (it's standing still) 
  //    -> there is never a need to copy in new data

  // if there is no dma delay, we need to plot the new column in at position index+39
  // if there is 1 char of dma delay, the correct positions is index+39-dma_delay

  inc newRibbonColumnNeeded
  lda index
  clc
  adc #39
  sec
  sbc dmaDelayIrq.offsetX

  // keep in 0..39
check:
  cmp #$80
  bcc positive
    clc
    adc #screen_width
    jmp check
positive:
  cmp #screen_width
  bcc ok
    sec
    sbc #screen_width
    jmp positive

ok:
  sta ribbonPos
  jmp continue

copyBitmapColumn:
  sta decompressNeeded // we need to decompress a new bitmap column

  // keep track of the first column
  lda firstColumn: #(width-1)-startOffset
  sec
  sbc #1
  bcs !+
    // keep in 0..width range
    //clc
    adc #width
  !:
  sta firstColumn

  // move bitmap, characters
  lda dmaDelayIrq.offsetX
  clc
  adc #1
  cmp #screen_width
  bcc !+
    // keep in 0..screen_width range
    sec
    sbc #screen_width
  !:
  sta dmaDelayIrq.offsetX

continue:
  ldx dmaDelayIrq.offsetX

  ldy #$37
  lda d011Tab,x
  sta openBorderIrq.d011Offset
  cmp #$37         // is this the case when we need to avoid the badline?
  bne !+
    ldy #$34
  !:
  sty dmaDelayIrq.d011Write3
  sta dmaDelayIrq.d011Write
  clc
  adc #1
  and #7
  ora #$38
  sta dmaDelayIrq.d011Write2  

  lda #<openBorderIrq
  sta $fffe
  lda #>openBorderIrq
  sta $ffff
  lda #$fa
  sta $d012

  asl $d019

  cli

  lda newRibbonColumnNeeded: #0
  beq skipNewRibbonColumn
    .if (DEBUG) { lda #$0a; sta $d020 }
    ldx ribbonPos: #0
    jsr scroller
skipNewRibbonColumn:

  // move colorcycler
  lda index: #(screen_width-2) //-offset
  clc
  adc #1
  cmp #screen_width
  bne !+
    lda #0
  !:
  sta index
  tay

  .if (DEBUG) { lda #$02; sta $d020 }
  lda firstColumn
  jsr speedcode

  lda decompressNeeded: #0
  beq skipNewColumn
  {
    lda #$34
    sta $01

    // where is the compressed data for the new column?
    ldx irq.firstColumn
    lda compressedDataPositionsLo,x
    sta in
    lda compressedDataPositionsHi,x
    sta in+1

    .if (DEBUG) { lda #$07; sta $d020 }

    // decompress the bitmap data for the new column
    jsr decompress2

    lda #$35
    sta $01

    .if (DEBUG) { lda #$03; sta $d020 }

    // decompress into what column of the bitmap?
    lda irq.firstColumn
  checkAgain:
    cmp #screen_width
    bcc !+
      sec
      sbc #screen_width
      bcs checkAgain
    !:

    jsr relocate
  }
skipNewColumn:

  .if (DEBUG) { lda #$0e; sta $d020 }

  //jsr cycle3
  jsr cycle1
  jsr cycle2

  .if (DEBUG) { lda #sideborder; sta $d020 }

  lda restoreA: #0
  ldx restoreX: #0
  ldy restoreY: #0
  rti
}

openBorderIrq:
{
  sta atemp
  stx xtemp
  sty ytemp

  lda $d011
  and #$f7
  sta $d011

  jsr playMusic
  
  lda #<dmaDelayIrq
  sta $fffe
  lda #>dmaDelayIrq
  sta $ffff
  lda #$2f-$30
  clc
  adc d011Offset: #$37
  sta $d012

  asl $d019

  lda #$37
  sta $d011

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

// this IRQ will keep the upper and border open and the screen 'off'
// while prepareWhileRunning clears the ribbondata and decompresses the bitmap

prepareIrq:
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

  asl $d019
  inc $dbff
  inc $dbff
  
  lda $d011 // open border
  and #$37
  sta $d011

  jsr playMusic

  lda #$2f
  sta $d011

  cli
  lda prepareWhileRunning.running
  beq !+
  {
    cmp #1
    beq endIrq  // still running
    {
      // prepare has finished, start the part for real
      lda #<dmaDelayIrq
      sta $fffe
      lda #>dmaDelayIrq
      sta $ffff
      lda #$2f-$30
      clc
      adc #$37
      sta $d012

      lda #$37
      sta $d011
    }
  }

  !:
  jsr prepareWhileRunning // prepare hasn't run, so run it

endIrq:
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
  keepTime()
  :MusicPlayCall()
  rts
}

d011Tab:
  .fill 40, $30+7-floor(i/5)

scroller:
{
  stx saveX

  lda scrollPosition: #0
  cmp charWidth:      #0
  bne continueCurrentChar 

  // load the next char
readNextChar:
  ldy #0
  sty scrollPosition // reset scroll position
  sty pointer
  lax (scroll),y     // fetch next char
  bpl notEnd         // this is a normal char

  // test for special chars
  cmp #$ff
  beq resetScroll

  // go to next char
  inc scroll
  bne !+
    inc scrollH
  !:

  and #$7f  // get the speed
  eor #$07
  sta irq.scrollSpeed
  bpl readNextChar

resetScroll:
  // switch to next part
  lda nextPartValue: #0
  sta nextpart

  // reset scroller
  lda #<scrolltext2
  sta scroll
  lda #>scrolltext2
  sta scrollH
  lax (scroll),y

notEnd:
  ldy fontWidth,x        // read width for this char
  sty charWidth          // store it
  asl
  tax
  // read pointer to the column list

  lda fontPositions,x
  sta columnPointer
  lda fontPositions+1,x
  sta columnPointer+1

  // go to next char
  inc scroll
  bne !+
    inc scrollH
  !:
continueCurrentChar:
  // read where the data for this column is stored
  lda pointer: #0
  asl
  tay

  // todo : allow to read below IO here

  lda #$34
  sta $01

  lda (columnPointer),y  // columnPointer may point below IO
  sta fontPointer
  iny
  lda (columnPointer),y
  sta fontPointer+1

  ldx saveX: #0
  ldy #nrRibbons-1
  lda (fontPointer),y

  .for (var r=0; r<nrRibbons; r++)
  {
    ldy #r
    lda (fontPointer),y            // fontPointer may point below IO
    .var ribbon = ribbons.get(r)
    sta ribbon,x
    sta ribbon+40,x
  }

  lda #$35
  sta $01

  // go to next column
  inc pointer
  inc scrollPosition
  rts
}

fontPositions:
  .word  0*16 * 2 + columnPointers // space
  .word  1*16 * 2 + columnPointers // a
  .word  2*16 * 2 + columnPointers // b
  .word  3*16 * 2 + columnPointers // c
  .word  4*16 * 2 + columnPointers // d
  .word  5*16 * 2 + columnPointers // e
  .word  6*16 * 2 + columnPointers // f
  .word  7*16 * 2 + columnPointers // g
  .word  8*16 * 2 + columnPointers // h
  .word  9*16 * 2 + columnPointers // i
  .word 10*16 * 2 + columnPointers // j
  .word 11*16 * 2 + columnPointers // k
  .word 12*16 * 2 + columnPointers // l
  .word 13*16 * 2 + columnPointers // m
  .word 14*16 * 2 + columnPointers // n
  .word 15*16 * 2 + columnPointers // o
  .word 16*16 * 2 + columnPointers // p
  .word 17*16 * 2 + columnPointers // q
  .word 18*16 * 2 + columnPointers // r
  .word 19*16 * 2 + columnPointers // s
  .word 20*16 * 2 + columnPointers // t
  .word 21*16 * 2 + columnPointers // u
  .word 22*16 * 2 + columnPointers // v
  .word 23*16 * 2 + columnPointers // w
  .word 24*16 * 2 + columnPointers // x
  .word 25*16 * 2 + columnPointers // y
  .word 26*16 * 2 + columnPointers // z
  .word 27*16 * 2 + columnPointers // .
  .word 28*16 * 2 + columnPointers // ,

fontWidth:
  .byte 12 // space
  .byte 16 // a
  .byte 16 // b
  .byte 16 // c
  .byte 16 // d
  .byte 16 // e
  .byte 16 // f
  .byte 16 // g
  .byte 16 // h
  .byte 9  // i
  .byte 16 // j
  .byte 16 // k
  .byte 17 // l == m
  .byte 17 // m
  .byte 16 // n
  .byte 16 // o
  .byte 16 // p
  .byte 16 // q
  .byte 16 // r
  .byte 16 // s
  .byte 16 // t
  .byte 16 // u
  .byte 17 // v == w
  .byte 17 // w
  .byte 16 // x
  .byte 16 // y
  .byte 16 // z
  .byte 9  // .
  .byte 9  // ,

decompress2:
{
  lda #<buffer
  sta out
  lda #>buffer
  sta out+1

  clc
loop:
  ldy #0
  lax (in),y        // fetch the next code
  bmi flushLiterals
  beq end           // 0 = end of data
copyEqual:
  // here is a run of equal bytes

  iny
  lda (in),y        // fetch the byte to copy
  stx gety
  ldy gety: #0
copyEqualLoop:
  {
    dey
    sta (out),y
    beq endEqualLoop // we can stop the loop if y==0, no need to decrease Y. 50% chance to save 2 cycles
    dey
    sta (out),y
    bne copyEqualLoop // if y is not 0, go back to the loop
  }
endEqualLoop:
  lda #2            
  // advance input by 2 bytes
  adc in
  sta in
  bcc !+
    inc in+1
    clc
  !:
  txa
  adc out
  sta out

  //ldy #0  y is 0 already
  bcs increaseH
  {
    lax (in),y
    // we just did a equal-copy. chances are pretty ok that next up is flushLiterals
    bmi flushLiterals
    beq end
    bpl copyEqual
  }

increaseH:
  inc out+1
  clc
  {
    lax (in),y
    bmi flushLiterals
    beq end
    bpl copyEqual
  }    
end:
  rts

flushLiterals:
  // at the start, y=0
  // we have to copy A AND #$7f bytes

  and #$7f
  tax
  tay
    
  // x = 84->83 x=84 -> 4 copies
  // copy 83,82,81,80 stop
flushLiteralsLoop:
  {
    lda (in),y         // copy all literals
    dey
    sta (out),y
    beq endFlushLiteralsLoop
    lda (in),y
    dey
    sta (out),y
    bne flushLiteralsLoop
  }
endFlushLiteralsLoop:
  sec // add one more
  txa

advanceInput:
  adc in
  sta in
  bcc advanceOutput
    inc in+1
    clc
advanceOutput:
  txa
  adc out
  sta out

  //ldy #0  y is 0 already  
  bcs increaseH2
  {
    lax (in),y
    // we just did a flush literals. chances are pretty good next up is a copy equal
    beq end
    bpl copyEqual
    bmi flushLiterals
  }

increaseH2:
  inc out+1
  clc
  {
    lax (in),y
    beq end
    bpl copyEqual
    bmi flushLiterals
  }    
}

*=* "[CODE] relocate: copy buffer into bitmap"
relocate:
{
  // column is in A

  .var rMin=floor(yMin/8) // first bitmap row
  .var rMax=floor(yMax/8) // last bitmap row

  // multiply times 8
  ldy #7
  asl
  asl
  asl
  ora #7
  tax
  bcc loop
  jmp loop2  // go to loop2 for columns 32-39

loop:
  .for (var r=0; r<=(rMax-rMin); r++)
  {
    lda buffer+r*8,y
    sta bitmap+(r+rMin)*320,x
  }
  dex
  dey
  .if ((rMax-rMin)<=19)
  {
    bpl loop
  } else {
    bmi end
    jmp loop
  }
end:
  rts

loop2:
  .for (var r=0; r<=(rMax-rMin); r++)
  {
    lda buffer+r*8,y
    sta bitmap+(r+rMin)*320+256,x
  }
  dex
  dey
  .if ((rMax-rMin)<=19)
  {
    bpl loop2
  } else {
    bmi end2
    jmp loop2
  }
end2:
  rts
}

cycle1:
{
  lda wait: #0
  beq cycle
  dec wait
  rts
cycle:
  lda #1
  sta wait
  .var offset = 16
  ldx colorTableL+offset
  .for (var c=0; c<15; c++)
  {
    lda colorTableL+c+1+offset
    sta colorTableL+c+offset
  }
  stx colorTableL+15+offset

  ldx colorTableH+offset
  .for (var c=0; c<15; c++)
  {
    lda colorTableH+c+1+offset
    sta colorTableH+c+offset
  }
  stx colorTableH+15+offset
  rts
}

cycle2:
{
  lda wait: #0
  beq cycle
  dec wait
  rts
cycle:
  lda #0
  sta wait

  .var offset = 32
  .var offsetFade = 64

  ldy index: #0
  ldx #$0f
  .for (var i=0; i<24; i++)
  {
    lda largeCycle+i,y
    // this code applies the fader to this cycle
    // 
    // and #$0f
    // tax
    // lda colorTableL+offsetFade,x
    // sta colorTableL+offset+i     
    // lda colorTableH+offsetFade,x
    // sta colorTableH+offset+i
    
    sax colorTableL+offset+i
    and #$f0
    sta colorTableH+offset+i    
  }

  inc index
  lda index
  cmp #(largeCycle2-largeCycle)
  bne !+
  {
    lda #0
    sta index
  }
  !:
  rts
}

/*
* = * "[CODE] color cycler 3"
cycle3:
{
  .var steps = 8
  .var offsetFade = 64

  lda wait: #0
  beq !+
  dec wait
  rts
!:
  lda #1
  sta wait

  inc phase

  ldx phase: #0
  cpx #steps*2
  bne continue
    ldx #0
    stx phase
continue:
  ldy offsets,x

  ldx #$0f

  .for (var i=0; i<16; i++)
  {
    lda faderamp+i,y
    sax colorTableL+offsetFade+i
    and #$f0
    sta colorTableH+offsetFade+i
  }
  rts

offsets:
  .fill steps,i*16
  .fill steps,(steps-1-i)*16
}
*/

* = * "[DATA] scrolltext"
scrolltext2:
  // some extra space after a scroll reset, to avoid the scrolltext showing up at the right when switching to the next part
  .byte 0,0,0,0

scrolltext:           //v=w        l=m    v=w
  .var text = "Fbut toC vin Bx, Eteals got vay Ctoo big. Ax Egot hexed...  F   "

  .for (var i=0; i<text.size(); i++)
  {
    .var char  = text.charAt(i)
    .var value = char

    .if (char == '.') { .eval value = 27 }
    .if (char == ',') { .eval value = 28 }
 
    .if (char == 'A') { .eval value = $81 } // speed 1
    .if (char == 'B') { .eval value = $82 } // speed 2
    .if (char == 'C') { .eval value = $83 } // speed 3
    .if (char == 'D') { .eval value = $84 } // speed 4
    .if (char == 'E') { .eval value = $85 } // speed 5
    .if (char == 'F') { .eval value = $86 } // speed 6
    .if (char == 'G') { .eval value = $87 } // speed 7
    .if (char == 'H') { .eval value = $88 } // speed 8
    .if (char == ' ') { .eval value = 0 }   // space

    .byte value
  }
  .byte $ff // reset scroll

// -------------------------------
// plot pixels into koala bitmap -
// and generate speedcode        -
// -------------------------------

// from here on everything is column based, because
// - we want to compress the bitmap data of every column
// - and for easy adressing of the speedcode

.var maxColors = 0          // maximum # of colors in each char
.var bad3 = 0

// --------------------------------------------------------
// 1. first we remove colorclashes from the bitmap        -
// 2. we also make a list of the colors used in each char -
// --------------------------------------------------------

.var bitmapColors = List() // list of colors in each char

.for (var charX=0; charX<width; charX++)                           // first loop over X
{
  .for (var charY=floor(yMin/8); charY<=floor(yMax/8); charY++)    // then loop over Y, to get the speedcode in columns
  {
    .var loops = 0   // keep track of nr of times we try to fix clashes in the koala char
    .var fix = true
    .while (fix)
    {
      .eval loops = loops + 1
      .if (loops>6)
      {
        .eval plotChar(charX, charY)
        .error ("color clash fixer stuck at char = (" + charX + "," + charY + ")")
      }

      .eval fix     = false
      .var nrColors = 0

      .var usedColors = List()         // the used colors in each char
      .var usedColorsCount = List()    // the amount of pixels of each color

      // read all data from this char
      .for (var pixel=0; pixel<4*8; pixel++)
      {
        .var color = getPixel(charX, charY, pixel)

        // is this a new color?
        .if ((colorUsed(color, usedColors)==false) && (color!=-1))
        {
          .eval usedColors.add(color)
        }
      }

      // sort
      .eval usedColors = usedColors.sort()
      .var ht = Hashtable()

      // count # of used colors
      // and generate hashtable

      .var used = 0
      .for (var c=0; c<usedColors.size(); c++)
      {
        .var color = usedColors.get(c)
        .eval used = used+1
        .eval ht.put(color, used)
      }

      .if (used >= 4)         
      { 
        .if (verbose)
        {
          .print ("color clash (" + used + " colors) in char: " + charX + ", " + charY) 
        }

        // count # of occurences of each color
        // general note : it's always the first OR the last color that has the least amount of pixels

        .var leastCount           = 32
        .var leastUsedColor       = -1
        .var secondLeastCount     = 32
        .var secondLeastUsedColor = -1
        .var surroundColor        = -1

        .for (var c=0; c<usedColors.size(); c++)
        {
          .var count = 0
          .var color = usedColors.get(c)

          // count nr of pixels with this color
          .for (var pixel=0; pixel<4*8; pixel++)
          {
            .if (color == getPixel(charX, charY, pixel))
            {
              .eval count = count+1
            }
          }
          .eval usedColorsCount.add(count)
        }

        // determine least used color
        .for (var c=0; c<usedColors.size(); c++)
        {
          .var color = usedColors.get(c)
          .var count = usedColorsCount.get(c)

          .if (count < leastCount)
          {
            .eval leastCount     = count
            .eval leastUsedColor = color
          }
        }

        // determine 2nd least used color
        .for (var c=0; c<usedColors.size(); c++)
        {
          .var color = usedColors.get(c)
          .var count = usedColorsCount.get(c)

          .if ((color != leastUsedColor) && (count < secondLeastCount))
          {
            .eval secondLeastCount     = count
            .eval secondLeastUsedColor = color
          }
        } 

        // determine best substitute color
        .var countReplaceColor = List(nrRibbons)
        .for (var c=0; c<nrRibbons; c++) { .eval countReplaceColor.set(c,0) }
        .var surroundCount = 0
        .for (var pixel=0; pixel<32; pixel++)
        {
          .var pixX = mod(pixel,4)
          .var pixY = floor(pixel/4)

          .if (getPixel(charX, charY, pixel) == leastUsedColor)
          {
            .var nColor = leastUsedColor
            .if (pixX>0) 
            { 
              .eval nColor = getPixel(charX, charY, pixel-1) 
              .if (nColor>=0) { .eval countReplaceColor.set(nColor, (countReplaceColor.get(nColor))+1) } // increase color count
            } // look left
            .if (pixX<3) 
            { 
              .eval nColor = getPixel(charX, charY, pixel+1) 
              .if (nColor>=0) { .eval countReplaceColor.set(nColor, (countReplaceColor.get(nColor))+1) } // increase color count
            } // look right
            .if (pixY>0) 
            { 
              .eval nColor = getPixel(charX, charY, pixel-4) 
              .if (nColor>=0) { .eval countReplaceColor.set(nColor, (countReplaceColor.get(nColor))+1) } // increase color count
            } // look up
            .if (pixY<7) 
            { 
              .eval nColor = getPixel(charX, charY, pixel+4) 
              .if (nColor>=0) { .eval countReplaceColor.set(nColor, (countReplaceColor.get(nColor))+1) } // increase color count
            } // look down
          }
        }
        .for (var c=0; c<nrRibbons; c++)
        {
          .var count = countReplaceColor.get(c)
          .if ((count>surroundCount) && (c!=leastUsedColor))
          {
            .eval surroundColor = c
            .eval surroundCount = count
          }
        }

        // replace least used color
        .var newColor     = -1
        .var replaceColor = -1
        .var ok = false
        .if (ok==false && ht.containsKey(mod(leastUsedColor-1,nrRibbons)))       
        { 
          .eval newColor = mod(leastUsedColor-1,nrRibbons)      
          .eval replaceColor = leastUsedColor 
          .eval ok = true
        }
        .if (ok==false && ht.containsKey(mod(leastUsedColor+1,nrRibbons)))       
        { 
          .eval newColor = mod(leastUsedColor+1,nrRibbons)         
          .eval replaceColor = leastUsedColor 
          .eval ok = true
        }
        .if (ok==false && ht.containsKey(surroundColor))       
        { 
          .eval newColor = surroundColor       
          .eval replaceColor = leastUsedColor 
          .eval ok = true
        }

        .if (ok==false && ht.containsKey(mod(secondLeastUsedColor-1,nrRibbons))) 
        { 
          .eval newColor = mod(secondLeastUsedColor-1,nrRibbons)   
          .eval replaceColor = secondLeastUsedColor 
          .eval ok = true
        }
        .if (ok==false && ht.containsKey(mod(secondLeastUsedColor+1,nrRibbons)))
        { 
          .eval newColor = mod(secondLeastUsedColor+1,nrRibbons)   
          .eval replaceColor = secondLeastUsedColor 
          .eval ok = true
        }

        .if (ok==false)
        {
          .error "error: can't fix color clash"
        }

        .eval ht.remove(replaceColor)

        .for (var pixel=0; pixel<4*8; pixel++)
        {
          .var oldColor = getPixel(charX, charY, pixel)
          .if (replaceColor == oldColor)
          {
            .eval putPixel(charX, charY, pixel, newColor)
          }
        }

        .eval fix = true  // test character again
      } 

      // if this char is OK, store the used colors in a List
      .if (!fix)
      {
        .eval bitmapColors.add(usedColors)
      }
    } // while fix
  } // for charY
} // for charX

// -----------------------------------------------
// now we generate the bitmap data and speedcode -
// -----------------------------------------------

.var lastLSBColor   = -1    // keep track of the last color in LSB
.var lastMSBColor   = -1    // keep track of the last color in MSB
.var lastXColor     = -1    // last color in X register

.var char = 0

.for (var charX=0; charX<width; charX++)           // first loop over X
{
  .var speedcodeColumn = List()  // this list holds all the speedcode for this column
  .var bitmapColumn    = List()  // this list holds all the bitmap data for this column

  .eval lastLSBColor   = -2    // keep track of the last color in LSB
  .eval lastMSBColor   = -2    // keep track of the last color in MSB
  .eval lastXColor     = -2    // last color in X register

  // -2 is undetermined, can be any value
  // -1 means bits 0000

  .for (var charY=floor(yMin/8); charY<=floor(yMax/8); charY++)    // then loop over Y, to get the speedcode in columns
  {
    // ----------------------
    // calculate koala data -
    // ----------------------

    .var firstColor  = 0
    .var secondColor = 0
    .var thirdColor  = 0

    // read colors used in this char
    .var usedColors = bitmapColors.get(char)

    // if a color is ALSO used in the next char, we want that color to be the LAST color
    .if (charY<floor(yMax/8)) // not the last char in the column?
    {
      .var nextColors = bitmapColors.get(char+1)     // read colors in next char
      .for (var c=0; c<usedColors.size(); c++)       // loop over all used colors
      {
        .var color = usedColors.get(c)               // read color
        // is this color used in the next char?
        .var used = false
        .for (var c2=0; c2<nextColors.size(); c2++)  // loop over all colors in the next char
        {
          .var color2 = nextColors.get(c2)           // read color
          .if (color == color2)                      // the same colors?
          {
            .eval usedColors.remove(c)               // remove the color
            .eval usedColors.add(color)              // and add it at the last position
            .eval c  = usedColors.size()             // break loops
            .eval c2 = nextColors.size()
          }
        }
      }
    }

    // count # of used colors and generate hashtable
    .var ht = Hashtable()
    .var used = 0
    .for (var c=0; c<usedColors.size(); c++)
    {
      .var color = usedColors.get(c)
      .eval used = used+1
      .eval ht.put(color, used)
      .if (c==0) { .eval firstColor  = color }
      .if (c==1) { .eval secondColor = color }
      .if (c==2) { .eval thirdColor  = color }
    }
    .eval maxColors = max(used, maxColors)
    
    .var swapBits = false
    // new swapbits function..
    .if (used == 1)
    {
      .if (firstColor == lastLSBColor) { .eval swapBits = false }  // the colors are already correct. do nothing
      else      { .eval swapBits = (firstColor == lastMSBColor) }  // swap the bits if that makes sense
    }
    
    .if (used >= 2)
    {
      // if one of the colors is already correct, swapping makes no sense
      .if ((firstColor == lastLSBColor) || (secondColor == lastMSBColor)) { .eval swapBits = false }
      else
      {
        // if it helps to swap the colors, do it
        .eval swapBits = ((firstColor == lastMSBColor) || (secondColor == lastLSBColor))
      }
    }

    // ----------------------------------
    // read all colors and write bitpairs
    // ----------------------------------

    .for (var byte=0; byte<8; byte++)
    {
      .var byteValue = 0

      .for (var pixel=0; pixel<4; pixel++)
      {
        // read color
        .var color = getPixel(charX, charY, pixel+byte*4)
        .var pixelValue = ht.get(color)
        .var bitValue = 0

        // now give each color a bitpair value
        
        .if ((pixelValue == 1) && !swapBits) { .eval bitValue = %10 } // the first (top) color becomes LSB of screen color
        .if ((pixelValue == 1) &&  swapBits) { .eval bitValue = %01 } // the first (top) color becomes MSB of screen color

        .if ((pixelValue == 2) && !swapBits) { .eval bitValue = %01 } // the last color becomes MSB of screen color}
        .if ((pixelValue == 2) &&  swapBits) { .eval bitValue = %10 } // the last color becomes LSB of screen color 

        .if ((pixelValue == 3))              { .eval bitValue = %11 } // the last (bottom) color becomes $d800 color

        .eval byteValue = byteValue + (bitValue << (2*(3-pixel)))
      }

      .eval bitmapColumn.add(byteValue)
    }

    // prepare speedcode
    .if (used == 1 && !swapBits)
    {
      .var case = 0
      .if (firstColor == lastLSBColor)                                  { .eval case = 1 }
      .if ((firstColor != lastLSBColor) && (firstColor == lastXColor))  { .eval case = 2 }  
      .if ((firstColor != lastLSBColor) && (firstColor != lastXColor))  { .eval case = 3 }

      .if (case==1)
      {
        // case 1: value can be used immediately
      }
      .if (case==2)
      {
        // case 2: we can reuse X
        .eval speedcodeColumn.add(LDA_ABSX, <colorTableL,  >colorTableL)

        .eval lastLSBColor = lastXColor // mark that we loaded A (LSB) depending on the color in X
        .eval lastMSBColor = -1         // no color in MSB
      }
      .if (case==3)
      {
        // we can not use A or X... we'll have to load it
        .var fetchColor   = (ribbons.get(firstColor)+mod(charX,screen_width))
        .eval speedcodeColumn.add(LDX_ABSY, <fetchColor,   >fetchColor)
        .eval speedcodeColumn.add(LDA_ABSX, <colorTableL,  >colorTableL)

        .eval lastXColor   = firstColor // x depends on firstcolor
        .eval lastLSBColor = lastXColor // mark that we have firstColor in LSB
        .eval lastMSBColor = -1         // no color in MSB
      }

      // store it

      .var  storeAddress = screen+mod(charX,screen_width)+charY*screen_width
      .eval speedcodeColumn.add(STA_ABS,  <storeAddress, >storeAddress)
    }

    .if (used == 1 && swapBits)
    {
      // we know that firstColor == lastMSBColor, or else we wouldn't have swapped..
      // we can write A directly

      .var  storeAddress = screen+mod(charX,screen_width)+charY*screen_width
      .eval speedcodeColumn.add(STA_ABS,  <storeAddress, >storeAddress)
    }


    // if we have 2 or 3 colors and decided to swap the bits, simply swap firstColor and secondColor
    .if ((used >= 2) && swapBits)
    {
      .var temp1 = secondColor
      .var temp2 = firstColor
      .eval firstColor  = temp1
      .eval secondColor = temp2
    }

    .var d800Written = false
    .if (used >= 2)
    {
      // optimization - can we write $d800 value by reusing LSB?
      .if (used == 3)
      {
        // reuse A
        .if (thirdColor == lastLSBColor) 
        {
          // store it

          .var storeAddress = $d800+mod(charX,screen_width)+charY*screen_width
          .eval speedcodeColumn.add(STA_ABS,  <storeAddress, >storeAddress)   
          .eval d800Written = true     
        }
        else
        {
          // reuse X
          .if (thirdColor == lastXColor)   
          { 
            .eval speedcodeColumn.add(LDA_ABSX, <colorTableL,  >colorTableL)

            .var storeAddress = $d800+mod(charX,screen_width)+charY*screen_width
            .eval speedcodeColumn.add(STA_ABS,  <storeAddress, >storeAddress)   

            .eval lastXColor   = lastXColor
            .eval lastLSBColor = lastXColor
            .eval lastMSBColor = -1 
            .eval d800Written = true         
          }

          .if ((d800Written == false) && (thirdColor == lastMSBColor)) { .print ("booh") }
        }
      }

      .var case = 0
      .if ((firstColor == lastLSBColor) && (secondColor == lastMSBColor)) { .eval case = 1 }
      .if ((firstColor != lastLSBColor) && (secondColor == lastMSBColor)) { .eval case = 2 }
      .if ((firstColor == lastLSBColor) && (secondColor != lastMSBColor)) { .eval case = 3 }
      .if ((firstColor != lastLSBColor) && (secondColor != lastMSBColor)) { .eval case = 4 }

      .if (case==1)
      {
        // both colors are correct, we can write the value immediately
      }
      .if (case==2)
      {
        // we have to load the LSB Color, but can reuse the MSB color
        .if (lastLSBColor != -1) .eval speedcodeColumn.add(AND_IMM, $f0)     // keep MSB, reset LSB  

        // there are two subcases :
        // case a : we can use X to load LSB
        // case b : we have to load X and A

        // case a : reuse X
        .if (firstColor == lastXColor)
        {
          .eval speedcodeColumn.add(ORA_ABSX, <colorTableL,  >colorTableL)   // ORA with new LSB color   

          .eval lastXColor   = lastXColor    // no change in X
          .eval lastLSBColor = lastXColor    // mark that we loaded A (LSB) depending on the color in X
          .eval lastMSBColor = lastMSBColor  // no change in MSB         
        } else
        {
          .var  fetchColor = (ribbons.get(firstColor)+mod(charX,screen_width))
          .eval speedcodeColumn.add(LDX_ABSY, <fetchColor,   >fetchColor)
          .eval speedcodeColumn.add(ORA_ABSX, <colorTableL,  >colorTableL)

          .eval lastXColor   = firstColor
          .eval lastLSBColor = lastXColor
          .eval lastMSBColor = lastMSBColor     
        }  
      }

      .if (case == 3)
      {
        // we have to load the MSB Color, but can reuse the LSB color
        .if (lastMSBColor != -1) .eval speedcodeColumn.add(AND_IMM, $0f)     // keep LSB, reset MSB
        
        // there are two subcases :
        // case a : we can use X to load MSB
        // case b : we have to load X and A

        // case a : reuse X
        .if (secondColor == lastXColor)
        {
          .eval speedcodeColumn.add(ORA_ABSX, <colorTableH,  >colorTableH)   // ORA with new LSB color   

          .eval lastXColor   = lastXColor    // no change in X
          .eval lastLSBColor = lastLSBColor  // no change in LSB
          .eval lastMSBColor = lastXColor    // mark that we loaded A (MSB) depending on the color in X       
        } else
        {
          .var  fetchColor = (ribbons.get(secondColor)+mod(charX,screen_width))
          .eval speedcodeColumn.add(LDX_ABSY, <fetchColor,   >fetchColor)
          .eval speedcodeColumn.add(ORA_ABSX, <colorTableH,  >colorTableH)

          .eval lastXColor   = secondColor
          .eval lastLSBColor = lastLSBColor
          .eval lastMSBColor = lastXColor     
        }         
      }
      .if (case == 4)
      {
        // we have to load both LSB and MSB colors

        // load LSB color
        .if (firstColor == lastXColor)
        {
          .eval speedcodeColumn.add(LDA_ABSX, <colorTableL,  >colorTableL)   

          .eval lastXColor   = lastXColor
          .eval lastLSBColor = lastXColor
          .eval lastMSBColor = -1 
        } else
        {
          .var  fetchColor = (ribbons.get(firstColor)+mod(charX,screen_width))
          .eval speedcodeColumn.add(LDX_ABSY, <fetchColor,   >fetchColor)
          .eval speedcodeColumn.add(LDA_ABSX, <colorTableL,  >colorTableL)   

          .eval lastXColor   = firstColor
          .eval lastLSBColor = lastXColor
          .eval lastMSBColor = -1 
        }

        // load MSB color
        .if (secondColor == lastXColor)
        {
          .eval speedcodeColumn.add(ORA_ABSX, <colorTableH,  >colorTableH)   

          .eval lastXColor   = lastXColor
          .eval lastLSBColor = lastLSBColor
          .eval lastMSBColor = lastXColor
        } else
        {
          .var  fetchColor = (ribbons.get(secondColor)+mod(charX,screen_width))
          .eval speedcodeColumn.add(LDX_ABSY, <fetchColor,   >fetchColor)
          .eval speedcodeColumn.add(ORA_ABSX, <colorTableH,  >colorTableH)   

          .eval lastXColor   = secondColor
          .eval lastLSBColor = lastLSBColor
          .eval lastMSBColor = lastXColor
        }
      }

      .var  storeAddress = screen+mod(charX,screen_width)+charY*screen_width
      .eval speedcodeColumn.add(STA_ABS,  <storeAddress, >storeAddress)   
    }

    // write $d800 color
    .if ((used == 3) && (d800Written==false))
    {
      // there are 3 cases
      .var case = 0
      .if ( thirdColor == lastLSBColor)                                 { .eval case = 1 }
      .if ((thirdColor != lastLSBColor) && (thirdColor == lastXColor))  { .eval case = 2 }  
      .if ((thirdColor != lastLSBColor) && (thirdColor != lastXColor))  { .eval case = 3 }

      .if (case==1)
      {
        // case 1: value can be used immediately
      }
      .if (case==2)
      {
        // case 2: we can reuse X
        .eval speedcodeColumn.add(LDA_ABSX, <colorTableL,  >colorTableL)

        .eval lastLSBColor = lastXColor // mark that we loaded A (LSB) depending on the color in X
        .eval lastMSBColor = -1         // no color in MSB
      }
      .if (case==3)
      {
        // we can not use A or X... we'll have to load it
        .var fetchColor   = (ribbons.get(thirdColor)+mod(charX,screen_width))
        .eval speedcodeColumn.add(LDX_ABSY, <fetchColor,   >fetchColor)
        .eval speedcodeColumn.add(LDA_ABSX, <colorTableL,  >colorTableL)

        .eval lastXColor   = thirdColor // x depends on thirdColor
        .eval lastLSBColor = lastXColor // mark that we have firstColor in LSB
        .eval lastMSBColor = -1         // no color in MSB
      }

      // store it

      .var storeAddress = $d800+mod(charX,screen_width)+charY*screen_width
      .eval speedcodeColumn.add(STA_ABS,  <storeAddress, >storeAddress)
    }

    .eval char = char + 1         // next char
  } // for charY
  
  .eval speedcodeList.add(speedcodeColumn)           // add the speedcode for this column into the speedcodelist
  .eval bitmapList.add(bitmapColumn)                 // add the bitmap data for this column into the bitmaplist
  .eval bitmapCompressed.add(compress(bitmapColumn)) // compress the bitmap data for this column and save into the list
} // for charX

.print ("bad 3 : " + bad3)

* = * "[CODE] speedcode"
speedcode:
{
  // DO NOT DESTROY Y!!!

    // a holds the start column
    sta jmpPos
    clc
    adc #39
    cmp #width
    bcc !+
      sbc #width
    !:
    sta rtsPos

    // restore previous rts to ldx_absy
    ldx previousRTS: #0
    lda speedcodePositionsLo,x
    sta storeNOP
    lda speedcodePositionsHi,x
    sta storeNOP+1

    lda #LDX_ABSY
    sta storeNOP: loop

    // set jump into the speedcode
    ldx jmpPos: #0
    lda speedcodePositionsLo,x
    sta jump
    lda speedcodePositionsHi,x
    sta jump+1

    // set new rts 
    ldx rtsPos: #0
    lda speedcodePositionsLo,x
    sta storeRTS
    lda speedcodePositionsHi,x
    sta storeRTS+1

    // save new RTS position for future restore
    stx previousRTS  

    lda #RTS
    sta storeRTS: speedcode

    jmp jump: speedcode


loop:
  .for (var c=0; c<width; c++)
  {
    .var codeColumn = speedcodeList.get(c)
    start: .fill codeColumn.size(), codeColumn.get(i)
  }
  jmp speedcode.loop
}

// ------------------------------------------
// pointers to all the columns of speedcode -
// ------------------------------------------

* = * "[DATA] speedcode positions"
speedcodePositionsLo:
  .for (var c=0; c<width; c++) { .byte <(speedcode.loop[mod(c+1,width)].start) }
speedcodePositionsHi:
  .for (var c=0; c<width; c++) { .byte >(speedcode.loop[mod(c+1,width)].start) }

// ---------------------------------------------
// the compressed bitmap data column-by column
// this data is allowed to be placed below $d000
// ---------------------------------------------

* = * "[DATA] compressed data"

.var previousData = List() // list of all columns so far
.var dataPointers = List() // list of pointers to the data
compressedData:
.for (var c=0; c<width; c++)
{
  .var data = bitmapCompressed.get(c)  // get new column of compressed data to store into memory

  // check if this is the same as data we stored before
  .var sameColumn = columnExists(data, previousData) 
  .if (sameColumn>=0) 
  {
    // the column is the same as a previous column, only store pointers to the data
    //.print ("column " + c + " is the same as column " + sameColumn)
    .eval dataPointers.add(dataPointers.get(sameColumn))
  } else {
    // this is a new column, store pointers and the data itself

    .eval dataPointers.add(*)
    .eval previousData.add(data)    // column not present yet, so add it to the list
    .fill data.size(), data.get(i)  // store data in memory
  }
}

* = * "[DATA] compressed data positions"
compressedDataPositionsLo:
  .for (var c=0; c<width; c++) { .byte <(dataPointers.get(c)) }
compressedDataPositionsHi:
  .for (var c=0; c<width; c++) { .byte >(dataPointers.get(c)) }


// read the font, remove equal columns and store in memory
// -------------------------------------------------------

.var fontColumnData     = List()       // list of all different columns of the font
.var fontColumnPointers = List()       // list of all pointers to font columns

.for (var c=0; c<fontGfx.width; c++)   // loop over all columns
{
  .var currentColumn = List()

  // read the column at this c position
  .for (var r=0; r<nrRibbons; r++)  // loop over all rows
  {
    .var color    = c64Colors.get(fontGfx.getPixel(c,r))                               // color of column c and row r
    .var colorMSB = c64Colors.get(fontMSB.getPixel(c,r))                               // read what colorcycle pattern to use
    .if (testPattern == 1) { .eval color = r }                                         // set test pattern if wanted
    .eval currentColumn.add(color + (colorMSB << 4))                                   // store color in list

    //.var prevColor = c64Colors.get(fontGfx.getPixel(c,mod(r-1+nrRibbons,nrRibbons)))  // color of column c and row r-1 
    //.var color     = c64Colors.get(fontGfx.getPixel(c,r))                             // color of column c and row r
    //.if (testPattern == 1) { .eval color = r }                                        // set test pattern if wanted
    //.eval currentColumn.add(color + (prevColor<<4))                                   // store color in list
  }

  // have we seen this color before?
  .var notFound = true
  .for (var p=0; (p<fontColumnData.size()) && notFound; p++)  // loop over all stored columns
  {
    .var storedColumn = fontColumnData.get(p)   // read stored column
    .var same = true
    .for (var i=0; (i<storedColumn.size()) && same; i++)
    {
      .eval same = same && (storedColumn.get(i) == currentColumn.get(i)) // check if the color is the same
    }

    .if (same)
    {
      .eval fontColumnPointers.add(p) // the column already exists. only write a pointer to the column
      .eval notFound = false    // mark that the column in found
    }
  }

  .if (notFound)  // this is a new column. add it to the list
  {
    .eval fontColumnPointers.add(fontColumnData.size())  // add pointer
    .eval fontColumnData.add(currentColumn)
  }
}

// how many unique columns?
.print ("unique columns in font : " + fontColumnData.size())

// write font data into memory
* = font "[DATA] font compressed"
.for (var c=0; c<fontColumnData.size(); c++)
{
  .var column = fontColumnData.get(c)
  .for (var r=0; r<nrRibbons; r++)
  {
    .byte column.get(r)
  }
}

// write font pointers
* = * "[DATA] columnPointers"
columnPointers:
.for (var c=0; c<fontColumnPointers.size(); c++)
{
  .var pointer    = fontColumnPointers.get(c)  // read pointer
  .var memAddress = pointer * 16 + font        // calculate memory address
  .word memAddress
}

/*
.align $100
* = * "[DATA] faderamp generated"
faderamp:
// generate faderamps
.var target = $5
.var ramp   = List().add($0,$6,$9,$2,$b,$4,$8,$e,$c,$5,$a,$3,$f,$7,$d,$1)
.var targetPosition = 0
.var maxStep = 0

// calculate position of target color in the ramp
.for (var c=0; c<16; c++) { .if (ramp.get(c) == target) { .eval targetPosition = c } }

// calculate max number of steps
.eval maxStep = 1+max(targetPosition-0, 15-targetPosition)
.eval maxStep = 16

.var colors = List().add(0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15) // starting colors

.for (var step=0; step<maxStep; step++)
{
  // write bytes
  .fill colors.size(), colors.get(i) + (colors.get(i)<<4)

  // take 1 step towards green
  .for (var i=0; i<16; i++) // loop over list
  {
    .var color = colors.get(i) // read the color
    .var position = 0
    .for (var c=0; c<16; c++) { .if (ramp.get(c) == color) { .eval position = c } }   
    .if (position < targetPosition) { .eval colors.set(i, ramp.get(position+1)) }
    .if (position > targetPosition) { .eval colors.set(i, ramp.get(position-1)) }
  }
}
endFaderamp:
*/

* = screen "[RT] screen for bitmap" virtual
  .fill 1000,0

* = bitmap "[GFX] bitmap" virtual
.fill screen_width*25*8,0 

* = bitmap+$1f40 "[BUFFER]" virtual
buffer:
  .fill 191,0

* = $3fff "[GFX] ghostbyte" virtual
.byte 0
