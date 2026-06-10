// Music starts at $0c00

.var music = LoadSid("../00.music/hexed2.sid")

#if AS_SPINDLE_PART
// dummy music data and calls
// spindle handles music loading and playing

  *=music.location "[MUSIC]" virtual
   .fill music.size, 0

  .macro MusicPlayCall() {
    .label @music_play = *
    bit.abs $0000
  }

  .macro MusicInitCall() {
  }

#else

  *=music.location "[MUSIC]"
    .fill music.size, music.getData(i)

  .macro MusicPlayCall() {
    .label @music_play = *
    jsr music.play
  }

  .macro MusicInitCall() {
    lda #0
    jsr music.init  
  }

#endif

