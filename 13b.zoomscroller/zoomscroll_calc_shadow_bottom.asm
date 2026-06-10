#import "zoomscroll_general.asm"

// ----------------
// create empty map 
// ----------------

.var map2 = List(mapWidth * mapHeight)
.for (var i=0; i<map2.size(); i++) { .eval map2.set(i, 0) }

// -------------------
// plot chars into map 
// -------------------

{
.var x=1 // skip first pixel
.for (var i=0; i<text.size(); i++)        // loop over the text
{
  .var char = text.charAt(i)              // read char to plot
  .var charData   = List()                // read char data
  .var startPixel = startPixels.get(char) // first set pixel of the char to plot
  .var width      = widths.get(char)      // get width of char to plot

  // copy char into charData
  .for (var byte=0; byte<8; byte++) { .eval charData.add(font.get(char*8 + byte)) }

  // shift data left
  .for (var i=0; i<startPixel; i++) { .for (var byte=0; byte<8; byte++) { .eval charData.set(byte, charData.get(byte)<<1)} }

  // plot char
  .for (var i=0; i<width; i++)
  {
    .for (var byte=0; byte<7; byte++)
    {
      .var value  = charData.get(byte+1)
      .eval value = value << i

      // if the pixel is set, plot the pixel 9 times (for all shadow versions)
      .if ((value & 128)!=0) 
      { 
        .for (var s=0; s<9; s++) { .eval map2.set( ( ((s*8)+byte) *mapWidth) + x + i, 1) }
      }
    }
  }

  // increase x position
  .eval x = x + width + 2
}
}

// ------------------------------
// calculate shadows to the right
// ------------------------------

// convert set pixels in the map into the correct shadow char
.var htChar2 = Hashtable().put(0,0, 1,6, 2,2, 3,7, 4,4, 5,5, 6,3, 7,7)

.for (var version=0; version<4; version++) // loop over all chars
{
  .for (var r=0; r<8; r++)
  {
    .for (var c=1; c<mapWidth; c++)
    {
      // position in memory
      .var pos = ((version*8)+r)*mapWidth + c

      // read char at position
      .var char = map2.get(pos)

      // if it's empty, calculate the shadow
      .if (char == 0)
      {
        .var charL  = map2.get(pos - 1)
        .var charU  = 0
        .var charLU = 0
        .if (r>0)
        {
          .eval charU  = map2.get(pos - mapWidth)
          .eval charLU = map2.get(pos - mapWidth - 1)
        }

        .var value = 0
        .if (charL == 1) { .eval value = value+1 }
        .if (charU == 1) { .eval value = value+2 }
        .if (charLU== 1) { .eval value = value+4 }

        // convert map pixels into the correct char for this position
        .var result = htChar2.get(value)

        // convert into the correct shadow version
        .eval result = result + version * 16 + 128

        // plot into the map
        .eval map2.set(pos, result)
      }
    }
  }
}

// -------------------------------
// calculate shadows straight down
// -------------------------------

.for (var version=4; version<5; version++) // loop over all chars
{
  .for (var r=0; r<8; r++)
  {
    .for (var c=1; c<mapWidth; c++)
    {
      // position in memory
      .var pos = ((version*8)+r)*mapWidth + c

      // read char at position
      .var char = map2.get(pos)

      // if it's empty, calculate the shadow
      .if (char == 0)
      {
        .var charU  = 0
        .if (r>0)
        {
          .eval charU  = map2.get(pos - mapWidth)
        }

        .var result = 0
        .if (charU == 1) { .eval result = 3 }

        .eval result = result + version * 16 + 128

        .eval map2.set(pos, result)
      }
    }
  }
}

// ------------------------------
// calculate shadows to the right
// ------------------------------

