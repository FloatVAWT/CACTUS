MODULE strut

	! Strut geometry and loads outputs
        
        use util
        
        implicit none
        
        type StrutType
            integer :: NElem
            
            ! Strut element end locations
            real, allocatable :: SEx(:)
            real, allocatable :: SEy(:)
            real, allocatable :: SEz(:)
            ! Strut chord to radius at element ends
            real, allocatable :: CRe(:)
            ! Strut element center locations
            real, allocatable :: SCx(:)
            real, allocatable :: SCy(:)
            real, allocatable :: SCz(:)
            ! Strut element spanwise vector
            real, allocatable :: sx(:)
            real, allocatable :: sy(:)
            real, allocatable :: sz(:)
            ! Strut mean chord to radius and norm. area
            real, allocatable :: CRm(:)
            real, allocatable :: AreaR(:)
            ! Interference drag calc parameters
            real :: sthick  ! Strut thickness to chord ratio
            real :: tcS      ! Thickness to chord of the blade element at the strut-blade junction (first strut element)
            real :: tcE      ! Thickness to chord of the blade element at the strut-blade junction (last strut element)
            ! Blade and element indicies to which the strut connects (for interference drag calc)
            ! For struts that are attached to the rotor shaft at one end (not to another blade), set the appropriate BInd and EInd values to zero.
            ! BIndS, EIndS : first strut element
            ! BIndE, EIndE : last strut element 
            integer :: BIndS
            integer :: EIndS
            integer :: BIndE
            integer :: EIndE
            real :: LR      ! Strut length to radius ratio
            
            ! Current flow quantities at each element center
            real, allocatable :: ReStrut(:) 
            real, allocatable :: u(:) ! u velocity over Uinf
            real, allocatable :: v(:) ! v velocity over Uinf
            real, allocatable :: w(:) ! w velocity over Uinf
            real, allocatable :: ur(:) ! velocity mag over Uinf
            
            ! Current strut element coeffs (normalized by strut element scale parameters)
            real, allocatable :: Cd0(:)

            ! Current total strut output (nomalized by machine scale parameters)
            real :: CP  ! Power coefficient due to this strut
            real :: CTR ! Torque coefficient due to this strut
            real :: CFx ! Fx coefficient due to this strut
            real :: CFy ! Fy coefficient due to this strut
            real :: CFz ! Fz coefficient due to this strut
            
        end type
            
        type(StrutType), allocatable :: Struts(:)   
        
        integer :: NStrut ! number of struts
        
        real, parameter :: ReCrit=3.0e5
        real :: Cdpar   ! Additional strut parasitic interference drag coefficient based on "chord area" (chord squared)
        
        ! Current sum of output over all struts (nomalized by machine scale parameters)
        real :: CP_S  ! Power coefficient due to all struts
        real :: CTR_S ! Torque coefficient due to all struts
        real :: CFx_S ! Fx coefficient due to all struts
        real :: CFy_S ! Fy coefficient due to all struts
        real :: CFz_S ! Fz coefficient due to all struts
	

	CONTAINS


        SUBROUTINE strut_comp_cns(SInd,NElem)

            ! Constructor for the arrays for a strut component

            integer :: SInd, NElem
    
            Struts(SInd)%NElem=NElem
            allocate(Struts(SInd)%SEx(NElem+1))  
            allocate(Struts(SInd)%SEy(NElem+1)) 
            allocate(Struts(SInd)%SEz(NElem+1)) 
            allocate(Struts(SInd)%CRe(NElem+1))  
            allocate(Struts(SInd)%SCx(NElem))  
            allocate(Struts(SInd)%SCy(NElem)) 
            allocate(Struts(SInd)%SCz(NElem))
            allocate(Struts(SInd)%sx(NElem))  
            allocate(Struts(SInd)%sy(NElem)) 
            allocate(Struts(SInd)%sz(NElem))
            allocate(Struts(SInd)%CRm(NElem)) 
            allocate(Struts(SInd)%AreaR(NElem))
            allocate(Struts(SInd)%ReStrut(NElem)) 
            allocate(Struts(SInd)%u(NElem))
            allocate(Struts(SInd)%v(NElem))
            allocate(Struts(SInd)%w(NElem))
            allocate(Struts(SInd)%ur(NElem))
            allocate(Struts(SInd)%Cd0(NElem))         
                
        End SUBROUTINE

        
        SUBROUTINE RotateStrut(SInd,delt,nrx,nry,nrz,px,py,pz)

            integer :: SInd, j
            real :: delt,nrx,nry,nrz,px,py,pz 
            real :: vrx,vry,vrz,VMag

            ! Rotates data in strut arrays                                                    

            ! Strut end locations
            do j=1,Struts(SInd)%NElem+1  
                Call QuatRot(Struts(SInd)%SEx(j),Struts(SInd)%SEy(j),Struts(SInd)%SEz(j),delt,nrx,nry,nrz,px,py,pz,vrx,vry,vrz)
                Struts(SInd)%SEx(j)=vrx                                       
                Struts(SInd)%SEy(j)=vry                                                                                               
                Struts(SInd)%SEz(j)=vrz 
            end do 
            
            ! Strut element center locations
            do j=1,Struts(SInd)%NElem  
                Call QuatRot(Struts(SInd)%SCx(j),Struts(SInd)%SCy(j),Struts(SInd)%SCz(j),delt,nrx,nry,nrz,px,py,pz,vrx,vry,vrz)
                Struts(SInd)%SCx(j)=vrx                                       
                Struts(SInd)%SCy(j)=vry                                                                                               
                Struts(SInd)%SCz(j)=vrz 
            end do 
            
            ! Strut element spanwise vectors
            do j=1,Struts(SInd)%NElem  
                Call QuatRot(Struts(SInd)%sx(j),Struts(SInd)%sy(j),Struts(SInd)%sz(j),delt,nrx,nry,nrz,0.0,0.0,0.0,vrx,vry,vrz)
                ! Force normalize
                VMag=sqrt(vrx**2+vry**2+vrz**2) 
                Struts(SInd)%sx(j)=vrx/VMag                                       
                Struts(SInd)%sy(j)=vry/VMag                                                                                              
                Struts(SInd)%sz(j)=vrz/VMag  
            end do 
       
        End SUBROUTINE
                
        
        SUBROUTINE StrutElemCoeffs(SInd,EInd)  
        
            integer :: SInd, EInd
            real :: st, ReS, vs, AOS, pc
            real :: Cflam, Cdlam, Cfturb, Cdturb, Fblend
            
            ! Updates strut element coeffs for current flow states
            
            ! Calc sideslip angle
            vs=Struts(SInd)%u(EInd)*Struts(SInd)%sx(EInd)+Struts(SInd)%v(EInd)*Struts(SInd)%sy(EInd)+Struts(SInd)%w(EInd)*Struts(SInd)%sz(EInd)
            AOS=asin(vs/Struts(SInd)%ur(EInd)) 
            
            ! Effective section thickness and Re referenced to nominal flow path length rather than chord (p/c = 1/cos(AOS))
            ! Allows estimation at high element sideslip (azimuthal struts).
            pc=1.0/abs(cos(AOS))
            pc=min(pc,Struts(SInd)%LR/Struts(SInd)%CRm(EInd)) ! Limit p to strut length
            st=Struts(SInd)%sthick/pc
            ReS=Struts(SInd)%ReStrut(EInd)*pc
                                
            ! Calculate strut element profile drag
            Cflam = 2.66 / SQRT(ReS)  ! Laminar friction drag coefficient
            Cdlam = 2.0 * Cflam * (1 + st) + st**2 ! Laminar drag coefficient
            Cfturb = 0.044 / ReS**(1.0/6.0) ! Turbulent friction drag coefficient
            Cdturb = 2.0 * Cfturb * (1.0 + 2.0*st + 60.0*st**4) ! Turbulent drag coefficient
            Fblend = 0.5 * (1.0 + TANH((LOG10(ReS)-LOG10(ReCrit))/0.2)) ! Blending function for transition between laminar and turbulent drag 
            Struts(SInd)%Cd0(EInd) = (1.0-Fblend) * Cdlam + Fblend * Cdturb ! Profile drag coefficient

                
        End SUBROUTINE
	
End
