!+
! Subroutine order_super_lord_slaves (ring, ix_lord)
!
! Subroutine to make the slave elements of a super_lord in order.
!
! Modules needed:
!   use bmad
!
! Input:
!   ring    -- Ring_struct: Ring.
!   ix_lord -- Integer: Index of lord element.
!
! Output
!   ring -- Ring_struct: Ring with fixed controls.
!-

#include "CESR_platform.inc"

subroutine order_super_lord_slaves (ring, ix_lord)

  use bmad_struct
  use bmad_interface
  use nr

  implicit none

  type (ring_struct), target :: ring
  type (ele_struct), pointer :: ele
  type (control_struct), allocatable :: cs_(:)

  integer i, ix, ix_lord, ix1, ix2, ns
  integer, allocatable :: ixx(:), iyy(:)

  real(rp) ds
  real(rp), allocatable :: s_rel(:)

! Init setup.

  ele => ring%ele_(ix_lord)
  ix1 = ele%ix1_slave; ix2 = ele%ix2_slave

  if (ele%control_type /= super_lord$) then
    print *, 'ERROR IN ORDER_SUPER_LORD_SLAVES: ELEMENT NOT A SUPER_LORD'
    call err_exit
  endif

! Make an array of distances between the slave elements and the lord element.
! Note that all distances are negative.

  ns = ele%n_slave
  allocate (s_rel(ns), ixx(ns), iyy(ns), cs_(ns))

  do i = ix1, ix2
    ix = ring%control_(i)%ix_slave
    ds = ring%ele_(ix)%s - ele%s
    if (ds > 0) ds = ds - ring%param%total_length
    if (-ds > ele%value(l$)) then
      print *, 'ERROR IN ORDER_SUPER_LORD_SLAVES: INTERNAL ERROR!'
      call err_exit
    endif
    s_rel(i+1-ix1) = ds
  enddo

! Sort slaves by distance.

  call indexx (s_rel, ixx)
  cs_ = ring%control_(ix1:ix2) 

  do i = 1, ns
    ring%control_(i+ix1-1) = cs_(ixx(i))
    iyy(ixx(i)) = i
  enddo
  
  do i = 1, ring%n_ic_max
    if (ring%ic_(i) >= ix1 .and. ring%ic_(i) <= ix2) then
      ring%ic_(i) = iyy(ring%ic_(i)+1-ix1) + ix1 - 1
    endif
  enddo

  deallocate (s_rel, ixx, iyy, cs_)

end subroutine
