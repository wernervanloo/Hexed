#import "../00.music/music2.asm"
#import "functions.asm"
#import "drawcircle.asm"

.const noScreen = List(); .for (var i=0; i<1000; i++) { .eval noScreen.add(-1) }

// these are the demo spanning 0 page adresses
// do not declare them in the Spindle header..

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

.label firstZP = $30
.label in      = $30
.label out     = $32
.label lastZP  = $33

.macro keepTime() { inc timelow; bne *+4; inc timehigh }

.label screen    = $4c00
.label firstByte = $5000
.label charset   = $5000

#if AS_SPINDLE_PART
  .label spindleLoadAddress = firstByte
  *=spindleLoadAddress-18-13-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word prepare       // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word 0             // cleanup routine
    .word music_play    // location of playroutine call

    .byte 'S'           // declare safe loading under IO
    .byte 'Z', <firstZP, <lastZP
    .byte 'P', >screen,  >(screen+$3ff)
    .byte 'I', >$3800,   >(screen-1)  // disable loading these blocks
    .byte 'I', >$8200,   >$baff  // disable loading these blocks

    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2($080e); sei; lda #$35; sta $01; jmp start
#endif

.var circleSizes       = List().add( 2, 4, 6, 8,10,11,12,13,14,15,17,19,21,23,25,28,31,34,37,41,45,50,55,61,67,74,81,89,98,108,119,131,144,158,174,191)            // all the circle sizes
.var colors            = List().add($0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$6,$9,$2,$b,$4,$8,$e,$c, $5, $a, $3, $f, $7, $d, $1, $1)

.var nrFrames = circleSizes.size()                                                     // # of animation frames

.var currentCharset    = List().add(0,0,0,0,0,0,0,0, $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff)  // an new charset with only the empty and filled char
.var charsets          = List()    // all charsets
.var compressedScreens = List()    // list with all the compressed screen datas
.var screens           = List()
.var usedCharset       = List()    // store what charset to use for each screen
.var currentScreen     = noScreen  // remember the previous screen for delta compression
.var bitmap            = List(); .for (var i=0; i<40*200; i++) { .eval bitmap.add(0) }

.for (var i=0; i<circleSizes.size(); i++)
{
  .var circleSize = circleSizes.get(i)             // read the next size circle

  .var charsetAndScreen = testDraw(bitmap, circleSize) // generate charset and screen
  .var charsetData = charsetAndScreen.get(0)       // get charset
  .var screenData  = charsetAndScreen.get(1)       // get screen
  .eval bitmap     = charsetAndScreen.get(2)       // get bitmap back..

  .var newChars = (charsetData.size()-16)/8        // calculate # of chars in the charset (except the empty and filled char)
  .var oldChars = currentCharset.size()/8          // # of chars in the current charset

  // check if the extra chars fit in the current charset
  .var totalChars = oldChars + newChars

  .var testCharset = List().addAll(currentCharset)
  .eval testCharset.addAll(charsetData)

  // it doesn't fit.. store the old charset and make a new one
  .if (countUnique(testCharset) > 256)
  {
    .eval charsets.add(currentCharset)
    
    .eval currentCharset = List().add(0,0,0,0,0,0,0,0, $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff)
    .eval oldChars       = 2
  }

  // add the new chars to the charsets
  .var currentCharsetScreen = addScreen(currentCharset, charsetData, screenData)
  .eval currentCharset = currentCharsetScreen.get(0)
  .eval screenData = currentCharsetScreen.get(1)

  // do a check : how many chars and how many unique chars?
  //.print ("chars in charset : " + currentCharset.size()/8)
  //.print ("unique chars     : " + countUnique(currentCharset))

  // update screen
  .eval screens.add(screenData)

  // compress screen (delta with old screen)
  .var compressedScreen = deltaCompress(screenData, currentScreen)
  .eval compressedScreens.add(compressedScreen)

  // store new screen for delta compression
  .eval currentScreen = screenData
 
  // store what charset to use for this screen
  .eval usedCharset.add(charsets.size())

  // chars needed
  //.print ("size : " + circleSize + ", chars : " + newChars + ", compressed screen size : " + compressedScreen.size())

  // if this is the last frame, store the charset
  .if (i==circleSizes.size()-1)
  {
    .eval charsets.add(currentCharset)
  }
}

// dump charsets into the memory
.for (var i=0; i<charsets.size(); i++)
{
  * = charset+i*$800 "[GFX] charsets"

  .var data = charsets.get(i)
  .fill data.size(), data.get(i)
}

