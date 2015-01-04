# The name of your project (used to name the compiled .hex file)
TARGET = NixieClock

# Folder where the .ino and .c/.cpp/.h files are located
SKETCHSRC = clock

# Path were the arduino install is located
ARDUINOPATH = $(HOME)/arduino

# The teensy version to use, 30 or 31
TEENSY = 31

# Set to 24000000, 48000000, or 96000000 to set CPU core speed
TEENSY_CORE_SPEED = 96000000

# Some libraries will require this to be defined
ARDUINO = 106
TEENSYDUINO = 121

# configurable options
OPTIONS = -DUSB_SERIAL -DLAYOUT_US_ENGLISH

# more speed at the cost of size
OPTIONS += -O2

# less size at the cost of speed
#OPTIONS += -Os

# ------- stuff below shouldn't need to be modified -----------

#************************************************************************
# Location of Teensyduino utilities, Toolchain, and Arduino Libraries.
# To use this makefile without Arduino, copy the resources from these
# locations and edit the pathnames.  The rest of Arduino is not needed.
#************************************************************************

# directory to build in
BUILDDIR = $(abspath $(CURDIR)/build)

# path location for Teensy Loader, teensy_post_compile and teensy_reboot
#TOOLSPATH = $(CURDIR)/tools
TOOLSPATH = $(ARDUINOPATH)/hardware/tools

ifeq ($(OS),Windows_NT)
    $(error What is Win Dose?)
else
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Darwin)
        TOOLSPATH = /Applications/Arduino.app/Contents/Resources/Java/hardware/tools/
    endif
endif

# path location for Teensy 3 core
COREPATH = $(ARDUINOPATH)/hardware/teensy/cores/teensy3

# path location for Arduino libraries
LIBRARYPATH = libraries

# path location for the arm-none-eabi compiler
#COMPILERPATH = $(TOOLSPATH)/arm-none-eabi/bin
COMPILERPATH = $(TOOLSPATH)/arm/bin

#************************************************************************
# Settings below this point usually do not need to be edited
#************************************************************************

# CPPFLAGS = compiler options for C and C++
CPPFLAGS = -Wall -Werror -g -mcpu=cortex-m4 -mthumb -nostdlib -fdata-sections -ffunction-sections -DTIME_T=$(shell date +%s) -MMD $(OPTIONS) -DF_CPU=$(TEENSY_CORE_SPEED) -I$(SKETCHSRC) -I$(COREPATH)

# compiler options for C++ only
CXXFLAGS = -std=gnu++0x -felide-constructors -fno-exceptions -fno-rtti

# compiler options for C only
CFLAGS =

FLASHSIZE30=131072
RAMSIZE30=16384
FLASHSIZE31=262144
RAMSIZE31=65536
# compiler options specific to teensy version
ifeq ($(TEENSY), 30)
    CPPFLAGS += -D__MK20DX128__
    LDSCRIPT = $(COREPATH)/mk20dx128.ld
    FLASHSIZE=$(FLASHSIZE30)
    RAMSIZE=$(RAMSIZE30)
else
    ifeq ($(TEENSY), 31)
        CPPFLAGS += -D__MK20DX256__
        LDSCRIPT = $(COREPATH)/mk20dx256.ld
        FLASHSIZE=$(FLASHSIZE31)
        RAMSIZE=$(RAMSIZE31)
    else
        $(error Invalid setting for TEENSY)
    endif
endif


# set arduino define if given
ifdef ARDUINO
	CPPFLAGS += -DARDUINO=$(ARDUINO)
endif
ifdef TEENSYDUINO
	CPPFLAGS += -DTEENSYDUINO=$(TEENSYDUINO)
endif

# linker options
LDFLAGS = -Os -Wl,--gc-sections -mcpu=cortex-m4 -mthumb -T$(LDSCRIPT)

# additional libraries to link
LIBS = -lm

# names for the compiler programs
CC = $(abspath $(COMPILERPATH))/arm-none-eabi-gcc
CXX = $(abspath $(COMPILERPATH))/arm-none-eabi-g++
OBJCOPY = $(abspath $(COMPILERPATH))/arm-none-eabi-objcopy
SIZE = $(abspath $(COMPILERPATH))/arm-none-eabi-size

# automatically create lists of the sources and objects
LC_FILES := $(wildcard $(LIBRARYPATH)/*/*.c)
LCPP_FILES := $(wildcard $(LIBRARYPATH)/*/*.cpp)
TC_FILES := $(wildcard $(COREPATH)/*.c)
TCPP_FILES := $(wildcard $(COREPATH)/*.cpp)
C_FILES := $(wildcard $(SKETCHSRC)/*.c)
CPP_FILES := $(wildcard $(SKETCHSRC)/*.cpp)
INO_FILES := $(wildcard $(SKETCHSRC)/*.ino)

# include paths for libraries
L_INC := $(foreach lib,$(filter %/, $(wildcard $(LIBRARYPATH)/*/)), -I$(lib))

SOURCES := $(C_FILES:.c=.o) $(CPP_FILES:.cpp=.o) $(INO_FILES:.ino=.o) $(TC_FILES:.c=.o) $(TCPP_FILES:.cpp=.o) $(LC_FILES:.c=.o) $(LCPP_FILES:.cpp=.o)
OBJS := $(foreach $(SKETCHSRC),$(SOURCES), $(BUILDDIR)/$($(SKETCHSRC)))

all: hex

build: $(TARGET).elf

hex: $(TARGET).hex

post_compile: $(TARGET).hex
	@$(abspath $(TOOLSPATH))/teensy_post_compile -file="$(basename $<)" -path=$(CURDIR) -tools="$(abspath $(TOOLSPATH))"

reboot:
	@-$(abspath $(TOOLSPATH))/teensy_reboot

upload: post_compile reboot

$(BUILDDIR)/%.o: %.c
	@echo "[CC]\t$<"
	@mkdir -p "$(dir $@)"
	@$(CC) $(CPPFLAGS) $(CFLAGS) $(L_INC) -o "$@" -c "$<"

$(BUILDDIR)/%.o: %.cpp
	@echo "[CXX]\t$<"
	@mkdir -p "$(dir $@)"
	@$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(L_INC) -o "$@" -c "$<"

$(BUILDDIR)/%.o: %.ino
	@echo "[CXX]\t$<"
	@mkdir -p "$(dir $@)"
	@$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(L_INC) -o "$@" -x c++ -include Arduino.h -c "$<"

$(TARGET).elf: $(OBJS) $(LDSCRIPT)
	@echo "[LD]\t$@"
	@$(CC) $(LDFLAGS) -o "$@" $(OBJS) $(LIBS)

%.hex: %.elf
	@echo "[HEX]\t$@"
	@$(SIZE) "$<" | awk '{ print; if (NR==2) { FLASH=$$1+$$2; RAM=$$2+$$3 } } END { printf "[FLASH]\t%6d/%6d (teensy30: %4.1f%%, teensy31: %4.1f%%)\n[RAM]\t%6d/%6d (teensy30: %4.1f%%, teensy31: %4.1f%%)\n", FLASH, $(FLASHSIZE), FLASH/$(FLASHSIZE30)*100, FLASH/$(FLASHSIZE31)*100, RAM, $(RAMSIZE), RAM/$(RAMSIZE30)*100, RAM/$(RAMSIZE31)*100 }'
	@$(OBJCOPY) -O ihex -R .eeprom "$<" "$@"

# compiler generated dependency info
-include $(OBJS:.o=.d)

clean:
	@echo Cleaning...
	@rm -rf "$(BUILDDIR)"
	@rm -f "$(TARGET).elf" "$(TARGET).hex"

