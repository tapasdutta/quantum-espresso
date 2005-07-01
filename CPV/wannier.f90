!
! Copyright (C) 2002-2005 Quantum-ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
! ... wannier function dynamics and electric field
!                                            - M.S
!----------------------------------------------------------------------------
MODULE efcalc
  !----------------------------------------------------------------------------
  !
  USE kinds,        ONLY : dbl
  USE wannier_base, ONLY : wf_efield, wf_switch
  USE wannier_base, ONLY : efx0, efy0, efz0, efx1, efy1, efz1, sw_len
  !
  IMPLICIT NONE
  !
  REAL(KIND=dbl)              :: efx, efy, efz, sw_step
  REAL(KIND=dbl), ALLOCATABLE :: xdist(:), ydist(:), zdist(:)
  !
  CONTAINS
  !
  !--------------------------------------------------------------------------
  SUBROUTINE clear_nbeg( nbeg )
    !--------------------------------------------------------------------------
    INTEGER, INTENT(OUT) :: nbeg
    !
    !  some more electric field stuff
    !             - M.S
    IF ( wf_efield ) THEN
      IF ( wf_switch ) THEN
        WRITE(6,*) "!-------------------------------------------------------!"
        WRITE(6,*) "!                                                       !"
        WRITE(6,*) "! NBEG IS SET TO 0 FOR ADIABATIC SWITCHING OF THE FIELD !"
        WRITE(6,*) "!                                                       !"
        WRITE(6,*) "!-------------------------------------------------------!"
        nbeg=0
      END IF
    END IF
    RETURN
  END SUBROUTINE clear_nbeg

  SUBROUTINE ef_force( fion, na, nsp, zv )
    IMPLICIT NONE
    REAL(KIND=dbl) :: fion( :, : ), zv(:)
    INTEGER :: na(:), nsp
    INTEGER :: is, ia, isa
    !  Electric Feild for ions here

     IF(wf_efield) THEN
        isa = 0
        DO is=1,nsp
           DO ia=1,na(is)
               isa = isa + 1
               fion(1,isa)=fion(1,isa)+efx*zv(is)
               fion(2,isa)=fion(2,isa)+efy*zv(is)
               fion(3,isa)=fion(3,isa)+efz*zv(is)
           END DO
        END DO
      END IF
    RETURN
  END SUBROUTINE ef_force
  !
END MODULE efcalc
!
MODULE tune
  !
  USE kinds, ONLY : dbl
  !
  LOGICAL        :: shift
  INTEGER        :: npts,av0,av1, xdir,ydir,zdir, start
  REAL(KIND=dbl) :: alpha,b
  !
END MODULE tune
!
MODULE wannier_module
  !
  USE kinds, ONLY : dbl
  !
  IMPLICIT NONE
  SAVE
  LOGICAL :: what1, wann_calc
  REAL(KIND=dbl), ALLOCATABLE :: utwf(:,:)
  REAL(KIND=dbl), ALLOCATABLE :: wfc(:,:)
  REAL(KIND=dbl), ALLOCATABLE :: rhos1(:,:), rhos2(:,:)
  COMPLEX(KIND=dbl), ALLOCATABLE :: rhogdum(:,:)
!N.B:      In the presence of an electric field every wannier state feels a different
!          potantial, which depends on the position of its center. RHOS is read in as
!          the charge density in subrouting vofrho and overwritten to be the potential.
!                                                                        -M.S
  REAL(KIND=dbl) :: wfx, wfy, wfz, ionx, iony, ionz

  CONTAINS

  SUBROUTINE allocate_wannier( n, nnrsx, nspin, ng )
    INTEGER, INTENT(in) :: n, nnrsx, nspin, ng
    ALLOCATE(utwf(n,n))
    ALLOCATE(wfc(3,n))
    ALLOCATE(rhos1(nnrsx, nspin))
    ALLOCATE(rhos2(nnrsx, nspin))
    ALLOCATE(rhogdum(ng,nspin))
    RETURN
  END SUBROUTINE allocate_wannier
  SUBROUTINE deallocate_wannier( )
    IF( ALLOCATED(utwf) ) DEALLOCATE(utwf)
    IF( ALLOCATED(wfc) ) DEALLOCATE(wfc)
    IF( ALLOCATED(rhos1) ) DEALLOCATE(rhos1)
    IF( ALLOCATED(rhos2) ) DEALLOCATE(rhos2)
    IF( ALLOCATED(rhogdum) ) DEALLOCATE(rhogdum)
    RETURN
  END SUBROUTINE deallocate_wannier

