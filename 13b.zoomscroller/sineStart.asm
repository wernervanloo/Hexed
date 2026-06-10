.var startPosition = $10
.var eindPosition  = $20
.var length        = 24-4               // normally this takes 16 frames, but we have to start with speed 0
.var speed         = 0                // start at speed 0
.var y             = startPosition    // start at startPosition
// in half the length (12 frames) we have to be at position ($10+$20)/2, or have a dy of
.var dy            = (eindPosition - startPosition)/2
//.var dy          = (length-1)*(length)/2 * a // we can also write this in a
//.var dy          = b * a
// what should the acceleration be?
.var l             = (length/2)
.var a             = dy / ((l)*(l+1)/2)

.var positions = List()

.for (var i=0; i<length/2; i++)
{
  .eval speed = speed + a
  .eval y = y + speed
  .eval positions.add(round(y))
}
.for (var i=0; i<length/2; i++)
{
  .eval y = y + speed
  .eval speed = speed - a
  .eval positions.add(round(y))
}

.var xstartPosition = 160-120
.var xeindPosition  = 120-120
.var xspeed         = 0                // start at speed 0
.var xp             = xstartPosition    // start at startPosition
// in half the length (12 frames) we have to be at position ($10+$20)/2, or have a dy of
.var dx            = (xeindPosition - xstartPosition)/2
//.var dx          = (length-1)*(length)/2 * a // we can also write this in a
//.var dx          = b * a
// what should the acceleration be?
.var xa             = dx / ((l)*(l+1)/2)

.var xPositions = List()

.for (var i=0; i<length/2; i++)
{
  .eval xspeed = xspeed + xa
  .eval xp = xp + xspeed
  .eval xPositions.add(round(xp))
}
.for (var i=0; i<length/2; i++)
{
  .eval xp = xp + xspeed
  .eval xspeed = xspeed - xa
  .eval xPositions.add(round(xp))
}


.for (var i=0; i<22+4+0; i++) 
{
  .eval positions.add(eindPosition)
  .eval xPositions.add(xeindPosition)
}

.print (positions)
.print (positions.size())
.print (xPositions)
.print (xPositions.size())
