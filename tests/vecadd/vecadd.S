#include "ventus.h"

  .text
  .global _start
  .type   _start, @function
_start:
  li t4,32
  vsetvli t4,t4,e32,m1,ta,ma

  csrr t0, CSR_KNL
  lw a0, KNL_ARG_BASE(t0)

  lw	t0, 0(a0)
  lw	t1, 4(a0)

  vid.v v0
  csrr t2, CSR_TID
  vmv.v.x	v1, t2
  vadd.vv	v0, v0, v1

  vsll.vi	v0, v0, 2
  vadd.vx	v1, v0, t0
  vlw12.v	v1, 0(v1)

  vadd.vx	v0, v0, t1
  vsw12.v	v1, 0(v0)

end:
  endprg	x0, x0, x0
  j end