END MODULE wannier_module

MODULE electric_field_module
  !
  USE kinds, ONLY : dbl
  !
  IMPLICIT NONE
  SAVE
  LOGICAL :: field_tune, ft
  REAL(KIND=dbl) :: efe_elec, efe_ion, prefactor, e_tuned(3)
  REAL(KIND=dbl) ::  tt(3), cdmm(3), tt2(3)
  REAL(KIND=dbl) :: par, alen, blen, clen, rel1(3), rel2(3)
!     ====  1 Volt / meter      = 1/(5.1412*1.e+11) a.u.            ====
END MODULE electric_field_module


MODULE wannier_subroutines
  !
  USE kinds, ONLY : dbl
  !
  IMPLICIT NONE
  SAVE
  !
  CONTAINS
  !
SUBROUTINE read_efwan_param( nbeg )

  USE wannier_module
  USE electric_field_module
  USE tune
  USE efcalc
  USE wannier_base

  IMPLICIT NONE

  INTEGER, INTENT(in) :: nbeg
  INTEGER :: i

  what1=.FALSE.
  wann_calc=.FALSE.
  INQUIRE (file='WANNIER', EXIST=wann_calc)
  IF(wann_calc) THEN
    OPEN(unit=1,file='WANNIER', status='old')
    READ(1,*) wf_efield, wf_switch
    READ(1,*) sw_len
    IF(sw_len.LE.0) sw_len=1
    READ(1,*) efx0, efy0, efz0
    READ(1,*) efx1, efy1, efz1
    READ(1,*) wfsd
    READ(1,*) wfdt, maxwfdt, nit, nsd
    READ(1,*) wf_q, wf_dt, wf_friction, nsteps
    READ(1,*) tolw
    READ(1,*) adapt
    READ(1,*) calwf, nwf, wffort
    IF(nwf.GT.0) ALLOCATE(iplot(nwf))
    DO i=1,nwf
      READ(1,*) iplot(i)
    END DO
    READ(1,*) writev
    CLOSE(1)
    IF(nbeg.EQ.-2.AND.(wf_efield)) THEN
      WRITE(6,*) "ERROR! ELECTRIC FIELD MUST BE SWITCHED ON ONLY AFTER OBTAINING THE GROUND STATE"
      WRITE(6,*) "-------------------------THE PROGRAM WILL STOP---------------------------------"
      CALL errore(' read_efwan_param ', ' electric field ', 1 )
    END IF
  END IF
  field_tune=.FALSE.
  ft=.FALSE.
  INQUIRE(file='FIELD_TUNE', EXIST=ft)
  IF(ft) THEN
    OPEN(unit=1, file='FIELD_TUNE', status='old')
    READ(1,*) field_tune
    IF(field_tune) THEN
      efx0=0.d0
      efy0=0.d0
      efz0=0.d0
      efx1=0.d0
      efy1=0.d0
      efz1=0.d0
    END IF
    READ(1,*) shift, start
    READ(1,*) npts, av0, av1
    READ(1,*) zdir, alpha,b
    CLOSE(1)
  END IF
 
END SUBROUTINE read_efwan_param

SUBROUTINE wannier_init( ibrav, alat, a1, a2, a3, b1, b2, b3 )

  USE wannier_module
  USE electric_field_module
  USE tune
  USE efcalc
  USE wannier_base

  IMPLICIT NONE

  INTEGER :: ibrav
  REAL(KIND=dbl) :: a1(3), a2(3), a3(3)
  REAL(KIND=dbl) :: b1(3), b2(3), b3(3)
  REAL(KIND=dbl) :: alat

  INTEGER :: i

