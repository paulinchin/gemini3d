submodule (io:plasma_input) plasma_input_hdf5

use timeutils, only : date_filename
use h5fortran, only: hdf5_file

implicit none (external)

contains

module procedure input_root_currents_hdf5
!! READS, AS INPUT, A FILE GENERATED BY THE GEMINI.F90 PROGRAM

character(:), allocatable :: filenamefull
real(wp), dimension(:,:,:), allocatable :: J1all,J2all,J3all
real(wp), dimension(:,:,:), allocatable :: tmpswap

type(hdf5_file) :: h5f

!>  CHECK TO MAKE SURE WE ACTUALLY HAVE THE DATA WE NEED TO DO THE MAG COMPUTATIONS.
if (flagoutput==3) error stop 'Need current densities in the output to compute magnetic fields'


!> FORM THE INPUT FILE NAME
filenamefull = date_filename(outdir,ymd,UTsec) // '.h5'
print *, 'Input file name for current densities:  ', filenamefull

call h5f%initialize(filenamefull, status='old', action='r')

!> LOAD THE DATA
!> PERMUTE THE ARRAYS IF NECESSARY
allocate(J1all(lx1,lx2all,lx3all),J2all(lx1,lx2all,lx3all),J3all(lx1,lx2all,lx3all))
if (flagswap==1) then
  allocate(tmpswap(lx1,lx3all,lx2all))
  call h5f%read('/J1all', tmpswap)
  J1all = reshape(tmpswap,[lx1,lx2all,lx3all],order=[1,3,2])
  call h5f%read('/J2all', tmpswap)
  J2all = reshape(tmpswap,[lx1,lx2all,lx3all],order=[1,3,2])
  call h5f%read('/J3all', tmpswap)
  J3all = reshape(tmpswap,[lx1,lx2all,lx3all],order=[1,3,2])
else
  !! no need to permute dimensions for 3D simulations
  call h5f%read('/J1all', J1all)
  call h5f%read('/J2all', J2all)
  call h5f%read('/J3all', J3all)
end if
print *, 'Min/max current data:  ',minval(J1all),maxval(J1all),minval(J2all),maxval(J2all),minval(J3all),maxval(J3all)

call h5f%finalize()

if(.not.all(ieee_is_finite(J1all))) error stop 'J1all: non-finite value(s)'
if(.not.all(ieee_is_finite(J2all))) error stop 'J2all: non-finite value(s)'
if(.not.all(ieee_is_finite(J3all))) error stop 'J3all: non-finite value(s)'

!> DISTRIBUTE DATA TO WORKERS AND TAKE A PIECE FOR ROOT
call bcast_send(J1all,tag%J1,J1)
call bcast_send(J2all,tag%J2,J2)
call bcast_send(J3all,tag%J3,J3)

end procedure input_root_currents_hdf5


module procedure input_root_mpi_hdf5

!! READ INPUT FROM FILE AND DISTRIBUTE TO WORKERS.
!! STATE VARS ARE EXPECTED INCLUDE GHOST CELLS.  NOTE ALSO
!! THAT RECORD-BASED INPUT IS USED SO NO FILES > 2GB DUE
!! TO GFORTRAN BUG WHICH DISALLOWS 8 BYTE INTEGER RECORD
!! LENGTHS.

type(hdf5_file) :: h5f

integer :: lx1,lx2,lx3,lx2all,lx3all,isp

real(wp), dimension(-1:size(x1,1)-2,-1:size(x2all,1)-2,-1:size(x3all,1)-2,1:lsp) :: nsall, vs1all, Tsall
integer :: lx1in,lx2in,lx3in,u, utrace
real(wp) :: tin
real(wp), dimension(3) :: ymdtmp

real(wp) :: tstart,tfin

!> so that random values (including NaN) don't show up in Ghost cells
nsall = 0
vs1all= 0
Tsall = 0

!> SYSTEM SIZES
lx1=size(ns,1)-4
lx2=size(ns,2)-4
lx3=size(ns,3)-4
lx2all=size(x2all)-4
lx3all=size(x3all)-4

!> READ IN FROM FILE, AS OF CURVILINEAR BRANCH THIS IS NOW THE ONLY INPUT OPTION
call get_simsize3(indatsize, lx1in, lx2in, lx3in)
print '(2A,3I6)', indatsize,' input dimensions:',lx1in,lx2in,lx3in
print '(A,3I6)', 'Target (output) grid structure dimensions:',lx1,lx2all,lx3all

