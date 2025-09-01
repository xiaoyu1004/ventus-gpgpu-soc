ROOT_DIR := $(realpath ../../)
PROJECT := vecadd

SRC_DIR := $(ROOT_DIR)/tests/$(PROJECT)

KNL_SRCS += $(SRC_DIR)/vecadd.cl
CPP_SRCS += $(SRC_DIR)/main.cpp

include ../common.mk

$(PROJECT): $(CPP_SRCS) $(RUNTIME_DIR)/libventusrt.so
	g++ $(CPP_SRCS) -std=c++17 -Wall -Wextra -Wfatal-errors -I$(RUNTIME_DIR) -I$(RTL_SIM_DIR) -L$(RUNTIME_DIR) -lventusrt -L$(RTL_SIM_DIR) -lrtlsim -o $@