!-------------------------------------------------------------------
!More Wannier and Field Initialization
!                               - M.S
!-------------------------------------------------------------------
    IF (calwf.GT.1) THEN
      IF(calwf.EQ.3) THEN
        WRITE(6,*) "------------------------DYNAMICS IN THE WANNIER BASIS--------------------------"
        WRITE(6,*) "                             DYNAMICS PARAMETERS "
        IF(wfsd) THEN
          WRITE(6,12132) wfdt
          WRITE(6,12133) maxwfdt
          WRITE(6,*) nsd,"STEPS OF STEEPEST DESCENT FOR OPTIMIZATION OF THE SPREAD"
          WRITE(6,*) nit-nsd,"STEPS OF CONJUGATE GRADIENT FOR OPTIMIZATION OF THE SPREAD"
        ELSE
          WRITE(6,12125) wf_q
          WRITE(6,12126) wf_dt
          WRITE(6,12124) wf_friction
          WRITE(6,*) nsteps,"STEPS OF DAMPED MOLECULAR DYNAMICS FOR OPTIMIZATION OF THE SPREAD"
        END IF
        WRITE(6,*) "AVERAGE WANNIER FUNCTION SPREAD WRITTEN TO     FORT.24"
        WRITE(6,*) "INDIVIDUAL WANNIER FUNCTION SPREAD WRITTEN TO  FORT.25"
        WRITE(6,*) "WANNIER CENTERS WRITTEN TO                     FORT.26"
        WRITE(6,*) "SOME PERTINENT RUN-TIME INFORMATION WRITTEN TO FORT.27"
        WRITE(6,*) "-------------------------------------------------------------------------------"
        WRITE(6,*)
12124   FORMAT(' DAMPING COEFFICIENT USED FOR WANNIER FUNCTION SPREAD OPTIMIZATION = ',f10.7)
12125   FORMAT(' FICTITIOUS MASS PARAMETER USED FOR SPREAD OPTIMIZATION            = ',f7.1)
12126   FORMAT(' TIME STEP USED FOR DAMPED DYNAMICS                                = ',f10.7)
!
12132   FORMAT(' SMALLEST TIMESTEP IN THE SD / CG DIRECTION FOR SPREAD OPTIMIZATION= ',f10.7)
12133   FORMAT(' LARGEST TIMESTEP IN THE SD / CG DIRECTION FOR SPREAD OPTIMIZATION = ',f10.7)
      END IF
      WRITE(6,*) "IBRAV SELECTED:",ibrav

      CALL recips( a1, a2, a3, b1, b2, b3 )
      b1 = b1 * alat
      b2 = b2 * alat
      b3 = b3 * alat

      CALL wfunc_init( calwf, b1, b2, b3, ibrav)
      WRITE (6,*) "out from wfunc_init"
      WRITE(6,*)
      utwf=0.d0
      DO i=1, SIZE( utwf, 1 )
        utwf(i, i)=1.d0
      END DO
    END IF
    IF(wf_efield) THEN
       CALL grid_map
       WRITE(6,*) "GRID MAPPING DONE"
       WRITE(6,*) "DYNAMICS IN THE PRESENCE OF AN EXTERNAL ELECTRIC FIELD"
       WRITE(6,*)
       WRITE(6,*) "POLARIZATION CONTRIBUTION OUTPUT TO FORT.28 IN THE FOLLOWING FORMAT"
       WRITE(6,*)
       WRITE(6,*) "EFX, EFY, EFZ, ELECTRIC ENTHANLPY(ELECTRONIC), ELECTRIC ENTHALPY(IONIC)"
       WRITE(6,*)
       WRITE(6,12121) efx0
       WRITE(6,12122) efy0
       WRITE(6,12123) efz0
       WRITE(6,12128) efx1
       WRITE(6,12129) efy1
       WRITE(6,12130) efz1
       IF(wf_switch) THEN
           WRITE(6,12127) sw_len
       END IF
       WRITE(6,*)
