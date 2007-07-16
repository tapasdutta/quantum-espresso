!
! Copyright (C) 2004 PWSCF group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
module ld1_parameters
   integer, parameter :: &
           ncmax1=10,    & ! the maximum configuration number
           nwfsx=10,     & ! the maximum number of pseudo wavefunctions
           nwfx=35,      & ! the maximum number of wavefunctions
           lmaxx=5         ! the maximum angular momentum of wfcs (for PAW)
end module ld1_parameters
