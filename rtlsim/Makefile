include ../common.mk

DESTDIR ?= $(CURDIR)
XLEN ?= 32

SRC_DIR = .

CXXFLAGS += -std=c++17 -Wall -Wextra -Wno-array-bounds
CXXFLAGS += -fPIC -Wno-maybe-uninitialized
CXXFLAGS += -I$(SRC_DIR) -I$(DESTDIR)/lib$(PROJECT).so.obj_dir
CXXFLAGS += -DXLEN_$(XLEN)

RTL_PKGS = gpgpu_top_wrapper.v ${RTL_DIR}/gpgpu_top/sm/pipeline/sfu_v2/float_div_mvp/defs_div_sqrt_mvp.sv ${RTL_DIR}/gpgpu_top/sm/pipeline/sfu_v2/float_div_mvp/cf_math_pkg.sv
RTL_ALL_DIRS := $(shell find $(RTL_DIR) -type d)
RTL_INCLUDE = $(patsubst %,-I%,$(RTL_ALL_DIRS))

SRCS = $(SRC_DIR)/processor.cpp $(SRC_DIR)/memory.cpp

TOP = gpgpu_top_wrapper

VL_FLAGS = --exe
VL_FLAGS += --language 1800-2009 --assert -Wall -Wpedantic
VL_FLAGS += -Wno-DECLFILENAME -Wno-REDEFMACRO
VL_FLAGS += --x-initial unique --x-assign unique
VL_FLAGS += -DXLEN_$(XLEN)
VL_FLAGS += $(RTL_INCLUDE)
VL_FLAGS += $(RTL_PKGS)
VL_FLAGS += --cc $(TOP) --top-module $(TOP)
VL_FLAGS += --trace --trace-structs -DFST_OUTPUT
VL_FLAGS += -timescale 1ns/1ps
# warning
VL_FLAGS += -Wno-WIDTHEXPAND
VL_FLAGS += -Wno-UNUSEDSIGNAL
VL_FLAGS += -Wno-UNUSEDPARAM
VL_FLAGS += -Wno-fatal

# Extract RTL directories from include directories
RTL_DIRS := $(patsubst -I%,%,$(filter -I%,$(RTL_INCLUDE)))

# Discover RTL source files from source directories
RTL_SRCS := $(shell find $(RTL_DIRS) -type f \( -name '*.v' -o -name '*.vh' -o -name '*.sv' -o -name '*.vi' \))

# Enable Verilator multithreaded simulation
THREADS ?= $(shell python3 -c 'import multiprocessing as mp; print(mp.cpu_count())')
VL_FLAGS += -j 4

PROJECT := rtlsim

.PHONY: all force clean clean-lib clean-exe

all: $(DESTDIR)/lib$(PROJECT).so

$(DESTDIR)/lib$(PROJECT).so: $(SRCS) $(RTL_SRCS)
	verilator --build $(VL_FLAGS) $(SRCS) -CFLAGS '$(CXXFLAGS)' -LDFLAGS '-shared' --MMD --Mdir $@.obj_dir -o $@

clean-lib:
	rm -rf $(DESTDIR)/lib$(PROJECT).so.obj_dir
	rm -f $(DESTDIR)/lib$(PROJECT).so

clean: clean-lib 