12121   FORMAT(' E0(x) = ',f10.7)
12122   FORMAT(' E0(y) = ',f10.7)
12123   FORMAT(' E0(z) = ',f10.7)
12128   FORMAT(' E1(x) = ',f10.7)
12129   FORMAT(' E1(y) = ',f10.7)
12130   FORMAT(' E1(z) = ',f10.7)
12131   FORMAT(' wf_efield Now ' ,3(f12.8,1x))
12127   FORMAT(' FIELD WILL BE TURNED ON ADIBATICALLY OVER ',i5,' STEPS')
      END IF
!--------------------------------------------------------------------------
!               End of more initialization - M.S
!--------------------------------------------------------------------------


  RETURN
END SUBROUTINE wannier_init


SUBROUTINE get_wannier_center( tfirst, cm, bec, becdr, eigr, eigrb, taub, irb, ibrav, b1, b2, b3 )
  USE efcalc, ONLY: wf_efield  
  USE wannier_base, ONLY: calwf, jwf
  USE wannier_module, ONLY: what1, wfc, utwf
  IMPLICIT NONE
  LOGICAL, INTENT(in) :: tfirst
  COMPLEX(KIND=dbl) :: cm(:,:,:,:)
  REAL(KIND=dbl) :: bec(:,:), becdr(:,:,:)
  COMPLEX(KIND=dbl) :: eigrb(:,:), eigr(:,:)
  INTEGER :: irb(:,:)
  REAL(KIND=dbl) :: taub(:,:)
  INTEGER :: ibrav
  REAL(KIND=dbl) :: b1(:), b2(:), b3(:)
  !--------------------------------------------------------------------------
  !Get Wannier centers for the first step if wf_efield=true
  !--------------------------------------------------------------------------
  IF(wf_efield) THEN
    IF(tfirst) THEN
      what1=.TRUE.
      jwf=1
      CALL wf (calwf,cm(:,:,1,1),bec,eigr,eigrb,taub,irb,b1,b2,b3,utwf,becdr,what1,wfc,jwf,ibrav)
      WRITE(6,*) "WFC Obtained"
      what1=.FALSE.
    END IF
  END IF
  RETURN
END SUBROUTINE get_wannier_center


SUBROUTINE ef_tune( rhog, tau0 )
  USE electric_field_module, ONLY: field_tune, e_tuned
  USE wannier_module, ONLY: rhogdum
  IMPLICIT NONE
  COMPLEX(KIND=dbl) :: rhog(:,:)
  REAL(KIND=dbl) :: tau0(:,:)
!-------------------------------------------------------------------
!     Tune the Electric field               - M.S
!-------------------------------------------------------------------
  IF (field_tune) THEN
    rhogdum=rhog
    CALL macroscopic_average(rhogdum,tau0,e_tuned)
  END IF

  RETURN
END SUBROUTINE ef_tune


SUBROUTINE write_charge_and_exit( rhog )
  USE mp, ONLY: mp_end
  USE wannier_base, ONLY: writev
  IMPLICIT NONE
  COMPLEX(KIND=dbl) :: rhog(:,:)
!-------------------------------------------------------------------
!     Write chargedensity in g-space    - M.S
      IF (writev) THEN
         CALL write_rho_g(rhog)
         CALL mp_end()
         STOP 'write_charge_and_exit'
      END IF
  RETURN
END SUBROUTINE write_charge_and_exit


