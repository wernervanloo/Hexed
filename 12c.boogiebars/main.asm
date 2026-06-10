// this is how the kefrens moved in pearls for pigs
// 1st : black (+- 1 wiggle). almost like a standing wave
// 2nd : 3 (+- 0.5 wiggle)
// 3rd : single (+- 1.5 wiggle)
// 4th : 2 (+- 0.5 wiggle)
// 5th : 4
// 6th : single with 3 wiggles

#import "../00.music/music2.asm"
// horizontal kefrens is simply Element54 territory

.const debug      = 0
.const nrRows     = 16        // number of different charrows for plotting into
.const plotLength = nrRows+16 // space to plot the data in. only nrRows are shown (without shifting)
.const invert     = true

.const sin1length   = 128
.const sin2length   = 80
.const boogielength = 64

.const logoCol1   = BLACK        // d800 color
.const logoCol2   = WHITE        // d022 color
.const logoCol3   = CYAN         // d023 color

.const border     = BLUE         // d020 color
.const background = BLUE         // d021 color

// --------------------------------------------------------
// here is all the binary data for the normal kefrens bar -
// --------------------------------------------------------

// tables for plotting the bottom char (char 2)
.var waswordt_20 = LoadBinary("./includes/waswordt0.bin")
.var waswordt_21 = LoadBinary("./includes/waswordt1.bin")
.var waswordt_22 = LoadBinary("./includes/waswordt2.bin")
.var waswordt_23 = LoadBinary("./includes/waswordt3.bin")
.var waswordt_24 = LoadBinary("./includes/waswordt4.bin")
.var waswordt_25 = LoadBinary("./includes/waswordt5.bin") // #$10 this is a solid char and is not used

// tables for plotting the middle char (char 1)
// these are actually not needed and are replaced by lda_imm in the code
.var waswordt_10 = LoadBinary("./includes/waswordt6.bin")  // #$11
.var waswordt_11 = LoadBinary("./includes/waswordt7.bin")  // #$12
.var waswordt_12 = LoadBinary("./includes/waswordt8.bin")  // #$13
.var waswordt_13 = LoadBinary("./includes/waswordt9.bin")  // #$14
.var waswordt_14 = LoadBinary("./includes/waswordt10.bin") // #$15
.var waswordt_15 = LoadBinary("./includes/waswordt11.bin") // #$16

// tables for plotting the top char (char 0)
.var waswordt_00 = LoadBinary("./includes/waswordt12.bin") // #$17 this is a solid char and is not used
.var waswordt_01 = LoadBinary("./includes/waswordt13.bin")
.var waswordt_02 = LoadBinary("./includes/waswordt14.bin")
.var waswordt_03 = LoadBinary("./includes/waswordt15.bin")
.var waswordt_04 = LoadBinary("./includes/waswordt16.bin")
.var waswordt_05 = LoadBinary("./includes/waswordt17.bin")

.var charsetData1 = LoadBinary("./includes/charset1.bin")
.var charsetData2 = LoadBinary("./includes/charset2.bin")

// ---------------------------------------------------------
// here is all the binary data for the 'pills' kefrens bar -
// ---------------------------------------------------------

// tables for plotting the bottom char (char 2)
.var waswordt_20p = LoadBinary("./includes/waswordt_pills0.bin")
.var waswordt_21p = LoadBinary("./includes/waswordt_pills1.bin")
.var waswordt_22p = LoadBinary("./includes/waswordt_pills2.bin")
.var waswordt_23p = LoadBinary("./includes/waswordt_pills3.bin")
.var waswordt_24p = LoadBinary("./includes/waswordt_pills4.bin")
.var waswordt_25p = LoadBinary("./includes/waswordt_pills5.bin") // #$10 this is a solid char and is not used

// tables for plotting the middle char (char 1)
// these are actually not needed and are replaced by lda_imm in the code
.var waswordt_10p = LoadBinary("./includes/waswordt_pills6.bin")  // #$11
.var waswordt_11p = LoadBinary("./includes/waswordt_pills7.bin")  // #$12
.var waswordt_12p = LoadBinary("./includes/waswordt_pills8.bin")  // #$13
.var waswordt_13p = LoadBinary("./includes/waswordt_pills9.bin")  // #$14
.var waswordt_14p = LoadBinary("./includes/waswordt_pills10.bin") // #$15
.var waswordt_15p = LoadBinary("./includes/waswordt_pills11.bin") // #$16

// tables for plotting the top char (char 0)
.var waswordt_00p = LoadBinary("./includes/waswordt_pills12.bin") // #$17 this is a solid char and is not used
.var waswordt_01p = LoadBinary("./includes/waswordt_pills13.bin")
.var waswordt_02p = LoadBinary("./includes/waswordt_pills14.bin")
.var waswordt_03p = LoadBinary("./includes/waswordt_pills15.bin")
.var waswordt_04p = LoadBinary("./includes/waswordt_pills16.bin")
.var waswordt_05p = LoadBinary("./includes/waswordt_pills17.bin")

.var charsetData1p = LoadBinary("./includes/charset1_pills.bin")
.var charsetData2p = LoadBinary("./includes/charset2_pills.bin")

                                                                 // bitpairs $d021,   $d022,   $d023,   $d800
//.var logo = LoadPicture("./includes/element54.png",  List().add($3828B4, $72CCD7, $AAFA7C, $9A40C8))
.var logo  = LoadPicture("./includes/ELEMENT_54.png", List().add($352879, $FFFFFF, $70A4B2, $000000))
                                                                 // bitpairs $d021,   $d022,   $d023,   $d800

// ----------------------------------------
// create data for left to right movement -
// ----------------------------------------

.var movement = List()
// make acceleration movement
{
  .const startPosition = 0
  .var   position      = startPosition
  .const startSpeed    = 0
  .var   speed         = startSpeed
  .const maxPosition   = 320
  .const acceleration  = 0.3
  .var nrBounces       = 0
  .const maxBounces    = 0

  .while (position < maxPosition)
  {
    // update speed
    .eval speed = speed + acceleration

    // update position
    .eval position = position + speed

    // bounce
    .if ((nrBounces < maxBounces) && (position >= maxPosition))
    {
      .print ("bounce")
      .print (position)
      .var overshoot = position - maxPosition
      .eval position = maxPosition - overshoot
      .eval speed = -0.3 * speed
      .eval nrBounces = nrBounces + 1
      .print (overshoot)
      .print (position)
    }

    // store position
    .eval movement.add(min(round(position),320))
  }
  .print ("left to right size : " + movement.size())
}

// --------------------------------------
// generate movement from right to left -
// --------------------------------------

.var movement2 = List()
// make acceleration movement
{
  .const startPosition = 320
  .var   position      = startPosition
  .const startSpeed    = 0
  .var   speed         = startSpeed
  .const minPosition   = 0
  .const acceleration  = -0.3
  .var   nrBounces     = 0
  .const maxBounces    = 3

  .while (position > minPosition)
  {
    // update speed
    .eval speed = speed + acceleration

    // update position
    .eval position = position + speed

    // bounce
    .if ((nrBounces < maxBounces) && (position < minPosition))
    {
      .var overshoot = minPosition - position 
      .eval position = minPosition + overshoot
      .eval speed = -0.5 * speed
      .eval nrBounces = nrBounces + 1
    }

    // store position
    .eval movement2.add(max(round(position),0))
  }

  .print ("right to left size : " + movement2.size())
}

// -----------------------
// read and convert logo -
// -----------------------

// create the list with unique chars
.var emptyChar   = List().add(0,0,0,0,0,0,0,0)  // the empty chars is special
.var uniqueChars = List().addAll(emptyChar)     // add empty char first
.var screenData  = List()
.var rowOffset   = 0  // in this part the logo is 3 char rows lower
.for (var i=0; i<rowOffset*40; i++) { .eval screenData.add(10) }  // add empty char to screendata for the empty rows

