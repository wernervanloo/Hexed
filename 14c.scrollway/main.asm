.const debug   = 0
.const verbose = 0
.const switch  = 11  // switch after 11 rows

#import "functions.asm"
#import "scrolltext.asm"
#import "../00.music/music2.asm"

                                            // bitpairs  $d021-3, $d022-b, $d023-7, $d800-1
.var logoTop    = LoadPicture("./includes/top.png",    List().add($70A4B2, $444444, $B8C76F, $FFFFFF))
.var logoBottom = LoadPicture("./includes/bottom.png", List().add($70A4B2, $444444, $B8C76F, $FFFFFF))


// update 1: (DONE!)
// observation : if the buffer is an (integer) multiple of the height of a font
// the empty lines will always be at the same location and we do not have to write them

// update2: (DONE)
// observation : the plotter takes the least amount of rasterlines when it has to plot
// the most empty lines at the bottom of the screen
// this is when we want to update to the next screen row to make rastertime use more stable

// update3: (DONE, except for a ROR/ROL)
// if we have an y difference of 2, we could write the values into the plotter
// example : 
// row 40, yoffset 30
// row 41, yoffset 32
// -> first execute code for row 40 (normally row 41 is executed first)
// row 40 has special code :
// lda #x (lsr / asl) sta $xxxx
// then execute row 41. which stores the data also to the lda #x values of the plotter
// two frames later the code for row 40 will write it to the screen, like it should be

.const border      = CYAN
.const background  = CYAN

// raistlin used 11232 bytes for the font (11060 with padding to align = 11232)
// update : 77*101 bytes = 7777 bytes (unoptimized font)
// update : 74*101 bytes =  bytes (unoptimized font)
// finally : 5834 bytes

// defines for the font
// --------------------

.const fontWidth     = 14    // the width of each character in pixels
.const fontGap       = 2     // pixel gap between two characters. a gap of 2 is nice. when zoomed to 50% it is still 1 pixel
.const fontHeight    = 14
.const fontEmpty     = 7
.const charsInFont   = 42    // empty + a-z + 0123456789!.- ?,

.var bufferLength = (fontHeight+fontEmpty) * floor(128/(fontHeight+fontEmpty))  // calculate optimal bufferlength

// -------------------------
// load and convert the logo
// -------------------------

#import "convert_logo.asm"  // outputs uniqueChars and screenData

.var logo1 = convertPicture(logoTop)
.var charset1 = logo1.get(0)
.var screen1  = logo1.get(1)

.var logo2 = convertPicture(logoBottom)
.var charset2 = logo2.get(0)
.var screen2  = logo2.get(1)

// -------------------------
// load and convert the font
// -------------------------

.var fontGfx = LoadPicture("./includes/font starwars v0.4.png", List().add($000000, $ffffff))

.var gfxWidth  = fontGfx.width
.var gfxHeight = fontGfx.height

.var fontNrChars = gfxWidth /(fontWidth+fontGap)

.var allFontRows = List() // a list with all the different rows found in the font
.var fontData    = List() // a list of all characters in the font with pointers to the rows

.for (var c=0; c<charsInFont; c++)
{
  .var startX = c*(fontWidth+fontGap)/8  // start X position (in bytes)

  .for (var Y=0; Y<fontHeight; Y++)
  {
    // this is the value for this row
    .var value = 0
    .for (var X=0; X<((fontWidth+fontGap)/8); X++)
    {
      .eval value = (value << 8) + fontGfx.getSinglecolorByte(startX+X,Y)
    }

    //.eval value = %1111111111111100

    // is this a new row?
    .var rowNr = exists(allFontRows, value)
    .if (rowNr == -1)
    {
      .eval fontData.add(allFontRows.size()) // store pointer to the new row
      .eval allFontRows.add(value)           // add row to list
    } else {
      .eval fontData.add(rowNr)              // add row to list
    }
  }

  .print ("after adding char " + c + ", the converter has seen " + allFontRows.size() + " unique bytes")
}

// add empty row to fontData
.for (var r=0; r<fontHeight; r++)
{
  .eval fontData.add($81)
}

.print("all different rows in the font: "+allFontRows.size())
.print(allFontRows)

// defines for the scroller
// ------------------------

.const height        = 11*8            // nr pixels high
.const width_top     = 18*8+2          // pixels wide at the top
.const width_bottom  = 40*8            // pixels wide at the bottom
.const scrollColumns = 20              // the width of the upscroll in characters
.const rows          = ceil(height/8)  // number of charrows 
.const scrollPixels  = scrollColumns*(fontWidth+fontGap) // total width in pixels
.const moveDown      = floor((200-height)/8)             // move down number of rows

// note : 
// chars are 14 pixels wide and 16 pixels high, between chars there are 2 empty pixels
// the empty space is not included in the chars themselves to use less different bytes (probably..)
// total width in pixels = 20 charcolumns * 16 pixels = 320

// defines for memory positions
// ----------------------------

.label firstZP       = $f3
  .label frame         = $f3
.label lastZP        = $f3

.label screen             = $0400      // final position of screenmap

.label charset1a          = $2000      // top charsets for frame 1
.label charset2a          = $2800      // top charsets for frame 2

.label firstByte          = $3000
.label scrollTextOriginal = $3000      // original position of scrolltext
.label charset1b          = $3000      // bottom charsets for frame 1
.label charset2b          = $3800      // bottom charsets for frame 2
.label screenOri          = $3800      // original position of screenmap in standalone mode

.label fontBytes          = $3e00
.label scrollBuffer       = $e100      // $1400-$400 ($400 is distributed over the memory)
.label scrollText         = $e200      // final position of scrolltext
.label scrollBuffer2      = $ea00      // virtual scrollbuffers
.label logoScreen         = $f400
.label logoCharset        = $f800

.var  scrollBuffers = List().add( scrollBuffer      , scrollBuffer2+$000, scrollBuffer2+$100, scrollBuffer2+$200)
.eval scrollBuffers.add(          scrollBuffer2+$300, scrollBuffer2+$400, scrollBuffer2+$500, scrollBuffer2+$600)
.eval scrollBuffers.add(          scrollBuffer2+$700, scrollBuffer2+$800,               $200,               $300) // kill spindle anyway..
.eval scrollBuffers.add(                        $800,               $900,               $a00,               $b00)
.eval scrollBuffers.add(             logoScreen+$200,    logoScreen+$300,     charset1b+$600,     charset1b+$700)

#if AS_SPINDLE_PART
  .label spindleLoadAddress = firstByte
  *=spindleLoadAddress-18-15-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"             // fileformat magic
    .word prepare            // prepare routine
    .word start              // setup routine
    .word 0                  // irq handler
    .word 0                  // main routine
    .word 0                  // fadeout routine
    .word 0                  // cleanup routine
    .word music_play         // location of playroutine call

    .byte 'Z', <firstZP,    <lastZP
    .byte 'I', >screen, >(screen+$3ff)               // inherit top part of picture from heaven, we will write over it later.
    .byte 'I', >charset1a, >(charset2a+$7ff)         // inherit top part of picture from heaven
    .byte 'I', >logoScreen, >(logoCharset+$7ff)      // inherit top part of picture from switch
    .byte 'P', >scrollBuffer, >(scrollBuffer+$fff)   // we will occupy the scrollbuffer in prepare

    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#else    
    :BasicUpstart2(start); jmp start
#endif


// -----------------------------------------------------------------------
// first we calculate the width at each row and the resulting charmap.   -
// we use charsets instead of bitmap to save memory and to double buffer -
// since it is double buffered, we need to save as much mem as we can..  -
// -----------------------------------------------------------------------

.var nrChars        = List() // nr of chars needed for each row
.var rowCharset     = List() // what charset for each row?
.var widths         = List() // the width of each line
.var charMap        = List() // charmap to put on screen
.var emptyChars     = List() // keep track of the 'empty' char in each charset
.var rowsPerCharset = List() // how many rows per charset
.var firstRaster    = List() // first raster for each charset

.var charsetSwap = 0
.var totalChars  = 2 // one empty char per charset
.var totalChars1 = 2 // chars used in charset 1
.var totalChars2 = 2 // chars used in charset 2
.var nrCharsets  = 1

