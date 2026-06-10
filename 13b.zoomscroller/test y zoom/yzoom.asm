.var mapFile        = LoadBinary("./testmap.bin") // font to make charmap from
.var shadowFontFile = LoadBinary("./charset_pfp.bin")    // charset from pearls for pigs

// copy charset into list for manipulations
.var shadowFont = List()
.for (var i=0; i<shadowFontFile.getSize(); i++) { .eval shadowFont.add($ff & shadowFontFile.get(i)) }

.label screen0 = $4000
.label screen1 = $4400
.label screen2 = $4800
.label screen3 = $4c00
.label screen4 = $5000
.label screen5 = $5400
.label screen6 = $5800
.label screen7 = $5c00

.label charset1 = $6000
.label charset2 = $6800 

:BasicUpstart2(start)

* = $1000
start:
  sei
  lda #$35
  sta $01

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  lda #$18
  sta $d018
  lda #$96
  sta $dd00
  lda #$d8
  sta $d016

  lda #$0c
  sta $d020
  lda #$0b
  sta $d021
  lda #$03
  sta $d022
  lda #$0e
  sta $d023

  ldx #19
loop:
  lda #BLUE|8
  .for (var r=0; r<9; r++) { sta $d800+r*40,x}
  lda #PURPLE|8
  .for (var r=0; r<9; r++) { sta $d814+r*40,x}

  dex
  bpl loop

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$fa
  sta $d012
  lda #$1b
  sta $d011

  cli
  jmp *

.var d018Values = List()

.for (var r=0; r<10; r++)
{
  .eval d018Values.add(r*16+$8)
  .eval d018Values.add(r*16+$a)
}

irq0:
{
  sta atemp

  lda d011Tab+1
  sta $d011

  lda #<irq1
  sta $fffe
  lda #>irq1
  sta $ffff
  lda d012Tab+1
  sta $d012
  asl $d019
  
  lda #d018Values.get(1)
  sta $d018 

  lda atemp: #0
  rti
}

irq1:
{
  sta atemp

  lda d011Tab+2
  sta $d011

  lda #<irq2
  sta $fffe
  lda #>irq2
  sta $ffff
  lda d012Tab+2
  sta $d012
  asl $d019
  
  lda #d018Values.get(2)
  sta $d018 

  lda atemp: #0
  rti
}

irq2:
{
  sta atemp

  lda d011Tab+3
  sta $d011

  lda #<irq3
  sta $fffe
  lda #>irq3
  sta $ffff
  lda d012Tab+3
  sta $d012
  asl $d019
  
  lda #d018Values.get(3)
  sta $d018 

  lda atemp: #0
  rti
}

irq3:
{
  sta atemp

  lda d011Tab+4
  sta $d011

  lda #<irq4
  sta $fffe
  lda #>irq4
  sta $ffff
  lda d012Tab+4
  sta $d012
  asl $d019
  
  lda #d018Values.get(4)
  sta $d018 

  lda atemp: #0
  rti
}

irq4:
{
  sta atemp

  lda d011Tab+5
  sta $d011

  lda #<irq5
  sta $fffe
  lda #>irq5
  sta $ffff
  lda d012Tab+5
  sta $d012
  asl $d019
  
  lda #d018Values.get(5)
  sta $d018 

  lda atemp: #0
  rti
}

irq5:
{
  sta atemp

  lda d011Tab+6
  sta $d011

  lda #<irq6
  sta $fffe
  lda #>irq6
  sta $ffff
  lda d012Tab+6
  sta $d012
  asl $d019
  
  lda #d018Values.get(6)
  sta $d018 

  lda atemp: #0
  rti
}

irq6:
{
  sta atemp

  lda d011Tab+7
  sta $d011

  lda #<irq7
  sta $fffe
  lda #>irq7
  sta $ffff
  lda d012Tab+7
  sta $d012
  asl $d019
  
  lda #d018Values.get(7)
  sta $d018 

  lda atemp: #0
  rti
}

irq7:
{
  sta atemp

  lda d011Tab+8
  sta $d011

  lda #<irq8
  sta $fffe
  lda #>irq8
  sta $ffff
  lda d012Tab+8
  sta $d012
  asl $d019
  
  lda #d018Values.get(8)
  sta $d018 

  lda atemp: #0
  rti
}

irq8:
{
  sta atemp

  lda d011Tab+9
  sta $d011

  lda #<irq9
  sta $fffe
  lda #>irq9
  sta $ffff
  lda d012Tab+9
  sta $d012
  asl $d019
  
  lda #d018Values.get(9)
  sta $d018 

  lda atemp: #0
  rti
}

irq9:
{
  sta atemp

  lda d011Tab+10
  sta $d011

  lda #<irq10
  sta $fffe
  lda #>irq10
  sta $ffff
  lda d012Tab+10
  sta $d012
  asl $d019
  
  lda #d018Values.get(10)
  sta $d018 

  lda atemp: #0
  rti
}

