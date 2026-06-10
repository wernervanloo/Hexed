.function updateScreen(screen, nrChars)
{
  .for (var i=0; i<screen.size(); i++)
  {
    .var value = screen.get(i)
    .if (value >= 2) { .eval value = value - 2 + nrChars }
    .eval screen.set(i, value)
  }

  .return screen
}

.function plotPixel(bitmap, x, y)
{
  .if ((x<0) || (x>=320) || (y<0) || (y>=200)) { .return bitmap }

  .var position = floor(x/8)+y*40

  .var pixelPosition = x&7
  .var pixelValue = 128>>pixelPosition

  .eval bitmap.set(position, bitmap.get(position)|pixelValue)
  .return bitmap
}

.function plotPixels(bitmap, xc, yc, x, y)
{
  .eval bitmap = plotPixel(bitmap, xc+x, yc+y)
  .eval bitmap = plotPixel(bitmap, xc-x, yc+y)
  .eval bitmap = plotPixel(bitmap, xc+x, yc-y)
  .eval bitmap = plotPixel(bitmap, xc-x, yc-y)

  .eval bitmap = plotPixel(bitmap, xc+y, yc+x)
  .eval bitmap = plotPixel(bitmap, xc-y, yc+x)
  .eval bitmap = plotPixel(bitmap, xc+y, yc-x)
  .eval bitmap = plotPixel(bitmap, xc-y, yc-x)
  .return bitmap
}

.function drawCircle(bitmap,r)
{
  .var widths1 = List() // widths from octant 1
  .var widths2 = List() // widths from octant 2

  .var xc = 160
  .var yc = 100

  .var d = 3 - 2*r
  .var x = 0
  .var y = r

  .eval widths2.add(r)

  .eval plotPixels(bitmap, xc, yc, x, y)

  .while (y>x)
  {
    .eval x = x + 1
    .if (d>0) 
    {
      .eval y = y - 1
      .eval widths1.add(x-1)  // add widths to list

      .eval d = d + 4 * (x - y) + 10
    } else
    {
      .eval d = d + 4 * x + 6
    }

    .if (y>=x) { .eval widths2.add(y) }

    .eval plotPixels(bitmap, xc, yc, x, y)
  }
  
  .var widths = List().addAll(widths1)
  .for (var i=widths2.size()-1; i>=0; i-- ) { .eval widths.add(widths2.get(i)) }

  // fill in the circle
  .for (var i=0; i<=r; i++)
  {
    .var width = widths.get(i)

    .for (var x=0; x<width; x++)
    {
      .eval plotPixel(bitmap, xc+x, yc+r-i)
      .eval plotPixel(bitmap, xc-x, yc+r-i)

      .eval plotPixel(bitmap, xc+x, yc-r+i)
      .eval plotPixel(bitmap, xc-x, yc-r+i)
    }
  }

  .return bitmap
}

.function bitmapToChars(bitmap)
{
  // ------------------------------------
  // convert picture into charset and map
  // ------------------------------------

  // create the list with unique chars
  .var uniqueChars = List().add(0,0,0,0,0,0,0,0, $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff)    // add empty char first
  .var screenData   = List()

  .for (var r=0; r<25; r++)
  {
    .for (var c=0; c<40; c++)
    {      
      // read char
      .var char = List()
      .for (var byte=0; byte<8; byte++)
      {
        .var value = bitmap.get(c+(byte*40)+(r*320))
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
      }
    }
  }
  
  // return charset and screendata
  .var result = List()
  .eval result.add(uniqueChars, screenData)
  .return result
}

// this function replaces a char in the screen
.function replaceChars(screen, ht)
{
  .for (var i=0; i<screen.size(); i++)
  {
    .var value = screen.get(i)   // read char# in the screen
    .eval value = ht.get(value)  // replace with new char #
    .eval screen.set(i, value)   // place new char in screen
  }
  
  .return screen
}

// this function removes duplicates chars and modifies the new screen
.function addScreen(charset, charset2, screen)
{
  .var newCharset  = List()
  .var uniqueChars = Hashtable()
  .var replaceHt   = Hashtable()

  // add offset to screen
  .for (var i=0; i<screen.size(); i++) { .eval screen.set(i, screen.get(i) + (charset.size()/8)) }

  // add chars from charset2 to charset
  .for (var i=0; i<charset2.size(); i++) { .eval charset.add(charset2.get(i)) }

  // loop over the chars
  .for (var i=0; i<charset.size()/8; i++)
  {
    // read char and convert to string for hashmap
    .var char = ""
    .for (var b=0; b<8; b++)
    {
      .var value = charset.get(i*8+b)
      .eval char = char+toHexString(value, 2)
    }

    // char already in the table?
    .if (uniqueChars.get(char) == null)
    {
      // no.. add it

      // what is the new position in the charset?
      .var newChar = uniqueChars.keys().size()

      // add the new char to the hashtable
      .eval uniqueChars.put(char, newChar)

      // add it to the replace table
      .eval replaceHt.put(i, newChar)

      // add it to the new charset
      .for (var b=0; b<8; b++) { .eval newCharset.add(charset.get(i*8+b)) }
    } else
    {
      // this a a char we have seen before, add it to the replace table
      .eval replaceHt.put(i, uniqueChars.get(char))
    }
  }

  .eval screen = replaceChars(screen, replaceHt)
  .var result = List().add(newCharset, screen)
  .return result
}

// count number of unique chars in charset
.function countUnique(charset)
{
  .var uniqueChars = Hashtable()

  // loop over the chars
  .for (var i=0; i<charset.size()/8; i++)
  {
    // read char and convert to string for hashmap
    .var char = ""
    .for (var b=0; b<8; b++)
    {
      .var value = charset.get(i*8+b)
      .eval char = char+toHexString(value, 2)
    }

    // char already in the table?
    .if (uniqueChars.get(char) == null)
    {
      // no.. add it
      .eval uniqueChars.put(char, uniqueChars.keys().size())
    }
  }

  .return uniqueChars.keys().size()
}

// draw a circle and return charset and screen
.function testDraw(bitmap, r)
{
  .eval bitmap = drawCircle(bitmap, r)
  .var  result = bitmapToChars(bitmap)
  .eval result.add(bitmap)

  .return result
}