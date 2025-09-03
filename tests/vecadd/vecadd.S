#include "ventus.h"

  .text
  .global _start
  .type   _start, @function
_start:
  li t4,32
  vsetvli t4,t4,e32,m1,ta,ma

  li t4,0x2000
  csrrs t4, mstatus, t4

  csrr t0, CSR_KNL
  lw a0, KNL_ARG_BASE(t0)

#   lw	t1, 4(a0)
  lw	t2, 8(a0)

#   vmv.v.x	v1, zero
#   vmv.v.x	v4, zero
# #   li t1, 4
# #   vadd.vx	v1, v0, t1

# #   csrr t1, CSR_TID
  vid.v v1
# #   vadd.vx v1, v1, zero

# #   vadd.vx	v1, v0, t1
# #   csrr t2, CSR_TID
# #   vmv.v.x	v1, t2
# #   vadd.vv	v0, v0, v1

  vsll.vi	v2, v1, 2
# #   vsub12.vi v2, v2, 12

#   vsll.vi	v4, v1, 1

# #   vadd.vx	v1, v0, t1
# #   vlw12.v	v2, 0(v1)

  vadd.vx	v3, v2, t2
  vsw12.v	v2, 0(v3)

#   vsw12.v	v4, 0(v3)

end:
  endprg	x0, x0, x0