.for (var r=0; r<(logo.height/8); r++)
{
  .for (var c=0; c<(logo.width/8); c++)
  {      
    // read char
    .var char = List()
    .for (var byte=0; byte<8; byte++)
    {
      .var value = logo.getMulticolorByte(c,r*8+byte)
      .eval char.add(value)
    }

    .var same = 1
    // is this a new char?
    .for (var i=0; i<(uniqueChars.size()/8); i++)
    {
      .eval same = 1
      .for (var byte=0; byte<8; byte++) { .if (uniqueChars.get(i*8+byte)!=char.get(byte)) { .eval same = 0 } }

      // is the char already in the set?
      .if (same==1)
      {
        // yes.. add the char to the screen
        .if (i==0) { .eval i=10 } // special : use $0a as empty character
        .eval screenData.add(i)

        // and break the loop
        .eval i = uniqueChars.size()/8
      }
    }

    // if we didn't find the char, add it
    .if (same==0)
    {
      // add char to the screen
      .eval screenData.add(uniqueChars.size()/8)

      // add char to the charset
      .eval uniqueChars.addAll(char)

      // special : we want character #10 to be empty.
      .if ((uniqueChars.size()/8)==10)
      {
        .eval uniqueChars.addAll(emptyChar) 
      }
    }
  }
}

.print ("nrChars : " + uniqueChars.size()/8)

// this is how the rasterbar looks in a sprite, if we ever need one..
.var sprite = List().add($00,$00,$00,
                         $00,$00,$00, 
                         $00,$00,$00, 
                         $00,$00,$00, 
                         $00,$00,$00, 
                         $00,$00,$00, 
                         $00,$00,$00, 
                         $00,$00,$00, 
                         $ff,$ff,$ff,
                         $ff,$ff,$ff,
                         $55,$55,$55,
                         $aa,$aa,$aa,
                         $55,$55,$55,
                         $aa,$aa,$aa,
                         $aa,$aa,$aa,
                         $aa,$aa,$aa,
                         $55,$55,$55,
                         $aa,$aa,$aa,
                         $55,$55,$55,
                         $ff,$ff,$ff,
                         $ff,$ff,$ff)   

// determine height of chars from the kefrens charset
.var nrChars = charsetData1.getSize()/8
.var height = 0
.for (var c=0; c<nrChars; c++)
{
  .for (var i=0; i<8; i++) { .if ((charsetData1.get(c*8+i)>0) && (i>(height+1))) { .eval height = i+1 } }
}

.var plotTables = List()

// DARK_GREY/BLACK/GREEN/CYAN

.var col1       = BLACK      // GREEN       // d800 color -> this has to be 0-7
.var col2       = BLACK      // CYAN     
.var col3       = BLACK      // LIGHT_GREEN // middle (lightest) color

.const charsets = List().add($7000, $7800)
.const screens  = List().add($4000,$4400,  // 2
                             $4800,$4c00,  // 4
                             $5000,$5400,  // 6
                             $5800,$5c00,  // 8
                             $6000,$6400,  // 10
                             $6800,$6c00,  // 12
                             $7000,$7400,  // 14
                             $7800,$7c00)  // 16

.label charsetLogo     = $2000  // charset for logo

.label firstByte       = $2800  // first empty page used to spread data
.label sineWaves       = $2800
.label charsetScreen   = $3c00  // screen for logo
.label code            = $8000

.label handOverSprites = $d000
.label handOverCharset = $f000
.label handOverScreen  = $f800

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

.macro keepTime() { inc timelow; bne *+4; inc timehigh }

.label firstZP       = $20

  .label low             = $20
  .label high            = $21
  .label compare         = $22
  .label xOffsetLeft     = $23 // how many chars to scroll to the left
  .label xOffsetRight    = $24 // how many chars to scroll to the right
  .label offset_modded   = $25
  .label offset2_modded  = $26
  .label offset3_modded  = $27
  .label offset          = $28
  .label offset2         = $29
  .label offset3         = $2a
  .label amplitude       = $2b

  .label plotData        = $2c
  // generate plot data tables and mark last used zeropage address
  .for (var i=0; i<height; i++) { * = plotData + (i*plotLength) "[RT] column data" virtual; .eval plotTables.add(*) }
.label lastZP = *

.var wasWordtFiles = List().add(             waswordt_01, waswordt_02, waswordt_03, waswordt_04, waswordt_05,
                  // not needed waswordt_10, waswordt_11, waswordt_12, waswordt_13, waswordt_14, waswordt_15,
                                waswordt_20, waswordt_21, waswordt_22, waswordt_23, waswordt_24) //, waswordt_25)

.var wasWordtFilesp = List().add(             waswordt_01p, waswordt_02p, waswordt_03p, waswordt_04p, waswordt_05p,
                  // not needed waswordt_10p, waswordt_11p, waswordt_12p, waswordt_13p, waswordt_14p, waswordt_15p,
                                waswordt_20p, waswordt_21p, waswordt_22p, waswordt_23p, waswordt_24p) //, waswordt_25p)

.var whichWasWordt = List().add(0,           0,           1,           2,           3,           4,
                                0,           0,           0,           0,           0,           0,
                                5,           6,           7,           8,           9,           0)


// these are all the pages that are empty between the screens and charset data 
// and that we want to fill up.
.var currentPage = 0 // the page in the fillPages list we can write to next
.var fillPages = List().add(//$2800, $2900, $2a00, $2b00,
                            //$2c00, $2d00, $2e00, $2f00,
                            //$3000, $3100, $3200, $3300,
                            //$3400, $3500, $3600, $3700, $3800
                            $3900, $3a00, $3b00,
                            $4100, $4200, $4300,
                            $4500, $4600, $4700,
                            $4900, $4a00, $4b00,
                            $4d00, $4e00, $4f00,
                            $5100, $5200, $5300,
                            $5500, $5600, $5700,
                            $5900, $5a00, $5b00,
                            $5d00, $5e00, $5f00,
                            $6100, $6200, $6300,
                            $6500, $6600, $6700,
                            $6900, $6a00, $6b00,
                            $6d00, $6e00, $6f00,
                             // charset at $7000-$77ff!
                             // charset at $7800-$7fff!
                            $9800, $9900, $9a00,
                            $9b00, $9c00, $9d00,
                            $9e00, $9f00, $a000,
                            $a100, $a200,
                            $a300, $a400, $a500,
                            $a600, $a700
                            )

.var plotters = List()

.function getPage()
{
  .var page = fillPages.get(currentPage)
  .eval currentPage++
  .return page
}

// put the sine waves into memory first. They occupy a whole page and do not mingle well with 'free' pages that also hold sprite pointers

* = getPage() "[DATA] sine"
sine:
{
  .var sinMin = ($00)*2  // double because ROR is added into tab1 and tab2
  .var sinMax = ($16)*2
  .var sinAmp = 0.5 * (sinMax-sinMin)
  .var sinLength = sin1length
  .fill 256, (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength))
}

* = getPage() "[DATA] sine2"
sine2:
{
  .var sinMin = $00*2
  .var sinMax = $42*2
  .var sinAmp = 0.5 * (sinMax-sinMin)
  .var sinLength = sin2length
  .fill 256, (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength))
}

.var wasWordtAddress  = List() // keep track where the wasWordt tables are in memory
.var wasWordtAddressp = List() // keep track where the wasWordt tables are in memory

// put waswordt into memory
.for (var i=0; i<wasWordtFiles.size(); i++)
{
  //* = wasWordtAddress.get(i) "[DATA] waswordt"
  * = getPage() "[DATA] waswordt"
  .eval wasWordtAddress.add(*)

  .var dataFile = wasWordtFiles.get(i)
  .fill dataFile.getSize(), dataFile.get(i)  
}

// put wasword [pill] into memory
.for (var i=0; i<wasWordtFilesp.size(); i++)
{
  //* = wasWordtAddress.get(i) "[DATA] waswordt"
  * = getPage() "[DATA] waswordt pills"
  .eval wasWordtAddressp.add(*)

  .var dataFile = wasWordtFilesp.get(i)
  .fill dataFile.getSize(), dataFile.get(i)  
}

