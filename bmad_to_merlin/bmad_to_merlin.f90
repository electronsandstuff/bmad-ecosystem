!+
! Program bmad_to_merlin
!
! Program to create, from a Bmad lattice file, a TFS compatible file containing lattice element parameters (like element lengths, etc.).
! The Merlin++ program uses this file for lattice initialization.
!
! Usage:
!   bmad_to_merlin <bmad-lattice-file>
! Where: <bmad-lattice-file> is the name of a Bmad lattice file to be translated.
! The output file name is the same as the input file name with a ".tfs" suffix.
!
! Note: The information in the TFS file is very basic containing:
!   Element name and type
!   s-position
!   element length
!   tilt
!   angle, e1, e2         ! Bend attributes
!   k1l, k2l, k3l         ! Integrated multipoles
!   Frequency, lag, volt  ! RF attributes
!
! Note: The TFS format is a MAD standard. See the MAD manual for details on this format.
!-

program bmad_to_merlin

use bmad

implicit none

type (lat_struct), target :: lat
type (ele_struct), pointer :: ele

real(rp) angle, e1, e2, freq, lag, volt, ksl
real(rp) knl(0:n_pole_maxx), tilt(0:n_pole_maxx)
integer i, j, ix

character(200) lat_file, out_file, path, base
character(300) line1, line2
character(20) date, name, ele_type
character(8) :: col_name(16) = [character(8):: 'NAME', 'KEYWORD', 'S', 'L', 'ANGLE', 'E1', 'E2', &
                                                  'KSL', 'K0L', 'K1L', 'K2L', 'K3L', 'TILT', 'FREQ', 'LAG', 'VOLT']
character(4) :: col_type(16) = [character(4):: '%s', '%s', '%le', '%le', '%le', '%le', '%le', '%le', &
                                                       '%le', '%le', '%le', '%le', '%le', '%le', '%le', '%le']

!

select case (cesr_iargc())
case (0)
  print *, 'Usage:'
  print *, '   bmad_to_merlin <bmad-lattice-file-name>'
  print *, 'Where: <bmad-lattice-file> is the name of a Bmad lattice file to be translated.'
  stop
case (1)
  call cesr_getarg(1, lat_file)
case default
  print *, 'Too many parameters on the command line.'
  print *, 'Usage:'
  print *, '   bmad_to_merlin <bmad-lattice-file-name>'
  print *, 'Where: <bmad-lattice-file> is the name of a Bmad lattice file to be translated.'
  stop
end select

!

call bmad_parser (lat_file, lat)

ix = SplitFileName(lat_file, path, base)
out_file = trim(base) // '.tfs'
open (1, file = out_file, recl = 300)
name = upcase(species_name(lat%param%particle))

call date_and_time_stamp (date, .true.)

write (1, '(2a)')        '@ TYPE         %08s "OPTICS"'
write (1, '(2a)')        '@ ORIGIN       %14s "Bmad_to_Merlin"'
write (1, '(a, i0, 2a)') '@ PARTICLE     %', len_trim(name), 's  ', quote(name)
write (1, '(a, f16.11)') '@ MASS         %le ', mass_of(lat%param%particle) / atomic_mass_unit
write (1, '(a, i0)')     '@ CHARGE       %le  ', charge_of(lat%param%particle)
write (1, '(a, f18.10)') '@ ENERGY       %le', lat%ele(0)%value(e_tot$) / 1d9
write (1, '(a, f18.10)') '@ PC           %le', lat%ele(0)%value(p0c$) / 1d9
write (1, '(2a)')        '@ DATE         %10s ', quote(date(1:10))
write (1, '(2a)')        '@ TIME         %08s ', quote(date(12:19))

line1 = '*'
line2 = '$'
j = 4
do i = 1, size(col_name)
  line1 = line1(1:j-1) // col_name(i)
  line2 = line2(1:j-1) // col_type(i)
  j = j + 17
  if (i == 2) j = j + 4
enddo

write (1, '(a)') trim(line1)
write (1, '(a)') trim(line2)

do i = 1, lat%n_ele_track
  ele => lat%ele(i)
  ix = min(14, len_trim(ele%name))
  name = quote(ele%name(1:ix))

  angle = 0
  e1 = 0
  e2 = 0
  freq = 0
  lag = 0
  volt = 0
  ksl = 0
  tilt = ele%value(tilt$)

  call multipole_ele_to_kt (ele, .true., ix, knl, tilt, magnetic$, include_kicks$)

  select case (ele%key)
  case (drift$, instrument$, pipe$);      ele_type = 'DRIFT'
  case (multipole$, ab_multipole$);    ele_type = 'MULTIPOLE'
  case (sbend$);          ele_type = 'SBEND'
    angle = ele%value(angle$)
    e1    = ele%value(e1$)
    e2    = ele%value(e2$)
    tilt  = ele%value(ref_tilt$)
  case (lcavity$);        ele_type = 'LCAV'
    freq = 1d-6 * ele%value(rf_frequency$)
    volt = 1d-6 * ele%value(voltage$)
    lag = ele%value(phi0$)
  case (rfcavity$);       ele_type = 'RFCAVITY'
    freq = 1d-6 * ele%value(rf_frequency$)
    volt = 1d-6 * ele%value(voltage$)
    lag = ele%value(phi0$)
  case (rcollimator$);    ele_type = 'RCOLLIMATOR'
  case (ecollimator$);    ele_type = 'ECOLLIMATOR'
  case (vkicker$);        ele_type = 'VKICKER'
    tilt(0) = tilt(0) - pi/2.0_rp
  case (hkicker$);        ele_type = 'HKICKER'
  case (kicker$);         ele_type = 'KICKER'
  case (quadrupole$);     ele_type = 'QUADRUPOLE'
  case (solenoid$);       ele_type = 'SOLENOID'
    ksl = ele%value(ks$) * ele%value(l$)
  case (sextupole$);      ele_type = 'SEXTUPOLE'
  case (octupole$);       ele_type = 'OCTUPOLE'
  case (monitor$);        ele_type = 'MONITOR'
  case (marker$);         ele_type = 'MARKER'
  case default
    print *, 'I do not know how to translate this element type: ' // key_name(ele%key)
    print *, 'Translating as a drift...'
    ele_type = 'DRIFT'
  end select

  write (1, '(2x, a17, a, t36, 14es17.6)') name, quote(ele_type), &
            ele%s, ele%value(l$), angle, e1, e2, ksl, knl(0), knl(1), knl(2), knl(3), ele%value(tilt$), freq, lag, volt
enddo

print '(a)', 'Written: ' // trim(out_file)

end program bmad_to_merlin
