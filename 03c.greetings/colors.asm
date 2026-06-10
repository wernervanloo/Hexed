#importonce

.const fixedColor = 0  // this is the fixed $d800 color

// Hammerfist palettes
.var  htColors = Hashtable().put($000000, 0)
.eval htColors.put($ffffff, 1)
.eval htColors.put($68372B, 2)
.eval htColors.put($70A4B2, 3)
.var cyanRGB = $70A4B2
.eval htColors.put($6F3D86, 4)
.eval htColors.put($588D43, 5)
.eval htColors.put($352879, 6)
.var blueRGB = $352879
.eval htColors.put($B8C76F, 7)
.eval htColors.put($6F4F25, 8)
.eval htColors.put($433900, 9)
.eval htColors.put($9A6759,10)
.eval htColors.put($444444,11)
.eval htColors.put($6C6C6C,12)
.eval htColors.put($9AD284,13)
.eval htColors.put($6C5EB5,14)
.var lightBlueRGB = $6C5EB5
.eval htColors.put($959595,15)
.var htKeys = htColors.keys()   // list with all RGB values

// what is the RGB value of the backgroundcolor?
.var fixedRGB = 0; .for (var c=0; c<16; c++) {  .if (fixedColor==htColors.get(htKeys.get(c))) { .eval fixedRGB = htKeys.get(c) } }

// list of the hashtables to convert RGB to bitpair
.var rowBitpairs = List()