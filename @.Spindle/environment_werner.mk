# Set various globally needed variables.

# Java, KickAssembler, Vice
JAVA := "C:\Program Files\Java\jdk-21\bin\java.exe"
KA_JAR := "C:\Users\wvanl\Documents\GitHub\kickass\KickAss.jar"
X64 := "C:\Users\wvanl\Documents\c64\VICE-38\bin\x64sc.exe"
KA := $(JAVA) -jar $(KA_JAR)

# Spindle
SPINDLE_BIN_DIR := "C:\Users\wvanl\Documents\GitHub\spindle-3.1\prebuilt-binaries\windows"
MKPEF := $(SPINDLE_BIN_DIR)\mkpef.exe
PEF2PRG := $(SPINDLE_BIN_DIR)\pef2prg.exe
PEFCHAIN := $(SPINDLE_BIN_DIR)\pefchain.exe
PEFFLAGS := -v -w

# Miscellaneous
DEL := rm -f
