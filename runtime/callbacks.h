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

#ifndef CALLBACKS_H
#define CALLBACKS_H

#include <iostream>
#include <cassert>
#include <fstream>
#include <vector>

#include <ventus_runtime.h>

#ifndef NDEBUG
#define DBGPRINT(format, ...) do { printf("[VXDRV] " format "", ##__VA_ARGS__); } while (0)
#else
#define DBGPRINT(format, ...) ((void)0)
#endif

#define CHECK_ERR(_expr, _cleanup) \
  do { \
    auto err = _expr; \
    if (err == 0) \
      break; \
    printf("[VXDRV] Error: '%s' returned %d!\n", #_expr, (int)err); \
    _cleanup \
  } while (false)

inline uint64_t aligned_size(uint64_t size, uint64_t alignment) {
  assert(0 == (alignment & (alignment - 1)));
  return (size + alignment - 1) & ~(alignment - 1);
}

inline bool is_aligned(uint64_t addr, uint64_t alignment) {
  assert(0 == (alignment & (alignment - 1)));
  return 0 == (addr & (alignment - 1));
}

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  // open the device and connect to it
  int (*dev_open) (vx_device_h* hdevice);

  // Close the device when all the operations are done
  int (*dev_close) (vx_device_h hdevice);

  // return device configurations
  int (*dev_caps) (vx_device_h hdevice, uint32_t caps_id, uint64_t *value);

  // allocate device memory and return address
  int (*mem_alloc) (vx_device_h hdevice, uint64_t size, uint64_t* addr);

  // release device memory
  int (*mem_free) (vx_device_h hdevice, uint64_t addr);

  // get device memory info
  int (*mem_info) (vx_device_h hdevice, uint64_t* mem_free, uint64_t* mem_used);

  // Copy bytes from host to device memory
  int (*copy_to_dev) (vx_device_h hdevice, uint64_t addr, const void* host_ptr, uint64_t size);

  // Copy bytes from device memory to host
  int (*copy_from_dev) (vx_device_h hdevice, void* host_ptr, uint64_t addr, uint64_t size);

  // Start device execution
  int (*start) (vx_device_h hdevice, metadata_buffer_t &metadata, uint64_t csr_knl_addr);

  // Wait for device ready with milliseconds timeout
  int (*ready_wait) (vx_device_h hdevice, uint64_t timeout);

} callbacks_t;

int vx_dev_init(callbacks_t* callbacks);

#ifdef __cplusplus
}
#endif

#endif