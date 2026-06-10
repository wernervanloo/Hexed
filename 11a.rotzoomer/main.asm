#import "../00.music/music2.asm"

// todo : -shifttables to start or end of part?
//        -8c00-8dff does not seem to get used..

.const debug      = false
.const fastmode   = false  // true  : plotter speedcode =            lda table,x / sta screen,y / tax. this is faster, but the tables get $1000 bigger
                          // false : plotter speedcode = axs #$bb / lda table,x / sta screen,y / tax. this is slower, but uses less memory for tables

.var border       = BLACK

.var sinLength1 = 64
.var sinLength2 = 43  // 6*43 = 258. almost 256

#import "brr.asm"

.var brrData = getSteps2(40)
.print (brrData)

// x = 40, cpx #1..40 -> carry is always set
// x =  0, cpx #1..40 -> carry is always clear
// x =  1, cpx #1..40 -> carry is only set when x = 1 (the middle)

// charsets : d800 = yellow
//            d021 = black
//            d022 = d grey
//            2023 = m grey

// to make a plasma, we want black to be d800
// swap bitpairs : 00 (black d021) -> 11
// this works if we do and EOR #$ff and also swap d022/d023 colors

// 00 = d021
// 01 = d022
// 10 = d023
// 11 = d800

.var black     = $000000  // #000000
.var blue      = $3828B4  // #3828B4
.var lightblue = $8071FB  // #8071FB
.var cyan      = $72CCD7  // #72CCD7

// memory layout
// -------------

.label sines       = $0800 // final position of sines.. (copied from sineOri)
.label sine1       = sines
.label sine2       = sines+$200

.label firstByte   = $2000
.label code        = $2000

// memory positions of all the charsets
.label charset1    = $4000
.label charset2    = $4800
.label charset3    = $5000
.label charset4    = $5800
.label charset5    = $6000
.label charset6    = $6800
.label charset7    = $7000
.label screen1     = $7800
.label screen2     = $7c00
.label sinesOri    = $7c00 // original position, copy to sines.

.label shiftTables = $8000 // $1000 or $2000 (fastmode)

.label charset8    = $a000
.label charset9    = $a800
.label charset10   = $b000
.label screen3     = $b800
.label screen4     = $bc00

.label charset11   = $c000
.label charset12   = $c800
.label charset13   = $d000
.label charset14   = $d800
.label charset15   = $e000
.label charset16   = $e800

.label screen5     = $f800
.label screen6     = $fc00


// list all the used charsets
.var charsets = List().add( charset1,  charset2, charset3,  charset4,  charset5,  charset6,  charset7,
                            charset8,  charset9, charset10, charset11, charset12, charset13, charset14,
                            charset15, charset16)

// give filenames to charsets
.var filenames = Hashtable()
.eval filenames.put(charset1,  "./charsets/charsetf.bin")
.eval filenames.put(charset2,  "./charsets/charsete.bin")
.eval filenames.put(charset3,  "./charsets/charsetd.bin")
.eval filenames.put(charset4,  "./charsets/charsetc.bin")
.eval filenames.put(charset5,  "./charsets/charsetb.bin")
.eval filenames.put(charset6,  "./charsets/charseta.bin")
.eval filenames.put(charset7,  "./charsets/charset9.bin")
.eval filenames.put(charset8,  "./charsets/charset8.bin")
.eval filenames.put(charset9,  "./charsets/charset7.bin")
.eval filenames.put(charset10, "./charsets/charset6.bin")
.eval filenames.put(charset11, "./charsets/charset5.bin")
.eval filenames.put(charset12, "./charsets/charset4.bin")
.eval filenames.put(charset13, "./charsets/charset3.bin")
.eval filenames.put(charset14, "./charsets/charset2.bin")
.eval filenames.put(charset15, "./charsets/charset1.bin")
.eval filenames.put(charset16, "./charsets/charset0.bin")

// link charsets to the screens (two screens per charset because of double buffering)
.var  screens  = Hashtable()
.eval screens.put(charset1,  List().add(screen1, screen2))
.eval screens.put(charset2,  List().add(screen1, screen2))
.eval screens.put(charset3,  List().add(screen1, screen2))
.eval screens.put(charset4,  List().add(screen1, screen2))
.eval screens.put(charset5,  List().add(screen1, screen2))
.eval screens.put(charset6,  List().add(screen1, screen2))
.eval screens.put(charset7,  List().add(screen1, screen2))
.eval screens.put(charset8,  List().add(screen3, screen4))
.eval screens.put(charset9,  List().add(screen3, screen4))
.eval screens.put(charset10, List().add(screen3, screen4))
.eval screens.put(charset11, List().add(screen5, screen6))
.eval screens.put(charset12, List().add(screen5, screen6))
.eval screens.put(charset13, List().add(screen5, screen6))
.eval screens.put(charset14, List().add(screen5, screen6))
.eval screens.put(charset15, List().add(screen5, screen6))
.eval screens.put(charset16, List().add(screen5, screen6))

