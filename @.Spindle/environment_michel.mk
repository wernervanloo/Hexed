C64_DEV := ~/Commodore64/Dev
JAVA := java
KA_JAR := $(C64_DEV)/KickAssembler/KickAss.jar
X64 := x64sc
KA := $(JAVA) -jar $(KA_JAR)
DBG := "/Applications/Retro Debugger.app/Contents/MacOS/Retro Debugger"
DART := "$(HOME)/dev/spartaomg/dart_cpp/bin/macos/dart"

ULTIMATE_API := http://192.168.1.72:80/v1

# Spindle
# Run `make` in this folder first to build the binaries
SPINDLE_BIN_DIR := $(C64_DEV)/spindle-3.1/src/
MKPEF := $(SPINDLE_BIN_DIR)mkpef
PEF2PRG := $(SPINDLE_BIN_DIR)pef2prg
PEFCHAIN := $(SPINDLE_BIN_DIR)pefchain
PEFFLAGS := -v -w

# Miscellaneous
DEL := rm -f
