.const width            = 16  // height of portraits in chars
.const height           = 16  // height of portraits in chars

// load portrait graphics
.const KOALA_TEMPLATE = "C64FILE, Bitmap=$0000, ScreenRam=$1f40, ColorRam=$2328, BackgroundColor = $2710"

.var picture0 = LoadBinary("./includes/hammerfist.kla", KOALA_TEMPLATE)
.var picture1 = LoadBinary("./includes/genius.kla",     KOALA_TEMPLATE)
.var picture2 = LoadBinary("./includes/yoohouth.kla",   KOALA_TEMPLATE)
.var picture3 = LoadBinary("./includes/wvl.kla",        KOALA_TEMPLATE)

// read bitmaps and convert the data into a list so it can be dumped into memory

.function convertBitmap(picture)
{
  .var data = List()  // this is the list that will contain all the data
  .for (var c=0; c<width; c++) {
    .for (var r=0; r<height; r++) {
      .for (var b=7; b>=0; b--) {
        .var value = picture.getBitmap(b+c*8+r*320)
        .eval data.add(value)
      }
    }
  }

  .for (var r=0; r<height; r++) {
    .for (var c=0; c<width; c++) {
      .var value = picture.getScreenRam(c+r*40)
      .eval data.add(value)
    }
  }

  .for (var r=0; r<height; r++) {
    .for (var c=0; c<width; c++) {
      .var value = picture.getColorRam(c+r*40)
      .eval data.add(value)
    }
  }

  .return data
}

.var data0 = convertBitmap(picture0)
.var data1 = convertBitmap(picture1)
.var data2 = convertBitmap(picture2)
.var data3 = convertBitmap(picture3)