genCharMap:
{
  .for (var x=0; x<40*moveDown; x++) 
  { 
    .eval charMap.add(-1) 
  } // move rows down

  .var firstChar  = 2       // start at the first char
  .var charset    = 0       // start at charset 0
  .eval firstRaster.add(0)

  .for (var raster=0; raster<height; raster++)
  {
    // calculate width and store it
    .var  width = (raster*(width_bottom-width_top)/(height-1)) + width_top
    .eval width = 2*round(width/2)
    .eval widths.add(width)

    // calculate nr of chars needed for each row
    .if (mod(raster,8)==7)
    {
      .var charRow = floor(raster/8)

      .var  chars  = (width/2)     // number of pixels on the left side of the screen
      .eval chars  = ceil(chars/8) // number of chars needed on the left side of the screen
      .eval chars  = 2*chars       // total number of chars

      // does it still fit inside the charset?
      // update : go to the 2nd charset early, so we free up chars in the top charset so we can add gfx
      .if (((firstChar+chars)>256) || (charRow==6))
      {
        .eval charsetSwap = charRow  // mark at what row to swap charset
        
        // jump to next charset
        .eval firstChar  = 2
        .eval charset    = charset+1
        .eval nrCharsets = charset+1
        .eval firstRaster.add(raster&$f8)
      }

      .eval nrChars.add(chars)             // keep track of # of chars in each row
      .eval rowCharset.add(charset)        // keep track of the charset for each row

      // add data to charmap
      .for (var c=0; c<(20-(chars/2)); c++) { .eval charMap.add(-1) }           // add empty chars on the left
      .for (var c=0; c<chars;          c++) { .eval charMap.add(firstChar+c) }  // add chars
      .for (var c=0; c<(20-(chars/2)); c++) { .eval charMap.add(-1) }           // add empty chars on the right

      .eval totalChars = totalChars+chars  // keep track of total amount of chars

      // keep track of total amount of chars used per charset
      .if (charset==0) { .eval totalChars1 = totalChars1+chars }
      .if (charset==1) { .eval totalChars2 = totalChars2+chars }

      .eval firstChar = firstChar + chars  // calculate next available char
    }
  }
}

.print("firstRaster : "+ firstRaster)


// ----------------------------------------------
// previously the chars were ordered in each row,
// now we will order them in columns instead..
// ----------------------------------------------

.var charMap2 = List()
.for (var i=0; i<40*25; i++) { .eval charMap2.add(-1) }  // empty charmap

.print ("nrCharsets : " + nrCharsets)
// we have to process the charmap per charset, so loop over the charsets
.for (var charset=0; charset<nrCharsets; charset++)
{
  .print ("analyzing charset " + charset)
  // how many rows for this charset?
  .var nrRows = 0       // total nr of rows that uses this charset
  .var firstRow = 99    // the first row that uses this charset
  .for (var i=0; i<rowCharset.size(); i++) 
  { 
    .if(charset==rowCharset.get(i)) 
    { 
      .eval nrRows++ 
      .eval firstRow = min(firstRow, i)
    } 
  }
  .eval rowsPerCharset.add(nrRows) // remember number of rows for each charset

  .var currentChar = 1  // the current char being plotted into the charmap, start at char 2
  .if (charset==0) { .eval currentChar = charset2.size()/8 }

  // scan the rows from the top
  .for (var charRow=firstRow; charRow<firstRow+nrRows; charRow++)
  {
    .var thisRow = charRow + moveDown // calculate row in the map

    // scan the row 
    .for (var c=0; c<40; c++)
    {
      // if a char goes here, but it is still empty in the target map, then write a column of chars
      .if ((charMap.get(thisRow*40+c)>=0) && (charMap2.get(thisRow*40+c)==-1))
      {
        // loop over the rest of the column
        .for (var j=charRow; j<firstRow+nrRows; j++)
        {
          .var targetRow = j + moveDown
          .eval charMap2.set(targetRow*40+c, currentChar)
          .eval currentChar++
        }
      }
    }
  }

  // remember the empty char
  .eval emptyChars.add(currentChar)

  // scan the rows from the top and write empty chars
  .for (var charRow=firstRow; charRow<firstRow+nrRows; charRow++)
  {
    .var thisRow = charRow + moveDown
    .for (var c=0; c<40; c++)
    {
      // replace char with empty char
      .if (charMap2.get(thisRow*40 + c) == -1) { .eval charMap2.set(thisRow*40+c, 0) } //currentChar) }
    }
  }
}

// copy charMap2 to charMap
.eval charMap=List().addAll(charMap2)
.print ("")

// ------------------------------------------------------
// generate the ultimate clear speedcode for each charset
// ------------------------------------------------------

.macro genUltimateSpeedCode(charset, frame)
{
  .print ("")
  .print ("generate speedcode for frame : " + frame + " and charset " + charset)

  // number of rows for this charset
  .var nrRows = rowsPerCharset.get(charset)

  // determine what charsets to plot to
  .var charsets  = List().add(charset1a, charset1b) // charsets for this frame

  // if we are plotting for the other frame, update accordingly..
  .if (frame == 1)
  {
    .eval charsets  = List().add(charset2a, charset2b) // charsets for this frame
  }

  // find the widest row for this charset
  .var widestRow   = 0
  .var widestWidth = 0

  .for (var charRow=0; charRow<rows; charRow++)
  {
    .if (rowCharset.get(charRow)==charset)
    {
      .if (nrChars.get(charRow) >= widestWidth)
      {
        .eval widestWidth = nrChars.get(charRow)
        .eval widestRow = charRow
      }
    }
  }

  .print ("charset " + charset + ", widest row=" + widestRow)

  // now generate the speedCode
  .var rowData = List()      // list with all the chars in the widest row
  .for (var c=0; c<40; c++) { .eval rowData.add(charMap.get(c+((widestRow+moveDown)*40))) }
  .print (rowData)

  .var width = 0

  // --------------------------------------------------------------------
  // start from the middle and then go out. this way we can jump over   -
  // the outermost columns when they don't have to be cleared           -
  // --------------------------------------------------------------------

  .for (var i=0; i<20; i++)
  {
    // left side
    .if (rowData.get(i) != emptyChars.get(charset))
    {
      sta charsets.get(charset)+(rowData.get(i)-(nrRows-1))*8,x
      .eval width++
    }

    // right side
    .if (rowData.get(39-i) != emptyChars.get(charset))
    {
      sta charsets.get(charset)+(rowData.get(39-i)-(nrRows-1))*8,x
      .eval width++
    }
  }

  .eval ultimateSpeedWidth.set(charset, width)
  rts
}

.print (charMap)
//.print (charMap2)

.print("")
.print("all different widths: ")
.print(widths)

// print debug info about charmap
// ------------------------------

.print("number of chars         : " + totalChars)
.print("number of chars per row : " + nrChars)
.print("charset of each row     : " + rowCharset)

.var charsPerCharset = List(); .for(var i=0; i<nrCharsets; i++) { .eval charsPerCharset.add(1) }
// count chars per charset:
.for (var row=0; row<rows; row++)
{
  .var nr  = nrChars.get(row)     // get # of chars for this row
  .var set = rowCharset.get(row)  // get the charset
  .eval charsPerCharset.set(set, charsPerCharset.get(set) + nr)
}
.print("chars per charset   :" + charsPerCharset)

// --------------------------------------------
// now we generate the y offset for each line -
// --------------------------------------------

.var yOffsets = List()
genYOffsets:
{
  .for (var raster=0; raster<height; raster++)
  {
    .var ZValue = 0.6 + (((raster) / (height)) * 0.32) // was 0.4
    .var yLookupPos = 320 - round(192 / ZValue)

    .eval yOffsets.add(yLookupPos)
  }
}

// hand optimized table..
.eval yOffsets = List().add(
2,3,     //S
5,7,     //S
9,10,    //R
12,13,   //S
15,17,   //S
19,20,   //S
22,23,   //R
25,27,   //S
29,30,   //R 28-29
32,33,   //S
35,36,   //R
38,39,   //R
41,42,   //R
44,45,   //R
47,48,   //R 46-47
50,51,   //R 49-50
52,53,   //R
55,56,   //R
58,59,   //R 57-58
60,61,   //R
63,64,   //R 62-63
65,66,   //R
68,69,   //R 67-68 
70,71,   //R
72,73,   //R
75,76,   //R 74-75
77,78,   //R
79,80,   //R
81,82,   //R
83,84,   //R
85,86,   //R
87,88,   //R
89,90,   //R
91,92,   //R
93,94,   //R
95,96,   //R
97,98,   //R
99,100,  //R
101,102, //R
103,104, //R
105,106, //R
107,108, //R
109,110, //R
111,112  //C
)

.print ("")
.print ("y offsets")
.print (yOffsets)

// ---------------------------------------------------------------------
// now, let's check if we can update any lines using the line below it -
// ---------------------------------------------------------------------

.var ROLRORlines    = List()  // mark which lines we will update using ROR/ROL
.var tripleUseLines = List()
.var doubleUseLines = List()  // mark which lines we will use to update the line above using ROR/ROL
.var copyLines      = List()  // lines that can be copied in the same frame
.var nrROLRORlines  = 0

