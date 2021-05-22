#Makefile from TI, modified by Derek Molloy, modified by Andrew Gies
#PRU_CGT environment variable must point to the TI PRU compiler directory. E.g.:
#(Linux) export PRU_CGT=/usr/lib/ti/pru-software-support-package

PROJ_NAME            := flash
PRU_CGT              := /usr/lib/ti/pru-software-support-package
LINKER_COMMAND_FILE  := ./AM335x_PRU.cmd
LIBS                 := --library=$(PRU_CGT)/lib/rpmsg_lib.lib
INCLUDE              := --include_path=$(PRU_CGT)/include --include_path=$(PRU_CGT)/include/am335x
STACK_SIZE           := 0x100
HEAP_SIZE            := 0x100
BUILD_DIR            := build
PRU0                 := /sys/class/remoteproc/remoteproc1
PRU1                 := /sys/class/remoteproc/remoteproc2

#Common compiler and linker flags (Defined in 'PRU Optimizing C/C++ Compiler User's Guide)
CFLAGS := -v3 -O2 --display_error_number --endian=little --hardware_mac=on --obj_directory=$(BUILD_DIR) --pp_directory=$(BUILD_DIR) -ppd -ppa
#Linker flags (Defined in 'PRU Optimizing C/C++ Compiler User's Guide)
LFLAGS := --reread_libs --warn_sections --stack_size=$(STACK_SIZE) --heap_size=$(HEAP_SIZE)

TARGET := $(BUILD_DIR)/$(PROJ_NAME).out

SOURCES := $(wildcard *.c)
#Using .object instead of .obj in order to not conflict with the CCS build process
OBJECTS := $(patsubst %,$(BUILD_DIR)/%,$(SOURCES:.c=.object))

## ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------

.PHONY: all r0 r1 run0 run1 clean stop stop0 stop1 init-pins

all: init-pins $(TARGET)

# Restart running program from new compilation on PRU 0:
r0: $(TARGET) run0

# Restart running program from new compilation on PRU 1:
r1: $(TARGET) run1

init-pins:
	@config-pin P9_27 pruout

stop: stop0 stop1

## ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------

$(BUILD_DIR)/main.object: main.c
	@mkdir -p $(BUILD_DIR)
	@echo 'compiling: $<'
	@/usr/bin/clpru --include_path=$(PRU_CGT)/include $(INCLUDE) $(CFLAGS) -fe $@ $<

$(BUILD_DIR)/flash.object: flash.asm
	@mkdir -p $(BUILD_DIR)
	@echo 'compiling: $<'
	@/usr/bin/clpru --include_path=$(PRU_CGT)/include $(INCLUDE) $(CFLAGS) -fe $@ $<

$(BUILD_DIR)/flash.out: $(BUILD_DIR)/main.object $(BUILD_DIR)/flash.object
	@echo 'linking: $^'
	@/usr/bin/lnkpru -i$(PRU_CGT)/lib -i$(PRU_CGT)/include $(LFLAGS) -o $@ $^  $(LINKER_COMMAND_FILE) --library=libc.a $(LIBS) $^

## ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------

run0: stop0
	@echo 'installing pru firmware'
	@sudo cp $(TARGET) /lib/firmware/am335x-pru0-fw
	@echo 'deploying pru firmware'
	@echo am335x-pru0-fw | sudo dd status=none of=$(PRU0)/firmware
	@echo 'restarting pru0'
	@echo start | sudo dd status=none of=$(PRU0)/state

run1: stop1
	@echo 'installing pru firmware'
	@sudo cp $(TARGET) /lib/firmware/am335x-pru1-fw
	@echo 'deploying pru firmware'
	@echo am335x-pru1-fw | sudo dd status=none of=$(PRU1)/firmware
	@echo 'restarting pru1'
	@echo start | sudo dd status=none of=$(PRU1)/state

## ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------

stop0:
ifeq ($(shell cat $(PRU0)/state),offline)
	@echo "pru0 already stopped"
else
	@echo 'stopping pru0'
	@echo stop | sudo dd status=none of=$(PRU0)/state
endif

stop1:
ifeq ($(shell cat $(PRU1)/state),offline)
	@echo "pru1 already stopped"
else
	@echo 'stopping pru1'
	@echo stop | sudo dd status=none of=$(PRU1)/state
endif

## ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------

clean:
	@rm   -rf $(BUILD_DIR)
	@echo 'project cleaned'

# Includes the dependencies that the compiler creates (-ppd and -ppa flags)
-include $(OBJECTS:%.object=%.pp)
