!=======================================================================
!> @file boundaries.f90
!> @brief Boundary conditions
!> @author Alejandro Esquivel
!> @date 2/Nov/2014

! Copyright (c) 2014 A. Esquivel, M. Schneiter, C. Villareal D'Angelo
!
! This file is part of Guacho-3D.
!
! Guacho-3D is free software; you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation; either version 3 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see http://www.gnu.org/licenses/.
!=======================================================================


!> @brief Boundary conditions
!> @details Sets boundary conditions, the type of boundaries is
!! set in the Makefile

module boundaries

  use parameters
  use globals
#ifdef OTHERB
  use user_mod
#endif

  implicit none

contains

!>@brief Boundary conditions for 1st order half timestep
!>@details Boundary conditions for 1st order half timestep
!! @n The conditions only are imposed at the innermost ghost cell, 
!! on the u (unstepped) variables
!> @param real [in] optional, time : integration time
!> @param real [in] optional, dt : timestep

subroutine boundaryI(time,dt)

  implicit none

#ifdef MPIP
  include "mpif.h"
#endif
  real, intent(in), optional :: time
  real, intent(in), optional :: dt
  integer, parameter :: nxm1=nx-1 ,nxp1=nx+1
  integer, parameter :: nym1=ny-1, nyp1=ny+1
  integer, parameter :: nzm1=nz-1, nzp1=nz+1
#ifdef MPIP
  integer:: status(MPI_STATUS_SIZE), err
  real, dimension(neq,1,0:nyp1,0:nzp1)::sendr,recvr,sendl,recvl
  real, dimension(neq,0:nxp1,1,0:nzp1)::sendt,recvt,sendb,recvb
  real, dimension(neq,0:nxp1,0:nyp1,1)::sendi,recvi,sendo,recvo
  integer, parameter :: bxsize=neq*(ny+2)*(nz+2)
  integer, parameter :: bysize=neq*(nx+2)*(nz+2)
  integer, parameter :: bzsize=neq*(nx+2)*(ny+2)
#endif

#ifdef MPIP

  !   Exchange boundaries between processors
  !   -------------------------------------------------------------

  !   boundaries to procs: right, left, top, bottom, in and out
  sendr(:,1,:,:)=u(:,nx    ,0:nyp1,0:nzp1)
  sendl(:,1,:,:)=u(:,1     ,0:nyp1,0:nzp1)
  sendt(:,:,1,:)=u(:,0:nxp1,ny    ,0:nzp1)
  sendb(:,:,1,:)=u(:,0:nxp1,1     ,0:nzp1)
  sendi(:,:,:,1)=u(:,0:nxp1,0:nyp1,nz    )
  sendo(:,:,:,1)=u(:,0:nxp1,0:nyp1,1     )

  call mpi_sendrecv(sendr, bxsize, mpi_real_kind, right  ,0,           &
                   recvl, bxsize, mpi_real_kind, left   ,0,            &
                   comm3d, status , err)

  call mpi_sendrecv(sendt, bysize, mpi_real_kind, top    ,0,           &
                   recvb, bysize, mpi_real_kind, bottom ,0,            &
                   comm3d, status , err)

  call mpi_sendrecv(sendi, bzsize, mpi_real_kind, in     ,0,           &
                   recvo, bzsize, mpi_real_kind, out    ,0,            &
                   comm3d, status , err)

  call mpi_sendrecv(sendl, bxsize, mpi_real_kind, left  , 0,           &
                   recvr, bxsize, mpi_real_kind, right , 0,            &
                   comm3d, status , err)

  call mpi_sendrecv(sendb, bysize, mpi_real_kind, bottom, 0,           &
                   recvt, bysize, mpi_real_kind, top   , 0,            &
                   comm3d, status , err)

  call mpi_sendrecv(sendo, bzsize, mpi_real_kind, out   , 0,           &
                   recvi, bzsize, mpi_real_kind, in    , 0,            &
                   comm3d, status , err)

  if (left  .ne. -1) u(:,0     ,0:nyp1,0:nzp1)=recvl(:,1,:,:)
  if (right .ne. -1) u(:,nxp1  ,0:nyp1,0:nzp1)=recvr(:,1,:,:)
  if (bottom.ne. -1) u(:,0:nxp1,0     ,0:nzp1)=recvb(:,:,1,:)
  if (top   .ne. -1) u(:,0:nxp1,nyp1  ,0:nzp1)=recvt(:,:,1,:)
  if (out   .ne. -1) u(:,0:nxp1,0:nyp1,0     )=recvo(:,:,:,1)
  if (in    .ne. -1) u(:,0:nxp1,0:nyp1,nzp1  )=recvi(:,:,:,1)

