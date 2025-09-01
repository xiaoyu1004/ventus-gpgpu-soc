RTL_SIM_DIR := $(ROOT_DIR)/rtlsim
RUNTIME_DIR := $(ROOT_DIR)/runtime

STARTUP_ADDR ?= 0x80000000

LLVM_VENTUS := /home/xiaoyu/ventus_home/llvm-project/install

CC  = $(LLVM_VENTUS)/bin/clang 
CXX = $(LLVM_VENTUS)/bin/clang++ 
AR  = $(LLVM_VENTUS)/bin/llvm-ar
DP  = $(LLVM_VENTUS)/bin/llvm-objdump
CP  = $(LLVM_VENTUS)/bin/llvm-objcopy
llc = $(LLVM_VENTUS)/bin/llc

CFLAGS += -O3 -cl-std=CL2.0 -target riscv32 -mcpu=ventus-gpgpu -nodefaultlibs
CFLAGS += -I$(RUNTIME_DIR) -I$(LLVM_VENTUS)/include -I$(LLVM_VENTUS)/libclc/generic/include
CFLAGS += -DNDEBUG $(LLVM_VENTUS)/../libclc/riscv32/lib/workitem/get_global_id.cl

LIBC_LIB += -L$(LLVM_VENTUS)/lib $(LLVM_VENTUS)/lib/crt0.o -lworkitem

LDFLAGS += -Wl,-T,$(LLVM_VENTUS)/../utils/ldscripts/ventus/elf32lriscv.ld $(LIBC_LIB)

kernel: $(PROJECT).elf $(PROJECT).ll $(PROJECT).s $(PROJECT).bin $(PROJECT).dump.s
all: $(PROJECT)

$(PROJECT).dump.s: $(PROJECT).elf
	$(DP) -D --mattr=+v,+zfinx $< > $@

$(PROJECT).bin: $(PROJECT).elf
	$(CP) -O binary $< $@

$(PROJECT).elf: $(KNL_SRCS)
	$(CC) $(CFLAGS) $^ $(LDFLAGS) -o $@

$(PROJECT).ll: $(KNL_SRCS)
	$(CC) -O3 -S -cl-std=CL2.0 -target riscv32 -mcpu=ventus-gpgpu -emit-llvm $^ -o $@

$(PROJECT).s: $(PROJECT).ll
	$(llc) -O3 -mtriple=riscv32 -mcpu=ventus-gpgpu $^ -o $@

.depend: $(KNL_SRCS)
	$(CC) $(CFLAGS) -MM $^ > .depend;

clean:
	rm -rf *.elf *.bin *.dump.s *.log .depend $(PROJECT) *.ll *.s