SUBROUTINE wf_options( tfirst, nfi, cm, rhovan, bec, becdr, eigr, eigrb, taub, irb, &
           ibrav, b1, b2, b3, rhor, rhog, rhos, enl, ekin  )

  USE efcalc, ONLY: wf_efield
  USE wannier_base, ONLY: nwf, calwf, jwf, wffort, iplot, iwf
  USE wannier_module, ONLY: what1, wfc, utwf
  USE mp, ONLY: mp_end
  USE control_flags, ONLY: iprsta

  IMPLICIT NONE

  LOGICAL, INTENT(in) :: tfirst
  INTEGER :: nfi
  COMPLEX(KIND=dbl) :: cm(:,:,:,:)
  REAL(KIND=dbl) :: bec(:,:), becdr(:,:,:)
  REAL(KIND=dbl) :: rhovan(:,:,:)
  COMPLEX(KIND=dbl) :: eigrb(:,:), eigr(:,:)
  INTEGER :: irb(:,:)
  REAL(KIND=dbl) :: taub(:,:)
  INTEGER :: ibrav
  REAL(KIND=dbl) :: b1(:), b2(:), b3(:)
  COMPLEX(KIND=dbl) :: rhog(:,:)
  REAL(KIND=dbl) :: rhor(:,:), rhos(:,:)
  REAL(KIND=dbl) :: enl, ekin 


  INTEGER :: i, j

!-------------------------------------------------------------------
! Wannier Function options            - M.S
!-------------------------------------------------------------------
    jwf=1
    IF (calwf.EQ.1) THEN
      DO i=1, nwf
        iwf=iplot(i)
        j=wffort+i-1
        CALL rhoiofr (nfi,cm, irb, eigrb,bec,rhovan,rhor,rhog,rhos,enl,ekin,j)
        IF(iprsta.GT.0) WRITE(6,*) 'Out from rhoiofr'
        IF(iprsta.GT.0) WRITE(6,*) 
      END DO
      CALL mp_end()
      STOP 'wf_options 1'
    END IF
!---------------------------------------------------------------------
    IF (calwf.EQ.2) THEN

!     calculate the overlap matrix
!
      jwf=1
      CALL wf (calwf,cm(:,:,1,1),bec,eigr,eigrb,taub,irb,b1,b2,b3,utwf,becdr,what1,wfc,jwf,ibrav)

      CALL mp_end()
      STOP 'wf_options 2'
    END IF
!---------------------------------------------------------------------
    IF (calwf.EQ.5) THEN
!
      jwf=iplot(1)
      CALL wf (calwf,cm(:,:,1,1),bec,eigr,eigrb,taub,irb,b1,b2,b3,utwf,becdr,what1,wfc,jwf,ibrav)

      CALL mp_end()
      STOP 'wf_options 5'
    END IF
!----------------------------------------------------------------------
! End Wannier Function options - M.S
!
!=======================================================================

  RETURN
END SUBROUTINE wf_options


SUBROUTINE ef_potential( nfi, rhos, bec, deeq, betae, c0, cm, emadt2, emaver, verl1, verl2, c2, c3 )
  USE efcalc, ONLY: wf_efield, efx, efy, efz, efx0, efy0, efz0, efx1, efy1, efz1, &
                    wf_switch, sw_len, sw_step, xdist, ydist, zdist
  USE electric_field_module, ONLY: field_tune, e_tuned, par, rel1, rel2
  USE wannier_module, ONLY: rhos1, rhos2, wfc
  USE smooth_grid_dimensions, ONLY: nnrsx
  USE electrons_base, ONLY: n => nbsp, nspin, nupdwn
  USE cell_base, ONLY: ainv, a1, a2, a3
  USE reciprocal_vectors, ONLY: ng0 => gstart
  USE control_flags, ONLY: tsde
  USE wave_base, ONLY: wave_steepest, wave_verlet

  IMPLICIT NONE

  INTEGER :: nfi
  REAL(KIND=dbl) :: rhos(:,:)
  REAL(KIND=dbl) :: bec(:,:)
  REAL(KIND=dbl) :: deeq(:,:,:,:)
  COMPLEX(KIND=dbl) :: betae(:,:)
  COMPLEX(KIND=dbl) :: c0( :, : ), c2( : ), c3( : )
  COMPLEX(KIND=dbl) :: cm( :, : )
  REAL(KIND=dbl) :: emadt2(:)
  REAL(KIND=dbl) :: emaver(:)
  REAL(KIND=dbl) :: verl1, verl2


  INTEGER :: i, ir
 
  !    Potential for electric field
  !                    - M.S

  IF(wf_efield) THEN
    IF(field_tune) THEN
      efx=e_tuned(1)
      efy=e_tuned(2)
      efz=e_tuned(3)
      WRITE(6,12131) efx, efy,efz