#else

     !   periodic BCs
#ifdef PERIODX
     !   Left BC
     if (coords(0).eq.0) then
        u(:,0,:,:)=u(:,nx,:,:)
     endif
     !   Right BC
     if (coords(0).eq.mpicol-1) then
        u(:,nxp1,:,:)=u(:,1,:,:)
     endif
#endif

#ifdef PERIODY
     !   bottom BC
     if (coords(1).eq.0) then
        u(:,:,0,:)= u(:,:,ny,:)
     endif
     !   top BC
     if (coords(1).eq.mpirow-1) then
        u(:,:,nyp1,:)= u(:,:,1,:)
     endif
#endif

#ifdef PERIODZ
     !   out BC
     if (coords(2).eq.0) then
        u(:,:,:,0)= u(:,:,:,nz)
     endif
     !   in BC
     if (coords(2).eq.mpirowz-1) then
        u(:,:,:,nzp1)= u(:,:,:,1)
     endif
#endif

#endif  
     !MPIP

     !   Reflecting BCs
#ifdef REFXL
     if (coords(0).eq.0) then
        u(1       ,0,0:nyp1,0:nzp1) = u(1       ,1,0:nyp1,0:nzp1)
        u(2       ,0,0:nyp1,0:nzp1) =-u(2       ,1,0:nyp1,0:nzp1)
        u(3:neq,0,0:nyp1,0:nzp1) = u(3:neq,1,0:nyp1,0:nzp1)
     endif
#endif

#ifdef REFXR
     if (coords(0).eq.(mpicol-1)) then
        u(1       ,nxp1,0:nyp1,0:nzp1) = u(1       ,nx,0:nyp1,0:nzp1)
        u(2       ,nxp1,0:nyp1,0:nzp1) =-u(2       ,nx,0:nyp1,0:nzp1)
        u(3:neq,nxp1,0:nyp1,0:nzp1) = u(3:neq,nx,0:nyp1,0:nzp1)
     endif
#endif

#ifdef REFYB
     if (coords(1).eq.0) then
        u(1:2     ,0:nxp1,0,0:nzp1) = u(1:2     ,0:nxp1,1,0:nzp1)
        u(3       ,0:nxp1,0,0:nzp1) =-u(3       ,0:nxp1,1,0:nzp1)
        u(4:neq,0:nxp1,0,0:nzp1) = u(4:neq,0:nxp1,1,0:nzp1)
     endif
#endif

#ifdef REFYT
     if (coords(1).eq.(mpirow-1)) then
        u(1:2     ,0:nxp1,nyp1,0:nzp1) = u(1:2     ,0:nxp1,ny,0:nzp1)
        u(3       ,0:nxp1,nyp1,0:nzp1) =-u(3       ,0:nxp1,ny,0:nzp1)
        u(4:neq,0:nxp1,nyp1,0:nzp1) = u(4:neq,0:nxp1,ny,0:nzp1)
     endif
#endif

#ifdef REFZO
     if (coords(2).eq.0) then
           u(1:3     ,0:nxp1,0:nyp1,0) = u(1:3     ,0:nxp1,0:nyp1,1)
           u(4       ,0:nxp1,0:nyp1,0) =-u(4       ,0:nxp1,0:nyp1,1)
           u(5:neq,0:nxp1,0:nyp1,0) = u(5:neq,0:nxp1,0:nyp1,1)
     endif
