

:BasicUpstart2(code)

.label screen = $0400
.label sprite = $0c00
.label code   = $1000
.label yPos1  = $2000
.label yPos2  = $2100

// movement constants
// ------------------

.const startRept1     = 0
.const endRept1       = 80

.const size           = 64   // vertical size of scroller  
.const frames_to_hit  = 60   // how many frames should it take to hit the top scroller?

.const amplitude      = 24   // amplitude of sine during repeated movement
.const minY           = 0    // minimum y value
.const startPosition2 = $80

.var hitSpeed          = 0
.var startRept2Scroll1 = 0
.var startRept2Scroll2 = 0

* = yPos2 "ypos2"
{
  .var remainingBytes = 256

  .fill 80,startPosition2

  .eval remainingBytes = remainingBytes-80

  // accelerate up, until we hit the top scroller
  .var frames   = 0
  .var speed    = 0
  .var position = startPosition2

  // what should the acceleration be if we want to hit in 40 frames? a = -2*x(0)/40^2
  .var accel = -2*position/(frames_to_hit*frames_to_hit)
  .var continue = true
  
  .for (var i=0; continue; i++)
  {
    .eval position = position + speed

    .if (position < 0)
    {
      .eval hitSpeed = speed
      .var overshoot = position
      .eval position = -overshoot
      .eval speed = 3
      .print ("hit at " + frames)
      .eval continue=false
    }

    .eval speed = speed + accel

    .byte position
    .eval frames = frames + 1
  }

  .eval remainingBytes = remainingBytes-frames

  .eval startRept2Scroll2 = 256-remainingBytes

  // this is the 2nd repeating part of the movement
  {
    .var sinMin = 0
    .var sinMax = 24
    .var sinAmp = 0.5 * (sinMax-sinMin)
    .var sinLength = 80
    .fill remainingBytes, (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(270+(mod(i,sinLength)*360)/sinLength))
  }
}

* = yPos1 "yPos1"
{
  .var lastValue      = 0
  .var remainingBytes = 256

  // this is the repeating part of the movement
  {
    .var sinMin = 0
    .var sinMax = amplitude
    .var sinAmp = 0.5 * (sinMax-sinMin)
    .var sinLength = 80
    .fill 80, (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength))+minY-((amplitude+size)/2)+100
  }

  .eval remainingBytes = remainingBytes-80

  // another repeat, until hit
  {
    .var sinMin = 0
    .var sinMax = amplitude
    .var sinAmp = 0.5 * (sinMax-sinMin)
    .var sinLength = 80
    .for (var i=0; i<frames_to_hit; i++)
    {
      .var value = (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength))+minY-((amplitude+size)/2)+100
      .byte value
      .eval lastValue = value
    }
  }

  .eval remainingBytes = remainingBytes-frames_to_hit

  // move up, and merge with final movement in 40 frames
  .var position      = lastValue
  .var speed         = hitSpeed
  .var finalPosition = minY

  // how many frames and how fast should we decellerate if we want to hit x=0, v=0?

  //.var decelFrames = round(2*(finalPosition-lastValue)/(speed))
  //.var accel       = -speed/decelFrames

  // we can't get it 100% correct using a formula.. so let's try a bit..
  // there's 2 variables we can adjust : the acceleration and the number of frames.
  // let's test by modifying the acceleration

  .var accel     = 0.1
  .var accelStep = 0.0001
  .var bestAccel = accel
  .var bestY     = 30000000000
  .var continue  = true
  .print ("hitspeed : " + hitSpeed)

  .for (var i=0; continue; i++)
  {
    // move up, and merge with final movement
    .var position      = lastValue
    .var speed         = hitSpeed
    .var finalPosition = minY

    // simulate until we hit speed 0
    .while (speed<0)
    {
      .eval position = position + speed
      .eval speed    = speed + accel
    }

    .if ((abs(finalPosition-position)) < (abs(finalPosition-bestY)))
    {
      .eval bestAccel = accel
      .eval bestY     = position
    }
    else
    {
      // it should be better.. if it's not, we better stop
      .eval continue = false
    }

    // try next accelleration
    .eval accel = accel + accelStep
  }

  .print ("best accel : " + bestAccel)
  .print ("best Y     : " + bestY)
  .var decelFrames   = -speed/bestAccel
  .eval position     = lastValue
  .eval speed        = hitSpeed
  .var frames        = 0

  // move up until we get to the top
  .for (var i=0; i<decelFrames; i++)
  {
    .eval position = position + speed
    .eval speed = speed + bestAccel

    .byte position
    .eval frames = frames + 1
  }

  .eval remainingBytes = remainingBytes-frames

  .eval startRept2Scroll1 = 256-remainingBytes

  // this is the 2nd repeating part of the movement
  {
    .var sinMin = 0
    .var sinMax = 24
    .var sinAmp = 0.5 * (sinMax-sinMin)
    .var sinLength = 80
    .fill remainingBytes, (sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(270+(mod(i,sinLength)*360)/sinLength))+minY
  }
}

.print ("rept : " + startRept2Scroll1 + ", " + startRept2Scroll2)

.var startRept2 = max(startRept2Scroll1, startRept2Scroll2)
.var endRept2   = startRept2 + 80

* = sprite "sprite"
  .fill 64,255

* = code "code"
  lda #$03
  sta $d015
  lda #$40
  sta $d000
  sta $d002
  lda #$00
  sta $d010
  lda #(sprite/64)
  sta screen+$3f8
  sta screen+$3f9
  lda #$00
  sta $d01b
  sta $d01c
  lda #$ff
  sta $d017
  sta $d01d

  lda #$50
  sta $d001
  lda #$90
  sta $d003
loop:
  lda $dc01
  and #$10
  bne noSpace

  inc $d020
  lda #0
  sta repeat

noSpace:

  // wait for next frame
  bit $d011
  bmi *-3
  bit $d011
  bpl *-3

  // increase phase
  lda phase
  clc
  adc #1
  sta phase

  // repeat first 80
  ldx repeat: #1
  beq continue

  cmp #80
  bne continue
    lda #0
    sta phase
continue:
  cmp #80
  bcc continue2
    ldx #1
    stx repeat
continue2:

  // 2nd repetition
  cmp #endRept2
  bne continue3
    lda #startRept2
    sta phase
continue3:

  ldx phase: #0
  lda yPos1,x
  clc
  adc #$32
  sta $d001

  clc
  adc #size
  clc
  adc yPos2,x
  bcc !+
    lda #$ff
  !: sta $d003

  jmp loop