.for (var version=5; version<9; version++) // loop over all chars
{
  .for (var r=0; r<8; r++)
  {
    .for (var c=0; c<(mapWidth-1); c++)
    {
      // position in memory
      .var pos = ((version*8)+r)*mapWidth + c

      // read char at position
      .var char = map2.get(pos)

      // if it's empty, calculate the shadow
      .if (char == 0)
      {
        .var charR  = map2.get(pos + 1)

        .var charU  = 0
        .var charRU = 0
        .if (r>0)
        {
          .eval charU  = map2.get(pos - mapWidth)
          .eval charRU = map2.get(pos - mapWidth + 1)
        }

        .var value = 0
        .if (charR == 1) { .eval value = value+1 }
        .if (charU == 1) { .eval value = value+2 }
        .if (charRU== 1) { .eval value = value+4 }

        // convert map pixels into the correct char for this position
        .var result = htChar2.get(value)

        // convert into the correct shadow version
        .eval result = result + (version-1) * 16 + 8 + 128

        // plot into the map
        .eval map2.set(pos, result)
      }
    }
  }
}

// ----------------------------------
// convert map into a virtual picture 
// ----------------------------------

.var pictureWidth2  = mapWidth * 4
.var pictureHeight2 = mapHeight * 8
.var picture2       = List(pictureWidth2 * pictureHeight2)

.for (var x=0; x<mapWidth; x++)
{
  .for (var y=0; y<mapHeight; y++)
  {
    // read char from map
    .var char = map2.get(y*mapWidth + x)
    
    // copy bytes into virtual picture
    .for (var byte=0; byte<8; byte++)
    {
      .var value  = shadowFont.get(char*8 + byte)

      .for (var shift=0; shift<4; shift++)
      {
        .eval picture2.set((y*8+byte)*pictureWidth2 + (shift*mapWidth) + x, value)
      }
    }
  }
}

// create shifted versions of picture
.for (var shift=1; shift<4; shift++)
{
  .for (var y=0; y<pictureHeight2; y++)
  {
    .for (var x=0; x<(mapWidth-1); x++)
    {
      // read values from previous shifted version
      .var value1 = picture2.get(y*pictureWidth2 + ((shift-1)*mapWidth) + x ) 
      .var value2 = picture2.get(y*pictureWidth2 + ((shift-1)*mapWidth) + x + 1) 

      // shift 2 pixels to the left and add the 2 left most pixels from next byte
      .var shifted = ((value1<<2) + (value2>>6)) & $ff

      // copy back into the picture
      .eval picture2.set(y*pictureWidth2 + (shift*mapWidth) + x, shifted)
    }
  }
}

// ----------------------------------------------
// calculate resulting charset and map for zoomer
// ----------------------------------------------

.var width2  = mapWidth * 4
.var height2 = mapHeight

// create the list with unique chars
.var emptyChar2   = List().add(0,0,0,0,0,0,0,0)  // the empty char is special
.var emptyCharString2 = "0000000000000000"
.var uniqueChars2 = List().addAll(emptyChar2)    // add empty char first
.var screenData2  = List()
.var ht2 = Hashtable()
.eval ht2.put(emptyCharString2, 0) // add empty char into hashtable

// fill screenData
.for (var i=0; i<width2*height2; i++) { .eval screenData2.add(0) }

.for (var r=0; r<height2; r++)
{
  .for (var c=0; c<width2; c++)
  {      
    // position
    .var pos = c+r*width2

    // read char
    .var char = List(8)
    .var charString = ""
    .for (var byte=0; byte<8; byte++)
    {
      .var value = picture2.get((r*8+byte)*width2 + c)
      //.var value = logo.getMulticolorByte(c,r*8+byte)
      .eval char.set(byte, value)
      .eval charString = charString + toHexString(value,2)
    }

    // is this a new char?
    .var i = ht2.get(charString)

    .if (i==null)
    {
      // this is a new char, add it
      .eval ht2.put(charString, uniqueChars2.size()/8) // add empty char into hashtable   

      // add char to the screen
      .eval screenData2.set(pos, uniqueChars2.size()/8)

      // add char to the charset
      .eval uniqueChars2.addAll(char)   
    } else {
      // add char to the screen
      .eval screenData2.set(pos, i)      
    }
  }
}

.print ("nrChars : " + uniqueChars2.size()/8)

// ---------------------------------
// 1.calculate protochars for zoomer
// 2.make a protochar map
// ---------------------------------