#endif

#ifdef REFZI
     if (coords(2).eq.mpirowz-1) then
           u(1:3     ,0:nxp1,0:nyp1,nzp1) = u(1:3     ,0:nxp1,0:nyp1,nz)
           u(4       ,0:nxp1,0:nyp1,nzp1) =-u(4       ,0:nxp1,0:nyp1,nz)
           u(5:neq,0:nxp1,0:nyp1,nzp1) = u(5:neq,0:nxp1,0:nyp1,nz)
     endif
#endif

     !   outflow BCs

     !   left
#ifdef OUTFXL
     if (coords(0).eq.0) then
        u(:,0,   0:nyp1,0:nzp1)=u(:,1 ,0:nyp1,0:nzp1)
     endif
#endif

     !   right
#ifdef OUTFXR
     if (coords(0).eq.mpicol-1) then
        u(:,nxp1,0:nyp1,0:nzp1)=u(:,nx,0:nyp1,0:nzp1)
     endif
#endif

     !   bottom
#ifdef OUTFYB
     if (coords(1).eq.0) then
        u(:,0:nxp1,0   ,0:nzp1)=u(:,0:nxp1,1 ,0:nzp1)
     endif
#endif

     !   top
#ifdef OUTFYT
     if (coords(1).eq.mpirow-1) then
        u(:,0:nxp1,nyp1,0:nzp1)=u(:,0:nxp1,ny,0:nzp1)
     endif
#endif

     !   out
#ifdef OUTFZO
     if (coords(2).eq.0) then
           u(:,0:nxp1,0:nyp1,0   )=u(:,0:nxp1,0:nyp1,1 )
     endif
#endif

     !   in
#ifdef OUTFZI
     if (coords(2).eq.mpirowz-1) then
           u(:,0:nxp1,0:nyp1,nzp1)=u(:,0:nxp1,0:nyp1,nz)
     endif
#endif
     !   other type of boundaries
#ifdef OTHERB

    call impose_user_bc(u,time)

#endif

end subroutine boundaryI

!=======================================================================

!>@brief Boundary conditions for 2nd order half timestep
!>@details Boundary conditions for 2nd order half timestep
!! @n The conditions only are imposed in two ghost cells
!! on the up (stepped) variables
!> @param real [in] optional, time : integration time
!> @param real [in] optional, dt : timestep
subroutine boundaryII(time,dt)
 
  implicit none

#ifdef MPIP
  include "mpif.h"
#endif  
  real, intent(in), optional :: time
  real, intent(in), optional :: dt
  integer, parameter :: nxmg=nx-nghost+1 ,nxp=nx+1
  integer, parameter :: nymg=ny-nghost+1, nyp=ny+1
  integer, parameter :: nzmg=nz-nghost+1, nzp=nz+1

#if defined(OUTFXL) || defined(OUTFXR) || \
    defined(OUTFYB) || defined(OUTFYT) |  \
    defined(OUTFZI) || defined(OUTFZO) || \
    defined(REFXL) || defined(REFXR) || \
    defined(REFYB) || defined(REFYT) || \
    defined(REFZI) || defined(REFZO)
  integer :: i
#endif
#if defined(REFXL) || defined(REFXR) || \
    defined(REFYB) || defined(REFYT) || \
    defined(REFZI) || defined(REFZO)
  integer :: j
#endif

#ifdef MPIP
  integer:: status(MPI_STATUS_SIZE), err
  real, dimension(neq,nghost,nymin:nymax,nzmin:nzmax)::sendr,recvr,sendl,recvl
  real, dimension(neq,nxmin:nxmax,nghost,nzmin:nzmax)::sendt,recvt,sendb,recvb
  real, dimension(neq,nxmin:nxmax,nymin:nymax,nghost)::sendi,recvi,sendo,recvo
  integer, parameter :: bxsize=neq*nghost*(nymax-nymin+1)*(nzmax-nzmin+1)
  integer, parameter :: bysize=neq*(nxmax-nxmin+1)*nghost*(nzmax-nzmin+1)
  integer, parameter :: bzsize=neq*(nxmax-nxmin+1)*(nymax-nymin+1)*nghost