.function optimizeLines()
{
  // first clear all data
  .for (var i=0; i<height; i++)
  {
    .eval ROLRORlines.add(0)
    .eval doubleUseLines.add(0)
    .eval copyLines.add(0)
    .eval tripleUseLines.add(0)
  }

  .for (var raster=height-1; raster>0; raster--) // start from the bottom raster
  {
    // we will only use this line to update the one above using ROL/ROR if this line is NOT made using ROL/ROR
    .if (ROLRORlines.get(raster)==0)
    {
      .var yOffset  = yOffsets.get(raster)    // get the yOffset for this raster
      .var yOffset2 = yOffsets.get(raster-1)  // get the yOffset for the raster above
      .var yOffset3 = 255

      .if (raster>2)
      {
        .eval yOffset3 = yOffsets.get(raster-2)  // get the yOffset for the raster above
      }

      // is this a line that can be copied?
      .if (yOffset == yOffset2)
      {
        .eval copyLines.set(raster, 1)
        .eval ROLRORlines.set(raster-1, 2)
        .eval nrROLRORlines++

        // can we triple use this line?
        .if(yOffsets.get(raster) == yOffsets.get(raster-2)+1)
        {
          .eval ROLRORlines.set(raster-2, 1)
          .eval tripleUseLines.set(raster, 1)
          .eval nrROLRORlines++
        }
      }

      // can we reuse the line for the next frame?
      .if (yOffset == yOffset2+1)  // can we update the line above using ROL/ROR?
      {
        // YES!
        .eval ROLRORlines.set(raster-1, 1)    // mark the line above this one as ROL/ROR line
        .eval doubleUseLines.set(raster,1)    // mark this line as being used to generate a ROL/ROR line
        .eval nrROLRORlines++
      }
    }
  }
}

.eval optimizeLines()

.print("")
.print("copylines :" + copyLines)
.print("")
.print("ROL/ROR lines: " + nrROLRORlines)
.print(ROLRORlines)

// ------------------------------------------------------
// evil tweak for the y-offsets to use more ROLROR line -
// ------------------------------------------------------

.var evilTweak = 0

.if (evilTweak==1)
{
  .var blocked = List()
  .for (var i=0; i<yOffsets.size(); i++)
  {
    // if a line is a ROLROR line or is a line that is used to make a ROLROR line, we can't tweak it
    .var block = ROLRORlines.get(i) + doubleUseLines.get(i)
    .eval blocked.add(block)
  }

  .var tweakable = List()
  // determine if there are lines that can be tweaked
  .for (var i=0; i<yOffsets.size(); i++)
  {
    // can this line be tweaked?
    .var tweak = false

    .if ((i>0) && (i<(yOffsets.size()-1)))
    {
      .eval tweak = true
      .if ((yOffsets.get(i)-yOffsets.get(i-1)) != 2) { .eval tweak = false } // difference in yOffset must be 2
      .if ((yOffsets.get(i+1)-yOffsets.get(i)) != 2) { .eval tweak = false } // difference in yOffset must be 2
      .if (blocked.get(i+0)   > 0)                   { .eval tweak = false } // not blocked
      .if (blocked.get(i-1)   > 0)                   { .eval tweak = false } // not blocked
      .if (blocked.get(i+1)   > 0)                   { .eval tweak = false } // not blocked
      .if (tweakable.get(i-1) == true)               { .eval tweak = false } // line above not tweaked
    }

    .eval tweakable.add(tweak)
  }

  .print("")
  .print("tweakable : " + tweakable)

  // tweak lines
  .for (var i=0; i<yOffsets.size(); i++)
  {
    .if (tweakable.get(i))
    {
      .var offset = yOffsets.get(i)
      .eval yOffsets.set(i, offset+1)
    }
  }

  .print("")
  .print("yOffsets : " + yOffsets)


  // -------------------------------------------------------------------------------------
  // now, after tweaking, let's check if we can update any lines using the line below it -
  // -------------------------------------------------------------------------------------

  .eval ROLRORlines    = List()  // mark which lines we will update using ROR/ROL
  .eval doubleUseLines = List()  // mark which lines we will use to update the line above using ROR/ROL
  .eval tripleUseLines = List()
  .eval copyLines      = List()
  .eval nrROLRORlines  = 0

  // optimize again
  .eval optimizeLines()

  .print("")
  .print("ROL/ROR lines: " + nrROLRORlines)
  .print(ROLRORlines)
}

// -----------------------------------------------
// can we find lines we can plot using method 3? -
// -----------------------------------------------

.var specialLines = List()
.for (var i=0; i<yOffsets.size(); i++) { .eval specialLines.add(0) }

.for (var i=0; i<(yOffsets.size()-1); i++)
{
  // we can use method 3 if :
  // it's not a ROLROR line AND the line above is not a ROLROR line AND the difference in yOffset between this line and the line below is 2
  
  .var yOffset     = yOffsets.get(i)
  .var yOffsetNext = yOffsets.get(i+1)

  .if ((ROLRORlines.get(i)==0) && (ROLRORlines.get(i+1)==0) && (yOffsets.get(i)==(yOffsets.get(i+1)-2)))
  {
    .if (i==0)
    {
      .eval specialLines.set(i, 1)
      .if (verbose==1) { .print ("special line : " + i) }
    }
    else
    {
      .if ((specialLines.get(i-1)==0) && (ROLRORlines.get(i-1)==0))
      {
        .eval specialLines.set(i, 1)
        .if (verbose==1) { .print ("special line : " + i) }
      }
    }
  }
}

.if (verbose==1) { .print ("special lines " + specialLines) }

// --------------------------------------------------
// now we calculate how an unzoomed line looks like -
// the result gets stored in sourcePixels           -
// --------------------------------------------------

.var sourcePixels = List() // the original pixels 1:1 zoom
.var targetPixels = List() // what source pixel goes where in each raster

// fill sourcePixels
// 0-7 = pixel number in byte, 0 = leftmost pixel, 7 = rightmost pixel
// -1  = gap
// column*8 gets ORed to pixel number
// example : 0,1,2,3,4,5,6,7, 8,9,10,11,12,13,14,15, -1, -1

// -------------------------------------------------------------
// generate a table with where we can jump after skipping a line
// -------------------------------------------------------------

.var skipTo = List(); .for (var i=0; i<yOffsets.size(); i++) { .eval skipTo.add(0) }

.for (var i=0; i<yOffsets.size(); i++)
{
  // if this is the third empty row, what is the next line that needs to get plotted?
  .var yOffset      = yOffsets.get(i)    // read the current yOffset
  .var targetOffset = yOffset + fontEmpty - 2 - 1
  .var targetLine   = i

  // find in what line the offset equals or is bigger than the targetOffset

  // the plot looks like this
  // data
  // data
  //   next follow 7 empty lines
  // $80 -> clear line
  // $80 -> clear line
  // $c0 -> first line that can be skipped  <= what is the yoffset of this line?
  // $c0 -> to catch the next line
  // $81 -> 2nd line that can be skipped
  // $81 -> ...
  // $81 ->
  // $81 -> ...
  // data                                   <= in how many lines is the yoffset 5 more?

  .for (var j=i+1; j<yOffsets.size(); j++)
  {
    .var offset = yOffsets.get(j)
    .if (offset >= targetOffset)
    {
      .eval targetLine = j-1
      .eval j=yOffsets.size()
    }

    // if we cannot find it, we can jump to the last line
    .if (j==yOffsets.size()-1)
    {
      .eval targetLine = j
    }
  }

  .eval skipTo.set(i, targetLine)
}

.if (verbose==1) { .print ("skipTo : " + skipTo) }

generateSourcePixels:
{
  .eval sourcePixels.add(-1) // half a gap at the left
 
  .var currentPixel  = 0
  .var currentColumn = 0
  .for (var pixel=0; pixel<(scrollPixels-fontGap); pixel++)
  {
    .if (currentPixel<fontWidth)
    {
      .eval sourcePixels.add((currentPixel&15)+(currentColumn*16))

      // go to the next pixel inside the char
      .eval currentPixel = currentPixel+1
    } else 
    {
      // add gap
      .for (var g=0; g<fontGap; g++) { .eval sourcePixels.add(-1) }

      .eval pixel = pixel+fontGap-1

      // start at the first pixel again
      .eval currentPixel = 0

      // next column
      .eval currentColumn = currentColumn+1
    }
  }
  .eval sourcePixels.add(-1) // half a gap at the right
}

.print ("")
.print ("source pixels")
.print (sourcePixels)
.print ("length source pixels : " + sourcePixels.size())
.print ("")

// -------------------------------------------------------------
// now we calculate where all the pixels go in each rasterline -
// -------------------------------------------------------------

