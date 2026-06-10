include ../@.Spindle/environment.mk

JSIDPLAY_VERSION=4.8
JSIDPLAY_HOME=~/dev/micheldebree/c64-tools/sid/jsidplay2-${JSIDPLAY_VERSION}-mac
JSIDPLAY=java -jar ~/dev/micheldebree/c64-tools/sid/jsidplay2-4.8-mac/jsidplay2-console-4.8.jar 

%.prg: %.asm
	$(KA) -o $@ $<

all: main.prg hexed1.wav hexed2.wav


%.wav: %.sid
	$(JSIDPLAY) \
	-n true \
	-e RESIDFP \
	-f HIGH \
	--sampling RESAMPLE \
	--defaultLength 03:00 \
--fadeOut 00:03 -a WAV $<

# clean:
	# rm *.wav
