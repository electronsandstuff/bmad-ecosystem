!+
! Subroutine tao_show_cmd (what, stuff)
!
! Show information on variable, parameters, elements, etc.
!
! Input:
!   what  -- Character(*): What to show.
!   stuff -- Character(*): ParticularStuff to show.
!-

module tao_show_mod

contains

!--------------------------------------------------------------------

recursive subroutine tao_show_cmd (what, stuff)

use tao_mod
use tao_top10_mod
use tao_single_mod
use tao_command_mod, only: tao_cmd_split

implicit none

type (tao_universe_struct), pointer :: u
type (tao_d1_data_struct), pointer :: d1_ptr
type (tao_d2_data_struct), pointer :: d2_ptr
type (tao_data_struct), pointer :: d_ptr
type (tao_v1_var_struct), pointer :: v1_ptr
type (tao_var_struct), pointer :: v_ptr
type (tao_plot_struct), pointer :: plot
type (tao_graph_struct), pointer :: graph
type (tao_curve_struct), pointer :: curve
type (tao_plot_region_struct), pointer :: region

type (lr_wake_struct), pointer :: lr
type (ele_struct), pointer :: ele
type (coord_struct) orb
type (ele_struct) ele3

real(rp) f_phi, s_pos

character(*) :: what, stuff
character(24) :: var_name
character(24)  :: plane, fmt, imt, lmt, amt, ffmt, iimt
character(80) :: word(2)
character(8) :: r_name = "tao_show_cmd"
character(24) show_name, show2_name
character(80), pointer :: ptr_lines(:)
character(100) file_name
character(16) ele_name, name, sub_name

character(16) :: show_names(14) = (/ &
   'data       ', 'var        ', 'global     ', 'alias      ', 'top10      ', &
   'optimizer  ', 'ele        ', 'lattice    ', 'constraints', 'plot       ', &
   'write      ', 'hom        ', 'graph      ', 'curve      ' /)

character(200), allocatable, save :: lines(:)
character(100) line1, line2
character(9) angle
character(4) null_word

integer :: data_number, ix_plane
integer nl, loc, ixl, iu
integer ix, ix1, ix2, ix_s2, i, j, k, n, show_index, ju
integer num_locations
integer, allocatable, save :: ix_ele(:)

logical err, found, at_ends
logical show_all, name_found
logical, automatic :: picked(size(s%u))
logical, allocatable :: show_here(:)

!

call reallocate_integer (ix_ele,1)
call re_allocate (lines, 200, 500)
null_word = 'null'

err = .false.

lines = " "
nl = 0

fmt  = '(a, 9es16.8)'
ffmt = '(a, i0, a, es16.8)'
imt  = '(a, 9i8)'
iimt = '(a, i0, a, i8)'
lmt  = '(a, 9l)'
amt  = '(9a)'

u => s%u(s%global%u_view)

if (s%global%phase_units == radians$) f_phi = 1
if (s%global%phase_units == degrees$) f_phi = 180 / pi
if (s%global%phase_units == cycles$)  f_phi = 1 / twopi

! find what to show

if (what == ' ') then
  call out_io (s_error$, r_name, 'SHOW WHAT?')
  return
endif

