// Copyright © 2019-2023
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "processor.h"
#include "Vgpgpu_top_wrapper.h"
#include "memory.h"

#define FST_OUTPUT

#ifdef FST_OUTPUT
#include <verilated_fst_c.h>
#endif

#include <fstream>
#include <iomanip>
#include <iostream>

#include <list>
#include <map>
#include <ostream>
#include <queue>
#include <sstream>
#include <tuple>
#include <unordered_map>
#include <vector>

#ifndef MEM_CLOCK_RATIO
#define MEM_CLOCK_RATIO 1
#endif

#ifndef TRACE_START_TIME
#define TRACE_START_TIME 0ull
#endif

#ifndef TRACE_STOP_TIME
#define TRACE_STOP_TIME -1ull
#endif

#ifndef VERILATOR_RESET_VALUE
#define VERILATOR_RESET_VALUE 2
#endif

#ifndef RESET_DELAY
#define RESET_DELAY 60
#endif

#define PLATFORM_MEMORY_DATA_SIZE 8
#define WARP_SIZE 32
#define NUMBER_WG_SLOTS 8
#define NUMBER_CU 2

static uint64_t timestamp = 0;

double sc_time_stamp() { return timestamp; }

///////////////////////////////////////////////////////////////////////////////

static bool trace_enabled = false;
static uint64_t trace_start_time = TRACE_START_TIME;
static uint64_t trace_stop_time = TRACE_STOP_TIME;

bool sim_trace_enabled() {
  if (timestamp >= trace_start_time && timestamp < trace_stop_time)
    return true;
  return trace_enabled;
}

void sim_trace_enable(bool enable) { trace_enabled = enable; }

///////////////////////////////////////////////////////////////////////////////

class Processor::Impl {
public:
  Impl() : grid_finish_(false), wg_finish_count_(0), cycles_(0) {
    // force random values for uninitialized signals
    Verilated::randReset(VERILATOR_RESET_VALUE);
    Verilated::randSeed(50);

    // turn off assertion before reset
    Verilated::assertOn(false);

    // create RTL module instance
    device_ = new Vgpgpu_top_wrapper();
    info_ = new dispatch_info_t();

#ifdef FST_OUTPUT
    Verilated::traceEverOn(true);
    tfp_ = new VerilatedFstC();
    device_->trace(tfp_, 99);
    tfp_->open("trace.fst");
#endif

    ram_ = nullptr;
    active_sms_[0] = false;
    active_sms_[1] = false;

    // reset the device
    this->reset();

    // Turn on assertion after reset
    Verilated::assertOn(true);
  }

  ~Impl() {
#ifdef FST_OUTPUT
    tfp_->close();
    delete tfp_;
#endif

    delete device_;
    delete info_;
  }

  void attach_ram(PhysicalMemory *ram) { ram_ = ram; }

