#include <chrono>
#include <iostream>
#include <string.h>
#include <unistd.h>
#include <vector>

#include "ventus_runtime.h"

#define NONCE 0xdeadbeef

#define RT_CHECK(_expr)                                                        \
  do {                                                                         \
    int _ret = _expr;                                                          \
    if (0 == _ret)                                                             \
      break;                                                                   \
    printf("Error: '%s' returned %d!\n", #_expr, (int)_ret);                   \
    cleanup();                                                                 \
    exit(-1);                                                                  \
  } while (false)

///////////////////////////////////////////////////////////////////////////////

typedef struct {
  uint32_t count;
  uint32_t src_addr;
  uint32_t dst_addr;
} kernel_arg_t;

const char *kernel_file = "vecadd.asm.bin";
int test = 1;

vx_device_h device = nullptr;
uint64_t src_buffer;
uint64_t dst_buffer;
uint64_t knl_entry;
uint64_t knl_arg_base;
kernel_arg_t kernel_arg = {};

void cleanup() {
  if (device) {
    vx_mem_free(device, src_buffer);
    vx_mem_free(device, dst_buffer);
    vx_mem_free(device, knl_entry);
    vx_mem_free(device, knl_arg_base);
    vx_dev_close(device);
  }
}

inline uint32_t shuffle(int i, uint32_t value) {
  return (value << i) | (value & ((1 << i) - 1));
  ;
}

int run_memcopy_test(const kernel_arg_t &kernel_arg) {
  uint32_t num_points = kernel_arg.count;
  uint32_t buf_size = num_points * sizeof(int32_t);

  std::vector<uint32_t> h_src(num_points);
  std::vector<uint32_t> h_dst(num_points);

  // update source buffer
  for (uint32_t i = 0; i < num_points; ++i) {
    h_src[i] = 1;
  }

  auto time_start = std::chrono::high_resolution_clock::now();

  // upload source buffer
  std::cout << "write source buffer to local memory" << std::endl;
  auto t0 = std::chrono::high_resolution_clock::now();
  RT_CHECK(vx_copy_to_dev(device, dst_buffer, h_src.data(), buf_size));
  auto t1 = std::chrono::high_resolution_clock::now();

  // download destination buffer
  std::cout << "read destination buffer from local memory" << std::endl;
  auto t2 = std::chrono::high_resolution_clock::now();
  RT_CHECK(vx_copy_from_dev(device, h_dst.data(), dst_buffer, buf_size));
  auto t3 = std::chrono::high_resolution_clock::now();

  // verify result
  int errors = 0;
  std::cout << "verify result" << std::endl;
  for (uint32_t i = 0; i < num_points; ++i) {
    auto cur = h_dst[i];
    auto ref = 1;
    if (cur != ref) {
      printf("*** error: [%d] expected=%d, actual=%d\n", i, ref, cur);
      ++errors;
    }
  }

  auto time_end = std::chrono::high_resolution_clock::now();

  double elapsed;
  elapsed =
      std::chrono::duration_cast<std::chrono::milliseconds>(t1 - t0).count();
  printf("upload time: %lg ms\n", elapsed);
  elapsed =
      std::chrono::duration_cast<std::chrono::milliseconds>(t3 - t2).count();
  printf("download time: %lg ms\n", elapsed);
  elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(time_end -
                                                                  time_start)
                .count();
  printf("Total elapsed time: %lg ms\n", elapsed);

  return errors;
}

int run_kernel_test(const kernel_arg_t &kernel_arg) {
  uint32_t num_points = kernel_arg.count;
  uint32_t buf_size = num_points * sizeof(int32_t);

  std::vector<uint32_t> h_src(num_points);
  std::vector<uint32_t> h_dst(num_points);

  // update source buffer
  for (uint32_t i = 0; i < num_points; ++i) {
    h_src[i] = i;
  }

  auto time_start = std::chrono::high_resolution_clock::now();

  // upload source buffer
  auto t0 = std::chrono::high_resolution_clock::now();
  RT_CHECK(vx_copy_to_dev(device, src_buffer, h_src.data(), buf_size));
  auto t1 = std::chrono::high_resolution_clock::now();

  // knl args
  RT_CHECK(vx_mem_alloc(device, sizeof(kernel_arg), &knl_arg_base));
  RT_CHECK(
      vx_copy_to_dev(device, knl_arg_base, &kernel_arg, sizeof(kernel_arg)));

  // start device
  std::cout << "start execution" << std::endl;
  auto t2 = std::chrono::high_resolution_clock::now();
  dim3 grid(num_points / 32, 1, 1);
  dim3 block(32, 1, 1);
  std::cout << std::dec << "grid.x:" << grid.x << ", grid.y:" << grid.y
            << ", grid.z:" << grid.z << std::endl;
  std::cout << std::dec << "block.x:" << block.x << ", block.y:" << block.y
            << ", block.z:" << block.z << std::endl;

  RT_CHECK(vx_start(device, grid, block, 0x80000130u, knl_arg_base));
  RT_CHECK(vx_ready_wait(device, VX_MAX_TIMEOUT));
  auto t3 = std::chrono::high_resolution_clock::now();

  // download destination buffer
  std::cout << "read destination buffer from local memory" << std::endl;
  auto t4 = std::chrono::high_resolution_clock::now();
  RT_CHECK(vx_copy_from_dev(device, h_dst.data(), dst_buffer, buf_size));
  auto t5 = std::chrono::high_resolution_clock::now();

  // verify result
  int errors = 0;
  std::cout << "verify result" << std::endl;
  for (uint32_t i = 0; i < num_points; ++i) {
    auto cur = h_dst[i];
    auto ref = i;
    if (cur != ref) {
      printf("*** error: [%d] expected=%d, actual=%d\n", i, ref, cur);
      ++errors;
    }
  }

  auto time_end = std::chrono::high_resolution_clock::now();

  double elapsed;
  elapsed =
      std::chrono::duration_cast<std::chrono::milliseconds>(t1 - t0).count();
  printf("upload time: %lg ms\n", elapsed);
  elapsed =
      std::chrono::duration_cast<std::chrono::milliseconds>(t3 - t2).count();
  printf("execute time: %lg ms\n", elapsed);
  elapsed =
      std::chrono::duration_cast<std::chrono::milliseconds>(t5 - t4).count();
  printf("download time: %lg ms\n", elapsed);
  elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(time_end -
                                                                  time_start)
                .count();
  printf("Total elapsed time: %lg ms\n", elapsed);

  return errors;
}

int main(int argc, char *argv[]) {
  // open device connection
  std::cout << "open device connection" << std::endl;
  RT_CHECK(vx_dev_open(&device));

  // uint64_t num_cores;
  // RT_CHECK(vx_dev_caps(device, VX_CAPS_NUM_CORES, &num_cores));

  uint32_t num_points = 32;
  uint32_t buf_size = num_points * sizeof(int32_t);

  std::cout << "number of points: " << num_points << std::endl;
  std::cout << "buffer size: " << buf_size << " bytes" << std::endl;

  // Upload kernel binary
  std::cout << "Upload kernel binary" << std::endl;
  RT_CHECK(vx_upload_file(device, kernel_file, &knl_entry));

  // allocate device memory
  std::cout << "allocate device memory" << std::endl;
  RT_CHECK(vx_mem_alloc(device, buf_size, &src_buffer));
  RT_CHECK(vx_mem_alloc(device, buf_size, &dst_buffer));

  kernel_arg.count = num_points;
  kernel_arg.src_addr = (uint32_t)src_buffer;
  kernel_arg.dst_addr = (uint32_t)dst_buffer;

  std::cout << "dev_src=0x" << std::hex << kernel_arg.src_addr << std::endl;
  std::cout << "dev_dst=0x" << std::hex << kernel_arg.dst_addr << std::endl;

  int errors = 0;

  // run tests
  if (0 == test || -1 == test) {
    std::cout << "run memcopy test" << std::endl;
    errors = run_memcopy_test(kernel_arg);
  }

  if (1 == test || -1 == test) {
    std::cout << "run kernel test" << std::endl;
    errors = run_kernel_test(kernel_arg);
  }

  // cleanup
  std::cout << "cleanup" << std::endl;
  cleanup();

  if (errors != 0) {
    std::cout << "Found " << std::dec << errors << " errors!" << std::endl;
    std::cout << "FAILED!" << std::endl;
    return errors;
  }

  std::cout << "Test PASSED" << std::endl;

  return 0;
}
