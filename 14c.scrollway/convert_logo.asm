.function convertPicture(logo)
{
  // create the list with unique chars
  .var emptyChar   = List().add(0,0,0,0,0,0,0,0)  // the empty chars is special
  .var uniqueChars = List().addAll(emptyChar)     // add empty char first
  .var screenData  = List()

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

      .if ((r+c)==0) { .print (char) }
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
          //.if (i==0) { .eval i=$ff } // special : use $ff as empty character
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

  .print ("nrChars : " + uniqueChars.size()/8)
  .var result = List().add(uniqueChars, screenData)
  .return result
}