irq10:
{
  sta atemp

  lda d011Tab+11
  sta $d011

  lda #<irq11
  sta $fffe
  lda #>irq11
  sta $ffff
  lda d012Tab+11
  sta $d012
  asl $d019
  
  lda #d018Values.get(11)
  sta $d018 

  lda atemp: #0
  rti
}

irq11:
{
  sta atemp

  lda d011Tab+12
  sta $d011

  lda #<irq12
  sta $fffe
  lda #>irq12
  sta $ffff
  lda d012Tab+12
  sta $d012
  asl $d019
  
  lda #d018Values.get(12)
  sta $d018 

  lda atemp: #0
  rti
}

irq12:
{
  sta atemp

  lda d011Tab+13
  sta $d011

  lda #<irq13
  sta $fffe
  lda #>irq13
  sta $ffff
  lda d012Tab+13
  sta $d012
  asl $d019
  
  lda #d018Values.get(13)
  sta $d018 

  lda atemp: #0
  rti
}

irq13:
{
  sta atemp

  lda d011Tab+14
  sta $d011

  lda #<irq14
  sta $fffe
  lda #>irq14
  sta $ffff
  lda d012Tab+14
  sta $d012
  asl $d019
  
  lda #d018Values.get(14)
  sta $d018 

  lda atemp: #0
  rti
}

irq14:
{
  sta atemp

  lda d011Tab+15
  sta $d011

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$fa
  sta $d012
  asl $d019
  
  lda #d018Values.get(15)
  sta $d018 

  lda atemp: #0
  rti
}

irq:
{
  sta atemp

  inc $d020

  lda #<irq0
  sta $fffe
  lda #>irq0
  sta $ffff
  asl $d019

  jsr calcYZoom

  // reset y zoomer
  lda #$1b
  sta $d011
  lda #d018Values.get(0)
  sta $d018
  lda d012Tab
  sta $d012

  dec $d020

  lda atemp: #0
  rti
}

calcYZoom:
{
  inc index
  ldx index: #0
  lda sineL,x
  //lda #0
  sta addLow
  lda sineH,x
  //lda #4
  sta addHigh
  ldx #0
  stx low
  stx high
loop:
  lda low:    #0
  clc
  adc addLow: #0
  sta low

  lda high:    #0
  adc addHigh: #0
  sta high

  lda #$1b
  clc
  adc high
  and #$07
  ora #$18
  sta d011Tab+1,x

  lda #$32
  clc
  adc high
  sta d012Tab,x

  inx
  cpx #15
  bne loop
  rts
}

* = * "[CODE] tables"
d011Tab:
  .fill 20,$1b
d012Tab:
  .fill 20,0

* = * "[DATA] sine (high byte)"
sineH:
{
  .var sinMin = $300
  .var sinMax = $500
  .var sinAmp = 0.5 * (sinMax-sinMin)
  .var sinLength = 64
  .fill 256, floor(((sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength))) / $100)
}

* = * "[DATA] sine (low byte)"
sineL:
{
  .var sinMin = $300
  .var sinMax = $500
  .var sinAmp = 0.5 * (sinMax-sinMin)
  .var sinLength = 64
  .fill 256, ((sinMin+sinAmp+0.5) + sinAmp*sin(toRadians(mod(i,sinLength)*360/sinLength))) & $ff
}


* = screen0 "[GFX] screen 0"
.fill mapFile.getSize(), mapFile.get(i)

* = screen1 "[GFX] screen 1"
.fill 40, mapFile.get(i+1*40)

* = screen2 "[GFX] screen 2"
.fill 40, mapFile.get(i+2*40)

* = screen3 "[GFX] screen 3"
.fill 40, mapFile.get(i+3*40)

* = screen4 "[GFX] screen 4"
.fill 40, mapFile.get(i+4*40)

* = screen5 "[GFX] screen 5"
.fill 40, mapFile.get(i+5*40)

* = screen6 "[GFX] screen 6"
.fill 40, mapFile.get(i+6*40)

* = screen7 "[GFX] screen 7"
.fill 40, mapFile.get(i+7*40)

* = charset1 "[GFX] charset"
.for (var ch=0; ch<256; ch++)
{
  .byte shadowFont.get(ch*8 + 0)
  .byte shadowFont.get(ch*8 + 1)
  .byte shadowFont.get(ch*8 + 2)
  .byte shadowFont.get(ch*8 + 3)
  .byte shadowFont.get(ch*8 + 3)
  .byte 0,0,0
}

* = charset2 "[GFX] charset"
.for (var ch=0; ch<256; ch++)
{
  .byte shadowFont.get(ch*8 + 4)
  .byte shadowFont.get(ch*8 + 5)
  .byte shadowFont.get(ch*8 + 6)
  .byte shadowFont.get(ch*8 + 7)
  .byte shadowFont.get(ch*8 + 7)
  .byte 0,0,0
}
