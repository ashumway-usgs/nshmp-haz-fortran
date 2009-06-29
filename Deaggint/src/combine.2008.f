c---- PSHA program combine.2008.f Aug 21 2008. Mod nov 21 2008 Mod june 29 2009
c June 29 2009 add several additional periods to C and D soil initial values (10hz 3hz 2sc)
c
c Nov 2008: add 0.75s, 3.0s, 4.0s, and 5.0s BC rock possibilities.
c --- a Fortran-95 code for WWW automatic seismic hazard deagg of 2008 update model.
c - - This program determines initial PGA or PSA values and writes scripts for running
c - - the various deaggregation programs for a specified site. One script
c - - is written,  for PGA or whatever specified SA 
c  --- A major improvement is the acceptance of any annual rate of exceedance (input)
c --- A second impr. compared to 2002 is the ability to run C&D soils in the west and
c--- 	hard-rock site condition in the east.
c---  A third impr. is fine-sampling of spatial grid in SF Bay region and southern CA.
c --- A fourth impr is availability of 3s response for WUS (BC only currently, July 2008)
c - -  
c -- Longer-period
c - - (3s 4s 5s ) PSA values may be of interest to tall-bldg studies
c - - Geographic deagg. is an option, invoked if calling script sets $geo=1
c - - Rate Interpolation is log-log (log SA, log rate). 
c - + - + Spatial interp is linear (not implementd aug 2008).
c
c Solaris compile:   f95 combine.2008.f iosubs.o -e -o combine.2008
c because of hard-wired directories this code cant be used on solaris. sorry.
c gldplone compile: 
c gfortran ./combine.2008.f -static -O iosubs.o -o combine.2008 -ffixed-line-length-none -ffpe-trap= 
c
c       try: combine.2008  Seattle 47.60639 -122.3308 4.04e-4 3  PID $loc $log 537.
c  The .000404 rate corresponds to 2475-year return time or the 2% in 50 yr probability. 
c  The 3 is a frequency or SA period index (3 for 5 hz). 
c PID is process ID, is needed to make file names unique to the process.
c - - - $loc, the location for input, is passed to program.
c --- vs30 is avg Vs in top 30 m. For CEUS, two allowed values, 760 and 2000
c --- for WUS, anything from about 150 m/s to 1100 m/s can be used.
c
c - - - Internal instructions open files in various deaggint subdirectories.
c - - - Also pass $log the location for logfile output and script output
c - - Diagnostic output is sent to /dev/null . could go to $3dea.log if
c - - problems are happening and you want to see where. 
c. Output scripts need to be made executable (chmod +x script.set*)
c - - Harmsen July, 2008
c --- Consolidation of several input files used in 2008 model to
c fewer but with equivalent hazard. California b-faults are much simplified,
c with 1 Char file and 1 GR file in the final set (Ned F sent 16 such files).
c-- outputs scripts for deaggregating PSA estimates for given lat, lon
c - - PSA (also PGA) value (g). Probs.  are not alway "within epsilon" of the target, so
c - - the script is designed to refine the values during deaggregation analysis.
c - - target annual rate, annrate, is input. The inversion accuracy
c - - is based on TOL (see below). Computed rate will be within TOL of ANN.
c - - There is a limit of 6 iterations though. If convergence rate is slower,
c - - and you demand higher accuracy, recompile rescale with higher itmax.
       parameter (nrates=6,nfiles=61)
c 2008 number of input files 61. These have been highly consolidated from initial
c set used for the 2008 NSHMP hazard runs. Try to reduce I/O to speed up process.
c Only a subset of them is needed at any site. 
c See vector mask, mask(i)=1 means include input file i, 0 means omit it.
c  
c Much of the below logic is to determine the appropriate subset, given a location.
c JUly 2008:  NMSZ cluster model is not included. 
c		Give 0.9 wt to 500yr, 0.1 wt to 1000yr no-cluster models
c
c Some attention is given to a slope of hazard curve estimate, related to
c SI, below. This may need work. SI was not reviewd for 2008.
c  
        integer nfil,ipr     !ipr=1 cumulative exc.; ipr=2 probability density at SA.
c the cumu. vs density is not going to be an option in first go-around of 2008 model
       character*2 frc
       character*7 geo(4)/'SUBnga','FXnga7c','FXnga7g','Xnga4'/
       character*80 loc,logdir
      real si/1.00/,pwr/1.0/
c si is a hazard curve slope, since it is applied to rates, it is inverse
c or reciprocal of s applied to SA or PGA.
c no longer confined to 6 annual rates; below are for the 2002-2003 Web Site
c      real pann(nrates)
      real ylat,xlon
      logical LXYIN_WUS, lxy
       character*12 pid,ch9*9
c 3hz is really 1/0.3 = 3.33 hz. 
       character*3 list(10)/'pga','10h','5hz','3hz','2hz','1hz',
     + '2sc','3sc','4sc','5sc'/
       character*4 cper(10)/'0.00','0.10','0.20','0.30','0.50','1.00',
     + '2.00','3.00','4.00','5.00'/
c 
c 
       character*3 tt/'.1p'/
       character*10 cord,ch8*8
       character*20 site/' '/
c input file is in one of 6 subdirectories, subd(). Which one? in_dir().
       character*3 subd(6)/'CA/','CU/','DE/','SU/','WU/','EX/'/
c Feb 2005: The *.robin programs get name from Robin McGuire,
c  who insists on using pr. density to
c obtain the deaggregation earthquakes. These are not going to be used in the
c first run version of 2008. We continue to deaggr. all exceedances in initial effort.
c 
       character*12 sfx(4)
       character*9 sfy(3)/'SUBD.2008','FLTH.2008','GRID.2008'/
c One Goal: deaggregate specific atten models. Show these on different
c plots. not available first try
c geo=1 means append script for geographic deagg.
c Pgm names for geographic deaggregations (?) not ready 2008
	real, dimension(nfiles):: wt
       integer*2, dimension(nfiles):: key,imap,in_dir
       character*24, dimension (nfiles):: fname
c fname2 no longer used in 2008    
         character*1 cseis,gseis
       integer, dimension(nfiles) :: mask,m_wash,m_west,m_oreg
       integer m_ida(nfiles)/28*1,23*0,2*1,8*0/
       integer m_mont(nfiles)/0,0,1,0,0,1,0,0,1,0,0,1,3*0,3*1,3*0,
     + 5*1,25*0,2*1,2*0,2*1,4*0/
       integer m_nnev(nfiles)/0,0,1,0,0,1,0,0,1,0,0,1,0,10*1,
     1 5*0,6*1,17*0,2*1,8*0/
       integer m_snev(nfiles)/15*0,8*1,5*0,1,0,0,6*1,10*0,1,0,1,0,2*1,8*0/
       integer m_aznm(nfiles)/15*0,8*1,28*0,2*1,2*0,2*1,4*0/
       integer m_utah(nfiles)/0,0,1,0,0,1,0,0,1,0,0,1,3*0,11*1,
     1 25*0,2*1,2*0,2*1,4*0/
       integer m_nocal(nfiles)/15*1,3*0,3*1,5*0,15*1,
     1 2*0,1,2*0,1,0,1,2*0,2*1,8*0/
       integer m_ccal(nfiles)/12*1,6*0,3*1,5*0,15*1,
     1 5*0,1,0,5*1,8*0/
       integer m_socal(nfiles)/0,0,1,0,0,1,0,0,1,0,0,1,3*0,1,2*0,3*1,7*0,
     1 1,3*0,9*1,5*0,2*1,0,4*1,8*0/
       integer m_midw(nfiles)/15*0,3*1,33*0,6*1,4*0/
       integer m_neus(nfiles)/55*0,2*1,4*0/
       integer m_seus(nfiles)/54*0,7*1/
       integer m_cus(nfiles)/53*0,4*1,4*0/
       integer m_east(nfiles)/53*0,8*1/
       integer iloc,iloq,icoarse/1/
       real perx(10)/0.,0.1,0.2,0.3,0.5,1.0,2.0,3.0,4.,5./,saout
       character nameout*50
	character*3 ext(nfiles)
       character ch1*1, ch2*2, Site_Class*2
      logical east/.false./,west/.false./,noiter/.true./,LP/.false./