#endif

#ifdef MPIP
 
  !   Exchange boundaries between processors
  !   -------------------------------------------------------------

  !   boundaries to processors to the right, left, top, and bottom
  sendr(:,1:nghost,:,:)=up(:,nxmg:nx ,:,:)
  sendl(:,1:nghost,:,:)=up(:,1:nghost,:,:)
  sendt(:,:,1:nghost,:)=up(:,:,nymg:ny ,:)
  sendb(:,:,1:nghost,:)=up(:,:,1:nghost,:)
  sendi(:,:,:,1:nghost)=up(:,:,:,nzmg:nz )
  sendo(:,:,:,1:nghost)=up(:,:,:,1:nghost)

  call mpi_sendrecv(sendr, bxsize, mpi_real_kind, right  ,0,           &
                   recvl, bxsize, mpi_real_kind, left   ,0,            &
                   comm3d, status , err)

  call mpi_sendrecv(sendt, bysize, mpi_real_kind, top    ,0,           &
                   recvb, bysize, mpi_real_kind, bottom ,0,            &
                   comm3d, status , err)

  call mpi_sendrecv(sendi, bzsize, mpi_real_kind, in     ,0,           &
                   recvo, bzsize, mpi_real_kind, out    ,0,            &
                   comm3d, status , err)

  call mpi_sendrecv(sendl, bxsize, mpi_real_kind, left  , 0,           &
                   recvr, bxsize, mpi_real_kind, right , 0,            &
                   comm3d, status , err)

  call mpi_sendrecv(sendb, bysize, mpi_real_kind, bottom, 0,           &
                   recvt, bysize, mpi_real_kind, top   , 0,            &
                   comm3d, status , err)

  call mpi_sendrecv(sendo, bzsize, mpi_real_kind, out   , 0,           &
                   recvi, bzsize, mpi_real_kind, in    , 0,            &
                   comm3d, status , err)

  if (left  .ne. -1) up(:,nxmin:0  ,:,:)=recvl(:,1:nghost,:,:)
  if (right .ne. -1) up(:,nxp:nxmax,:,:)=recvr(:,1:nghost,:,:)
  if (bottom.ne. -1) up(:,:,nymin:0  ,:)=recvb(:,:,1:nghost,:)
  if (top   .ne. -1) up(:,:,nyp:nymax,:)=recvt(:,:,1:nghost,:)
  if (out   .ne. -1) up(:,:,:,nzmin:0  )=recvo(:,:,:,1:nghost)
  if (in    .ne. -1) up(:,:,:,nzp:nzmax)=recvi(:,:,:,1:nghost)

#else

     !   periodic BCs
#ifdef PERIODX
     !   Left BC
     if (coords(0).eq.0) then
        up(:,nxmin:0,:,:)=up(:,nxmg:nx,:,:)
     endif
     !   Right BC
     if (coords(0).eq.mpicol-1) then
        up(:,nxp:nxmax,:,:)=up(:,1:nghost,:,:)
     endif
#endif

#ifdef PERIODY
     !   bottom BC
     if (coords(1).eq.0) then
        up(:,:,nymin:0,:)= up(:,:,nymg:ny,:)
     endif
     !   top BC
     if (coords(1).eq.mpirow-1) then
        up(:,:,nyp:nymax,:)= up(:,:,1:nghost,:)
     endif
#endif

#ifdef PERIODZ
     !   out BC
     if (coords(2).eq.0) then
        up(:,:,:,nzmin:0)= up(:,:,:,nzmg:nz)
     endif
     !   in BC
     if (coords(2).eq.mpirowz-1) then
        up(:,:,:,nzp:nzmax)= up(:,:,:,1:nghost)
     endif
