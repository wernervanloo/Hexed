#import "zoomscroll_general.asm"

// ----------------
// create empty map 
// ----------------

.var map = List(mapWidth * mapHeight)
.for (var i=0; i<map.size(); i++) { .eval map.set(i, 0) }

// -------------------
// plot chars into map 
// -------------------

.var x=1 // skip first pixel
.for (var i=0; i<text.size(); i++)        // loop over the text
{
  .eval startPositions.add(x-1)           // keep track of all start positions of letters in the map
  .var char = text.charAt(i)              // read char to plot
  .var charData = List()                  // read char data
  .var startPixel = startPixels.get(char) // first set pixel of the char to plot
  .var width      = widths.get(char)      // get width of char to plot

  // copy char into charData
  .for (var byte=0; byte<8; byte++) { .eval charData.add(font.get(char*8 + byte)) }

  // shift data left
  .for (var i=0; i<startPixel; i++) { .for (var byte=0; byte<8; byte++) { .eval charData.set(byte, charData.get(byte)<<1)} }

  // plot char
  .for (var i=0; i<width; i++)
  {
    .for (var byte=0; byte<8; byte++)
    {
      .var value  = charData.get(byte)
      .eval value = value << i

      // if the pixel is set, plot the pixel 9 times (for all shadow versions)
      .if ((value & 128)!=0) 
      { 
        .for (var s=0; s<9; s++) { .eval map.set( ( ((s*8)+byte) *mapWidth) + x + i, 1) }
      }
    }
  }

  // increase x position
  .eval x = x + width + 2
}

// ------------------------------
// calculate shadows to the right
// ------------------------------

// convert set pixels in the map into the correct shadow char
.var htChar = Hashtable().put(0,0, 1,6, 2,2, 3,7, 4,4, 5,5, 6,3, 7,7)

.for (var version=0; version<4; version++) // loop over all chars
{
  .for (var r=0; r<8; r++)
  {
    .for (var c=1; c<mapWidth; c++)
    {
      // position in memory
      .var pos = ((version*8)+r)*mapWidth + c

      // read char at position
      .var char = map.get(pos)

      // if it's empty, calculate the shadow
      .if (char == 0)
      {
        .var value = 0

        .var charL  = map.get(pos - 1)
        .var charD  = map.get(pos + mapWidth)
        .var charLD = map.get(pos + mapWidth - 1)

        .if (charL == 1) { .eval value = value+1 }
        .if (charD == 1) { .eval value = value+2 }
        .if (charLD== 1) { .eval value = value+4 }

        // convert map pixels into the correct char for this position
        .var result = htChar.get(value)

        // convert into the correct shadow version
        .eval result = result + version * 16

        // plot into the map
        .eval map.set(pos, result)
      }
    }
  }
}

// ------------------------------------------
// calculate shadows straight up (version==4)
// ------------------------------------------

.for (var version=4; version<5; version++) // loop over all chars
{
  .for (var r=0; r<8; r++)
  {
    .for (var c=1; c<mapWidth; c++)
    {
      // position in memory
      .var pos = ((version*8)+r)*mapWidth + c

      // read char at position
      .var char = map.get(pos)

      // if it's empty, calculate the shadow
      .if (char == 0)
      {
        .var charD  = map.get(pos + mapWidth)

        .var result = 0
        .if (charD == 1) { .eval result = 3 }

        .eval result = result + version * 16

        .eval map.set(pos, result)
      }
    }
  }
}

// -----------------------------
// calculate shadows to the left
// -----------------------------

.for (var version=5; version<9; version++) // loop over all chars
{
  .for (var r=0; r<8; r++)
  {
    .for (var c=0; c<(mapWidth-1); c++)
    {
      // position in memory
      .var pos = ((version*8)+r)*mapWidth + c

      // read char at position
      .var char = map.get(pos)

      // if it's empty, calculate the shadow
      .if (char == 0)
      {
        .var charR  = map.get(pos + 1)
        .var charD  = map.get(pos + mapWidth)
        .var charRD = map.get(pos + mapWidth + 1)

        .var value = 0
        .if (charR == 1) { .eval value = value+1 }
        .if (charD == 1) { .eval value = value+2 }
        .if (charRD== 1) { .eval value = value+4 }

        // convert map pixels into the correct char for this position
        .var result = htChar.get(value)

        // convert into the correct shadow version
        .eval result = result + (version-1) * 16 + 8

        // plot into the map
        .eval map.set(pos, result)
      }
    }
  }
}

// -------------------------------------------
// convert map into a virtual (bitmap) picture 
// -generate 4 versions, each shifted 1 pixel
// -------------------------------------------

.var pictureWidth  = mapWidth * 4
.var pictureHeight = mapHeight * 8
.var picture       = List(pictureWidth * pictureHeight)

.for (var x=0; x<mapWidth; x++)
{
  .for (var y=0; y<mapHeight; y++)
  {
    // read char from map
    .var char = map.get(y*mapWidth + x)
    
    // copy (unshifted) bytes into virtual picture
    .for (var byte=0; byte<8; byte++)
    {
      .var value  = shadowFont.get(char*8 + byte)

      .for (var shift=0; shift<4; shift++)
      {
        .eval picture.set((y*8+byte)*pictureWidth + (shift*mapWidth) + x, value)
      }
    }
  }
}

