!
! Copyright (C) 2011 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!-------------------------------------------------------------------------
      SUBROUTINE s_wfc(n_atomic_wfc1,becwfc,betae,wfc,swfc) !#@@@ Changed n_atomic_wfc to n_atomic_wfc1
!-----------------------------------------------------------------------
!
!     input: wfc, becwfc=<wfc|beta>, betae=|beta>
!     output: swfc=S|wfc>
!
      USE kinds, ONLY: DP
      USE ions_base, ONLY: na
      USE uspp, ONLY: nhsa => nkb, nhsavb=>nkbus, qq
      USE uspp_param, ONLY: nh, nvb, ish
      USE gvecw, ONLY: ngw
      USE constants, ONLY: pi, fpi
      IMPLICIT NONE
! input
      INTEGER, INTENT(in)         :: n_atomic_wfc1
      COMPLEX(DP), INTENT(in) :: betae(ngw,nhsa),                   &
     &                               wfc(ngw,n_atomic_wfc1)
      REAL(DP), INTENT(in)    :: becwfc(nhsa,n_atomic_wfc1)
! output
      COMPLEX(DP), INTENT(out):: swfc(ngw,n_atomic_wfc1)
! local
      INTEGER is, iv, jv, ia, inl, jnl, i
      REAL(DP) qtemp(nhsavb,n_atomic_wfc1)
!
      swfc = wfc
!
      IF (nvb.GT.0) THEN
         qtemp=0.d0
         DO is=1,nvb
            DO iv=1,nh(is)
               DO jv=1,nh(is)
                  IF(ABS(qq(iv,jv,is)).GT.1.e-5) THEN
                     DO ia=1,na(is)
                        inl=ish(is)+(iv-1)*na(is)+ia
                        jnl=ish(is)+(jv-1)*na(is)+ia
                        DO i=1,n_atomic_wfc1
                           qtemp(inl,i) = qtemp(inl,i) +                &
     &                                    qq(iv,jv,is)*becwfc(jnl,i)
                        END DO
                     END DO
                  ENDIF
               END DO
            END DO
         END DO
!
         CALL dgemm &
              ('N','N',2*ngw,n_atomic_wfc1,nhsavb,1.0d0,betae,2*ngw,&
               qtemp,nhsavb,1.0d0,swfc,2*ngw)
!
      END IF
!
!      swfc=swfc+wfc
!
      RETURN
      END SUBROUTINE s_wfc
!-----------------------------------------------------------------------
      subroutine ldaU_init
!-----------------------------------------------------------------------
!
      USE constants,        ONLY: autoev
      use ldaU_cp,          ONLY: n_atomic_wfc, atomwfc,lda_plus_u, Hubbard_U
      use ldaU_cp,          ONLY: Hubbard_lmax, Hubbard_l, ns, vupsi
      use input_parameters, ONLY: lda_plus_u_ => lda_plus_u
      use input_parameters, ONLY: Hubbard_U_ => Hubbard_U
      use ions_base,        only: na, nsp, nat, atm
      use gvecw,            only: ngw
      use electrons_base,   only: nspin, nx => nbspx
      USE uspp_param,       ONLY: upf
      USE step_penalty,     ONLY: vpsi_pen, A_pen, sigma_pen, alpha_pen, step_pen
      use input_parameters, ONLY: step_pen_ => step_pen
      use input_parameters, ONLY: A_pen_ => A_pen
      use input_parameters, ONLY: sigma_pen_ => sigma_pen
      use input_parameters, ONLY: alpha_pen_ => alpha_pen
      !
      implicit none
      integer is, nb, l
      integer, external :: set_Hubbard_l

! allocate vupsi

      lda_plus_u = lda_plus_u_
      IF ( .NOT.lda_plus_u ) RETURN
      allocate(vupsi(ngw,nx))

      vupsi=(0.0d0,0.0d0)
      allocate(vpsi_pen(ngw,nx)) ! step_constraint 
      vpsi_pen=(0.0d0,0.0d0)
      n_atomic_wfc=0

      do is=1,nsp
         !
         Hubbard_U( is ) = Hubbard_U_( is )/autoev
         !
         do nb = 1,upf(is)%nwfc
            l = upf(is)%lchi(nb)
            n_atomic_wfc = n_atomic_wfc + (2*l+1)*na(is)
         end do
         !
      end do
!
      allocate(atomwfc(ngw,n_atomic_wfc))

      if (lda_plus_u) then
         Hubbard_lmax = -1
         do is=1,nsp
            if (Hubbard_U(is).ne.0.d0) then 
!                Hubbard_l(is)=2
               Hubbard_l(is) = set_Hubbard_l( atm(is) )
                Hubbard_lmax = max(Hubbard_lmax,Hubbard_l(is))
               write (6,*) ' HUBBARD L FOR TYPE ',atm(is),' IS ',&
     &                       Hubbard_l(is)
            end if
         end do
         write (6,*) ' MAXIMUM HUBBARD L IS ', Hubbard_lmax
         if (Hubbard_lmax.eq.-1) call errore                            &
     &        ('setup','lda_plus_u calculation but Hubbard_l not set',1)
      end if
      l = 2 * Hubbard_lmax + 1
      allocate(ns(nat,nspin,l,l))
      step_pen=step_pen_
      A_pen=A_pen_
      sigma_pen=sigma_pen_
      alpha_pen=alpha_pen_
      return
      end subroutine ldaU_init
