// this is a fake loading part..
// -when greetings starts the fadeout, it no longer needs $2000-$9fff
// -this part is started when 08.greetings starts the fadeout and hands control back to 08.greetings.
// -it protects all the data 08.greetings is still using by inheriting it
// -this way the loading of $2000-$9fff can proceed during the fadeout

#import "../00.music/music2.asm"

.label code = $f700

#if AS_SPINDLE_PART
  .label spindleLoadAddress = code
  *=spindleLoadAddress-18-3-3 "Spindle header"
  .label spindleHeaderStart = *

    .text "EFO2"        // fileformat magic
    .word 0             // prepare routine
    .word start         // setup routine
    .word 0             // irq handler
    .word 0             // main routine
    .word 0             // fadeout routine
    .word 0             // cleanup routine
    .word 0             // location of playroutine call

    .byte 'I', >($2000), >($ffff)  // 'inherit' all memory $2000-$ffff

    .byte 0
    .word spindleLoadAddress    // Load address

  .label spindleHeaderEnd = *
  .var efoHeaderSize = spindleHeaderEnd-spindleHeaderStart
#endif

* = code "[CODE]"
start:
{
  cli // driver kills interrupts
  rts // go back to rotozoomer
}