// occupy data for charsets and screens

* = charsets.get(0)      "[GFX] charset part 1"
  .fill charsetData1.getSize(), charsetData1.get(i)
* = charsets.get(0)+$400 "[GFX] charset part 2"
  .fill charsetData2.getSize(), charsetData2.get(i)

* = charsets.get(1)      "[GFX] charset pills part 1"
  .fill charsetData1p.getSize(), charsetData1p.get(i)
* = charsets.get(1)+$400 "[GFX] charset pills part 2"
  .fill charsetData2p.getSize(), charsetData2p.get(i)

#if AS_SPINDLE_PART
  .label spindleLoadAddress = firstByte
  *=spindleLoadAddress-18-12-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word prepare       // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word 0             // cleanup routine
    .word music_play // location of playroutine call

    .byte 'Z', <firstZP,         <lastZP
    .byte 'I', >charsetLogo,     >(charsetLogo+uniqueChars.size())  // inherit logo from border fade
    .byte 'I', >handOverSprites, >(handOverSprites+$eff)  // keep sprites            from border in the memory for the fadeout
    .byte 'I', >handOverCharset, >(handOverScreen+$3e8)   // keep charset and screen from border in the memory for the fadeout

    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2(start); jmp start
#endif

* = code "[CODE] Main"
start:
{
  sei
  lda #$35
  sta $01

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  #if !AS_SPINDLE_PART
    lda #$94
    sta $dd00

    // setup display - keep the old screen in spindle until the irq's are running..
    lda #$3c
    sta $dd02

    // setup colors
    lda #border
    sta $d020
    lda #background
    sta $d021

    // multicolor mode
    lda #$d8
    sta $d016
  #endif

  lda #$00
  sta $d015

  // in spindle, the colors are already set
  #if !AS_SPINDLE_PART
    ldx #0
    !:   
      lda #logoCol1|8
      sta $d800,x
      sta $d900,x
      sta $da00,x
      sta $db00,x
      inx
    bne !-
  #endif

  ldx #39
  !:
    lda #col1|8
    sta $d800,x
    sta $d828,x
    dex
    bpl !-

  lda #0
  sta amplitude
  sta xOffsetRight
  sta offset
  sta offset2
  sta offset3

  lda #40
  sta xOffsetLeft

  #if !AS_SPINDLE_PART
    lda #0
    sta timelow
    sta timehigh

    jsr prepare
    :MusicInitCall()
  #endif

  ldx nextpart
  inx
  stx handOverIrq.nextPartValue

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff

  lda $d011
  and #$7f
  sta $d011

  lda #$fa
  sta $d012

  cli
      
  #if !AS_SPINDLE_PART
  loop:
    //inc $d020
    jmp loop
  #else
    rts
  #endif
}

prepare:
{
  rts
}

// to do double buffering, we have to use FLD.
// in even frames, we will show row 1 of the screen
// in odd frames, we will show row 0 of the screen
// to use row 0, we will have to FLD the screen down
FLDIrq:
{
  sta atemp

  lda #$1b  // FLD 4 more pixels..
  sta $d011

  lda #$3d
  sta $dd02

  lda d018TableReversed+15
  sta $d018

  lda #<doubleRowIrq
  sta $fffe
  lda #>doubleRowIrq
  sta $ffff
  lda d012TableReversed+nrRows-1
  sta $d012
  asl $d019

  lda atemp: #0
  rti  
}

preIrq:
{
  sta atemp

  lda #$3d
  sta $dd02
  lda d018TableReversed+15
  sta $d018

  lda #<doubleRowIrq
  sta $fffe
  lda #>doubleRowIrq
  sta $ffff
  lda d012TableReversed+nrRows-1
  sta $d012

  asl $d019
  lda atemp: #0
  rti
}

doubleRowIrq:
{
  sta atemp
  stx xtemp

  ldx index: #nrRows-2

  lda d011TableReversed,x
  sta $d011
  lda d012TableReversed,x
  sta $d012

  // for bank 1 (4000-8000) (dd02 = $01) the charset is at $5000 (d018 = $04)
  // for bank 3 (c000-ffff) (dd02 = $03) the charset is at $d000 (d018 = $04)
  // if we change bank, we also change charset (if we use the same value for dd02 and d018)
  // if the charset is at 5000 in bank 1
  // the charsets would have to be at 5800 in bank 2 (bit 1 gets set)
  // but then we would have to do cycle exact changing of the $d018 to avoid glitches
  // or.. we could have charset at $5000 AND $5800 :-) (and $d000 and $d800)
  // is 16 pages worth 16*4 cycles?

  lda d018TableReversed,x
  sta $d018
  
  // keep jumping to this irq, unless we have to end
  dec index
  bmi endIrqs

  asl $d019
  lda atemp: #0
  ldx xtemp: #0
  rti

endIrqs:
  lda #$3a+1+(nrRows*height) - 1//+height
  sta $d012
  lda #<logoIrq
  sta $fffe
  lda #>logoIrq
  sta $ffff
  asl $d019
  lda atemp
  ldx xtemp
  rti
}

logoIrq:
{
  sta atemp

  // rasterline a3, d011 = 15
  // this would make a badline at a5

  lda irq.fld // if 0, we did not do a fld -> we have to fld now to make the screen stable
              // if 1, we already did a fld and do not have to do an fld now
  
  bne noFLD

  lda #$1f    // set $d011 to avoid a badline at rasterline a5
  sta $d011

  lda #<deFLDIrq
  sta $fffe
  lda #>deFLDIrq
  sta $ffff
  lda #$a4
  sta $d012
  bne continue

noFLD:
  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$fa
  sta $d012

continue:

  asl $d019

  // switch back to stable x position
  lda #$d8
  sta $d016

  // switch back to logo
  lda #((charsetLogo&$3c00)/$4000)|$3c
  sta $dd02

  lda #(((charsetScreen&$3c00)/$400)*16) | (((charsetLogo&$3800)/$800)*2)
  sta $d018

  lda #logoCol2
  sta $d022
  lda #logoCol3
  sta $d023

  lda atemp: #0
  rti  
}

deFLDIrq:
{
  sta atemp
  lda #$13+8   // set $d011 to create a badline at rasterline a5+8
  sta $d011

  // switch back to logo
  lda #(((charsetScreen&$3c00)/$400)*16) | (((charsetLogo&$3800)/$800)*2)
  sta $d018

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$fa
  sta $d012

  asl $d019
  lda atemp: #0
  rti  
}

playMusic:
{
  keepTime()          // increase frame counter
  :MusicPlayCall()  
  rts
}

// if we have to switch to the next part, we will do this using the handover Irq
handOverIrq:
{
  sta irq.atemp
  stx irq.xtemp
  sty irq.ytemp
start:
  lda #<handOverIrq
  sta $fffe
  lda #>handOverIrq
  sta $ffff
  lda #$fa
  sta $d012
  asl $d019

  // swith to hand over gfx that are still in memory
  lda #((handOverScreen&$3c00)/$400)*$10+((handOverCharset&$3800)/$800*$2)
  sta $d018
  lda #((handOverScreen&$c000)/$4000)|$3c
  sta $dd02

  jsr playMusic

  lda nextPartValue: #0
  sta nextpart

  lda irq.atemp
  ldx irq.xtemp
  ldy irq.ytemp

  rti
}

