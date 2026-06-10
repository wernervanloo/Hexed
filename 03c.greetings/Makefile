EFFECT_NAME = 03c.greetings

include ../include.mk

$(EFFECT_NAME).pef: $(EFFECT_NAME).efo
		$(MKPEF) -o ../@.Spindle/$@ $^ \
		--stream ../03a.binaryblob1/empty.bin,fc00 ../03a.binaryblob1/03a.binaryblob1.prg