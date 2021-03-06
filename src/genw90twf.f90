! Copyright (C) 2015 Manh Duc Le
! This file is distributed under the terms of the GNU General Public License.
! See the file COPYING for license details.

!BOP
! !ROUTINE: genw90twf
! !INTERFACE:
subroutine genw90twf
! !USES:
use modmain
use modw90
! !DESCRIPTION:
!   Generates the trial orbitals for the projection Amn matrix required by wannier90
!
! !REVISION HISTORY:
!   Created January 2015 (Manh Duc Le)
!EOP
!BOC
implicit none
! local variables
integer i,is,ia,ias,lmaxproj,lmmaxproj,lm,l,m,n,nr,ir,irc
real(8) s2,s3,s6,s12
! allocatable arrays
real(8), allocatable :: rlm(:)
! automatic arrays
real(8) v1(3)
integer irlm(16)
logical noweight(wann_nproj)
! fixed values
data irlm / 1, &            ! s
            2,3,1, &        ! pz,px,py -> py,pz,px
            3,4,2,5,1, &    ! z2,xz,yz,xy2y,xy -> xy,yz,z2,zx,x2y2
            4,5,3,6,2,7,1 / ! z3,xz2,yz2,zx2y2,xyz,xx2y2,yx2y2 -> yx2y2,xyz,yz2,z3,xz2,zx2y2,xx2y2
s2=1./sqrt(2.)
s3=1./sqrt(3.)
s6=1./sqrt(6.)
s12=1./sqrt(12.)
! determines the maximum lmax for projections (<=3)
lmaxproj=maxval(wann_proj_l)
if(any(wann_proj_l.lt.0).and.lmaxproj.lt.1) lmaxproj=1    ! sp,sp2,sp3 orbitals
if(any(wann_proj_l.lt.-3).and.lmaxproj.lt.2) lmaxproj=2   ! sp3d,sp3d2 orbitals
if(lmaxproj.gt.3) then
  write(*,*)
  write(*,'("error(genw90twf): projections with l>3 not supported")')
  write(*,*)
  stop
end if
lmmaxproj=lmaxproj*(lmaxproj+2)+1
allocate(rlm(lmmaxproj))
allocate(wann_projulr(nrmtmax,0:lmaxo,natmtot,wann_nproj))
allocate(wann_projclm(lmaxo*(lmaxo+2)+1,natmtot,wann_nproj))
allocate(wann_proj_haswt(wann_nproj,natmtot))
! at the moment, non-atom centred projections are treated as random (!)
noweight=.true.
wann_projulr=0.d0
do is=1,nspecies
  nr=nrcmt(is)
  do ia=1,natoms(is)
    ias=idxas(ia,is)
! code taken from writegeom.f90
    if (molecule) then
! map lattice coordinates to [-0.5,0.5)
      v1(:)=atposl(:,ia,is)
      do i=1,3
        if (v1(i).gt.0.5d0) v1(i)=v1(i)-1.d0
      end do
    else
! otherwise write lattice coordinates
      v1(:)=atposl(:,ia,is)
    end if
    wann_proj_haswt(:,ias)=.false.
    do n=1,wann_nproj
      if(wann_proj_isrand(n)) cycle
! only treats atom centred projections in this version (!)
      if(abs(sum(wann_proj_site(:,n)-v1)).lt.0.0001) then
        wann_proj_haswt(n,ias)=.true.
        noweight(n)=.false.
        select case (wann_proj_radial(n))
! expressions taken from table 3.3 of the wannier90 user guide and the Orbitron
          case (0)
            do l=0,lmaxproj
             !wann_projulr(1:nr,l,ias,n)=apwfr(1:nr,1,1,l,ias)  ! just use the APW radial fn
              irc=1
              do ir=1,nr
                wann_projulr(ir,l,ias,n)=apwfr(irc,1,1,l,ias)   ! just use the APW radial fn (on coarse mesh)
                irc=irc+lradstp
              end do
            end do
          case (1)
            wann_projulr(1:nr,0,ias,n)=2.*wann_proj_zona(n)**1.5&              ! 1s
                *exp(-wann_proj_zona(n)*rcmt(1:nr,is))
          case (2)
            wann_projulr(1:nr,0,ias,n)=(1./2./sqrt(2.))*wann_proj_zona(n)**1.5&! 2s
                *(2.-wann_proj_zona(n)*rcmt(1:nr,is))&
                *exp(-wann_proj_zona(n)*rcmt(1:nr,is)/2.)
            wann_projulr(1:nr,1,ias,n)=(1./2./sqrt(2.))*wann_proj_zona(n)**1.5&! 2p
                *wann_proj_zona(n)*rcmt(1:nr,is)&
                *exp(-wann_proj_zona(n)*rcmt(1:nr,is)/2.)
          case (3)
            wann_projulr(1:nr,0,ias,n)=sqrt(4./27.)*wann_proj_zona(n)**1.5&    ! 3s
                *(1.-(2./3.)*wann_proj_zona(n)*rcmt(1:nr,is)&
                +(2./27.)*((wann_proj_zona(n)*rcmt(1:nr,is))**2.))&
                *exp(-wann_proj_zona(n)*rcmt(1:nr,is)/3.)
            wann_projulr(1:nr,1,ias,n)=sqrt(4./54.)*wann_proj_zona(n)**1.5&    ! 3p
                *(2.-wann_proj_zona(n)*rcmt(1:nr,is)/3.)&
                *(2.*wann_proj_zona(n)*rcmt(1:nr,is)/3.)&
                *exp(-wann_proj_zona(n)*rcmt(1:nr,is)/3.)
            wann_projulr(1:nr,2,ias,n)=sqrt(1./270.)*wann_proj_zona(n)**1.5&   ! 3d
                *(2.*wann_proj_zona(n)*rcmt(1:nr,is)/3.)**2.&
                *exp(-wann_proj_zona(n)*rcmt(1:nr,is)/3.)
          case default
            write(*,*)
            write(*,'("error(genw90twf): radial fn type ",I2," not recognised.")')
            write(*,*)
            stop
        end select
        rlm=0
        wann_projclm(:,ias,n)=cmplx(0.d0,0.d0,kind=8)
        if(wann_proj_l(n).ge.0) then