// zp adresses
// -----------

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

.macro keepTime() { inc timelow; bne *+4; inc timehigh }

.label firstZP        = $10
  .label colData        = $10 // up to and including $37
  .label selectCharset  = $38 // select screen that corresponds to charset & buffer for the next frame
  .label temp           = $39
  .label shiftUpDown    = $3a
  .label shiftLeftRight = $3b

  .label shiftColUDLow  = $3c
  .label shiftColUDHigh = $3d
  .label shiftColLRLow  = $3e
  .label shiftColLRHigh = $3f

  .label shiftRowLRLow  = $3c  // value for colums up/down is equal to value for rows left/right
  .label shiftRowLRHigh = $3d
  .label shiftRowUDLow  = $3e
  .label shiftRowUDHigh = $3f

  .label waitFrames     = $40
.label lastZP         = $40

#if AS_SPINDLE_PART
  .label spindleLoadAddress = firstByte
  *=spindleLoadAddress-18-9-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word prepare       // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word 0             // cleanup routine
    .word music_play    // location of playroutine call

    //.byte 'M', <music.play, >music.play
    .byte 'Z', <firstZP,   <lastZP
    .byte 'I', >(screen5), >(screen5+$3e7)     // the screens are used, but not yet during prepare
    .byte 'P', >sines,     >(sines+$3ff)       // protect final position of sines

    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2(start); jmp start
#endif

* = code "[CODE] main"
start:
{
  sei

  lda #$35
  sta $01

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  :MusicInitCall()

  #if !AS_SPINDLE_PART
    jsr prepare

    lda #$94
    sta $dd00

    lda #0
    sta timelow
    sta timehigh
  #endif

  lda #0
  sta selectCharset

  lda d018Table
  sta $d018
  lda dd02Table
  sta $dd02

  lda #4
  sta waitFrames

  lda #$d8
  sta $d016
  #if !AS_SPINDLE_PART
    lda #border
    sta $d020
    sta $d021
  #endif

  lda #$00
  sta $d022
  sta $d023

  lda #$00|8
  {
    ldx #0

  loop:
    sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $db00,x
    inx
    bne loop
  }

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$fc
  sta $d012
  lda #$1b
  sta $d011

  lda #<fadeInNMI
  sta $fffa
  lda #>fadeInNMI
  sta $fffb
  lda #RTI
  sta $dd0c

  ldx nextpart
  inx
  stx irq.fadein.preLoadValue   // signal that it is safe to preload over the sinedata
  inx
  stx irq.fadeout.nextPartValue // signal to go to the next part

  lda #$7f
  sta $dc0d               // disable timer interrupts which can be generated by the two CIA chips
  sta $dd0d               // the kernal uses such an interrupt to flash the cursor and scan the keyboard, so stop it

  lda $dc0d               // by reading this two registers we negate any pending CIA irqs.
  lda $dd0d               // if we don't do this, a pending CIA irq might occur after we finish setting up our irq.
                          // we don't want that to happen.
  cli
loop:
  #if !AS_SPINDLE_PART
    //inc $d020
    jmp loop
  #else
    rts
  #endif
}


.text "ich bin aug ein toller typ weil ich auch rot-zoomen kann!!!"
.text " -but rotzooming is just element54 territory-"

prepare:
{
  ldx #0
  loop:
    .for (var i=0; i<2; i++)
    {
      lda sinesOri+i*$100,x
      sta sines+i*$200,x
      sta sines+i*$200+$100,x
    }
    inx
    bne loop

  jmp genTables
}

// this IRQ sets up the NMI's for the fadein
// -----------------------------------------

fadeInIrq:
{
  sta atemp
  stx xtemp

  .var waitCycles = 16*63-1  
  lda #<waitCycles
  sta $dd04
  lda #>waitCycles
  sta $dd05

  // go to irq next
  lda #$fa
  sta $d012
  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff

  asl $d019

  ldx #%10010001
  // remove most of the jitter before starting the NMI countdown..
  lda $d012
  cmp $d012
  bne !+
    bit $ea
  !:

  // set up NMI every 8 rasterlines
  {
    // enable timer 
    stx $dd0e

    lda #$81   // activate nmi
    bit $dd0d
    sta $dd0d
  }

  lda fadeInNMI.readSine1
  clc
  adc #1
  cmp #sinLength1
  bne !+
    lda #0
  !: 
  sta fadeInNMI.readSine1

  dec waitFrames
  bpl !+
    inc fadeInNMI.add
    lda #1
    sta waitFrames
    dec fadeInNMI.readSine2
    bpl !+
      lda #sinLength2
      sta fadeInNMI.readSine2
  !:  

  ldx xtemp: #0
  lda atemp: #0
  rti
}