c key to brief names describing fault or other hazard
c	character*28 srcdesc(35)
c     +/'Cascadia M8.0-M8.2','Cascadia M8.3-M8.7','Cascadia Megathrust',
c     +'Wash-Oreg Compr faults','Wash-Oreg Extens faults','Basin&Range M<6.5 flts',
c     +'Basin&Range M>6.5 Char','Basin&Range M>6.5 GR','NV-UT M<6.5 flts',
c     +'NV M>6.5 Char','NV M>6.5 GR','UT M>6.5 Char - Wasat','UT M>6.5 GR - Wasat',
c     +'Wasatch Segmented Char','Wasatch Segmented GR','Wasatch Unsegmented M7.4',
c     +'WUS Compr crustal gridded','CA-NV Shear Zones','CA B-faults Char',
c     +'CA B-faults GR','CA A-faults',
c     +'CA Compr crustal gridded','50-km Deep Intraplate','Puget Lowlands grid',
c     +'SAF Creep-gridded','Brawley gridded','Mendocino grid',
cc     +'Mojave grid', 'San Gorgonio Pass grid','Extensional grid', 
c     +'Cheraw CO or Meers OK','NMSZ no clustering','CEUS gridded',
c     +'Charleston SC M<7.2 zone','Charleston SC M>7.2 zone'/
      key=(/1,2,3,1,2,3,1,2,3,1,2,3, 4,5,5, 6,7,8, 9,10,11, 12,13,	!23
     + 14,15,16, 17,17, 18,18,18,18, 19,20,21,21,21, 22,22,22,22, 23,23,23, !20
     +24,24, 25,26,27,28,29, 30,30, 31, 32, 33,33, 34,34,35,35/)	!17
	m_west(1:57)=1; m_west(58:61)=0; 
	m_wash(16:61)=0
      m_wash(1:15)=1; m_wash(27:28)=1;m_wash(42:43)=1; m_wash(45:46)=1;
      m_wash(52:53)=1
      m_oreg=m_wash;m_oreg(38:41)=1; m_oreg(44)=1;m_oreg(49)=1
c ext(i) are file name extensions for writing intermediate results. Ideally
c these would be stored in memory rather than written to disk.
       imap=(/1,1,1,1,1,1,1,1,1,1,1,1,
     + 2,2,2, 2,2,2, 2,2,2, 2,2, 2,2,2,
     + 3,3, 3,3,3,3, 2,2, 2,2,2, 3,3,3,3, 3,3,3, 3,3,
     + 3,3,3,3,3, 3,3,2,2, 3,3, 3,3,3,3/)
	in_dir =(/4,4,4,4,4,4,4,4,4,4,4,4,
     + 5,5,5,6,6,6, 6,6,6, 6,6, 6,6,6, 
     + 5,5, 1,1,1,1, 1,1, 1,1,1, 1,1,1,1, 3,3,3, 
     + 5,5, 1,1,1,1,1, 6,6, 2,2, 2,2, 2,2,2,2/)
	ext =(/'cs1','cs2','cs3','cs4','cs5','cs6','cs7','cs8','cs9',
     + 'csa','csb','csc','owc','own','owg','br6','brc','brg','nv6',
     + 'nvc','nvg','utc','utg','wsc','wsg','wsm','wuc','wug','sh1',
     + 'sh2','sh3','sh4','cbc','cbg','caa','cam','cau','cm1','cm2',
     + 'cm3','cm4','pnd','pod','cad','puc','pug','crm','brm','mem',
     + 'mom','sgm','egc','egg','ccm','nmz','cuj','cua','cha','chb',
     + 'chc','chd'/)
c weights: start with cascadia, then various wus faults,... 
c Because of input file consolidation, some weights may look different from
c those used in national map preparation, 2007-2008.
       wt =(/.0051282,.0102564,0.13333, .0051282,.0102564,0.13333,
     1 .0025641,.0051282,0.06666667, .012821,.025641,0.33333,
c orwa, brange, nv
     1 0.5,0.6667,0.3333,1.,0.6667,0.3333,1.,0.6667,0.3333,
c utah, wasatch(partialwt), WUSmap (combined with nopugetmap) agrid half wt so double epist. wt.
     2 0.6667,0.3333,0.72,0.18,0.1,0.5,0.5,
c shear zones bfault_char bfault_gr (half wt, double wts internal), afaults
     3 1.,1.,1.,1.,0.66667,0.16667,0.45,0.225,0.05,
c CAmapC, CAmapG, pacnwdeep, portdeep, CAdeep, pugetC&G, creepmap,brawmap
     4 0.33333,0.33334,0.16667,0.16666,1.,1.,1.,0.25,0.25,1.,1.,
c mendo, mojave, sangorg, extgridC&G, CEUScm NMSZnocl
     5 1.,1.,1.,0.6667,0.3333,1.,1.,
c CEUS gridded J&AB files, 4 CEUS charleston files  with Mchar stated in name   
     5 0.5,0.5,0.2,0.2,0.45,0.15/)
c a larger set of ann rates is now allowed for 2008. This was 2002 set:
c 	pann=(/0.000201,.000404,.001026,.002107,.0044629,.009242/)
        fname=(/
     1'cascadia.bot.8082.in    ','cascadia.bot.8387.in    ','cascadia.bot.mega.in    ',
     1'cascadia.mid.8082.in    ','cascadia.mid.8387.in    ','cascadia.mid.mega.in    ',
     1'cascadia.top.8082.in    ','cascadia.top.8387.in    ','cascadia.top.mega.in    ',
     2'cascadia.older2.8082.in ','cascadia.older2.8387.in ','cascadia.older2.mega.in ',
     2'orwa_c.in               ','orwa_n.3dip.char        ','orwa_n.3dip.gr          ',
     3'brange.3dip.65          ','brange.3dip.char        ','brange.3dip.gr          ',
     3'nvut.3dip.65            ','nv.3dip.char            ','nv.3dip.gr              ',
     3'ut.3dip.char            ','ut.3dip.gr              ',
     4'wasatch.3dip.char       ','wasatch.3dip.gr         ','wasatch74.3dip.gr       ',
     4'WUSmapCP.in             ','WUSmapGP.in             ',
     4'SHEAR1.in               ','SHEAR2.in               ','SHEAR3.in               ',
     5'SHEAR4.in               ','bFault_D2.1_2.4_Char.in ','bFault_GR0.in           ',
     5'aFault_aPriori_D2.1.in  ','aFault_MoBal.in         ','aFault_unseg.in         ',
     5'CAmapC_21.in            ','CAmapC_24.in            ','CAmapG_21.in            ',
     6'CAmapG_24.in            ','pacnwdeep.in            ','portdeep.in             ',
     6'CAdeep.in               ','pugetmapC.in            ','pugetmapG.in            ',
     6'creepmap.in             ','brawmap.in              ','mendomap.in             ',
     7'mojave.in               ','sangorg.in              ',
     7'EXTgridC.in             ','EXTgridG.in             ',
c CEUS files below (consolidate the .nmc and .out into one agrid, and all Mmax)
     7'CEUScm.in               ','NMSZnocl.5branch.in     ','CEUS.2007all.J.in       ',
     8'CEUS.2007all.AB.in      ','CEUSchar.68.in          ','CEUSchar.71.in          ',
     8'CEUSchar.73.in          ','CEUSchar.75.in          '/)