// create shifted versions of picture
.for (var shift=1; shift<4; shift++)
{
  .for (var y=0; y<pictureHeight; y++)
  {
    .for (var x=0; x<(mapWidth-1); x++)
    {
      // read values from previous shifted version
      .var value1 = picture.get(y*pictureWidth + ((shift-1)*mapWidth) + x ) 
      .var value2 = picture.get(y*pictureWidth + ((shift-1)*mapWidth) + x + 1) 

      // shift 2 pixels to the left and add the 2 left most pixels from next byte
      .var shifted = ((value1<<2) + (value2>>6)) & $ff

      // copy back into the picture
      .eval picture.set(y*pictureWidth + (shift*mapWidth) + x, shifted)
    }
  }
}

// ----------------------------------------------
// calculate resulting charset and map for zoomer
// ----------------------------------------------

.var width  = mapWidth * 4
.var height = mapHeight

// create the list with unique chars
.var emptyChar   = List().add(0,0,0,0,0,0,0,0)  // the empty char is special
.var emptyCharString = "0000000000000000"
.var uniqueChars = List().addAll(emptyChar)     // add empty char first
.var screenData  = List(); .for (var i=0; i<width*height; i++) { .eval screenData.add(0) }
.var ht = Hashtable().put(emptyCharString, 0)   // add empty char into hashtable, string "0000000000000000" matches to char 0

.for (var r=0; r<height; r++)
{
  .for (var c=0; c<width; c++)
  {      
    // position
    .var pos = c+r*width

    // read char
    .var char = List(8)
    .var charString = ""
    .for (var byte=0; byte<8; byte++)
    {
      .var value = picture.get((r*8+byte)*width + c)
      .eval char.set(byte, value)
      .eval charString = charString + toHexString(value,2)
    }

    // is this a new char?
    .var i = ht.get(charString)

    .if (i==null)
    {
      // this is a new char, add it
      .eval ht.put(charString, uniqueChars.size()/8) // add empty char into hashtable   

      // add char to the screen
      .eval screenData.set(pos, uniqueChars.size()/8)

      // add char to the charset
      .eval uniqueChars.addAll(char)   
    } else {
      // add char to the screen
      .eval screenData.set(pos, i)      
    }
  }
}

.print ("nrChars : " + uniqueChars.size()/8)

// ------------------------------------------------------
// 1.calculate protochars for zoomer
// 2.make a protochar map
// protochars are combinations of a char and the char
// next to it. Each unique combination is a new protochar
// ------------------------------------------------------

.var protoMap1 = List(mapWidth*8); .for (var i=0; i<mapWidth*8; i++) { .eval protoMap1.set(i,0) }
.var htProtoChars = Hashtable()

// calculate the protochars for the first shadow version
.for (var r=0; r<8; r++)
{
  .for (var c=0; c<mapWidth-2; c++)
  {
    // position
    .var pos  = c+r*width     // use pos to read the shift 0 portion of screenData
    .var pos2 = c+r*mapWidth  // use pos2 to store into the protoMap
    
    // read the char
    .var char = screenData.get(pos)

    // read char to the right
    .var char2 = screenData.get(pos+1)

    // calculate proto char
    .var protoChar = (char2<<8) + char

    // check the hashtable
    .var i = htProtoChars.get(protoChar)
    
    // is this a new protochar?
    .if (i==null)
    {
      // add protochar to the map
      .eval protoMap1.set(pos2, htProtoChars.keys().size())

      // put protochar in the hashtable
      .eval htProtoChars.put(protoChar, htProtoChars.keys().size())
    } else
    {
      // add protochar to the map
      .eval protoMap1.set(pos2, i)      
    }
  }
}

.var conversionTableLength1 = floor(256/9)
.print ("nrTestProtoChars : " + conversionTableLength1)

// -----------------------------------------------
// count the number of unique columns in protoMap1
// -----------------------------------------------

.var uniqueColumns1      = Hashtable()       // a hashtable with all unique columns
.var columns1            = List()            // pointer for each column to a unique column
.var compressedProtoMap1 = List(mapWidth*8)  // compressed protomap, holding all the unique columns

.for (var c=0; c<mapWidth-2; c++)
{
  // convert column into a string with hexadecimal value
  .var columnString = ""
  .for (var r=0; r<8; r++)
  {
    // add hexadecimal value of next row to the string
    .eval columnString = columnString + toHexString(protoMap1.get(c+r*mapWidth),2)
  }

  // is this a new column?
  .var i = uniqueColumns1.get(columnString)

  .if (i==null)
  {
    // this is a new unique column    
    .eval i = uniqueColumns1.keys().size()
    .eval columns1.add(i)
    .eval uniqueColumns1.put(columnString, i)

    // copy into the compressed map
    .for (var r=0; r<8; r++) { .eval compressedProtoMap1.set(i+(r*mapWidth), protoMap1.get(c+r*mapWidth)) }
  } else
  {
    .eval columns1.add(i)
  }
}

