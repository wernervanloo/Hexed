.filenamespace sfx

#if !AS_SPINDLE_PART

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
  jsr sfx.init

  asl $d019
  cli
  jmp *

irq:


  lda $dc01
  and #$10
  bne skip
    jsr sfx.trigger

skip:
  jsr sfx.play

  asl $d019
  rti
  #endif

//  per voice
.label FREQ                     = $d400 // HI = $d401
.label PULSEWIDTH               = $d402 // HI = $d403
.label VOICE_CONTROL            = $d404
.label ADSR                     = $d405 // SR = $d406

// overall
.label FILTER_CUTOFF            = $d415 // HI = $d416
.label FILTER_RES_AND_ROUTING   = $d417
.label FILTER_AND_VOLUME        = $d418

// get a register address relative to the voice (0-2)
.function voiceRegister(voice, register) { .return register + voice * 7 }

.macro pokeWordToRegister(word, register) {
    lda #<word
    sta register
    lda #>word
    sta register + 1
}

.macro pokeWordToVoiceRegister(word, voice, register) {
    pokeWordToRegister(word, voiceRegister(voice, register))
}

.macro setFilterAndVolume(type, cutoff, res, voiceMask, volume) {
    pokeWordToRegister(cutoff, FILTER_CUTOFF)
    lda #res << 4 | voiceMask
    sta FILTER_RES_AND_ROUTING
    lda #type << 4 | volume
    sta FILTER_AND_VOLUME
}

init: {
    lda #0
    sta voiceRegister(0, FREQ)
    sta voiceRegister(1, FREQ)
    sta voiceRegister(2, FREQ)
    sta voiceRegister(0, VOICE_CONTROL)
    sta voiceRegister(1, VOICE_CONTROL)
    sta voiceRegister(2, VOICE_CONTROL)
    setFilterAndVolume(1, $1400, $0, %111, $f)
    jsr set_adsr
    pokeWordToVoiceRegister($e204, 0, FREQ)
    pokeWordToVoiceRegister($07c1, 1, FREQ)
    pokeWordToVoiceRegister($e204, 2, FREQ)
    pokeWordToVoiceRegister($200, 1, PULSEWIDTH)
    rts
}

play: {
    lda enabled:#0
    beq done
        
        // if enabled, update registers with next table value
        ldx idx:#0
        lda wave0,x
        sta voiceRegister(0, VOICE_CONTROL)
        lda wave1,x
        sta voiceRegister(1, VOICE_CONTROL)
        lda wave2,x
        sta voiceRegister(2, VOICE_CONTROL)

        inx

        // after 8 bytes, wrap around
        txa
        and #%111
        sta idx
    bne done
        // if wrapped around to 0, disable playing
        sta enabled

done:
    rts

wave0: .byte $09,$09,$81,$09,$09,$08,$08,$08
wave1: .byte $09,$09,$51,$51,$51,$51,$50,$08
wave2: .byte $09,$09,$09,$09,$09,$08,$81,$08

}

set_adsr:
    pokeWordToVoiceRegister($0402, 0, ADSR)
    pokeWordToVoiceRegister($0202, 1, ADSR)
    pokeWordToVoiceRegister($04F2, 2, ADSR)
    rts


// trigger a new keyboard click
trigger: {
    lda play.enabled
    // if not playing, start playing
    beq start 

    // else rewind to beginning
    lda #0
    sta play.idx
    rts

start:
    inc play.enabled
    rts

}