!
!-----------------------------------------------------------------------
integer function set_Hubbard_l(psd) result (hubbard_l)
!-----------------------------------------------------------------------
!
implicit none
character*3 :: psd
!
! TRANSITION METALS
!
if (psd.eq.'V'  .or. psd.eq.'Cr' .or. psd .eq.'Mn' .or. psd.eq.'Fe' .or. &
    psd.eq.'Co' .or. psd.eq.'Ni' .or. psd .eq.'Cu'.or. psd .eq.'Fe1'.or. &
    psd .eq.'Fe2' ) then
    hubbard_l = 2
!
! RARE EARTHS
!
elseif (psd .eq.'Ce') then
   hubbard_l =  3
!
! OTHER ELEMENTS
!
elseif (psd .eq.'H') then
   hubbard_l =  0
elseif (psd .eq.'O') then
   hubbard_l = 1
else
   hubbard_l = -1
   call errore ('set_Hubbard_l','pseudopotential not yet inserted', 1)
endif
return
end function set_Hubbard_l
!
!-----------------------------------------------------------------------
      subroutine new_ns(c,eigr,betae,hpsi,hpsi_pen,forceh)
!-----------------------------------------------------------------------
!
! This routine computes the on site occupation numbers of the Hubbard ions.
! It also calculates the contribution of the Hubbard Hamiltonian to the
! electronic potential and to the forces acting on ions.
!
      use control_flags,      ONLY: tfor, tprnfor
      use kinds,              ONLY: DP        
      use ions_base,          only: na, nat, nsp
      use gvecw,              only: ngw
      use gvect, only: gstart
      USE uspp,               ONLY: nhsa=>nkb
      USE uspp_param,         ONLY: upf
      use electrons_base,     only: nspin, n => nbsp, nx => nbspx, ispin, f
      USE ldaU_cp,            ONLY: Hubbard_U, Hubbard_l
      USE ldaU_cp,            ONLY: n_atomic_wfc, ns, e_hubbard
      USE step_penalty,       ONLY: E_pen, A_pen, sigma_pen, alpha_pen
      USE step_penalty,       ONLY: step_pen
      USE dspev_module,       only: dspev_drv
      USE mp_global,       only: nbgrp
!
      implicit none
#ifdef __PARA
      include 'mpif.h'
#endif
      integer, parameter :: ldmx = 7
      complex(DP), intent(in) :: c(ngw,nx), eigr(ngw,nat),      &
     &                               betae(ngw,nhsa)
      complex(DP), intent(out) :: hpsi(ngw,nx), hpsi_pen(ngw,nx)
      real(DP) forceh(3,nat), force_pen(3,nat)
!
      complex(DP), allocatable:: wfc(:,:), swfc(:,:),dphi(:,:,:),   &
     &                               spsi(:,:)
      real(DP), allocatable   :: becwfc(:,:), bp(:,:),              &
     &                               dbp(:,:,:), wdb(:,:,:)
      real(DP), allocatable   :: dns(:,:,:,:), proj(:,:)
      real(DP), allocatable   :: lambda(:), f1(:), vet(:,:)
      real(DP)                :: somma, ntot, nsum,   &
     &                           nsuma, x_value, g_value, step_value
      integer is, ia, iat, nb, isp, l, m, m1, m2, k, i, counter, err, ig
      integer iv, jv, inl, jnl,alpha,alpha_a,alpha_s,ipol
      integer, allocatable ::  offset (:,:)
      complex(DP) :: tempsi
!
      if( nbgrp > 1 ) &
         call errore(' new_ns ', ' parallelization over bands not yet implemented ', 1 )
!
      allocate(f1 (ldmx*ldmx), vet (ldmx,ldmx), lambda(ldmx) )
      allocate(wfc(ngw,n_atomic_wfc))
      allocate(becwfc(nhsa,n_atomic_wfc))
      allocate(swfc(ngw,n_atomic_wfc))
      allocate(proj(n,n_atomic_wfc))
      allocate(offset(nsp,nat))
!
! calculate proj = <c|S|wfc>
!
      CALL projwfc_hub( c, nx, eigr, betae, n, n_atomic_wfc,            &
     & wfc, becwfc, swfc, proj ) !#@
!
      counter = 0
      do is = 1, nsp
         do ia = 1, na(is)
            do i = 1, upf(is)%nwfc
               l = upf(is)%lchi(i)
               if (l.eq.Hubbard_l(is)) offset (is,ia) = counter
               counter = counter + 2 * l + 1
            end do
         end do
      end do
      if (counter.ne.n_atomic_wfc) call errore ('new_ns','nstart<>counter',1)
      ns(:,:,:,:) = 0.d0
      iat = 0
      do is = 1,nsp
         do ia = 1,na(is)
            iat = iat + 1
            if (Hubbard_U(is).ne.0.d0) then 
               k = offset(is,ia)
               do m1 = 1, 2*Hubbard_l(is) + 1
                  do m2 = m1, 2*Hubbard_l(is) + 1
                     do i = 1,n
