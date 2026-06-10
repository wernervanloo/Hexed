#importonce

//.const fontFile       = LoadBinary("./includes/romfont_lower.bin")        // font to make charmap from
//.const fontFile       = LoadBinary("./includes/romfont_test.bin")         // font to make charmap from
.const fontFile       = LoadBinary("./includes/charset_murder.bin")         // font to make charmap from
.const shadowFontFile = LoadBinary("./includes/charset_pfp.bin")            // charset from pearls for pigs
//.const shadowFontFile = LoadBinary("./includes/romfont.bin")              // charset from pearls for pigs
.var text             = " abcdefghijklmnopqrstuvwxyz.,!?-=*/0123456789#[%"  // chars that go into the charmap
.eval text = text + $22  // I don't remember why I did this.

.var widths         = List()                                          // width of each char 
.var startPixels    = List()                                          // first used pixel in char
.var startPositions = List()                                          // start positions of letters in the map

// copy file into list
.var font = List()
.for (var i=0; i<fontFile.getSize(); i++) { .eval font.add($ff & fontFile.get(i)) }

.var shadowFont = List()
.for (var i=0; i<shadowFontFile.getSize(); i++) { .eval shadowFont.add($ff & shadowFontFile.get(i)) }

// -----------------------------
// calculate widths of each char
// -----------------------------

.for(var c=0; c<font.size()/8; c++)
{
  .var setPixels  = 0
  .for (var byte=0; byte<8; byte++) { .eval setPixels = setPixels | font.get(c*8 + byte) }

  .var startPixel = 0
  .var endPixel   = 7

    // we start checking on the right to find the first set pixel on the right
  .for (var bit=0; bit<8; bit++)
  {
    .if ((setPixels & (1<<bit))==0) { .eval endPixel-- }
    .if ((setPixels & (1<<bit))!=0) { .eval bit=8      }       
  }

  .for (var bit=7; bit>=0; bit--)
  {
    // we start checking on the left to find the first set pixel on the left
    .if ((setPixels & (1<<bit))==0) { .eval startPixel++ }
    .if ((setPixels & (1<<bit))!=0) { .eval bit=-1       }       
  }

  // empty char? set a width
  .if (endPixel == -1)
  {
    .eval startPixel = 0
    .eval endPixel   = 3
  }

  .eval widths.add(endPixel - startPixel + 1)
  .eval startPixels.add(startPixel)
}


// ------------------------------------------------------------------------
// remap the widths of all chars to the codes that are used in the scroller
// -> in the scroller, the codes are different than in a normal petscii 
// ------------------------------------------------------------------------

.var cmax = 0
.for (var i=0; i<text.size(); i++) { .eval cmax = max(cmax, charToByte(text.charAt(i))) }
.var widthsScroller = List(cmax+1); .for (var i=0; i<widthsScroller.size(); i++) { .eval widthsScroller.set(i,0) }
.for (var i=0; i<text.size(); i++) { .eval widthsScroller.set(charToByte(text.charAt(i)), 2+widths.get(text.charAt(i))) }

// ---------------------------------
// calculate width and height of map
// ---------------------------------

// calculate width of map needed for text
.var mapWidth  = 3      // 1 pixel at the left and 1 right for shadows. 1 to fit the shifts
.var mapHeight = 8*9+1  // one char is 8 pixels high and there are 9 different shadows. +1 pixel for the bottom

// calculate width of map
.for (var i=0; i<text.size(); i++)  // loop over the wanted text
{
  // read char
  .var char = text.charAt(i)
  .eval mapWidth = mapWidth + widths.get(char)

  // add 2 empty pixels between chars
  .if (i<(text.size()-1)) { .eval mapWidth = mapWidth + 2 }
}

.function charToByte(c)
{
  .if ((c >= 'a') && (c<='z')) { .return c }
  .if (c == ' ')               { .return 0 }
  .if (c == '.')               { .return 27 }
  .if (c == ',')               { .return 28 }
  .if (c == '!')               { .return 29 }
  .if (c == '?')               { .return 30 }
  .if (c == '-')               { .return 31 }
  .if (c == '=')               { .return 32 }
  .if (c == '*')               { .return 33 }
  .if (c == '/')               { .return 34 }
  .if ((c >= '0') && (c<='9')) { .return c-13 }  // '0' = 48 -> 35
  .if (c == '#')               { .return 45 }
  .if (c == '[')               { .return 46 }
  .if (c == '%')               { .return 47 }    // this is actually ' char

  // the following are not real characters, but are used to control the part
  .if (c == 'A')               { .return $80 }  // scroller 1 speed 2
  .if (c == 'B')               { .return $81 }  // scroller 1 speed 3
  .if (c == 'C')               { .return $82 }  // scroller 1 speed 4
  .if (c == 'D')               { .return $83 }  // turn on zoom scroller 1
  .if (c == 'E')               { .return $84 }  // turn on scroller 2
  .if (c == 'F')               { .return $85 }  // go to 2nd part of movement

  .if (c == 'G')               { .return $86 }  // not used

  .if (c == '@')               { .return $ff }  // end of scrolltext
}