call match_word (what, show_names, ix)
if (ix == 0) then
  call out_io (s_error$, r_name, 'SHOW WHAT? WORD NOT RECOGNIZED: ' // what)
  return
endif

call tao_cmd_split (stuff, 2, word, .false., err)


select case (show_names(ix))

!----------------------------------------------------------------------
! hom

case ('hom')

  nl=nl+1; lines(nl) = '       #        Freq         R/Q           Q   m  Polarization_Angle'
  do i = 1, size(u%model%lat%ele_)
    ele => u%model%lat%ele_(i)
    if (ele%key /= lcavity$) cycle
    if (ele%control_type == multipass_slave$) cycle
    nl=nl+1; write (lines(nl), '(a, i6)') ele%name, i
    do j = 1, size(ele%wake%lr)
      lr => ele%wake%lr(j)
      angle = '-'
      if (lr%polarized) write (angle, '(f9.4)') lr%angle
      nl=nl+1; write (lines(nl), '(i8, 3es12.4, i4, a)') j, &
                  lr%freq, lr%R_over_Q, lr%Q, lr%m, angle
    enddo
    nl=nl+1; lines(nl) = ' '
  enddo
  nl=nl+1; lines(nl) = '       #        Freq         R/Q           Q   m  Polarization_Angle'

  call out_io (s_blank$, r_name, lines(1:nl))

!----------------------------------------------------------------------
! write

case ('write')

  iu = lunget()
  file_name = s%global%write_file
  ix = index(file_name, '*')
  if (ix /= 0) then
    s%global%n_write_file = s%global%n_write_file + 1
    write (file_name, '(a, i3.3, a)') file_name(1:ix-1), &
                      s%global%n_write_file, trim(file_name(ix+1:))
  endif

  open (iu, file = file_name, position = 'APPEND', status = 'UNKNOWN')
  call output_direct (iu)  ! tell out_io to write to a file

  call out_io (s_blank$, r_name, ' ', 'Tao> show ' // stuff, ' ')
  call tao_show_cmd (word(1), word(2))  ! recursive

  call output_direct (0)  ! reset to not write to a file
  close (iu)
  call out_io (s_blank$, r_name, 'Written to file: ' // file_name)

  return

!----------------------------------------------------------------------
! alias

case ('alias')

  call re_allocate (lines, len(lines(1)), tao_com%n_alias+10)
  lines(1) = 'Aliases:'
  nl = 1
  do i = 1, tao_com%n_alias
    nl=nl+1; lines(nl) = trim(tao_com%alias(i)%name) // ' = "' // &
                                    trim(tao_com%alias(i)%string) // '"'
  enddo
  
  call out_io (s_blank$, r_name, lines(1:nl))

!----------------------------------------------------------------------
! constraints

case ('constraints')

  call tao_show_constraints (0, 'ALL')
  call tao_show_constraints (0, 'TOP10')

!----------------------------------------------------------------------
! data

case ('data')

  call tao_pick_universe (word(1), word(1), picked, err)
  if (err) return

  u_loop: do ju = 1, size(s%u)

    if (.not. picked(ju)) cycle
    if (.not. associated (s%u(ju)%d2_data)) return 
    u => s%u(ju)

    if (size(s%u) > 1) then
      nl=nl+1; write(lines(nl), *) ' '
      nl=nl+1; write(lines(nl), *) 'Universe:', ju
    endif

! If just "show data" then show all names

    if (word(1) == ' ') then
      nl=nl+1; write (lines(nl), '(62x, a)') 'Bounds' 
      nl=nl+1; write (lines(nl), '(5x, a, 23x, a, 14x, a)') &
                                        'd2_Name', 'Ix  d1_Name', 'Lower  Upper'
      do i = 1, size(u%d2_data)
        d2_ptr => u%d2_data(i)
        if (d2_ptr%name == ' ') cycle
        nl=nl+1; write (lines(nl), '(5x, a)') d2_ptr%name
        do j = lbound(d2_ptr%d1, 1), ubound(d2_ptr%d1, 1)
          d1_ptr => d2_ptr%d1(j)
          name = d1_ptr%name
          if (name == ' ') name = '<blank>'
          nl=nl+1; write (lines(nl), '(32x, i5, 2x, a, 2x, 2i6)') &
                        j, name, lbound(d1_ptr%d, 1), ubound(d1_ptr%d, 1)
        enddo
      enddo
      call out_io (s_blank$, r_name, lines(1:nl))
      cycle u_loop
    endif

! get pointers to the data

    call string_trim (word(2), word(2), ix)
    ! are we looking at a range of locations?
    if ((word(2) .eq. ' ') .or. (index(trim(word(2)), ' ') .ne. 0) &
                                           .or. index(word(2), ':') .ne. 0) then
      call tao_find_data (err, u, word(1), d2_ptr, d1_ptr, null_word, d_ptr)
    else
      call tao_find_data (err, u, word(1), d2_ptr, d1_ptr, word(2), d_ptr)
    endif
    if (err) return

! If d_ptr points to something then show the datum info.

    if (associated(d_ptr)) then

      nl=nl+1; write(lines(nl), amt)  '%Name:              ', d_ptr%name
      nl=nl+1; write(lines(nl), amt)  '%Ele_name:          ', d_ptr%ele_name
      nl=nl+1; write(lines(nl), amt)  '%Ele2_name:         ', d_ptr%ele2_name
      nl=nl+1; write(lines(nl), amt)  '%Data_type:         ', d_ptr%data_type
      nl=nl+1; write(lines(nl), imt)  '%Ix_ele:            ', d_ptr%ix_ele
      nl=nl+1; write(lines(nl), imt)  '%Ix_ele2:           ', d_ptr%ix_ele2
      nl=nl+1; write(lines(nl), imt)  '%Ix_ele_merit:      ', d_ptr%ix_ele_merit
      nl=nl+1; write(lines(nl), imt)  '%Ix_dModel:         ', d_ptr%ix_dModel
      nl=nl+1; write(lines(nl), imt)  '%Ix_d1:             ', d_ptr%ix_d1
      nl=nl+1; write(lines(nl), imt)  '%Ix_data:           ', d_ptr%ix_data
      nl=nl+1; write(lines(nl), fmt)  '%meas_value:        ', d_ptr%meas_value
      nl=nl+1; write(lines(nl), fmt)  '%Ref_value:         ', d_ptr%ref_value
      nl=nl+1; write(lines(nl), fmt)  '%Model_value:       ', d_ptr%model_value
      nl=nl+1; write(lines(nl), fmt)  '%base_value:        ', d_ptr%base_value
      nl=nl+1; write(lines(nl), fmt)  '%Delta:             ', d_ptr%delta
      nl=nl+1; write(lines(nl), fmt)  '%Design_value:      ', d_ptr%design_value
      nl=nl+1; write(lines(nl), fmt)  '%Old_value:         ', d_ptr%old_value
      nl=nl+1; write(lines(nl), fmt)  '%Fit_value:         ', d_ptr%fit_value
      nl=nl+1; write(lines(nl), fmt)  '%Merit:             ', d_ptr%merit
      nl=nl+1; write(lines(nl), fmt)  '%Conversion_factor: ', d_ptr%conversion_factor
      nl=nl+1; write(lines(nl), fmt)  '%S:                 ', d_ptr%s
      nl=nl+1; write(lines(nl), fmt)  '%Weight:            ', d_ptr%weight
      nl=nl+1; write(lines(nl), amt)  '%Merit_type:        ', d_ptr%merit_type
      nl=nl+1; write(lines(nl), lmt)  '%Exists:            ', d_ptr%exists
      nl=nl+1; write(lines(nl), lmt)  '%Good_meas:         ', d_ptr%good_meas
      nl=nl+1; write(lines(nl), lmt)  '%Good_ref:          ', d_ptr%good_ref
      nl=nl+1; write(lines(nl), lmt)  '%Good_user:         ', d_ptr%good_user
      nl=nl+1; write(lines(nl), lmt)  '%Good_opt:          ', d_ptr%good_opt
      nl=nl+1; write(lines(nl), lmt)  '%Good_plot:         ', d_ptr%good_plot
      nl=nl+1; write(lines(nl), lmt)  '%Useit_plot:        ', d_ptr%useit_plot
      nl=nl+1; write(lines(nl), lmt)  '%Useit_opt:         ', d_ptr%useit_opt

! Else show the d1_data info.

    elseif (associated(d1_ptr)) then

      write(lines(1), '(2a)') 'Data name: ', trim(d2_ptr%name) // ':' // d1_ptr%name
      lines(2) = ' '
      nl = 2

      line1 = '                                                                  |   Useit'
      line2 = '     Name                     Data         Model        Design    | Opt  Plot'
      nl=nl+1; lines(nl) = line1
      nl=nl+1; lines(nl) = line2

! if a range is specified, show the data range   

      allocate (show_here(lbound(d1_ptr%d,1):ubound(d1_ptr%d,1)))
      if (word(2) == ' ') then
        show_here = .true.
      else
        call location_decode (word(2), show_here, lbound(d1_ptr%d,1), num_locations)
        if (num_locations .eq. -1) then
          call out_io (s_error$, r_name, "Syntax error in range list!")
          deallocate(show_here)
          return
        endif
      endif

      call re_allocate (lines, len(lines(1)), nl+100+size(d1_ptr%d))

      do i = lbound(d1_ptr%d, 1), ubound(d1_ptr%d, 1)
        if (.not. (show_here(i) .and. d1_ptr%d(i)%exists)) cycle
        if (size(lines) > nl + 50) call re_allocate (lines, len(lines(1)), nl+100)
        nl=nl+1; write(lines(nl), '(i5, 2x, a16, 3es14.4, 2l6)') i, &
                     d1_ptr%d(i)%name, d1_ptr%d(i)%meas_value, &
                     d1_ptr%d(i)%model_value, d1_ptr%d(i)%design_value, &
                     d1_ptr%d(i)%useit_opt, d1_ptr%d(i)%useit_plot
      enddo

      deallocate(show_here)

      nl=nl+1; lines(nl) = line2
      nl=nl+1; lines(nl) = line1

! else we must have a valid d2_ptr.

    else 

      call re_allocate (lines, len(lines(1)), nl+100+size(d2_ptr%d1))

      nl=nl+1; write(lines(nl), '(2a)') 'D2_Data type:    ', d2_ptr%name
      nl=nl+1; write(lines(nl), '(5x, a)') '                   Bounds'
      nl=nl+1; write(lines(nl), '(5x, a)') 'D1_Data name    lower: Upper' 

      do i = 1, size(d2_ptr%d1)
        if (size(lines) > nl + 50) call re_allocate (lines, len(lines(1)), nl+100)
        nl=nl+1; write(lines(nl), '(5x, a, i5, a, i5)') d2_ptr%d1(i)%name, &
                  lbound(d2_ptr%d1(i)%d, 1), ':', ubound(d2_ptr%d1(i)%d, 1)
      enddo

      if (any(d2_ptr%descrip /= ' ')) then
        call re_allocate (lines, len(lines(1)), nl+100+size(d2_ptr%descrip))
        nl=nl+1; write (lines(nl), *)
        nl=nl+1; write (lines(nl), '(a)') 'Descrip:'
        do i = 1, size(d2_ptr%descrip)
          if (d2_ptr%descrip(i) /= ' ') then
            nl=nl+1; write (lines(nl), '(i4, 2a)') i, ': ', d2_ptr%descrip(i)
          endif
        enddo
      endif

    endif

    call out_io (s_blank$, r_name, lines(1:nl))

  enddo u_loop

!----------------------------------------------------------------------
! ele

case ('ele')

  call str_upcase (ele_name, word(1))

  if (index(ele_name, '*') /= 0 .or. index(ele_name, '%') /= 0) then
    write (lines(1), *) 'Matches to name:'
    nl = 1
    do loc = 1, u%model%lat%n_ele_max
      if (.not. match_wild(u%model%lat%ele_(loc)%name, ele_name)) cycle
      if (size(lines) < nl+100) call re_allocate (lines, len(lines(1)), nl+200)
      nl=nl+1; write (lines(nl), '(i8, 2x, a)') loc, u%model%lat%ele_(loc)%name
      name_found = .true.
    enddo
    if (.not. name_found) then
      nl=nl+1; write (lines(nl), *) '   *** No Matches to Name Found ***'
    endif

! else no wild cards

  else  

    call tao_locate_element (ele_name, s%global%u_view, ix_ele)
    loc = ix_ele(1)
    if (loc < 0) return

    write (lines(nl+1), *) 'Element #', loc
    nl = nl + 1

    ! Show the element info
    call type2_ele (u%model%lat%ele_(loc), ptr_lines, n, .true., 6, .false., &
                                        s%global%phase_units, .true., u%model%lat)
    if (size(lines) < nl+n+100) call re_allocate (lines, len(lines(1)), nl+n+100)
    lines(nl+1:nl+n) = ptr_lines(1:n)
    nl = nl + n
    deallocate (ptr_lines)

    orb = u%model%orb(loc)
    fmt = '(2x, a, 3p2f11.4)'
    write (lines(nl+1), *) ' '
    write (lines(nl+2), *)   'Orbit: [mm, mrad]'
    write (lines(nl+3), fmt) "X  X':", orb%vec(1:2)
    write (lines(nl+4), fmt) "Y  Y':", orb%vec(3:4)
    write (lines(nl+5), fmt) "Z  Z':", orb%vec(5:6)
    nl = nl + 5

    ! Show data associated with this element
    call show_ele_data (u, loc, lines, nl)

    found = .false.
    do i = loc + 1, u%model%lat%n_ele_max
      if (u%model%lat%ele_(i)%name /= ele_name) cycle
      if (size(lines) < nl+100) call re_allocate (lines, len(lines(1)), nl+200)
      if (found) then
        nl=nl+1; write (lines(nl), *)
        found = .true.
      endif 
      nl=nl+1;  write (lines(nl), *) &
                'Note: Found another element with same name at:', i
    enddo

  endif

  call out_io (s_blank$, r_name, lines(1:nl))

!----------------------------------------------------------------------
! global

case ('global')

  nl=nl+1; write (lines(nl), imt) 'n_universes:       ', size(s%u)
  nl=nl+1; write (lines(nl), imt) 'u_view:            ', s%global%u_view
  nl=nl+1; write (lines(nl), imt) 'phase_units:       ', s%global%phase_units
  nl=nl+1; write (lines(nl), imt) 'n_opti_cycles:     ', s%global%n_opti_cycles
  nl=nl+1; write (lines(nl), amt) 'track_type:        ', s%global%track_type
  if (s%global%track_type .eq. 'macro') &
  nl=nl+1; write (lines(nl), imt) 'bunch_to_plot::    ', s%global%bunch_to_plot
  nl=nl+1; write (lines(nl), amt) 'optimizer:         ', s%global%optimizer
  nl=nl+1; write (lines(nl), amt) 'prompt_string:     ', s%global%prompt_string
  nl=nl+1; write (lines(nl), amt) 'var_out_file:      ', s%global%var_out_file
  nl=nl+1; write (lines(nl), amt) 'opt_var_out_file:  ', s%global%opt_var_out_file
  nl=nl+1; write (lines(nl), amt) 'print_command:     ', s%global%print_command
  nl=nl+1; write (lines(nl), amt) 'current_init_file: ',s%global%current_init_file
  nl=nl+1; write (lines(nl), lmt) 'var_limits_on:     ', s%global%var_limits_on
  nl=nl+1; write (lines(nl), lmt) 'opt_with_ref:      ', s%global%opt_with_ref 
  nl=nl+1; write (lines(nl), lmt) 'opt_with_base:     ', s%global%opt_with_base
  nl=nl+1; write (lines(nl), lmt) 'plot_on:           ', s%global%plot_on
  nl=nl+1; write (lines(nl), lmt) 'var_limits_on:     ', s%global%var_limits_on
  nl=nl+1; write (lines(nl), amt) 'curren_init_file:  ', s%global%current_init_file

  call out_io (s_blank$, r_name, lines(1:nl))

!----------------------------------------------------------------------
! lattice

case ('lattice')
  
  if (word(1) .eq. ' ') then
    nl=nl+1; write (lines(nl), '(a, i3)') 'Universe: ', s%global%u_view
    nl=nl+1; write (lines(nl), '(a, i5, a, i5)') 'Regular elements:', &
                                          1, '  through', u%model%lat%n_ele_use
    if (u%model%lat%n_ele_max .gt. u%model%lat%n_ele_use) then
      nl=nl+1; write (lines(nl), '(a, i5, a, i5)') 'Lord elements:   ', &
                        u%model%lat%n_ele_use+1, '  through', u%model%lat%n_ele_max
    else
      nl=nl+1; write (lines(nl), '(a)') "there are NO Lord elements"
    endif
    if (u%is_on) then
      nl=nl+1; write (lines(nl), '(a)') 'This universe is turned ON'
    else
      nl=nl+1; write (lines(nl), '(a)') 'This universe is turned OFF'
    endif
    call out_io (s_blank$, r_name, lines(1:nl))
    return
  endif
  
  allocate (show_here(0:u%model%lat%n_ele_use))
  if (word(1) == 'all') then
    show_here = .true.
  else
    word(2) = trim(word(1)) // trim(word(2))
    call location_decode (word(2), show_here, 0, num_locations)
    if (num_locations .eq. -1) then
      call out_io (s_error$, r_name, "Syntax error in range list!")
      deallocate(show_here)
      return
    endif
  endif

  if (.true.) then
    at_ends = .true.
    write (lines(nl+1), '(37x, a)') 'Model values at End of Element:'
  else
    at_ends = .false.
    write (lines(nl+1), '(37x, a)') 'Model values at Center of Element:'
  endif


  write (lines(nl+2), '(29x, 22x, a)') &
                     '|              X           |             Y        '
  write (lines(nl+3), '(6x, a, 16x, a)') ' Name             key', &
                  '   S    |  Beta   Phi   Eta  Orb   | Beta    Phi    Eta   Orb'

  nl=nl+3
  do ix = lbound(show_here,1), ubound(show_here,1)
    if (.not. show_here(ix)) cycle
    if (size(lines) < nl+100) call re_allocate (lines, len(lines(1)), nl+200)
    ele => u%model%lat%ele_(ix)
    if (ix == 0 .or. at_ends) then
      ele3 = ele
      orb = u%model%orb(ix)
      s_pos = ele3%s
    else
      call twiss_and_track_partial (u%model%lat%ele_(ix-1), ele, &
                u%model%lat%param, ele%value(l$)/2, ele3, u%model%orb(ix-1), orb)
      s_pos = ele%s-ele%value(l$)/2
    endif
    nl=nl+1
    write (lines(nl), '(i6, 1x, a16, 1x, a16, f10.3, 2(f7.2, f8.3, f5.1, f8.3))') &
          ix, ele%name, key_name(ele%key), s_pos, &
          ele3%x%beta, f_phi*ele3%x%phi, ele3%x%eta, 1000*orb%vec(1), &
          ele3%y%beta, f_phi*ele3%y%phi, ele3%y%eta, 1000*orb%vec(3)
  enddo

  write (lines(nl+1), '(6x, a, 16x, a)') ' Name             key', &
                  '   S    |  Beta   Phi   Eta  Orb   | Beta    Phi    Eta   Orb'
  write (lines(nl+2), '(29x, 22x, a)') &
                     '|              X           |             Y        '
  nl=nl+2
  
  call out_io (s_blank$, r_name, lines(1:nl))

  deallocate(show_here)

!----------------------------------------------------------------------
! optimizer

case ('optimizer')

  do i = 1, size(s%u)
    u => s%u(i)
    call out_io (s_blank$, r_name, ' ', 'Data Used:')
    write (lines(1), '(a, i4)') 'Universe: ', i
    if (size(s%u) > 1) call out_io (s_blank$, r_name, lines(1))
    do j = 1, size(u%d2_data)
      if (u%d2_data(j)%name == ' ') cycle
      call tao_data_show_use (u%d2_data(j))
    enddo
  enddo

  call out_io (s_blank$, r_name, ' ', 'Variables Used:')
  do j = 1, size(s%v1_var)
    if (s%v1_var(j)%name == ' ') cycle
    call tao_var_show_use (s%v1_var(j))
  enddo

  nl=nl+1; lines(nl) = ' '
  nl=nl+1; write (lines(nl), amt) 'optimizer:        ', s%global%optimizer
  call out_io (s_blank$, r_name, lines(1:nl))

!----------------------------------------------------------------------
! plots

case ('plot')

! word(1) is blank => print overall info

  if (word(1) == ' ') then

    nl=nl+1; lines(nl) = '   '
    nl=nl+1; lines(nl) = '  Template Plots :   Graphs'
    do i = 1, size(s%template_plot)
      plot => s%template_plot(i)
      if (plot%name == ' ') cycle
      ix = len(name) - len_trim(plot%name) + 1
      name = ' '
      name(ix:) = trim(plot%name)
      nl=nl+1; write (lines(nl), '(2a)') name, ' :'
      if (associated(plot%graph)) then
        do j = 1, size(plot%graph)
          nl=nl+1; write (lines(nl), '(21x, a)') plot%graph(j)%name
        enddo
      endif
    enddo

    nl=nl+1; lines(nl) = ' '
    nl=nl+1; lines(nl) = '[Visible]     Plot Region     <-->  Template' 
    nl=nl+1; lines(nl) = '---------     -----------           ------------'
    do i = 1, size(s%plot_page%region)
      region => s%plot_page%region(i)
      nl=nl+1; write (lines(nl), '(3x l1, 10x, 3a)') region%visible, &
                                    region%name, '<-->  ', region%plot%name
    enddo

    call out_io (s_blank$, r_name, lines(1:nl))
    return
  endif

! Find particular plot

  call tao_find_template_plot (err, word(1), plot, graph, curve, print_flag = .false.)
  if (err) call tao_find_plot_by_region (err, word(1), plot, graph, curve)
  if (err) return

! print info on particular plot, graph, or curve

  if (.not. associated(plot)) then
    call out_io (s_error$, r_name, 'This is not a graph')
    return
  endif

  nl=nl+1; lines(nl) = 'Plot:  ' // plot%name
  nl=nl+1; write (lines(nl), amt) 'x_axis_type:              ', plot%x_axis_type
  nl=nl+1; write (lines(nl), fmt) 'x_divisions:              ', plot%x_divisions
  nl=nl+1; write (lines(nl), lmt) 'independent_graphs:       ', plot%independent_graphs
    
  nl=nl+1; write (lines(nl), *) 'Graphs:'
  do i = 1, size(plot%graph)
    nl=nl+1; write (lines(nl), amt) '   ', plot%graph(i)%name
  enddo

  call out_io (s_blank$, r_name, lines(1:nl))

!----------------------------------------------------------------------
! graph


case ('graph')

  call tao_find_template_plot (err, word(1), plot, graph, curve, print_flag = .false.)
  if (err) call tao_find_plot_by_region (err, word(1), plot, graph, curve)
  if (err) return
  if (.not. associated(graph)) then
    call out_io (s_error$, r_name, 'This is not a graph')
    return
  endif

  nl=nl+1; lines(nl) = 'Plot:  ' // plot%name
  nl=nl+1; lines(nl) = 'Graph: ' // graph%name
  nl=nl+1; lines(nl) = ' '
  nl=nl+1; write (lines(nl), amt) 'type:                     ', graph%type
  nl=nl+1; write (lines(nl), amt) 'title:                    ', trim(graph%title)
  nl=nl+1; write (lines(nl), amt) 'title_suffix:             ', trim(graph%title_suffix)
  nl=nl+1; write (lines(nl), imt) 'box:                      ', graph%box
  nl=nl+1; write (lines(nl), imt) 'ix_universe:              ', graph%ix_universe
  nl=nl+1; write (lines(nl), lmt) 'clip:                     ', graph%clip
  nl=nl+1; write (lines(nl), lmt) 'valid:                    ', graph%valid
  nl=nl+1; write (lines(nl), *) 'Curves:'

  do i = 1, size(graph%curve)
    nl=nl+1; write (lines(nl), amt) '   ', graph%curve(i)%name
  enddo

  call out_io (s_blank$, r_name, lines(1:nl))

!----------------------------------------------------------------------
! curve

case ('curve')

  call tao_find_template_plot (err, word(1), plot, graph, curve, print_flag = .false.)
  if (err) call tao_find_plot_by_region (err, word(1), plot, graph, curve)
  if (err) return
  if (.not. associated(curve)) then
    call out_io (s_error$, r_name, 'This is not a curve')
    return
  endif

  nl=nl+1; lines(nl) = 'Plot:  ' // plot%name
  nl=nl+1; lines(nl) = 'Graph: ' // graph%name
  nl=nl+1; lines(nl) = 'Curve: ' // curve%name
  nl=nl+1; lines(nl) = ' '
  nl=nl+1; write (lines(nl), amt) 'data_source:              ', curve%data_source
  nl=nl+1; write (lines(nl), amt) 'data_type:                ', curve%data_type  
  nl=nl+1; write (lines(nl), amt) 'ele_ref_name:             ', curve%ele_ref_name
  nl=nl+1; write (lines(nl), fmt) 'units_factor:             ', curve%units_factor
  nl=nl+1; write (lines(nl), imt) 'ix_universe:              ', curve%ix_universe
  nl=nl+1; write (lines(nl), imt) 'symbol_every:             ', curve%symbol_every
  nl=nl+1; write (lines(nl), imt) 'ix_ele_ref:               ', curve%ix_ele_ref
  nl=nl+1; write (lines(nl), lmt) 'use_y2:                   ', curve%use_y2
  nl=nl+1; write (lines(nl), lmt) 'draw_line:                ', curve%draw_line
  nl=nl+1; write (lines(nl), lmt) 'draw_symbols:             ', curve%draw_symbols
  nl=nl+1; write (lines(nl), lmt) 'limited:                  ', curve%limited
  nl=nl+1; write (lines(nl), lmt) 'convert:                  ', curve%convert
    
  call out_io (s_blank$, r_name, lines(1:nl))

!----------------------------------------------------------------------
! top10

case ('top10')

  call tao_top10_print ()

!----------------------------------------------------------------------
! variable
    
case ('var')

  if (.not. associated (s%v1_var)) return 

! If just "show var" then show all namees

  if (word(1) == ' ') then
    write (lines(1), '(5x, a)') '                  Bounds'
    write (lines(2), '(5x, a)') 'Name            Lower  Upper'
    nl = 2
    do i = 1, size(s%v1_var)
      v1_ptr => s%v1_var(i)
      if (v1_ptr%name == ' ') cycle
      if (size(lines) < nl+100) call re_allocate (lines, len(lines(1)), nl+200)
      nl=nl+1
      write(lines(nl), '(5x, a, i5, i7)') v1_ptr%name, &
                  lbound(v1_ptr%v, 1), ubound(v1_ptr%v, 1)
    enddo
    call out_io (s_blank$, r_name, lines(1:nl))
    return
  endif

! get pointers to the variables

  call string_trim (word(2), word(2), ix)
! are we looking at a range of locations?
  if ((word(2) .eq. ' ') .or. (index(trim(word(2)), ' ') .ne. 0) &
                                       .or. index(word(2), ':') .ne. 0) then
    call tao_find_var(err, word(1), v1_ptr, null_word, v_ptr) 
  else
    call tao_find_var(err, word(1), v1_ptr, word(2), v_ptr) 
  endif
  if (err) return

! v_ptr is valid then show the variable info.

  if (associated(v_ptr)) then

    nl=nl+1; write(lines(nl), amt)  'Name:          ', v_ptr%name        
    nl=nl+1; write(lines(nl), amt)  'Alias:         ', v_ptr%alias       
    nl=nl+1; write(lines(nl), amt)  'Ele_name:      ', v_ptr%ele_name    
    nl=nl+1; write(lines(nl), amt)  'Attrib_name:   ', v_ptr%attrib_name 
    nl=nl+1; write(lines(nl), imt)  'Ix_var:        ', v_ptr%ix_var
    nl=nl+1; write(lines(nl), imt)  'Ix_dvar:       ', v_ptr%ix_dvar           
    nl=nl+1; write(lines(nl), imt)  'Ix_v1:         ', v_ptr%ix_v1
    nl=nl+1; write(lines(nl), fmt)  'Model_value:   ', v_ptr%model_value
    nl=nl+1; write(lines(nl), fmt)  'Base_value:    ', v_ptr%base_value

    if (.not. associated (v_ptr%this)) then
      nl=nl+1; write(lines(nl), imt)  'this(:) -- Not associated!'
    else
      do i = 1, size(v_ptr%this)
        nl=nl+1; write(lines(nl), iimt)  '%this(', i, ')%Ix_uni:        ', &
                                                            v_ptr%this(i)%ix_uni
        nl=nl+1; write(lines(nl), iimt)  '%this(', i, ')%Ix_ele:        ', v_ptr%this(i)%ix_ele
        if (associated (v_ptr%this(i)%model_ptr)) then
          nl=nl+1; write(lines(nl), ffmt)  '%this(', i, ')%Model_ptr:   ', &
                                                            v_ptr%this(i)%model_ptr
        else
          nl=nl+1; write(lines(nl), ffmt)  '%this(', i, ')%Model_ptr:   <not associated>'
        endif
        if (associated (v_ptr%this(i)%base_ptr)) then
          nl=nl+1; write(lines(nl), ffmt)  '%this(', i, ')%Base_ptr:    ', &
                                                            v_ptr%this(i)%base_ptr
        else
          nl=nl+1; write(lines(nl), ffmt)  '%this(', i, ')%Base_ptr:    <not associated>'
        endif
      enddo
    endif

    nl=nl+1; write(lines(nl), fmt)  '%Design_value:    ', v_ptr%design_value
    nl=nl+1; write(lines(nl), fmt)  '%Old_value:       ', v_ptr%old_value
    nl=nl+1; write(lines(nl), fmt)  '%Meas_value:      ', v_ptr%meas_value
    nl=nl+1; write(lines(nl), fmt)  '%Ref_value:       ', v_ptr%ref_value
    nl=nl+1; write(lines(nl), fmt)  '%Correction_value:', v_ptr%correction_value
    nl=nl+1; write(lines(nl), fmt)  '%High_lim:        ', v_ptr%high_lim
    nl=nl+1; write(lines(nl), fmt)  '%Low_lim:         ', v_ptr%low_lim
    nl=nl+1; write(lines(nl), fmt)  '%Step:            ', v_ptr%step
    nl=nl+1; write(lines(nl), fmt)  '%Weight:          ', v_ptr%weight
    nl=nl+1; write(lines(nl), fmt)  '%Delta:           ', v_ptr%delta
    nl=nl+1; write(lines(nl), amt)  '%Merit_type:      ', v_ptr%merit_type
    nl=nl+1; write(lines(nl), fmt)  '%Merit:           ', v_ptr%merit
    nl=nl+1; write(lines(nl), fmt)  '%dMerit_dVar:     ', v_ptr%dMerit_dVar
    nl=nl+1; write(lines(nl), lmt)  '%Exists:          ', v_ptr%exists
    nl=nl+1; write(lines(nl), lmt)  '%Good_var:        ', v_ptr%good_var
    nl=nl+1; write(lines(nl), lmt)  '%Good_user:       ', v_ptr%good_user
    nl=nl+1; write(lines(nl), lmt)  '%Good_opt:        ', v_ptr%good_opt
    nl=nl+1; write(lines(nl), lmt)  '%Useit_opt:       ', v_ptr%useit_opt
    nl=nl+1; write(lines(nl), lmt)  '%Useit_plot:      ', v_ptr%useit_plot

! check if there is a variable number
! if no variable number requested, show a range

  else

    write(lines(1), '(2a)') 'Variable name:   ', v1_ptr%name
    lines(2) = ' '
    line1 = '       Name                     Meas         Model        Design  Useit_opt'
    write (lines(3), *) line1
    nl = 3
    ! if a range is specified, show the variable range   
    if (word(2) .ne. ' ') then
      allocate (show_here(lbound(v1_ptr%v,1):ubound(v1_ptr%v,1)))
      call location_decode (word(2), show_here, lbound(v1_ptr%v,1), num_locations)
      if (num_locations .eq. -1) then
        call out_io (s_error$, r_name, "Syntax error in range list!")
        deallocate(show_here)
        return
      endif
      do i = lbound(v1_ptr%v, 1), ubound(v1_ptr%v, 1)
        if (.not. (show_here(i) .and. v1_ptr%v(i)%exists)) cycle
        if (size(lines) < nl+100) call re_allocate (lines, len(lines(1)), nl+200)
        nl=nl+1
        write(lines(nl), '(i6, 2x, a16, 3es14.4, 7x, l)') i, &
                 v1_ptr%v(i)%name, v1_ptr%v(i)%meas_value, &
                 v1_ptr%v(i)%model_value, v1_ptr%v(i)%design_value, v1_ptr%v(i)%useit_opt
      enddo 
      nl=nl+1
      write (lines(nl), *) line1
      deallocate(show_here)
    else
      do i = lbound(v1_ptr%v, 1), ubound(v1_ptr%v, 1)
        if (.not. v1_ptr%v(i)%exists) cycle
        if (size(lines) < nl+100) call re_allocate (lines, len(lines(1)), nl+200)
        nl=nl+1
        write(lines(nl), '(i6, 2x, a16, 3es14.4, 7x, l)') i, &
                 v1_ptr%v(i)%name, v1_ptr%v(i)%meas_value, &
                 v1_ptr%v(i)%model_value, v1_ptr%v(i)%design_value, v1_ptr%v(i)%useit_opt
      enddo
      nl=nl+1
      write (lines(nl), *) line1
    endif
  endif

! print out results

  call out_io (s_blank$, r_name, lines(1:nl))


!----------------------------------------------------------------------

case default

  call out_io (s_error$, r_name, "INTERNAL ERROR, SHOULDN'T BE HERE!")
  return

end select

!----------------------------------------------------------------------
!----------------------------------------------------------------------
contains

subroutine show_ele_data (u, i_ele, lines, nl)

implicit none

type (tao_universe_struct), target :: u
type (tao_data_struct), pointer :: datum
character(*) :: lines(:)
integer i_ele, nl, i

character(30) :: dmt = "(a, 3(1x, es15.5)) "

logical :: found_one = .false.

  nl=nl+1; write (lines(nl), '(a)') "  "
  nl=nl+1; write (lines(nl), '(a)') &
        "   Data Type                     |  Model Value  |  Design Value |  Base Value"

  do i = 1, size(u%data)
    if (u%data(i)%ix_ele .eq. i_ele) then
      found_one = .true.
      datum => u%data(i)
      nl = nl + 1
      write (lines(nl), dmt) datum%data_type, datum%model_value, &
                             datum%design_value, datum%base_value 
    endif
  enddo

  if (.not. found_one) then
    nl = nl +1 
    write (lines(nl), '(a)') "No data types associated with this element."
  endif

  nl=nl+1; write (lines(nl), '(a)') "  "
  nl=nl+1; write (lines(nl), '(a)') &
        "   Data Type                     |  Model Value  |  Design Value |  Base Value"


end subroutine show_ele_data

end subroutine tao_show_cmd

end module
