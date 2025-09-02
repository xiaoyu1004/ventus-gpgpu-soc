include ../common.mk

DESTDIR ?= $(CURDIR)

SRC_DIR := $(RUNTIME_DIR)

CXXFLAGS += -std=c++17 -Wall -Wextra -pedantic -Wfatal-errors
CXXFLAGS += -I$(RUNTIME_DIR) -I$(RTL_SIM_DIR)

# Position independent code
CXXFLAGS += -fPIC

LDFLAGS += -shared -pthread -Wl,--export-dynamic
LDFLAGS += -L$(RTL_SIM_DIR) -lrtlsim

SRCS := $(SRC_DIR)/ventus_runtime.cpp $(SRC_DIR)/callbacks.cpp

# Debugging
# ifdef DEBUG
# 	CXXFLAGS += -g -O0
# else
# 	CXXFLAGS += -DNDEBUG
# endif

PROJECT := libventusrt.so

.PHONY: all force driver clean-driver clean-runtime clean

all: $(DESTDIR)/$(PROJECT)

driver: $(DESTDIR)/librtlsim.so

# $(DESTDIR)/librtlsim.so: force
# 	DESTDIR=$(DESTDIR) $(MAKE) -C $(RTL_SIM_DIR) $(DESTDIR)/librtlsim.so

$(DESTDIR)/$(PROJECT): $(SRCS) $(RTL_SIM_DIR)/librtlsim.so
	$(CXX) $(CXXFLAGS) $(SRCS) $(LDFLAGS) -o $@

clean-driver:
	DESTDIR=$(DESTDIR) $(MAKE) -C $(RTL_SIM_DIR) clean-lib

clean-runtime:
	rm -f $(DESTDIR)/$(PROJECT)

clean: clean-driver clean-runtime