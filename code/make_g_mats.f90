!+
! Subroutine MAKE_G_MATS (ELE, G_MAT, G_INV_MAT)
!
! Subroutine make the matrices needed to go from normal mode coords 
! to coordinates with the beta function removed.
!
! Modules Needed:
!   use bmad
!
! Input:
!     ELE        -- Ele_struct: Element
!
! Output:
!     G_MAT(4,4)     -- Real(rp): Normal mode to betaless coords
!     G_INV_MAT(4,4) -- Real(rp): The inverse of G_MAT
!-

!$Id$
!$Log$
!Revision 1.5  2003/07/09 01:38:14  dcs
!new bmad with allocatable ring%ele_(:)
!
!Revision 1.4  2003/01/27 14:40:37  dcs
!bmad_version = 56
!
!Revision 1.3  2002/02/23 20:32:18  dcs
!Double/Single Real toggle added
!
!Revision 1.2  2001/09/27 18:31:52  rwh24
!UNIX compatibility updates
!

#include "CESR_platform.inc"


subroutine make_g_mats (ele, g_mat, g_inv_mat)

  use bmad_struct
  use bmad_interface

  implicit none

  type (ele_struct) ele

  real(rp) g_mat(4,4), g_inv_mat(4,4)
  real(rp) sqrt_beta_a, sqrt_beta_b, alpha_a, alpha_b
!

  sqrt_beta_a = sqrt(ele%x%beta)
  alpha_a     = ele%x%alpha
  sqrt_beta_b = sqrt(ele%y%beta)
  alpha_b     = ele%y%alpha

  g_mat = 0
  g_mat(1,1) = 1 / sqrt_beta_a
  g_mat(2,1) = alpha_a / sqrt_beta_a
  g_mat(2,2) = sqrt_beta_a
  g_mat(3,3) = 1 / sqrt_beta_b
  g_mat(4,3) = alpha_b / sqrt_beta_b
  g_mat(4,4) = sqrt_beta_b
                                  
  g_inv_mat = 0
  g_inv_mat(1,1) = sqrt_beta_a
  g_inv_mat(2,1) = -alpha_a / sqrt_beta_a
  g_inv_mat(2,2) = 1 / sqrt_beta_a
  g_inv_mat(3,3) = sqrt_beta_b
  g_inv_mat(4,3) = -alpha_b / sqrt_beta_b
  g_inv_mat(4,4) = 1 / sqrt_beta_b

end subroutine