c
c       if(iargc().lt.9)stop'combine:  Usage: combine site ylat xlon j ...'
      numargs=iargc()
       ipr=1
       ivs=1	!initially a site class is entered. if not, default to BC
       vs30=760.
      nfil=0
      gseis='0'
      call getarg(1,site)
      call getarg(2,cord)
c Put in decimal point if not present in command-line argument
       if(index(cord,'.').eq.0)then
           j=index(cord,' ')-1
          cord=cord(1:j)//'.0'
      endif
      read(cord,303,err=1999)ylat
      noiter=abs(float(nint(ylat*20.))-ylat*20.).lt.0.01
303     format(f9.4)
      call getarg(3,cord)
          if(index(cord,'.').eq.0)then
           j=index(cord,' ')-1
          cord=cord(1:j)//'.0'
      endif
      read(cord,303,err=1999)xlon
      noiter=noiter.and.float(int(xlon*20.)).eq.xlon*20.
      call getarg(4,ch9)
      read(ch9,'(f9.7)')annrate
c 2008: find motion corresponding to any annual rate of exceedance, annrate     
	if(annrate.lt.2.2e-4)then
	irate=1
	elseif(annrate.lt.4.3e-4)then
	irate=2
	elseif(annrate.lt.1.1e-3)then
	irate=3
	elseif(annrate.lt.2.e-3)then
	irate=4
	elseif(annrate.lt.4.6e-3)then
	irate=5
	else
	irate=6
	endif
      call getarg(5,frc)
c frequency code
      read(frc,'(i2)')ifrc
c ifrc should be limited to values between 1 and 10 nov 2008
	if(ifrc.ge.8.and.xlon.gt.-101.)stop'3s not available for CEUS'
	if(perx(ifrc).gt.3.)then
c substitute LP for in in some names
	do i=1,12
c Cascadia changes.
	j=index(fname(i),'.in')
	fname(i)=fname(i)(1:j)//'LP'
	enddo
	do i=42,44
c Deep intraplate changes
	j=index(fname(i),'.in')
	fname(i)=fname(i)(1:j)//'LP'
	enddo	
	endif	!LP changes to attn. model set when T > 3 s.
      call getarg(6,pid)
       ipid=index(pid,' ')-1
      call getarg(7,loc)
       iloc=index(loc,' ')-1
c have to have absolute location.
      call getarg(8,logdir)
       iloq=index(logdir,' ')-1
c separate location ,  output dir, "addhaz" and "*4p" type files.
c irate=index for annual rate, 1 => 1% in 50 years, 2=> 2%50, 
c  3=> 5%50, 4=> 10%50 years, 5 => 20% in 50 years, 6 => 50% in 75 years
c the 6 index added May '02 for AshToe.
c     print *,' Irate interpreted to be ',irate
       irate=max(1,irate)
       irate=min(nrates,irate)
c If invalid instructions modify irate to nearest available index.
       if(ylat.gt.49.05.or.xlon.lt.-125.)stop'Please confine to contig USA'
       if(ylat.lt.25..or.xlon.gt.-65.)stop'Lat or long out of range, USA'
       if(numargs.ge.9)then
      call getarg(9,cseis)
      gseis=cseis
        if(numargs.ge.10)then
       call getarg(10,ch1)
       read(ch1,'(i1)')icoarse
c icoarse is a small integer, 1,2,3,4 are likely. 0 is possible.
      call getarg(11,ch8)
      read(ch8,'(f8.1)')vs30
c Reset vs30 if analysis is not available for the input value
	lxy= LXYIN_WUS(xlon,ylat)
	if(lxy.and.vs30.gt.1300.)then
	vs30=1300.
	elseif(lxy.and.vs30.lt.180.)then
c site class vs30 low lim recommendation by BA and others
	vs30=180.
	elseif(.not.lxy.and.vs30.lt.760.)then
c east of rocky mountain rangefront must use BC
	vs30=760.
	elseif(.not.lxy.and.vs30.gt.1200.)then
	vs30=2000.
	endif
      if(vs30.ge.1500.)then
      Site_Class= 'A'
      vs30=2000.
c there is only one hard-rock model for most CEUS atten. relations.
c use 2000 m/s to distinguish from firm rock case or BC
      ivs=0
      elseif(xlon.gt.-101.)then
      vs30=760.
      Site_Class= 'BC'
      elseif(vs30.gt.800.)then
      Site_Class= 'B'
      if(xlon.gt.-105.)vs30=760.
      elseif(vs30.gt.700.)then
      Site_Class= 'BC'
      if(xlon.gt.-104.)vs30=760.
      ivs=1
      elseif(vs30.ge.380.)then
c Boore says the avg encountered C is about 490 (Eq Spectra feb 08)
c you might have soil  site analysis for places like El Paso TX
c the CEUS src contrib. anywhere in Texas will be for rock, however.
      Site_Class='C'
      if(xlon.gt.-103.)vs30=760.
      ivs=3
      elseif(vs30.gt.350.)then
      Site_Class= 'CD'
      if(xlon.gt.-103.)vs30=760.
      ivs=3
      print *,'Setting up WUS ground motions for site class C'
      elseif(vs30.gt.190.)then
      ivs=4
      Site_Class= 'D'
      print *,'Setting up WUS ground motions for site class D'
      else
       Site_Class= 'DE'
            ivs=4
c As of July 2008 we have a limited ability to set up a Soil model
      endif
       endif	!numargs.ge.10
       endif     
      call usa_sa(xlon,ylat,annrate,saout,ifrc,ivs,noiter)
      if(ifrc.eq.3)then
      saout5=saout
      call usa_sa(xlon,ylat,annrate,saout1,6,ivs,logit)
      elseif(ifrc.eq.6)then
      saout1=saout
      call usa_sa(xlon,ylat,annrate,saout5,3,ivs,logit)
      
      else
c some stuff for the approximate UHS. Probably no longer used.
      call usa_sa(xlon,ylat,annrate,saout1,6,ivs,logit)
      call usa_sa(xlon,ylat,annrate,saout5,3,ivs,logit)
      endif
       TOL=0.02
         if(xlon.gt.-85.)TOL=0.01
       ix0=  int((xlon+115.0)/0.1 )
c ix0 is a positive number for xlon .gt. -114.9
       iy0= (50.0-ylat)/0.1 + 1.5
       ixc=int((xlon+115.)/0.2)
       iyc=int((50.0-ylat)/0.2)
c     print *,ixc,iyc,'index in coarse grid'
      west=xlon.lt.-99.95
      east=xlon.gt.-115.05
c In several regions some simplification is possible
c se us check:
       if(ylat.lt.34..and.xlon.gt.-81.5)then
        mask=m_seus
      do i=1,nfiles
       if(mask(i).gt.0)print *,fname(i),i,wt(i)
      enddo
