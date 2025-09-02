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

#include "callbacks.h"
#include "ventus_runtime.h"

#include <unistd.h>
#include <string.h>
#include <string>
#include <cstdlib>
#include <dlfcn.h>

///////////////////////////////////////////////////////////////////////////////

static callbacks_t g_callbacks;
static uint64_t g_csr_knl_addr;

typedef int (*vx_dev_init_t)(callbacks_t*);

int vx_dev_open(vx_device_h* hdevice) {
  vx_dev_init(&g_callbacks);

  vx_device_h _hdevice;
  CHECK_ERR((g_callbacks.dev_open)(&_hdevice), {
    return err;
    });

  *hdevice = _hdevice;

  return 0;
}

int vx_dev_close(vx_device_h hdevice) {
  int ret = (g_callbacks.dev_close)(hdevice);
  return ret;
}

int vx_dev_caps(vx_device_h hdevice, uint32_t caps_id, uint64_t* value) {
  return (g_callbacks.dev_caps)(hdevice, caps_id, value);
}

int vx_mem_alloc(vx_device_h hdevice, uint64_t size, uint64_t* addr) {
  return (g_callbacks.mem_alloc)(hdevice, size, addr);
}

int vx_mem_free(vx_device_h hdevice, uint64_t addr) {
  return (g_callbacks.mem_free)(hdevice, addr);
}

int vx_mem_info(vx_device_h hdevice, uint64_t* mem_free, uint64_t* mem_used) {
  return (g_callbacks.mem_info)(hdevice, mem_free, mem_used);
}

int vx_copy_to_dev(vx_device_h hdevice, uint64_t addr, const void* host_ptr, uint64_t size) {
  return (g_callbacks.copy_to_dev)(hdevice, addr, host_ptr, size);
}

int vx_copy_from_dev(vx_device_h hdevice, void* host_ptr, uint64_t addr, uint64_t size) {
  return (g_callbacks.copy_from_dev)(hdevice, host_ptr, addr, size);
}

int vx_start(vx_device_h hdevice, dim3 grid, dim3 block, uint64_t knl_entry, uint64_t knl_arg_base) {
  metadata_buffer_t metadata;
  metadata.knl_entry = (uint32_t)knl_entry;
  metadata.knl_arg_base = (uint32_t)knl_arg_base;
  metadata.knl_work_dim = 0;
  metadata.knl_gl_size_x = grid.x * block.x;
  metadata.knl_gl_size_y = grid.y * block.y;
  metadata.knl_gl_size_z = grid.z * block.z;
  metadata.knl_lc_size_x = block.x;
  metadata.knl_lc_size_y = block.y;
  metadata.knl_lc_size_z = block.z;
  metadata.knl_gl_offset_x = 0;
  metadata.knl_gl_offset_y = 0;
  metadata.knl_gl_offset_z = 0;
  metadata.knl_print_addr = 0;
  metadata.knl_print_size = 0;

  uint32_t metadata_size = sizeof(metadata);
  CHECK_ERR(vx_mem_alloc(hdevice, metadata_size, &g_csr_knl_addr), {
    return err;
    });

  CHECK_ERR(vx_copy_to_dev(hdevice, g_csr_knl_addr, &metadata, metadata_size), {
    vx_mem_free(hdevice, g_csr_knl_addr);
    return err;
    });

  return (g_callbacks.start)(hdevice, metadata, g_csr_knl_addr);
}

int vx_ready_wait(vx_device_h hdevice, uint64_t timeout) {
  int ret = (g_callbacks.ready_wait)(hdevice, timeout);
  vx_mem_free(hdevice, g_csr_knl_addr);
  return ret;
}

int vx_upload_bytes(vx_device_h hdevice, const void* content, uint64_t size, uint64_t* addr) {
  if (nullptr == hdevice || nullptr == content || 0 == size || nullptr == addr)
    return -1;

  uint64_t _addr;

  CHECK_ERR(vx_mem_alloc(hdevice, size, &_addr), {
    return err;
    });

  CHECK_ERR(vx_copy_to_dev(hdevice, _addr, content, size), {
    vx_mem_free(hdevice, _addr);
    return err;
    });

  *addr = _addr;

  return 0;
}

int vx_upload_file(vx_device_h hdevice, const char* filename, uint64_t* addr) {
  if (nullptr == hdevice || nullptr == filename || nullptr == addr)
    return -1;

  std::ifstream ifs(filename);
  if (!ifs) {
    std::cerr << "Error: " << filename << " not found" << std::endl;
    return -1;
  }
 
  // read file content
  ifs.seekg(0, ifs.end);
  auto size = ifs.tellg();
  std::vector<char> content(size);
  ifs.seekg(0, ifs.beg);
  ifs.read(content.data(), size);

  // upload buffer
  CHECK_ERR(vx_upload_bytes(hdevice, content.data(), size, addr), {
    return err;
    });

    uint8_t inst = *reinterpret_cast<uint8_t*>(content.data());
  printf("---- inst 0: %x\n", inst);

  return 0;
}