!                      write(6,*) i,ispin(i),f(i)
                      ns(iat,ispin(i),m1,m2) = ns(iat,ispin(i),m1,m2) + &
     &                               f(i) * proj(i,k+m2) * proj(i,k+m1)
                     end do
!                     ns(iat,:,m2,m1) = ns(iat,:,m1,m2)
                     ns(iat,1,m2,m1) = ns(iat,1,m1,m2)
                     ns(iat,2,m2,m1) = ns(iat,2,m1,m2)
                  end do
               end do
            end if
         end do
      end do
      if (nspin.eq.1) ns = 0.5d0 * ns
! Contributions to total energy
      e_hubbard = 0.d0
      iat = 0
      do is = 1,nsp
         do ia = 1,na(is)
            iat=iat + 1
            if (Hubbard_U(is).ne.0.d0) then
                k = offset(is,ia)
                do isp = 1,nspin
                   do m1 = 1, 2*Hubbard_l(is) + 1
                     e_hubbard = e_hubbard + 0.5d0 * Hubbard_U(is) *    &
     &                           ns(iat,isp,m1,m1)
                     do m2 = 1, 2*Hubbard_l(is) + 1
                        e_hubbard = e_hubbard - 0.5d0 * Hubbard_U(is) * &
     &                              ns(iat,isp,m1,m2) * ns(iat,isp,m2,m1)
                     end do
                   end do
                end do
             end if
         end do
       end do
       if (nspin.eq.1) e_hubbard = 2.d0*e_hubbard
!       if (nspin.eq.1) e_lambda = 2.d0*e_lambda
!
!      Calculate the potential and forces on wavefunctions due to U
!
      hpsi(:,:)=(0.d0,0.d0)
      iat=0
      do is = 1, nsp
         do ia=1, na(is)
            iat = iat + 1
            if (Hubbard_U(is).ne.0.d0) then
               do i=1, n
                  do m1 = 1, 2 * Hubbard_l(is) + 1
                     tempsi = proj (i,offset(is,ia)+m1)
                     do m2 = 1, 2 * Hubbard_l(is) + 1
                        tempsi = tempsi - 2.d0 * ns(iat,ispin(i),m1,m2)*&
     &                                proj (i,offset(is,ia)+m2)
                     enddo
                     tempsi = tempsi * Hubbard_U(is)/2.d0*f(i)
                     call zaxpy (ngw,tempsi,swfc(1,offset(is,ia)+m1),1, &
     &                           hpsi(1,i),1)
                  enddo
               enddo
            endif
         enddo
      enddo
!
!      Calculate the potential and energy due to constraint
!
      hpsi_pen(:,:)=0.d0

      if (step_pen) then
         iat=0
         E_pen=0
         do is = 1,nsp
            do ia = 1, na(is)
               nsuma = 0.d0
               iat = iat + 1
              if (Hubbard_U(is).ne.0.d0) then
               do isp = 1, nspin
                  if (A_pen(iat,isp).ne.0.0) then
                     k = 0
                     f1=0.0
                     do m1 = 1, 2 * Hubbard_l(is) + 1
                        do m2 = m1, 2 * Hubbard_l(is) + 1
                           k = k + 1
                           f1 (k) = ns (iat, isp, m2, m1)
                        enddo
                     enddo
                     CALL dspev_drv( 'V', 'L', 2 * Hubbard_l(is) + 1, f1, lambda, vet, ldmx  )
                     x_value=alpha_pen(iat)-lambda(2*Hubbard_l(is)+1)
                     call stepfn(A_pen(iat,isp),sigma_pen(iat),x_value, &
     &                           g_value,step_value)
                     do i=1, n
                        do m1 = 1, 2 * Hubbard_l(is) + 1
                           do m2 = 1, 2 * Hubbard_l(is) + 1
                              tempsi=-1.d0*f(i)*proj (i,offset(is,ia)+m1)* &
     &                       vet(m1,2*Hubbard_l(is)+1)*vet(m2,2*Hubbard_l(is)+1)*g_value
                              call ZAXPY (ngw,tempsi,swfc(1,offset(is,ia)+ &
     &                           m2),1,hpsi_pen(1,i),1)
                           enddo
                        enddo
                     end do
                     E_pen=E_pen+step_value
                  end if
               enddo
              endif
            enddo
         enddo
      endif

!
! Calculate the contribution to forces on ions due to U and constraint
!
      forceh=0.d0

      force_pen=0.d0

      if ((tfor).or.(tprnfor)) then
        allocate (bp(nhsa,n), dbp(nhsa,n,3), wdb(nhsa,n_atomic_wfc,3))
        allocate(dns(nat,nspin,ldmx,ldmx))
        allocate (spsi(ngw,n))
