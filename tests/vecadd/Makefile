PROJECT := vecadd

include ../common.mk

SRC_DIR := $(ROOT_DIR)/tests/$(PROJECT)

SRCS := $(SRC_DIR)/main.cpp

$(PROJECT): $(SRCS) $(RUNTIME_DIR)/libventusrt.so
	g++ $(SRCS) -std=c++17 -Wall -Wextra -Wfatal-errors -I$(RUNTIME_DIR) -I$(RTL_SIM_DIR) -L$(RUNTIME_DIR) -lventusrt -L$(RTL_SIM_DIR) -lrtlsim -o $@