.var nrUniqueColumns1 = uniqueColumns1.keys().size()
.print ("nr unique columns : " + nrUniqueColumns1)

// ------------------------------
// recalculate compressedProtoMap
// ------------------------------

{
  .var temp = List(nrUniqueColumns1*8)
  .for (var r=0; r<8; r++) 
  {
    .for (var c=0; c<nrUniqueColumns1; c++)
    {
      .eval temp.set(c+nrUniqueColumns1*r, compressedProtoMap1.get(c+mapWidth*r))
    }
  }

  .eval compressedProtoMap1 = temp
}

// ---------------------------------------
// make a map for shadows to the left also
// ---------------------------------------

.var protoMap2 = List(mapWidth*8); .for (var i=0; i<mapWidth*8; i++) { .eval protoMap2.set(i,0) }
.eval htProtoChars = Hashtable()

// calculate the protochars for the last shadow version
.for (var r=0; r<8; r++)
{
  .for (var c=0; c<mapWidth-2; c++)
  {
    // position
    .var pos  = c+(r+8*8)*width     // use pos to read the shift 0 portion of screenData
    .var pos2 = c+r*mapWidth        // use pos2 to store into the protoMap
    
    // read the char
    .var char = screenData.get(pos)

    // read char to the right
    .var char2 = screenData.get(pos+1)

    // calculate proto char
    .var protoChar = (char2<<8) + char

    // check the hashtable
    .var i = htProtoChars.get(protoChar)
    
    // is this a new protochar?
    .if (i==null)
    {
      // add protochar to the map
      .eval protoMap2.set(pos2, htProtoChars.keys().size())

      // put protochar in the hashtable
      .eval htProtoChars.put(protoChar, htProtoChars.keys().size())
    } else
    {
      // add protochar to the map
      .eval protoMap2.set(pos2, i)      
    }
  }
}

.var conversionTableLength2 = floor(256/9)
.print ("nrTestProtoChars2 : " + conversionTableLength2)

// -----------------------------------------------
// count the number of unique columns in protoMap2
// -----------------------------------------------

.var uniqueColumns2      = Hashtable()       // a hashtable with all unique columns
.var columns2            = List()            // pointer for each column to a unique column
.var compressedProtoMap2 = List(mapWidth*8)  // compressed protomap, holding all the unique columns
.for (var c=0; c<mapWidth-2; c++)
{
  // convert column into a string with hexadecimal value
  .var columnString = ""
  .for (var r=0; r<8; r++)
  {
    // add hexadecimal value of next row to the string
    .eval columnString = columnString + toHexString(protoMap2.get(c+r*mapWidth),2)
  }

  // is this a new column?
  .var i = uniqueColumns2.get(columnString)

  .if (i==null)
  {
    // this is a new unique column    
    .eval i = uniqueColumns2.keys().size()
    .eval columns2.add(i)
    .eval uniqueColumns2.put(columnString, i)

    // copy into the compressed map
    .for (var r=0; r<8; r++) { .eval compressedProtoMap2.set(i+(r*mapWidth), protoMap2.get(c+r*mapWidth)) }
  } else
  {
    .eval columns2.add(i)
  }
}

.var nrUniqueColumns2 = uniqueColumns2.keys().size()
.print ("nr unique columns : " + nrUniqueColumns2)

// ------------------------------
// recalculate compressedProtoMap
// ------------------------------

{
  .var temp = List(nrUniqueColumns2*8)
  .for (var r=0; r<8; r++) 
  {
    .for (var c=0; c<nrUniqueColumns2; c++)
    {
      .eval temp.set(c+nrUniqueColumns2*r, compressedProtoMap2.get(c+mapWidth*r))
    }
  }

  .eval compressedProtoMap2 = temp
}

// ---------------------------------------------------
// calculate conversion tables from protoChar to chars
// ---------------------------------------------------

.var protoCharToChar1 = List() // a list to store all the conversion tables

// loop over all shift and shadow versions
.for (var shift=0; shift<4; shift++)
{
  .for (var shadow=0; shadow<9; shadow++)
  {
    .var convert = List(conversionTableLength1)
    .for (var i=0; i<conversionTableLength1; i++) { .eval convert.set(i,0) }
    .var htTest  = Hashtable()

    // loop over the protomap
    .for (var r=0; r<8; r++)
    {
      .for (var c=0; c<mapWidth-2; c++)
      {
        // pointer to the screenData
        .var pos       = c+(shift*mapWidth)+(((shadow*8) + r)*width)  // position in screenData
        .var pos2      = c+r*mapWidth                                 // position in protoMap

        .var protoChar = 0
        .if (shadow<=4) { .eval protoChar = protoMap1.get(pos2) }     // read protochar
        else            { .eval protoChar = protoMap2.get(pos2) }     // read protochar

        .var char = screenData.get(pos)                               // read char in screenData

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
    .eval protoCharToChar1.add(convert) // save conversion table
  }
}