fadeInNMI:
{
  sta atemp
  stx xtemp
  sty ytemp

  ldx $d012
  //clc
  lda readSine1: sine1+10,x
  adc readSine2: sine2,x
  adc add: #3
  tax

  ldy d021Tab,x
  lda d022Tab,x
  sty $d021
  sta $d022
  lda d023Tab,x
  sta $d023

  ldy ytemp: #0
  ldx xtemp: #0
  lda atemp: #0
  jmp $dd0c
}

fadeOutIrq:
{
  sta atemp
  nop
  nop

  .var waitCycles = 16*63-1  
  lda #<waitCycles
  sta $dd04
  lda #>waitCycles
  sta $dd05

  // go to irq next
  lda #$fa
  sta $d012
  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff

  asl $d019

  nop

  // remove most of the jitter before starting the NMI countdown..
  lda $d012
  cmp $d012
  bne !+
    bit $ea
  !:

  lda step: #13
  sta fadeOutNMI.step

  // set up NMI every 8 rasterlines
  {
    // enable timer 
    lda #%10010001
    sta $dd0e

    lda #$81   // activate nmi
    bit $dd0d
    sta $dd0d
  }

  dec waitFrames
  bpl !+
    inc step
    lda #1
    sta waitFrames
  !:  

  lda atemp: #0
  rti
}

fadeOutNMI:
{
  sta atemp
  stx xtemp
  sty ytemp

  ldx step: #0
  inx
  stx step

  ldy d021Tab2,x
  lda d022Tab2,x
  sty $d021
  sta $d022
  lda d023Tab2,x
  sta $d023

  ldy ytemp: #0
  ldx xtemp: #0
  lda atemp: #0
  jmp $dd0c
}

