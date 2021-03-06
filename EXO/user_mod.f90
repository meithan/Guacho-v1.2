!=======================================================================
!> @file user_mod.f90
!> @brief User input module
!> @author C. Villarreal, M. Schneiter, A. Esquivel
!> @date 4/May/2016

! Copyright (c) 2016 Guacho Co-Op
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

!> @brief User imput module
!> @details  This is an attempt to have all input neede from user in a
!! single file
!!!  This module should load additional modules (i.e. star, jet, sn), to
!!  impose initial and boundary conditions (such as sources)

module user_mod

  ! load auxiliary modules
  use exoplanet

  implicit none
 
contains

!> @brief Initializes variables in the module, as well as other
!! modules loaded by user.
!! @n It has to be present, even if empty 
subroutine init_user_mod()

  implicit none      
  !  initialize modules loaded by user
  call init_exo()

end subroutine init_user_mod

!=====================================================================

!> @brief Here the domain is initialized at t=0
!> @param real [out] u(neq,nxmin:nxmax,nymin:nymax,nzmin:nzmax) : 
!! conserved variables
!> @param real [in] time : time in the simulation (code units)

subroutine initial_conditions(u)

  use parameters, only : neq, nxmin, nxmax, nymin, nymax, nzmin, nzmax, &
                         pmhd, mhd, passives
  use globals,    only: coords, dx ,dy ,dz

  implicit none
  real, intent(out) :: u(neq,nxmin:nxmax,nymin:nymax,nzmin:nzmax)

  integer :: i,j,k
  real :: x,y,z, rads, velx, vely, velz, dens,cpi
  !  the star wind does not cover the entire domain, we fill here 
  !  as if the exoplanet is absent
  do i=nxmin,nxmax
    do j=nymin,nymax
      do k=nzmin,nzmax

        ! Position measured from the centre of the grid (star)
        x=(float(i+coords(0)*nx-nxtot/2)+0.5)*dx
        y=(float(j+coords(1)*ny-nytot/2)+0.5)*dy
        z=(float(k+coords(2)*nz-nztot/2)+0.5)*dz

        ! Distance from the centre of the star
        rads=sqrt(x**2+y**2+z**2)

        VelX=VSW*X/RADS
        VelY=VSW*Y/RADS
        VelZ=VSW*Z/RADS
        DENS=DSW*RSW**2/RADS**2
        !   total density and momena
        u(1,i,j,k) = dens
        u(2,i,j,k) = dens*velx
        u(3,i,j,k) = dens*vely
        u(4,i,j,k) = dens*velz
        if (pmhd .or. mhd) then
          cpi = bsw*(RSW/rads)**3/(2.*rads**2)
          u(6,i,j,k) = 3.*y*x*cpi
          u(7,i,j,k) = (3.*y**2-rads**2)*cpi
          u(8,i,j,k) = 3.*y*z*cpi
        end if
        if (mhd) then
          ! total energy
          u(5,i,j,k)=0.5*dens*vsw**2         &
               + cv*dens*Tsw       & 
               + 0.5*(u(6,i,j,k)**2+u(7,i,j,k)**2+u(8,i,j,k)**2)
        else
                ! total energy
          u(5,i,j,k)=0.5*dens*(velx**2+vely**2+velz**2) &
               + cv*dens*1.9999*Tsw
        end if
        if (passives) then
          !  density of neutrals
          u(neqdyn+1,i,j,k)= 0.0001*dens
          !   passive scalar (h-hot, c-cold, i-ionized, n-neutral)
          u(neqdyn+2,i,j,k)= dens   ! passive scalar
        end if
      end do
    end do
  end do

  call impose_exo(u,0.)

end subroutine initial_conditions
  
!=====================================================================

!> @brief User Defined Boundary conditions
!> @param real [out] u(neq,nxmin:nxmax,nymin:nymax,nzmin:nzmax) : 
!! conserved variables
!> @param real [in] time : time in the simulation (code units)
!> @param integer [in] order : order (mum of cells to be filled in case
!> domain boundaries are being set)

subroutine impose_user_bc(u,order)

  use parameters, only:  neq, nxmin, nxmax, nymin, nymax, nzmin, nzmax
  use globals,    only: time
  implicit none
  real, intent(out) :: u(neq,nxmin:nxmax,nymin:nymax,nzmin:nzmax)
  integer, intent(in) :: order

  !  In this case the boundary is the same for 1st and second order)
  if (order >= 1) then 
    call impose_exo(u,time)
  end if
 
end subroutine impose_user_bc

!=======================================================================

!> @brief User Defined source terms
!> This is a generic interrface to add a source term S in the equation
!> of the form:  dU/dt+dF/dx+dG/dy+dH/dz=S
!> @param real [in] pp(neq) : vector of primitive variables
!> @param real [inout] s(neq) : vector with source terms, has to add to
!>  whatever is there, as other modules can add their own sources
!> @param integer [in] i : cell index in the X direction
!> @param integer [in] j : cell index in the Y direction
!> @param integer [in] k : cell index in the Z direction

subroutine get_user_source_terms(pp,s, i, j , k)

  ! in this example a constant gravity is added
  use constants,  only : Ggrav
  use parameters, only : nx, ny, nz, nxtot, nytot, nztot, rsc, vsc2
  use globals,    only : dx, dy, dz, coords
  use exoplanet
  implicit none
  integer, intent(in) :: i,j,k
  real, intent(in)    :: pp(neq)
  real, intent(inout) :: s(neq)
  integer, parameter  :: nb=2   ! 2 particles
  real :: x(nb),y(nb),z(nb), GM(nb), rad2(nb)
  integer :: l
  real    :: xc ,yc, zc

  GM(1)=0.3*Ggrav*MassS/rsc/vsc2
  GM(2)=    Ggrav*MassP/rsc/vsc2


  !   get cell position
  xc=(float(i+coords(0)*nx-nxtot/2)+0.5)*dx
  yc=(float(j+coords(1)*ny-nytot/2)+0.5)*dy
  zc=(float(k+coords(2)*nz-nztot/2)+0.5)*dz

  ! calculate distance from the sources
  ! star
  x(1)=xc
  y(1)=yc
  z(1)=zc
  rad2(1) = x(1)**2 +y(1)**2 + z(1)**2
  ! planet
  x(2)=xc-xp
  y(2)=yc
  z(2)=zc-zp
  rad2(2) = x(2)**2 +y(2)**2 + z(2)**2

  ! update source terms with gravity
  do l=1, nb
    ! momenta
    s(2)= s(2)-pp(1)*GM(l)*x(l)/(rad2(l)**1.5)
    s(3)= s(3)-pp(1)*GM(l)*y(l)/(rad2(l)**1.5)
    s(4)= s(4)-pp(1)*GM(l)*z(l)/(rad2(l)**1.5)
    ! energy
    s(5)= s(5)-pp(1)*GM(l)*( pp(2)*x(l) +pp(3)*y(l) +pp(4)*z(l) )  &
           /(rad2(l)**1.5 )
  end do

end subroutine get_user_source_terms


!=======================================================================

end module user_mod

!=======================================================================
