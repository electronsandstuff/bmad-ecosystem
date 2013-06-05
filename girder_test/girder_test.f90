!+
! Program girder_test
!
! This program is part of the Bmad regression testing suite.
!-

program girder_test

use bmad

implicit none

type (lat_struct), target :: lat
type (ele_struct), pointer :: girder, slave, slave2

real(rp) w_mat(3,3), w_mat_inv(3,3), mat3(3,3)
real(rp), pointer :: v(:)
integer i, ig, j, nargs

character(40) fmt
character(100) lat_file
logical print_extra

!

print_extra = .false.
lat_file = 'girder_test.bmad'

nargs = cesr_iargc()
if (nargs == 1)then
   call cesr_getarg(1, lat_file)
   print *, 'Using ', trim(lat_file)
   print_extra = .true.
elseif (nargs > 1) then
  print *, 'Only one command line arg permitted.'
  call err_exit
endif

!

call bmad_parser (lat_file, lat)

!

open (1, file = 'output.now')
fmt = '(3a, 3f20.15, 5x, 3f20.15)'

do ig = lat%n_ele_track+1, lat%n_ele_max
  girder => lat%ele(ig)
  if (girder%lord_status /= girder_lord$) cycle

  do i = 1, girder%n_slave
    slave => pointer_to_slave(girder, i)
    v => slave%value
    write (1, fmt) '"Offset: ', trim(slave%name), '" ABS 1e-14 ', v(x_offset_tot$), v(y_offset_tot$), v(z_offset_tot$)
    write (1, fmt) '"Angle:  ', trim(slave%name), '" ABS 1e-14 ', v(x_pitch_tot$), v(y_pitch_tot$), v(tilt_tot$), v(roll_tot$)
    write (1, *)

    do j = 1, slave%n_slave
      slave2 => pointer_to_slave(slave, j)
      v => slave2%value
      write (1, fmt) '"Offset: ', trim(slave2%name), '" ABS 1e-14 ', v(x_offset_tot$), v(y_offset_tot$), v(z_offset_tot$)
      write (1, fmt) '"Angle:  ', trim(slave2%name), '" ABS 1e-14 ', v(x_pitch_tot$), v(y_pitch_tot$), v(tilt_tot$), v(roll_tot$)
      write (1, *)
    enddo
  enddo
enddo

!

call floor_angles_to_w_mat (0.1_rp, 0.2_rp, 0.3_rp, w_mat, w_mat_inv)
call mat_make_unit (mat3)
mat3 = matmul(w_mat, w_mat_inv) - mat3
write (1, '(a, es10.2)') '"W_mat_inv"  ABS 1E-14', maxval(abs(mat3))

!

close (1)

end program
