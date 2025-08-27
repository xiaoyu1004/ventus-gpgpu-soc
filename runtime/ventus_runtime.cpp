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

#include <unistd.h>
#include <string.h>
#include <string>
#include <cstdlib>
#include <dlfcn.h>

///////////////////////////////////////////////////////////////////////////////

struct metadata_buffer_t
{
  uint32_t knl_entry;
  uint32_t knl_arg_base;
  uint32_t knl_work_dim;
  uint32_t knl_gl_size_x;
  uint32_t knl_gl_size_y;
  uint32_t knl_gl_size_z;
  uint32_t knl_lc_size_x;
  uint32_t knl_lc_size_y;
  uint32_t knl_lc_size_z;
  uint32_t knl_gl_offset_x;
  uint32_t knl_gl_offset_y;
  uint32_t knl_gl_offset_z;
  uint32_t knl_print_addr;
  uint32_t knl_print_size;
};

static callbacks_t g_callbacks;

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

int vx_start(vx_device_h hdevice, uint64_t knl_addr, uint32_t *knl_args, unsigned knl_args_count) {
  return (g_callbacks.start)(hdevice, knl_addr, knl_args, knl_args_count);
}

int vx_ready_wait(vx_device_h hdevice, uint64_t timeout) {
  return (g_callbacks.ready_wait)(hdevice, timeout);
}

int vx_upload_kernel_bytes(vx_device_h hdevice, const void* content, uint64_t size, vx_buffer_h* hbuffer) {
  if (nullptr == hdevice || nullptr == content || size <= 8 || nullptr == hbuffer)
    return -1;

  auto bytes = reinterpret_cast<const uint64_t*>(content);

  auto min_vma = *bytes++;
  auto max_vma = *bytes++;
  auto bin_size = size - 2 * 8;
  auto runtime_size = (max_vma - min_vma);

  CHECK_ERR(vx_copy_to_dev(_hbuffer, bytes, 0, bin_size), {
    vx_mem_free(_hbuffer);
    return err;
    });

  *hbuffer = _hbuffer;

  return 0;
}

int vx_upload_kernel_file(vx_device_h hdevice, const char* filename, vx_buffer_h* hbuffer) {
  if (nullptr == hdevice || nullptr == filename || nullptr == hbuffer)
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
  CHECK_ERR(vx_upload_kernel_bytes(hdevice, content.data(), size, hbuffer), {
    return err;
    });

  return 0;
}

int vx_upload_bytes(vx_device_h hdevice, const void* content, uint64_t size, vx_buffer_h* hbuffer) {
  if (nullptr == hdevice || nullptr == content || 0 == size || nullptr == hbuffer)
    return -1;

  vx_buffer_h _hbuffer;

  CHECK_ERR(vx_mem_alloc(hdevice, size, VX_MEM_READ, &_hbuffer), {
    return err;
    });

  CHECK_ERR(vx_copy_to_dev(_hbuffer, content, 0, size), {
    vx_mem_free(_hbuffer);
    return err;
    });

  *hbuffer = _hbuffer;

  return 0;
}

int vx_upload_file(vx_device_h hdevice, const char* filename, vx_buffer_h* hbuffer) {
  if (nullptr == hdevice || nullptr == filename || nullptr == hbuffer)
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
  CHECK_ERR(vx_upload_bytes(hdevice, content.data(), size, hbuffer), {
    return err;
    });

  return 0;
}
