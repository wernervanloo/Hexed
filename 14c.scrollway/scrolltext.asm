.var allRows = List().add(
 " we are element 54  ", 
 " and we throw down  ",
 "   the gauntlet.    ",
 "@@@@@@@@@@@@@@@@@@@@",
 "@@@@@@@@@@@@@@@@@@@@",
 "    we are four,    ",
 "  no need for more  ",
 "@@@@@@@@@@@@@@@@@@@@",
 "@@@@@@@@@@@@@@@@@@@@",
 "we challenge you to ",
 "  challenge us and  ",
 "leave your entourage",
 "      at home.      ",
 "@@@@@@@@@@@@@@@@@@@@",
 "@@@@@@@@@@@@@@@@@@@@",
 "thanks for watching ",
 "we hope you enjoyed ",
 "      the show      ",
 "@@@@@@@@@@@@@@@@@@@@",
 "@@@@@@@@@@@@@@@@@@@@",
 "  stick around for  ",
 " personal greetings ",
 "from the team, some ",
 " additional credits ",
 "@@@@@@@@@@@@@@@@@@@@",
 "@@@@@@@@@@@@@@@@@@@@",
 "and some tips on how",
 "  to train ferrets. ",
 "@@@@@@@@@@@@@@@@@@@@",
 "you know, the usual ",
 "  scroller stuff..  ",
 "@@@@@@@@@@@@@@@@@@@@",
 "@@@@@@@@@@@@@@@@@@@@",
 "@@@@@@@@@@@@@@@@@@@@",
 "  hammerfist here.  ",
 "have you enjoyed the",
 "       show?        ",
 "@@@@@@@@@@@@@@@@@@@@", 
 "quick shoutout to my",
 "non-c64 friends who ",
 " probably wont see  ",
 "this until it is on ",
 "     youtube.       ",
 "@@@@@@@@@@@@@@@@@@@@", 
 "infant, zerozshadow,",
 "  olympian, progen, ",
 "@@@@@@@@@@@@@@@@@@@@", 
 "and everyone else in",
 " the desire discord ",
 "for their motivation",
 "@@@@@@@@@@@@@@@@@@@@", 
 "hft out.            ",
 "@@@@@@@@@@@@@@@@@@@@", 
 "@@@@@@@@@@@@@@@@@@@@", 
 "@@@@@@@@@@@@@@@@@@@@",
 "  wvl here..  this  ",
 "   has been a long  ",
 "      journey.      ",
 "@@@@@@@@@@@@@@@@@@@@",
 "it was not possible ",
 "without these people",
 "@@@@@@@@@@@@@@@@@@@@",
 " big thanks to hcl, ",
 "for helping out with",
 "rotozoomer graphics.",
 "@@@@@@@@@@@@@@@@@@@@",
 "  thanks quiss for  ",
 " your brr technique ",
 "@@@@@@@@@@@@@@@@@@@@",
 "    and raistlin    ", 
 "  for your papers!  ",
 "@@@@@@@@@@@@@@@@@@@@",
 "here it is in 50fps,",
 "maybe a bit too fast",
 "  and rounded font  ",
 "@@@@@@@@@@@@@@@@@@@@",
 "-happy 50th oswald!-",
 "@@@@@@@@@@@@@@@@@@@@",
 "@@@@@@@@@@@@@@@@@@@@",
 "@@@@@@@@@@@@@@@@@@@@",
 "      mic drop      ",
 "@@@@@@@@@@@@@@@@@@@@",
 "@@@@@@@@@@@@@@@@@@@@",
 "@@@@@@@@@@@@@@@@@@@@",
 "@@@@@@@@@@@@@@@@@@@@",
 "@@@@@@@@@@@@@@@@@@@@",
 "@@@@@@@@@@@@@@@@@@@@",
 "@@@@@@@@@@@@@@@@@@@@",
 "@@@@@@@@@@@@@@@@@@@@",
 "@@@@@@@@@@@@@@@@@@@@")

// process rows
.var scrollTextList = List()  // a list holding the scrolltext in 20 columns

.for (var c=0; c<20; c++) // loop over all columns
{
  .var columnData = List()
  .for (var r=0; r<allRows.size(); r++) // loop over all rows
  {
    .var rowData = allRows.get(r) // get string for row r
    .var char = rowData.charAt(c) // read char at c
    .var value = 1 + char-'a'
    .if (char>='0') { .eval value = char-'0' + 27}
    .if (char=='@') { .eval value = 42 }
    .if (char==' ') { .eval value = 0  }  // empty
    .if (char=='!') { .eval value = 37 }
    .if (char=='.') { .eval value = 38 }
    .if (char=='-') { .eval value = 39 }
    .if (char=='?') { .eval value = 40 }
    .if (char==',') { .eval value = 41 }

    .eval columnData.add(value)
  }
  .eval columnData.add($ff)            // mark end of text

  .eval scrollTextList.add(columnData) // add list to the list of columns
}

.var scrollLength = allRows.size()+1   // +1 for the last $ff
