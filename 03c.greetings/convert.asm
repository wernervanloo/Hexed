#import "colors.asm"

.var lstGfx  = List()                         // make list to hold the converted graphics in the correct order
.var lstD021 = List()
.var lstD022 = List()
.var lstD023 = List()

//.var gfx = LoadPicture("./includes/vertical_logos_colored4.png") // set black as $d800
.var gfx = LoadPicture("./includes/element dist v0.127.png") // set black as $d800
.const nrRows = gfx.height / 8

.eval rowBitpairs = List() // empty list
.var errors = false
.var htUnknownRGB = Hashtable()

// determine the colors used in each row
.for (var r=0; r<nrRows; r++)                               // loop over all rows
{
  // add colors for the colortables
  .eval lstD021.add(0)
  .eval lstD022.add(0)
  .eval lstD023.add(0)

  .var colorsUsed   = List().add(fixedColor)                // list of the used colors (c64 values)
  .var htColorsUsed = Hashtable().put(fixedRGB,fixedColor)  // hashtable with the RGB values of the used colors
  .var bitValues    = Hashtable().put(fixedRGB, 3)          // fixed color = bitpair %11

  .for (var x=0; x<gfx.width; x++)               // loop over all pixels
  {
    .for (var y=(r*8); y<(r*8+8); y++)           // loop over the pixelrows in each charrow
    {
      .var color    = gfx.getPixel(x, y)         // read RGB value at position x,y 
      .if (color == 1052688) { .eval color = 0 } // Hammerfist uses an extra black sometimes.. replace this value by true black
      .if (color == 2105376) { .eval color = 0 } // Hammerfist uses an extra black sometimes.. replace this value by true black
      .if (color == 7171437) { .eval color = 7105644 }  // replace $6d6d6d with $6c6c6c
      .var c64Color = htColors.get(color)        // try to read the color from the used colors in this row by checking the RGB value

      .if (c64Color==null) 
      { 
        //.print("unknown RGB " + color + " at position " + x + ", " + y)
        .eval htUnknownRGB.put(color, 0)
        .eval errors = true 
      }

      // is this a new color?
      .if (htColorsUsed.get(color)==null) 
      { 
        .eval htColorsUsed.put(color, htColors.get(color))         // add the rgb value and c64 color to the hashtable
        .eval colorsUsed.add(htColors.get(color))                  // add the c64 color to colors used
        .var  bitpair = (bitValues.keys().size())-1                // bitpair = (number of items in the hashtable-1)
        .eval bitValues.put(color, bitpair)                        // add the bitpair for this RGB value

        .if (bitpair==0) { .eval lstD021.set(r,htColors.get(color))} // add d021 color
        .if (bitpair==1) { .eval lstD022.set(r,htColors.get(color))} // add d022 color
        .if (bitpair==2) { .eval lstD023.set(r,htColors.get(color))} // add d023 color

        .if (bitpair==3) { } //  .error("too many colors at position " + x + ", " + y + " (charrow " + floor(y/8) + ")")}
      }
    }
  }
  
  .if ((bitValues.keys().size()) > 4) 
  { 
    .print ("too many colors at y = " + r*8 + " (charrow " + r + "), " + colorsUsed)
    .eval errors = true 
  }

  .eval rowBitpairs.add(bitValues)    // store the bitpairs
}

.if (htUnknownRGB.keys().size() > 0)
{
  .print ("unknown RGB colors : " + htUnknownRGB.keys())
}

// convert graphics in the correct order

.for (var y=0; y<8; y++){                    // loop over pixel rows in each char row
  .for (var c=0; c<16; c++){                 // loop over columns
    .for (var r=0; r<nrRows; r++){           // loop over charrows
      .var bitValues = rowBitpairs.get(r)    // fetch the bitpairs for this row

      .var bitpair0 = bitValues.get(gfx.getPixel((c*4)+0, (r*8)+y))
      .var bitpair1 = bitValues.get(gfx.getPixel((c*4)+1, (r*8)+y))
      .var bitpair2 = bitValues.get(gfx.getPixel((c*4)+2, (r*8)+y))
      .var bitpair3 = bitValues.get(gfx.getPixel((c*4)+3, (r*8)+y))

      .if (bitpair0==null) { .eval bitpair0 = 0 }
      .if (bitpair1==null) { .eval bitpair1 = 0 }
      .if (bitpair2==null) { .eval bitpair2 = 0 }
      .if (bitpair3==null) { .eval bitpair3 = 0 }

      .var byte = bitpair0*64 + bitpair1*16 + bitpair2*4 + bitpair3
      .eval lstGfx.add(byte)
    }
  } 
}