  void run(metadata_buffer_t metadata, uint64_t csr_knl_addr) {
    parse_metadata(metadata, csr_knl_addr);
#ifndef NDEBUG
    INFO("%lx: [sim] run() ", timestamp);
#endif

    // reset device
    this->reset();

    // start
    device_->rst_n = 1;
    device_->host_rsp_ready_i = 1;
    device_->out_a_ready_i = 1;

    while (!grid_finish_) {
      this->tick();
      cycles_++;
      INFO("cycles_: %lu", cycles_);
    }

    // stop
    device_->rst_n = 0;
  }

private:
  void parse_metadata(metadata_buffer_t metadata, uint64_t csr_knl_addr) {
    info_->dim_grid.x = metadata.knl_gl_size_x / metadata.knl_lc_size_x;
    info_->dim_grid.y = metadata.knl_gl_size_y / metadata.knl_lc_size_y;
    info_->dim_grid.z = metadata.knl_gl_size_z / metadata.knl_lc_size_z;

#ifndef NDEBUG
    INFO("metadata.knl_gl_size_x:%u", metadata.knl_gl_size_x);
    INFO("metadata.knl_gl_size_y:%u", metadata.knl_gl_size_y);
    INFO("metadata.knl_gl_size_z:%u", metadata.knl_gl_size_z);

    INFO("metadata.knl_lc_size_x:%u", metadata.knl_lc_size_x);
    INFO("metadata.knl_lc_size_y:%u", metadata.knl_lc_size_y);
    INFO("metadata.knl_lc_size_z:%u", metadata.knl_lc_size_z);

    uint32_t knl_entry;
    ram_->read(csr_knl_addr, &knl_entry, 4);
    INFO("csr_knl_addr:%x, knl_entry:%x", (uint32_t)csr_knl_addr, knl_entry);
#endif

    info_->grid_idx.x = 0; // kernel_size_x
    info_->grid_idx.y = 0; // kernel_size_y
    info_->grid_idx.z = 0; // kernel_size_z

    info_->wg_id = 0;
    info_->num_warps = (metadata.knl_lc_size_x / WARP_SIZE) *
                       metadata.knl_lc_size_y * metadata.knl_lc_size_z;
    info_->warp_size = WARP_SIZE;
    info_->start_pc = 0x80000000U;

    info_->pds_baseaddr = 0;
    info_->csr_knl = (uint32_t)csr_knl_addr;
    info_->vgpr_size_total = info_->num_warps * 64;
    info_->sgpr_size_total = info_->num_warps * 64;
    info_->lds_size_total = 0;
    info_->gds_size_total = 0;
    info_->vgpr_size_per_warp = 64;
    info_->sgpr_size_per_warp = 64;
    info_->gds_baseaddr = 0;
  }

  void reset() {
    device_->rst_n = 0;
    device_->host_req_valid_i = 0;
    device_->host_rsp_ready_i = 0;
    device_->out_a_ready_i = 0;
    device_->out_d_valid_i = 0;

    for (int i = 0; i < RESET_DELAY; ++i) {
      device_->clk = 0;
      this->eval();
      device_->clk = 1;
      this->eval();
    }
  }

  void handle_host() {
    // rsp
    if (device_->host_rsp_valid_o && device_->host_rsp_ready_i) {
      uint32_t sm_idx =
          device_->host_rsp_inflight_wg_buffer_host_wf_done_wg_id_o && 0x1;
      wg_finish_count_++;
      active_sms_[sm_idx] = false;
      INFO("wg finish count: :%u", wg_finish_count_);
    }

    uint32_t wg_num_totals =
        info_->dim_grid.x * info_->dim_grid.y * info_->dim_grid.z;
    if (wg_finish_count_ == wg_num_totals) {
      grid_finish_ = true;
      return;
    }

    // req
    if (device_->host_req_valid_i && device_->host_req_ready_o) {
      device_->host_req_valid_i = 0;
      uint32_t sm_idx = device_->host_req_wg_id_i;
      active_sms_[sm_idx] = true;
      INFO("dispatch cta: x:%u y:%u z:%u", info_->grid_idx.x, info_->grid_idx.y,
           info_->grid_idx.z);

      info_->grid_idx.x++;
      if (info_->grid_idx.x == info_->dim_grid.x) {
        info_->grid_idx.x = 0;
        info_->grid_idx.y++;
        if (info_->grid_idx.y == info_->dim_grid.y) {
          info_->grid_idx.y = 0;
          info_->grid_idx.z++;
        }
      }
      return;
    }

    bool host_dispatch_finish = info_->grid_idx.z >= info_->dim_grid.z;
    bool dispatch_valid = !active_sms_[0] || !active_sms_[1];
    if (!host_dispatch_finish && dispatch_valid && !device_->host_req_valid_i) {
      uint32_t sm_idx = !active_sms_[0] ? 0 : 1;
      device_->host_req_valid_i = 1;
      device_->host_req_wg_id_i = sm_idx;
      device_->host_req_num_wf_i = info_->num_warps;
      device_->host_req_wf_size_i = info_->warp_size;
      device_->host_req_start_pc_i = info_->start_pc;
      device_->host_req_start_pc_i = info_->start_pc;
      device_->host_req_kernel_size_x_i = info_->grid_idx.x;
      device_->host_req_kernel_size_y_i = info_->grid_idx.y;
      device_->host_req_kernel_size_z_i = info_->grid_idx.z;
      device_->host_req_pds_baseaddr_i = info_->pds_baseaddr;
      device_->host_req_csr_knl_i = info_->csr_knl;
      device_->host_req_vgpr_size_total_i = info_->vgpr_size_total;
      device_->host_req_sgpr_size_total_i = info_->sgpr_size_total;
      device_->host_req_lds_size_total_i = info_->lds_size_total;
      device_->host_req_gds_size_total_i = info_->gds_size_total;
      device_->host_req_vgpr_size_per_wf_i = info_->vgpr_size_per_warp;
      device_->host_req_sgpr_size_per_wf_i = info_->sgpr_size_per_warp;
      device_->host_req_gds_baseaddr_i = info_->gds_baseaddr;
    }
  }