.var protoMap1b = List(mapWidth*8)
.for (var i=0; i<mapWidth*8; i++) { .eval protoMap1b.set(i,0) }
.var htProtoCharsb = Hashtable()

// calculate the protochars for the first shadow version
.for (var r=0; r<8; r++)
{
  .for (var c=0; c<mapWidth-2; c++)
  {
    // position
    .var pos  = c+r*width2    // use pos to read the shift 0 portion of screenData
    .var pos2 = c+r*mapWidth  // use pos2 to store into the protoMap
    
    // read the char
    .var char = screenData2.get(pos)

    // read char to the right
    .var char2 = screenData2.get(pos+1)

    // calculate proto char
    .var protoChar = (char2<<8) + char

    // check the hashtable
    .var i = htProtoCharsb.get(protoChar)
    
    // is this a new protochar?
    .if (i==null)
    {
      // add protochar to the map
      .eval protoMap1b.set(pos2, htProtoCharsb.keys().size())

      // put protochar in the hashtable
      .eval htProtoCharsb.put(protoChar, htProtoCharsb.keys().size())
    } else
    {
      // add protochar to the map
      .eval protoMap1b.set(pos2, i)      
    }
  }
}

.var conversionTableLength1b = floor(256/9)
.print ("nrProtoCharsb : " + conversionTableLength1b)


// ------------------------------------------------
// count the number of unique columns in protoMap1b
// ------------------------------------------------

.var uniqueColumns1b      = Hashtable()       // a hashtable with all unique columns
.var columns1b            = List()            // pointer for each column to a unique column
.var compressedProtoMap1b = List(mapWidth*8)  // compressed protomap, holding all the unique columns

.for (var c=0; c<mapWidth-2; c++)
{
  // convert column into a string with hexadecimal value
  .var columnString = ""
  .for (var r=0; r<8; r++)
  {
    // add hexadecimal value of next row to the string
    .eval columnString = columnString + toHexString(protoMap1b.get(c+r*mapWidth),2)
  }

  // is this a new column?
  .var i = uniqueColumns1b.get(columnString)

  .if (i==null)
  {
    // this is a new unique column    
    .eval i = uniqueColumns1b.keys().size()
    .eval columns1b.add(i)
    .eval uniqueColumns1b.put(columnString, i)

    // copy into the compressed map
    .for (var r=0; r<8; r++) { .eval compressedProtoMap1b.set(i+(r*mapWidth), protoMap1b.get(c+r*mapWidth)) }
  } else
  {
    .eval columns1b.add(i)
  }
}

.var nrUniqueColumns1b = uniqueColumns1b.keys().size()
.print ("nr unique columns : " + nrUniqueColumns1b)

// ------------------------------
// recalculate compressedProtoMap
// ------------------------------

{
  .var temp = List(nrUniqueColumns1b*8)
  .for (var r=0; r<8; r++) 
  {
    .for (var c=0; c<nrUniqueColumns1b; c++)
    {
      .eval temp.set(c+nrUniqueColumns1b*r, compressedProtoMap1b.get(c+mapWidth*r))
    }
  }

  .eval compressedProtoMap1b = temp
}

// ---------------------------------------
// make a map for shadows to the left also
// ---------------------------------------

.var protoMap2b = List(mapWidth*8)
.for (var i=0; i<mapWidth*8; i++) { .eval protoMap2b.set(i,0) }
.eval htProtoCharsb = Hashtable()

// calculate the protochars for the last shadow version
.for (var r=0; r<8; r++)
{
  .for (var c=0; c<mapWidth-2; c++)
  {
    // position
    .var pos  = c+(r+8*8)*width2    // use pos to read the shift 0 portion of screenData
    .var pos2 = c+r*mapWidth        // use pos2 to store into the protoMap
    
    // read the char
    .var char = screenData2.get(pos)

    // read char to the right
    .var char2 = screenData2.get(pos+1)

    // calculate proto char
    .var protoChar = (char2<<8) + char

    // check the hashtable
    .var i = htProtoCharsb.get(protoChar)
    
    // is this a new protochar?
    .if (i==null)
    {
      // add protochar to the map
      .eval protoMap2b.set(pos2, htProtoCharsb.keys().size())

      // put protochar in the hashtable
      .eval htProtoCharsb.put(protoChar, htProtoCharsb.keys().size())
    } else
    {
      // add protochar to the map
      .eval protoMap2b.set(pos2, i)      
    }
  }
}