irq:
{
  sta atemp
  stx xtemp
  sty ytemp

  lda #$1b
  sta $d011

  jsr script

  // switch over to handover Irq?
  lda goHandOver: #0
  bne handOverIrq.start

  // reset repeat charrow Irqs
  lda #nrRows-2
  sta doubleRowIrq.index

  lda d022Color: #col2
  sta $d022
  lda d023Color: #col3
  sta $d023

  lda spriteY: #0
  lsr
  clc
  adc spriteAdd: #0
  clc
  adc #$26
  sta $d001

  lda d016: #$d8
  sta $d016

  // move to the right?
  // ------------------

  lda right: #0
  beq skipRight
  {
    ldx index: #0
    lda movementChars,x
    sta xOffsetRight
    lda movementD016,x
    sta d016

    inx
    cpx #movement.size()
    bne !+
      ldx #0
      stx right
  !:
    stx index
  }
  skipRight:

  // move to the left?
  // ------------------

  lda left: #0
  beq skipLeft
  {
    ldx index: #0
    lda movement2Chars,x
    sta xOffsetRight
    lda movement2D016,x
    sta d016

    inx
    cpx #movement2.size()
    bne !+
      ldx #0
      stx left
  !:
    stx index
  }
  skipLeft:

  lda unroll: #0
  beq skipUnroll
  {
    lda wait: #1
    bne waitFrame
    lda maxWait: #30
    sta wait

    lda maxWait
    cmp #2
    beq !+
    sec
    sbc #4
    sta maxWait
  !:

    lda xOffsetLeft
    beq kill
    sec
    sbc #1
    sta xOffsetLeft
    bne skipUnroll
  kill:
    sta unroll     // unroll finished
  waitFrame:
    dec wait
  }
  skipUnroll:

  lda wave: #0
  beq skipWave
  {
    lda amplitude
    cmp #$10
    beq endWave

    lda wait: #2
    bne waitFrame

    lda #2
    sta wait
    lda amplitude
    clc
    adc #1
    sta amplitude
    cmp #$10         // max reached? stop
    bne skipWave
  endWave:
    lda #0
    sta wave
  waitFrame:
    dec wait
  }
  skipWave:

  .if (debug==1) { inc $d020 }

  jsr playMusic

  lda fld: #0
  eor #1
  sta fld

  beq noFLD

  // we need to FLD the screen down
  lda #$1f  // first move 4 pixels down
  sta $d011
  lda #<FLDIrq
  sta $fffe
  lda #>FLDIrq
  sta $ffff
  lda #$34
  sta $d012
  bne continue  

noFLD:
  lda #<preIrq
  sta $fffe
  lda #>preIrq
  sta $ffff
  lda #$38
  sta $d012
continue:

  asl $d019

  jsr clearPlotData

  cli

  lda fld
  bne frame0

  .if (debug==1) { inc $d020 }
    // plot in the background
    jsr plotFrame1
  .if (debug==1) 
  { 
    lda #border 
    sta $d020 
  }
  jmp endIrq

frame0:
  .if (debug==1) { inc $d020 }
    // plot in the background
    jsr plotFrame0
  .if (debug==1) 
  { 
    lda #border 
    sta $d020 
  }
endIrq:
  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  rti
}

// these are the commands in the script for the part
.var Wait         = $00
.var Unroll       = $01
.var Right        = $02 // move to the right
.var Left         = $03 // move to the left
.var Reset        = $04
.var Wave         = $05
.var ColorChange  = $06
.var ColorChange2 = $07
.var Skip1        = $08
.var Skip2        = $09
.var Skip3        = $0a
.var Speeds       = $0b
.var WaitUntil    = $0c
.var Cialis       = $0d

.var adresses = List().add(script.checkWait, script.checkUnroll, script.checkRight, script.checkLeft, script.checkReset, script.checkWave, script.checkColorChange, script.checkColorChange2, script.checkSkip1, script.checkSkip2, script.checkSkip3, script.checkSpeeds, script.checkWaitUntil, script.checkCialis)
scriptJumpTable: .lohifill adresses.size(),adresses.get(i)

*=* "[CODE] script"
script:
{
  lda waitUntil: #0
  beq dontWaitUntil
  lda timehigh
  cmp waitHi: #0
  bcc notYet
  lda timelow
  cmp waitLo: #0
  bcs stopWaiting
notYet:
  // we didnt reach the frame yet
  rts
stopWaiting:
  // frame reached. stop waiting for the frame
  lda #0
  sta waitUntil

  // are we waiting for a certain # of frames?
dontWaitUntil:
  lda wait: #0
  beq advanceScript
  dec wait
  rts
advanceScript:

  ldx scriptPointer: #0
  ldy scriptData,x
  lda scriptJumpTable.lo,y
  sta jump
  lda scriptJumpTable.hi,y
  sta jump+1

  jmp jump: $1234

  checkSkip1:
  {
    inx
    lda scriptData,x
    sta skip1
    inx
    stx scriptPointer

    jmp genModOffset1
  }

  checkSkip2:
  {
    inx
    lda scriptData,x
    sta skip2
    inx
    stx scriptPointer

    jmp genModOffset2
  }
  checkSkip3:
  {
    inx
    lda scriptData,x
    sta skip3
    inx
    stx scriptPointer

    jmp genModOffset3
  }
  checkSpeeds:
  {
    inx
    lda scriptData,x
    sta progressSines.update1.speed
    inx
    lda scriptData,x
    sta progressSines.update2.speed
    inx
    lda scriptData,x
    sta plotFrame0.updateBoogie.speed
    sta plotFrame1.updateBoogie.speed
    jmp end
  }

  checkUnroll:
  {
    lda #1
    sta irq.unroll
    bne end    
  }

  checkRight:
  {
    lda #1
    sta irq.right
    bne end    
  }

  checkLeft:
  {
    lda #1
    sta irq.left
    bne end    
  }

  checkReset:
  {
    lda #(scriptReset-scriptData)
    sta scriptPointer

    #if AS_SPINDLE_PART
      // switch to handOver Irq to safely go to the next part
      lda #1
      sta irq.goHandOver
    #endif
    
    jmp advanceScript
  }

  checkWave:
  {
    lda #1
    sta irq.wave
    bne end
  }

  checkColorChange:
  {
    inx
    ldy scriptData,x // load next colorset
    lda d022Colors,y
    sta irq.d022Color
    lda d023Colors,y
    sta irq.d023Color
    lda d021Colors,y
    
    ldy #79
    loop:
    {
      sta $d800,y
      dey
      bpl loop
    }
    bmi end 
  }

  checkColorChange2:
  {
    inx
    ldy scriptData,x // load next colorset
    lda d022Colors,y
    sta irq.d022Color
    lda d023Colors,y
    sta irq.d023Color
    bpl end 
  }
  checkWaitUntil:
  {
    lda scriptData+1,x
    sta waitHi
    lda scriptData+2,x
    sta waitLo
    inx
    inx
    lda #1
    sta waitUntil
    bne end
  }
  checkCialis:
  {
    inx
    stx scriptPointer
    jmp goPills
  }

  checkWait:
  {
    inx
    lda scriptData,x
    sta wait
  }
  end:
  {
    inx
    stx scriptPointer
    rts
  }
}

d021Colors: .byte BLACK|8,     GREEN|8,      RED|8,   PURPLE|8,   PURPLE|8
d022Colors: .byte   BLACK,        GREEN,     PURPLE,  LIGHT_RED,  LIGHT_RED
d023Colors: .byte   BLACK, LIGHT_GREEN,  LIGHT_RED, LIGHT_GREY,        RED

scriptData:
  .byte Wait,50        // wait 50 frames
  #if AS_SPINDLE_PART
    .byte WaitUntil, $08,$a0
  #endif
  .byte Unroll         // unroll the kefrens bars
  .byte Wait,200       // wait 200 frames
  .byte Wait,200

  #if AS_SPINDLE_PART
    .byte WaitUntil, $0a, $7d
  #else
    .byte Wait,50
  #endif

  .byte Right          // move right (and back left again)
  .byte Wait,44