.var allShifts     = Hashtable()
.var shiftedBytes  = List()  // all types of bytes stored as string
.var shiftedBytes2 = List()  // all types of bytes stored as lists
.var plotData      = List()

.for (var raster=0; raster<height; raster++)
{
  .var width = widths.get(raster)    // get width
  .eval targetPixels = List()        // reset what pixel goes where

  // -------------------------------------------------------------------------------------------------------
  // first we zoom the sourcepixels to the wanted width for this rasterline. the result is in targetPixels -
  // -------------------------------------------------------------------------------------------------------
  
  // fill empty space at the left
  .for (var pixel=0; pixel<((320-width)/2); pixel++) { .eval targetPixels.add(-1) }

  // calculate what pixel goes where and populate targetPixels
  .var skip = scrollPixels/width   // 320 / width
  .var firstSourcePixel = floor(0.49*skip)

  .for (var pixel=0; pixel<width; pixel++)
  {
    .var sourcePixel = floor(0.49*skip + pixel*skip)
    .eval targetPixels.add(sourcePixels.get(sourcePixel))
  }

  // fill empty space at the right
  .for (var pixel=0; pixel<((320-width)/2); pixel++) { .eval targetPixels.add(-1) }

  .if ((raster==0) && (verbose==1))
  {
    .print ("first source pixel: " + firstSourcePixel)
    .print ("target pixel example")
    .print (targetPixels)
    .print ("")
  }

  // ----------------------------------------------------------------------------------------------------------
  // transform this to the information we need for the plotter :                                              -
  // column 0 get plotted in byte X. the first pixel in the byte = [0..7]. the width of the colum is Y pixels -
  // ----------------------------------------------------------------------------------------------------------

  .var wantedColumn = 0 // we are scanning the targetPixels to check where the pixels for wantedColumn are
  .var startColumn  = 0 // this is the column of the screen the column starts at
  .var plotDataLine = List()

  .if (ROLRORlines.get(raster)==0) // only scan the line if it's NOT a ROLROL line
  {
    // scan along the targetPixels until we hit the first pixel for the column we are looking for 
    // "hey G*P. this is the column you are looking for"
    .for (var pixel=0; pixel<targetPixels.size(); pixel++)
    {
      .var source = targetPixels.get(pixel) 
      .var column = source>>4

      // does the wanted column start at this pixel?
      .if (column == wantedColumn)
      {
        .eval startColumn = floor(pixel/8) // mark at what char column it starts

        // yes. we now know the byte and start pixel
        .var byte       = pixel>>4
        .var startPixel = pixel&7

        // how wide is the column?
        .var nrPixels = 1
        .for (var w=1; w<fontWidth; w++)
        {
          .if (((pixel+w)<targetPixels.size()) && (((targetPixels.get(pixel))>>4) == ((targetPixels.get(pixel+w))>>4))) 
          {
            .eval nrPixels = w+1 
          }
        }
      
        // now, we know where this column of the scroller goes AND to how many pixels it is zoomed
        // ---------------------------------------------------------------------------------------

        // store this width + specific shift
        .var widthShift = nrPixels*10 + startPixel
        .eval allShifts.put(widthShift,widthShift)

        // calculate how the pixels would look for this width & shift
        .var bytes = ceil((nrPixels+startPixel)/8) // number of bytes needed
        .var bits = List()
        .for (var p=0; p<bytes*8; p++) { .eval bits.add(0) }
        {
          .var skipPixels = fontWidth/nrPixels
          .for (var p=0; p<nrPixels; p++)
          {
            .var sourcePixel = floor(0.5*skipPixels + p*skipPixels)
            .eval bits.set(startPixel+p,sourcePixel+1)
          }      
        }
        // store how the byte looks
        .for (var b=0; b<bytes; b++)
        {
          .var byteValue = ""
          .var bitList = List()
          .var codes = List().add("0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f")
          .for (var p=0; p<8; p++) 
          { 
            .eval byteValue = byteValue + codes.get((bits.get(b*8+p))) 
            .eval bitList.add(bits.get(b*8+p))
          }

          // transform byte into more general information to remove almost equal bytes
          .eval byteValue = toInfo(byteValue)

          // is this a new byte?
          .var position=exists(shiftedBytes, byteValue)

          // if it doesnt exist, we could also check a byte that is visually equal
          //.var position2=exists(shiftedBytes,pixelDown(byteValue))
          .var position2 = -1

          // if the almost equal byte DOES exist, we will use that one instead..
          .if ((position==-1) && (position2>=0))
          {
            .eval position = position2
          }

          // if we didnt find it.. we'll store the almostSame byte to always round down..
          //.if (position==-1) { .eval byteValue = pixelDown(byteValue) }

          .if (position==-1) // is this a new type of byte?
          {
            // store data for the plotter.
            .var data = List().add(startColumn+b, wantedColumn, shiftedBytes.size())  // store X, scrollColumn and the type of byte to plot
            .eval plotDataLine.add(data)

            // it's a new byte. store it.
            .eval shiftedBytes.add(byteValue)
            .eval shiftedBytes2.add(bitList)
          } else {
            // no.. 
            .var data = List().add(startColumn+b, wantedColumn, position)  // store X, scrollColumn and the type of byte to plot
            .eval plotDataLine.add(data)
          }
        }

        // now look for the next column
        .eval wantedColumn = wantedColumn + 1
      }
    }
  } // .if (ROLRORlines.get(raster)==0)
  .eval plotData.add(plotDataLine)
} // for raster

.if (verbose==1)
{
  .print ("")
  .print ("all sizes and shifts")
  .print (allShifts.keys())
  .print (allShifts.keys().size())

  .print ("")
  .print ("# of shifted zoomed bytes : " + shiftedBytes.size())
  .print (shiftedBytes)
}

.function calcByte(bitPos, data)
{
  .var value = 0
  .for (var i=0; i<8; i++)
  {
    .var bitValue = $80>>i
    .var pixel = bitPos.get(i)  // what pixel from data should go here?
    .if (pixel==0)
    {
      // this is an empty pixel.. value is unchanged
    } else
    {
      // read that bit from data
      // pixel      1,    2,    3,    4,    5,    6,    7,    8,   9,  10,  11,  12,  13,  14,  15,  16
      // AND    $8000,$4000,$2000,$1000, $800, $400, $200, $100, $80, $40, $20, $10, $08, $04, $02, $01
      .var b = 16-pixel               // 1 = the first pixel, which should equal $8000
      .var ANDvalue = 1<<b            // calculate the AND value
      .var bitSet = data & ANDvalue   // read the bit

      .if (bitSet !=0)
      {
        .eval value = value + bitValue
      }
    }
  }
  .return value
}

// calculate all the zoomed and shifted bytes for all the different font rows
// --------------------------------------------------------------------------

* = fontBytes "[GFX] font bytes (shifted and zoomed)"
.var fontPositions = List()
.var nrBytes = allFontRows.size()
// generate all shifted and zoomed bytes
.for (var type=0; type<shiftedBytes2.size(); type++)  // loop over all byte types
{
  .if ((>*) != (>(*+nrBytes-1))) { .align $100 } // align data to pages
  .eval fontPositions.add(*)                     // store address for this byte type for the plotter
  .var bitPosition = shiftedBytes2.get(type)     // read where the pixels should go

  .for (var i=0; i<allFontRows.size(); i++)      // loop over all the different font rows
  {
    .var data = allFontRows.get(i)
    .var value = calcByte(bitPosition, data)
    .byte value
  }
}

* = * "[DATA] fontPointers low"
fontPointersLow:  .for (var i=0; i<charsInFont+1; i++) { .byte <(fontRows+(fontHeight*i)) }
* = * "[DATA] fontPointers high"
fontPointersHigh: .for (var i=0; i<charsInFont+1; i++) { .byte >(fontRows+(fontHeight*i)) }

.if ((>(fontPointersLow)) != >(*)) { .error ("font pointers in 2 banks")}

* = * "[CODE] Main"

