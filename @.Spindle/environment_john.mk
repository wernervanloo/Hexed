# Set various globally needed variables.

# Java, KickAssembler, Vice, Dart
JAVA := "G:\Mijn Drive\c64\jdk-11.0.9.11-hotspot\bin\java.exe"
KA_JAR := "G:\Mijn Drive\c64\KickAssembler\KickAss.jar"
X64 := "G:\Mijn Drive\c64\VICE\bin\x64sc.exe"
KA := $(JAVA) -jar $(KA_JAR)
DART := "G:\Mijn Drive\c64\dart1.4\binaries\windows_static\dart.exe" 

# Spindle
SPINDLE_BIN_DIR := G:\Mijn Drive\c64\spindle-3.1\prebuilt-binaries\windows
MKPEF := $(SPINDLE_BIN_DIR)\mkpef.exe
PEF2PRG := $(SPINDLE_BIN_DIR)\pef2prg.exe
PEFCHAIN := $(SPINDLE_BIN_DIR)\pefchain.exe
PEFFLAGS := -v -w

# Miscellaneous
DEL := rm -f
