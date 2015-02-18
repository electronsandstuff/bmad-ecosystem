!To do:
!  *) Code: lux_add_in_slave_data
!  *) Add files: lux/examples/run_lux_mpi.sh
!  *) Make sure lux/examples/lux.init works.

program lux_mpi

use lux_module

implicit none

include 'mpif.h'

type (lux_param_struct) lux_param
type (lux_common_struct), target :: lux_com
type (lux_output_data_struct) lux_data
type (surface_grid_struct) :: slave_grid
type (surface_grid_struct), pointer :: detec_grid

integer master_rank, ierr, rc, leng, i, stat(MPI_STATUS_SIZE)
integer data_size, num_photons_left, num_slaves
integer results_tag, is_done_tag, slave_rank

logical am_i_done
logical, allocatable :: slave_is_done(:)

character(MPI_MAX_PROCESSOR_NAME) name

! Initialize MPI 

call mpi_init(ierr)
if (ierr /= MPI_SUCCESS) then
   print *,'Error starting MPI program. Terminating.'
   call mpi_abort(MPI_COMM_WORLD, rc, ierr)
end if

! Get the number of processors this job is using:
call mpi_comm_size(MPI_COMM_WORLD, lux_com%mpi_n_proc, ierr)

! Get the rank of the processor this thread is running on.  (Each
! processor has a unique rank.)
call mpi_comm_rank(MPI_COMM_WORLD, lux_com%mpi_rank, ierr)

! Get the name of this processor (usually the hostname)
call mpi_get_processor_name(name, leng, ierr)
if (ierr /= MPI_SUCCESS) then
   print *,'Error getting processor name. Terminating.'
   call mpi_abort(MPI_COMM_WORLD, rc, ierr)
end if

master_rank = 0
num_slaves = lux_com%mpi_n_proc - 1

! Init Lux

lux_com%using_mpi = .true.
call lux_init (lux_param, lux_com)

detec_grid => lux_com%detec_ele%photon%surface%grid
allocate (slave_grid%pt(size(detec_grid%pt, 1), size(detec_grid%pt, 1)))

! storage_size returns size in bytes per point
data_size = size(detec_grid%pt, 1) * size(detec_grid%pt, 2) * storage_size(detec_grid%pt) / 8

if (num_slaves < 1) then
  print *, 'ONLY ONE PROCESS EXISTS!'
  call mpi_finalize(ierr)
  stop
ENDIF

results_tag = 1000
is_done_tag = 1001

!-------------------------------
! Master collects the work of the slaves

if (lux_com%mpi_rank == master_rank) then
  call print_this ('Master: Starting...')

  allocate (slave_is_done(num_slaves))
  slave_is_done = .false.

  ! Init the output arrays.
  call lux_init_data (lux_param, lux_com, lux_data)

  ! Slaves automatically start one round of tracking
  num_photons_left = lux_param%stop_num_photons - num_slaves * lux_com%n_photon_stop1

  do
    ! Get data from a slave
    call print_this ('Master: Waiting for a Slave...')
    call mpi_recv (slave_grid%pt, data_size, MPI_REAL8, MPI_ANY_SOURCE, results_tag, MPI_COMM_WORLD, stat, ierr)
    call lux_add_in_slave_data (slave_grid%pt, lux_param, lux_com, lux_data)
    slave_rank = stat(MPI_SOURCE)
    call print_this ('Master: Gathered data from Slave: ', slave_rank)

    ! Tell slave if more tracking needed
    call print_this ('Master: Commanding Slave. Photons left:', num_photons_left)
    if (num_photons_left < 1) slave_is_done(slave_rank) = .true.
    call mpi_send (slave_is_done(slave_rank), 1, MPI_LOGICAL, slave_rank, is_done_tag, MPI_COMM_WORLD, ierr)
    if (.not. slave_is_done(slave_rank)) num_photons_left = num_photons_left - lux_com%n_photon_stop1

    ! All done?
    if (all(slave_is_done)) exit

  enddo

  call print_this ('Master: All done!')

  ! write results and quit

  call lux_write_data (lux_param, lux_com, lux_data)

  call mpi_finalize(ierr)
  stop

endif

!-------------------------------
! A slave process tracks photons

do
  call print_this ('Slave: Starting...')

  ! Init the output arrays
  call print_this ('Slave: Tracking Photons...')
  call lux_init_data (lux_param, lux_com, lux_data)
  call lux_track_photons (lux_param, lux_com, lux_data)

  ! Send results to the Master
  call print_this ('Slave: Sending Data...')
  call mpi_send (detec_grid%pt, data_size, MPI_BYTE, master_rank, results_tag, MPI_COMM_WORLD, ierr)

  ! Query Master if more tracking needed
  call print_this ('Slave: Query to master...')
  call mpi_recv (am_i_done, 1, MPI_LOGICAL, master_rank, is_done_tag, MPI_COMM_WORLD, stat, ierr)
  if (am_i_done) exit

enddo

call print_this ('Slave: All done!')

! And end

call mpi_finalize(ierr)


!---------------------------------------------------------------------
contains

subroutine print_this (line, inum)

character(*) line
character(20) dtime
integer, optional :: inum

!

call date_and_time_stamp (dtime)
if (present(inum)) then
  print '(a, 2x, i0, 2a, 1x, i0)', dtime, lux_com%mpi_rank, ': ', trim(line), inum
else
  print '(a, 2x, i0, 2a)', dtime, lux_com%mpi_rank, ': ', trim(line)
endif

end subroutine print_this

end program
