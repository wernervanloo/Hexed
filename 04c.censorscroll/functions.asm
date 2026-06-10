.const width  = 40*4
.var bitmap16 = List()

// this is a hastable to convert RGB into C64 color
.var c64Colors = Hashtable()

// this is my palette from paint.net

.eval c64Colors.put($000000,0  ,$ffffff, 1 ,$9C3D2E, 2 ,$72CCD7, 3,
                    $9A40C8,4  ,$63B930, 5 ,$3828B4, 6 ,$DBE95E, 7,
                    $9F6014,8  ,$634C00, 9 ,$D07769,10 ,$595959,11,
                    $868686,12 ,$AAFA7C,13 ,$8071FB,14 ,$B3B3B3,15)

// this is the palette used by hammerfist

.eval c64Colors.put($00000c,0,  $202020,0  ,$ffffff, 1 ,$68372B, 2 ,$70A4B2, 3,
                    $6F3D86,4  ,$588D43, 5 ,$352879, 6 ,$B8C76F, 7,
                    $6F4F25,8  ,$433900, 9 ,$9A6759,10 ,$444444,11,
                    $6C6C6C,12 ,$9AD284,13 ,$6C5EB5,14 ,$959595,15)


// this functions RLE compresses bitmapdata in a list
.function compress(data)
{
  .var compressed    = List()
  .var length        = data.size()
  .var nrLiteral     = 0  // nr of literals to copy
  .var startPosition = 0  // start position
  .var pos           = 0
  .const minRun      = 4
  .var loops         = 0  // count # of loops to protect against stuck compressor

  .while(pos < length)
  {
    // keep adding literals, until we have too many or we spot repeating bytes
    .var value = data.get(pos)

    // check how many equal bytes there are from this position
    .var run = 1
    .while (((pos+run)<length) && (value==(data.get(pos+run))) && (run<127)) { .eval run = run + 1 }

    // add a literal if the run is too short
    .if (run<minRun) 
    { 
      .eval nrLiteral = nrLiteral + 1 
      .eval pos = pos + 1
    }

    // flush literals to the output if:
    // - end of data OR 
    // - 127 literals OR 
    // - a run starts here
    .if ((nrLiteral>0) && ((pos==length) || (nrLiteral == 127) || (run>=minRun)))
    {
      .eval compressed.add(nrLiteral|$80)
      .for (var i=0; i<nrLiteral; i++) { .eval compressed.add(data.get(startPosition+i)) }

      .eval startPosition = startPosition+nrLiteral
      .eval nrLiteral = 0
    }

    // flush the run to the output
    .if (run>=minRun)
    {
      .eval compressed.add(run)
      .eval compressed.add(value)

      .eval startPosition = startPosition+run
    }

    .eval pos = startPosition+nrLiteral

    // count number of loops to see if there was a fatal error and everything is stuck
    .eval loops = loops + 1
    .if (loops >= length)
    {
      .error "compressor stuck"
    }
  } // while pos<length

  // add end of data marker
  .eval compressed.add(0)

  // return output
  .return compressed
}


// this functions calculates the skew needed to make the bitmap wrap
.function calcSkew(x)
{
    .var charX  = floor(x/4)                       // x position in chars
    .var skew  = 8-(x/20)

    .if ((x>=160) && (x<320)) {.eval skew = skew+8}
    .if ((x>=320) && (x<480)) {.eval skew = skew+16}
    .if ((x>=480) && (x<640)) {.eval skew = skew+24}

    .return skew
}

// this function plots colpixels into the protobitmap
.function plot(x, color, v1, v2, priority)
{
  .eval v1 = round(v1)
  .eval v2 = round(v2)

  .var yStart = min(v1, v2)
  .var yEnd   = max(v1, v2)

  .for (var y=yStart; y<yEnd; y++)
  {
    .if ((y<0) || (y>200)) 
    { 
      .print (y)
      .error "y range fail" 
    }

    // read current pixel
    .var i = (x + (width*4*y))

    .if ((priority == false) || (bitmap16.get(i)==-1))
    {
      .eval bitmap16.set(i, color) 
    } else 
    {
      // only plot if going up
      .if (v1<v2)
      {
        .eval bitmap16.set(i, color) 
      }      
    }
  }
}

// this function retrieves a pixel from the proto bitmap
.function getPixel(charX, charY, pixel)
{
  .return bitmap16.get(mod(pixel,4)+charX*4+width*4*((charY*8)+(floor(pixel/4))))
}

// this function plots a pixel into the proto bitmap
.function putPixel(charX, charY, pixel, color)
{
  .eval bitmap16.set(mod(pixel,4)+charX*4+width*4*((charY*8)+(floor(pixel/4))), color)
}

// this function checks if the given color is in the list of already used color
.function colorUsed(color, usedColors)
{
  .for (var c=0; c<usedColors.size(); c++)
  {
    .if (color == usedColors.get(c))
    {
      .return true
    }
  }

  .return false
}

// plot char
.function plotChar(x,y) 
{
  .print ("char: " + x + ", " + y)
  .for (var pixel=0; pixel<32; pixel=pixel+4)
  {
    .var color1 = getPixel(x, y, pixel+0)
    .var color2 = getPixel(x, y, pixel+1)
    .var color3 = getPixel(x, y, pixel+2)
    .var color4 = getPixel(x, y, pixel+3)
    .print ("- " + color1 + ", " + color2 + ", " + color3 + ", " + color4)
  }
}

.function columnExists(col, colList)
{
  .var sameColumn = -1
  .for (var i=0; i<colList.size(); i++)
  {
    .var same = true
    .var existingCol = colList.get(i)
    // check contents if sizes are the same
    .if (col.size() == existingCol.size())
    {
      .for (var j=0; (j<col.size()) && same; j++)
      {
        .if (col.get(j) != existingCol.get(j))
        {
          .eval same = false
        }
      }

      .if (same) { .eval sameColumn = i } // same column found!
    } else { .eval same = false }
  }

  .return sameColumn
}
