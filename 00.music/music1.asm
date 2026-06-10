// Music starts at $0c00

.const visualize = false  // visualize music player during the demo..

.var music = LoadSid("../00.music/hexed1.sid")

#if AS_SPINDLE_PART
// dummy music data and calls
// spindle handles music loading and playing

  *=music.location "[MUSIC]" virtual
   .fill music.size, 0

  .macro MusicPlayCall() {
  .if (visualize) { inc $d020 }
    .label @music_play = *
    bit.abs $0000
  .if (visualize) { dec $d020 }

  }

  .macro MusicInitCall() {
  }

#else

  *=music.location "[MUSIC]"
    .fill music.size, music.getData(i)

  .macro MusicPlayCall() {
  .if (visualize) { inc $d020 }
    .label @music_play = *
    jsr music.play
  .if (visualize) { dec $d020 }
  }


  .macro MusicInitCall() {
    lda #0
    jsr music.init  
  }

#endif