12131      FORMAT(' wf_efield Now ' ,3(f12.8,1x))
    ELSE
      IF(wf_switch) THEN
        par=0.d0
        IF(nfi.LE.sw_len) THEN
          sw_step=1.0d0/DBLE(sw_len)
          par=nfi*sw_step
          IF(efx1.LT.efx0) THEN
            efx=efx0-(efx0-efx1)*par**5*(70*par**4-315*par**3+540*par**2-420*par+126)
          ELSE
            efx=efx0+(efx1-efx0)*par**5*(70*par**4-315*par**3+540*par**2-420*par+126)
          END IF
          IF(efy1.LT.efy0) THEN
            efy=efy0-(efy0-efy1)*par**5*(70*par**4-315*par**3+540*par**2-420*par+126)
          ELSE
            efy=efy0+(efy1-efy0)*par**5*(70*par**4-315*par**3+540*par**2-420*par+126)
          END IF
          IF(efz1.LT.efz0) THEN
            efz=efz0-(efz0-efz1)*par**5*(70*par**4-315*par**3+540*par**2-420*par+126)
          ELSE
            efz=efz0+(efz1-efz0)*par**5*(70*par**4-315*par**3+540*par**2-420*par+126)
          END IF
        END IF
      ELSE
        efx=efx1
        efy=efy1
        efz=efz1
      END IF
    END IF
  END IF
  DO i=1,n,2
    IF(wf_efield) THEN
      rhos1=0.d0
      rhos2=0.d0
      DO ir=1,nnrsx
        rel1(1)=xdist(ir)*a1(1)+ydist(ir)*a2(1)+zdist(ir)*a3(1)-wfc(1,i)
        rel1(2)=xdist(ir)*a1(2)+ydist(ir)*a2(2)+zdist(ir)*a3(2)-wfc(2,i)
        rel1(3)=xdist(ir)*a1(3)+ydist(ir)*a2(3)+zdist(ir)*a3(3)-wfc(3,i)
!  minimum image convention
        CALL pbc(rel1,a1,a2,a3,ainv,rel1)
        IF(nspin.EQ.2) THEN
          IF(i.LE.nupdwn(1)) THEN
            rhos1(ir,1)=rhos(ir,1)+efx*rel1(1)+efy*rel1(2)+efz*rel1(3)
          ELSE
            rhos1(ir,2)=rhos(ir,2)+efx*rel1(1)+efy*rel1(2)+efz*rel1(3)
          END IF
        ELSE
          rhos1(ir,1)=rhos(ir,1)+efx*rel1(1)+efy*rel1(2)+efz*rel1(3)
        END IF
        IF(i.NE.n) THEN
          rel2(1)=xdist(ir)*a1(1)+ydist(ir)*a2(1)+zdist(ir)*a3(1)-wfc(1,i+1)
          rel2(2)=xdist(ir)*a1(2)+ydist(ir)*a2(2)+zdist(ir)*a3(2)-wfc(2,i+1)
          rel2(3)=xdist(ir)*a1(3)+ydist(ir)*a2(3)+zdist(ir)*a3(3)-wfc(3,i+1)
