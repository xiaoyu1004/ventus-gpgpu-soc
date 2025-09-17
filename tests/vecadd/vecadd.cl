kernel void
vecadd (__global const int *src,
	__global int *dst)
{
  int gid = get_global_id(0);
//   int num_warps = get_num_sub_groups(0);
  dst[gid] = gid;
//   c[gid] = a[gid] + b[gid];
}