irq:
{
  sta atemp

  lda #$7f   // disable nmi
  sta $dd0d

  stx xtemp
  sty ytemp
  
  keepTime()

  .if (debug) { inc $d020 }
  :MusicPlayCall()

  // switch to the prepared frame, depending on charset and buffer
  ldx selectCharset
  lda d018Table,x
  sta $d018
  lda dd02Table,x
  sta $dd02

  // change buffer for plotting the next frame
  inc selectCharset

  asl $d019

  jsr script

  // constants to end fadein and fadeout
  .var maxFadeIn = 120
  .var maxFadeOut = 30

  // go to fadein or fadeout? 0 = normal operation, 1 = fade in, 2 = fade out
  lda fade: #0
  cmp #1
  beq fadein    // first check fadein, this one takes the most rastertime.. so let's not waste extra cycles
  bcs fadeout   // then go to fadeout
  jmp normal    // finally normal operation

  fadein:
  {
    // check if fadein has ended
    // -------------------------

    lda fadeInNMI.add
    cmp #maxFadeIn
    bcc !+

      // set up for fadeout
      lda #<fadeOutNMI
      sta $fffa
      lda #>fadeOutNMI
      sta $fffb

      // we can now preload the area where the sines are
      lda preLoadValue: #0 
      sta nextpart

      // fadein has ended
      lda #0
      sta fade
      beq normal
    !:

    // go to fade in
    // -------------

    lda #<fadeInIrq
    sta $fffe
    lda #>fadeInIrq
    sta $ffff
    lda #$36-8+8 // avoid badlines..
    sta $d012
    
    ldx fadeInNMI.readSine1
    lda sine1+($3c-12),x
    ldx fadeInNMI.readSine2
    adc sine2+($3c-12),x
    adc fadeInNMI.add
    tax

    lda d021Tab,x
    sta $d021
    lda d022Tab,x
    sta $d022
    lda d023Tab,x
    sta $d023
    bpl plotScreen
  }

  fadeout:
  {
    lda fadeOutIrq.step
    cmp #maxFadeOut
    bcc !+
      // end fadeout and prepare to go to the next part
      lda nextPartValue: #0
      sta nextpart
      
      lda #0
      sta fade
      beq normal
    !:

    // go to fade out
    // --------------

    lda #<fadeOutIrq
    sta $fffe
    lda #>fadeOutIrq
    sta $ffff
    lda #$36-8
    sta $d012  

    ldx fadeOutIrq.step
    lda d021Tab2,x
    sta $d021
    lda d022Tab2,x
    sta $d022
    lda d023Tab2,x
    sta $d023

    bpl plotScreen
  }

normal:
  // when not fading in or out, repeat this irq
  // ------------------------------------------

  //lda #<irq  // already set
  //sta $fffe
  //lda #>irq
  //sta $ffff
  lda #$fc
  sta $d012

  // calculate and plot the next frame
  // ---------------------------------
plotScreen:
  .if (debug)
  {
    lda #YELLOW
    sta $d020
  }

  jsr movement

  .if (debug) { inc $d020 }
    jsr calcColumnData
  .if (debug) { inc $d020 }
    jsr calcRowData           // remove this : still crashes
  .if (debug) { inc $d020 }
  
    cli

    jsr speedCode

  .if (debug)
  {
    lda #border
    sta $d020
  }

  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

// colors for fadein
// -----------------

d021Tab:
  .fill 80,$0
  .fill 10,$6
  .fill 10,$2
  .fill 10,$8
  .fill 10,$a
  .fill 10,$f
  .fill 100,$7

d022Tab:
  .fill 80,$0
  .fill 10,$0
  .fill 10,$6
  .fill 10,$9
  .fill 10,$4
  .fill 10,$8
  .fill 100,$c

d023Tab:
  .fill 80,$0
  .fill 10,$0
  .fill 10,$0
  .fill 10,$6
  .fill 10,$6
  .fill 10,$b
  .fill 100,$b

// colors for fadeout
// ------------------

d021Tab2:
  .fill 25,7
  .byte $f,$a,$8,$2,$9
  .fill 25,0

d022Tab2:
  .fill 25,$c
  .byte $8,$4,$9,$6,$0
  .fill 25,0

d023Tab2:
  .fill 25,$b
  .byte $b,$b,$6,$0,$0
  .fill 25,0

// generate table with all $d018 values
d018Table: .for (var c=0; c<charsets.size(); c++)
{
  .var charset       = charsets.get(c)
  .var linkedScreens = screens.get(charset)

  .byte (((charset&$3fff)/$800)*2) + ((((linkedScreens.get(0))&$3fff)/$400)*16)
  .byte (((charset&$3fff)/$800)*2) + ((((linkedScreens.get(1))&$3fff)/$400)*16)
}

// generate table with all $dd02 values
dd02Table: .for (var c=0; c<charsets.size(); c++)
{
  .var charset       = charsets.get(c)

  .byte (((charset&$c000)/$4000))|$3c  // value for the first screen
  .byte (((charset&$c000)/$4000))|$3c  // and for the second screen
}

// generate table with all the high bytes of the screens
screenTable: .for (var c=0; c<charsets.size(); c++)
{
  .var charset       = charsets.get(c)
  .var linkedScreens = screens.get(charset)

  .byte >(linkedScreens.get(0)),>(linkedScreens.get(1))
}

//.var tablePos = List().add($0000,$0200,$0400,$0600,$0800,$0a00,-1,-1,-1,-1,$0c00,$0e00,$1000,$1200,$1400,$1600)
.var tablePos = List().add($0000,$0200,$0400,$0600,$0800,$0a00,$0c00,-1,-1,$0e00,$1000,$1200,$1400,$1600,$1800,$1a00)

// generate the tables ($1000) to enable a quick add to only the lower 4 bits while not affecting the upper 4 bits
genTables:
{
  ldy #0
loop:
  // write first table
  tya
  sta shiftTables,y
  .if (fastmode) { sta shiftTables+$100,y }

  // calc MSB value and write it
  and #$f0
  sta temp

  tya
  forLoop: .for (var i=1; i<16; i++)
  {
    .var position = tablePos.get(i)
    sec
    sbc #1
    and #$0f
    ora temp

    // do not write tables for i = 6,7,8,9

    .if (position > 0)
    {
      .if (fastmode)
      {
        sta shiftTables+position,y      // why does sax,y not exist..
        sta shiftTables+position+$100,y
      }
      else
      {
        sta shiftTables+i*$100,y      // why does sax,y not exist..      
      }
    }
  }

  iny
  beq end
  jmp loop
end:
  rts
}

movement:
{
  lda playback: #0
  bne playbackMovement
  // don't rotate, only movement and zooming during fadeout

  // always 'straight' charset
  lda selectCharset
  and #1
  ora #$1e
  sta selectCharset

  lda #0
  sta calcColumnData.startValueUpDownLow

    lda startValUD: #0
    clc
    adc speedUD: #$01  // adjust by $01
    and #$0f
    sta startValUD
    sta calcColumnData.startValueUpDownHigh

  lda #0
  sta calcColumnData.startValueLeftRightLow

  lda startValLR: #0
  clc
  adc speedLR: #$f0  // asjust by $10
  and #$f0
  sta startValLR
  sta calcColumnData.startValueLeftRightHigh

  // this controls the zoom. $3000 = zoom in, $5000 = zoom out

  // adjust zoom speed
  lda zoomSpeedLLow: #0
  clc
  adc zoomAccelLLow: #0
  sta zoomSpeedLLow

  lda zoomSpeedLow:  #0
  adc zoomAccelLow:  #0
  sta zoomSpeedLow

  lda zoomSpeedHigh: #0
  adc zoomAccelHigh: #0
  sta zoomSpeedHigh

  // adjust zoom
  lda zoomLLow:     #0
  clc
  adc zoomSpeedLLow
  sta zoomLLow
  lda zoomLow:      #0
  adc zoomSpeedLow
  sta zoomLow
  //sta $0401
  sta shiftColLRLow
  
  lda zoomHigh: #$04
  adc zoomSpeedHigh
  sta zoomHigh
  //sta $0400
  asl
  asl
  asl
  asl
  sta shiftColLRHigh

  // this always stays 0 if we only zoom and move
  lda #0
  sta shiftColUDLow
  sta shiftColUDHigh
  rts

playbackMovement:
  // playback the movement
  ldy step: #0

  lda readUV: uv,y
  ldx #$f0
  sax calcColumnData.startValueLeftRightHigh
  and #$0f
  sta calcColumnData.startValueUpDownHigh

  lda readULow: uLow,y
  sta calcColumnData.startValueLeftRightLow
  lda readVLow: vLow,y
  sta calcColumnData.startValueUpDownLow
  
  lda readColRowStep: colRowStep,y
  //and #$f0  - x is still f0
  sax shiftColLRHigh
  and #$0f
  sta shiftColUDHigh

  lda readColStepLow: colStepLow,y
  sta shiftColLRLow
  lda readRowStepLow: rowStepLow,y
  sta shiftColUDLow

  lsr selectCharset       // put buffer to use into carry
  lda readCSelect: cSelect,y    // read charset to use
  rol                     // combine charset and buffer
  sta selectCharset       // update d018/bank select
  //sta $00ff

  // next step
  inc step
  bne !+
  {
  nextPage:
    inc readUV+1
    inc readULow+1
    inc readVLow+1
    inc readColRowStep+1
    inc readColStepLow+1
    inc readRowStepLow+1
    inc readCSelect+1
  }
  !:
  rts

Reset:
  lda #>uv
  sta readUV+1
  lda #>uLow
  sta readULow+1
  lda #>vLow
  sta readVLow+1

  lda #>colRowStep
  sta readColRowStep+1
  lda #>colStepLow
  sta readColStepLow+1
  lda #>rowStepLow
  sta readRowStepLow+1
  lda #>cSelect
  sta readCSelect+1
  rts
}

calcColumnData:
{
  // every next column we have to shift a bit up/down
  // ------------------------------------------------

  ldx startValueUpDownHigh  : #$00  // this is the start value for the up/down shifts
  ldy startValueUpDownLow   : #$00  // this is the start value for the up/down shifts
  clc

  .for (var c=0; c<40; c++)
  {
    .if (c==0)
    {
      stx forLoop2[c].LSBValue
    } else
    {
      tya
      adc shiftColUDLow
      tay
      txa
      adc shiftColUDHigh
      // the result is always between 0 and $1e, so carry is always clear
      and #$0f
      tax
      sta forLoop2[c].LSBValue

      // is BRR a solution?!
      // ldx #$0f
      // -------
      // cpy #imm
      // adc zp
      // sax forLoop
      //  ->> we precalculate the #imm values, and select the correct x value for the # of notches we want

      // there is ofcourse some deformation.. not sure if we really want that..
    }
  }

  // every column also has to shift a bit left/right
  // this is the new code with 8 bit subpixel precision
  // --------------------------------------------------

  ldx startValueLeftRightHigh  : #$00  // this is the start value for the left/right shifts
  ldy startValueLeftRightLow   : #$00  // this is the start value for the left/right shifts
  clc

  forLoop2: .for (var c=0; c<40; c++)
  {
    .if (c==0)
    {
      txa
    }
    .if (c>0)
    {
      tya
      adc shiftColLRLow
      tay
      txa
      bcc !+
        adc #$0f  // carry is set, so adc #$0f == adc #$10
        clc
      !:
      adc shiftColLRHigh  // shiftLRHigh is ANDed with #$f0
      tax
    }
    ora LSBValue: #0
    sta colData+c
  }

  rts
}

calcRowData:
{
  // swap steps from Column to use for Row calculation

  lda shiftRowUDHigh
  lsr
  lsr
  lsr
  lsr
  sta shiftRowUDHigh

  lda #$00
  sec
  sbc shiftRowLRLow
  sta shiftRowLRLow
  lda #$10
  sbc shiftRowLRHigh
  asl
  asl
  asl
  asl
  sta shiftRowLRHigh

  // every next row we have to shift a bit up/down

  // normally, we have to add this value every row..
  lax shiftRowUDHigh

  clc
  adc #$01              // but after an overflow we have to shift one pixel more
  and #$0f
  tay                   // put the value needed when an overflow occurs in Y
  lda tableHighBytes,x  // this is the normal value that has to be written
  ldx tableHighBytes,y  // this is the value we have to write when an overflow occurs

  // normally, we have to add this value every row..
  .for (var r=1; r<25; r++) { sta speedCode.forLoop[r].update.table+1 }

  lda calcColumnData.startValueUpDownLow
  clc

  forLoop1: .for (var r=1; r<25; r++)
  {
    adc shiftRowUDLow
    bcc skip              // if carry clear, the correct value is already present in the speedcode
      clc
      stx speedCode.forLoop[r].update.table+1
    skip:
  }

  lda shiftRowLRHigh
  .if (fastmode)
  {
    eor #$f0  // 00->00
    clc       // 10->f0
    adc #$10
  }   

  // normally, we have to add this value every row..
  .for (var r=1; r<25; r++) { .if (fastmode) { sta speedCode.forLoop[r].update.table     } 
                              else           { sta speedCode.forLoop[r].update.selectFastMode.leftRight } }

  // but after an overflow, we have to shift one pixel more
  .if (fastmode)
  {
    sec
    sbc #$10
  } else
  {
    clc
    adc #$10
  }
  tax

  lda calcColumnData.startValueLeftRightLow

  clc
  .for (var r=1; r<25; r++)
  {
    adc shiftRowLRLow
    bcc !+
      clc
      .if (fastmode) { stx speedCode.forLoop[r].update.table                    }
      else           { stx speedCode.forLoop[r].update.selectFastMode.leftRight }
    !:
  }

  rts
}

// generate a table to go from delta-shift to the correct table
tableHighBytes: .for (var i=0; i<16; i++) 
{ 
  .if (fastmode) { .byte >(shiftTables+tablePos.get(i)) } 
  else           { .byte >(shiftTables+(i*$100)) } 
}

* = * "[CODE] speedcode"
speedCode:
{
  // select the correct screen, depending on buffer and charset
  // ----------------------------------------------------------

  ldx selectCharset   // what charset and buffer to plot?
  ldy screenTable,x   // read high byte of screen into Y

  // update plotter by updating the store adresses
  {
    // buffer0
    .var address     = 0
    .var prevAddress = address

    .for (var r=0; r<25; r++)                     // loop over all rows
    {
      .eval address = r*40                        // calculate address for this row (starting at $0000)
      .if ((>address) != (>prevAddress)) { iny }  // increase high byte to store if the address in a different page compared to the previous address
      .eval prevAddress = address                 // remember the new address
      sty forLoop[r].screen+1                     // and update the plotter
    }
  }

  // plot the screen
  ldy #39
loop:                                    // loop over all columns (starting at the right)
  lax colData,y                          // read data for the first row for this column

  forLoop: .for (var r=0; r<25; r++)     // loop over all rows
  {
    update: .if (r>0)
    {
      // note!! we could do the left/right shift by selecting the low
      selectFastMode: .if (fastmode==false) { axs leftRight: #$00 } // shift left/right by modifying the high nybble
      lda table: shiftTables,x      // shift up/down by modifying the low nybble
    }

    sta screen: screen1+r*40,y           // store into the screen

    .if ((r!=0) && (r!=24)) { tax }      // move value into X again for the AXS instruction (X = X&A-#imm)
  }
  dey
  bmi end
  jmp loop
end:
  rts
}

// -------------
// script engine
// -------------

.const Wait      = $80
.const Fade      = $81
.const WaitUntil = $82
.const Playback  = $83 // start playback
.const AccelZoom = $84 // zoom in or out
.const Zoom      = $85 // set a fixed zoom
.const Speed     = $86 // set a fixed speed
.const Break     = $87
.const End       = $ff

script:
{
  lda waitUntil: #0
  beq dontWaitUntil
  lda timehigh
  cmp waitHi: #0
  bcc notyet
  lda timelow
  cmp waitLo: #0
  bcs now
notyet:
  rts
now:
  lda #0
  sta waitUntil
dontWaitUntil:

  lda wait: #0
  sta $0402
  beq continue
  dec wait
  rts

continue:
  ldx scriptPointer: #0
  lda scriptData,x
  
  cmp #Wait
  bne !+
  {
    lda scriptData+1,x
    sta wait
    inx
    jmp done
  }
  !:
  cmp #Fade
  bne !+
  {
    lda scriptData+1,x
    sta irq.fade
    inx
    jmp done
  }
  !:
  cmp #WaitUntil
  bne !+
  {
    lda scriptData+1,x
    sta waitHi
    lda scriptData+2,x
    sta waitLo
    inx
    inx
    lda #1
    sta waitUntil
    jmp done
  }
  !:
  cmp #Playback
  bne !+
  {
    lda #1
    sta movement.playback
    jmp done
  }
  !:
  cmp #AccelZoom
  bne !+
  {
    lda scriptData+1,x
    sta movement.zoomAccelHigh
    lda scriptData+2,x
    sta movement.zoomAccelLow
    lda scriptData+3,x
    sta movement.zoomAccelLLow
    inx
    inx
    inx
    jmp done
  }
  !:
  cmp #Zoom
  bne !+
  {
    lda scriptData+1,x
    sta movement.zoomHigh
    lda scriptData+2,x
    sta movement.zoomLow
    lda scriptData+3,x
    sta movement.zoomLLow
    inx
    inx
    inx
    jmp done
  }
  !:
  cmp #Speed
  bne !+
  {
    lda scriptData+1,x
    sta movement.zoomSpeedHigh
    lda scriptData+2,x
    sta movement.zoomSpeedLow
    lda scriptData+3,x
    sta movement.zoomSpeedLLow
    lda scriptData+4,x
    sta movement.speedUD
    lda scriptData+5,x
    sta movement.speedLR
    inx
    inx
    inx
    inx
    inx
    jmp done
  }
  !:
  cmp #Break
  bne !+
  {
    .break
    nop
    jmp done
  }
  !:
  // no need to check for end. if we do not recognize the command, reset the script
  {
    ldx #0
  }
done:
  inx
  stx scriptPointer
done2:
  rts
}

scriptData:
  #if AS_SPINDLE_PART  
    .byte WaitUntil, $01,$00  // wait until fixed time in the demo for music synching
  #else
    .byte WaitUntil, $00,50   // wait 1 second as test in standalone
  #endif

  // only then start the part
  .byte Fade, 1    // start fade in
  .byte Zoom, $02,$ab,$00       // set zoom to zoomed-in mode  this is a nice starting position without too much distortion

  //.byte Zoom, $05,$f8,$00       // set zoom to zoomed-in mode  this is a nice starting position without too much distortion
  
  .byte Wait, 1  // 100
  .byte AccelZoom, $00,$00,$7a  // zoom out (make smaller, drop it)
  // with accel $7a we nearly hit size $05f800 (5F684) after 59 frames, the speed is $1c1e
  .byte Wait,59-2
  .byte Speed,     $ff,$ec,$00,$01,$00  // quickly reverse speed (first bounce)
  .byte Wait, 81
  .byte Speed,     $ff,$f4,$00,$00,$00  // quickly reverse speed (2nd bounce)
  .byte Wait, 47
  .byte Speed,     $ff,$fb,$00,$00,$00  // quickly reverse speed (3rd bounce)
  .byte Wait, 19
  .byte Speed,     $ff,$fd,$00,$00,$00  // quickly reverse speed (4th bounce)
  .byte Wait, 7
  .byte AccelZoom, $00,$00,$00          // stop zooming out
  .byte Speed,     $00,$00,$00,$00,$00
  .byte Zoom,      $05,$f8,$00       // set zoom to zoomed-in mode  this is a nice starting position without too much distortion
  // we are now ready for takeover.. wait for an interesting moment in the music before playback
  .byte Wait, 125

  .byte Playback   // start playback
  .byte Wait, 230
  .byte Wait, 255
  .byte Wait, 80
  .byte Fade, 2    // fade out, takes 34 frames (if i counted correctly)
  .byte Wait, 255 
  .byte End

// load charsets into files and copy them into the memory
// ------------------------------------------------------

/*
.var previousCharsetPosition = 0
.for (var c=0; c<charsets.size(); c++)    // loop over all charsets
{
  .var charset = charsets.get(c)          // read position of next charset
  .var filename = filenames.get(charset)  // get the filename
  .var data = LoadBinary(filename)        // read data from file

  .if ((charset - previousCharsetPosition)!=$0800) { * = charset "[DATA] charsets" }           // set memory position

  .eval previousCharsetPosition = charset

  .fill data.getSize(), data.get(i)^$ff   // dump data into memory
  }
*/

// load charset file
.var allChars = LoadBinary("./includes/charsets.prg")
//.eval allChars = LoadBinary("./includes/original.prg")


// charset1  = charsetf.bin = positie 1800
// charset2  = charsete.bin = positie 1000
// charset3  = charsetd.bin = positie 0800
// charset4  = charsetc.bin = positie 0000
// charset5  = charsetb.bin = positie 4800
// charset6  = charseta.bin = positie b000
// charset7  = charset9.bin = positie a800
// charset8  = charset8.bin = positie a000
// charset9  = charset7.bin = positie 9800
// charset10 = charset6.bin = positie 9000
// charset11 = charset5.bin = positie 8800
// charset12 = charset4.bin = positie 8000
// charset13 = charset3.bin = positie 4000
// charset14 = charset2.bin = positie 3000
// charset15 = charset1.bin = positie 2800
// charset16 = charset0.bin = positie 2000

.var positionsInFile = List().add($1800,$1000,$0800,$0000,$4800,$b000,$a800,$a000,$9800,$9000,$8800,$8000,$4000,$3000,$2800,$2000)

.var previousCharsetPosition = 0
.for (var c=0; c<charsets.size(); c++)    // loop over all charsets
{
  .var charset = charsets.get(c)          // read position of next charset
  .var positionInFile = positionsInFile.get(c) + $2  // get position in the file

  .if ((charset - previousCharsetPosition)!=$0800) { * = charset "[DATA] charsets" }           // set memory position

  .eval previousCharsetPosition = charset

  .fill 8*256, allChars.uget(positionInFile+i)^$ff   // dump data into memory
  }

// (virtually) occupy memory for all the screens
// we could do this by hand, but let's do it in a neat way
// -------------------------------------------------------

{
  .var occupiedScreens = Hashtable()                           // empty hashtable to remember which screens are already declared

  .for (var c=0; c<charsets.size(); c++)                       // loop over all charsets
  {
    .var charset       = charsets.get(c)                       // read the next charset
    .var linkedScreens = screens.get(charset)                  // read screens that this charset needs

    .for (var i=0; i<linkedScreens.size(); i++)                // loop over the screens
    {
      .var linkedScreen = linkedScreens.get(i)                 // read the next screen
      .if (occupiedScreens.get(linkedScreen) == null)          // is the screen in the hashtable (if not, we did not declare the memory yet)
      {
        .eval occupiedScreens.put(linkedScreen, 1)             // add into the hashtable
        * = linkedScreen "[GFX] screen" virtual; .fill 1000,0  // fill the memory
      }
    }
  }
}

* = shiftTables "[DATA] shift tables" virtual; 
.if (fastmode) { .fill 28*$100,0 }
else           { .fill 16*$100,0 } // virtually occupy the memory for the shifting tables

// --------------------------
// spindle driver can go here
// --------------------------




* = sinesOri "[DATA] sine1 (fade, temporary)"
{
  .var sinMin = 0
  .var sinMax = 60
  .var sinAmp = 0.5 * (sinMax-sinMin)
  .var sinFill   = 256
  .fill sinFill, (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength1)*360/sinLength1))
}