  void handle_memory() {
    bool read = device_->out_a_opcode_o == 4;
    bool write = device_->out_a_opcode_o == 0 || device_->out_a_opcode_o == 1;
    // read
    if (device_->out_a_valid_o && device_->out_a_ready_i && read) {
      device_->out_d_valid_i = 1;
      device_->out_d_opcode_i = 1;
      device_->out_d_size_i = device_->out_a_size_o;
      device_->out_d_source_i = device_->out_a_source_o;
      ram_->read(device_->out_a_address_o, &device_->out_d_data_i, 8);
      device_->out_d_param_i = device_->out_a_param_o;
      INFO("memory read; addr:%x size:%d", device_->out_a_address_o,
           (int)std::pow(2, device_->out_a_size_o));
    } else if (device_->out_a_valid_o && device_->out_a_ready_i && write) {
      device_->out_d_valid_i = 1;
      device_->out_d_opcode_i = 0;
      device_->out_d_size_i = device_->out_a_size_o;
      device_->out_d_source_i = device_->out_a_source_o;
      device_->out_d_param_i = device_->out_a_param_o;
      for (uint32_t i = 0; i < 8; ++i) {
        if (device_->out_a_mask_o & (1u << i)) {
          uint8_t val = (device_->out_a_data_o >> (i * 8)) & 0xFF;
          ram_->write(device_->out_a_address_o + i, &val, 1);
        }
      }
      INFO("memory write; addr:%x mask:%x size:%d", device_->out_a_address_o,
           device_->out_a_mask_o, (int)std::pow(2, device_->out_a_size_o));
    }
  }

  void tick() {
    device_->clk = 0;
    this->eval();

    device_->clk = 1;
    handle_host();
    handle_memory();
    this->eval();

#ifndef NDEBUG
    fflush(stdout);
#endif
  }

  void eval() {
    device_->eval();
#ifdef FST_OUTPUT
    if (sim_trace_enabled()) {
      tfp_->dump(timestamp);
    }
#endif
    ++timestamp;
  }

  void wait(uint32_t cycles) {
    for (int i = 0; i < cycles; ++i) {
      this->tick();
    }
  }

private:
  // typedef struct {
  //   std::array<uint8_t, PLATFORM_MEMORY_DATA_SIZE> data;
  //   uint32_t addr;
  //   bool write;
  //   bool cycles;
  // } mem_req_t;

  // std::list<mem_req_t*> pending_mem_reqs_;

  Vgpgpu_top_wrapper *device_;

  PhysicalMemory *ram_;
  bool grid_finish_;
  uint32_t wg_finish_count_;
  uint64_t cycles_;
  bool active_sms_[NUMBER_CU];

  dispatch_info_t *info_;

#ifdef FST_OUTPUT
  VerilatedFstC *tfp_;
#endif
};

///////////////////////////////////////////////////////////////////////////////

Processor::Processor() : impl_(new Impl()) {}

Processor::~Processor() { delete impl_; }

void Processor::attach_ram(PhysicalMemory *mem) { impl_->attach_ram(mem); }

void Processor::run(metadata_buffer_t metadata, uint64_t csr_knl_addr) {
  impl_->run(metadata, csr_knl_addr);
}