scriptReset:           // the script resets to this place
  .byte ColorChange,1  // switch to color set #1 (green)
  .byte Skip1,1
  .byte Skip2,1
  .byte Skip3,3
  #if AS_SPINDLE_PART
    .byte WaitUntil, $0a,$b5
  #endif
  // when is this exact moment?
  .byte Left
  .byte Wait,110        // wait 110 frames
  .byte Wait,115

  .byte Speeds, 0, 0, 0 // stop the wave
  .byte Wait, 50
  .byte Wave            // show the wave
  // wait until the swoosh
  #if AS_SPINDLE_PART
    .byte WaitUntil,$0c,$40
  #else
    .byte Wait,108
  #endif
  .byte Speeds, 0, 0, 63

  // wait until the beat
  #if AS_SPINDLE_PART
    .byte WaitUntil,$0c,$c0
  #else
    .byte Wait,92
  #endif

  .byte Speeds, 1, 1, 63
  //.byte Wait,192       // wait 192 frames
  .byte Wait,130

  .byte Right
  .byte Wait,50
  .byte ColorChange,2  // switch to color set #2 (red)
  .byte Skip1,5
  .byte Skip2,39
  .byte Skip3,2
  .byte Speeds, 1, 1, 63
  .byte Left
  .byte Wait,110       // wait 110 frames
  .byte Wait,135       // wait 135 frames

  .byte Right
  .byte Wait,50
  .byte ColorChange,3  // switch to color set #2 (red)
  .byte Skip1,3
  .byte Skip2,3
  .byte Skip3,4
  .byte Speeds, 1, sin2length-1, 63
  .byte Left
  .byte Wait,110       // wait 110 frames
  .byte Wait,135       // wait 135 frames

  .byte Right
  .byte Wait,50
  .byte ColorChange,4  // switch to color set #2 (blue)
  .byte Skip1,5
  .byte Skip2,39
  .byte Skip3,2
  .byte Cialis         // go into pills mode
  .byte Speeds, 1, 1, 63
  .byte Left
  .byte Wait,110       // wait 110 frames
  .byte Wait,135       // wait 135 frames

  .byte Right          // move right (and back left again)

  #if AS_SPINDLE_PART
    .byte WaitUntil,$11,$46
  #else
    .byte Wait,50
  #endif

  .byte Reset          // reset script


goPills:
{
  ldx #0
  {
  loop:
    lda tab1p,x
    sta tab1,x
    inx
    bne loop
  }

  ldx #$0f
  {
  loop:
    lda d018TableReversed,x
    eor #((charsets.get(0)&$3800)/$800*2) ^ ((charsets.get(1)&$3800)/$800*2)
    sta d018TableReversed,x
    dex
    bpl loop
  }
  rts
}

// generate code to clear all plot data
clearPlotData:
{
  lda #10
  .for (var i=0; i<nrRows + 4; i++)
  {
    .for (var j=0; j<plotTables.size(); j++)
    {
      .var table = plotTables.get(j)
      sta table+i
    }
  }
  rts
}

.var sin1skip   = 0   // lenght 128
.var sin1speed  = 127

.var sin2skip   = 41  // lenghth 80
.var sin2speed  = 1

.var boogieskip   = 3
.var boogiespeed  = 0

//0,41 -> no boogie
//127,1,2
//5,39,3
//3,3,2

skip1: .byte 3
skip2: .byte 3
skip3: .byte 2

genModOffset1:
{
  ldx #1
  lda skip1
  clc
  {
  loop:
    // carry already clear
    sta modOffset1,x
    adc skip1
    cmp #sin1length
    bcc !+
      // carry already set
      sbc #sin1length
    !:
    inx
    cpx #40  // carry clear after cpx
    bne loop
  }

  .for (var c=0; c<40; c++)
  {
    lda modOffset1+c
    sta calcYPos1.forLoop[c].loadSine
    sta calcYPos2.forLoop[c].loadSine
  }
  rts
}

genModOffset2:
{
  ldx #1
  lda skip2
  clc
  {
  loop:
    // carry already clear
    sta modOffset2,x
    adc skip2
    cmp #sin2length
    bcc !+
      // carry already set
      sbc #sin2length
    !:
    inx
    cpx #40  // carry clear after cpx
    bne loop
  }

  .for (var c=0; c<40; c++)
  {
    lda modOffset2+c
    sta calcYPos1.forLoop[c].addSine
    sta calcYPos2.forLoop[c].addSine
  }
  rts
}

genModOffset3:
{
  ldx #1
  lda skip3
  clc
  {
  loop:
    // carry already clear
    sta modOffset2x64,x
    adc skip3
    cmp #boogielength
    bcc !+
      // carry already set
      sbc #boogielength
    !:
    inx
    cpx #40  // carry clear after cpx
    bne loop
  }
  rts
}

calcYPos1:
{
  ldx offset_modded
  ldy offset2_modded

  forLoop: .for (var c=0; c<40; c++)
  {
    .var c2 = mod(sin1skip*c, sin1length)
    .var c3 = mod(sin2skip*c, sin2length)

    lda loadSine: sine  + c2,x
    // @HCL : please don't bitch about the lack of CLC and ROR
    // clc is not needed since the carry is never set
    // ror is not needed because it's taken care of in the tables instead.
    adc addSine: sine2 + c3,y
    sta plotFrame0.forLoop2[c].yPos
  }
  rts
}

calcYPos2:
{
  ldx offset_modded
  ldy offset2_modded

  forLoop: .for (var c=0; c<40; c++)
  {
    .var c2 = mod(sin1skip*c, sin1length)
    .var c3 = mod(sin2skip*c, sin2length)

    lda loadSine: sine  + c2,x
    // @HCL : please don't bitch about the lack of CLC and ROR
    // clc is not needed since the carry is never set
    // ror is not needed because it's taken care of in the tables instead.
    adc addSine: sine2 + c3,y
    sta plotFrame1.forLoop2[c].yPos
  }
  rts
}

* = * "[CODE] plotframe 0"
plotFrame0:
{
  {
    // if the bars are moving to the right, we have to clear the part on the left.
    // optimization possible : maybe it's enough to only clear the empty column on the far right
    // if the bars are moving <= 8 pixels/frame (actually <=4 pixels per frame because of double buffering)

    lda xOffsetRight
    beq clearNotNeeded
    tay
    clc
    adc #39
    tax
  clearLoop:
    jsr plotCode.forLoop1[0].forLoop2[0].plot
    dex
    dey
    bne clearLoop
  clearNotNeeded:
  }
  updateBoogie:
  {
    lda offset3
    clc
    adc speed: #boogiespeed
    cmp #boogielength
    bcc !+
      sbc #boogielength
    !:
    sta offset3
  }
  {
    // compensate offset for xOffsetRight
    ldx xOffsetRight
    sec
    sbc modOffset2x64,x
    bcs !+
    adc #64
  !:
    ldx xOffsetLeft
    ldx #0
    clc
    adc modOffset2x64,x
    cmp #64
    bcc !+
    sbc #64
  !:
    //tax
  }

  sta low
  lda amplitude
  clc
  adc #>sineWaves
  sta high

  // prepare disco swing. add into plotter later
  .for (var c=0; c<40; c++)
  { 
    ldy modOffset2x64+c
    lda (low),y
    sta plotFrame0.forLoop2[c].plotter+1  
  }
  
  jsr progressSines
  jsr calcYPos1

  // jump to the correct spot to move to the right
  ldx xOffsetRight
  lda plotFrame0StartLo,x
  sta jump
  lda plotFrame0StartHi,x
  sta jump+1
  
  // restore LDY in the speedcode
  lda #LDY_IMM
  sta restoreLDX: forLoop2[0].start

  lda #40
  sec
  sbc xOffsetLeft
  tax
  lda plotFrame0StartLo,x
  sta setRTS
  sta restoreLDX
  lda plotFrame0StartHi,x
  sta setRTS+1
  sta restoreLDX+1

  // set RTS in speedcode
  lda #RTS
  sta setRTS: forLoop2[0].start
  clc
  jsr jump: forLoop2[0].start

  // do we have to plot extra bars at the right?
  lda xOffsetLeft
  bne plotExtraBars
  
  // no
  rts
plotExtraBars:
  // yes.. extra bars coming up

  lda #40
  sec
  sbc xOffsetLeft
  tay

  lda #40+40
  sec
  sbc xOffsetLeft
  tax  // this is the X value for the first column

plotExtraLoop:
  // read address where to JSR to
  lda plotter0PositionsLo-40,x
  sta indirect
  lda plotter0PositionsHi-40,x
  sta indirect+1
  // read high byte
  lda indirect: $1000
  sta jsrAddress+1

  jsr jsrAddress: plotCode.forLoop1[0].forLoop2[0].plot
  inx
  cpx #80
  bcc plotExtraLoop
  rts

  forLoop2: .for (var c=0; c<40; c++)
  {
    start:

    ldy yPos: #0

    lda tab1,y
    sta plotFrame0.forLoop2[c].jsrAddress+1
    ldx tab2,y

    jsr jsrAddress: plotOffset0  // needs x, thrashes y
skipPlot:
    ldx #40+c                    // directly loading x is quicker than storing + restoring
    jsr plotter: $1080
  }

  noPlot:
  rts
}

