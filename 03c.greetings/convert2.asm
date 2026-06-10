#import "colors.asm"

.var lstGfxb  = List()                         // make list to hold the converted graphics in the correct order
.var lstD021b = List()
.var lstD022b = List()
.var lstD023b = List()

//.var gfxb = LoadPicture("./includes/element54.png")
.var gfxb = LoadPicture("./includes/element dist v0.192.png")
.const nrRowsb = gfxb.height / 8

.print ("start gfx has " + nrRowsb + " rows of gfx")

.eval rowBitpairs = List() // empty list
.var errorsb = false
.var htUnknownRGBb = Hashtable()

.var grahamData   = List() // gahamified data

// determine the colors used in each row
.for (var r=0; r<nrRowsb; r++)                               // loop over all rows
{
  // add colors for the colortables
  .eval lstD021b.add(0)
  .eval lstD022b.add(0)
  .eval lstD023b.add(0)

  .var colorsUsed   = List().add(fixedColor)                // list of the used colors (c64 values)
  .var htColorsUsed = Hashtable().put(fixedRGB,fixedColor)  // hashtable with the RGB values of the used colors
  .var bitValues    = Hashtable().put(fixedRGB, 3)          // fixed color = bitpair %11

  .for (var x=0; x<gfxb.width; x++)            // loop over all pixels
  {
    .for (var y=(r*8); y<(r*8+8); y++)         // loop over the pixelrows in each charrow
    {
      .var color    = gfxb.getPixel(x, y)      // read RGB value at position x,y 
      .if (color == 1052688) { .eval color = 0 } // Hammerfist uses an extra black sometimes.. replace this value by true black
      .if (color == 2105376) { .eval color = 0 } // Hammerfist uses an extra black sometimes.. replace this value by true black
      .if (color == 7171437) { .eval color = 7105644 }  // replace $6d6d6d with $6c6c6c
      .var c64Color = htColors.get(color)      // try to read the color from the used colors in this row by checking the RGB value

      .if (c64Color==null) 
      { 
        //.print("unknown RGB " + color + " at position " + x + ", " + y)
        .eval htUnknownRGBb.put(color, 0)
        .eval errorsb = true 
      }

      // is this a new color?
      .if (htColorsUsed.get(color)==null) 
      { 
        .eval htColorsUsed.put(color, htColors.get(color))    
        .eval colorsUsed.add(htColors.get(color))                  // add the c64 color to colors used
        .var  bitpair = (bitValues.keys().size())-1                // bitpair = (number of items in the hashtable-1)
        .eval bitValues.put(color, bitpair)                        // add the bitpair for this RGB value

        .if (bitpair==0) { .eval lstD021b.set(r,htColors.get(color))} // add d021 color
        .if (bitpair==1) { .eval lstD022b.set(r,htColors.get(color))} // add d022 color
        .if (bitpair==2) { .eval lstD023b.set(r,htColors.get(color))} // add d023 color

        .if (bitpair==3) { } //  .error("too many colors at position " + x + ", " + y + " (charrow " + floor(y/8) + ")")}
      } 
    }
  }

  .if ((bitValues.keys().size()) > 4) 
  { 
    .print ("too many colors at y = " + r*8 + " (charrow " + r + "), " + colorsUsed)
    .eval errorsb = true 
  }

  .eval rowBitpairs.add(bitValues)    // store the bitpairs
}

.if (htUnknownRGBb.keys().size() > 0)
{
  .print ("unknown RGB colors : " + htUnknownRGBb.keys())
}

// convert graphics in the correct order

.for (var r=0; r<nrRowsb; r++){              // loop over charrows

  .var rowData = List()                      // data for this charrow

  .for (var c=0; c<16; c++){                 // loop over columns
    .for (var y=0; y<8; y++){                // loop over pixel rows in each char row
      .var bitValues = rowBitpairs.get(r)    // fetch the bitpairs for this row

      .var bitpair0 = bitValues.get(gfxb.getPixel((c*4)+0, (r*8)+y))
      .var bitpair1 = bitValues.get(gfxb.getPixel((c*4)+1, (r*8)+y))
      .var bitpair2 = bitValues.get(gfxb.getPixel((c*4)+2, (r*8)+y))
      .var bitpair3 = bitValues.get(gfxb.getPixel((c*4)+3, (r*8)+y))

      .if (bitpair0==null) { .eval bitpair0 = 0 }
      .if (bitpair1==null) { .eval bitpair1 = 0 }
      .if (bitpair2==null) { .eval bitpair2 = 0 }
      .if (bitpair3==null) { .eval bitpair3 = 0 }

      .var byte = bitpair0*64 + bitpair1*16 + bitpair2*4 + bitpair3
      .eval rowData.add(byte)
    }
  } 

  // now grahamify the data

  .for (var c=0; c<16; c++) {
    // convert into 1st char
    .for (var y=0; y<8; y++) {
      .var value1 = rowData.get(y+c*8)

      .eval grahamData.add(value1)
    }
    // convert into 2nd char
    .for (var y=0; y<8; y++) {
      .var value1 = rowData.get(y+c*8)
      .var value2 = rowData.get(y+(mod(c+1,16))*8)

      .var value = (((value1<<2)&$ff) + ((value2>>6)&$ff))&$ff
      .eval grahamData.add(value)
    }
    // convert into 2nd char
    .for (var y=0; y<8; y++) {
      .var value1 = rowData.get(y+c*8)
      .var value2 = rowData.get(y+(mod(c+1,16))*8)

      .var value = (((value1<<4)&$ff) + ((value2>>4)&$ff))&$ff
      .eval grahamData.add(value)
    }
    // convert into 3rd char
    .for (var y=0; y<8; y++) {
      .var value1 = rowData.get(y+c*8)
      .var value2 = rowData.get(y+(mod(c+1,16))*8)

      .var value = (((value1<<6)&$ff) + ((value2>>2)&$ff))&$ff

      .eval grahamData.add(value)
    }
  }
}

.print(lstD021b)
.print(lstD022b)
.print(lstD023b)
