ROOT_DIR := $(realpath ../../)
RTL_SIM_DIR := $(ROOT_DIR)/rtlsim
RUNTIME_DIR := $(ROOT_DIR)/runtime

STARTUP_ADDR ?= 0x80000000

LLVM_VENTUS := /opt/workspace/ventus/llvm-project/install

CC  = $(LLVM_VENTUS)/bin/clang 
CXX = $(LLVM_VENTUS)/bin/clang++ 
AR  = $(LLVM_VENTUS)/bin/llvm-ar
DP  = $(LLVM_VENTUS)/bin/llvm-objdump
CP  = $(LLVM_VENTUS)/bin/llvm-objcopy

CFLAGS += -O3 -cl-std=CL2.0 -target riscv32 -mcpu=ventus-gpgpu -nodefaultlibs
CFLAGS += -I$(RUNTIME_DIR) -I$(LLVM_VENTUS)/include -I$(LLVM_VENTUS)/libclc/generic/include
CFLAGS += -DNDEBUG $(LLVM_VENTUS)/../libclc/riscv32/lib/workitem/get_global_id.cl

LIBC_LIB += -L$(LLVM_VENTUS)/lib $(LLVM_VENTUS)/lib/crt0.o -lworkitem

LDFLAGS += -Wl,-T,$(LLVM_VENTUS)/../utils/ldscripts/ventus/elf32lriscv.ld $(LIBC_LIB)

kernel: $(PROJECT).elf $(PROJECT).bin $(PROJECT).dump.s
all: $(PROJECT)

$(PROJECT).dump.s: $(PROJECT).elf
	$(DP) -D $< > $@

$(PROJECT).bin: $(PROJECT).elf
	$(CP) -O binary $< $@

$(PROJECT).elf: $(SRCS)
	$(CC) $(CFLAGS) $^ $(LDFLAGS) -o $@

.depend: $(SRCS)
	$(CC) $(CFLAGS) -MM $^ > .depend;

clean:
	rm -rf *.elf *.bin *.dump.s *.log .depend
