__kernel void vecadd(__global const float *src, __global const float *dst, int size) {
  int tid = get_global_id(0);
  if (tid < size) {
    dst[tid] = 4 * src[tid]; 
  }
}