if (flagswap==1) then
  print *, '2D simulation: **SWAP** x2/x3 dims and **PERMUTE** input arrays'
  lx3in=lx2in
  lx2in=1
end if

if (.not. (lx1==lx1in .and. lx2all==lx2in .and. lx3all==lx3in)) then
  error stop 'The input data must be the same size as the grid which you are running the simulation on' // &
       '- use a script to interpolate up/down to the simulation grid'
end if

call h5f%initialize(indatfile, status='old', action='r')

if (flagswap==1) then
  block
  !> NOTE: workaround for intel 2020 segfault--may be a compiler bug
  !real(wp) :: tmp(lx1,lx3all,lx2all,lsp)
  real(wp), allocatable :: tmp(:,:,:,:)
  allocate(tmp(lx1,lx3all,lx2all,lsp))
  !! end workaround
  call h5f%read('/ns', tmp)
  nsall(1:lx1,1:lx2all,1:lx3all,1:lsp) = reshape(tmp,[lx1,lx2all,lx3all,lsp],order=[1,3,2,4])
  call h5f%read('/vsx1', tmp)
  vs1all(1:lx1,1:lx2all,1:lx3all,1:lsp) = reshape(tmp,[lx1,lx2all,lx3all,lsp],order=[1,3,2,4])
  call h5f%read('/Ts', tmp)
  Tsall(1:lx1,1:lx2all,1:lx3all,1:lsp) = reshape(tmp,[lx1,lx2all,lx3all,lsp],order=[1,3,2,4])
  !! permute the dimensions so that 2D runs are parallelized
  end block
else
  call h5f%read('/ns', nsall(1:lx1,1:lx2all,1:lx3all,1:lsp))
  call h5f%read('/vsx1', vs1all(1:lx1,1:lx2all,1:lx3all,1:lsp))
  call h5f%read('/Ts', Tsall(1:lx1,1:lx2all,1:lx3all,1:lsp))
end if

call h5f%finalize()

!> Sanity checks
if (.not. all(ieee_is_finite(nsall))) error stop 'nsall: non-finite value(s)'
if (any(nsall < 0)) error stop 'negative density'
if (maxval(nsall) < 1e6) error stop 'unrealistically low maximum density'
if (maxval(nsall) > 1e16) error stop 'unrealistically high maximum density'

if (.not. all(ieee_is_finite(vs1all))) error stop 'vs1all: non-finite value(s)'
if (any(abs(vs1all) > 1e7_wp)) error stop 'drift should not be realativistic'

if (.not. all(ieee_is_finite(Tsall))) error stop 'Tsall: non-finite value(s)'
if (any(Tsall < 0)) error stop 'negative temperature in Tsall'
if (any(Tsall > 100000)) error stop 'too hot Tsall'
if (maxval(Tsall) < 500) error stop 'too cold maximum Tsall'

!> USER SUPPLIED FUNCTION TO TAKE A REFERENCE PROFILE AND CREATE INITIAL CONDITIONS FOR ENTIRE GRID.
!> ASSUMING THAT THE INPUT DATA ARE EXACTLY THE CORRECT SIZE (AS IS THE CASE WITH FILE INPUT) THIS IS NOW SUPERFLUOUS
print '(/,A,/,A)', 'HDF5: Initial conditions:','------------------------'
print '(A,2ES11.2)', 'Min/max input density:',     minval(nsall(:,:,:,7)),  maxval(nsall(:,:,:,7))
print '(A,2ES11.2)', 'Min/max input velocity:',    minval(vs1all(:,:,:,:)), maxval(vs1all(:,:,:,:))
print '(A,2ES11.2)', 'Min/max input temperature:', minval(Tsall(:,:,:,:)),  maxval(Tsall(:,:,:,:))


!> ROOT BROADCASTS IC DATA TO WORKERS
call cpu_time(tstart)
call bcast_send(nsall,tag%ns,ns)
call bcast_send(vs1all,tag%vs1,vs1)
call bcast_send(Tsall,tag%Ts,Ts)
call cpu_time(tfin)
print '(A,F10.6,A)', 'Sent ICs to workers in',tfin-tstart, ' seconds.'

end procedure input_root_mpi_hdf5


end submodule plasma_input_hdf5
