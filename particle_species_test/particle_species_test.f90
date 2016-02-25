program particle_species_test

use particle_species_mod

integer :: i_dim, species
integer :: namelist_file, n_char

character(100) :: lat_name, lat_path, base_name, in_file
character(30), parameter :: r_name = 'particle_species_test'


character(20) :: example_names(1:100)  = ''

namelist / particle_species_test_params / &
    example_names

!------------------------------------------
!Defaults for namelist
example_names(1:6) =  ['NH3+', 'CH3++', 'CH3+2', 'NH3@M37.5-', 'C+', '#12C+']

!Read namelist
in_file = 'particle_species_test.in'
if (command_argument_count() > 0) call get_command_argument(1, in_file)

namelist_file = lunget()
print *, 'Opening: ', trim(in_file)
open (namelist_file, file = in_file, status = "old")
read (namelist_file, nml = particle_species_test_params)
close (namelist_file)



! 
print *, 'atomic mass unit (eV): ', atomic_mass_unit

! Decode
!call print_species(1)

! Encode
!species = species_id('#2H--')
!call print_species(species)

open (1, file = 'output.now')

!species = species_id('H2O ')
!call print_species(species)
!call write_mass_and_charge(species)

call print_all(example_names)

write(1, *) ''
call print_all(fundamental_species_name)
write(1, *) ''
call print_all(atomic_name)
write(1, *) ''
call print_all(molecular_name)

contains

subroutine print_all(p_array)
integer :: i, species
character(*)  :: p_array(:)

do i=lbound(p_array, 1), ubound(p_array, 1)
  if (trim(p_array(i)) =='') cycle ! Skip empty
  species = species_id(p_array(i))
  call print_species(species)
  call write_mass_and_charge(species)
enddo

end subroutine


subroutine print_species(species)

integer :: species

write (*, '(a, i0)')    'species: ', species
write (*, '(a, a)'),   'name:    ', species_name(species)
write (*, '(a, f20.5)') 'mass (MeV):    ', mass_of(species)*1e-6
write (*, '(a, f20.5)') 'mass (u) :    ', mass_of(species)/atomic_mass_unit
write (*, '(a, i0)')    'charge   ', charge_of(species)
write (*,*) ''


end subroutine 


subroutine write_mass_and_charge(species)
integer :: species
character(20) :: name
name = species_name(species)
write (1, '(a, a, es20.10)') '"'//trim(name)//':mass"', ' ABS  1E-10 ', mass_of(species)
write (1, '(a, a, i0)') '"'//trim(name)//':charge"'   , ' ABS  0 ', charge_of(species)
end subroutine

end program