!
        call nlsm1 (n,1,nsp,eigr,c,bp)
        call s_wfc(n,bp,betae,c,spsi)
        call nlsm2_bgrp( ngw, nhsa, eigr, c, dbp, nx, n )
        call nlsm2_bgrp( ngw, nhsa, eigr, wfc, wdb, n_atomic_wfc, n_atomic_wfc )
!
        alpha=0
        do alpha_s = 1, nsp
         do alpha_a = 1, na(alpha_s)
            alpha=alpha+1
            do ipol = 1,3
               call dndtau(alpha_a,alpha_s,becwfc,spsi,bp,dbp,wdb,      &
     &                    offset,c,wfc,eigr,betae,proj,ipol,dns)
               iat=0
               do is = 1, nsp
                  do ia=1, na(is)
                     iat = iat + 1
                     if (Hubbard_U(is).ne.0.d0) then
                        do isp = 1,nspin
                           do m2 = 1,2*Hubbard_l(is) + 1
                              forceh(ipol,alpha) = forceh(ipol,alpha) -            &
     &                        Hubbard_U(is) * 0.5d0 * dns(iat,isp,m2,m2)
                              do m1 = 1,2*Hubbard_l(is) + 1
                                 forceh(ipol,alpha) = forceh(ipol,alpha) +         &
     &                           Hubbard_U(is)*ns(iat,isp,m2,m1)*       &
     &                           dns(iat,isp,m1,m2)
                              end do
                           end do
                        end do
                     end if
! Occupation constraint add here
                     if (step_pen) then
                        do isp = 1, nspin
                           if ((A_pen(iat,isp).ne.0.0).and.           &
      &                       (Hubbard_U(is).ne.0.d0)) then
                              k = 0
                              f1=0.0
                              do m1 = 1, 2 * Hubbard_l(is) + 1
                                 do m2 = m1, 2 * Hubbard_l(is) + 1
                                    k = k + 1
                                    f1 (k) = ns (iat, isp, m2, m1)
                                 enddo
                              enddo
                              CALL dspev_drv( 'V', 'L', 2 * Hubbard_l(is) + 1, f1, lambda, vet, ldmx  )
                              x_value=alpha_pen(iat)-lambda(2*Hubbard_l(is)+1)
                              call stepfn(A_pen(iat,isp),sigma_pen(iat),x_value,g_value,&
     &                             step_value)
                              do m1 = 1,2*Hubbard_l(is) + 1
                                 do m2 = 1,2*Hubbard_l(is) + 1
                                    force_pen(ipol,alpha) =                &
     &                              force_pen(ipol,alpha) +                &
     &                              g_value * dns(iat,isp,m1,m2)           &
     &                              *vet(m1,2*Hubbard_l(is)+1)*vet(m2,2*Hubbard_l(is)+1)
                                 end do
                              end do
                           endif
                        end do
                     end if
                  end do
               end do
            end do
         end do
        end do
        if (nspin.eq.1) then
           forceh = 2.d0 * forceh
           force_pen=2.d0 * force_pen
        end if

        forceh = forceh + force_pen
!
        deallocate ( spsi, dns, bp, dbp, wdb)
      end if
      deallocate ( wfc, becwfc, proj, offset, swfc)
      deallocate ( f1, vet, lambda )
!
      return
      end subroutine new_ns
!
!-----------------------------------------------------------------------
      subroutine write_ns
!-----------------------------------------------------------------------
!
! This routine computes the occupation numbers on atomic orbitals.
! It also write the occupation number in the output file.
!
      USE kinds,            only: DP
      USE constants,        ONLY: autoev
      use electrons_base,   only: nspin
      use electrons_base,   only: n => nbsp 
      use ions_base,        only: na, nat, nsp
      use gvecw,            only: ngw
      USE ldaU_cp,          ONLY: Hubbard_U, Hubbard_l
      USE ldaU_cp,          ONLY: n_atomic_wfc, ns, e_hubbard
      USE ldaU_cp,          ONLY: Hubbard_lmax
      use dspev_module,     only : dspev_drv
      USE step_penalty,     ONLY: step_pen, A_pen, sigma_pen, alpha_pen

      implicit none

  integer :: is, isp, ia, m1, m2, ldim, iat, err, k
! cpunter on atoms type
! counter on spin component
! counter on atoms
! counter on wavefn
! counters on d components
  integer, parameter :: ldmx = 7
  real(DP), allocatable   :: ftemp1(:), ftemp2(:), f1 (:), vet (:,:)

  real(DP) :: lambda (ldmx), nsum, nsuma
  write (*,*) 'enter write_ns'

  if ( 2 * Hubbard_lmax + 1 .gt. ldmx ) &
       call errore ('write_ns', 'ldmx is too small', 1)

  if (step_pen) then
     do isp=1,nspin
        write (6,'(6(a,i2,a,i2,a,f8.4,6x))') &
        ('A_pen(',is,',',isp,') =', A_pen(is,isp),is=1,nsp)
     enddo
     write (6,'(6(a,i2,a,f8.4,6x))') &
           ('sigma_pen(',is,') =', sigma_pen(is), is=1,nsp)
     write (6,'(6(a,i2,a,f8.4,6x))') &
        ('alpha_pen(',is,') =', alpha_pen(is), is=1,nsp)
  endif

  write (6,'(6(a,i2,a,f8.4,6x))') &
        ('U(',is,') =', Hubbard_U(is) * autoev, is=1,nsp)