start:
{
  sei
  lda #$35
  sta $01

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  lda #$1b
  sta $d011
  
  lda #0
  sta frame

  lda #<irq3
  sta $fffe
  lda #>irq3
  sta $ffff

  lda $d011
  and #$7f
  sta $d011
  lda #$fb
  sta $d012

  #if !AS_SPINDLE_PART
    lda #border
    sta $d020
    .if (border!=background)
    {
      lda #background
    }
    sta $d021

    lda #$0b
    sta $d022
    lda #$07
    sta $d023

    lda #$d8   // the whole part is in multicolor mode
    sta $d016

    jsr prepare

    lda #$94
    sta $dd00

    :MusicInitCall()
  #endif

  lda #$00
  sta $dd00 // kill spindle and stop drive spinning
  
  lda #$34  // access to all the memory..
  sta $01

  cli
    
  // first copy the scrolltext
  ldx #0
  {
  loop:
    .for (var i=0; i<8; i++)
    {
      lda scrollText0+i*256,x
      sta scrollText+i*256,x
    }
    inx
    bne loop
  }

  // then clear bottom charset of frame 0

  ldx #0
  lda #0
  {
  loop:
    sta charset1b+$000,x
    sta charset1b+$100,x
    sta charset1b+$200,x
    sta charset1b+$300,x
    sta charset1b+$400,x
    sta charset1b+$500,x

    inx
    bne loop
  }

  // then copy the charmap (only after we cleared the charset at the bottom!)
  ldx #0
  {
  loop:
    .for (var i=0; i<4; i++)
    {
      .if (i>0)
      {
        lda screenOri+i*256,x
        sta screen+i*256,x
      }
    }
    inx
    bne loop
  }

  // finally clear the bottom charset for frame 1
  ldx #0
  lda #0
  {
  loop:
    sta screenOri+0*256,x
    sta screenOri+1*256,x
    sta screenOri+2*256,x
    sta screenOri+3*256,x

    .for (var i=1; i<scrollBuffers.size(); i++)
    {
      .var buffer = scrollBuffers.get(i)
      sta buffer,x
    }

    inx
    bne loop
  }

  // write colors to part of the screen occupied by scroller
  {
  lda #$35
  sta $01
  bigloop:

    ldx startX: #10
    ldy w:      #20-1
    lda #WHITE
    loop:
      sta write: $d800+14*40,x
      inx
      dey
      bpl loop
    
    lda write
    clc
    adc #40
    sta write
    bcc !+
      inc write+1
    !:
    // increase width by 2
    inc w
    inc w

    // decrease start x
    dec startX
    bpl bigloop
  lda #$34
  sta $01
  }


  //inc irq2.startPart
  lda #1
  sta irq2.eorValue

loop1:
  lda frame
  beq loop1

  .if (debug==1)
  {
    inc $01
    inc $d020
    dec $01
  }

  ldy offset: #11  // offset plotter and scrollupdate to stabilize rastertime use
  jsr plotFrame2
  iny
  cpy #bufferLength
  bne !+
  ldy #0
!:
  sty offset

  .if (debug==1)
  {
    inc $01
    inc $d020
    dec $01
  }

  jsr scroll

  .if (debug==1)
  {
    inc $01
    lda #BLUE
    sta $d020
    dec $01
  }

loop2:
  lda frame
  bne loop2

  .if (debug==1)
  {
    inc $01
    inc $d020
    dec $01
  }

  ldy offset
  jsr plotFrame1 // plot first
  iny
  cpy #bufferLength
  bne !+
  ldy #0
!:
  sty offset

  .if (debug==1)
  {
    inc $01
    inc $d020
    dec $01
  }
  jsr scroll     // then scroll to avoid update bugs

  .if (debug==1)
  {
    inc $01
    lda #BLUE
    sta $d020
    dec $01
  }

  // this is the last part
  // don't go back to spindle
  jmp loop1
}

prepare:
{
  // colors already set by previous part
  #if !AS_SPINDLE_PART
    ldx #0
    {
    loop:
      .for (var i=0; i<4; i++)
      {
        lda #$01|$08
        sta $d800+i*256,x
      }
      inx
      bne loop
    }

  // write colors to part of the screen occupied by scroller
  {
  bigloop:

    ldx startX: #10
    ldy w:      #20-1
    lda #CYAN
    loop:
      sta write: $d800+14*40,x
      inx
      dey
      bpl loop
    
    lda write
    clc
    adc #40
    sta write
    bcc !+
      inc write+1
    !:
    // increase width by 2
    inc w
    inc w

    // decrease start x
    dec startX
    bpl bigloop
  }
  #endif
  rts
}

d018Values1:
  .byte (16*(screen&$3c00)/$400)+(((charset1b+$000)&$3800)/$400)
  .byte (16*(screen&$3c00)/$400)+(((charset2b+$000)&$3800)/$400)

d018Values2:
  .byte (16*(screen&$3c00)/$400)+(((charset1a+$000)&$3800)/$400)
  .byte (16*(screen&$3c00)/$400)+(((charset2a+$000)&$3800)/$400)

// this is the irq below the logo, switching to the first charset of the scroller
// ------------------------------------------------------------------------------
.align $100
* = * "[CODE] irq1"
irq1:
{
  dec 0
  sta atemp
  stx xtemp
  sty ytemp

  lda #<irq2
  sta $fffe
  //lda #>irq2
  //sta $ffff

  lda #$32+(charsetSwap+moveDown)*8
  sta $d012
  asl $d019

  ldx frame
  lda d018Values2,x
  sta $d018
  lda #((screen&$c000)/$4000)|$3c  // 3c of 00
  sta $dd02

  //inc $d021

  //cli
  :MusicPlayCall()
  
  lda atemp: #0
  ldx xtemp: #0
  ldy ytemp: #0
  inc 0
  rti
}

// this irq switches to the 2nd charset of the scroller
// ----------------------------------------------------
* = * "[CODE] irq2"
irq2:
{
  dec 0
  sta atemp
  stx xtemp

  lda #<irq3
  sta $fffe
  //lda #>irq3
  //sta $ffff

  lda #$fb
  sta $d012
  asl $d019

  lax frame
  eor eorValue: #1
  sta frame
  lda d018From: d018Values1,x
  sta $d018

  lda atemp: #0
  ldx xtemp: #0
  inc 0
  rti
}

// this is the irq at the lower border
// -----------------------------------
* = * "[CODE] irq3"
irq3:
{
  dec 0
  sta atemp

  lda #<irq1
  sta $fffe
  //lda #>irq1
  //sta $ffff
  lda #$32+switch*8 //8a
  sta $d012
  asl $d019

  lda #((logoScreen&$3c00)/$400)*$10 + ((logoCharset&$3800)/$800)*2+1 // add 1 to reuse value for dd02 write
  sta $d018
  //lda #((logoScreen&$c000)/$4000)|$3c  // 3f
  sta $dd02

  lda atemp: #0
  inc 0
  rti
}

scroll:
{
  ldx phase: #255 // read next row immediately
  
  // go to next row?
  //cpx #(fontHeight+fontEmpty-4) // we can check at fontHeight+fontEmpty-1, but if we check at -4, we will split the rastertime a bit better over frames..
  cpx #fontHeight
  {
    bne continue
    ldx scrollRow: #0
    ldy scrollText,x
    bpl readNextRow             // end of scrolltext?
    // reset scroll
      ldx #0
      stx scrollRow
      ldy scrollText
  readNextRow:
    inc scrollRow
    jmp nextScrollRow           // read the next scroll row here
    // nextScrollRow jumps to finish.
  continue:
  }

  // x = phase
  ldy yOffset: #0

  //cpx #fontHeight
  bcc updateBuffers

  // reset phase?
  cpx #(fontHeight+fontEmpty)
  {
    bcc continue

    // go to next row in the scroll
    ldx #0
    stx phase
    beq updateBuffers  // we can skip the compare
  continue:
  }

  jmp finish

  // this gets called every new line
  updateBuffers:
  {
  loop:
    .for (var i=0; i<scrollColumns; i++)
    {
      .var buffer = scrollBuffers.get(i)
    
      lda readRow: fontRows,x
      sta buffer,y
      sta buffer+bufferLength,y
    }
  }

finish:
  //ldy yOffset
  iny
  cpy #bufferLength
  bne !+
    ldy #0
  !:
  sty yOffset
  inc phase
  rts
}

// this gets called only once per character row
nextScrollRow:
{
  .for (var i=0; i<scrollColumns; i++)
  {
    .if (i>0) { ldy scrollText+i*scrollLength,x }
    //ldy scrollText0+i*scrollLength,x
    lda fontPointersLow,y
    sta scroll.updateBuffers.loop[i].readRow
    lda fontPointersHigh,y
    sta scroll.updateBuffers.loop[i].readRow+1
  }
  ldy scroll.yOffset
  jmp scroll.finish
}

// this table holds which rows are needed by a char in the font
* = * "[DATA] fontRows"
fontRows:
.for (var i=0; i<charsInFont; i++)  // empty+a-z
{
  .for (var y=0; y<fontHeight; y++)
  {
    .var value = fontData.get(i*fontHeight + y)
    .byte value
  }
}
// add empty
.for (var i=0; i<fontHeight; i++)
{
  .byte $81
}

// sort the data to plot, so we can plot it in the correct order
// first from left to the middle
// then from right to the middle
// we have to do it in this order so we can use ROR and ROL correctly
// ------------------------------------------------------------------

