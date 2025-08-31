#ifndef COMMON_H
#define COMMON_H

#include <cstdint>

struct dim3
{
  dim3(uint32_t x = 1, uint32_t y = 1, uint32_t z = 1)
    : x(x), y(y), z(z) {
  }
  uint32_t x;
  uint32_t y;
  uint32_t z;
};

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

struct dispatch_info_t {
  dim3 dim_grid;
  dim3 grid_idx;

  uint32_t wg_id;
  uint32_t num_warps;
  uint32_t warp_size;
  uint32_t start_pc;
  uint32_t kernel_size_x;
  uint32_t kernel_size_y;
  uint32_t kernel_size_z;
  uint32_t pds_baseaddr;
  uint32_t csr_knl;
  uint32_t vgpr_size_total;
  uint32_t sgpr_size_total;
  uint32_t lds_size_total;
  uint32_t gds_size_total;
  uint32_t vgpr_size_per_warp;
  uint32_t sgpr_size_per_warp;
  uint32_t gds_baseaddr;
};

#endif