! converts projection angular part from wannier90 indexing (tab 3.1) to standard
          l=wann_proj_l(n)
          if(wann_proj_m(n).gt.(2*l+1)) goto 100
          m=irlm(wann_proj_m(n)+l*l)-1-l
          lm=l*(l+1)+m+1
          rlm(lm)=1
        else
          select case(wann_proj_l(n))
! lin. comb. of real spherical harmonics from table 3.2 of wannier90 user guide
            case (-1)                         ! sp
              rlm(1)=s2                       ! 1/sqrt(2) s
              select case (wann_proj_m(n))
                case (1)
                  rlm(4)=s2                   ! 1/sqrt(2) px
                case (2)
                  rlm(4)=-s2                  ! -1/sqrt(2) px
                case default
                  goto 100
              end select
            case (-2)                         ! sp2
              rlm(1)=s3                       ! 1/sqrt(3) s
              select case (wann_proj_m(n))
                case (1)
                  rlm(4)=-s6; rlm(2)=s2       ! -1/sqrt(6) px + 1/sqrt(2) py
                case (2)
                  rlm(4)=-s6; rlm(2)=-s2      ! -1/sqrt(6) px - 1/sqrt(2) py
                case (3)
                  rlm(4)=2.*s6;               ! 2/sqrt(6) px
                case default
                  goto 100
              end select
            case (-3)                         ! sp3
              rlm(1)=1/2.                     ! 1/sqrt(3) s
              select case (wann_proj_m(n))
                case (1)    !py,pz,px
                  rlm(2:4)=(/ 1., 1., 1./)/.2 ! (+px+py+pz)/2
                case (2)
                  rlm(2:4)=(/-1.,-1., 1./)/.2 ! (+px-py-pz)/2
                case (3)
                  rlm(2:4)=(/ 1.,-1.,-1./)/.2 ! (-px+py-pz)/2
                case (4)
                  rlm(2:4)=(/-1., 1.,-1./)/.2 ! (-px-py+pz)/2
                case default
                  goto 100
              end select
            case (-4)                         ! sp3d
              select case (wann_proj_m(n))
                case (1)    ! s, py,pz,px
                  rlm(1:4)=(/s3, s2,0d0,-s6/) ! 1/sqrt(3) s - 1/sqrt(6) px + 1/sqrt(2) py
                case (2)
                  rlm(1:4)=(/s3,-s2,0d0,-s6/) ! 1/sqrt(3) s - 1/sqrt(6) px - 1/sqrt(2) py
                case (3)
                  rlm(1:4)=(/s3,0d0,0d0,2*s6/)! 1/sqrt(3) s + 2/sqrt(6) px
                case (4)
                  rlm(3)=s2; rlm(7)=s2        ! 1/sqrt(2) pz + 1/sqrt(2) dz2
                case (5)
                  rlm(3)=-s2; rlm(7)=s2       ! -1/sqrt(2) pz + 1/sqrt(2) dz2
                case default
                  goto 100
              end select
            case (-5)                         ! sp3d2
              rlm(1)=s6                       ! 1/sqrt(6) s
              select case (wann_proj_m(n))
                case (1)
                  rlm(4)=-s2                  ! -1/sqrt(2) px
                  rlm(7)=-s12; rlm(9)=1./2.   ! -1/sqrt(12) dz2 + 1/2 dx2-y2
                case (2)
                  rlm(4)=s2                   ! 1/sqrt(2) px
                  rlm(7)=-s12; rlm(9)=1./2.   ! -1/sqrt(12) dz2 + 1/2 dx2-y2
                case (3)
                  rlm(4)=-s2                  ! -1/sqrt(2) px
                  rlm(7)=-s12; rlm(9)=-1./2.  ! -1/sqrt(12) dz2 + 1/2 dx2-y2
                case (4)
                  rlm(4)=s2                   ! 1/sqrt(2) px
                  rlm(7)=-s12; rlm(9)=-1./2.  ! -1/sqrt(12) dz2 + 1/2 dx2-y2
                case (5)
                  rlm(3)=-s2; rlm(7)=s3       ! -1/sqrt(2) pz + 1/sqrt(3) dz2
                case (6)
                  rlm(3)=s2;  rlm(7)=s3       ! 1/sqrt(2) pz + 1/sqrt(3) dz2
                case default
                  goto 100
              end select
          end select
        end if
! converts from real to complex spherical harmonics
        call rtozflm(lmaxproj,rlm,wann_projclm(:,ias,n))
      end if
    end do
  end do    ! loop over atoms
end do      ! loop over species
! Prints a warning if projections are not atom centred
do n=1,wann_nproj
  if(noweight(n).and..not.wann_proj_isrand(n)) then
    write(*,*)
    write(*,'("Warning(genw90twf): projection ",I4," at ",3F12.8," is not atom &
              &centred. Treated as random.")') n, wann_proj_site(:,n)
    wann_proj_isrand(n)=.true.
  end if
end do

return

100 write(*,*)
    write(*,'("error(genw90twf): (l=",I2,",m=",I2,") combination not recognised.")')&
        wann_proj_l(n),wann_proj_m(n)
    write(*,*)
    stop

end subroutine
!EOC