!  write (6,'(6(a,i2,a,f8.4,6x))') &
!        ('alpha(',is,') =', Hubbard_alpha(is) * autoev, is=1,nsp)
      nsum = 0.d0
      allocate(ftemp1(ldmx), ftemp2(ldmx), f1(ldmx*ldmx), vet(ldmx,ldmx) )
      iat = 0
      write(6,*) 'nsp',nsp
      do is = 1,nsp
         do ia = 1, na(is)
            nsuma = 0.d0
            iat = iat + 1
!        if (iat.eq.1) then
            if (Hubbard_U(is).ne.0.d0) then
               do isp = 1, nspin
                   do m1 = 1, 2 * Hubbard_l(is) + 1
                      nsuma = nsuma + ns (iat, isp, m1, m1)
                   end do
               end do
               if (nspin.eq.1) nsuma = 2.d0 * nsuma
               write(6,'(a,1x,i2,2x,a,f11.7)') 'atom', iat,              &
     &                                      ' Tr[ns(na)]= ',nsuma
               nsum = nsum + nsuma
!
               do isp = 1, nspin

                  k = 0
                  do m1 = 1, 2 * Hubbard_l(is) + 1
                     do m2 = m1, 2 * Hubbard_l(is) + 1
                        k = k + 1
                        f1 ( k ) = ns (iat, isp, m2, m1)
                     enddo
                  enddo

                  CALL dspev_drv( 'V', 'L', 2 * Hubbard_l(is) + 1, f1, lambda, vet, ldmx  )

                  write(6,'(a,1x,i2,2x,a,1x,i2)') 'atom', iat, 'spin', isp
                  write(6,'(a,7f10.7)') 'eigenvalues: ',(lambda(m1),m1=1,&
     &                                2 * Hubbard_l(is) + 1)
                  write(6,*) 'eigenvectors'
                  do m2 = 1, 2*Hubbard_l(is)+1
                     write(6,'(i2,2x,7(f10.7,1x))') m2,(real(vet(m1,m2)),&
     &                            m1=1,2 * Hubbard_l(is) + 1)
                  end do
                  write(6,*) 'occupations'
                  do m1 = 1, 2*Hubbard_l(is)+1
                     write (6,'(7(f6.3,1x))') (ns(iat,isp,m1,m2),m2=1,    &
     &                     2*Hubbard_l(is)+1)
                  end do
               end do
            end if
!        end if
         end do
      end do
      deallocate ( ftemp1, ftemp2,f1, vet )
      return
      end subroutine write_ns
!
!-------------------------------------------------------------------------
      subroutine dndtau(alpha_a,alpha_s,becwfc,spsi,bp,dbp,wdb,         &
     &                  offset,c,wfc,                                   &
     &                  eigr,betae,                                     &
     &                  proj,ipol,dns)
!-----------------------------------------------------------------------
!
! This routine computes the derivative of the ns with respect to the ionic
! displacement tau(alpha,ipol) used to obtain the Hubbard contribution to the
! atomic forces.
!
      use ions_base, only: na, nat, nsp
      use gvecw, only: ngw
      use electrons_base, only: nspin, n => nbsp, nx => nbspx, ispin, f
      USE uspp,           ONLY: nhsa=>nkb
      USE ldaU_cp,        ONLY: Hubbard_U, Hubbard_l
      USE ldaU_cp,        ONLY: n_atomic_wfc, ns
      USE kinds,          ONLY: DP
!
      implicit none
      integer, parameter :: ldmx = 7
      integer ibnd,is,i,ia,counter, m1,m2, l, iat, alpha, ldim
! input
      integer,      intent(in) :: offset(nsp,nat)
      integer,      intent(in) :: alpha_a,alpha_s,ipol
      real(DP),     intent(in) :: wfc(ngw,n_atomic_wfc),  c(2,ngw,nx),  &
     &                            eigr(2,ngw,nat),betae(2,ngw,nhsa),    &
     &                            becwfc(nhsa,n_atomic_wfc),            &
     &                            bp(nhsa,n), dbp(nhsa,n,3), wdb(nhsa,n_atomic_wfc,3)
      real(DP),     intent(in) :: proj(n,n_atomic_wfc)
      complex (DP), intent(in) :: spsi(ngw,n)
! output
      real (DP),   intent(out) :: dns(nat,nspin,ldmx,ldmx)
!
!     dns !derivative of ns(:,:,:,:) w.r.t. tau
!
      real (DP),   allocatable :: dproj(:,:)