* = * "[CODE] plotframe 1"
plotFrame1:
{
  // if the bars are moving to the right, we have to clear the part on the left.
  // optimization possible : maybe it's enough to only clear the empty column on the far right
  // if the bars are moving <= 8 pixels/frame (actually <=4 pixels per frame because of double buffering)
  {
    lda xOffsetRight
    beq clearNotNeeded
    tax
    dex
  clearLoop:
    jsr plotCode.forLoop1[0].forLoop2[0].plot
    dex
    bpl clearLoop
  clearNotNeeded:
  }
  updateBoogie: {
    lda offset3
    clc
    adc speed: #boogiespeed
    cmp #boogielength
    bcc !+
      sbc #boogielength
    !:
    sta offset3
  }
  {
    // compensate offset for xOffsetRight
    ldx xOffsetRight
    sec
    sbc modOffset2x64,x
    bcs !+
    adc #64
  !:
    ldx xOffsetLeft
    ldx #0
    clc
    adc modOffset2x64,x
    cmp #64
    bcc !+
    sbc #64
  !:
    //tax
  }

  sta low
  lda amplitude
  clc
  adc #>sineWaves
  sta high

  // prepare disco swing. add into plotter later
  .for (var c=0; c<40; c++)
  { 
    ldy modOffset2x64+c
    lda (low),y
    sta plotFrame1.forLoop2[c].plotter+1  
  }

  jsr progressSines
  jsr calcYPos2

  // jump to the correct spot to move to the right
  // we have to decrease offset by 3*c
  // we have to decrease offset2 by 3*c
  ldx xOffsetRight
  lda plotFrame1StartLo,x
  sta jump
  lda plotFrame1StartHi,x
  sta jump+1

  // restore LDY in the speedcode
  lda #LDY_IMM
  sta restoreLDX: forLoop2[0].start

  lda #40
  sec
  sbc xOffsetLeft
  tax
  lda plotFrame1StartLo,x
  sta setRTS
  sta restoreLDX
  lda plotFrame1StartHi,x
  sta setRTS+1
  sta restoreLDX+1

  // set RTS in speedcode
  lda #RTS
  sta setRTS: forLoop2[0].start

  clc
  jsr jump: forLoop2[0].start

  // do we have to plot extra bars at the right?
  lda xOffsetLeft
  bne plotExtraBars
  
  // no
  rts
plotExtraBars:
  // yes.. extra bars coming up

  lda #40
  sec
  sbc xOffsetLeft
  tay

  lda #40
  sec
  sbc xOffsetLeft
  tax  // this is the X value for the first column

plotExtraLoop:
  // read address where to JSR to
  lda plotter1PositionsLo,x
  sta indirect
  lda plotter1PositionsHi,x
  sta indirect+1
  // read high byte
  lda indirect: $1000
  sta jsrAddress+1

  jsr jsrAddress: plotCode.forLoop1[0].forLoop2[0].plot
  inx
  cpx #40
  bcc plotExtraLoop
  rts

  forLoop2: .for (var c=0; c<40; c++)
  {
    start:

    ldy yPos: #0

    lda tab1,y
    sta plotFrame1.forLoop2[c].jsrAddress+1
    ldx tab2,y

    jsr jsrAddress: plotOffset0  // needs x, thrashes y
skipPlot:
    ldx #c                       // x = screen column. directly loading x is quicker than storing + restoring
    jsr plotter: $1080           // does not need y
  }
  noPlot:
  rts
}

* = * "[CODE] plotter positions"
plotter0PositionsLo:
.for (var i=0; i<40; i++) { .byte <(plotFrame0.forLoop2[i].plotter+1) }
.byte <plotFrame1.noPlot

plotter0PositionsHi:
.for (var i=0; i<40; i++) { .byte >(plotFrame0.forLoop2[i].plotter+1) }
.byte >plotFrame1.noPlot

plotter1PositionsLo:
.for (var i=0; i<40; i++) { .byte <(plotFrame1.forLoop2[i].plotter+1) }
.byte <plotFrame1.noPlot

plotter1PositionsHi:
.for (var i=0; i<40; i++) { .byte >(plotFrame1.forLoop2[i].plotter+1) }
.byte >plotFrame1.noPlot

progressSines:
{
  update1: {
    lda offset
    clc
    adc speed: #sin1speed
    and #$7f
    sta offset
  }
  {
    // compensate offset for xOffsetRight
    ldx xOffsetRight
    sec
    sbc modOffset1,x
    bcs !+
    adc #$80
  !:
    sta offset_modded
  }
  update2: {
    lda offset2
    clc
    adc speed: #sin2speed
    cmp #sin2length
    bcc !+
      sbc #sin2length
  !:
    sta offset2

    // compensate offset for xOffsetRight
    sec
    sbc modOffset2,x
    bcs !+
    adc #sin2length
  !:
    sta offset2_modded
  }

  // compensate for xOffsetLeft
  ldx xOffsetLeft
  ldx #0
  lda offset_modded
  clc
  adc modOffset1,x
  cmp #$80
  bcc !+
    sec
    sbc #$80
  !:
  sta offset_modded  

  // compensate for xOffsetLeft
  lda offset2_modded
  clc
  adc modOffset2,x
  cmp #sin2length
  bcc !+
    sec
    sbc #sin2length
  !:
  sta offset2_modded  
  rts
}

plotFrame0StartLo:
.for (var i=0; i<40; i++) { .byte <(plotFrame0.forLoop2[i].start) }
.byte <(plotFrame0.noPlot)

plotFrame0StartHi:
.for (var i=0; i<40; i++) { .byte >(plotFrame0.forLoop2[i].start) }
.byte >(plotFrame0.noPlot)

plotFrame1StartLo:
.for (var i=0; i<40; i++) { .byte <(plotFrame1.forLoop2[i].start) }
.byte <(plotFrame1.noPlot)

plotFrame1StartHi:
.for (var i=0; i<40; i++) { .byte >(plotFrame1.forLoop2[i].start) }
.byte >(plotFrame1.noPlot)

modOffset2x64:
.for (var i=0; i<40; i++) { .byte mod(boogieskip*i, boogielength) }
modOffset1:
.for (var i=0; i<40; i++) { .byte mod(sin1skip*i,   sin1length) }
modOffset2:
.for (var i=0; i<40; i++) { .byte mod(sin2skip*i,   sin2length) }

jumpTable:
  .byte >plotOffset0, >plotOffset1, >plotOffset2, >plotOffset3, >plotOffset4, >plotOffset5

.if ((>*) != (>(*+nrRows-1))) { .align $100 }
d018TableReversed:
.for (var s=0; s<nrRows; s++)
{
  .var s2 = nrRows-1-s
  .byte (((screens.get(s2)&$3fff)/$400)*16)+((charsets.get(0)&$3fff)/$800)*2
}

