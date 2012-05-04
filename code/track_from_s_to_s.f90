!+
! Subroutine track_from_s_to_s (lat, s_start, s_end, orbit_start, orbit_end, all_orb, ix_branch)
!
! Routine to track a particle between two s-positions.
! If the particle is lost in tracking, end_orb will hold the coordinates at the point of loss.
! To get the twiss parameters at the ending s-position use twiss_and_track_at_s.
!
! Modules needed:
!   use bmad
!
! Input:
!   lat         -- lat_struct: Lattice to track through
!   s_start     -- Real(rp): Starting s-position.
!   s_end       -- Real(rp): Ending s-position. If <= s_start then will wrap
!   orbit_start -- coord_struct: Starting coordinates.
!   ix_branch   -- Integer, optional: Lattice branch index. Default is 0 (main branch).
!
! Output:
!   lat%branch(ix_branch)%param -- Structure holding the info if the particle is lost.
!     %lost          -- Set True If the particle cannot make it through an element.
!                         Set False otherwise.
!     %ix_lost       -- Integer: Set to index of element where particle is lost.
!     %end_lost_at   -- entrance_end$ or exit_end$.
!     %plane_lost_at -- x_plane$, y_plane$ (for apertures), or 
!                         z_plane$ (turned around in an lcavity).
!   orbit_end   -- coord_struct: Ending coordinates.
!   all_orb(0:) -- coord_struct, allocatable, optional: If present then the orbit at the exit ends
!                   of the elements tracked through will be recorded in this structure. 
!-   

subroutine track_from_s_to_s (lat, s_start, s_end, orbit_start, orbit_end, all_orb, ix_branch)

use bookkeeper_mod

implicit none

type (lat_struct), target :: lat
type (coord_struct) orbit_start, orbit_end
type (branch_struct), pointer :: branch
type (coord_struct), optional, allocatable :: all_orb(:)

real(rp) s_start, s_end
real(rp) s0

integer, optional :: ix_branch
integer ix_start, ix_end
integer ix_ele

logical err

character(40), parameter :: r_name = 'track_from_s_to_s'

! Easy case & error check

branch => lat%branch(integer_option(0, ix_branch))
branch%param%ix_lost = not_lost$

if (s_start == s_end .and. branch%param%lattice_type == linear_lattice$) then
  orbit_end = orbit_start
  return
endif

if (s_end < s_start .and. lat%param%lattice_type == linear_lattice$) then
  call out_io (s_abort$, r_name, 'S_END < S_START WITH A LINEAR LATTICE.')
  if (bmad_status%exit_on_error) call err_exit
endif

! Find elements corresponding to s_start and s_stop

ix_start = element_at_s (lat, s_start, .true., ix_branch)
if (branch%ele(ix_start)%s == s_start) then
  ix_start = modulo (ix_start, branch%n_ele_track) + 1
endif
s0 = lat%ele(ix_start-1)%s

ix_end = element_at_s (lat, s_end, .true., ix_branch)


! Track within a single element case

if (s_end > s_start .and. ix_start == ix_end) then
  call twiss_and_track_intra_ele (branch%ele(ix_start), branch%param, s_start-s0, s_end-s0, &
                                               .true., .true., orbit_start, orbit_end)
  if (branch%param%lost) branch%param%ix_lost = ix_start
  return
endif

! Track to end of current element

call twiss_and_track_intra_ele (branch%ele(ix_start), branch%param,  &
            s_start-s0, branch%ele(ix_start)%value(l$), .true., .true., orbit_start, orbit_end)

if (branch%param%lost) then
  branch%param%ix_lost = ix_start
  return
endif

if (present(all_orb)) then
  call reallocate_coord(all_orb, branch%n_ele_max)
  all_orb(ix_start) = orbit_end
endif

! Track to ending element

ix_ele = ix_start + 1
do
  if (ix_ele == ix_end) exit

  call track1 (orbit_end, branch%ele(ix_ele), branch%param, orbit_end)

  if (present(all_orb)) all_orb(ix_ele) = orbit_end
  if (branch%param%lost) then
    branch%param%ix_lost = ix_ele
    return
  endif
  ix_ele = modulo(ix_ele, branch%n_ele_track) + 1
enddo

! Track to s_end

call twiss_and_track_intra_ele (branch%ele(ix_end), branch%param, 0.0_rp, s_end-branch%ele(ix_end-1)%s, &
                                                                      .true., .true., orbit_end, orbit_end)
if (branch%param%lost) branch%param%ix_lost = ix_end

end subroutine
