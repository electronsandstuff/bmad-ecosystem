!+
! Subroutine tao_write_cmd (what)
!
! Routine to write output to a file or files or send the output to the printer.
! 
! Input:
!   what -- Character(*): What to output. See the code for more details.
!-

subroutine tao_write_cmd (what)

use tao_interface, dummy => tao_write_cmd
use tao_command_mod, only: tao_cmd_split, tao_next_switch
use tao_plot_mod, only: tao_draw_plots
use tao_top10_mod, only: tao_var_write

use quick_plot, only: qp_open_page, qp_base_library, qp_close_page
use blender_interface_mod, only: write_blender_lat_layout
use madx_ptc_module, only: m_u, m_t, print_universe_pointed, &
                           print_complex_single_structure, print_new_flat, print_universe
use beam_file_io, only: write_beam_file
use ptc_layout_mod, only: ptc_emit_calc, lat_to_ptc_layout

implicit none

type (tao_curve_array_struct), allocatable :: curve(:)
type (tao_curve_struct), pointer :: c
type (tao_plot_struct), pointer :: tp
type (tao_plot_region_struct), pointer :: r
type (tao_universe_struct), pointer :: u
type (beam_struct), pointer :: beam
type (bunch_struct), pointer :: bunch
type (branch_struct), pointer :: branch
type (ele_pointer_struct), allocatable :: eles(:)
type (ele_struct), pointer :: ele
type (coord_struct), pointer :: p
type (tao_d2_data_struct), pointer :: d2
type (tao_d1_data_struct), pointer :: d1
type (tao_data_struct), pointer :: dat
type (tao_data_struct), target :: datum
type (tao_v1_var_struct), pointer :: v1
type (tao_spin_map_struct), pointer :: sm

real(rp) scale, mat6(6,6)

character(*) what
character(1) delim
character(20) action, name, lat_type, which, last_col, b_name
character(40), allocatable :: z(:)
character(100) str
character(200) line, switch, header1, header2
character(200) file_name0, file_name, what2
character(200) :: word(12)
character(*), parameter :: r_name = 'tao_write_cmd'

integer i, j, k, m, n, ie, id, ix, iu, nd, ii, i_uni, ib, ip, ios, loc
integer i_chan, ix_beam, ix_word, ix_w2, file_format
integer n_type, n_ref, n_start, n_ele, n_merit, n_meas, n_weight, n_good, n_bunch, n_eval, n_s
integer i_min, i_max, n_len, len_d_type, ix_branch

logical is_open, ok, err, good_opt_only, at_switch, new_file, append
logical write_data_source, write_data_type, write_merit_type, write_weight, write_attribute, write_step
logical write_high_lim, write_low_lim, tao_format, eq_d_type, delim_found

!

call string_trim (what, what2, ix)
action = what2(1:ix)
call string_trim(what2(ix+1:), what2, ix_w2)

call tao_cmd_split (what2, 10, word, .true., err)
if (err) return

call match_word (action, [character(20):: &
              'hard', 'gif', 'ps', 'variable', 'bmad_lattice', 'derivative_matrix', 'digested', &
              'curve', 'mad_lattice', 'beam', 'ps-l', 'hard-l', 'covariance_matrix', &
              'mad8_lattice', 'madx_lattice', 'pdf', 'pdf-l', 'opal_lattice', '3d_model', 'gif-l', &
              'ptc', 'sad_lattice', 'spin_mat8', 'blender', 'namelist', 'xsif_lattice', 'matrix'], &
              ix, .true., matched_name = action)