c NEUS check:
      elseif(ylat.gt.41.5.and.xlon.gt.-78.)then
        mask=m_neus
      do i=1,nfiles
       if(mask(i).gt.0)print *,fname(i),i,wt(i)
      enddo
c  northern NMSZ check
      elseif(xlon.gt.-100.01)then
      call setorig(37,20.,-89,30.,0)
      call dist(ylat,xlon,0.,a,b,c)
      a=sqrt(a*a+b*b)
       if(a.lt.400..or.(ylat.gt.38..and.xlon.lt.-88.))then
        mask=m_cus
      do i=1,nfiles
       if(mask(i).gt.0)print *,fname(i),i,wt(i)
      enddo
      else
c southern NMSZ?
         call setorig(35,21.,-90,30.,0)
      if(sqrt(a*a+b*b).lt.400.)then
       mask=m_cus
      else
       mask=m_east
       if(ylat.gt.40..and.xlon.gt.-90.)mask(54)=0
      endif
c above if is to eliminate calcs for Charleston if too far north
      do i=1,nfiles
       if(mask(i).gt.0)print *,fname(i),i,wt(i)
      enddo
      endif
c ceus_west midwest more or less to Colorado's west boundary
      elseif(xlon.gt.-111.1.and.ylat.le.37.04)then
       mask=m_midw
       if(ivs.gt.1)mask(54:61)=0	!CEUS atten cant handle soil
      do i=1,nfiles
       if(mask(i).gt.0)print *,fname(i),i,wt(i)
      enddo
      elseif(xlon.gt.-111.1.and.ylat.gt.37.04)then
       mask=m_midw
       if(xlon.lt.-109.5.and.ylat.gt.38.) mask(22:26)=1
       if(ylat.gt.45.)mask(54)=0	!Cheraw-Meers omit.
c include Wasatch hazard for western Col and western Wyoming
      do i=1,nfiles
       if(mask(i).gt.0)print *,fname(i),i,wt(i)
      enddo
      elseif(xlon.gt.-113..and.ylat.gt.45.5)then
       mask=m_mont
       if(ivs.gt.1)mask(54:61)=0	!CEUS atten cant handle soil
      print *,"Montana N.Dakota reg"
      elseif(xlon.gt.-117..and.xlon.lt.-111..and.ylat.gt.42.)then
       mask=m_ida
       if(xlon.gt.-113.5)then
       mask(1:12)=0
       mask(27:28)=0
       endif
      print *,"idaho reg"
            do i=1,nfiles
       if(mask(i).gt.0)print *,i,wt(i),fname(i)
      enddo
      elseif(xlon.gt.-114.05.and.xlon.lt.-108.5.and.ylat.gt.37.)then
       mask=m_utah
       if(xlon.gt.-113.5)mask(6:9)=0
       if(ivs.gt.1)mask(54:61)=0	!CEUS atten cant handle soil
      print *,"Utah reg"
            do i=1,nfiles
       if(mask(i).gt.0)print *,i,wt(i),fname(i)
      enddo
c gridded sources are extensional or ceus_w in Utah (Omit WUS gridded & nopuget gridded)
      elseif(xlon.lt.-116.9.and.ylat.gt.45.)then
       mask=m_wash
c extensional sources not relevant to western Wash or western Oreg. hazard
       if(xlon.lt.-122.18)mask(52:53)=0
	if(xlon.lt.-123..and.ylat.gt.47.)mask(14:15)=0
      do i=1,nfiles
      if(mask(i).gt.0)print *,fname(i),mask(i),wt(i)
      enddo
      elseif(xlon.lt.-116.9.and.ylat.gt.42.)then
      print *,'Oregon'
       mask=m_oreg
       if(ylat.gt.43.3.or.xlon.gt.-121.)mask(49)=0	!mendomap
c extensional sources not relevant to Western Wash Western Oreg. hazard
       if(xlon.lt.-122.48.and.ylat.gt.43.6)mask(52:53)=0
       if(ylat.lt.43.5)mask(42)=0	!pacnw deep no longer rel.
       if(ylat.lt.43.1)mask(45:46)=0
       if(ylat.gt.43.9)mask(38:41)=0	!Camap not relevant N of 43.9
      do i=1,nfiles
       if(mask(i).gt.0)print *,i,fname(i),wt(i)
      enddo
      elseif(xlon.lt.-119.98.and.ylat.gt.39.)then
      print *,'N Calif'
       mask=m_nocal
       if(xlon.lt.-122.2)mask(19:21)=0
       if(ylat.le.40.2)mask(13:15)=0	!oregon faults no longer matter
      do i=1,nfiles
       if(mask(i).gt.0)print *,i,fname(i),wt(i)
      enddo
      elseif(ylat.gt.35.51.and.xlon.lt.-115.3-9./7.*(ylat-35.5))then
      do i=1,nfiles
      mask(i)=m_ccal(i)
      enddo
c include CA deep for west-Central
       if(xlon.lt.-116.6)mask(44)=1
c skip WUS gridded if in SW part of region (extensional OK but not non-ext)
       if(xlon.gt.-118.0 .or. xlat.lt.38.6)mask(27:28)=0
c skip the NV faults, EXTmap & San Gorgonio setup if site is close to SF bay.
c this will be a common deagg region and it needs to be efficiently analysed.
       if(xlon.lt.-121.8.and.ylat.le.38.2)then
       mask(51:53)=0; mask(19:21)=0
       endif
       if(xlon.lt.-119.8.and.ylat.gt.37.)mask(50)=0
       
c skip the creeping section if east
       if(xlon.gt.-117.3) mask(47)=0
       print *,'Central Calif region site'
       do i=1,nfiles
        if(mask(i).gt.0)print *,i,fname(i),wt(i)
       enddo
      elseif(xlon.lt.-114..and.ylat.lt.35.52)then
      do i=1,nfiles
      mask(i)=m_socal(i)
      enddo
       if(xlon.lt.-117.)then
       mask(52:53)=0
       mask(16)=0; mask(19:21)=0
       endif
       if(xlon.lt.-119.1)mask(51)=0	!san gorgonio influence nil
       if(ylat.lt.35.05)mask(29)=0	!shear1 irrelevant s of here
       if(ylat.lt.33.4)then
      mask(3)=0
      mask(6)=0
      mask(9)=0
      mask(12)=0
      endif
c for jim brune remove all background. then commented out this experiment
c	mask(47:53)=0
c	mask(38:41)=0	!camap
	
      do i=1,nfiles
      if(mask(i).eq.1)print *,fname(i),i,wt(i)
      enddo
      elseif(xlon.gt.-120.and.ylat.lt.42.02.and.ylat.gt.37.9)then
      do i=1,nfiles
      mask(i)=m_nnev(i)
      enddo
       if(xlon.gt.-115.)mask(24:26)=1
c Omit wasatch front contributions except in eastern Nv
       if(xlon.gt.-118.)mask(14:15)=0
       if(xlon.lt.-117.5.and.ylat.lt.-40.5)then
       mask(16:18)=0
       mask(22:23)=0
       endif
c omit OR-WA in eastern nev
       if(ylat.lt.40.9)then
      mask(9)=0
      mask(3)=0
      mask(6)=0
      mask(12)=0
      endif
       if(ylat.lt.39.2)mask(14:15)=0
       print *,'Northern Nevada'
      do i=1,nfiles
       if(mask(i).gt.0)print *,fname(i),i,wt(i)
      enddo
      elseif(xlon.gt.-119.and.ylat.lt.37.91.and.ylat.gt.36.)then
      do i=1,nfiles
      mask(i)=m_snev(i)
      enddo
       if(xlon.ge.-115.)      mask(56:57)=1