!
!     dproj(n,n_atomic_wfc) ! derivative of proj(:,:) w.r.t. tau 
!
      allocate (dproj(n,n_atomic_wfc) )
!
      dns(:,:,:,:) = 0.d0
!
          call dprojdtau(c,wfc,becwfc,spsi,bp,dbp,wdb,eigr,alpha_a,     &
     &                   alpha_s,ipol,offset(alpha_s,alpha_a),dproj)
!
! compute the derivative of occupation numbers (the quantities dn(m1,m2))
! of the atomic orbitals. They are real quantities as well as n(m1,m2)
!
      iat=0
      do is=1,nsp
         do ia = 1,na(is)
            iat=iat+1
            if (Hubbard_U(is).ne.0.d0) then
               ldim = 2*Hubbard_l(is) + 1
               do m1 = 1, ldim
                  do m2 = m1, ldim
                     do ibnd = 1,n
                        dns(iat,ispin(ibnd),m1,m2) =                    &
     &                  dns(iat,ispin(ibnd),m1,m2) +                    &
     &                   f(ibnd)*REAL(  proj(ibnd,offset(is,ia)+m1) *   &
     &                   (dproj(ibnd,offset(is,ia)+m2))  +              &
     &                         dproj(ibnd,offset(is,ia)+m1)  *          &
     &                         (proj(ibnd,offset(is,ia)+m2)) )
                     end do
                     dns(iat,:,m2,m1) = dns(iat,:,m1,m2)
                  end do
               end do
            end if
         end do
      end do
!
      deallocate (dproj)
      return
      end subroutine dndtau
!
!
!-----------------------------------------------------------------------
      subroutine dprojdtau(c,wfc,becwfc,spsi,bp,dbp,wdb,eigr,alpha_a,    &
     &                     alpha_s,ipol,offset,dproj)
!-----------------------------------------------------------------------
!
! This routine computes the first derivative of the projection
! <\fi^{at}_{I,m1}|S|\psi_{k,v,s}> with respect to the atomic displacement
! u(alpha,ipol) (we remember that ns_{I,s,m1,m2} = \sum_{k,v}
! f_{kv} <\fi^{at}_{I,m1}|S|\psi_{k,v,s}><\psi_{k,v,s}|S|\fi^{at}_{I,m2}>)
!
      use ions_base, only: na, nat
      use gvecw, only: ngw
      use gvect, only: g, gstart
      use electrons_base, only: n => nbsp, nx => nbspx
!      use gvec
!      use constants
      USE uspp,           ONLY: nhsa=>nkb, qq
      USE ldaU_cp,        ONLY: Hubbard_U, Hubbard_l
      USE ldaU_cp,        ONLY: n_atomic_wfc
      use cell_base,      ONLY: tpiba
      USE uspp_param,     only: nh, ish
      use mp_global,      only: intra_bgrp_comm
      use mp,             only: mp_sum
      USE kinds,          ONLY: DP
!
       implicit none
       integer, parameter :: ldmx = 7
       integer alpha_a, alpha_s,ipol, offset
! input: the displaced atom
! input: the component of displacement
! input: the offset of the wfcs of the atom "alpha_a,alpha_s"
       complex (DP), intent(in) :: spsi(ngw,n),                     &
     &                  c(ngw,nx), eigr(ngw,nat)
! input: the atomic wfc
! input: S|evc>
       real(DP), intent(in) ::becwfc(nhsa,n_atomic_wfc),            &
     &                            wfc(2,ngw,n_atomic_wfc),              &
     &            bp(nhsa,n), dbp(nhsa,n,3), wdb(nhsa,n_atomic_wfc,3)
       real(DP), intent(out) :: dproj(n,n_atomic_wfc)
! output: the derivative of the projection
!
      integer i,ig,m1,ibnd,iwf,ia,is,iv,jv,ldim,alpha,l,m,k,inl
!
      real(kind=8), allocatable :: gk(:)
!
      complex (DP), allocatable :: dwfc(:,:)
      real (DP), allocatable :: betapsi(:,:),                       &
     &                              dbetapsi(:,:),                      &
     &                              wfcbeta(:,:),wfcdbeta(:,:),temp(:)
!      dwfc(ngw,ldmx),             ! the derivative of the atomic d wfc
!      betapsi(nh,n),              ! <beta|evc>
!      dbetapsi(nh,n),             ! <dbeta|evc>
!      wfcbeta(n_atomic_wfc,nh),   ! <wfc|beta>
!      wfcdbeta(n_atomic_wfc,nh),  ! <wfc|dbeta>
      ldim = 2 * Hubbard_l(alpha_s) + 1
      allocate ( dwfc(ngw,ldmx),betapsi(nh(alpha_s),n))
      allocate ( dbetapsi(nh(alpha_s),n),                               &
     &           wfcbeta(n_atomic_wfc,nh(alpha_s)))
      allocate (wfcdbeta(n_atomic_wfc,nh(alpha_s)) )
      dproj(:,:)=0.d0
!
! At first the derivative of the atomic wfc is computed
!
!
      allocate(gk(ngw))
      allocate(temp(ngw))
