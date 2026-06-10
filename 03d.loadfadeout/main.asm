// this is a fake loading part..
// -when greetings starts the fadeout, it no longer needs $2000-$9fff
// -this part is started when 08.greetings starts the fadeout and hands control back to 08.greetings.
// -it protects all the data 08.greetings is still using by inheriting it
// -this way the loading of $2000-$9fff can proceed during the fadeout

#import "../00.music/music1.asm"

.label code = $0900

.label nextpart = $02
.label timelow  = $03
.label timehigh = $04

#if AS_SPINDLE_PART
  .label spindleLoadAddress = code
  *=spindleLoadAddress-18-9-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word 0             // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word cleanup       // cleanup routine
    .word 0             // location of playroutine call

    .byte 'I', >($0400), >($07ff)  // 'inherit' the shift tables
    .byte 'I', >($a000), >($ffff)  // 'inherit' all the other stuff
    .byte 'I', >($9000), >($9fff)  // do not load to much, or we will miss the fixed moment

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
waitFrame:
  // wait until frame $1680
  lda timehigh
  cmp #$16
  bcc waitFrame // not at the correct frame yet..
  beq checkLow
  bcs wait      // we already passed the fixed moment
checkLow:
  lda timelow
  cmp #$78
  bcc waitFrame // not at the correct frame yet..

  // wait until invisible rasterline
wait:
  lda $d012
  cmp #4
  bcs wait   // stay in the wait loop until rasterline < 4
  lda $d011
  bmi wait   // stay in the loop if we are at the bottom of the screen (rasterline $100-$103)
  rts
}
