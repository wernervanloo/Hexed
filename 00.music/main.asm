.var music    = LoadSid("hexed1.sid")
.const sidMax = $18

:BasicUpstart2(start); jmp start

start:
  sei
  lda #$35
  sta $01

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  lda #$7f  // only read space bar from keyboard
  sta $dc00

  lda #<irq
  sta $fffe
  lda #>irq
  sta $ffff
  lda #$fa
  sta $d012
  lda #$1b
  sta $d011

  lda #0
  jsr music.init

  asl $d019
  cli
  jmp *

irq:

  jsr music.play
  asl $d019
  rti


*=music.location "[MUSIC]"
  .fill music.size, music.getData(i)
