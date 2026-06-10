// this is the BRR algorithm by Quiss (https://www.quiss.org/boo/)
// but modified to suit this demo

.function reverse(x)
{
  .var result = 0
  .for (var i=0; i<8; i++)
  {
    .if ((x & (1<<i))>0) { .eval result = result | ($80 >> i) }
  }
  .return result
}

.var bitReversed = List()

// fill bitreverse list
.for (var i=0; i<256; i++) 
{
  .eval bitReversed.add(reverse(i)) 
}


// this part is completely different from how Quiss explains it.
// but I cannot understand the reason Quiss is sorting the bitReversed array..
// Instead, we only select the values up to x, which are the values that we want

.function getSteps(x)
{
  .var steps = List()
  .for (var i=0; i<bitReversed.size(); i++)
  {
    .if ((bitReversed.get(i)) < x) { .eval steps.add(bitReversed.get(i)) }
  }

  .return steps
}

.function getSteps2(x)
{
  .var steps = getSteps(x)
  .for (var i=0; i<steps.size(); i++) { .if (steps.get(i) == 0) { .eval steps.set(i, x) } }
  .return steps
}