c include CEUS gridded in special cases (this should not be s. Nevada)
      print *,'Southern Nevada'
      do i=1,nfiles
       if(mask(i).gt.0)print *,fname(i),i,wt(i)
      enddo
      elseif(ylat.lt.37.05)then
c ariz - new mexico - texas
      do i=1,nfiles
      mask(i)=m_aznm(i)
      enddo
       if(xlon.lt.-113.1)mask(35:37)=1
c include calif a-faults even this far east Apr 2003 mod. 
c Also Calif gridded but exclude CEUS gridded (slow, best to avoid these calcs if possible)
       if(xlon.lt.-114.2)mask(56:57)=0
c omit brawley if site is east of its influence     but include cheraw-meers
       if(xlon.lt.-113.4)then
      mask(56:57)=0
      mask(48)=1
      endif
      if(xlon.gt.-112.5.and.ylat.lt.35.55)mask(20:21)=0	!nevada too far away
      do i=1,nfiles
       if(mask(i).gt.0)print *,fname(i),i,wt(i)
      enddo
      elseif(xlon.lt.-99.99)then
      do i=1,nfiles
      mask(i)=m_west(i)
      enddo
      print *,' site ',xlon,ylat,' general wus. repair mask logic?'
      else
      print *,' site ',xlon,ylat,' no mask model '
      stop'cant go on'
      endif
      nfil=0
      do i=1,nfiles
      nfil=nfil+mask(i)
      enddo
      print *,'Number of files to be run with deagg pgms ',nfil
c nfil is the number of files that might have non-zero annual rates. This
c number is independent of period and ground motion level at this stage of
c the analysis. There isn't much runtime penalty for doing extra files, so
c we err on the side of overkill.
       isite=min(16,index(site,' ')-1)
