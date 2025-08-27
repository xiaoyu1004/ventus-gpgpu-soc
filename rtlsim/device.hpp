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

#include <vt_config.h>
#include <processor.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <iostream>
#include <future>
#include <list>
#include <chrono>
#include <unordered_map>

class vt_device {
public:
  vt_device()
    : ram_()
  {
    processor_.attach_ram(&ram_);
  }

  ~vt_device() {
    if (future_.valid()) {
      future_.wait();
    }
  }

  int init() {
    return 0;
  }

  int get_caps(uint32_t caps_id, uint64_t *value) {
    uint64_t _value;
    // switch (caps_id) {
    // case VX_CAPS_VERSION:
    //   _value = IMPLEMENTATION_ID;
    //   break;
    // case VX_CAPS_NUM_THREADS:
    //   _value = NUM_THREADS;
    //   break;
    // case VX_CAPS_NUM_WARPS:
    //   _value = NUM_WARPS;
    //   break;
    // case VX_CAPS_NUM_CORES:
    //   _value = NUM_CORES * NUM_CLUSTERS;
    //   break;
    // case VX_CAPS_CACHE_LINE_SIZE:
    //   _value = CACHE_BLOCK_SIZE;
    //   break;
    // case VX_CAPS_GLOBAL_MEM_SIZE:
    //   _value = GLOBAL_MEM_SIZE;
    //   break;
    // case VX_CAPS_LOCAL_MEM_SIZE:
    //   _value = (1 << LMEM_LOG_SIZE);
    //   break;
    // case VX_CAPS_ISA_FLAGS:
    //   _value = ((uint64_t(MISA_EXT))<<32) | ((log2floor(XLEN)-4) << 30) | MISA_STD;
    //   break;
    // case VX_CAPS_NUM_MEM_BANKS:
    //   _value = PLATFORM_MEMORY_NUM_BANKS;
    //   break;
    // case VX_CAPS_MEM_BANK_SIZE:
    //   _value = 1ull << (MEM_ADDR_WIDTH / PLATFORM_MEMORY_NUM_BANKS);
    //   break;
    // default:
    //   std::cout << "invalid caps id: " << caps_id << std::endl;
    //   std::abort();
    //   return -1;
    // }
    *value = _value;
    return 0;
  }

  int mem_alloc(uint64_t* dev_addr, uint64_t size) {
    return ram_.alloc(dev_addr, size) ? 0 : -1;
  }

  int mem_free(uint64_t dev_addr) {
    return ram_.free(dev_addr);
  }

  int mem_info(uint64_t* mem_free, uint64_t* mem_used) const {
    return 0;
  }

  int upload(uint64_t dest_addr, const void* src, uint64_t size) {
    if (dest_addr + size > GLOBAL_MEM_SIZE)
      return -1;

    ram_.write(dest_addr, src, size);
    return 0;
  }

  int download(void* dest, uint64_t src_addr, uint64_t size) {
    if (src_addr + size > GLOBAL_MEM_SIZE)
      return -1;

    ram_.read(src_addr, dest, size);
    return 0;
  }

  int start(uint64_t krnl_addr, uint64_t args_addr) {
    // ensure prior run completed
    if (future_.valid()) {
      future_.wait();
    }

    // set kernel info

    // start new run
    future_ = std::async(std::launch::async, [&]{
      processor_.run();
    });

    return 0;
  }
~
  int ready_wait(uint64_t timeout) {
    if (!future_.valid())
      return 0;
    uint64_t timeout_sec = timeout / 1000;
    std::chrono::seconds wait_time(1);
    for (;;) {
      // wait for 1 sec and check status
      auto status = future_.wait_for(wait_time);
      if (status == std::future_status::ready)
        break;
      if (0 == timeout_sec--)
        return -1;
    }
    return 0;
  }

private:
  PhysicalMemory      ram_;
  Processor           processor_;
  std::future<void>   future_;
};