#endif

#endif
     !MPIP

     !   Reflecting BCs
#ifdef REFXL
     if (coords(0).eq.0) then
        j=nghost
        do i=nxmin,0
           up(1  ,i,:,:) = up(1  ,j,:,:)
           up(2  ,i,:,:) =-up(2  ,j,:,:)
           up(3:neq,i,:,:) = up(3:neq,j,:,:)
           j=j-1
        enddo
     endif
#endif

#ifdef REFXR
     if (coords(0).eq.mpicol-1) then
        j=nx
        do i=nxp,nxmax
           up(1  ,i,:,:) = up(1  ,j,:,:)
           up(2  ,i,:,:) =-up(2  ,j,:,:)
           up(3:neq,i,:,:) = up(3:neq,j,:,:)
           j=j-1
        enddo
     endif
#endif

#ifdef REFYB
     if (coords(1).eq.0) then
        j=nghost
        do i=nymin,0
           up(1:2,:,i,:) = up(1:2,:,j,:)
           up(3  ,:,i,:) =-up(3  ,:,j,:)
           up(4:neq,:,i,:) = up(4:neq,:,j,:)
           j=j-1
        enddo
     endif
#endif

#ifdef REFYT
     if (coords(1).eq.(mpirow-1)) then
        j=ny
        do i=nyp,nymax
           up(1:2,:,i,:) = up(1:2,:,j,:)
           up(3  ,:,i,:) =-up(3  ,:,j,:)
           up(4:neq,:,i,:) = up(4:neq,:,j,:)
           j=j-1
        enddo
     endif
#endif

#ifdef REFZO
     if (coords(2).eq.0) then
        j=nghost
        do i=nzmin,0
           up(1:3,:,:,i) = up(1:3,:,:,j)
           up(4  ,:,:,i) =-up(4  ,:,:,j)
           up(5:neq  ,:,:,i) = up(5:neq  ,:,:,j)
           j=j-1
        enddo
     endif
#endif

#ifdef REFZI
     if (coords(2).eq.mpirowz-1) then
        j=nz
        do i=nzp,nzmax
           up(1:3,:,:,i) = up(1:3,:,:,j)
           up(4  ,:,:,i) =-up(4  ,:,:,j)
           up(5:neq  ,:,:,i) = up(5:neq  ,:,:,j)
           j=j-1
        enddo
     endif
#endif

     !   outflow BCs

     !   left
#ifdef OUTFXL
     if (coords(0).eq.0) then
        do i=nxmin,0
           up(:,i,:,:)=up(:,1,:,:)
        enddo
     endif
#endif

     !   right
#ifdef OUTFXR
     if (coords(0).eq.mpicol-1) then
        do i=nxp,nxmax
           up(:,i,:,:)=up(:,nx,:,:)
        enddo
     endif
#endif

     !   bottom
#ifdef OUTFYB
     if (coords(1).eq.0) then
        do i=nymin,0
           up(:,:,i,:)=up(:,:,1,:)
        enddo
     endif
#endif

     !   top
#ifdef OUTFYT
     if (coords(1).eq.mpirow-1) then
        do i=nyp,nymax
           up(:,:,i,:)=up(:,:,ny,:)
        enddo
     endif
#endif

     !   out
#ifdef OUTFZO
     if (coords(2).eq.0) then
        do i=nzmin,0
           up(:,:,:,i)=up(:,:,:,1)
        enddo
     endif
#endif

     !   in
#ifdef OUTFZI
     if (coords(2).eq.mpirowz-1) then
        do i=nzp,nzmax
           up(:,:,:,i)=up(:,:,:,nz)
        enddo
     endif
#endif

     !   other type of bounadries  <e.g. winds jets outflows>
#ifdef OTHERB

     call impose_user_bc(up,time)

#endif
  !
  return
end subroutine boundaryII

!=======================================================================

end module boundaries

!=======================================================================