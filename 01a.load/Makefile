EFFECT_NAME = 01a.load

include ../include.mk

$(EFFECT_NAME).pef: $(EFFECT_NAME).efo
		$(MKPEF) -o ../@.Spindle/$@ $^ --music ../00.music/hexed1.sid,,7c

sfx.prg: sfx.asm
	$(KA) -o $@ $<
	$(X64) $@
