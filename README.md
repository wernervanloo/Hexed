## introduction

This is the sourcecode for the C64 demo "Hexed" by Element54 using LFT's excellent Spindle trackmo system. This demo was made by WVL of Xenon (code), Hammerfist of Desire (art), Youth of Heatwave (music) and Genius of Xenon (residual graphics). You might have noticed that the 54th element in the periodic table is Xenon.

# contents

This readme contains the following chapters.

1. Compiling
2. How effects work
3. Spindle
4. Finally

# 1. Compiling
## prerequisites

To compile the demo and generate a .d64 you will need the following installed on your pc:

- [Kickassembler](https://theweb.dk/KickAssembler/) v5.25 (or higher) by Mads Nielsen,
- Java in order to run Kickassembler. The current version of Kickassembler needs at least version 8.0,
- the demo is linked with the [Spindle v3.1 trackmo system by LFT](https://www.linusakesson.net/software/spindle/v3.php),
- everything that is needed to run make on your system

## environment

In order to compile the demo you need to provide the locations of these dependencies in the `environment.mk` file, which is in the `@.Spindle` directory.

You will need to set at least the locations for the following variables: 
- JAVA (the java executable)
- KA_JAR (the kickassembler jar file)
- SPINDLE_BIN_DIR (the directory that holds the spindle binaries, in my case for Windows)

When compiling the demo, it will start the demo in VICE at the end. You will have to set the X64 variable correctly for this.

The makefile also has to possibility to build a diskside and send it to a C64 ultimate that is connected to the network. You will have to setup the IP adress for this to work in the 'ULTIMATE_API' parameter in your environment.mk.

## compiling

The demo-spanning files are in the `@.Spindle` directory. You can compile the demo with `make' using the makefile in the `@.Spindle` directory. The separate sourcefiles will be compiled and linked with Spindle, according to the script files. 'script1.txt' describes the parts on the first diskimage and 'script2.txt' describes the second diskimage of the demo. It is possible to build disksides seperately with 'make vice1' building diskside 1 and 'make vice2' building diskside2.

Spindle will 'enhance' the resulting diskimages with dirart from two .d64's that are located in the dirart directory.

## running parts separately

Most parts (except some which are only used for linking) can be compiled and run as a separate part. I do not use the facilities that Spindle supplies for this, but compile them directly from Visual Code with the [8-bit retro studio extension](https://marketplace.visualstudio.com/items?itemName=paulhocker.kick-assembler-vscode-ext) by Paul Hocker. 
If you compile parts separately with the makefiles in the directories, you will not get a runnable prg file since the parts will be compiled with the AS_SPINDLE_PART flag and components needed to run standalone will be missing.

You should be able to compile the parts separately using kickassembler from the commandline and generate a runnable .prg file like so :

`java -jar KickAss.jar main.asm`

Some compiled parts will need an emulated cartridge in X64sc.exe to be able to load the prg correctly, since they can occupy memory ranges above $d000. For some parts there is a crunch.bat file in the directory, which will crunch the effect (to avoid the $d000 limit) using tscrunch to make a standalone prg that can be loaded on any C64. The resulting .prg will be copied to the '\prg' directory. Note the neat trick to avoid having to update 'crunch.bat' with the correct start address by adding some startup code directly after the BasicUpStart2. This way tscrunch can always jump to $080e to start the part.

~~~
:BasicUpstart2(quickstart); quickstart: sei; lda #$35; sta $01; jmp start
~~~

## boogiebars - precalced binaries

The boogiebars part needs special precalculated binaries with a charset and a couple of tables. The charset is split into two parts (charset1.bin and charset2.bin) since it is interleaved in memory with screendata. These binaries are calculated by a small C++ program called 'kefrens sim'. This is a Visual Studio solution and the code generates all possible chars needed to draw the kefrens bars on the screen plus the tables ('waswordt0.bin' to 'waswordt17.bin') needed to select the correct chars to draw. It only needs to be run once and it will generate all the binaries inside the .\includes directory of boogiebars.

The effect needs two versions of the binary blobs. The version for the normal Kefrens bars are created when the boolean 'pills' is set to false. The binaries for the fatter bars are created when 'pills' is set to true. The boolean is called pills because we had a different shape in mind at first.

# 2. How effects work (this is where the magic is)

These explanations are meant to broadly give some understanding about the effects, but do not go into the details. 

## bitmap split (basic fader)

The demo opens with this effect that slowly reveals a bitmap picture in the middle of the basic screen. At the start the basic screen is converted into a hires bitmap screen. Then the effect basically is a horizontal split over the whole screen between the generated single color bitmap ($d016 = $c8), the multicolor bitmap ($d016 = $d8) and (again) the single color bitmap. In normal lines this is not a problem, but you can't do a split in badlines. And neither can I. As the colors on the screen show, there clearly are badlines, so how can that be? The answer is ofcourse that there are badlines and they are not split. Instead, the effect carefully prepares the hires bitmap screen (with the basic text) to be compatible with multicolor mode in 1 line (the badline). The normal basic font has an empty line in the lowest pixelrow. It would be good to have that empty line on the top row (the badline). And this is exactly how the bitmap is prepared : the bitmap is scrolled one pixel up and the font is scrolled one pixel down. This way the badline is mostly in this empty pixelrow and is not causing problems anymore. There are still some chars that will give trouble. To fix that, the effect uses a carefully crafted font with some characters shifted. The bounce in the beginning hides this swap from the viewer. A real magicians trick.

This fade was inspired by the basic fader from the demo 'The shores of reflection' by Shape that scrolls a 40 chars wide hires bitmap picture. A pretty subtle fader, but amazing if you know the VIC-II.

## greetings

This is a 'normal' Graham char zoomer, but with an incredibly large picture. The base picture is 16 chars wide (128 pixels or 64 multicolor pixels) and 256 chars (2048 pixels or a little over 10 screens(!) high). The graphics can cover a little over 4 complete screens (16*256 = 4096, which is a bit over 4000 chars for 4 screens). The effect calculates all the 'Graham' chars in realtime which is what is really new. The maximum scrollspeed the part can sustain is 4 pixels/frame. The graphics can have 3 unique colors for every charrow and are converted from a .png with a KickAss script. When moving, every row on the screen is different, so the whole screen gets recalculated every frame. The effect slows down on every greeting for readability, not for calculating. Also the effect does not have to load extra data during runtime. 

When the part starts, the 'Graham' charsets are already occupied with data, giving another 24 char rows of data (+ 2 empty rows), giving a total of 24+256 = 280 rows without loading.

## mega wide censorscroller

This is a color cycler scroller like the one from ['Daah, Those Acid Pills!'](https://csdb.dk/release/?id=118639) by Censor Design. I always wanted to make a scroller like this, so here we go. These scrollers work by scrolling a precalculated bitmap horizontally to the right (and moving it up by 1 pixel after moving it to the right by 40 pixels so the picture wraps). The bitmap contains 16 horizontal 'bands', in which the effect plots colors to show the text. The scrolling to the right makes the letters 'warp'. Now this specific 'Censor' scroller is a bit different than any I have seen. First, it does not use a bitmap that's 40 chars wide, but a bitmap that's 160 chars (4 screens) wide. With the extra width, it's possible to add multiple movements like the wobble and a super nice swirl effect at the same time. The swirl alone is 2 bitmaps wide and connects to a wobble that is about 1 screen wide. The areas that morph the swirl into the wobble are both around 0.5 screens wide.

The bitmaps are calculated by the KickAss script and stored into Lists. The data in the lists is then compressed by another part of the KickAss script and then stored into memory. The script also generates very optimzed speedcode for the plotting. Whenever the bitmap has scrolled 8 pixels to the right, a new column of bitmap graphics is decompressed and copied to the screen.

What's also very nice (and new? I'm not sure) is that the part can add (multiple) colorcyclers to the colorcycle. The font can have fixed colors, but also pixels that are part of a colorcycle. Here, the inside of the letters have a cycle that moves one way and the rim has a different colorcyle. Very stylish. The effect also used to have a colorcycle in a colorcyle in the colorcycler. It was too crazy and I removed it (try imaging how that would look).

### fader before censorscroller

The little fader that comes out of the sideborders is really nice I think. It covers the rasterlines $6 all the way up to $12c, so you cannot see any bugs in VICE with 'full' screenmode. Opening the sideborders costs almost all CPU cycles and there is not enough time left to play the music. Just before the borders get opened, the demo records 50 frames of music by fast forwarding through the sid and writing everything into a small buffer. This is simply replayed when the sideborders get opened. Normal music play resumes when the buffer is empty. 

## flipdisk

I wanted to make a zoomer that could scale every raster differently. It does not work with [sprite FPP](https://codebase.c64.org/doku.php?id=base:sprite_fpp), but with normal multiplexed sprites. The graphic consists of a sprite layer that's 7 sprites wide and 4 sprites high. There are 6 versions for every sprite: 2 (multicolor) pixels wide, 4, 6, 8, 10 and 12. In total there are 2 (front side and back side) * 7 * 4 * 6 = 336 sprites in the memory. 

The routine works in alternating lines. Every _even_ line it selects a different screen to set the width of the graphics in the sprites. The effect needs 2 (the graphic has a front and a backside) * 6 (sprite sizes) * 4 (the graphic is 4 sprites high) = 48 different screens. Every _odd_ line it changes the x positions of all the sprites (except the middle sprite). Together it makes the twisting very smooth and even gives it a bit of a high resolution look.

The first version of this effect had an open sideborder, but I couldnt get the sprites to move in X enough to make use of the sideborders. The code always runs into problems with moving a sprite (to the left) just when the VIC-II wants to draw it, causing the VIC-II to skip drawing that sprite. I call this effect 'sprite skip'. The only way I could imagine to work around it was to use different speedcodes for different ranges of x-positions. It would never fit into the memory though. Maybe some of you can think of a solution? It would also be nice to stretch in Y aswell!

The small 'element54' logo in the lower border has some nice hires pixels for antialiasing.

## rotozoomer

I cannot explain fully how this works, at least not in a way that makes sense to anyone. I will try to come up with a good explanation in the future.

Basically the effect is based on 16 charsets. There is one charset for every 22.5 degrees of rotation. Rotation and zooming are done by stepping a certain number of pixels in the U direction and a certain number of pixels in the V direction every char. The 4 most significant bits encode the 16 possible steps in the U direction and the 4 least significant bits encode the possible steps in the V direction.

Now, the big problem lies in stepping in the U and V direction separately in a fast way. The problem is that whenever we calculate what the neighbouring char is, we need to add a certain number to the 4 LSB bits and a different number to the 4 MSB bits. You see the problem : if we add (or subtract) a 4 bit value (0-15) to the current charvalue, it might change the 4 most significant bits aswell. The solution here is to use tables.

The final speedcode looks like this:

~~~
for y in columns:
  lax startValue,y  // load the start value for this column
  sta screen,y      // write to the screen

  lda table,x       // read what the next char should be
  sta screen+40,y   // store it to the screen
  tax               // a to x, to be able to read the next char

  lda table,x
  sta screen+80,y
  tax
  ..
~~~

### the tables

Every frame the startValues are calculated and the table positions are modified. There are 16 tables in total (each 512 bytes long), which look like this:

table0 : 00,01,02,03..0f, 10,11,12,13, .. ff (repeat once) -> this is the identity table, when reading from the table nothing changes.<br>
table1 : 0f,00,01,02..0e, 1f,10,11,12, .. fe (repeat once) -> this table shifts 1 pixel in the V direction by reading from it.<br>
table2 : 0e,0f,00,01..0d, etc -> this table shifts 2 pixels in the V direction when reading from it<br>

example:
  x = U0; lda table1,x results in a = Uf, never changing U just like we wanted.

So be selecting the correct table we can control the steps in V every next row. Using the same tables, we can also step in the U direction when calculating the charvalue for the next row, by reading from a Ustep*$10 offset.

example:
  x = U0; lda table1+$20,x result in a = (U+2)f. Basically taking a 1 pixel step in the V direction (by selecting table1) and 2 pixel steps in the U direction (by selecting an offset of $20).

The reading from an offset is the reason the tables are 512 bytes long instead of 256 bytes.

### plotting columnwise

The effect plots columns in a loop, since it needs to plot to a few different screens and the fastest way to update the screen where everything is plotted is by doing it columnwise (needs 25 bytes to be modified in the plotter).

### Mekanix

This effect is ofcourse inspired by the rotozoomer in [Mekanix](https://csdb.dk/release/?id=94438) by Booze Design. Calling the effect in Mekanix a rotozoomer might be unqualified however. The Mekanix chessboard does rotate and zoom, but the zoom is fixed to the rotation in a way that it graphics will zoom out a factor of square root of 2 whenever the rotation is 45 degrees. This is directly caused by the way in which the rotating is calculated. This new routine fixes this by making zooming and rotating totally separate.

My effect used (16) ripped charsets from Mekanix during development and I couldn't figure out a good way to generate my own graphics that looked good. In the weeks before X-2026 I asked HCL if he would tell me his secret and I was allowed to use some old code to generate my own charsets. HCL's generating code is not included in this repository.

## boogiebars

As far as I'm aware we 'invented' horizontal kefrens (at least on the c64) in our Pearls for Pigs demo from 2008. That effect used an empty charset where every column 3 (or was it 4) new characters were used to plot a new bar in. The next column was a copy of the previous column, using 3 new chars to plot a new bar. Every frame this effect continuously updates the charset. Soon after we got our butts kicked by Crossbow of Crest doing 80 horizontal kefrens bars (without music) and even 160 bars later in a hidden part. I tried to beat Crossbow by doing 80 bars with music, but failed. One of the ideas on my list was to see if I could prepare a special character set, so I'd only have to plot characters on the screen. Somehow I didn't get that to work, every attempt kept using a few rasterlines too many.

The effect in this demo, which I call 'boogiebars', is based on that idea. Instead of 'straight' Kefrens bars, it produces bars with a boogie twist: each line can be (vertically) shifted compared to the previous one. It also uses a uniquely crafted characterset and a couple of tables to draw the screen. Every column, the effect updates 6 copies (since the char rows on the screen are 6 pixels high, see below) of the previous column with a new bar. Each of this copies is shifted one pixel down. Then a specific copy of the columns is written to the screen, depending on the shift. 

It was not possible to make use of all 8 pixelrows in the characterset. The effect would need way over 256 differenct characters in that case. To keep the number of unique characters below 256, only the first 6 pixelrows of each char are used. This forces us to repeat the character rows on the screen every 6 pixels with some VIC trickery. The downside is that you need a new screen for every 6 rasterlines.

The effect uses double buffering by using the second character row of all screens (offset 40-79) for the first frame and the first character row (offset 0-39) of all screens for the second frame. Some $d011 messing is used to scroll the second frame down so it lines up with the first frame.

## perspective zoomscroller

In my opinion this is the best effect of the demo, but a bit difficult to explain maybe. Here's my best effort to explain how it works.

### zooming in X

Basically, the zooming in X is your typical Graham zoomer consisting of chars shifted in X. A perspective scroller adds some difficulties though. Normally, the picture in a Graham zoomer in fixed, but the sides of the letters in this perspective scroller depend on the x position of the screen. The effect works in a number of steps with most of the work done using KickAssembler scripts.

The scroller might remind someone of the wobbly scoller in [+H2K by Plush](https://csdb.dk/release/?id=11755). This is the first example that I know of a scrolling Graham type zoomer. The big difference is ofcourse that here the graphic stays the same from scrolling from right to left.

To get the effect working, there's quite some steps taking place in KickAssembler during compilation:
1. using a kickAss script, a 'bitmap' in memory is drawn by zooming a charset with a factor of 8. All letters are drawn horizontally in this bitmap.
2. The letters are drawn 9 times. Every row with all letters has a different phase of the 'sides' of the letters, which are drawn into the bitmap. (4 pixel sides to the right, 3 pixels, 2 pixels, 1 pixel, no sides, 1 pixel to the left, 2 to the left, 3 to the left and 4 to the left).
3. Then 4 copies of the bitmap are made and shifted by 0,1,2,3 multicolor pixels to the left. These shifted bitmaps are the basis for the graham zoomer.
4. The bitmaps are converted into unique chars in a charset. By being a little bit careful, we can make it fit in the maximum of 256 chars. (there is a different charset for the top scroller and the bottom scroller though).
5. A map with 'protochars' is generated. These protochars are basically a combination of the graphic in column x and the graphic in the column next to it, because the shape of the side will depend on it. These protochars are the key to the whole effect. Without it, we would have to use 9 different buffers in the memory to plot the screen. I doubt it's possible to do it fast enough.
6. These maps are the basis for the plotter : the protochars are copied in a little buffer, and the speedcode will plot the correct chars on the screen and take care of the perspective effect.

The preprocessing in KickAssembler for this effect takes quite a while.. You will notice during compilation.

#### BRR

The zooming in X is calculated using the [BRR method](https://www.quiss.org/boo/) that Quiss of Reflex first introduced in his 4K intro ['Boo'](https://csdb.dk/release/?id=232949). His methoded provided me with a way to speed things up a bit and freed up enough time for the second scroller. Note that the BRR method is ideally suited for a graham zoomer like this: when zooming you take either a step of A pixels or a step of A+1 pixels. BRR is ideal in this scenario. 

The scroller does not use $d016 for scrolling and only makes use of the graham-zoomer to move the scrolltext. This way the screen can have the full width of 40 chars instead of 38 like the scrollers in Pearls for Pigs.

### zooming in Y

Zooming in Y is done by restarting char rows and selecting a new screen every couple of rasterlines. Normally it is only possible to shrink in Y using this method. Imagine a picture using only the first 7 pixelrows in each char. Every 7 pixels, the char row is restarted with a $d011 trick and a switch happens to the next screen. Doing this, the VIC-II will show the picture as intended. Restarting the char row earlier, like after 5 or 6 rasterlines, will shrink the picture in Y. I don't think this leads to a very smooth zoom effect, so the Y zoomer in this part works in a bit modified way. Here, the picture only uses the first 4 pixel rows of each char. Restarting the char row every 4 pixels will result in a 100% zoom. Now, the trick is that also the 5th pixel row is filled with graphic (a repeat of the 4th row). So now, the zoomer can also zoom out and show 5 pixels instead of 4 (resulting in 125% zoom). Also the zooming in Y is a lot smoother there being twice as many positions a rasterline is removed (by restarting after 3 pixels) or added (by restarting after 5 pixels) compared to the normal 7-pixel method. The disadvantage being that we need twice as many interrupts, charsets and screens for the effect to work. I think it's worth it.

There is a separate example (test y zoom) that only has the zooming as a simple example. There also is an example how to do FLD on the cheap with and IRQ that triggers itself again.

## scrollway to heaven

This part originated from the [Raistlin Papers](https://c64demo.com/star-wars-scrollers/), where Raistlin of Genesis*Project explains the ideas behind some of his effect. One of these effects is a Star Wars scroller. Dear Raistlin, your challenge is accepted and you can now hold my beer on X. Here is a real 50fps Star Wars scroller with a rounded font.

There are some differences between Raistlin's and this version. The main thing is that Hexed uses a charmode scroller instead of a bitmap. This allows to have (some) multicolor graphics beside the scroller by using chars that are still free. But codewise it allows me to do a couple of things:

1. double buffer the effect, by using multiple charsets (and 2 sets of code). The greatest advantage of double buffering is the total removal of update bugs. 
2. make a super fast clear line, saving a lot of rastertime (this is the really smart idea)
3. reuse data from one frame for the next frame

### Super fast clear line

Raistlins routine uses his normal codepath to write empty bytes. By arranging the chars in a special way, the Hexed routine can clear every line with just one fast subroutine. Let's have a look at the char order at the top and middle of the effect. Let's assume the first row is 4 chars wide, the second row is 6 chars wide and the third row is 8 chars wide. In the effect itself these rows are 10,12 and 14 chars wide, but that would make for a table that's too wide to show here.

| row # | column 16 |column 17 | column 18 | column 19 | column 20 | column 21 | column 22 | column 23 |
|-------|-----------|----------|-----------|-----------|-----------|-----------|-----------|-----------|
| 0     | empty     | empty    | 128       | 134       | 140       | 146       | empty     | empty     |
| 1     | empty     | 123      | 129       | 135       | 141       | 147       | 153       | empty     |
| 2     | 118       | 124      | 130       | 136       | 142       | 148       | 154       | 160       |

As you can see, the chars are arranged in columns. This is needed to clear all lines with one single piece of speedcode. The reason will become clear when looking at the speedcode, which looks like this.

~~~
clearline:
{
entryPointClear8: // clears the two columns 2 left and 2 right of the middle
  sta charset+116*8,x
  sta charset+158*8,x

entryPointClear6: // clears the two columns left and right of the middle
  sta charset+122*8,x
  sta charset+152*8,x

entryPointClear4: // clears the midddle columns
  sta charset+128*8,x
  sta charset+146*8,x

  sta charset+134*8,x
  sta charset+140*8,x

  rts
}
~~~

By jumping to the correct entry point and correct value in the X register, you can clear any line you need. For example, we clear any of the 8 pixel lines of row 0 with:

~~~
ldx #pixelline (value 0-7)
jsr clearLine.entryPointClear4  // note we are jumping into the last part of the speedcode, which only clears the middle 4 columns
~~~

Also, we can clear any pixelline of row 1 with:

~~~
ldx #pixelline+8 (value 8-15)
jsr clearLine.entryPointClear4 // we are jumping into the part of the speedcode which clears the middle 4 columns and the 2 columns beside of it
~~~

Now it becomes clear why the chars need to be ordered in columns. This allows you to clear lines using an index register. The code corrects for the increasing width of the scroller by jumping into the correct part of the speedcode.

### reusing data

Another speedup comes from reusing data. Notice that the effect is double buffered and there are separate speedcode routines for the odd and even frames. If line X of the scroller is drawn into the odd frame, we might be able to reuse that data for the next frame if that frame also needs to plot that data. So this is what happens. Let's say the y-positions that frame 1 needs to draw are scroll lines 1,2,3 and 4 in the first four lines. The next frame will have to draw scroller lines 2,3,4 and 5 (because we scrolled up 1 line). Now the speedcode for the first frame reads the data for scroll line 2 and stores that data in the speedcode for the nextframe one line higher. Then the same happens : when the data for line 3 is read for the even frame, it will also store the data in the speedcode for next odd frame 1 line higher.

There might be a better (and faster) way to do this though: instead of storing the data inside the other speedcode, you might be able to draw the data directly on the screen if the rasterbeam has already passed that line. That would save quite a lot of stores and lda #'s. You would need a more stable rastertime usage though and a kind of predictor (did the rasterbeam already pass or not?) if this is possible. I've only thought of this a couple of weeks before X2026 and didn't have time anymore to work it out. Probably you could make a much higher scroller this way.

# 3. Spindle ideas and tips

Here are some thoughts about using Spindle and how Spindle might be improved in the future.

1. I often find that small parts that stay on the screen for a short time tend to want to load too much. Spindle has no way to determine how many blocks can be loaded: it has no idea of the runtime of a part or the amount of available rastertime. My solution to this is blocking part of the memory available for loading by inheriting from a previous part. Say part X has memory $4000-$c000 free and Spindle wants to preload all this memory, yet there is only enough time to load 16 pages. I will then 'block' loading by declaring that part X 'inherits' some data from the previous part with the 'I' parameter (.byte 'I', >$5000, >$c000). Spindle will then only load data from $4000-$4fff. Now this obviously works, but it's not clear what is happening anymore in the flow diagram. Maybe there could be a 'B' or 'X' (for block) parameter that does the exact same thing as 'I', but show an 'X' in the flow diagram to show that loading is blocked there. Alternatively, it might be nice to have a parameter to tell Spindle how many pages it can load. Like .byte 'L', $10 // load $10 pages max. Note that the 'A' (avoid loading) parameter is not helpful. There might not be anything to load at all to go to the next part and precious loading time will go to waste.

2. I find that sometimes parts will use memory, but only after starting the part and not yet in the prepare function. If you declare the memory use with the 'P' parameter, it might clash with the previous part and Spindle will insist to insert a blank part or a small switch part of your own. Let's say part X uses $4000-$7fff during runtime and the previous part does as well. My solution is to declare the memory use by inheriting it: .byte 'I', >$4000, >$7fff. This solves the problem : there is no clash with the previous part and it still protects the memory by being loaded over or againt the prepare of a next effect. My gripe with it is that things become unclear in the flow diagram : Part X is not really inheriting the data from the previous part. It would be nice if we could have a special parameter for this, with it's own character in the flow diagram (like 'U' for use).

3. Placement of the driver. God. I'm always running into problems with Spindle choosing weird places to put the driver. I've seen it place it after the code at a memory address that I declared protected (and it gets written over). I've seen it placed at $fffa while being 16 bytes long. It would be really nice if it were possible to have a parameter to hint Spindle for a nice position in memory to put the driver.

4. Sometimes I've had a dreaded error -1073741819 when Spindle crunches all the files. It's unclear what is wrong and by moving some small things around the error disappears. This is probably a small bug in Spindle.

# 4. Finally

Thanks for all the great feedback and see you in our next demo.
