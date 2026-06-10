# Set various globally-used variables.
include environment.mk

NAME := hexed
NAME_UPPER := HEXED

PARTS1 = \
03a.binaryblob1 \
03b.binaryblob2 \
01a.load \
01b.basicfade \
01c.clean \
01d.bitmapchange \
01e.drop \
01f.bitmapfade \
01g.load \
01h.message \
01i.preload \
02a.rasterlogo \
02b.switch \
02c.kefrens \
02d.chessboard \
02e.message \
02f.messageload \
03c.greetings \
03d.loadfadeout \
04a.border \
04b.switch \
04c.censorscroll \
05a.element54 \
05b.flipside

PARTS2 = \
10.binary1 \
10.binary2 \
10a.unload \
10b.credits \
10c.preload1 \
10d.preload2 \
10e.closeborder \
11a.rotzoomer \
11b.preload \
12a.blocks \
12b.logo \
12c.boogiebars \
12d.border \
12e.openborder \
13a.fade \
13b.zoomscroller \
13c.fade \
13d.nova \
14a.heaven \
14b.switch \
14c.scrollway

PEFS1 := $(patsubst %,%.pef, $(PARTS1))
PEFS2 := $(patsubst %,%.pef, $(PARTS2))

.PHONY: all
all: $(NAME)1.d64 $(NAME)2.d64

%.pef:
	make -C "../$*" $@

# For testing ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$(NAME)1.d64: script1.txt $(PEFS1)
	$(PEFCHAIN) $(PEFFLAGS) --next-magic 133754 -r 02 -b 03 -z 06 -o $@ -t '-=$(NAME_UPPER) SIDE 1=-' -a ../00.dirart/dirart1.d64 $<
# add --40 for 40 track disk

$(NAME)2.d64: script2.txt $(PEFS2)
	$(PEFCHAIN) $(PEFFLAGS) --my-magic 133754 -r 02 -b 03 -z 06 -o $@ -t '-=$(NAME_UPPER) SIDE 2=-' -a ../00.dirart/dirart2.d64 $<

.PHONY: vice1
vice1: clean1 $(NAME)1.d64
	$(X64) -autostart $(NAME)1.d64

.PHONY: vice2
vice2: clean2 $(NAME)2.d64
	$(X64) -autostart $(NAME)2.d64

# Tasks to send stuff to the c64-ultimate

.PHONY: ultimate1
ultimate1: $(NAME)1.d64
	curl -X POST "$(ULTIMATE_API)/drives/a:mount?type=d64" --data-binary @$<

.PHONY: ultimate2
ultimate2: $(NAME)2.d64
	curl -X POST "$(ULTIMATE_API)/drives/a:mount?type=d64" --data-binary @$<

.PHONY: ultimatereset
ultimatereset:
	curl -X PUT "$(ULTIMATE_API)/machine:reset" 


.PHONY: clean
clean: clean1 clean2

.PHONY: clean1
clean1:
	$(DEL) $(NAME)1.d64
	$(DEL) $(PEFS1)
	$(DEL) $(patsubst %,../%/*.prg, $(PARTS1))
	$(DEL) $(patsubst %,../%/*.efo, $(PARTS1))
	$(DEL) $(patsubst %,../%/*.sym, $(PARTS1))
	$(DEL) $(patsubst %,../%/*.dbg, $(PARTS1))
	$(DEL) $(patsubst %,../%/.source.txt, $(PARTS1))

.PHONY: clean2
clean2:
	$(DEL) $(NAME)2.d64
	$(DEL) $(PEFS2)
	$(DEL) $(patsubst %,../%/*.prg, $(PARTS2))
	$(DEL) $(patsubst %,../%/*.efo, $(PARTS2))
	$(DEL) $(patsubst %,../%/*.sym, $(PARTS2))
	$(DEL) $(patsubst %,../%/*.dbg, $(PARTS2))
	$(DEL) $(patsubst %,../%/.source.txt, $(PARTS2))