!
      if (Hubbard_U(alpha_s).ne.0.d0) then
!
         do ig=1,ngw
            gk(ig)=g(ipol,ig)*tpiba 
!
            do m1=1,ldim
                  dwfc(ig,m1) = CMPLX (gk(ig)*wfc(2,ig,offset+m1),      &
     &                  -1*gk(ig)*wfc(1,ig,offset+m1), kind=dp )
            end do
         end do
!
         do ibnd=1,n
            do m1=1,ldim
               temp(:)=real(conjg(dwfc(:,m1))*spsi(:,ibnd))
               dproj(ibnd,offset+m1)=2.d0*SUM(temp) 
               if (gstart==2) dproj(ibnd,offset+m1)=dproj(ibnd,offset+m1)-temp(1)
            end do
         end do
         call mp_sum( dproj, intra_bgrp_comm )
      end if
      do iv=1,nh(alpha_s)
         inl=ish(alpha_s)+(iv-1)*na(alpha_s)+alpha_a
         do i=1,n
            betapsi(iv,i)=bp(inl,i)
            dbetapsi(iv,i)=dbp(inl,i,ipol)
         end do
         do m=1,n_atomic_wfc
!                 do m1=1,2**Hubbard_l(is) + 1
            wfcbeta(m,iv)=becwfc(inl,m)
            wfcdbeta(m,iv)=wdb(inl,m,ipol)
         end do
      end do
      do ibnd=1,n
         do iv=1,nh(alpha_s)
            do jv=1,nh(alpha_s)
               do m=1,n_atomic_wfc
!                       do m1=1,2**Hubbard_l(is) + 1
                  dproj(ibnd,m) =                                       &
     &                        dproj(ibnd,m) + qq(iv,jv,alpha_s) *       &
     &                         ( wfcdbeta(m,iv)*betapsi(jv,ibnd) +      &
     &                           wfcbeta(m,iv)*dbetapsi(jv,ibnd) )
               end do
            end do
         end do
      end do
      deallocate(temp, gk)
      deallocate (betapsi)
      deallocate (dwfc)
      deallocate (dbetapsi)
      deallocate (wfcbeta)
      deallocate (wfcdbeta)
      return
      end subroutine dprojdtau
!
!
!-----------------------------------------------------------------------
      subroutine stepfn(A,sigma,x_value,g_value,step_value)
!-----------------------------------------------------------------------
!     This subroutine calculates the value of the gaussian and step
!     functions with a given x_value. A and sigma are given in the
!     input file. ... to be used in occupation_constraint...
!
      USE constants, ONLY : pi
      implicit none
      real(kind=8) A, sigma, x_value, g_value, step_value
      real(kind=8) x
      integer i
      step_value=0.0d0
      g_value=0.0d0
!
      do i=1,100000
         x=x_value + (i-100000)/100000.0d0*(x_value + 5.d0*sigma)
!
! Integrate from 5 sigma before the x_value
!
         g_value=A*dexp(-x*x/(2*sigma*sigma))/(sigma*dsqrt(2*pi))
!         write(6,*) 'step', step_value,'g',g_value
!         if (g_value.le.0.0) g_value=0.0
         if ((x_value+5*sigma).ge.0.0d0) then
         step_value=step_value+g_value/100000.0d0*(x_value+5.d0*sigma)
         end if
      end do
      return
      end subroutine stepfn
!
!-----------------------------------------------------------------------
      SUBROUTINE projwfc_hub( c, nx, eigr, betae, n, n_atomic_wfc,  &
     & wfc, becwfc, swfc, proj )
!-----------------------------------------------------------------------
      !
      ! Projection on atomic wavefunctions
      ! Atomic wavefunctions are not orthogonalized
      !
      USE kinds,              ONLY: DP
      USE constants,          ONLY: autoev
      USE io_global,          ONLY: stdout
      USE mp_global,          ONLY: intra_bgrp_comm
      USE mp,                 ONLY: mp_sum
      USE gvecw,              ONLY: ngw
      USE gvect, ONLY: gstart
      USE ions_base,          ONLY: nsp, na, nat
      USE uspp,               ONLY: nhsa => nkb
!
      IMPLICIT NONE
      INTEGER,     INTENT(IN) :: nx, n, n_atomic_wfc
      COMPLEX(DP), INTENT(IN) :: c( ngw, nx ), eigr(ngw,nat), betae(ngw,nhsa)
