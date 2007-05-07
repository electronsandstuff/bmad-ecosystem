!+
! Subroutine tao_place_cmd (where, who)
!
! Subroutine to determine the placement of a plot in the plot window.
! The appropriate s%tamplate_plot(i) determined by the who argument is
! transfered to the appropriate s%plot_page%plot(j) determined by the where
! argument.
!
! Input:
!    %template_plot(i) -- template matched to who.
!   where -- Character(*): Region where the plot goes. Eg: 'top'.
!   who   -- Character(*): Type of plot. Eg: 'orbit'.
!
! Output
!    %plot_page%plot(j) -- Plot matched to where.
!-

subroutine tao_place_cmd (where, who)

use tao_mod
use tao_x_scale_mod
use quick_plot
use beam_mod

implicit none

type (tao_plot_array_struct), allocatable, save :: template(:)
type (qp_axis_struct), pointer :: ax
type (tao_universe_struct), pointer :: u
type (tao_plot_region_struct), pointer :: region
type (tao_curve_struct), pointer :: curve

integer i, j, k, i_uni
logical err

character(*) who, where
character(20) :: r_name = 'tao_place_cmd'

! Find the region where the plot is to be placed.
! The plot pointer will point to the plot associated with the region.

call tao_find_plot_region (err, where, region)
if (err) return

! If who = 'none' then no plot is wanted here so just turn off
! plotting in the region

if (who == 'none') then
  region%visible = .false.
  return
endif

! Find the template for the type of plot.

call tao_find_plots (err, who, 'TEMPLATE', template)
if (err) return

! transfer the plotting information from the template to the plot 
! representing the region

call tao_plot_struct_transfer (template(1)%p, region%plot)
region%visible = .true.
region%plot%r => region

! If the plot has a phase_space curve then recalculate the lattice

do i = 1, size(region%plot%graph)
  if (region%plot%graph(i)%type /= 'phase_space') cycle
  do j = 1, size(region%plot%graph(i)%curve)
    curve => region%plot%graph(i)%curve(j)
    if (curve%ix_ele_ref_track < 0) then
      call out_io (s_error$, r_name, &
                'BAD REFERENCE ELEMENT: ' // curve%ele_ref_name, &
                'CANNOT PLOT PHASE SPACE FOR: ' // tao_curve_name(curve))
      return
    endif
    u => s%u(tao_universe_number(curve%ix_universe))
    if (.not. allocated(u%beam_at_element(curve%ix_ele_ref_track)%bunch)) then
      call reallocate_beam (u%beam_at_element(curve%ix_ele_ref_track), &
                              u%beam_init%n_bunch, u%beam_init%n_particle)
      s%global%lattice_recalc = .true.
    endif
  enddo
enddo

end subroutine
