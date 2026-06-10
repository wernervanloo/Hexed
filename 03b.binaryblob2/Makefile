EFFECT_NAME = 03b.binaryblob2

# Set various globally-used variables.
include ../@.Spindle/environment.mk

# Make as spindle part
$(EFFECT_NAME).efo:	main.asm
	$(KA) -define AS_SPINDLE_PART -o $@ $<

# Make as prg
$(EFFECT_NAME).prg:	main.asm
	$(KA) main.asm -o $@ $<	

%.pef: %.prg
	$(KA) main.asm -o $@ $<	

.PHONY: clean
clean:
	$(DEL) *.sym *.dbg *.vs .source.txt
	$(DEL) splitefocmd_$(EFFECT_NAME).txt
	$(DEL) *.efo *.pef *.prg $(EFFECT_NAME)_part*.bin