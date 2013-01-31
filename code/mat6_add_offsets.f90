!+
! Subroutine mat6_add_offsets (ele, param)
!
! Subroutine to add in the effect of an element's orientation in space to
! to the computed Jacobian matrix. It is assumed that the input matrix
! has been computed without offsets. That is, in the element's reference frame
!
! Modules needed:
!   use bmad
!
! Input:
!   ele       -- Ele_struct: Element with given orientation.
!     %vec0(6)        -- 0th order part of the transfer map.
!     %mat6(6,6)      -- 1st order part of the transfer map (Jacobian).
!     %map_ref_orb_in(6)  -- Reference orbit at entrance end.
!     %map_ref_orb_out(6) -- Reference orbit at exit end.
!     %value(x_offset$), 
!     %value(x_pitch$), 
!     %value(tilt$), etc.
!                     -- Offsets, tilts, and pitches
!   param    -- lat_param_struct:
!
! Output:
!   ele       -- Ele_struct: Element with given orientation.
!     %vec0(6)     -- 0th order part of the transfer map.
!     %mat6(6,6)   -- 1st order xfer map.
!     %map_ref_orb_in  -- Reference orbit at entrance end.
!     %map_ref_orb_out -- Reference orbit at exit end.
!-

subroutine mat6_add_offsets (ele, param)

use bmad_interface, except_dummy => mat6_add_offsets

implicit none

type (ele_struct) ele
type (coord_struct) orb, map_orb
type (lat_param_struct) param

! the new vec0 is obtained by just tracking through the element

orb%vec = 0
call offset_particle (ele, orb, param, set$, set_canonical = .false., set_hvkicks = .false.)
orb%vec = ele%vec0 + matmul (ele%mat6, orb%vec)
call offset_particle (ele, orb, param, unset$, set_canonical = .false., set_hvkicks = .false.)
ele%vec0 = orb%vec

! transform the ref_orb

map_orb%vec = ele%map_ref_orb_in
call offset_particle (ele, map_orb, param, unset$, &
                              set_canonical = .false., set_hvkicks = .false., ds_pos = 0.0_rp)
ele%map_ref_orb_in = map_orb%vec


map_orb%vec = ele%map_ref_orb_out
call offset_particle (ele, map_orb, param, unset$, &
                              set_canonical = .false., set_hvkicks = .false.)
ele%map_ref_orb_out = map_orb%vec

! calculate the new Jacobian.

if (ele%value(tilt_tot$) /= 0) call tilt_mat6 (ele%mat6, ele%value(tilt_tot$))
call mat6_add_pitch (ele%value(x_pitch_tot$), ele%value(y_pitch_tot$), ele%orientation, ele%mat6)

end subroutine