.function sortLeftRight(line)
{
  .var left = List()
  .var right = List()

  // add from left to the middle
  .for (var i=0; i<line.size(); i++)
  {
    .var data = line.get(i)
    .var column = data.get(0) // read column
    .if (column<20)
    {
      .eval left.add(data)
    }
  }

  // add from right to the middle
  .for (var i=line.size()-1; i>=0; i--)
  {
    .var data = line.get(i)
    .var column = data.get(0) // read column
    .if (column>=20)
    {
      .eval right.add(data)
    }
  }
  .var allData = List().addAll(left)
  .eval allData = allData.addAll(right)

  .return allData
}

.var ultimateSpeed0 = List()
.var ultimateSpeed1 = List()
.var ultimateSpeedWidth = List() // number of chars that are cleared in each speedcode
.for (var charset=0; charset<nrCharsets; charset++) { .eval ultimateSpeedWidth.add(0) }

* = * "[CODE] ultimate speedcode frame 0"
.for (var charset=0; charset<nrCharsets; charset++)
{
  .eval ultimateSpeed0.add(*)
  genUltimateSpeedCode(charset,0)  // charset, frame 0
}

* = * "[CODE] ultimate speedcode frame 1"
.for (var charset=0; charset<nrCharsets; charset++)
{
  .eval ultimateSpeed1.add(*)
  ultimateSpeedClear1:
  genUltimateSpeedCode(charset,1)  // charset, frame 1
}

.print ("widths :" + ultimateSpeedWidth)

.var addressWritten = List(); .for (var i=0; i<65536; i++) { .eval addressWritten.add(0) }