.if ((>*) != (>(*+nrRows-1))) { .align $100 }
d012TableReversed:
.for (var s=0; s<nrRows; s++)
{
  .var s2 = nrRows-1-s
  .byte $38+3+(s2*height)
}

.if ((>*) != (>(*+nrRows-1))) { .align $100 }
d011TableReversed:
.for (var s=0; s<nrRows; s++)
{
  .var s2 = nrRows-1-s
  .byte (($19+(s2*height)) & 7) | $18
}
endOfCode:




// empty screens
.for (var s=0; (s<nrRows) && (s<nrRows); s++)
{
  * = screens.get(s) "[DATA] screens" virtual
  .fill 80,0

  * = screens.get(s) + $3f8 "[DATA] spritepointer"
  .byte (spriteimage&$3fff)/64
}

.macro plotCode(offset, table)
{
  .if (offset == 0)
  {
    // plot offset 0 in table 0
    lda #waswordt_00.get(0)
    sta.zpx plotTables.get(table)+0,x

    lda #waswordt_10.get(0)               // this value is in the middle and is fixed
    sta.zpx plotTables.get(table)+1,x

    ldy plotTables.get(table)+2,x
    lda wasWordtAddress.get(whichWasWordt.get(2*height+0)),y
    sta.zpx plotTables.get(table)+2,x
  }
  .if (offset == 1)
  {
    ldy plotTables.get(table)+0,x
    lda wasWordtAddress.get(whichWasWordt.get(0*height+1)),y
    sta.zpx plotTables.get(table)+0,x

    lda #waswordt_11.get(0)               // this value is in the middle and is fixed
    sta.zpx plotTables.get(table)+1,x

    ldy plotTables.get(table)+2,x
    lda wasWordtAddress.get(whichWasWordt.get(2*height+1)),y
    sta.zpx plotTables.get(table)+2,x
  }
  .if (offset == 2)
  {
    ldy plotTables.get(table)+0,x
    lda wasWordtAddress.get(whichWasWordt.get(0*height+2)),y
    sta.zpx plotTables.get(table)+0,x

    lda #waswordt_12.get(0)               // this value is in the middle and is fixed
    sta.zpx plotTables.get(table)+1,x

    ldy plotTables.get(table)+2,x
    lda wasWordtAddress.get(whichWasWordt.get(2*height+2)),y
    sta.zpx plotTables.get(table)+2,x
  }
  .if (offset == 3)
  {
    ldy plotTables.get(table)+0,x
    lda wasWordtAddress.get(whichWasWordt.get(0*height+3)),y
    sta.zpx plotTables.get(table)+0,x

    lda #waswordt_13.get(0)               // this value is in the middle and is fixed
    sta.zpx plotTables.get(table)+1,x

    ldy plotTables.get(table)+2,x
    lda wasWordtAddress.get(whichWasWordt.get(2*height+3)),y
    sta.zpx plotTables.get(table)+2,x
  }
  .if (offset==4)
  {
    ldy plotTables.get(table)+0,x
    lda wasWordtAddress.get(whichWasWordt.get(0*height+4)),y
    sta.zpx plotTables.get(table)+0,x

    lda #waswordt_14.get(0)               // this value is in the middle and is fixed
    sta.zpx plotTables.get(table)+1,x

    ldy plotTables.get(table)+2,x
    lda wasWordtAddress.get(whichWasWordt.get(2*height+4)),y
    sta.zpx plotTables.get(table)+2,x
  }
  .if (offset==5)
  {
    ldy plotTables.get(table)+0,x
    lda wasWordtAddress.get(whichWasWordt.get(0*height+5)),y
    sta.zpx plotTables.get(table)+0,x

    lda #waswordt_15.get(0)               // this value is in the middle and is fixed
    sta.zpx plotTables.get(table)+1,x

    lda #waswordt_25.get(0)               // this is a fixed value also (bar completely at the bottom of a char)
    sta.zpx plotTables.get(table)+2,x  
  }
}

.macro plotCodep(offset, table)
{
  .if (offset == 0)
  {
    // plot offset 0 in table 0
    lda #waswordt_00p.get(0)
    sta.zpx plotTables.get(table)+0,x

    lda #waswordt_10p.get(0)               // this value is in the middle and is fixed
    sta.zpx plotTables.get(table)+1,x

    ldy plotTables.get(table)+2,x
    lda wasWordtAddressp.get(whichWasWordt.get(2*height+0)),y
    sta.zpx plotTables.get(table)+2,x
  }
  .if (offset == 1)
  {
    ldy plotTables.get(table)+0,x
    lda wasWordtAddressp.get(whichWasWordt.get(0*height+1)),y
    sta.zpx plotTables.get(table)+0,x

    lda #waswordt_11p.get(0)               // this value is in the middle and is fixed
    sta.zpx plotTables.get(table)+1,x

    ldy plotTables.get(table)+2,x
    lda wasWordtAddressp.get(whichWasWordt.get(2*height+1)),y
    sta.zpx plotTables.get(table)+2,x
  }
  .if (offset == 2)
  {
    ldy plotTables.get(table)+0,x
    lda wasWordtAddressp.get(whichWasWordt.get(0*height+2)),y
    sta.zpx plotTables.get(table)+0,x

    lda #waswordt_12p.get(0)               // this value is in the middle and is fixed
    sta.zpx plotTables.get(table)+1,x

    ldy plotTables.get(table)+2,x
    lda wasWordtAddressp.get(whichWasWordt.get(2*height+2)),y
    sta.zpx plotTables.get(table)+2,x
  }
  .if (offset == 3)
  {
    ldy plotTables.get(table)+0,x
    lda wasWordtAddressp.get(whichWasWordt.get(0*height+3)),y
    sta.zpx plotTables.get(table)+0,x

    lda #waswordt_13p.get(0)               // this value is in the middle and is fixed
    sta.zpx plotTables.get(table)+1,x

    ldy plotTables.get(table)+2,x
    lda wasWordtAddressp.get(whichWasWordt.get(2*height+3)),y
    sta.zpx plotTables.get(table)+2,x
  }
  .if (offset==4)
  {
    ldy plotTables.get(table)+0,x
    lda wasWordtAddressp.get(whichWasWordt.get(0*height+4)),y
    sta.zpx plotTables.get(table)+0,x

    lda #waswordt_14p.get(0)               // this value is in the middle and is fixed
    sta.zpx plotTables.get(table)+1,x

    ldy plotTables.get(table)+2,x
    lda wasWordtAddressp.get(whichWasWordt.get(2*height+4)),y
    sta.zpx plotTables.get(table)+2,x
  }
  .if (offset==5)
  {
    ldy plotTables.get(table)+0,x
    lda wasWordtAddressp.get(whichWasWordt.get(0*height+5)),y
    sta.zpx plotTables.get(table)+0,x

    lda #waswordt_15p.get(0)               // this value is in the middle and is fixed
    sta.zpx plotTables.get(table)+1,x

    lda #waswordt_25p.get(0)               // this is a fixed value also (bar completely at the bottom of a char)
    sta.zpx plotTables.get(table)+2,x  
  }
}

.var plotColumnPages = List()  // we can add the code for plotting a column in the same page
* = getPage() "[CODE] plot offset 0"
.eval plotColumnPages.add(*)
plotOffset0:
{
  plotCode(0,0)
  plotCode(1,1)
  plotCode(2,2)
  plotCode(3,3)
  plotCode(4,4)
  plotCode(5,5)
  rts
}

* = getPage() "[CODE] plot offset 1"
.eval plotColumnPages.add(*)
plotOffset1:
{
  plotCode(1,0)
  plotCode(2,1)
  plotCode(3,2)
  plotCode(4,3)
  plotCode(5,4)
  inx
  plotCode(0,5)
  rts
}

* = getPage() "[CODE] plot offset 2"
.eval plotColumnPages.add(*)
plotOffset2:
{
  plotCode(2,0)
  plotCode(3,1)
  plotCode(4,2)
  plotCode(5,3)
  inx
  plotCode(0,4)
  plotCode(1,5)
  rts
}