!
      COMPLEX(DP), INTENT(OUT):: wfc(ngw,n_atomic_wfc),    &
     & swfc( ngw, n_atomic_wfc )
      real(DP), intent(out):: becwfc(nhsa,n_atomic_wfc), proj(n,n_atomic_wfc)
      REAL(DP),    ALLOCATABLE :: temp(:)
      REAL(DP)                 :: somma
      INTEGER :: is, ia, nb, l, m, k, i
      !
      ! calculate number of atomic states
      !
      !
      IF ( n_atomic_wfc .EQ. 0 ) RETURN
      !
      !
      ! calculate wfc = atomic states
      !
      CALL atomic_wfc_northo( eigr, n_atomic_wfc, wfc )
      !
      ! calculate bec = <beta|wfc>
      !
      CALL nlsm1( n_atomic_wfc, 1, nsp, eigr, wfc, becwfc )
      !
      ! calculate swfc = S|wfc>
      !
      CALL s_wfc( n_atomic_wfc, becwfc, betae, wfc, swfc )
      !
      ! calculate proj = <c|S|wfc>
      !
      ALLOCATE(temp(ngw))
      DO m=1,n
         DO l=1,n_atomic_wfc
            temp(:)=DBLE(CONJG(c(:,m))*swfc(:,l)) !#@@@
            proj(m,l)=2.d0*SUM(temp)
            IF (gstart == 2) proj(m,l)=proj(m,l)-temp(1)
         END DO
      END DO
      DEALLOCATE(temp)
      CALL mp_sum( proj, intra_bgrp_comm )
!
      RETURN
      END SUBROUTINE projwfc_hub
!
!-----------------------------------------------------------------------
      SUBROUTINE atomic_wfc_northo( eigr, n_atomic_wfc, wfc )
!-----------------------------------------------------------------------
!
! Compute atomic wavefunctions in G-space
! Atomic wavefunctions not orthogonalized
!
      USE kinds,              ONLY: DP
      USE gvecw,              ONLY: ngw
      USE gvect, ONLY: gstart, gg, g
      USE ions_base,          ONLY: nsp, na, nat
      USE cell_base,          ONLY: tpiba, omega !#@@@
      USE atom,               ONLY: rgrid
      USE uspp_param,         ONLY: upf
!#@@@@
      USE constants,          ONLY: fpi
!#@@@@
!
      IMPLICIT NONE
      INTEGER,     INTENT(in) :: n_atomic_wfc
      COMPLEX(DP), INTENT(in) :: eigr( ngw, nat )
      COMPLEX(DP), INTENT(out):: wfc( ngw, n_atomic_wfc )
!
      INTEGER :: natwfc, ndm, is, ia, ir, nb, l, m, lm, i, lmax_wfc, isa
      REAL(DP), ALLOCATABLE ::  ylm(:,:), q(:), jl(:), vchi(:), chiq(:)

      IF( .NOT. ALLOCATED( rgrid ) ) &
         CALL errore( ' atomic_wfc_northo ', ' rgrid not allocated ', 1 )
!
! calculate max angular momentum required in wavefunctions
!
      lmax_wfc=-1
      DO is = 1,nsp
         lmax_wfc = MAX ( lmax_wfc, MAXVAL (upf(is)%lchi(1:upf(is)%nwfc) ) )
      ENDDO
      !
      ALLOCATE(ylm(ngw,(lmax_wfc+1)**2))
      !
      CALL ylmr2 ((lmax_wfc+1)**2, ngw, g, gg, ylm)
      ndm = MAXVAL(rgrid(1:nsp)%mesh)
      !
      ALLOCATE(jl(ndm), vchi(ndm))
      ALLOCATE(q(ngw), chiq(ngw))
!
      DO i=1,ngw
         q(i) = SQRT(gg(i))*tpiba
      END DO
!
      natwfc=0
      isa   = 0
      DO is=1,nsp
         !
         !   radial fourier transform of the chi functions
         !   NOTA BENE: chi is r times the radial part of the atomic wavefunction
         !
         DO ia = 1 + isa, na(is) + isa
            DO nb = 1,upf(is)%nwfc
               l = upf(is)%lchi(nb)
               DO i=1,ngw
                  CALL sph_bes (rgrid(is)%mesh, rgrid(is)%r, q(i), l, jl)
                  DO ir=1,rgrid(is)%mesh
                     vchi(ir) = upf(is)%chi(ir,nb)*rgrid(is)%r(ir)*jl(ir)
                  ENDDO
                  CALL simpson_cp90(rgrid(is)%mesh,vchi,rgrid(is)%rab,chiq(i))
               ENDDO
               !
               !   multiply by angular part and structure factor
               !   NOTA BENE: the factor i^l MUST be present!!!
               !
               DO m = 1,2*l+1
                  lm = l**2 + m
                  !DO ia = 1 + isa, na(is) + isa
                  natwfc = natwfc + 1
                  wfc(:,natwfc) = (0.d0,1.d0)**l * eigr(:,ia)* ylm(:,lm)*chiq(:)
                  !ENDDO
               ENDDO
            ENDDO
         ENDDO
         isa = isa + na(is)
      ENDDO
!
      IF (natwfc.NE.n_atomic_wfc)                                       &
     &     CALL errore('atomic_wfc','unexpected error',natwfc)
!
!#@@@@
      do i = 1,n_atomic_wfc
        call dscal(2*ngw,fpi/sqrt(omega),wfc(1,i),1)
      end do
!#@@@@
      DEALLOCATE(q, chiq, vchi, jl, ylm)
!
      RETURN
      END SUBROUTINE atomic_wfc_northo