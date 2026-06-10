// this is a fake loading part..
// -when greetings starts the fadeout, it no longer needs $2000-$9fff
// -this part is started when 08.greetings starts the fadeout and hands control back to 08.greetings.
// -it protects all the data 08.greetings is still using by inheriting it
// -this way the loading of $2000-$9fff can proceed during the fadeout

#import "../00.music/music1.asm"

.label code = $0900

#if AS_SPINDLE_PART
  .label spindleLoadAddress = code
  *=spindleLoadAddress-18-6-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word 0             // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word cleanup       // cleanup routine
    .word 0             // location of playroutine call

    .byte 'I', >($5c00), >($7fff)  // 'inherit' the screen and bitmap
    // $8000-$83ff can be preloaded
    .byte 'I', >($8400), >($87ff)  // 'inherit' the code

    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#endif

* = code "[CODE]"
start:
{
  cli // driver kills interrupts
  rts // go back to greetings
}

cleanup:
{
  // wait until invisible rasterline
wait:
  lda $d012
  cmp #4
  bcs wait   // stay in the wait loop until rasterline < 4
  lda $d011
  bmi wait   // stay in the loop if we are at the bottom of the screen (rasterline $100-$103)
  and #$ef
  sta $d011  // turn screen off
  rts
}
