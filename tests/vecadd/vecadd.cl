// kernel void
// vecadd (__global const int *src,
// 	__global int *dst)
// {
//   int gid = get_global_id(0);
//   int num_warps = get_num_sub_groups(0);
//   dst[gid] = num_warps;
// //   c[gid] = a[gid] + b[gid];
// }

kernel void vecadd(__global const float *a, __global const float *b,
                   __global float *c) {
  int gid = get_global_id(0);
  __local float local_mem[64];

  local_mem[gid] = a[gid];
  local_mem[32 + gid] = b[gid];

  //   local_mem[gid ^ 31] = gid;
  //   work_group_barrier(CLK_LOCAL_MEM_FENCE);
  //   c[gid] = local_mem[gid];

  c[gid] = local_mem[2 * gid] + local_mem[1 + 2 * gid];
}