c	print *,isite,site(1:isite)
c Some deaggregation programs insist on max 12 character namesize 12=isite+2exten.
      jj=ifrc
      nameout='addhaz.'//pid(1:ipid)
       open(1,file=logdir(1:iloq)//nameout,status='unknown')
      write(1,103)nfil
103     format(i2,/,'n',/,'z')
      do i=1,nfiles
       if(mask(i).eq.1)then
      nameout=pid(1:ipid)//ext(i)
      write(1,106)nameout,wt(i),key(i)
106     format(a30,/,f9.7,1x,i2)
      endif
      enddo
       i1=ipid+4
      write(1,107)pid(1:ipid)//'.'//list(jj),cper(jj)
107     format(a,/,a4,' sec. PSH deaggregation USGS-CGHT 2008')
      close(1)
 900  format(a50)
909     format(1x,f8.5,1x,f10.5,2(1x,e12.5))
910     format(4(1x,e12.5),' 4-neighber estimates, sum wts=',f4.1)
9091     format(2x,f6.3,1x,f8.3,2(1x,e12.5))
c     close(8)
       ilev=irate
      nameout=pid(1:ipid)//tt
      open(1,file=logdir(1:iloq)//nameout,status='unknown')
c     open(3,file='g'//nameout,status='unknown')
      np=1
      ireturn=nint(1./annrate)
      write(1,407)site(1:isite),cper(jj),ireturn
407     format('#!/bin/csh',/,'# ',a,1x,a4,
     1 ' sec. Interactive Web Site PSHA Deaggregation',
     2 /,'# Return period ',i5,' years.',/,
     3'#Contact Steve Harmsen, USGS, 303 273 8567',/,
     4'set path = ( $path /www/eqint.cr.tmp/eq-men/deaggint2008 )',/)
220     format(' set L',i1,' = ',f7.5)
      write(1,220)(ii,saout,ii=1,np)
	r15=saout1/saout5
226     format(' set TS = ',f6.3,/,' set SA5 = ',f8.5)
      write(1,226)r15,saout5
      write(1,222)annrate,TOL,Site_Class,pid(1:ipid)
222     format(' set ANN = ',f9.7,/' set B = 1',/,
     1 ' set TOL = ',f5.3,/,
     1' set Site_Class = ',a,/,
     1' set IT = 0',/,'#rm gmset.?',a,/,
     1'while ( $B == 1 ) ',/,' @ IT += 1 ')
 
      do i=1,nfiles
       if(mask(i).eq.1)then
      np=1
c call the program that is going to handle the input file
       ii=imap(i)
       write(1,209)sfy(ii),subd(in_dir(i))//fname(i),pid(1:ipid),
     1 ext(i),ylat,xlon,perx(ifrc),1, vs30
       endif
      enddo
209     format(' $1bin/deagg',a,' ',a,1x,a,a3,1x,f8.5,1x,
     1 f10.5,1x,f4.2,1x,'$L',i1, 1x,f6.1,' $1 $3 >>& /dev/null')
609     format(' $1bin/deagg',a,' ',a,1x,a,a3,1x,f8.5,1x,
     1 f10.5,1x,f4.2,1x,'$L',i1,1x,f6.1,' $AT $1 $3 >>& /dev/null')
619     format(' $1bin/deagg',a,' ',a,1x,a,a3,1x,f8.5,1x,
     1 f10.5,1x,f4.2,1x,'$L',i1,i2,1x,f6.1,' $AT $1 $3 >>& /dev/null')
      jj=1
        nameout=
     1'addhaz.'//pid(1:ipid)//' '
       ii=index(nameout,' ')-1
      write(1,230)jj,nameout(1:ii)
230     format(' set y',i1,' = `$1bin/checksum $3 ',a,' `')
 
233     format(' set B = `$1bin/decides $IT $TOL $ANN $y1 `',/,
     1' if ($B == 0  && $Site_Class == BC) then',/,' set Pr0 = $Pr')
     
234     format(' set B = 0 ',/,'# DO not ITERATE gridpts 2008 update')     
235     format(' set B = `$1bin/decides $IT $TOL $ANN $y1 `')

     
       if(noiter)then
      write(1,234)
       else
      write(1,235)
      endif     
        if(xlon.lt.-116.)then
      si=0.29
        if(irate.ge.3.and.(ylat-42.).gt.-8.*(xlon+121.))then
      si=0.5 +0.05*(irate-4)
       elseif(irate.ge.3.and.(ylat-34.).gt.-8.*(xlon+121.))then
      si= 0.4 + 0.05*(irate-4)
       endif
       elseif(xlon.lt.-103.)then
      si=0.48
       if(xlon.gt.-109..and.irate.gt.2)si=0.6
       elseif(abs(xlon+90.).lt.0.6.and.abs(ylat-36.).lt.0.6
     1  .and. irate.ge.3)then
      si= 1.10 - .1*abs(irate-4)
c nmsz with short return time, this exponent may exceed 1
       elseif(abs(xlon+87.7).lt.1.0.and.abs(ylat-36.5).lt.3.5
     1  .and. irate.ge.3)then
      si=0.8
c East of NMSZ, si decreases slowly to the 0.6 "background level"
       elseif(abs(xlon+91.7).lt.1.3.and.abs(ylat-36.).lt.2.5
     1 .and. irate .ge.3)then
      si=0.8
c west of NMSZ similar situation
       elseif(abs(xlon+80.).lt.0.5.and.abs(ylat-32.8).lt..6
     1 .and. irate.ge.2)then
      si=1.1-0.1*abs(irate-4)
c charleston sc region
      elseif(xlon.gt.-83.)then
      si=.8-.1*abs(irate-4)
       endif
       jj=1
      write(1,237)jj,jj,jj,jj,pid(1:ipid),si
237     format(' set L',i1,' = `$1bin/rescale $B $IT $ANN ',i1,
     1 ' $L',i1,' $y',i1,' ',a,' $3 ',f4.2,' `')
      write(1,239)
239     format(/,'end'/,'#echo $y1 computed rates')
241     format('end',/,' set SA5 = $L3',/,' set TS = `echo $L2 $L3 | 
     1 /usr/bin/awk ''{print $1/$2}'' ` ')

      jj=1
         nameout='$3addhaz.'//pid(1:ipid)
        ko=index(nameout,' ')
      write(1,211)site(1:isite),xlon,ylat,ireturn,vs30,
     1 cper(ifrc),jj,jj,pid(1:ipid),gseis,nameout(1:ko)
c          write(1,2111)jj
2111    format('set AT = $A',i1) 
c $TS below is the ratio SA1/SA5, used to select time series. the selection
c was based on attempt to approximate spectrum of UHS. Should this be the
c criterion in 2008? Not outputting an "A" from sum_haz_2008
211     format('$1bin/sum_haz_2008 ',a,1x,f10.5,
     1 1x,f8.5,1x,i5,1x,f5.0,1x,a4,' $L',i1,' $y',i1,' ',a,
     2' $1 $3 $TS $SA5 ',a,' <',a)
311     format('$1bin/geog_haz.2008 ',a,1x,f10.5,1x,f8.5,1x,a,1x,i5,
     1 1x,f5.0,1x,f5.2,' $L1 $y1  ',
     2 1x,i1,' $1 $3 >>& /dev/null < ',a)
	write(1,307)pid(1:ipid)
c the $2 arg below should be 1 if you want a geographic deagg. In script 
c "run_2008" 2nd arg is $geo. First arg is absolute path to pgm executables.
307     format('if ($2)  then',/,
     1 ' /usr/bin/rm $1',a,'*.?0 >& /dev/null')
      do i=1,nfiles
      ii=imap(i)
       if(mask(i).gt.0.and.ii.ne.4)then
      write(1,609)geo(ii),subd(in_dir(i))//fname(i),pid(1:ipid),
     1 ext(i),ylat,xlon,perx(ifrc),1,vs30
           elseif(mask(i).gt.0)then
          write(1,619)geo(ii),subd(in_dir(i))//fname(i),pid(1:ipid),
     1 ext(i),ylat,xlon,perx(ifrc),1,icoarse,vs30
      endif
      enddo
       jj = 1
c just write the GMT script  for frequency requested, with index jj
c       nameout='$3addhaz.'//pid(1:ipid)
      write(1,311)site(1:isite),xlon,ylat,pid(1:ipid),ireturn,vs30,
     1 perx(ifrc),icoarse,nameout(1:ko)
      write(1,318)
318     format('endif',/,'#end of conditional for geographic deagg')
      write(1,213)pid(1:ipid)
213     format(/,'/usr/bin/rm $3',a,'*.*0 >& /dev/null',/,
     1'exit 0')
c     2,/,'# end of script to deaggregate for return=',i4,' yrs')
      close(1)
      stop ' combine.2008: normal exit'
1999     stop'combine: aborted run: Site coordinate wouldnt read'
      end
      
      subroutine setorig(lat,xlat,lon,xlon,depth)
c setorig will compute constants for short distance conversions
c when the user calls dist 
c lat= lat,deg
c xlat= lat,min
c lon= lon, deg
c xlon= lon, minutes

      common /setx/ olat,olon,oz,aa,bb,bc
       double precision lat1,lat2,rlatc,x1,xt
       double precision dela,delb,rad
      data rearth /6378.163/, ellip /298.26/
      rad= 0.017453292
      rlatc = 0.99330647
c-----input center of coordinate system
 10   format (i2,1x,f5.2,i4,1x,f5.2,1f7.2)
c      write(24,10) lat,olat,lon,olon,oz
c      write(25,10) lat,olat,lon,olon,oz
c      write(6,15)
      olat=xlat
      olon=xlon
      oz=depth
c       write (6,20) lat,olat,lon,olon,oz
 15   format(' origin of cartesian coordinates ',5x,'depth')
 20   format (10x,i2,1h-,f5.2,1hn,i4,1h-,f5.2,1hw,11x, f7.2)
      olat=lat*60.+sign(olat,float(lat))
      olon=lon*60.+sign(olon,float(lon))
c-----calculate aa ,  bb
c-----length of one minute of lat and lon in km
      x1 = olat*rad/60.0
      xt = dsin(x1)/dcos(x1)
      lat1 = datan(rlatc*xt)
      x1 = (olat+1.)*rad/60.0
      xt = dsin(x1)/dcos(x1)
      lat2 = datan(rlatc*xt)
      dela = lat2 - lat1
      r = rearth*(1.0 - (dsin(lat1)**2)/ellip)
      aa = r*dela
      delb = (dsin(lat1)**2 + dcos(rad/60.)*
     *  dcos(lat1)**2)
      dela = dsqrt(1.0-delb**2)
      delb = datan(dela/delb)
      bc=r*delb
      bb = r*delb/dcos(lat1)
c       write (6,3001) aa, bc
 3001 format (10x, 27hshort distance conversions  /
     *  10x, 12hone min lat  , f7.4, 4h  km  /
     *  10x , 12hone min lon   , f7.4, 4h  km  ,/)
      return
      end subroutine setorig
      
      subroutine dist (xlat,xlon,z,qp,xxp,zpri)
c computes distances (km) from (xlat,xlon,z) to origin determined
c during a call to setorig
      common /setx/ olat,olon,oz,aa,bb,bc
c-----conversion of latitude and longitude to kilometers relative
c-----to center of coordinates
       double precision lat1,yp,rad/0.017453292/,rlatc/0.99330647/,xt,x1
      data rearth /6378.163/, ellip /298.26/
      q=60.*xlat - olat
      yp=q+olat
      x1=yp*rad/60.0
      xt=dsin(x1)/dcos(x1)
      lat1=datan(rlatc*xt)
      xx=60.*xlon - olon
      qp=q*aa
      xxp = xx*bb*dcos(lat1)
      zpri = z-oz
      return
      end subroutine dist

      subroutine usa_sa(xlon,ylat,ann,saout,ifrc,ivs,noiter)
c computes sa values at xlon ylat for annual rate of exc = ann from
c usgs 2008 update values available as hazard curves.
c ann is a real scalar. log-log interp is used. 
c     usa_sa.f outputs Spectral Acceleration or PGA. 
c for sampled sites in continental usa. UShazard covers whole 48-state region
c plus some Canada and Mexico and quite a few ocean sites too. 
c Half-country data are stored in two blocks, the WUS 125 to 100 degrees W by 0.05,
c and the CEUS 115 to 65 degrees W by 0.1 degrees.
c Input: 
c xlon,ylat: site coords in degrees. The curve nearest these coords will be used.
c ifrc 1 to 10: period from 0 (pga) to 3s (index 8). add 4s (9) and 5s (index10)
c ivs = 0 hard-rock (ceus only);  1 BC rock (available everywhere); 3 C-soil WUS;
c   or 4 D-soil WUS
c input&output noiter : instruction to iterate GM soln. FOR SFBAY and LA reg this may get
c reset here. soil sa for non-std periods also may require iteration. Extrapolated GM also
c should be iterated (interpolated  GM error has a limit of about 2 or 3% which is tolerable).
c Primary output:
c saout = pga if ifrc is 1, to 5s sa if ifrc is 10, corresponding to "ann" rate.
c Erate is a temp. vector which will contain the mean ann. rate of exc., i.e., 
c the hazard curve. If the requested ann rate is outside the sampled rates, a
c flat extrapolation occurs to smaller values, but log-log is attempted to larger
c values. Extrapolation should be monitored.
c For C and D soils the model is for far West. Mid-West, e.g. COlorado, won't work
c because the CEUS source models do not have soil response set up. 
c Requires a collection of binary files each with 308-byte header.
c Initially  GLDFISH DIR str.
	parameter (nfi = 7, nfip=8,nfmin=3)
	real saout,xlon,ylat,ann,hanna,x1,y1,x2,y2,y,y0,dy
	integer ifrc,ivs,readn
	integer istd(10)/1,2,3,4,4,5,6,6,6,6/,jstd(10)/1,2,3,4,4,6,7,7,7,7/
	real Tfac(10)/1.,1.,1.,1.,.67,1.,1.,0.67,0.49,0.39/
c for incomplete period sampling, non-sampled period SA is based on sampled period
c with simple factors to account for delta-T. The ground motion will be iterated to
c convergence in these cases.
	real, dimension(21):: fac,erate
      type  header 
        character*30 :: name(6)
        real :: period
        integer :: nlev
        real :: xlev(20)
        real :: extra(10)
      end type header
      type(header) :: head
      real perx(10)/0.,0.1,0.2,0.3,0.5,1.0,2.0,3.0,4.,5./,T
      logical noiter
c 
c head%name(i) contains some files & program in history.
c 
c head%period(i) is the SA period in seconds for the given SAfile (See below)
c 
c headr%xmin, etc longitude ranges and sampling
c headr%ymin, etc latitude ranges and sampling interval
c extra() tells us the regional grid (US, CEUS or WUS bounding box)
c Binary files store the curves. Their names have region indicator, period, etc. 
	character*22 myfi
        character*41 loc/'/www/eqint.cr.tmp/eq-men/deaggint2008/GM/'/
c Loc is the gldplone directory where the GM data should reside
      character*18 inf(nfi)/'UShazbin.2008.pga','UShazbin.2008.10hz',
     + 'UShazbin.2008.5hz','UShazbin.2008.3hz','UShazbin.2008.2hz',
     + 'UShazbin.2008.1hz','UShazbin.2008.2sc'/
      character*18 la_inf(nfip)/'LAhazbin.2008.pga','LAhazbin.2008.10hz',
     + 'LAhazbin.2008.5hz','LAhazbin.2008.3hz','LAhazbin.2008.2hz',
     + 'LAhazbin.2008.1hz','LAhazbin.2008.2sc','LAhazbin.2008.3sc'/
      character*18 sf_inf(nfip)/'SFhazbin.2008.pga','SFhazbin.2008.10hz',
     + 'SFhazbin.2008.5hz','SFhazbin.2008.3hz','SFhazbin.2008.2hz',
     + 'SFhazbin.2008.1hz','SFhazbin.2008.2sc','SFhazbin.2008.3sc'/
      character*22 infi(nfi)/'CEUSHRhazbin.2008.pga','CEUSHRhazbin.2008.10h',
     + 'CEUSHRhazbin.2008.5hz','CEUSHRhazbin.2008.3hz','CEUSHRhazbin.2008.2hz',
     + 'CEUSHRhazbin.2008.1hz','CEUSHRhazbin.2008.2sc'/
      character*18 lowfi(3)/'WUShazbin.2008.3sc','WUShazbin.2008.4sc','WUShazbin.2008.5sc'/
c	2008: several long period PSHA are available for wus only.
c NEHRP site class C, vs30 is 537 m/s for the NGA relations. includes Cascadia haz.
c initially prepared for just 3 periods. should not try for soil unless these are chosen
c reanalyse June 2009 for 23 additional soil periods: 10hz 3hz and 2sc.
      character*22 cfi(6)/'WUS_C.hazbin.2008.pga','WUS_C.hazbin.2008.10h','WUS_C.hazbin.2008.5hz',
     +'WUS_C.hazbin.2009.3hz','WUS_C.hazbin.2008.1hz','WUS_C.hazbin.2009.2sc'/
c NEHRP site class D, vs30 is 259 m/s for the NGA relations. 
      character*22 dfi(6)/'WUS_D.hazbin.2008.pga','WUS_D.hazbin.2009.10h','WUS_D.hazbin.2008.5hz',
     +'WUS_D.hazbin.2009.3hz','WUS_D.hazbin.2008.1hz','WUS_D.hazbin.2009.2sc'/
c select the file of hazard curves to look at. Put selection in myfi
	fac=1.0
	T=perx(ifrc)
c LA region rock haz precomputed over fine grid and data can be used jan 2009.
      if(xlon.ge.-120..and.xlon.le.-116..and.ylat.ge.32.5.and.ylat.le.35.
     + .and.ifrc.lt.9.and.ivs.lt.3)then
c use 0.01 degree sampled data for SO CALIF region. If input coords are to
c nearest 1/100 degree, don't iterate solution (available for BC rock only)
      myfi = la_inf(ifrc)
      noiter = abs(float(nint(ylat*100.))-ylat*100.).lt.0.02.and.
     + abs(float(nint(xlon*100.))-xlon*100.).lt.0.02
c use 0.01 degree sampled data for Central CALIF or SF Bay region
      elseif(xlon.ge.-123.0.and.xlon.le.-120.5.and.ylat.ge.37.and.ylat.le.38.6
     + .and.ifrc.lt.9.and.ivs.lt.3)then
c San Franc. regional rock haz  precomputed for T<=3 s SA and pga.
      myfi=sf_inf(ifrc)
      noiter=abs(float(nint(ylat*100.))-ylat*100.).lt.0.02.and.
     + abs(float(nint(xlon*100.))-xlon*100.).lt.0.02
c long period or low-freq files. We have 3s for SF and LA regions and these should
c have been reached above if ifrc = 8.
      elseif(ifrc.eq.8.and.ivs.lt.3)then
      myfi=lowfi(1)
      elseif(ifrc.eq.9.and.ivs.lt.3)then
      myfi=lowfi(2)
      elseif(ifrc.eq.10.and.ivs.lt.3)then
      myfi=lowfi(3)
      elseif(ivs.eq.3)then
c C-soil WUS only
        myfi = cfi(istd(ifrc))
        T=perx(jstd(ifrc))
        s=Tfac(ifrc)
        if(s.ne.1.0)then
        fac(11:20)=s
        y=alog(s)
        y0=-y
        dy=0.055*(y-y0)
        do i=1,10
        fac(i)=s*exp(y0)
        y0=y0+dy
        enddo
        endif
        noiter=.false.	!iterate solution if noiter is false
      elseif(ivs.eq.4)then
c D-soil WUS only
      myfi = dfi(istd(ifrc))
        s=Tfac(ifrc)
        T=perx(jstd(ifrc))
        if(s.ne.1.0)then
        fac(11:20)=s
        y=alog(s)
        y0=-y
        dy=0.055*(y-y0)
        do i=1,10
        fac(i)=s*exp(y0)
c        print *,i,fac(i),s,' i fac(i), s'
        y0=y0+dy
        enddo
        endif
c for the solved for periods. iterate solution always
        noiter=.false.	!iterate solution if noiter is false
      elseif(ivs.eq.0)then
c A-rock CEUS only
      myfi = infi(ifrc)
      else
      myfi=inf(ifrc)
      endif
            nhead= 308
            print *,myfi
      call openr(loc//myfi)
      call gethead(head,nhead,readn)
c------ get region parameters. From  header
        dx=head%extra(4)
        dy=head%extra(7)
        xmin=head%extra(2)
        xmax=head%extra(3)
        ymin=head%extra(5)
        ymax=head%extra(6)
c check period matchup. For soil only a few SA Ts have been computed by July 2008
	if(abs (T-head%period) .gt.0.002)stop'period mismatch in usa_sa'
        nx= nint((xmax-xmin)/dx) +1
        ny= nint((ymax-ymin)/dy) +1
        nrec= nx*ny
c I.V.: pull data from nearest grid point. No spatial interp. here.
        nxs=nint((xlon-xmin)/dx) + 1
        nys= nint((ymax-ylat)/dy)
        nsite=nys*nx+nxs
c        print *,nrec, xlon,ylat,nsite
        if(nxs.lt.0.or.nys.lt.0)stop'site outside of available grid'
      if(nsite.gt.nrec)stop 'site SE of study area, Cuba? PR?'
       nlev= head%nlev
       iskip= 4*(nsite-1)*nlev+nhead
c Skip (bytes) to the site whose location was given. From beginning of
c file, thus header as well as data need to be skipped.
c
c For skipping (lseek) the less frequently used getbuf3 is appropriate here
      erate=1e-21
c  erate needs to be initialized 
      call getbuf3(erate,nlev,readn,iskip)
c      print *,erate
      if(readn.lt.nlev)print *,'Read failed ',readn,' expected ',nlev
c      call closeio(name)
	call close(name)
	if(erate(1).lt.ann)then
	saout=head%xlev(1)
	return
	endif
	i=2
	dowhile(erate(i).gt.ann)
	i=i+1
	if(i.gt.nlev)then
c 2008: try log-log extrapolation. Result possibly too large because of clamps	
	y1=alog(erate(nlev-1))
	y2=alog(erate(nlev))-y1
	x1=alog(fac(nlev-1)*head%xlev(nlev-1))
	x2=alog(fac(nlev)*head%xlev(nlev))
	hanna=alog(ann)
	saout=exp(x1+(x2-x1)*(hanna-y1)/y2)
c 2002 estimate used the max sampled GM (SA). For longer return times, we can do better.
	noiter = .false.
c Extrapolated values should not be the final answer.
	return
	endif
	enddo
c ann is between erate(i-1) and erate(i). log-log interpolation is usually superior to
c linear.
	y1=alog(erate(i-1))
	y2=alog(erate(i))-y1
	x1=alog(fac(i-1)*head%xlev(i-1))
c soil-site curve may need adjustment for unavailable periods. Otherwise fac==1
	x2=alog(fac(i)*head%xlev(i))
	hanna=alog(ann)
c	if(ifrc.eq.8)print *,y1,y2,x1,x2,hanna,saout
	saout=exp(x1+(x2-x1)*(hanna-y1)/y2)
	return
	end subroutine usa_sa
	

      logical function LXYIN_WUS (X,Y)
c Is point (X,Y) inside the (unclosed) polygon (PX,PY)?
c Is point (QLN,QLT) inside the wus in this instance
c See "Application of the winding-number algorithm...",
c  by Godkin and Pulli, BSSA, pp. 1845-1848, 1984.
c LXYIN= .true. if (X,Y) is inside or on polygon, .false. otherwise.
c Written by C. Mueller, USGS.
	parameter(n=52)
      dimension PX(N),PY(N)
	px=(/
     + -126.,-113.70,-113.35,-112.20,-110.90,-110.45,-110.00,
     + -110.10,
     + -109.90,
     + -109.85,
     + -110.28,
     + -110.72,
     + -110.70,
     + -111.00,
     + -111.50,
     + -111.60,
     + -111.40,
     + -110.90,
     + -110.90,
     + -111.50,
     + -111.35,
     + -111.00,
     + -110.25,
     + -109.70,
     + -109.30,
     + -109.00,
     + -108.45,
     + -107.60,
     + -107.15,
     + -106.90,
     + -106.85,
     + -107.00,
     + -107.55,
     + -107.75,
     + -107.80,
     + -107.50,
     + -106.25,
     + -105.90,
     + -105.55,
     + -105.20,
     + -104.90,
     + -104.85,
     + -105.00,
     + -105.20,
     + -105.55,
     + -105.55,
     + -105.35,
     + -104.50,
     + -102.10,
     + -101.00,
     + -101.,-126./)
	py=(/
     + 50.,50.00,49.00,47.55,46.45,45.75,45.50,44.90,
     + 44.55,
     + 44.15,
     + 43.17,
     + 42.18,
     + 39.55,
     + 39.40,
     + 38.50,
     + 37.95,
     + 37.45,
     + 37.05,
     + 36.80,
     + 36.20,
     + 35.70,
     + 35.25,
     + 34.80,
     + 34.55,
     + 34.55,
     + 34.70,
     + 35.00,
     + 35.50,
     + 35.90,
     + 36.25,
     + 36.65,
     + 37.00,
     + 37.30,
     + 37.55,
     + 37.85,
     + 38.40,
     + 38.55,
     + 38.30,
     + 38.05,
     + 37.80,
     + 37.45,
     + 37.00,
     + 36.00,
     + 35.00,
     + 34.35,
     + 33.85,
     + 33.25,
     + 31.70,29.60,29.20,24.6,24.6/)
      LXYIN_WUS= .true.
      KSUM= 0
      do 1 I=1,N-1
        K= KPSCR(PX(I)-X,PY(I)-Y,PX(I+1)-X,PY(I+1)-Y)
        if (K.eq.4) return
        KSUM= KSUM+K
1       continue
      K= KPSCR(PX(N)-X,PY(N)-Y,PX(1)-X,PY(1)-Y)
      if (K.eq.4) return
      KSUM= KSUM+K
      if (KSUM.eq.0) LXYIN_WUS= .false.
      return
      end

      integer function KPSCR (X1,Y1,X2,Y2)
c Compute the signed crossing number of the segment from (X1,Y1) to (X2,Y2).
c See "Application of the winding-number algorithm...",
c  by Godkin and Pulli, BSSA, pp. 1845-1848, 1984.
c KPSCR= +4 if segment passes through the origin
c        +2 if segment crosses -x axis from below
c        +1 if segment ends on -x axis from below or starts up from -x axis
c         0 if no crossing
c        -1 if segment ends on -x axis from above or starts down from -x axis
c        -2 if segment crosses -x axis from above
c Written by C. Mueller, USGS.
      KPSCR= 0
      if (Y1*Y2.gt.0.) return
      if (X1*Y2.eq.X2*Y1.and.X1*X2.le.0.) then
        KPSCR= 4
      elseif (Y1*Y2.lt.0.) then
        if (Y1.lt.0..and.X1*Y2.lt.X2*Y1) KPSCR= +2
        if (Y1.gt.0..and.X1*Y2.gt.X2*Y1) KPSCR= -2
      elseif (Y1.eq.0..and.X1.lt.0.) then
        if (Y2.lt.0.) KPSCR= -1
        if (Y2.gt.0.) KPSCR= +1
      elseif (Y2.eq.0..and.X2.lt.0.) then
        if (Y1.lt.0.) KPSCR= +1
        if (Y1.gt.0.) KPSCR= -1
      endif
      return
      end