* = * "[DATA] compressed screen data"
compressedScreenData:
{
  data:
  .for (var i=0; i<compressedScreens.size(); i++)
  {
    start:
    .var data = compressedScreens.get(i)
    .fill data.size(), data.get(i)
  }
}

* = * "[DATA] position of compressed screen data"
compressedPositionsLo: .for (var i=0; i<compressedScreens.size(); i++) { .byte <(compressedScreenData.data[i].start) }
compressedPositionsHi: .for (var i=0; i<compressedScreens.size(); i++) { .byte >(compressedScreenData.data[i].start) }

* = * "[CODE]"
start:
{
  sei

  lda #$35
  sta $01

  lda #$7f   // disable nmi
  sta $dd0d

  ldx nextpart
  inx
  stx irq.nextPartValue

  #if !AS_SPINDLE_PART
    lda #DARK_GREY
    sta $d020
    lda #BLACK
    sta $d021
  #endif

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  #if !AS_SPINDLE_PART
    jsr prepare
    :MusicInitCall()
  #endif

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$f9
  sta $d012

  lda $d011
  and #$7f
  sta $d011

  lda #$00
  sta $d015
  
  lda $dc0d
  lda $dd0d
  asl $d019

  lda #$02
  sta $d018
  
  #if !AS_SPINDLE_PART
    lda #$94
    sta $dd00
  #endif

  lda #$3d
  sta $dd02

  cli

  // recolor screen

  ldx #0
  lda #WHITE
  {
  loop:
    .for (var i=0; i<4; i++)
    {
      sta $d800+i*256,x
    }
    inx
    bne loop
  }

  #if !AS_SPINDLE_PART
loop:
    jmp loop
  #else
    rts
  #endif
}

prepare:
{
  lda #<compressedScreenData
  sta in
  lda #>compressedScreenData+1
  sta in+1

  jmp deltaDecompress
}

topIrq:
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

  ldx irq.frame
  lda colorTable,x
  sta $d021
  // do not write $0,$06,$09 to $d020
  beq skipD020
  cmp #$06
  beq skipD020
  cmp #$09
  beq skipD020
    sta $d020
skipD020:

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$f9
  sta $d012

  asl $d019
}
endIrq:
{

  pla
  sta $01
  pla
  tay
  pla
  tax
  pla
  rti
}

whichCharset:
  .for (var i=0; i<usedCharset.size(); i++)
  {
    .var address = usedCharset.get(i)*$800 + charset
    .var d018    = (address&$3800)/$800*2 + (screen&$3c00)/$400*$10
    .byte d018
  }

//* = $7fff "[GFX] ghostbyte"
//  .byte 0

//* = * "[CODE] rest of code"

* = $7fff-20 "[DATA] colortable + ghostbyte"
colorTable:
  .fill colors.size(), colors.get(i)

* = * "[CODE] rest of code"

irq:
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

  // keep border open
  lda #$13
  sta $d011

  keepTime()

  :MusicPlayCall()
 
  // reset border
  lda #$1b
  sta $d011

  lda #<topIrq
  sta $fffe
  lda #>topIrq
  sta $ffff
  lda #$00
  sta $d012

  ldx frame: #0
  cpx #nrFrames
  bcc !+
    // allow to go to the next part
    lda nextPartValue: #0
    sta nextpart

    #if AS_SPINDLE_PART
      asl $d019
      jmp skipAnim
    #else
      lda #DARK_GREY
      sta $d020

      ldx #0
      stx frame
    #endif
  !:

  lda compressedPositionsLo,x
  sta in
  lda compressedPositionsHi,x
  sta in+1

  lda whichCharset,x
  sta $d018

  inc frame

  asl $d019
  cli
  jsr deltaDecompress
skipAnim:
  jmp endIrq
}

deltaDecompress:
{
  lda #<screen
  sta out
  lda #>screen
  sta out+1

  clc
loop:
  ldy #0
  lax (in),y        // fetch the next code
  bmi flushLiterals
  beq end           // 0 = end of data
copyEqual:
  // do we have to skip bytes?
  cmp #1
  clc
  bne noSkip

  iny
  lax (in),y        // read # of bytes to skip in x
  dey               // make y 0
  bcc endEqualLoop  // advance to the next input token
  
noSkip:
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
//.align $100
endPart:

* = screen "[USE] screen" virtual
.fill 1000,0