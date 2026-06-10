// this is a small tool to record my keypresses for the fader to make the text appear in a human-typed way

BasicUpstart2(start)

.label SCNKEY     = $ff9f   // scan keyboard - kernal routine
.label GETIN      = $ffe4   // read keyboard buffer - kernal routine

.label timeLow   = $10
.label timeHigh  = $11

.label keys   = $2000
.label times  = $2100

start:
  sei
  lda #0
  sta timeLow
  sta timeHigh

  lda #$01
  sta $d019
  sta $d01a
  sta $dc0d

  lda #<irq
  sta $0314
  lda #>irq
  sta $0315
  lda #$fa
  sta $d012
  lda $d011
  and #$7f
  sta $d011

  asl $d019
  cli

  lda #1
  sta $0289  //  disable keyboard buffer
  lda #127
  sta $028a  // disable key repeat
main_loop:

  check_keypress:
  jsr SCNKEY
  jsr GETIN

  beq main_loop

  tax
  sta add
  lsr
  lsr
  lsr
  lsr
  clc
  adc add: #0
  sta $d020
  txa

  { 
    ldy position: #0
    sta keys,y
    lda timeLow
    sec
    sbc prevTimeLow: #0
    sta times,y
    lda timeLow
    sta prevTimeLow
    inc position
  }
  cli

  txa
  jsr $ffd2  // chr out

jmp main_loop

irq:
  inc timeLow
  bne !+
    inc timeHigh
  !:
  asl $d019

  lda #<irq
  sta $0314

  jmp $ea31

*=keys
  .fill 256,0

*=times
  .fill 256,0