!  minimum image convention
          CALL pbc(rel2,a1,a2,a3,ainv,rel2)
          IF(nspin.EQ.2) THEN
            IF(i+1.LE.nupdwn(1)) THEN
              rhos2(ir,1)=rhos(ir,1)+efx*rel2(1)+efy*rel2(2)+efz*rel2(3)
            ELSE
              rhos2(ir,2)=rhos(ir,2)+efx*rel2(1)+efy*rel2(2)+efz*rel2(3)
            END IF
          ELSE
            rhos2(ir,1)=rhos(ir,1)+efx*rel2(1)+efy*rel2(2)+efz*rel2(3)
          END IF
        ELSE
          rhos2(ir,:)=rhos1(ir,:)
        END IF
      END DO
      CALL dforce_field(bec,deeq,betae,i,c0(1,i),c0(1,i+1),c2,c3,rhos1,rhos2)
    ELSE
      CALL dforce(bec,betae,i,c0(1,i),c0(1,i+1),c2,c3,rhos)
    END IF
    IF(tsde) THEN
      CALL wave_steepest( cm(:, i  ), c0(:, i  ), emadt2, c2 )
      CALL wave_steepest( cm(:, i+1), c0(:, i+1), emadt2, c3 )
    ELSE
      CALL wave_verlet( cm(:, i  ), c0(:, i  ), verl1, verl2, emaver, c2 )
      CALL wave_verlet( cm(:, i+1), c0(:, i+1), verl1, verl2, emaver, c3 )
    ENDIF
    IF (ng0.EQ.2) THEN
      cm(1,  i)=CMPLX(REAL(cm(1,  i)),0.0)
      cm(1,i+1)=CMPLX(REAL(cm(1,i+1)),0.0)
    END IF
  END DO

  RETURN
END SUBROUTINE ef_potential


!--------------------------------------------------------------------
!Electric Field Implementation for Electric Enthalpy
!                                              - M.S
!--------------------------------------------------------------------
SUBROUTINE ef_enthalpy( enthal, tau0 )
  USE efcalc, ONLY: wf_efield, efx, efy, efz
  USE electric_field_module, ONLY: efe_elec, efe_ion, tt2, tt
  USE wannier_module, ONLY: wfx, wfy, wfz, ionx, iony, ionz, wfc
  USE electrons_base, ONLY: n => nbsp, f
  USE cell_base, ONLY: ainv, a1, a2, a3
  USE ions_base, ONLY: na, nsp, zv
  USE io_global, ONLY: ionode

  IMPLICIT NONE

  REAL(KIND=dbl) :: enthal, tau0(:,:)
  INTEGER :: i, is, ia, isa

  IF(wf_efield) THEN
    !  Electronic Contribution First
    wfx=0.d0
    wfy=0.d0
    wfz=0.d0
    efe_elec=0.d0
    DO i=1,n
      tt2(1)=wfc(1,i)
      tt2(2)=wfc(2,i)
      tt2(3)=wfc(3,i)
      CALL pbc(tt2,a1,a2,a3,ainv,tt2)
      wfx=wfx+f(i)*tt2(1)
      wfy=wfy+f(i)*tt2(2)
      wfz=wfz+f(i)*tt2(3)
    END DO
    efe_elec=efe_elec+efx*wfx+efy*wfy+efz*wfz
    !Then Ionic Contribution
    ionx=0.d0
    iony=0.d0
    ionz=0.d0
    efe_ion=0.d0
    isa = 0
    DO is=1,nsp
      DO ia=1,na(is)
        isa = isa + 1
        tt(1)=tau0(1,isa)
        tt(2)=tau0(2,isa)
        tt(3)=tau0(3,isa)
        CALL pbc(tt,a1,a2,a3,ainv,tt)
        ionx=ionx+zv(is)*tt(1)
        iony=iony+zv(is)*tt(2)
        ionz=ionz+zv(is)*tt(3)
      END DO
    END DO
    efe_ion=efe_ion+efx*ionx+efy*iony+efz*ionz
    IF( ionode ) THEN
      WRITE(28,'(f12.9,1x,f12.9,1x,f12.9,1x,f20.15,1x,f20.15)') efx, efy, efz, efe_elec,-efe_ion
    END IF
  END IF
  enthal=enthal+efe_elec-efe_ion

  RETURN
END SUBROUTINE ef_enthalpy