.var conversionTableLength2b = floor(256/9)
.print ("nrProtoChars2b : " + conversionTableLength2b)

// ------------------------------------------------
// count the number of unique columns in protoMap2b
// ------------------------------------------------

.var uniqueColumns2b      = Hashtable()       // a hashtable with all unique columns
.var columns2b            = List()            // pointer for each column to a unique column
.var compressedProtoMap2b = List(mapWidth*8)  // compressed protomap, holding all the unique columns

.for (var c=0; c<mapWidth-2; c++)
{
  // convert column into a string with hexadecimal value
  .var columnString = ""
  .for (var r=0; r<8; r++)
  {
    // add hexadecimal value of next row to the string
    .eval columnString = columnString + toHexString(protoMap2b.get(c+r*mapWidth),2)
  }

  // is this a new column?
  .var i = uniqueColumns2b.get(columnString)

  .if (i==null)
  {
    // this is a new unique column    
    .eval i = uniqueColumns2b.keys().size()
    .eval columns2b.add(i)
    .eval uniqueColumns2b.put(columnString, i)

    // copy into the compressed map
    .for (var r=0; r<8; r++) { .eval compressedProtoMap2b.set(i+(r*mapWidth), protoMap2b.get(c+r*mapWidth)) }
  } else
  {
    .eval columns2b.add(i)
  }
}

.var nrUniqueColumns2b = uniqueColumns2b.keys().size()
.print ("nr unique columns : " + nrUniqueColumns2b)

// ------------------------------
// recalculate compressedProtoMap
// ------------------------------

{
  .var temp = List(nrUniqueColumns2b*8)
  .for (var r=0; r<8; r++) 
  {
    .for (var c=0; c<nrUniqueColumns2b; c++)
    {
      .eval temp.set(c+nrUniqueColumns2b*r, compressedProtoMap2b.get(c+mapWidth*r))
    }
  }

  .eval compressedProtoMap2b = temp
}


// ---------------------------------------------------
// calculate conversion tables from protoChar to chars
// ---------------------------------------------------

.var protoCharToChar1b = List() // a list to store all the conversion tables

// loop over all shift and shadow versions
.for (var shift=0; shift<4; shift++)
{
  .for (var shadow=0; shadow<9; shadow++)
  {
    .var convert = List(conversionTableLength1b)
    .for (var i=0; i<conversionTableLength1b; i++) { .eval convert.set(i,0) }

    .var htTest  = Hashtable()

    // loop over the test protomap
    .for (var r=0; r<8; r++)
    {
      .for (var c=0; c<mapWidth-2; c++)
      {
        // pointer to the screenData
        .var pos       = c+(shift*mapWidth)+(((shadow*8) + r)*width2)  // position in screenData
        .var pos2      = c+r*mapWidth                                  // position in testProtoMap

        .var protoChar = 0
        .if (shadow<=4) { .eval protoChar = protoMap1b.get(pos2) }     // read protochar
        else            { .eval protoChar = protoMap2b.get(pos2) }     // read protochar

        .var char      = screenData2.get(pos)                          // read char in screenData

        .var i = htTest.get(protoChar)  // test hashtable for protochar

        .if (i==null)
        {
          // put protochar in the hashtable
          .eval htTest.put(protoChar, char)

          // fill convert table
          .eval convert.set(protoChar, char) 
        }
        else
        {
          // if the protochar is already in the table...
          // does the protochar <-> char combination match?

          .var char2 = convert.get(protoChar)

          .if (char != char2)
          {
            .error ("aargh!!")
          }
        }
      }
    }
    .eval protoCharToChar1b.add(convert) // save conversion table
  }
}
