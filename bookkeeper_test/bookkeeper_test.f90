program bookkeeper_test

use bmad
use mad_mod
use write_lat_file_mod

implicit none

type (lat_struct), target :: lat, lat2, lat3
type (ele_struct), pointer :: ele, nele
type (ele_struct) a_ele
type (ele_pointer_struct), allocatable :: eles(:)
type (coord_struct) orb
type (control_struct), pointer :: ctl
type (lat_nametable_struct) ntab

character(40) :: lat_file  = 'bookkeeper_test.bmad'
character(40) :: loc_str(12) = [character(40):: &
          '1>>drift::3:15', 'sb', '3:15:3', '1>>quad::*', 'octupole::1>>*', &
          'sb##2', 'type::*', 'alias::"q*t"', 'descrip::"So Long"', 'sb%', &
          '0>>drift::qu1:qu2', '1>>drift::qu1:qu2']
character(100) str

real(rp), allocatable :: save(:)
real(rp) m1(6,6), m2(6,6), r0(6), vec1(6), vec2(6)
integer :: i, j, k, n, ie, nargs, n_loc
logical print_extra, err

!

print_extra = .false.
nargs = cesr_iargc()
if (nargs == 1)then
   call cesr_getarg(1, lat_file)
   print *, 'Using ', trim(lat_file)
   print_extra = .true.
elseif (nargs > 1) then
  print *, 'Only one command line arg permitted.'
  call err_exit
endif

!-------------

open (1, file = 'output.now', recl = 200)

!

call bmad_parser ('bookkeeper_test1.bmad', lat)

call create_lat_ele_sorted_nametable(lat, ntab)

do i = 0, ubound(lat%branch, 1)
  n = size(ntab%branch(i)%indexx)
  write (1, '(a, i0, a, 100(a, i0))') '"Sort-B', i, '"  STR   "', (';', ntab%branch(i)%indexx(ie), ie = 1, n, 3), '"'
enddo

n = size(ntab%all_indexx)
write (1, '(a, 100(a, i0))') '"Sort-All"  STR   "', (';', ntab%all_indexx(ie), ie = 1, n, 3), '"'

!

do i = 1, size(loc_str)
  call lat_ele_locator (loc_str(i), lat, eles, n_loc, err); 
  if (n_loc == 0) then
    write (1, '(a, i0, a)') '"Loc', i, '" STR  "None"' 
  else
    write (1, '(a, i0, 100a)') '"Loc', i, '" STR  "', (trim(eles(j)%ele%name), ';', j = 1, n_loc), '"'
  endif
enddo

!

call bmad_parser ('bookkeeper_test2.bmad', lat)

write (1, "(a, 100i4)") '"lat%ic"   ABS 0    ', lat%ic(1:lat%n_ic_max)
do i = 1, lat%n_control_max
  ctl => lat%control(i)
  write (1, "(a, i0, a, 4i4)") '"lat%con', i, '"    ABS 0    ', ctl%slave, ctl%lord
enddo

do i = 1, lat%n_ele_max
  ele => lat%ele(i)
  write (1, "(a, i0, a, 6i4)") '"ele', i, '"    ABS 0    ', ele%ix1_slave, ele%n_slave, ele%n_slave_field, ele%ic1_lord, ele%n_lord, ele%n_lord_field
enddo  

do i = 1, lat%n_ele_max
  lat%ele(i)%select = .false.
  if (lat%ele(i)%type == 'A') lat%ele(i)%select = .true.
enddo

call make_hybrid_lat (lat, lat2)
call write_bmad_lattice_file('lat2.bmad', lat2)
call bmad_parser('lat2.bmad', lat3)
r0 = 0
call taylor_to_mat6(lat2%ele(1)%taylor, r0, vec1, m1)
call taylor_to_mat6(lat3%ele(1)%taylor, r0, vec2, m2)
write (1, '(a, es12.3)') '"Hybrid" ABS 1e-12  ', maxval(abs(m2-m1))+sum(abs(vec2-vec1))

!-------------

call bmad_parser (lat_file, lat, make_mats6 = .false.)

!

call set_on_off (quadrupole$, lat, off_and_save$, saved_values = save, attribute = 'Y_OFFSET')
write (1, '(a, 6f10.3)') '"ON_OFF_SAVE"  ABS 0', save(1:4)

do i = 1, lat%n_ele_max
  ele => lat%ele(i)

  if (ele%name == 'Q1') then
    write (1, '(a, f10.4)') '"Q1[K1]"     ABS 0', ele%value(k1$) 
    write (1, '(a, f10.4)') '"Q1[TILT]"   ABS 0', ele%value(tilt$) 
    write (1, '(a, f10.4)') '"Q1[HKICK]"  ABS 0', ele%value(hkick$) 
    write (1, '(a, f10.4)') '"Q1[Y_OFF]"  ABS 0', ele%value(y_offset$) 
  endif

  write (1, '(3a, f10.4)') '"', trim(ele%name), '[L]"      ABS 0', ele%value(l$)
