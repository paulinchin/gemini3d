submodule (mpimod) mpisend

implicit none

contains

module procedure gather_send2D

!------------------------------------------------------------
!-------THIS SUBROUTINE GATHERS DATA FROM ALL WORKERS ONTO
!-------A FULL-GRID ARRAY ON THE ROOT PROCESS (PRESUMABLY FOR
!-------OUTPUT OR SOME ELECTRODYNAMIC CALCULATION, PERHAPS.
!-------
!-------SUBROUTINE IS TO BE CALLED BY WORKERS TO DO GATHER
!-------
!-------THIS VERSION WORKS ON 2D ARRAYS WHICH DO NOT INCLUDE
!-------ANY GHOST CELLS!!!!
!------------------------------------------------------------

integer :: lx2,lx3


lx2=size(paramtrim,1)    !note here that paramtrim does not have ghost cells
lx3=size(paramtrim,2)

call mpi_send(paramtrim,lx2*lx3,mpi_realprec,0,tag,MPI_COMM_WORLD,ierr)

end procedure gather_send2D


module procedure gather_send3D

!------------------------------------------------------------
!-------THIS SUBROUTINE GATHERS DATA FROM ALL WORKERS ONTO
!-------A FULL-GRID ARRAY ON THE ROOT PROCESS (PRESUMABLY FOR
!-------OUTPUT OR SOME ELECTRODYNAMIC CALCULATION, PERHAPS.
!-------
!-------SUBROUTINE IS TO BE CALLED BY WORKERS TO DO GATHER
!-------
!-------THIS VERSION WORKS ON 3D ARRAYS WHICH DO NOT INCLUDE
!-------ANY GHOST CELLS!!!!
!------------------------------------------------------------

integer :: lx1,lx2,lx3


lx1=size(paramtrim,1)    !note here that paramtrim does not have ghost cells
lx2=size(paramtrim,2)
lx3=size(paramtrim,3)

call mpi_send(paramtrim,lx1*lx2*lx3,mpi_realprec,0,tag,MPI_COMM_WORLD,ierr)

end procedure gather_send3D


module procedure gather_send4D

!------------------------------------------------------------
!-------THIS SUBROUTINE GATHERS DATA FROM ALL WORKERS ONTO
!-------A FULL-GRID ARRAY ON THE ROOT PROCESS (PRESUMABLY FOR
!-------OUTPUT OR SOME ELECTRODYNAMIC CALCULATION, PERHAPS.
!-------
!-------SUBROUTINE IS TO BE CALLED BY WORKERS TO DO GATHER
!-------
!-------THIS VERSION WORKS ON 4D ARRAYS WHICH INCLUDE
!-------GHOST CELLS!
!------------------------------------------------------------

integer :: lx1,lx2,lx3,isp


lx1=size(param,1)-4
lx2=size(param,2)-4
lx3=size(param,3)-4

do isp=1,lsp
  call mpi_send(param(:,:,1:lx3,isp),(lx1+4)*(lx2+4)*lx3,mpi_realprec,0,tag,MPI_COMM_WORLD,ierr)
end do

end procedure gather_send4D


module procedure bcast_send1D

!------------------------------------------------------------
!-------BROADCASTS MPI DIMENSION VARIABLES TO WORKERS.  NOTE THAT
!-------WE'VE ELECTED TO NOT USE THE GENERAL BROADCAST ROUTINES FOR
!-------SINCE THESE OPERATIONS REQUIRE A LOT OF SPECIAL CASING FOR
!-------THE SIZES OF THE VARIABLES TO BE SENT
!-------
!-------SUBROUTINE IS TO BE CALLED BY ROOT TO DO A BROADCAST
!-------
!-------THIS VERSION WORKS ON 1D ARRAYS
!------------------------------------------------------------

integer :: lx,lxall     !local sizes
integer :: iid,islstart,islfin


lxall=size(paramall,1)-4
lx=size(param,1)-4


do iid=1,lid-1
  islstart=iid*lx+1
  islfin=islstart+lx-1

  call mpi_send(paramall(islstart-2:islfin+2),(lx+4), &
               mpi_realprec,iid,tag,MPI_COMM_WORLD,ierr)
end do
param=paramall(-1:lx+2)

end procedure bcast_send1D


module procedure bcast_send2D

!------------------------------------------------------------
!-------THIS SUBROUTINE BROADCASTS DATA FROM A FULL GRID ARRAY
!-------ON ROOT PROCESS TO ALL WORKERS' SUB-GRID ARRAYS.
!-------
!-------SUBROUTINE IS TO BE CALLED BY ROOT TO DO A BROADCAST
!-------
!-------THIS VERSION WORKS ON 2D ARRAYS WHICH DO NOT INCLUDE
!-------GHOST CELLS!
!------------------------------------------------------------

integer :: lx2,lx3
integer :: iid,islstart,islfin


lx2=size(paramtrim,1)    !assume this is an array which has been 'flattened' along the 1-dimension
lx3=size(paramtrim,2)


!ROOT BROADCASTS IC DATA TO WORKERS
do iid=1,lid-1
  islstart=iid*lx3+1
  islfin=islstart+lx3-1

  call mpi_send(paramtrimall(:,islstart:islfin),lx2*lx3, &
               mpi_realprec,iid,tag,MPI_COMM_WORLD,ierr)
end do


!ROOT TAKES A SLAB OF DATA
paramtrim=paramtrimall(:,1:lx3)

end procedure bcast_send2D


module procedure bcast_send3D

!------------------------------------------------------------
!-------THIS SUBROUTINE BROADCASTS DATA FROM A FULL GRID ARRAY
!-------ON ROOT PROCESS TO ALL WORKERS' SUB-GRID ARRAYS.
!-------
!-------SUBROUTINE IS TO BE CALLED BY ROOT TO DO A BROADCAST
!-------
!-------THIS VERSION WORKS ON 3D ARRAYS WHICH DO NOT INCLUDE
!-------GHOST CELLS!
!-------
!-------ALSO NOTE THAT IF THE ARRAY SIZE (DIM 3)  DOES NOT CORRESPOND
!-------TO THE SIZE OF THE SYSTEM IN THE X3-DIRECTION, THEN
!-------THE SLAB CALCULATIONS FOR WORKERS WILL BE OFF.
!------------------------------------------------------------

integer :: lx1,lx2,lx3
integer :: iid,islstart,islfin


lx1=size(paramtrim,1)    !note here that paramtrim does not have ghost cells
lx2=size(paramtrim,2)
lx3=size(paramtrim,3)


!> ROOT BROADCASTS IC DATA TO WORKERS
do iid=1,lid-1
  islstart=iid*lx3+1
  islfin=islstart+lx3-1

  call mpi_send(paramtrimall(:,:,islstart:islfin),lx1*lx2*lx3, &
               mpi_realprec,iid,tag,MPI_COMM_WORLD,ierr)
end do


!> ROOT TAKES A SLAB OF DATA
paramtrim=paramtrimall(:,:,1:lx3)

end procedure bcast_send3D


module procedure bcast_send3D_x3i

!------------------------------------------------------------
!-------THIS SUBROUTINE BROADCASTS DATA FROM A FULL GRID ARRAY
!-------ON ROOT PROCESS TO ALL WORKERS' SUB-GRID ARRAYS.
!-------
!-------SUBROUTINE IS TO BE CALLED BY ROOT TO DO A BROADCAST
!-------
!-------THIS VERSION WORKS ON 3D ARRAYS WHICH DO NOT INCLUDE
!-------GHOST CELLS, BUT ARE X3 INTERFACE QUANITTIES
!------------------------------------------------------------

integer :: lx1,lx2,lx3
integer :: iid,islstart,islfin


lx1=size(paramtrim,1)    !note here that paramtrim does not have ghost cells
lx2=size(paramtrim,2)
lx3=size(paramtrim,3)-1    !note that we are interpreting input as an x3i quantity meaning that it has size lx3+1


!ROOT BROADCASTS IC DATA TO WORKERS
do iid=1,lid-1
  islstart=iid*lx3+1
  islfin=islstart+lx3-1

  call mpi_send(paramtrimall(:,:,islstart:islfin+1),lx1*lx2*(lx3+1), &
               mpi_realprec,iid,tag,MPI_COMM_WORLD,ierr)     !note the +1 since thes are interfact quantities (and need to overlap b/t workers)
end do


!ROOT TAKES A SLAB OF DATA
paramtrim=paramtrimall(:,:,1:lx3+1)

end procedure bcast_send3D_x3i


module procedure bcast_send3D_ghost
!! THIS SUBROUTINE BROADCASTS DATA FROM A FULL GRID ARRAY
!!ON ROOT PROCESS TO ALL WORKERS' SUB-GRID ARRAYS.
!!
!! SUBROUTINE IS TO BE CALLED BY ROOT TO DO A BROADCAST
!!
!! THIS VERSION WORKS ON 3D ARRAYS WHICH INCLUDE GHOST CELLS

integer :: lx1,lx2,lx3
integer :: iid,islstart,islfin

!> note here that param has ghost cells
lx1=size(param,1)-4
lx2=size(param,2)-4
lx3=size(param,3)-4


!> ROOT BROADCASTS IC DATA TO WORKERS
do iid=1,lid-1
  islstart=iid*lx3+1
  islfin=islstart+lx3-1

  call mpi_send(paramall(:,:,islstart-2:islfin+2),(lx1+4)*(lx2+4)*(lx3+4), &
               mpi_realprec,iid,tag,MPI_COMM_WORLD,ierr)
end do


!> ROOT TAKES A SLAB OF DATA
param=paramall(:,:,-1:lx3+2)

end procedure bcast_send3D_ghost


module procedure bcast_send4D
!! THIS SUBROUTINE BROADCASTS DATA FROM A FULL GRID ARRAY
!! ON ROOT PROCESS TO ALL WORKERS' SUB-GRID ARRAYS.
!!
!! SUBROUTINE IS TO BE CALLED BY ROOT TO DO A BROADCAST
!!
!! THIS VERSION WORKS ON 4D ARRAYS WHICH INCLUDE
!! GHOST CELLS!

integer :: lx1,lx2,lx3,isp
integer :: iid,islstart,islfin


lx1=size(param,1)-4
lx2=size(param,2)-4
lx3=size(param,3)-4


!> ROOT BROADCASTS IC DATA TO WORKERS
do isp=1,lsp
  param(:,:,:,isp)=paramall(:,:,-1:lx3+2,isp)
    !! roots part of the data

  do iid=1,lid-1
    islstart=iid*lx3+1
    islfin=islstart+lx3-1

    call mpi_send(paramall(:,:,islstart-2:islfin+2,isp),(lx1+4)*(lx2+4)*(lx3+4), &
               mpi_realprec,iid,tag,MPI_COMM_WORLD,ierr)
  end do
end do

end procedure bcast_send4D

end submodule mpisend
