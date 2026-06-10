// this is the position of the rotation centre
.var centreX = 160/2
.var centreY = 100/2

.var startUpDown    = 3
.var startLeftRight = 0 
.var startAngle     = 0
.var startZoom      = $05f800

// this is the zoom factor 0.8 (5 pixels become 4 pixels) to 1.33 (3 pixels become 4 pixels)
//.var zoomFactor = 1.2 // acceptable values = 0.66 to 1.15 or 1.2..

// this is the rotation angle, there are 512 angles in a one complete rotation

.function calcUV(angle_d, x, y, zoom)
{
  // this will cause jitter I think.
  // first calculate angle_x and recalculate angle_d from that..
  
  //  2.9,[4,0,32,167,6,3]
  //  3.2,[4,0,32,234,6,99]
  //  3.5,[4,0,48,49,6,199]

  .eval angle_d = 360-angle_d

  .var  angle_x = angle_d/360*512
  .eval angle_x = round(angle_x)
  .eval angle_x = mod(angle_x+65536,512)

  .eval angle_d = (512-angle_x)/512*360
  .var  angle_r = toRadians(angle_d)
  
  .var charsetSelect = floor(mod(angle_x-16+65536,512)/32)
  //.var charsetSelect = floor(mod(angle_x+65536,512)/16)
  .var angle_low  = (angle_x & $0ff)
  .var angle_high = (angle_x & $100) >> 8

  .var u = -1*x*cos(angle_r) + 1*y*sin(angle_r)
  .var v =  1*x*sin(angle_r) + 1*y*cos(angle_r)
  
  .eval u = u / zoom
  .eval v = v / zoom

  .var u2      = floor(mod(u + 65536, 16)) * 16
  .var v2      = floor(mod(v + 65536, 16))
  .var u2l     = floor((u - floor(u)) * 256)
  .var v2l     = floor((v - floor(v)) * 256)

  .var angle_r2       = toRadians(((angle_high*256 + angle_low))/512*360)
  .var stepSize       = round(cos(angle_r2)*$4000)            // calculate x component
  .eval stepSize      = stepSize / zoom
  .var stepSizeHigh   = (stepSize&$f000)>>8
  .var stepSizeLow    = (stepSize&$0fff)>>4

  .var stepSize2      = round(cos((angle_r2) - (PI/2))*$4000) // calculate y component
  .eval stepSize2     = stepSize2 / zoom
  .var stepSizeHigh2  = (stepSize2&$f000)>>8
  .var stepSizeLow2   = (stepSize2&$0fff)>>4

  .var result = List().add(charsetSelect, u2, u2l, v2, v2l, stepSizeLow, stepSizeHigh, stepSizeLow2, stepSizeHigh2)
  .return result
}

.var movementData = List()

//.var startUpDown    = 3
//.var startLeftRight = 0 
//.var startAngle     = 0
//.var startZoom      = $05f800


// starting values for takeover:
.var angle      = 0
.var angleSpeed = 0
.var zoom    = 1/(startZoom/$040000)
.var zoomSpeed  = 0
.var zoomFactor = 1
.var xCentre = 80
.var yCentre = 50
//.var x       = xCentre+5.78
//.var y       = yCentre+5.64
.var radius    = 8.0757
.var moveAngle = 44.2971
.var radiusSpeed = 0
.var moveAngleSpeed = 0

.var x       = xCentre + radius*cos(toRadians(moveAngle))
.var y       = yCentre + radius*sin(toRadians(moveAngle))

.for (var i=0; i<$340; i++)
{
  //.var zoom    = (sinMin  + sinMax)/2  + sinAmp *sin(toRadians((j+16)*2*360/sinLength))
  //.var x       = (sinMinX + sinMaxX)/2 + sinAmpX*sin(toRadians((-j+0)*360/sinLength))
  //.var y       = (sinMinY + sinMaxY)/2 + sinAmpY*sin(toRadians((j+64)*360/sinLength))

  // rotate 'script'
  .if ((i==  0))             { .eval angleSpeed = 0.5 }
  .if ((i>=  0) && (i< 50))  { .eval angleSpeed = angleSpeed + 0.03 }
  .if ((i>= 70) && (i<130))  { .eval angleSpeed = angleSpeed - 0.07 }
  .if ((i>=140) && (i<200))  { .eval angleSpeed = angleSpeed + 0.06 }
  .if ((i>=240) && (i<280))  { .eval angleSpeed = angleSpeed - 0.08 }

  // zoom 'script'
  .if ((i>=120) && (i<170)) { .eval zoomFactor = 1; .eval zoomSpeed = zoomSpeed + 0.0002 }
  .if ((i>=170) && (i<210)) { .eval zoomFactor = 1; .eval zoomSpeed = zoomSpeed - 0.0002 }
  .if ((i>=210) && (i<280)) { .eval zoomFactor = 1; .eval zoomSpeed = zoomSpeed - 0.0003 }
  .if (i==280)              { .eval zoomSpeed = zoomSpeed * -1 }
  .if ((i>280) && (i<330))  { .eval zoomSpeed = zoomSpeed - 0.0004 }
  .if (i==330)              { .eval zoomSpeed = 0 }
  .if ((i>=330) && (i<370)) { .eval zoomSpeed = zoomSpeed - 0.0004 }
  .if (i==375)              { .eval zoomSpeed = zoomSpeed * -1 } 
  .if (i==405)              { .eval zoomSpeed = 0 }
  .if ((i>410) && (i<450))  { .eval zoomSpeed = zoomSpeed - 0.0004 }
  .if (i==455)              { .eval zoomSpeed = 0 }
  .if ((i>455) && (i<490))  { .eval zoomSpeed = zoomSpeed + 0.00015 }

  // x-y 'script'
  .if ((i == 260))          { .eval radiusSpeed    = 0.01 
                              .eval moveAngleSpeed = 1 }
  .if ((i>=260) && (i<305)) { .eval radiusSpeed    = radiusSpeed + 0.010
                              .eval moveAngleSpeed = moveAngleSpeed + 0.08 }
  .if (i==320)              { .eval moveAngleSpeed = moveAngleSpeed }
  .if (i==330)              { .eval radiusSpeed    = 0 }

  // update angle
  // ------------

  .eval angle = angle+angleSpeed
  .if (angle<0)   { .eval angle = angle + 360 }
  .if (angle>360) { .eval angle = angle - 360 }

  // update zoom
  // -----------
  .eval zoom = (zoom + zoomSpeed) * zoomFactor

  // update x and y
  // --------------
   
  .eval radius    = radius + radiusSpeed
  .eval moveAngle = moveAngle + moveAngleSpeed
  .if (moveAngle<0)   { .eval moveAngle = moveAngle + 360 }
  .if (moveAngle>360) { .eval moveAngle = moveAngle - 360 }

  .eval x       = xCentre + radius*cos(toRadians(moveAngle))
  .eval y       = yCentre + radius*sin(toRadians(moveAngle))

  // calculate result and store it
  .var result = calcUV(angle, x, y, zoom)
  .eval movementData.add(result)
}
