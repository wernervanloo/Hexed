EFFECT_NAME = 10b.credits

include ../include.mk

$(EFFECT_NAME).pef: $(EFFECT_NAME).efo
		$(MKPEF) -o ../@.Spindle/$@ $^ --music ../00.music/hexed2.sid,,7c \
		--stream ../10.binary1/10.binary1.prg ../10.binary2/10.binary2.prg