* = * "[DATA] sine2 (fade, temporary)"
{
  .var sinMin = 0
  .var sinMax = 30
  .var sinAmp = 0.5 * (sinMax-sinMin)
  .var sinFill   = 256
  .var sinOffset = 10
  .fill sinFill, (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i+sinOffset,sinLength2)*360/sinLength2))
}

* = sines "[GEN] final position of sinedata" virtual
.fill 4*256,0

// movement test
#import "movement.asm"

.label cSelect    = $3200
.label uv         = $3580
.label uLow       = $3900
.label vLow       = $3c80 // ..$3fff
.label colStepLow = $9c00 // ..$9f80
.label colRowStep = $f000
.label rowStepLow = $f380 // ..$f700

* = cSelect    "[DATA] playback movements"
  .for (var i=0; i<movementData.size(); i++) { .var result = movementData.get(i); .byte result.get(0) }
* = uv         "[DATA] playback movements"
  .for (var i=0; i<movementData.size(); i++) { .var result = movementData.get(i); .byte result.get(1) + result.get(3) } // u uses the ms nybble, v uses the ls nybble
* = uLow       "[DATA] playback movements"
  .for (var i=0; i<movementData.size(); i++) { .var result = movementData.get(i); .byte result.get(2) }
* = vLow       "[DATA] playback movements"
  .for (var i=0; i<movementData.size(); i++) { .var result = movementData.get(i); .byte result.get(4) }
* = colStepLow "[DATA] playback movements"
  .for (var i=0; i<movementData.size(); i++) { .var result = movementData.get(i); .byte result.get(5) }
* = colRowStep "[DATA] playback movements"
  .for (var i=0; i<movementData.size(); i++) { .var result = movementData.get(i); .byte result.get(6) + (result.get(8)/16) }
* = rowStepLow "[DATA] playback movements"
  .for (var i=0; i<movementData.size(); i++) { .var result = movementData.get(i); .byte result.get(7) }
