__kernel void vecadd(__global const float *src, __global float *dst, float a,
                     float b, int size) {
  int tid = get_global_id(0);
  // if (tid < size) {
  //   dst[tid] = a * src[tid];
  // } else {
  //   if (tid % 2 == 0) {
  //     dst[tid] = b * src[tid];
  //   } else {
  //     dst[tid] = (b + a) * src[tid];
  //   }
  // }

  if (tid < size) {
    dst[tid] = 4 * src[tid];
  } else {
    dst[tid] = 8 * src[tid];
  }
}