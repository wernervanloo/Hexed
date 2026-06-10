.function exists(lst, value)
{
  .for (var l=0; l<lst.size(); l++) { .if(lst.get(l)==value) { .return l } }
  .return -1
}

// transform string into information
// we do not need to know exactly where each pixel goes.
// for us 01234589 is equal to 01234689.
// we care about the first and the last non-0 pixel and where they are at.

.function toInfo(value)
{
  // what is the first non 0 character and what is the position?
  .var firstNon0    = 0
  .var firstNon0Pos = 0

  .for (var i=0; i<value.size(); i++)
  {
    .var charValue = value.charAt(i)
    .if (charValue != '0')
    {
      .eval firstNon0 = charValue
      .eval firstNon0Pos = i
      .eval i=value.size() 
    }
  }

  // what is the last non 0 character and what is the position?
  .var lastNon0    = 0
  .var lastNon0Pos = 0

  .for (var i=value.size()-1; i>=0; i--)
  {
    .var charValue = value.charAt(i)
    .if (charValue != '0')
    {
      .eval lastNon0 = charValue
      .eval lastNon0Pos = i
      .eval i=0 
    }
  }

  .var info = "" + firstNon0Pos + firstNon0 + lastNon0Pos + lastNon0
  .return info
}

.function pixelDown(value)
{
  .var firstNon0Pos = value.charAt(0)
  .var firstNon0    = value.charAt(1)
  .var lastNon0Pos  = value.charAt(2)
  .var lastNon0     = value.charAt(3)

  .if (firstNon0 != '1')
  {
    .eval firstNon0 = firstNon0.string().asNumber(16)-1
    .eval lastNon0  = lastNon0.string().asNumber(16)-1
  } else
  {
    .return value    
  }

  .var codes = List().add("0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f")
  .eval value = "" + firstNon0Pos + codes.get(firstNon0) + lastNon0Pos + codes.get(lastNon0)

  .return value
}

.function pixelUp(value)
{
  .var firstNon0Pos = value.charAt(0)
  .var firstNon0    = value.charAt(1)
  .var lastNon0Pos  = value.charAt(2)
  .var lastNon0     = value.charAt(3)

  .if (lastNon0 != 'E')
  {
    .eval firstNon0 = firstNon0.string().asNumber()
    .eval firstNon0 = firstNon0 + 1
    .eval lastNon0  = lastNon0.string().asNumber()
    .eval lastNon0  = lastNon0 + 1
  }

  .var codes = List().add("0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f")
  .eval value = "" + firstNon0Pos + codes.get(firstNon0) + lastNon0Pos + codes.get(lastNon0)
  .return value
}

.function modulo(a,b)
{
  .var result = a - floor(a/b)*b
  .return result
}