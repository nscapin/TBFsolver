! ************************************************************************************** !
!    TBFsolver - DNS turbulent bubbly flow solver
!    Copyright (C) 2018  University of Twente.
!
!    This program is free software: you can redistribute it and/or modify
!    it under the terms of the GNU General Public License as published by
!    the Free Software Foundation, either version 3 of the License, or
!    (at your option) any later version.
!
!    This program is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!    GNU General Public License for more details.
!
!    You should have received a copy of the GNU General Public License
!    along with this program.  If not, see <https://www.gnu.org/licenses/>.
! ************************************************************************************** !

module vectorFieldMod

	use scalarFieldMod
	
	implicit none
	
	
	! vectorField
	type, public :: vectorField
	
		!keep a pointer to grid
		type(grid), pointer :: ptrMesh_ => NULL() 
	
		type(scalarField) :: ux_, uy_, uz_

	end type
	
	private :: equatePeriodicBC

	public :: vectorFieldCTOR
	public :: decomposeFieldV
	public :: reconstructAndWriteFieldV
	public :: updateBoundariesV
	public :: copyBoundaryV
	
contains

!========================================================================================!
	subroutine vectorFieldCTOR(this,fileName,mesh,tpx,tpy,tpz,hd,initOpt,nFolder)
		class(vectorField), intent(out) :: this
		type(grid), intent(in), target :: mesh
		character(len=*), intent(in) :: fileName
		character(len=*), intent(in) :: tpx, tpy, tpz
		integer, intent(in) :: hd
		integer, intent(in) :: initOpt
		integer, intent(in), optional :: nFolder
		integer :: opt_nFolder
		
		this%ptrMesh_ => mesh
		
		!optional arguments
		if (present(nFolder)) then
			opt_nFolder = nFolder
		else
			opt_nFolder = 0
		end if

		call scalarFieldCTOR(this%ux_,fileName//'x',mesh,tpx,hd,initOpt,opt_nFolder)
		call scalarFieldCTOR(this%uy_,fileName//'y',mesh,tpy,hd,initOpt,opt_nFolder)
		call scalarFieldCTOR(this%uz_,fileName//'z',mesh,tpz,hd,initOpt,opt_nFolder)
		
		
	end subroutine
!========================================================================================!

!========================================================================================!
	subroutine decomposeFieldV(this,lf) 
        type(vectorField), intent(inout) :: this
        type(vectorField), intent(inout) :: lf 
        
        call decomposeField(this%ux_,lf%ux_)
        call decomposeField(this%uy_,lf%uy_)
        call decomposeField(this%uz_,lf%uz_)
        
	end subroutine
!========================================================================================!

!========================================================================================!
	subroutine reconstructAndWriteFieldV(this,lf,output_folder) 
        type(vectorField), intent(inout) :: this
        type(vectorField), intent(inout) :: lf 
        integer, intent(in) :: output_folder
        
        call reconstructAndWriteField(this%ux_,lf%ux_,output_folder)
        call reconstructAndWriteField(this%uy_,lf%uy_,output_folder)
        call reconstructAndWriteField(this%uz_,lf%uz_,output_folder)
        
	end subroutine
!========================================================================================!

!========================================================================================!
	subroutine updateBoundariesV(this) 
        type(vectorField), intent(inout) :: this
        
        call updateBoundaries(this%ux_)
        call updateBoundaries(this%uy_)
        call updateBoundaries(this%uz_)
        
        call equatePeriodicBC(this)
        
	end subroutine
!========================================================================================!

!========================================================================================!
    subroutine equatePeriodicBC(u)
    	type(vectorField), intent(inout) :: u
    	type(mpiControl), pointer :: mpic
    	integer, dimension(6) :: requests
    	integer, dimension(MPI_STATUS_SIZE,6) :: status
  		integer :: hd, ierror, tag1, tag2, tag3
        integer :: isx, jsx, ksx, iex, jex, kex
        integer :: isy, jsy, ksy, iey, jey, key
        integer :: isz, jsz, ksz, iez, jez, kez
  		
  		mpic => u%ptrMesh_%ptrMPIC_
  		hd = u%ux_%hd_
  		
  		tag1 = 0
  		tag2 = 1
  		tag3 = 2
  		
  		!ux indexes     
		isx = u%ux_%is_
		iex = u%ux_%ie_
		jsx = u%ux_%js_
		jex = u%ux_%je_
		ksx = u%ux_%ks_
		kex = u%ux_%ke_		
		
  		!uy indexes     
		isy = u%uy_%is_
		iey = u%uy_%ie_
		jsy = u%uy_%js_
		jey = u%uy_%je_
		ksy = u%uy_%ks_
		key = u%uy_%ke_	
		
  		!uz indexes     
		isz = u%uz_%is_
		iez = u%uz_%ie_
		jsz = u%uz_%js_
		jez = u%uz_%je_
		ksz = u%uz_%ks_
		kez = u%uz_%ke_	
		
		!equate ux bc
  		!recv from left and send to right boundary
  		call MPI_IRECV(u%ux_%f_(isx,jsx-hd,ksx-hd),1,u%ux_%xPatchEq_, mpic%leftNe_, &
  					   	tag1, mpic%cartComm_, requests(1), ierror)
        call MPI_ISSEND(u%ux_%f_(iex,jsx-hd,ksx-hd), 1, u%ux_%xPatchEq_, mpic%rightNe_, &
        			   	tag1, mpic%cartComm_, requests(2), ierror)
        			   			
		!equate uy bc
  		!recv from bottom and send to top boundary
  		call MPI_IRECV(u%uy_%f_(isy-hd,jsy,ksy-hd),1,u%uy_%yPatchEq_, mpic%bottomNe_, &
  					   tag2, mpic%cartComm_, requests(3), ierror)
        call MPI_ISSEND(u%uy_%f_(isy-hd,jey,ksy-hd), 1, u%uy_%yPatchEq_, mpic%topNe_, &
        			   tag2, mpic%cartComm_, requests(4), ierror) 
		
		!equate uz bc      
  		!recv from back and send to front boundary 
  		call MPI_IRECV(u%uz_%f_(isz-hd,jsz-hd,ksz),1,u%uz_%zPatchEq_, mpic%backNe_, &
  					   tag3, mpic%cartComm_, requests(5), ierror)
        call MPI_ISSEND(u%uz_%f_(isz-hd,jsz-hd,kez), 1, u%uz_%zPatchEq_, mpic%frontNe_, &
        			   tag3, mpic%cartComm_, requests(6), ierror) 
        
        call MPI_WAITALL(6, requests, status, ierror)
		
    	
    end subroutine
!========================================================================================!

!========================================================================================!
	subroutine copyBoundaryV(cpf,f)
		type(vectorField), intent(inout) :: cpf
		type(vectorField), intent(in) :: f
		
		call copyBoundary(cpf%ux_,f%ux_)
		call copyBoundary(cpf%uy_,f%uy_)
		call copyBoundary(cpf%uz_,f%uz_)
		
		
	end subroutine
!========================================================================================!



	
end module vectorFieldMod


	