if (ix == 0) then
  call out_io (s_error$, r_name, 'UNRECOGNIZED "WHAT": ' // action)
  return
elseif (ix < 0) then
  call out_io (s_error$, r_name, 'AMBIGUOUS "WHAT": ' // action)
  return
endif

iu = lunget()

select case (action)

!---------------------------------------------------
! beam

case ('beam')

  file_format = hdf5$
  is_open = .false.
  at_switch = .false.
  ix_word = 0
  file_name0 = ''

  do 
    ix_word = ix_word + 1
    if (ix_word == size(word)-1) exit

    call tao_next_switch (word(ix_word), [character(8):: '-ascii', '-at', '-hdf5'], .true., switch, err, ix)
    if (err) return

    select case (switch)
    case ('');       exit
    case ('-ascii');  file_format = ascii$
    case ('-hdf5'); file_format = hdf5$
    case ('-at')
      ix_word = ix_word + 1
      call tao_locate_elements (word(ix_word), s%global%default_universe, eles, err)
      if (err .or. size(eles) == 0) return
      at_switch = .true.
    case default
      if (file_name0 /= '') then
        call out_io (s_error$, r_name, 'EXTRA STUFF ON THE COMMAND LINE. NOTHING DONE.')
        return
      endif
      file_name0 = switch
    end select
  enddo

  if (file_format == hdf5$) then
    if (file_name0 == '') then
      file_name0 = 'beam_#.hdf5'
    else
      n = len_trim(file_name0)
      if (file_name0(n-2:n) /= '.h5' .and. file_name0(n-4:n) /= '.hdf5') then
        file_name0 = trim(file_name0) // '.hdf5'
      endif
    endif

  elseif (file_name0 == '') then
    file_name0 = 'beam_#.dat'
  endif

  if (.not. at_switch) then
    call out_io (s_error$, r_name, 'YOU NEED TO SPECIFY "-at".')
    return
  endif 

  uni_loop: do i = lbound(s%u, 1), ubound(s%u, 1)
    u => s%u(i)

    if (.not. tao_subin_uni_number (file_name0, i, file_name)) return
    call fullfilename (file_name, file_name)
    new_file = .true.

    do ie = 1, size(eles)
      ele => eles(ie)%ele
      ! Write file

      beam => u%model_branch(ele%ix_branch)%ele(ele%ix_ele)%beam
      if (.not. allocated(beam%bunch)) cycle

      call write_beam_file (file_name, beam, new_file, file_format, u%model%lat)
      new_file = .false.
    enddo 

    if (new_file) then
      call out_io (s_error$, r_name, 'BEAM NOT SAVED AT THIS ELEMENT.', &
                    'CHECK THE SETTING OF THE BEAM_SAVED_AT COMPONENT OF THE TAO_BEAM_INIT NAMELIST.', &
                    'ANOTHER POSSIBILITY IS THAT GLOBAL%TRACK_TYPE = "single" SO NO BEAM TRACKING HAS BEEN DONE.')
    else
      call out_io (s_info$, r_name, 'Written: ' // file_name)
    endif

  enddo uni_loop


!---------------------------------------------------
! 3D model script for Blender
! Note: Old cubit interface code was in tao_write_3d_floor_plan.f90 which was deleted 9/2015.

case ('blender', '3d_model')

  file_name0 = 'blender_lat_#.py'
  if (word(1) /= '') file_name0 = word(1) 

  if (word(2) /= '') then
    call out_io (s_error$, r_name, 'EXTRA STUFF ON THE COMMAND LINE. NOTHING DONE.')
    return
  endif

  do i = lbound(s%u, 1), ubound(s%u, 1)
    if (.not. tao_subin_uni_number (file_name0, i, file_name)) return
    call write_blender_lat_layout (file_name, s%u(i)%model%lat)
    call out_io (s_info$, r_name, 'Written: ' // file_name)
  enddo

!---------------------------------------------------
! bmad_lattice

case ('bmad_lattice')

  file_format = binary$
  file_name0 = 'lat_#.bmad'
  ix_word = 0

  do 
    ix_word = ix_word + 1
    if (ix_word == size(word)-1) exit

    call tao_next_switch (word(ix_word), [character(16):: '-one_file', '-format'], .true., switch, err, ix)
    if (err) return

    select case (switch)
    case ('');       exit
    case ('-one_file'); file_format = one_file$
    case ('-format')
      ix_word = ix_word + 1
      call tao_next_switch(word(ix_word), [character(16):: 'one_file', 'binary', 'ascii'], .true., switch, err, ix)
      if (err) return
      select case (switch)
      case ('one_file');   file_format = one_file$
      case ('binary');     file_format = binary$
      case ('ascii');      file_format = ascii$
      case default
        call out_io (s_error$, r_name, 'UNKNOWN -format SWITCH: ' // word(ix_word))
        return
      end select

    case default
      if (file_name0 /= 'lat_#.bmad') then
        call out_io (s_error$, r_name, 'EXTRA STUFF ON THE COMMAND LINE. NOTHING DONE.')
        return
      endif
      file_name0 = switch
    end select
  enddo

  do i = lbound(s%u, 1), ubound(s%u, 1)
    if (.not. tao_subin_uni_number (file_name0, i, file_name)) return
    call write_bmad_lattice_file (file_name, s%u(i)%model%lat, err, file_format, s%u(i)%model%tao_branch(0)%orbit(0))
    if (err) return
    call out_io (s_info$, r_name, 'Written: ' // file_name)
  enddo

!---------------------------------------------------
case ('covariance_matrix')

  if (.not. allocated (s%com%covar)) then
    call out_io (s_error$, r_name, 'COVARIANCE MATRIX NOT YET CALCULATED!')
    return
  endif

  file_name = 'covar.matrix'
  if (word(1) /= '') file_name = word(1) 

  if (word(2) /= '') then
    call out_io (s_error$, r_name, 'EXTRA STUFF ON THE COMMAND LINE. NOTHING DONE.')
    return
  endif

  call fullfilename (file_name, file_name)
  open (iu, file = file_name)

  write (iu, '(i7, 2x, a)') count(s%var%useit_opt), '! n_var'

  write (iu, *)
  write (iu, *) '! Index   Variable'

  do i = 1, s%n_var_used
    if (.not. s%var(i)%useit_opt) cycle
    write (iu, '(i7, 3x, a)') s%var(i)%ix_dvar, tao_var1_name(s%var(i))
  enddo

  write (iu, *)
  write (iu, *) '!   i     j    Covar_Mat    Alpha_Mat'

  do i = 1, ubound(s%com%covar, 1)
    do j = 1, ubound(s%com%covar, 2)
      write (iu, '(2i6, 2es13.4)') i, j, s%com%covar(i,j), s%com%alpha(i,j)
    enddo
  enddo

  call out_io (s_info$, r_name, 'Written: ' // file_name)
  close(iu)

!---------------------------------------------------
! curve

case ('curve')

  call tao_find_plots (err, word(1), 'BOTH', curve = curve, blank_means_all = .true.)
  if (err .or. size(curve) == 0) then
    call out_io (s_error$, r_name, 'CANNOT FIND CURVE')
    return
  endif

  if (size(curve) > 1) then
    call out_io (s_error$, r_name, 'MULTIPLE CURVES FIT NAME')
    return
  endif

  file_name = 'curve.dat'
  if (word(2) /= ' ') file_name = word(2)
  call fullfilename (file_name, file_name)

  c => curve(1)%c
  ok = .false.

  if (c%g%type == "phase_space") then
    i_uni = c%ix_universe
    if (i_uni == 0) i_uni = s%global%default_universe
    beam => s%u(i_uni)%model_branch(c%ix_branch)%ele(c%ix_ele_ref_track)%beam
    call file_suffixer (file_name, file_name, 'particle_dat', .true.)
    open (iu, file = file_name)
    write (iu, '(a, 6(12x, a))') '  Ix', '  x', 'px', '  y', 'py', '  z', 'pz'
    do i = 1, size(beam%bunch(1)%particle)
      write (iu, '(i6, 6es15.7)') i, (beam%bunch(1)%particle(i)%vec(j), j = 1, 6)
    enddo
    call out_io (s_info$, r_name, 'Written: ' // file_name)
    close(iu)
    ok = .true.
  endif

  if (allocated(c%x_symb) .and. allocated(c%y_symb)) then
    call file_suffixer (file_name, file_name, 'symbol_dat', .true.)
    open (iu, file = file_name)
    write (iu, '(a, 6(12x, a))') '  Ix', '  x', '  y'
    do i = 1, size(c%x_symb)
      write (iu, '(i6, 2es15.7)') i, c%x_symb(i), c%y_symb(i)
    enddo
    call out_io (s_info$, r_name, 'Written: ' // file_name)
    close(iu)
    ok = .true.
  endif

  if (allocated(c%x_line) .and. allocated(c%y_line)) then
    call file_suffixer (file_name, file_name, 'line_dat', .true.)
    open (iu, file = file_name)
    write (iu, '(a, 6(12x, a))') '  Ix', '  x', '  y'
    do i = 1, size(c%x_line)
      write (iu, '(i6, 2es15.7)') i, c%x_line(i), c%y_line(i)
    enddo
    call out_io (s_info$, r_name, 'Written: ' // file_name)
    close(iu)
    ok = .true.
  endif

  if (.not. ok) then
    call out_io (s_info$, r_name, 'No data found in curve to write')
  endif

!---------------------------------------------------
! derivative_matrix

case ('derivative_matrix')

  nd = 0
  do i = lbound(s%u, 1), ubound(s%u, 1)  
    if (.not. s%u(i)%is_on) cycle
    nd = nd + count(s%u(i)%data%useit_opt)
    if (.not. allocated(s%u(i)%dmodel_dvar)) then
      call out_io (s_error$, r_name, 'DERIVATIVE MATRIX NOT YET CALCULATED!')
      return
    endif
  enddo

  file_name = word(1)
  if (file_name == ' ') file_name = 'derivative_matrix.dat'
  call fullfilename (file_name, file_name)
  open (iu, file = file_name)

  write (iu, *) count(s%var%useit_opt), '  ! n_var'
  write (iu, *) nd, '  ! n_data'

  write (iu, *)
  write (iu, *) '! Index   Variable'

  do i = 1, s%n_var_used
    if (.not. s%var(i)%useit_opt) cycle
    write (iu, '(i7, 3x, a)') s%var(i)%ix_dvar, tao_var1_name(s%var(i))
  enddo

  write (iu, *)
  write (iu, *) '! Index   Data'

  do i = lbound(s%u, 1), ubound(s%u, 1)
    if (.not. s%u(i)%is_on) cycle
    do j = 1, size(s%u(i)%data)
      if (.not. s%u(i)%data(j)%useit_opt) cycle
      write (iu, '(i7, 3x, a)') s%u(i)%data(j)%ix_dModel, tao_datum_name(s%u(i)%data(j))
    enddo
  enddo

  write (iu, *)
  write (iu, *) ' ix_dat ix_var  dModel_dVar'
  nd = 0
  do i = lbound(s%u, 1), ubound(s%u, 1)
    if (.not. s%u(i)%is_on) cycle
    do ii = 1, size(s%u(i)%dmodel_dvar, 1)
      do j = 1, size(s%u(i)%dmodel_dvar, 2)
        write (iu, '(2i7, es15.5)') nd + ii, j, s%u(i)%dmodel_dvar(ii, j)
      enddo
    enddo
    nd = nd + count(s%u(i)%data%useit_opt)
  enddo


  call out_io (s_info$, r_name, 'Written: ' // file_name)
  close(iu)

!---------------------------------------------------
! digested

case ('digested')

  file_name0 = word(1)
  if (file_name0 == ' ') file_name0 = 'lat_#.digested'

  do i = lbound(s%u, 1), ubound(s%u, 1)
    if (.not. tao_subin_uni_number (file_name0, i, file_name)) return
    call write_digested_bmad_file (file_name, s%u(i)%model%lat)
    call out_io (s_info$, r_name, 'Written: ' // file_name)
  enddo

!---------------------------------------------------
! hard

case ('hard', 'hard-l')

  if (action == 'hard') then
    call qp_open_page ('PS', scale = 0.0_rp)
  else
    call qp_open_page ('PS-L', scale = 0.0_rp)
  endif
  call tao_draw_plots ()   ! PS out
  call qp_close_page
  call tao_draw_plots ()   ! Update the plotting window

  if (s%global%print_command == ' ') then
    call out_io (s_fatal$, r_name, 'P%PRINT_COMMAND NEEDS TO BE SET TO SEND THE PS FILE TO THE PRINTER!')
    return
  endif

  call system (trim(s%global%print_command) // ' quick_plot.ps')
  call out_io (s_blank$, r_name, 'Printing with command: ' // s%global%print_command)

!---------------------------------------------------
! Foreign lattice format

case ('mad_lattice', 'mad8_lattice', 'madx_lattice', 'opal_latice', 'sad_lattice', 'xsif_lattice')

  select case (action)
  case ('mad_lattice');   file_name0 = 'lat_#.mad8'; lat_type = 'MAD-8'
  case ('mad8_lattice');  file_name0 = 'lat_#.mad8'; lat_type = 'MAD-8'
  case ('madx_lattice');  file_name0 = 'lat_#.madx'; lat_type = 'MAD-X'
  case ('opal_lattice');  file_name0 = 'lat_#.opal'; lat_type = 'OPAL-T'
  case ('xsif_lattice');  file_name0 = 'lat_#.xsif'; lat_type = 'XSIF'
  case ('sad_lattice');   file_name0 = 'lat_#.sad';  lat_type = 'SAD'
  end select

  if (word(1) /= '') file_name0 = word(1)

  do i = lbound(s%u, 1), ubound(s%u, 1)
    if (.not. tao_subin_uni_number (file_name0, i, file_name)) return
    call write_lattice_in_foreign_format (lat_type, file_name, s%u(i)%model%lat, &
                                             s%u(i)%model%tao_branch(0)%orbit, err = err)
    if (err) return
    call out_io (s_info$, r_name, 'Written: ' // file_name)
  enddo

!---------------------------------------------------
! matrix

case ('matrix')

  ix_word = 0
  file_name = ''
  which = '-single'
  append = .false.
  i_uni = -1
  b_name = ''

  do
    ix_word = ix_word + 1
    if (ix_word == size(word)-1) exit    
    call tao_next_switch (word(ix_word), [character(16):: '-single', '-from_start', '-combined', &
                      '-universe', '-branch'], .true., switch, err, ix)
    if (err) return

    select case (switch)
    case ('')
        exit
    case ('-single', '-from_start', '-combined')
      which = switch
    case ('-universe')
      ix_word = ix_word + 1
      if (.not. is_integer(word(ix_word), i_uni)) then
        call out_io (s_error$, r_name, 'BAD UNIVERSE INDEX: ' // word(ix_word))
        return
      endif
    case ('-branch')
      ix_word = ix_word + 1
      b_name = word(ix_word)
    case default
      if (file_name /= '') then
        call out_io (s_error$, r_name, 'EXTRA STUFF ON THE COMMAND LINE. NOTHING DONE.')
        return
      endif
      file_name = switch
    end select
  enddo

  !

  u => tao_pointer_to_universe(i_uni)
  if (.not. associated(u)) then
    call out_io (s_error$, r_name, 'BAD UNIVERSE INDEX: ' // word(i_uni))
    return
  endif

  branch => pointer_to_branch(b_name, u%model%lat, blank_is_branch0 = .true.)
  if (.not. associated(branch)) then
    call out_io (s_error$, r_name, 'BAD LATTICE BRANCH NAME OR INDEX: ' // b_name)
    return
  endif

  if (file_name == '') file_name = 'matrix.dat'
  open (iu, file = file_name)


  call mat_make_unit(mat6)

  do i = 1, branch%n_ele_track
    ele => branch%ele(i)
    mat6 = matmul(ele%mat6, mat6)

    if (which == '-single' .or. which == '-combined') then
      write (iu, *)
      write (iu, '(i6, 2x, a, a16, f16.9)') i, ele%name, key_name(ele%key), ele%s
      call mat_type (ele%mat6, iu, num_form = '(4x, 6f14.8)')
    endif

    if (which == '-from_start' .or. which == '-combined') then
      write (iu, *)
      write (iu, '(a, i6, 2x, a, a16, f16.9)') 'From start to:', i, ele%name, key_name(ele%key), ele%s
      call mat_type (mat6, iu, num_form = '(4x, 6f14.8)')
    endif
  enddo

  close (iu)

!---------------------------------------------------
! namelist

case ('namelist')

  ix_word = 0
  file_name = ''
  which = ''
  append = .false.

  do
    ix_word = ix_word + 1
    if (ix_word == size(word)-1) exit
    call tao_next_switch (word(ix_word), [character(16):: '-data', '-plot', '-variable', '-append'], .true., switch, err, ix)
    if (err) return

    select case (switch)
    case ('');                             exit
    case ('-data', '-plot', '-variable');  which = switch
    case ('-append');                      append = .true.
    case default
      if (file_name /= '') then
        call out_io (s_error$, r_name, 'EXTRA STUFF ON THE COMMAND LINE. NOTHING DONE.')
        return
      endif
      file_name = switch
    end select
  enddo

  !

  if (which == '') then
    call out_io (s_error$, r_name, 'WHICH NAMELIST (-data, -variable) NOT SET.')
    return
  endif

  if (file_name == '') file_name = 'tao.namelist'

  if (append) then
    open (iu, file = file_name, access = 'append')
  else
    open (iu, file = file_name)
  endif

  !--------------
  ! namelist -data

  select case (which)
  case ('-data')
    do i = 1, size(s%u)
      u => s%u(i)

      do j = 1, u%n_d2_data_used
        d2 => u%d2_data(j)
        write (iu, *)
        write (iu, '(a)') '!---------------------------------------'
        write (iu, *)
        write (iu, '(a)')     '&tao_d2_data'
        write (iu, '(2a)')    '  d2_data%name = ', quote(d2%name)
        write (iu, '(a, i0)') '  universe = ', i
        write (iu, '(a, i0)') '  n_d1_data = ', size(d2%d1)
        write (iu, '(a)')     '/'

        do k = 1, size(d2%d1)
          d1 => d2%d1(k)
          write (iu, *)
          write (iu, '(a)')      '&tao_d1_data'
          write (iu, '(2a)')     '  d1_data%name   = ', quote(d1%name)
          write (iu, '(a, i0)')  '  ix_d1_data     = ', k
          i_min = lbound(d1%d, 1);   i_max = ubound(d1%d, 1)
          write (iu, '(a, i0)')  '  ix_min_data    = ', i_min
          write (iu, '(a, i0)')  '  ix_max_data    = ', i_max

          ! Data output parameter-by-parameter

          len_d_type = 0
          eq_d_type = .true.
          do id = i_min, i_max
            len_d_type = max(len_d_type, len_trim(d1%d(id)%data_type))
            eq_d_type = eq_d_type .and. d1%d(id)%data_type == d1%d(i_min)%data_type
          enddo

          if ((eq_d_type .and. (size(d1%d) > 10)) .or. len_d_type > 30) then
            write_data_source = .true.
            if (all(d1%d%data_source == d1%d(i_min)%data_source)) then
              if (d1%d(i_min)%data_source /= tao_d2_d1_name(d1, .false.)) write (iu, '(2a)') '  default_data_source = ', quote(d1%d(i_min)%data_source)
              write_data_source = .false.
            endif

            write_data_type = .true.
            if (eq_d_type) then
              write (iu, '(2a)') '  default_data_type = ', quote(d1%d(i_min)%data_type)
              write_data_type = .false.
            endif

            write_merit_type = .true.
            if (all(d1%d%merit_type == 'target')) then
              write_merit_type = .false.
            endif

            write_weight = .true.
            if (all(d1%d%weight == d1%d(i_min)%weight)) then
              write (iu, '(2a)') '  default_weight = ', real_to_string(d1%d(i_min)%weight, 12, 5)
              write_weight = .false.
            endif

            if (write_data_source) call namelist_param_out ('d', 'data_source', i_min, i_max, d1%d%data_source)
            if (write_data_type)   call namelist_param_out ('d', 'data_type', i_min, i_max, data_type_arr = d1%d)
            call namelist_param_out ('d', 'ele_name', i_min, i_max, d1%d%ele_name)
            call namelist_param_out ('d', 'ele_start_name', i_min, i_max, d1%d%ele_start_name, '')
            call namelist_param_out ('d', 'ele_ref_name', i_min, i_max, d1%d%ele_ref_name, '')
            if (write_merit_type)  call namelist_param_out ('d', 'merit_type', i_min, i_max, d1%d%merit_type, '')

            if (any(d1%d%good_meas)) then
              call namelist_param_out ('d', 'good_meas', i_min, i_max, logic_arr = d1%d%good_meas, logic_dflt = .false.)
              call namelist_param_out ('d', 'meas', i_min, i_max, re_arr = d1%d%meas_value)
            endif

            if (any(d1%d%good_ref)) then
              call namelist_param_out ('d', 'good_ref', i_min, i_max, logic_arr = d1%d%good_ref, logic_dflt = .false.)
              call namelist_param_out ('d', 'ref', i_min, i_max, re_arr = d1%d%ref_value)
            endif

            if (write_weight)      call namelist_param_out ('d', 'weight', i_min, i_max, re_arr = d1%d%weight)
            call namelist_param_out ('d', 'good_user', i_min, i_max, logic_arr = d1%d%good_user, logic_dflt = .true.)
            call namelist_param_out ('d', 'eval_point', i_min, i_max, anchor_pt_name(d1%d%eval_point), anchor_pt_name(anchor_end$))
            call namelist_param_out ('d', 's_offset', i_min, i_max, re_arr = d1%d%s_offset, re_dflt = 0.0_rp)
            call namelist_param_out ('d', 'ix_bunch', i_min, i_max, int_arr = d1%d%ix_bunch, int_dflt = 0)

          ! Data output datum-by-datum
          else
            n_type   = max(11, len_d_type)
            n_ref    = max(11, maxval(len_trim(d1%d%ele_ref_name)))
            n_start  = max(11, maxval(len_trim(d1%d%ele_start_name)))
            n_ele    = max(11, maxval(len_trim(d1%d%ele_name)))
            n_merit  = max(10, maxval(len_trim(d1%d%merit_type)))
            n_meas   = 14
            n_weight = 12
            n_good   = 6
            n_bunch  = 6
            n_eval   = max(8, maxval(len_trim(anchor_pt_name(d1%d%eval_point))))
            n_s      = 12

            last_col = 'merit'
            if (any(d1%d%meas_value /= 0)) last_col = 'meas'
            if (any(d1%d%weight /= 0)) last_col = 'weight'
            if (any(d1%d%good_user .neqv. .true.)) last_col = 'good'
            if (any(d1%d%ix_bunch /= 0)) last_col = 'bunch'
            if (any(d1%d%eval_point /= anchor_end$)) last_col = 'eval'
            if (any(d1%d%s_offset /= 0)) last_col = 's'

            do m = i_min, i_max
              dat => d1%d(m)
              header1 =                  '  !'
              header2 =                  '  !'
              write (line, '(a, i3, a)') '  datum(', m, ') ='
              n_len = len_trim(line) + 1
              call namelist_item_out (header1, header2, line, n_len, n_type,    'data_', 'type', dat%data_type)
              call namelist_item_out (header1, header2, line, n_len, n_ref,     'ele_ref', 'name', dat%ele_ref_name)
              call namelist_item_out (header1, header2, line, n_len, n_start,   'ele_start', 'name', dat%ele_start_name)
              call namelist_item_out (header1, header2, line, n_len, n_ele,     'ele', 'name', dat%ele_name)
              call namelist_item_out (header1, header2, line, n_len, n_merit,   'merit', 'type', dat%merit_type)
              call namelist_item_out (header1, header2, line, n_len, n_meas,    'meas', 'value', re_val = dat%meas_value)
              call namelist_item_out (header1, header2, line, n_len, n_weight,  'weight', '', re_val = dat%weight)
              call namelist_item_out (header1, header2, line, n_len, n_good ,   'good', 'user', logic_val = dat%good_user)
              call namelist_item_out (header1, header2, line, n_len, n_bunch,   'ix', 'bunch', int_val = dat%ix_bunch)
              call namelist_item_out (header1, header2, line, n_len, n_eval,    'eval', 'point', anchor_pt_name(dat%eval_point))
              call namelist_item_out (header1, header2, line, n_len, n_s,       's', 'offset', re_val = dat%s_offset)
            enddo
          endif

          ! spin out

          do m = i_min, i_max
            if (any(d1%d(m)%spin_map%axis0%n0 /= 0)) &
                    write (iu, '(a, i0, a, 3f12.6)') 'datum(', m, ')%spin_axis%n0 = ', d1%d(m)%spin_map%axis0%n0
          enddo

          write (iu, '(a)') '/'
        enddo

      enddo
    enddo

  !--------------------------------------------
  ! namelist -plot

  case ('-plot')

    write (iu, '(a)') '&tao_plot_page'
    j = 0
    do i = 1, size(s%plot_page%region)
      r => s%plot_page%region(i)
      if (r%plot%name == '' .or. .not. r%visible) cycle
      j = j + 1
      write (iu, '(a, i0, a, i0, 2a)') '  place(', j, ') = @R', r%plot%ix_plot, ', ',  r%plot%name 
    enddo
    write (iu, '(a, /)') '/'

  !--------------------------------------------
  ! namelist -variable

  case ('-variable')

    do i = 1, s%n_v1_var_used
      v1 => s%v1_var(i)
      write (iu, *)
      write (iu, '(a)') '!---------------------------------------'
      write (iu, *)
      write (iu, '(a)')    '&tao_var'
      write (iu, '(2a)')   '  v1_var%name   = ', quote(v1%name)
      i_min = lbound(v1%v, 1);   i_max = ubound(v1%v, 1)
      write (iu, '(a, i0)')  '  ix_min_var    = ', i_min
      write (iu, '(a, i0)')  '  ix_max_var    = ', i_max
      
      if (size(s%u) > 1) then
        call re_allocate2(z, i_min, i_max)
        do j = i_min, i_max
          z(j) = ''
          if (.not. v1%v(j)%exists) cycle 
          s%u%picked_uni = .false.
          do k = 1, size(v1%v(j)%slave)
            s%u(v1%v(j)%slave(k)%ix_uni)%picked_uni = .true.
          enddo
          if (all(s%u%picked_uni)) then
            z(j) = '*'
          else
            z(j) = ''
            do k = lbound(s%u, 1), ubound(s%u, 1)
              if (.not. s%u(k)%picked_uni) cycle
              if (z(j) == '') then
                z(j) = int_str(k)
              else 
                z(j) = trim(z(j)) // ', ' // int_str(k)
              endif
            enddo
          endif
        enddo

        if (all(z == z(i_min))) then
          write (iu, '(2a)') '  default_universe = ', quote(z(i_min))
        else
          call namelist_param_out ('v', 'universe', i_min, i_max, z)
        endif
      endif

      call namelist_param_out ('v', 'ele_name', i_min, i_max, v1%v%ele_name)

      if (all(v1%v%attrib_name == v1%v(i_min)%attrib_name)) then
        write (iu, '(2a)') '  default_attribute = ', quote(v1%v(i_min)%attrib_name)
      else
        call namelist_param_out ('v', 'attribute', i_min, i_max, v1%v%attrib_name)
      endif

      if (all(v1%v%step == v1%v(i_min)%step)) then
        write (iu, '(2a)') '  default_step = ', real_to_string(v1%v(i_min)%step, 12, 5)
      else
        call namelist_param_out ('v', 'step', i_min, i_max, re_arr = v1%v%step)
      endif

      if (all(v1%v%weight == v1%v(i_min)%weight)) then
        write (iu, '(2a)') '  default_weight = ', real_to_string(v1%v(i_min)%weight, 12, 5)
      else
        call namelist_param_out ('v', 'weight', i_min, i_max, re_arr = v1%v%weight)
      endif

      if (all(v1%v%merit_type == v1%v(i_min)%merit_type)) then
        write (iu, '(2a)') '  default_merit_type = ', v1%v(i_min)%merit_type
      else
        call namelist_param_out ('v', 'merit_type', i_min, i_max, v1%v%merit_type)
      endif

      if (all(v1%v%low_lim == v1%v(i_min)%low_lim)) then
        write (iu, '(2a)') '  default_low_lim = ', real_to_string(v1%v(i_min)%low_lim, 12, 5)
      else
        call namelist_param_out ('v', 'low_lim', i_min, i_max, re_arr = v1%v%low_lim, re_dflt = 0.0_rp)
      endif

      if (all(v1%v%high_lim == v1%v(i_min)%high_lim)) then
        write (iu, '(2a)') '  default_high_lim = ', real_to_string(v1%v(i_min)%high_lim, 12, 5)
      else
        call namelist_param_out ('v', 'high_lim', i_min, i_max, re_arr = v1%v%high_lim, re_dflt = 0.0_rp)
      endif

      call namelist_param_out ('v', 'good_user', i_min, i_max, logic_arr = v1%v%good_user, logic_dflt = .true.)
      call namelist_param_out ('v', 'key_bound', i_min, i_max, logic_arr = v1%v%key_bound, logic_dflt = .false.)
      call namelist_param_out ('v', 'key_delta', i_min, i_max, re_arr = v1%v%key_delta, re_dflt = 0.0_rp)
      write (iu, '(a)') '/'
    enddo
  end select

  close (iu)

!---------------------------------------------------
! ps

case ('ps', 'ps-l', 'gif', 'gif-l', 'pdf', 'pdf-l')

  if (qp_base_library == 'PGPLOT' .and. action(1:3) == 'pdf') then
    call out_io (s_error$, r_name, 'PGPLOT DOES NOT SUPPORT PDF!')
    return
  endif

  ix_word = 0
  scale = 0
  file_name = ''

  do
    ix_word = ix_word + 1
    if (ix_word == size(word)-1) exit

    call tao_next_switch (word(ix_word), ['-scale'], .true., switch, err, ix)
    if (err) return

    select case (switch)
    case ('');  exit
    case ('-scale')
      ix_word = ix_word + 1
      read (word(ix_word), *, iostat = ios) scale
      if (ios /= 0 .or. word(ix_word) == '') then
        call out_io (s_error$, r_name, 'BAD SCALE NUMBER.')
        return
      endif
    case default
      if (file_name /= '') then
        call out_io (s_error$, r_name, 'EXTRA STUFF ON THE COMMAND LINE. NOTHING DONE.')
        return
      endif
      file_name = switch
    end select
  enddo

  if (word(ix_word) /= '') then
    file_name = word(ix_word)
    if (word(ix_word+1) /= '' .or. file_name(1:1) == '-') then
      call out_io (s_error$, r_name, 'EXTRA STUFF ON THE COMMAND LINE. NOTHING DONE.')
      return
    endif
  endif

  if (file_name == '') then
    file_name = "tao.ps"
    if (action(1:3) == 'gif') file_name = 'tao.gif'
    if (action(1:3) == 'pdf') file_name = 'tao.pdf'
  endif

  call str_upcase (action, action)

  if (action(1:3) == 'GIF') then
    call qp_open_page (action, plot_file = file_name, x_len = s%plot_page%size(1), y_len = s%plot_page%size(2), &
                                                                                    units = 'POINTS', scale = scale)
  else
    call qp_open_page (action, plot_file = file_name, scale = scale)
  endif
  call tao_draw_plots (.false.)   ! GIF plot
  call qp_close_page

  call tao_draw_plots ()   ! Update the plotting window

  call out_io (s_blank$, r_name, "Created " // trim(action) // " file: " // file_name)

!---------------------------------------------------
! ptc

case ('ptc')

  which = '-new'
  u => tao_pointer_to_universe(-1)
  branch => u%model%lat%branch(0)
  file_name = ''

  do 
    call tao_next_switch (what2, [character(16):: '-old', '-branch', '-all'], .true., switch, err, ix_w2)
    if (err) return
    if (switch == '') exit

    select case (switch)
    case ('-old', '-all')
      which = switch
    case ('-branch')
      branch => pointer_to_branch (what2(1:ix_w2), u%model%lat)
      if (.not. associated(branch)) then
        call out_io (s_fatal$, r_name, 'Bad branch name or index: ' // what2(:ix_w2))
        return
      endif
    case default
      if (file_name /= '') then
        call out_io (s_error$, r_name, 'EXTRA STUFF ON THE COMMAND LINE. NOTHING DONE.')
        return
      endif
      file_name = switch
    end select
  enddo

  if (file_name == '') file_name = 'ptc.flatfile'

  if (.not. associated(branch%ptc%m_t_layout)) then
    call out_io (s_info$, r_name, 'Note: Creating PTC layout (equivalent to "ptc init").')
    call lat_to_ptc_layout (branch%lat)
  endif

  select case (which)
  case ('-old')
    call print_complex_single_structure (branch%ptc%m_t_layout, file_name)
    call out_io (s_info$, r_name, 'Written: ' // file_name)

  case ('-new')
    call print_new_flat (branch%ptc%m_t_layout, file_name)
    call out_io (s_info$, r_name, 'Written: ' // file_name)

  case ('-all')
    call print_universe (M_u, trim(file_name) // '.m_u')
    call print_universe_pointed (M_u, M_t, trim(file_name) // '.m_t')
    call out_io (s_info$, r_name, 'Written: ' // trim(file_name) // '.m_u')
    call out_io (s_info$, r_name, 'Written: ' // trim(file_name) // '.m_t')
  end select

!---------------------------------------------------
! spin

case ('spin_mat8')

  u => tao_pointer_to_universe(-1)
  branch => u%model%lat%branch(0)
  file_name = ''
  sm => datum%spin_map

  do 
    call tao_next_switch (what2, [character(16):: '-l_axis'], .true., switch, err, ix_w2)
    if (err) return
    if (switch == '') exit

    select case (switch)
    case ('-l_axis')
      read (what2, *, iostat = ios) sm%axis_input%l
      if (ios /= 0) then
        call out_io (s_error$, r_name, 'CANNOT PARSE L-AXIS: ' // what2)
        return
      endif
      call word_read(what2, ' ,', str, ix, delim, delim_found, what2) ! Strip Axis from what2
      call word_read(what2, ' ,', str, ix, delim, delim_found, what2)
      call word_read(what2, ' ,', str, ix, delim, delim_found, what2)

    case default
      if (file_name /= '') then
        call out_io (s_error$, r_name, 'EXTRA STUFF ON THE COMMAND LINE. NOTHING DONE.')
        return
      endif
      file_name = switch
    end select
  enddo

  if (file_name == '') file_name = 'spin_mat8.dat'
  call fullfilename (file_name, file_name)
  open (iu, file = file_name)

  !

  sm%axis_input%n0 = u%model%tao_branch(branch%ix_branch)%orbit(0)%spin
  datum%ix_branch = branch%ix_branch

  do ie = 1, branch%n_ele_track
    ele => branch%ele(ie)
    call tao_spin_matrix_calc (datum, u, ie-1, ie)

    write (iu, *)
    write (iu, '(i6, 2x, a, a16, f16.9)') ie, ele%name, key_name(ele%key), ele%s
    write (iu, '(2(a, 3f14.8))') 'l_start: ', sm%axis0%l,  '  l_end: ', sm%axis1%l
    write (iu, '(2(a, 3f14.8))') 'n0_start:', sm%axis0%n0, '  n0_end:', sm%axis1%n0
    write (iu, '(2(a, 3f14.8))') 'm_start: ', sm%axis0%m,  '  m_end: ', sm%axis1%m
    do i = 1, 8
      write(iu, '(5x, a)') reals_to_table_row(sm%mat8(i,:), 13, 7)
    enddo

    sm%axis_input%n0 = sm%axis1%n0
    sm%axis_input%l  = sm%axis1%l
    sm%axis_input%m  = sm%axis1%m
  enddo

  call out_io (s_info$, r_name, 'Written: ' // file_name)

!---------------------------------------------------
! variable

case ('variable')
  good_opt_only = .false.
  ix_word = 0
  file_name = ''
  tao_format = .false.

  do 
    ix_word = ix_word + 1
    if (ix_word >= size(word)-1) exit
    call tao_next_switch (word(ix_word), [character(20):: '-good_opt_only', '-tao_format'], .true., switch, err, ix)
    if (err) return
    select case (switch)
    case (''); exit
    case ('-tao_format'); tao_format = .true.
    case ('-good_opt_only'); good_opt_only = .true.
    case default
      if (file_name /= '') then
        call out_io (s_error$, r_name, 'EXTRA STUFF ON THE COMMAND LINE. NOTHING DONE.')
        return
      endif
      file_name = switch
    end select
  enddo  

  if (file_name == '') then
    call tao_var_write (s%global%var_out_file, good_opt_only, tao_format)
  else
    call tao_var_write (file_name, good_opt_only, tao_format)
  endif

!---------------------------------------------------
! error

case default

  call out_io (s_error$, r_name, 'UNKNOWN "WHAT": ' // what)

end select

!-----------------------------------------------------------------------------
contains

subroutine namelist_item_out (header1, header2, line, n_len, n_add, h1, h2, str_val, re_val, logic_val, int_val)

real(rp), optional :: re_val
integer, optional :: int_val
integer n_len, n_add
logical, optional :: logic_val
character(*) header1, header2, line, h1, h2
character(*), optional :: str_val
character(n_add) add_str

!

header1 = header1(1:n_len) // h1
header2 = header2(1:n_len) // h1

!

if (present(str_val)) then
  add_str = quote(str_val)
elseif (present(re_val)) then
  add_str = real_to_string(re_val, n_add-1, n_add-9)
elseif (present(logic_val)) then
  write (add_str, '(l2)') logic_val
elseif (present(int_val)) then
  write (add_str, '(i4)') int_val
endif

!

line = line(1:n_len) // add_str
n_len = n_len + n_add

end subroutine namelist_item_out

!-----------------------------------------------------------------------------
! contains

subroutine namelist_param_out (who, name, i_min, i_max, str_arr, str_dflt, data_type_arr, re_arr, re_dflt, logic_arr, logic_dflt, int_arr, int_dflt)

integer i_min, i_max

type (tao_data_struct), optional :: data_type_arr(i_min:)
type (var_length_string_struct) :: out_str(i_min:i_max)

real(rp), optional :: re_arr(i_min:), re_dflt

integer i
integer, optional :: int_arr(i_min:), int_dflt
logical, optional :: logic_arr(i_min:), logic_dflt

character(*) who, name
character(*), optional :: str_arr(i_min:), str_dflt
character(600) line


! Encode values

if (present(data_type_arr)) then
  do i = i_min, i_max
    out_str(i)%str = quote(data_type_arr(i)%data_type)
  enddo

elseif (present(str_arr)) then
  if (present(str_dflt)) then
    if (all(str_arr == str_dflt)) return
  endif

  do i = i_min, i_max
    out_str(i)%str = quote(str_arr(i))
  enddo

elseif (present(re_arr)) then
  if (present(re_dflt)) then
    if (all(re_arr == re_dflt)) return
  endif

  do i = i_min, i_max
    out_str(i)%str = real_to_string(re_arr(i), 15, 8)
  enddo

elseif (present(logic_arr)) then
  if (present(logic_dflt)) then
    if (all(logic_arr .eqv. logic_dflt)) return
  endif

  do i = i_min, i_max
    write (out_str(i)%str, '(l1)') logic_arr(i)
  enddo

elseif (present(int_arr)) then
  if (present(int_dflt)) then
    if (all(int_arr == int_dflt)) return
  endif

  do i = i_min, i_max
    write (out_str(i)%str, '(i0)') int_arr(i) 
  enddo
endif

! Write to output
! Note: Using an array multiplyer is not valid for strings.

if (who == 'd') then
  write (line, '(2x, 2(a, i0), 4a)') 'datum(', i_min, ':', i_max, ')%', trim(name), ' = '
else
  write (line, '(2x, 2(a, i0), 4a)') 'var(', i_min, ':', i_max, ')%', trim(name), ' = '
endif

if (all_equal_var_str(out_str, out_str(i_min)%str)) then
  if (present(str_arr)) then
    write (iu, '(a, i0, 2a)') trim(line), i_max-i_min+1, '*', quote(out_str(i_min)%str)
  else
    write (iu, '(a, i0, 2a)') trim(line), i_max-i_min+1, '*', trim(out_str(i_min)%str)
  endif
  return
endif

write (iu, '(a)') trim(line)
line = ''

do i = i_min, i_max
  if (line == '') then
    line = out_str(i)%str
  else
    line = trim(line) // ', ' // out_str(i)%str
  endif

  if (i == i_max) then
    write (iu, '(6x, a)') trim(line)
    exit
  elseif (len_trim(line) +len_trim(out_str(i+1)%str) > 100) then
    write (iu, '(6x, a)') trim(line)
    line = ''
  endif
enddo

end subroutine namelist_param_out

end subroutine tao_write_cmd
