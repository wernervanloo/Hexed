# Set various globally-used variables.
include ../@.Spindle/environment.mk

.PHONY: all
all: $(EFFECT_NAME).pef $(EFFECT_NAME).prg

# Run the standalone version
.PHONY: test
test: main.test.prg
	$(X64) $<

# Run standalone version in debugger
.PHONY: debug
debug: main.test.prg
	$(DBG) $<

# Make as standalone version
main.test.prg: main.asm
	$(KA) -debugdump -o $@ $<

# Make as spindle part
$(EFFECT_NAME).efo:	main.asm
	$(KA) -define AS_SPINDLE_PART -binfile -o $@ $<

%.pef: %.efo
		$(MKPEF) -o ../@.Spindle/$@ $^

%.prg: %.pef
	$(PEF2PRG) -o $@ -m $(EFFECT_NAME).vs $<

.PHONY: clean
clean:
	$(DEL) *.sym *.dbg *.vs .source.txt
	$(DEL) splitefocmd_$(EFFECT_NAME).txt
	$(DEL) *.efo *.pef *.prg $(EFFECT_NAME)_part*.bin