.macro genSpeedCode(frame)
{
  .print ("generating speedcode for frame " + frame)

  .var ultimateSpeedClears  = ultimateSpeed0
  .var ultimateSpeedClears2 = ultimateSpeed1
  .if (frame==1) 
  {
     .eval ultimateSpeedClears  = ultimateSpeed1 
     .eval ultimateSpeedClears2 = ultimateSpeed0
  }

  // determine what charsets to plot to
  .var charsets  = List().add(charset1a, charset1b) // charsets for this frame
  .var charsets2 = List().add(charset2a, charset2b) // charsets for the next frame

  // if we are plotting for the other frame, update accordingly..
  .if (frame == 1)
  {
    .eval charsets  = List().add(charset2a, charset2b) // charsets for this frame
    .eval charsets2 = List().add(charset1a, charset1b) // charsets for the next frame
  }

  .print (charsets)

  .var previousSpecial = 0
  .var specialRaster   = 0

  forLoop: .for (var raster=0; raster<height; raster++)
  {
    .var skipBPL       = 200
    .var width         = widths.get(raster)/2  // width in pixels for the left or right side
    .var widthChars    = ceil(width/8)         // width in chars/bytes for the left side 
    .var RORcolumn     = 20-(widthChars*3/4)   // ROR to this column
    .var ROLcolumn     = 20+(widthChars*3/4)   // ROR to this column

    .var yOffset       = yOffsets.get(raster)
    .var ROLRORline    = ROLRORlines.get(raster)
    .var specialLine   = specialLines.get(raster)
    .var doubleUseLine = doubleUseLines.get(raster)
    .var tripleUseLine = tripleUseLines.get(raster)

    ROLRORcode: .if (ROLRORline>0)
    {
      // this is a ROLROR line, the plotting is done in the line below
    }
    specialLineCode: .if ((ROLRORline==0) && (specialLine==1))
    {
      .eval specialRaster = raster // keep track of the last raster where there was a special line
      .eval previousSpecial = 1    // keep track that we had a special line

      .print ("special code for raster : " + raster + " at " + *)

      .var charRow  = floor(raster/8)          // calculate which character row
      .var charY    = mod(raster,8)            // calculate y position in character row
      .var charset  = rowCharset.get(charRow)  // fetch charset for this row

      // can we skip this line or do we have to clear it?
      lax scrollBuffer+(0*$100)+yOffset,y  // read character we have to plot
      bpl dontSkip  // this line contains data. we have to plot it

      .var speedCode = ultimateSpeedClears.get(charset)     // get address of speedcode
      .var speedCodeWidth = ultimateSpeedWidth.get(charset) // get width of speedcode
      .var raster0 = firstRaster.get(charset)               // get first raster where the charset is valid
      .var plotChars = 2*ceil(widths.get(raster)/2/8)

      asl
      beq clearLine
      // this line is always empty, skip it
      .if (raster == height-1) { rts }
      else
      {
        // this bpl is only needed in the first couple of lines.. we don't need it later on.
        // we might need it, if the y offsets make skips > 2. if that happens, we might miss where the big skip starts
        // it could also happen at the top, if the big skip marker has scrolled out

        .if (raster < skipBPL)
        {
          bpl skipIt // this is not the first skippable line. so we don't know how many we can skip.. go to the next line
        }

        // if we have a negative value ($c0, asl -> $80), then this is the first empty line and
        // we know how many lines we can skip

        .var to = skipTo.get(raster) // to which skipLine can we jump?
        jmp forLoop[to].skipLine 
      }

    clearLine:
      // a = 0, x = $80
      .var xValue = raster-raster0
      .if (xValue==0) { tax  } // x is already 0, do nothing
      .if (xValue>0)  { ldx #(raster-raster0) }
      
      jsr speedCode+((speedCodeWidth-plotChars)*3)
    skipIt: 
        jmp skipLine

      // this is a special line, plotting is done using special code getting feed from the line below
    dontSkip:
      .var  plotDataLine = plotData.get(raster+1)    // read all data for the next line (where this line is based on)
      .if (ROLRORlines.get(raster+1)==1)
      {
        .eval  plotDataLine = plotData.get(raster+2)  // or the line after that if the next line is a ROLROR line
      }
      .eval plotDataLine = sortLeftRight(plotDataLine) // resort it for plotting   

      // get first and last column..
      .var firstColumn = 39
      .var lastColumn  = 0
      .for (var i=0; i<plotDataLine.size(); i++)
      {
        .var data = plotDataLine.get(i)
        .var column = data.get(0)

        .eval firstColumn = min(column, firstColumn)
        .eval lastColumn  = max(column, lastColumn)
      }

      .print("firstColumn : " + firstColumn + ", " + lastColumn)

      // plot data

      // left to right
      forLoop2: .for (var c=firstColumn; c<20; c++)
      {
        .var address  = charsets.get(charset) + 8*charMap.get((charRow+moveDown)*40+c) + charY
        lda colValue: #$55

        .if (c<(20-((20-firstColumn)/3)))
        {
          .if (c==firstColumn)
          {
            lsr
          }
          else
          {
            ror
          }
        }
        sta address
        .eval addressWritten.set(address, addressWritten.get(address)+1)
      }

      // right to left
      forLoop3: .for (var c=lastColumn; c>=20; c--)
      {
        .var address  = charsets.get(charset) + 8*charMap.get((charRow+moveDown)*40+c) + charY
        lda colValue: #$55

        .if (c>(20+((lastColumn-20)/3)))
        {
          .if (c==lastColumn)
          {
            asl
          }
          else
          {
            rol
          }
        }
        sta address
        .eval addressWritten.set(address, addressWritten.get(address)+1)
      }
    }

    .if ((ROLRORline==0) && (specialLine==0))
    {
      // do we have to write to a special line?

      .var charRow  = floor(raster/8)          // calculate which character row
      .var charY    = mod(raster,8)            // calculate y position in character row
      .var charset  = rowCharset.get(charRow)  // fetch charset for this row

      .var charRow2 = 0
      .var charY2   = 0
      .var charset2 = 0

      .var charRow3 = 0
      .var charY3   = 0
      .var charset3 = 0

      .var firstROR = 0
      .var firstROL = 0

      .if (doubleUseLine==1)
      {
        .eval charRow2 = floor((raster-1)/8)       // character row for other frame
        .eval charY2   = mod(raster-1,8)           // y position in other frame
        .eval charset2 = rowCharset.get(charRow2)  // charset for this row in the other frame
      }

      .if (tripleUseLine==1)
      {
        .eval charRow2 = floor((raster-2)/8)       // character row for other frame
        .eval charY2   = mod(raster-2,8)           // y position in other frame
        .eval charset2 = rowCharset.get(charRow2)  // charset for this row in the other frame
    
        .eval charRow3 = floor((raster-1)/8)       // character row for the line above this one
        .eval charY3   = mod(raster-1,8)           // y position
        .eval charset3 = rowCharset.get(charRow3)  // charset for the line above this row
      }

      .var  plotDataLine = plotData.get(raster)        // read all data for this line
      .eval plotDataLine = sortLeftRight(plotDataLine) // resort it for plotting

      // get first and last column..
      .var firstColumn = 39
      .var lastColumn  = 0
      .for (var i=0; i<plotDataLine.size(); i++)
      {
        .var data = plotDataLine.get(i)
        .var column = data.get(0)

        .eval firstColumn = min(column, firstColumn)
        .eval lastColumn  = max(column, lastColumn)
      }

      .var previousScreenColumn = -1
      .var previousScrollColumn = -1
      .var previousAddress      = -1
      .var previousAddress2     = -1
      .var previousAddress3     = -1

      // loop over all data for this line
      .for (var i=0; i<plotDataLine.size(); i++)
      {
        .var data = plotDataLine.get(i)      // get data for 1 plot
  
        .var screenColumn = data.get(0)      // get which column on screen
        .var scrollColumn = data.get(1)      // get which scroll column to plot
        .var byteType     = data.get(2)      // get which type of byte to plot

        .var address  = charsets.get(charset) + 8*charMap.get((charRow+moveDown)*40+screenColumn) + charY
        
        // calculate store address for other frame
        .var address2 = 0
        .var address3 = 0
        .if (doubleUseLine==1)
        {
          .eval address2 = charsets2.get(charset2) + 8*charMap.get((charRow2+moveDown)*40+screenColumn) + charY2
        }
        .if (tripleUseLine==1)
        {
          .eval address2 = charsets2.get(charset2) + 8*charMap.get((charRow2+moveDown)*40+screenColumn) + charY2
          .eval address3 = charsets.get(charset3)  + 8*charMap.get((charRow3+moveDown)*40+screenColumn) + charY3
        }

        // is this a new screen column? then we can write the previous screen column
        .if (((previousScreenColumn!=screenColumn) && (previousScreenColumn!=-1)))
        {
          sta previousAddress
          .eval addressWritten.set(previousAddress, addressWritten.get(previousAddress)+1)

          .if (doubleUseLine==1)
          {
            .if ((previousScreenColumn<20) && ((previousScreenColumn<RORcolumn)))
            {
              .if (widths.get(raster-1)<widths.get(raster))
              {
                .if (firstROR==0)
                {
                  lsr
                } else
                {
                  ror
                }
                .eval firstROR = 1
              }
            }

            .if ((previousScreenColumn>=20) && ((previousScreenColumn>ROLcolumn)))
            {
              .if (widths.get(raster-1)<widths.get(raster))
              {
                .if (firstROL==0)
                {
                  asl
                } else
                {
                  rol
                }
                .eval firstROL = 1
              }
            }
            // TODO : sometimes we do not have to write this byte.. 
            // can we figure out when? (width = n*8+1, rolrorwidth = n*8 -> the first byte is always 0)
            // -> this does not seem to happen
            
            .var widthROLROR = widths.get(raster-1)/2

            .var bytesWide1  = ceil(width/8)          // the number of bytes plotted
            .var bytesWide2  = ceil(widthROLROR/8)    // the number of bytes we have to plot for ROLROL line

            .if (bytesWide1 == bytesWide2)
            {
              sta previousAddress2 // write to 2nd frame
              .eval addressWritten.set(previousAddress2, addressWritten.get(previousAddress2)+1)
            }
          }

          .if (tripleUseLine==1)
          {
            .if ((previousScreenColumn<20) && (firstROR==0))
            {
              lsr
            }
            .if ((previousScreenColumn>=20) && (firstROL==0))
            {
              asl
            }

            sta previousAddress3 // write to line above
            .eval addressWritten.set(previousAddress3, addressWritten.get(previousAddress3)+1)

            .if ((previousScreenColumn<20) && ((previousScreenColumn<RORcolumn)))
            {
              .if (widths.get(raster-1)<widths.get(raster))
              {
                .if (firstROR==0)
                {
                  lsr
                } else
                {
                  ror
                }
                .eval firstROR = 1
              }
            }

            .if ((previousScreenColumn>=20) && ((previousScreenColumn>ROLcolumn)))
            {
              .if (widths.get(raster-1)<widths.get(raster))
              {
                .if (firstROL==0)
                {
                  asl
                } else
                {
                  rol
                }
                .eval firstROL = 1
              }
            }
            sta previousAddress2 // write to 2nd frame
            .eval addressWritten.set(previousAddress2, addressWritten.get(previousAddress2)+1)
          }

          .if (previousSpecial==1)
          {
            .if (previousScreenColumn<20) 
            {
              // plot in left to middle plotter
              sta forLoop[specialRaster].specialLineCode.forLoop2[previousScreenColumn - firstColumn].colValue
            } else                        
            {
              // plot in right to middle plotter
              sta forLoop[specialRaster].specialLineCode.forLoop3[lastColumn - previousScreenColumn].colValue
            }
          }
        }

        // is this a new scroll column? then we have to fetch the character at this position
        .if (scrollColumn != previousScrollColumn)
        {
          .if (i==0)
          {
            // special for the first value in the line : use LAX so we can use the accumulator to clear the line if necessary
            .var buffer = scrollBuffers.get(scrollColumn)
            lax buffer+yOffset,y  // read character we have to plot
          }
          else
          {
            .var buffer = scrollBuffers.get(scrollColumn)
            ldx buffer+yOffset,y  // read character we have to plot
          }
        }

        // skip this entire line?
        .if (i==0)
        {
          bpl dontSkip  // this line contains data. we have to plot it

          .var speedCode = ultimateSpeedClears.get(charset)     // get address of speedcode
          .var speedCodeWidth = ultimateSpeedWidth.get(charset) // get width of speedcode
          .var raster0 = firstRaster.get(charset)               // get first raster where the charset is valid
          .var plotChars = 2*ceil(widths.get(raster)/2/8)

          .if ((doubleUseLine==0) && (tripleUseLine==0)) 
          {
            // this is not a doubleUse line. we only have to clear this line

            asl
            beq clearLine
            // this line is always empty, skip it
            .if (raster == height-1) { rts }
            else
            {
              // this bpl is only needed in the first couple of lines.. we don't need it later on.
              // we might need it, if the y offsets make skips > 2. if that happens, we might miss where the big skip starts
              // it could also happen at the top, if the big skip marker has scrolled out
              .if (raster < skipBPL)
              {
                bpl skipIt // this is not the first skippable line. so we don't know how many we can skip.. go to the next line
              }
              
              // if we have a negative value ($c0, asl -> $80), then this is the first empty line and
              // we know how many lines we can skip

              .var to = skipTo.get(raster) // to which skipLine can we jump?
              jmp forLoop[to].skipLine 
            }

          clearLine:
            // a = 0, x = $80
                  
            .var xValue = raster-raster0
            .if (xValue==0) { tax  } // x is already 0, do nothing
            .if (xValue>0)  { ldx #(raster-raster0) }

            jsr speedCode+((speedCodeWidth-plotChars)*3)
          }

          .if (doubleUseLine==1)
          {
            // this is a doubleUse line. the line above in the other frame also has to be cleared

            asl
            beq clearLine
            // this line is always empty, skip it
            .if (raster == height-1) { rts }
            else
            {
              // this bpl is only needed in the first couple of lines.. we don't need it later on.
              // we might need it, if the y offsets make skips > 2. if that happens, we might miss where the big skip starts
              // it could also happen at the top, if the big skip marker has scrolled out

              .if (raster < skipBPL)
              {
                bpl skipIt // this is not the first skippable line. so we don't know how many we can skip.. go to the next line
              }

              // if we have a negative value ($c0, asl -> $80), then this is the first empty line and
              // we know how many lines we can skip

              .var to = skipTo.get(raster) // to which skipLine can we jump?
              jmp forLoop[to].skipLine 
            }

          clearLine:
            // a = 0, x = $80

            .var xValue = raster-raster0
            .if (xValue==0) { tax  } // x is already 0, do nothing
            .if (xValue>0)  { ldx #(raster-raster0) }

            jsr speedCode+((speedCodeWidth-plotChars)*3)

            .var speedCode2 = ultimateSpeedClears2.get(charset2)    // get address of speedcode
            .var speedCodeWidth2 = ultimateSpeedWidth.get(charset2) // get width of speedcode
            .var raster02 = firstRaster.get(charset2)               // get first raster where the charset is valid
            .var plotChars2 = 2*ceil(widths.get(raster-1)/2/8)
            .var xValue2 = (raster-1)-raster02

            // clear line in the other frame
            .if (xValue2 == (xValue-1))
            { 
              dex
            } else
            {
              ldx #xValue2
            }
            jsr speedCode2+((speedCodeWidth2-plotChars2)*3)          
          }

          .if (tripleUseLine==1)
          {
            // this is a tripleUse line. the two lines above also have to be cleared
            asl
            beq clearLine
            // this line is always empty, skip it
            .if (raster == height-1) { rts }
            else
            {
              // this bpl is only needed in the first couple of lines.. we don't need it later on.
              // we might need it, if the y offsets make skips > 2. if that happens, we might miss where the big skip starts
              // it could also happen at the top, if the big skip marker has scrolled out
              .if (raster < skipBPL)
              {
                bpl skipIt // this is not the first skippable line. so we don't know how many we can skip.. go to the next line
              }

              // if we have a negative value ($c0, asl -> $80), then this is the first empty line and
              // we know how many lines we can skip

              .var to = skipTo.get(raster) // to which skipLine can we jump?
              jmp forLoop[to].skipLine 
            }
          clearLine:
            // a = 0, x = $80

            .var xValue = raster-raster0
            .if (xValue==0) { tax  } // x is already 0, do nothing
            .if (xValue>0)  { ldx #(raster-raster0) }

            jsr speedCode+((speedCodeWidth-plotChars)*3)

            .var speedCode3 = ultimateSpeedClears.get(charset3)     // get address of speedcode
            .var speedCodeWidth3 = ultimateSpeedWidth.get(charset3) // get width of speedcode
            .var raster03 = firstRaster.get(charset3)               // get first raster where the charset is valid
            .var plotChars3 = 2*ceil(widths.get(raster-1)/2/8)
            .var xValue3 = (raster-1)-raster03

            // clear line in the other frame
            .if (xValue3 == (xValue-1))
            { 
              dex
            } else
            {
              ldx #xValue3
            }
            jsr speedCode3+((speedCodeWidth3-plotChars3)*3)  

            .var speedCode2 = ultimateSpeedClears2.get(charset2)    // get address of speedcode
            .var speedCodeWidth2 = ultimateSpeedWidth.get(charset2) // get width of speedcode
            .var raster02 = firstRaster.get(charset2)               // get first raster where the charset is valid
            .var plotChars2 = 2*ceil(widths.get(raster-1)/2/8)
            .var xValue2 = (raster-2)-raster02

            // clear line in the other frame
            .if (xValue2 == (xValue3-1))
            { 
              dex
            } else
            {
              ldx #xValue2
            }
            jsr speedCode2+((speedCodeWidth2-plotChars2)*3)          
          }

          skipIt:   
          .if (raster == height-1)
          {
            rts
          }
          else
          {
            jmp forLoop[raster].skipLine
          }

          dontSkip: // continue plotting
        }

        // fetch the bits to plot

        // if this is the first time we are writing to this screenColumn, we need LDA
        // if we were already writing to this screenColumn, we need ORA

        .if (screenColumn == previousScreenColumn)
        {
          ora (fontPositions.get(byteType)),x
        } else {
          lda (fontPositions.get(byteType)),x
        }

        .eval previousScrollColumn = scrollColumn 
        .eval previousScreenColumn = screenColumn
        .eval previousAddress      = address
        .eval previousAddress2     = address2
        .eval previousAddress3     = address3
      }

      .if (doubleUseLine==1)
      {
        .eval addressWritten.set(previousAddress2, addressWritten.get(previousAddress2)+1)
        sta previousAddress2 // write to 2nd frame
      }
      .if (tripleUseLine==1)
      {
        .eval addressWritten.set(previousAddress3, addressWritten.get(previousAddress3)+1)
        .eval addressWritten.set(previousAddress2, addressWritten.get(previousAddress2)+1)
        sta previousAddress3 // write to line above
        sta previousAddress2 // write to 2nd frame
      }

      .eval addressWritten.set(previousAddress, addressWritten.get(previousAddress)+1)
      sta previousAddress // write the last data

      .if (previousSpecial==1)
      {
        .if (previousScreenColumn<20) 
        {
          // plot in left to middle plotter
          sta forLoop[specialRaster].specialLineCode.forLoop2[previousScreenColumn - firstColumn].colValue
        } else                        
        {
          // plot in right to middle plotter
          sta forLoop[specialRaster].specialLineCode.forLoop3[lastColumn - previousScreenColumn].colValue
        }
      }

      .eval previousSpecial = 0 // previous line was not special
    }
    skipLine:
  }

  rts
}

* = * "[CODE] plotFrame1"
plotFrame1: genSpeedCode(0)

* = * "[CODE] plotFrame2"
plotFrame2: genSpeedCode(1)

* = screen "[GEN] generated screen" virtual
.fill 1000,0

// ----------------------------------------
// combine logo and charmap into one screen
// ----------------------------------------

* = screenOri "[DATA] charmap (original position of data)"
.var combinedMap = List()
.for (var i=0; i<max(screen2.size(), charMap.size()); i++)
{
  .var row = floor(i/40)         // calculate the row #
  .var value = 0                 // start with empty char

  // read char from the picture
  .if (i<screen2.size())                       { .eval value = screen2.get(i)      }

  // if the char is empty, try getting the char from the scroller char map
  .if ((value == $00) && (i<charMap.size()))   { .eval value = charMap.get(i)      }

  .eval combinedMap.add(value)
}
.fill combinedMap.size(), combinedMap.get(i)

// in spindle, we inherit the picture from switch. we have to dump the bytes for standalone though
#if !AS_SPINDLE_PART
  *=charset1a "[GFX] charset 1a frame 1 top charset"
  .fill charset2.size(), charset2.get(i)
  .fill totalChars1*8,0

  *=charset2a "[GFX] charset 2a frame 2 top charset"
  .fill charset2.size(), charset2.get(i)
  .fill totalChars1*8,0
#else
  *=charset1a "[GFX] charset 1a frame 1 top charset" virtual
  .fill charset2.size(), charset2.get(i)
  .fill totalChars1*8,0

  *=charset2a "[GFX] charset 2a frame 2 top charset" virtual
  .fill charset2.size(), charset2.get(i)
  .fill totalChars1*8,0
#endif

*=charset1b "[GFX] charset 1b frame 1 bottom charset" virtual
.fill totalChars2*8,0

*=charset2b "[GFX] charset 2b frame 2 bottom charset" virtual
.fill totalChars2*8,0

// -------------------------
// process scrolltext here -
// -------------------------

// this is the original scrolltext data, which gets copied to scrollText (see below)
*=scrollTextOriginal "[DATA] scrolltext"
scrollText0:        // text for column 0
.for (var c=0; c<20; c++)
{
  .var data = scrollTextList.get(c)
  .fill data.size(), data.get(i)
}

// this is where the scrolltext is copied to
* = scrollText "[DATA] final position of scrolltext" virtual
.for (var c=0; c<20; c++)
{
  .var data = scrollTextList.get(c)
  .fill data.size(), data.get(i)
}

// ----------------------------------
// space for the scrollbuffers here -
// ----------------------------------

* = scrollBuffer "[RT] scrollBuffer prototype = $100"

// every line has 20 columns
// there are 128 lines, each column repeats the data once, so 256 per column

// column looks like this, repeating : 00 00 00 00  00 00 00 00  00 00 00 00  00 00 80 80  c0 c0 81 81 81 
// -> if we use $c0 instead of $00, the plotter will clear the charsets for us and save same rastertime at the start
// of the scroller..

.var bytes = List()
.for (var i=0; i<fontHeight; i++) { .eval bytes.add($c0) }
.eval bytes.add($80,$80,$c0,$c0)
.for (var i=0; i<fontEmpty-4; i++) { .eval bytes.add($81) }
.for (var j=0; j<floor(256/(fontHeight+fontEmpty)); j++) { .fill bytes.size(),bytes.get(i) }

// (virtually) occupy the memory for the scrollbuffers
.var previousBuffer = -1
.for (var i=1; i<scrollBuffers.size(); i++)
{
  .var buffer = scrollBuffers.get(i)

  .if (previousBuffer+$100 != buffer) { * = buffer "[RT] virtual scrollbuffer" virtual }
  else                                { .align $100 }
  .fill $fc,0
  
  .eval previousBuffer = buffer
}

// in spindle, the screen and charset gets inherited from the loader
#if !AS_SPINDLE_PART
  * = logoScreen "[GFX] screen for logo"
  .fill min(screen1.size(),switch*40), screen1.get(i)

  * = logoCharset "[GFX] charset for logo"
  .fill charset1.size(),charset1.get(i)
#endif


.print ("single use lines:")
.for (var i=0; i<doubleUseLines.size(); i++)
{
  .if ((doubleUseLines.get(i)==0) && (ROLRORlines.get(i)==0)) { .print (i) }
}

.for (var i=0; i<addressWritten.size(); i++)
{
  .if (addressWritten.get(i) > 1) { .print ("address written more then once! :" + i)}
}