* = getPage() "[CODE] plot offset 3"
.eval plotColumnPages.add(*)
plotOffset3:
{
  plotCode(3,0)
  plotCode(4,1)
  plotCode(5,2)
  inx
  plotCode(0,3)
  plotCode(1,4)
  plotCode(2,5)
  rts
}

* = getPage() "[CODE] plot offset 4"
.eval plotColumnPages.add(*)
plotOffset4:
{
  plotCode(4,0)
  plotCode(5,1)
  inx
  plotCode(0,2)
  plotCode(1,3)
  plotCode(2,4)
  plotCode(3,5)
  rts
}

* = getPage() "[CODE] plot offset 5"
.eval plotColumnPages.add(*)
plotOffset5:
{
  plotCode(5,0)
  inx
  plotCode(0,1)
  plotCode(1,2)
  plotCode(2,3)
  plotCode(3,4)
  plotCode(4,5)
  rts
}

* = getPage() "[CODE] plot offset 0p"
.eval plotColumnPages.add(*)
plotOffset0p:
{
  plotCodep(0,0)
  plotCodep(1,1)
  plotCodep(2,2)
  plotCodep(3,3)
  plotCodep(4,4)
 plotCodep(5,5)
  rts
}

* = getPage() "[CODE] plot offset 1p"
.eval plotColumnPages.add(*)
plotOffset1p:
{
  plotCodep(1,0)
  plotCodep(2,1)
  plotCodep(3,2)
  plotCodep(4,3)
  plotCodep(5,4)
  inx
  plotCodep(0,5)
  rts
}

* = getPage() "[CODE] plot offset 2p"
.eval plotColumnPages.add(*)
plotOffset2p:
{
  plotCodep(2,0)
  plotCodep(3,1)
  plotCodep(4,2)
  plotCodep(5,3)
  inx
  plotCodep(0,4)
  plotCodep(1,5)
  rts
}

* = getPage() "[CODE] plot offset 3p"
.eval plotColumnPages.add(*)
plotOffset3p:
{
  plotCodep(3,0)
  plotCodep(4,1)
  plotCodep(5,2)
  inx
  plotCodep(0,3)
  plotCodep(1,4)
  plotCodep(2,5)
  rts
}

* = getPage() "[CODE] plot offset 4p"
.eval plotColumnPages.add(*)
plotOffset4p:
{
  plotCodep(4,0)
  plotCodep(5,1)
  inx
  plotCodep(0,2)
  plotCodep(1,3)
  plotCodep(2,4)
  plotCodep(3,5)
  rts
}

* = getPage() "[CODE] plot offset 5p"
.eval plotColumnPages.add(*)
plotOffset5p:
{
  plotCodep(5,0)
  inx
  plotCodep(0,1)
  plotCodep(1,2)
  plotCodep(2,3)
  plotCodep(3,4)
  plotCodep(4,5)
  rts
}

// -------------------------------------------------
// here we generate the code to plot all the columns
// -------------------------------------------------

// macro to generate all the plotters
.macro genPlotColumn(offset, yOffset)
{
  .var data = plotTables.get(offset) // get what data column to plot

  .for (var r=0; r<nrRows; r++)      // loop over all the rows to plot
  {
    lda data+r+yOffset
    sta screens.get(r),x
  }
  rts
}

// generate all plotters
.var usedPlotterPage = 0

plotCode:
{
  forLoop1: .for (var y=0; y<3; y++)
  {
    forLoop2: .for (var i=0; i<height; i++)
    {
      .if (usedPlotterPage < plotColumnPages.size())
      {
        // first, fit the code into the same pages as the offset plotters
        * = plotColumnPages.get(usedPlotterPage)+$80 "[CODE] plotter"
        .eval usedPlotterPage++
      }
      else
      {
        // if there are no more pages, continue using normal empty pages
        * = getPage()+$80 "[CODE] plotter"
      }

      plot:
      {
        .eval plotters.add(*) // store PC into list of plotters
        genPlotColumn(i, y)
      }
    }
  }
}

// select what plotOffset code to use, depending on the offset in the char
* = getPage() "[DATA] y modulo height"
.var OffsetToJump  = List().add(>plotOffset0,  >plotOffset1,  >plotOffset2,  >plotOffset3,  >plotOffset4,  >plotOffset5)

tab1:
.for (var i=0; i<248; i++)
{
  .byte OffsetToJump.get(mod(i/2,height))
}

* = getPage() "[DATA] y modulo height pills"
.var OffsetToJumpp = List().add(>plotOffset0p, >plotOffset1p, >plotOffset2p, >plotOffset3p, >plotOffset4p, >plotOffset5p)

tab1p:
.for (var i=0; i<248; i++)
{
  .byte OffsetToJumpp.get(mod(i/2,height))
}

* = getPage() "[DATA] y / height"
tab2:
.for (var i=0; i<248; i++)
{
  .byte floor(i/2/height)
}

.print (movement)
.print (movement.size())

* = getPage() "[DATA] movement d016"
movementD016:
{
  .fill movement.size(), (movement.get(i) & 7) | $d8
}

* = * "[DATA] movement chars"
movementChars:
{
  .fill movement.size(), floor(movement.get(i) / 8)
}

* = getPage() "[DATA] movement2 d016"
movement2D016:
{
  .fill movement2.size(), (movement2.get(i) & 7) | $d8
}

* = * "[DATA] movement2 chars"
movement2Chars:
{
  .fill movement2.size(), floor(movement2.get(i) / 8)
}

* = getPage() "[DATA] sinewave to plotter"
// if we add 2 sines, the max value that we can get is 2*sinMax. this table converts these values into the correct plotter
sineWaveToPlotter:
{
  .var sinMax = $20
  .var maxFloor = floor((sinMax/2)/height)

  .for (var i=0; i<=sinMax; i++)
  {
    .var j = floor(i/2)
    .var floorValue = maxFloor - floor(j /height)
    .var modValue   =              mod(j, height)
    .var value = modValue + floorValue*height

    .byte >(plotters.get(value))
  }
}

* = endOfCode "[MARKER] end of code"

* = sineWaves "[DATA] sinewaves"
{
  .var maxFloor = floor($10/height)
  
  .for (var amplitude=0; amplitude<=$10; amplitude++)
  {
    .var sinMin    = round(8 - (amplitude/2))
    .var sinMax    = round(8 + (amplitude/2))
    .var sinLength = 64
    .var sinAmp    = 0.5 * (sinMax-sinMin)

    .for (var i=0; i<256; i++)
    {
      .var floorValue = maxFloor - floor(((sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength)))/height)
      .var modValue   =              mod(((sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength))), height)
      .var value = modValue + floorValue*height
      .byte >(plotters.get(value))
    }
  }
}

* = $76c0 "[GFX] sprite"
spriteimage:
//.fill sprite.size(),sprite.get(i)

* = $7fff "[GHOSTBYTE]"
.byte 0

// inherit the charset in spindle
#if AS_SPINDLE_PART
  * = charsetLogo "[GFX] charset for logo" virtual
  .fill uniqueChars.size(), uniqueChars.get(i)
#else
  * = charsetLogo "[GFX] charset for logo"
  .fill uniqueChars.size(), uniqueChars.get(i)
#endif

* = charsetScreen "[GFX] screen for logo"
.fill max(screenData.size(),1000), screenData.get(i)

// in standalone, fill the handover charset and screen
#if !AS_SPINDLE_PART
  * = handOverCharset "[GFX] handover charset"
    .fill uniqueChars.size(), uniqueChars.get(i)

  * = handOverScreen "[GFX] handover screen"
    .for (var row=0; row<25; row++)
    {
      .var row2 = row-12
      .if (row2 < 0) 
      {
        .fill 40, 0
      }
      else
      {
        .fill 40, screenData.get(row2*40+i)
      }
    }
#endif