SUBROUTINE wf_closing_options( nfi, c0, cm, bec, becdr, eigr, eigrb, taub, irb, &
           ibrav, b1, b2, b3, taus, tausm, vels, velsm, acc, lambda, lambdam, xnhe0, &
           xnhem, vnhe, xnhp0, xnhpm, vnhp, nhpcl, ekincm, xnhh0, xnhhm, vnhh, velh, &
           ecut, ecutw, delt, celldm, fion, tps, mat_z, occ_f )

  USE efcalc,         ONLY : wf_efield
  USE wannier_base,   ONLY : nwf, calwf, jwf, wffort, iplot, iwf
  USE wannier_module, ONLY : what1, wfc, utwf
  USE mp,             ONLY : mp_end
  USE control_flags,  ONLY : iprsta
  USE electrons_base, ONLY : n => nbsp
  USE gvecw,          ONLY : ngw
  USE control_flags,  ONLY : ndw
  USE cell_base,      ONLY : h, hold
  USE ions_base,      ONLY : pmass
  USE cvan,           ONLY : nvb
  USE restart_file

  IMPLICIT NONE

  INTEGER :: nfi
  COMPLEX(KIND=dbl) :: c0(:,:,:,:)
  COMPLEX(KIND=dbl) :: cm(:,:,:,:)
  REAL(KIND=dbl) :: bec(:,:), becdr(:,:,:)
  COMPLEX(KIND=dbl) :: eigrb(:,:), eigr(:,:)
  INTEGER :: irb(:,:)
  REAL(KIND=dbl) :: taub(:,:)
  INTEGER :: ibrav
  REAL(KIND=dbl) :: b1(:), b2(:), b3(:)
  REAL(KIND=dbl) :: taus(:,:), tausm(:,:), vels(:,:), velsm(:,:)
  REAL(KIND=dbl) :: acc(:)
  REAL(KIND=dbl) :: lambda(:,:), lambdam(:,:)
  REAL(KIND=dbl) :: xnhe0, xnhem, vnhe, xnhp0(:), xnhpm(:), vnhp(:), ekincm
  INTEGER      :: nhpcl
  REAL(KIND=dbl) :: velh(:,:)
  REAL(KIND=dbl) :: xnhh0(:,:), xnhhm(:,:), vnhh(:,:)
  REAL(KIND=dbl) :: ecut, ecutw, delt, celldm(:)
  REAL(KIND=dbl) :: fion(:,:), tps
  REAL(KIND=dbl) :: mat_z(:,:,:), occ_f(:)

!=============================================================
! More Wannier Function Options
!                         - M.S
!=============================================================

  IF(calwf.EQ.4) THEN
    jwf=1
    CALL wf(calwf,c0(:,:,1,1),bec,eigr,eigrb,taub,irb,b1,b2,b3,utwf,becdr,what1,wfc,jwf,ibrav)
    IF(nvb.EQ.0) THEN
      CALL wf(calwf,cm(:,:,1,1),bec,eigr,eigrb,taub,irb,b1,b2,b3,utwf,becdr,what1,wfc,jwf,ibrav)
    ELSE
        cm(1:n,1:ngw,1,1)=c0(1:n,1:ngw,1,1)
    END IF

    CALL writefile &
     &     ( ndw,h,hold,nfi,c0(:,:,1,1),cm(:,:,1,1),taus,tausm,vels,velsm,acc,   &
     &       lambda,lambdam,xnhe0,xnhem,vnhe,xnhp0,xnhpm,vnhp,nhpcl,ekincm,   &
     &       xnhh0,xnhhm,vnhh,velh,ecut,ecutw,delt,pmass,ibrav,celldm,fion,tps, &
     &       mat_z, occ_f )


    WRITE(6,*) 'Wannier Functions Written to unit',ndw
    CALL mp_end()
    STOP 'wf_closing_options 4' 
  END IF

!---------------------------------------------------------

  IF(calwf.EQ.3) THEN
!   construct overlap matrix and calculate spreads and do Localization
    jwf=1
    CALL wf (calwf,c0(:,:,1,1),bec,eigr,eigrb,taub,irb,b1,b2,b3,utwf,becdr,what1,wfc,jwf,ibrav)
  END IF
  RETURN
END SUBROUTINE wf_closing_options


END MODULE wannier_subroutines