enddo

do i = lat%n_ele_track+1, lat%n_ele_max

  ele => lat%ele(i)
  if (ele%lord_status == super_lord$) then
    write (1, '(3a, f10.4)') '"', trim(ele%name), '[L]"      ABS 0', ele%value(l$)
  endif

  if (ele%key == overlay$ .or. ele%key == group$) then
    do j = 1, size(ele%control%var)
      write (1, '(5a, f10.4)') '"', trim(ele%name), '[', &
                      trim(ele%control%var(j)%name), ']"      ABS 0', ele%control%var(j)%value
    enddo
  endif

  if (ele%name == 'GRN') then
    j = ele%ix1_slave
    str = expression_stack_to_string(lat%control(j)%stack)
    write (1, '(5a, f10.4)') '"GRN[string]" STR "', trim(str), '"'
  endif

enddo

! pointer_to_next_ele test

nele => pointer_to_next_ele(lat%ele(1), 7)
write (1, '(a, i4)') '"Next-1" ABS 0', nele%ix_ele

nele => pointer_to_next_ele(lat%ele(1), 7, .true.)
write (1, '(a, i4)') '"Next-2" ABS 0', nele%ix_ele

nele => pointer_to_next_ele(lat%ele(1), -7)
write (1, '(a, i4)') '"Next-3" ABS 0', nele%ix_ele

nele => pointer_to_next_ele(lat%ele(1), -7, .true.)
write (1, '(a, i4)') '"Next-4" ABS 0', nele%ix_ele

! Aperture

call init_ele(a_ele, quadrupole$)
a_ele%value(x1_limit$) = 1
a_ele%value(x2_limit$) = 2
a_ele%value(y1_limit$) = 3
a_ele%value(y2_limit$) = 4
a_ele%slave_status = free$
a_ele%aperture_type = rectangular$
a_ele%aperture_at = exit_end$
a_ele%orientation = -1

orb%vec = [2.1_rp, 0.0_rp, 2.9_rp, 0.0_rp, 0.0_rp, 0.0_rp]
orb%direction = 1

orb%state = alive$
call check_aperture_limit (orb, a_ele, second_track_edge$, lat%param)
write (1, '(3a)') '"Aperture-1"   STR "', trim(coord_state_name(orb%state)), '"' 

call check_aperture_limit (orb, a_ele, first_track_edge$, lat%param)
write (1, '(3a)') '"Aperture-2"   STR "', trim(coord_state_name(orb%state)), '"' 

orb%vec = [-1.1_rp, 0.0_rp, 2.9_rp, 0.0_rp, 0.0_rp, 0.0_rp]
call check_aperture_limit (orb, a_ele, first_track_edge$, lat%param)
write (1, '(3a)') '"Aperture-3"   STR "', trim(coord_state_name(orb%state)), '"' 

a_ele%orientation = 1
orb%direction = -1

orb%vec = [0.9_rp, 0.0_rp, 4.1_rp, 0.0_rp, 0.0_rp, 0.0_rp]
call check_aperture_limit (orb, a_ele, first_track_edge$, lat%param)
write (1, '(3a)') '"Aperture-4"   STR "', trim(coord_state_name(orb%state)), '"' 

orb%vec = [0.9_rp, 0.0_rp, -3.1_rp, 0.0_rp, 0.0_rp, 0.0_rp]
call check_aperture_limit (orb, a_ele, first_track_edge$, lat%param)
write (1, '(3a)') '"Aperture-5"   STR "', trim(coord_state_name(orb%state)), '"' 

a_ele%aperture_type = elliptical$
a_ele%orientation = -1

orb%vec = [0.2_rp, 0.0_rp, 4.1_rp, 0.0_rp, 0.0_rp, 0.0_rp]
call check_aperture_limit (orb, a_ele, second_track_edge$, lat%param)
write (1, '(3a)') '"Aperture-6"   STR "', trim(coord_state_name(orb%state)), '"' 

orb%vec = [-1.1_rp, 0.0_rp, -0.1_rp, 0.0_rp, 0.0_rp, 0.0_rp]
call check_aperture_limit (orb, a_ele, second_track_edge$, lat%param)
write (1, '(3a)') '"Aperture-7"   STR "', trim(coord_state_name(orb%state)), '"' 

!

call lat_ele_locator ('quad::*', lat, eles, n_loc, err)
write (1, '(a, i4)') '"N_Quad_Loc" ABS 0', n_loc

close(1)

end program
