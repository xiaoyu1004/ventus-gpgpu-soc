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
#include "device.hpp"

int vx_dev_init(callbacks_t* callbacks) {
  if (nullptr == callbacks)
    return -1;

  callbacks->dev_open = [](vx_device_h* hdevice)->int {
    if (nullptr == hdevice)
      return  -1;
    auto device = new vt_device();
    if (device == nullptr)
      return -1;
    device->init();
    DBGPRINT("DEV_OPEN: hdevice=%p\n", (void*)device);
    *hdevice = device;
    return 0;
    };

  callbacks->dev_close = [](vx_device_h hdevice)->int {
    if (nullptr == hdevice)
      return -1;
    DBGPRINT("DEV_CLOSE: hdevice=%p\n", hdevice);
    auto device = ((vt_device*)hdevice);
    delete device;
    return 0;
    };

  callbacks->dev_caps = [](vx_device_h hdevice, uint32_t caps_id, uint64_t* value)->int {
    if (nullptr == hdevice)
      return -1;
    vt_device* device = ((vt_device*)hdevice);
    uint64_t _value;
    CHECK_ERR(device->get_caps(caps_id, &_value), {
      return err;
      });
    DBGPRINT("DEV_CAPS: hdevice=%p, caps_id=%d, value=%ld\n", hdevice, caps_id, _value);
    *value = _value;
    return 0;
    };

  callbacks->mem_alloc = [](vx_device_h hdevice, uint64_t size, uint64_t* addr)->int {
    if (nullptr == hdevice
      || nullptr == addr
      || 0 == size)
      return -1;
    auto device = ((vt_device*)hdevice);
    uint64_t dev_addr;
    CHECK_ERR(device->mem_alloc(&dev_addr, size), {
      return err;
      });
    DBGPRINT("MEM_ALLOC: hdevice=%p, size=%ld, addr=%p\n", hdevice, size, dev_addr);
    *addr = dev_addr;
    return 0;
    };

  callbacks->mem_free = [](vx_device_h hdevice, uint64_t addr) {
    if (0 == addr)
      return 0;
    DBGPRINT("MEM_FREE: addr=%p\n", addr);
    auto device = ((vt_device*)hdevice);
    int err = device->mem_free(addr);
    return err;
    };

  callbacks->mem_info = [](vx_device_h hdevice, uint64_t* mem_free, uint64_t* mem_used) {
    // if (nullptr == hdevice)
    //   return -1;
    // auto device = ((vt_device*)hdevice);
    // uint64_t _mem_free, _mem_used;
    // CHECK_ERR(device->mem_info(&_mem_free, &_mem_used), {
    //   return err;
    //   });
    // DBGPRINT("MEM_INFO: hdevice=%p, mem_free=%ld, mem_used=%ld\n", hdevice, _mem_free, _mem_used);
    // if (mem_free) {
    //   *mem_free = _mem_free;
    // }
    // if (mem_used) {
    //   *mem_used = _mem_used;
    // }
    return 0;
    };

  callbacks->copy_to_dev = [](vx_device_h hdevice, uint64_t addr, const void* host_ptr, uint64_t size) {
    if (nullptr == host_ptr)
      return -1;
    auto device = ((vt_device*)hdevice);
    DBGPRINT("COPY_TO_DEV: addr=%p, host_addr=%p, size=%ld\n", addr, host_ptr, size);
    return device->upload(addr, host_ptr, size);
    };

  callbacks->copy_from_dev = [](vx_device_h hdevice, void* host_ptr, uint64_t addr, uint64_t size) {
    if (nullptr == host_ptr)
      return -1;
    auto device = ((vt_device*)hdevice);
    DBGPRINT("COPY_FROM_DEV: addr=%p, host_addr=%p, size=%ld\n", addr, host_ptr, size);
    return device->download(host_ptr, addr, size);
    };

  callbacks->start = [](vx_device_h hdevice, metadata_buffer_t& metadata, uint64_t csr_knl_addr) {
    if (nullptr == hdevice)
      return -1;
    DBGPRINT("START: hdevice=%p, knl_entry=%p, knl_args=%p\n", hdevice, metadata.knl_entry, metadata.knl_arg_base);
    auto device = ((vt_device*)hdevice);
    return device->start(metadata, csr_knl_addr);
    };

  callbacks->ready_wait = [](vx_device_h hdevice, uint64_t timeout) {
    if (nullptr == hdevice)
      return -1;
    DBGPRINT("READY_WAIT: hdevice=%p, timeout=%ld\n", hdevice, timeout);
    auto device = ((vt_device*)hdevice);
    return device->ready_wait(timeout);
    };

  return 0;
}
