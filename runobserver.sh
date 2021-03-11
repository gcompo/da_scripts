#!/bin/sh
#SBATCH -q debug
#SBATCH -t 00:30:00
#SBATCH -A gsienkf
#SBATCH -N 10    
#SBATCH -J observer
#SBATCH -e observer.err
#SBATCH -o observer.out

export gsi_control_threads=2
export NODES=$SLURM_NNODES
export corespernode=$SLURM_CPUS_ON_NODE
export machine='hera'
export cores=`expr $NODES \* $corespernode`
echo "running on $machine using $NODES nodes and $cores CORES"
export RUN='gdas'
export RES='192'
export basedir=/scratch2/BMC/gsienkf/${USER}
export datadir=$basedir
export exptname="C${RES}_hybgain_hourly"
export obs_datapath=/scratch1/NCEPDEV/global/glopara/dump # for sst,snow,ice grib
source $MODULESHOME/init/sh
module purge
module load intel/18.0.5.274
module load impi/2018.0.4 
module use -a /scratch1/NCEPDEV/global/gwv/lp/lib/modulefiles
module load netcdfp/4.7.4
module use -a /scratch1/NCEPDEV/nems/emc.nemspara/soft/modulefiles
module load hdf5_parallel/1.10.6
export datapath="${datadir}/${exptname}"
export logdir="${datadir}/logs/${exptname}"
export NOSAT="NO" # if yes, no radiances assimilated
export NOCONV="NO"
export NOTLNMC="NO" # no TLNMC in GSI in GSI EnVar
export NOOUTERLOOP="NO" # no outer loop in GSI EnVar
# model NSST parameters contained within nstf_name in FV3 namelist
# (comment out to get default - no NSST)
# nstf_name(1) : NST_MODEL (NSST Model) : 0 = OFF, 1 = ON but uncoupled, 2 = ON and coupled
export DONST="YES"
export NST_MODEL=2
# nstf_name(2) : NST_SPINUP : 0 = OFF, 1 = ON,
export NST_SPINUP=0 # (will be set to 1 if cold_start=='true')
# nstf_name(3) : NST_RESV (Reserved, NSST Analysis) : 0 = OFF, 1 = ON
export NST_RESV=0
# nstf_name(4,5) : ZSEA1, ZSEA2 the two depths to apply vertical average (bias correction)
export ZSEA1=0
export ZSEA2=0
export NSTINFO=0          # number of elements added in obs. data array (default = 0)
export NST_GSI=3          # default 0: No NST info at all;
                          #         1: Input NST info but not used in GSI;
                          #         2: Input NST info, used in CRTM simulation, no Tr analysis
                          #         3: Input NST info, used in both CRTM simulation and Tr analysis

# turn off NST
export DONST="NO"
export NST_MODEL=0
export NST_GSI=0

if [ $NST_GSI -gt 0 ]; then export NSTINFO=4; fi
if [ $NOSAT == "YES" ]; then export NST_GSI=0; fi # don't try to do NST in GSI without satellite data

export LEVS=64   
if [ $LEVS -eq 64 ]; then
  export nsig_ext=12
  export gpstop=50
  export GRIDOPTS="nlayers(63)=3,nlayers(64)=6,"
elif [ $LEVS -eq 127 ]; then
  export nsig_ext=56
  export gpstop=55
  export GRIDOPTS="nlayers(63)=1,nlayers(64)=1,"
else
  echo "LEVS must be 64 or 127"
  exit 1
fi

# radiance thinning parameters for GSI
export dmesh1=145
export dmesh2=145
export dmesh3=100

# resolution dependent model parameters
if [ $RES -eq 384 ]; then
   export JCAP=766
   export LONB=1536
   export LATB=768
elif [ $RES -eq 192 ]; then
   export JCAP=382 
   export LONB=768   
   export LATB=384  
elif [ $RES -eq 128 ]; then
   export JCAP=254 
   export LONB=512   
   export LATB=256  
elif [ $RES -eq 96 ]; then
   export JCAP=188 
   export LONB=384   
   export LATB=190  
elif [ $RES -eq 48 ]; then
   export JCAP=94
   export LONB=192   
   export LATB=96   
else
   echo "model parameters for ensemble resolution C$RES not set"
   exit 1
fi
# analysis is done at ensemble resolution
export LONA=$LONB
export LATA=$LATB      

export FHMIN=3
export FHMAX=9
export FHOUT=1
export ANALINC=6
# Analysis increments to zero out
export INCREMENTS_TO_ZERO="'liq_wat_inc','icmr_inc'"
# Stratospheric increments to zero
export INCVARS_ZERO_STRAT="'sphum_inc','liq_wat_inc','icmr_inc'"
export INCVARS_EFOLD="5"
export write_fv3_increment=".false." # if .false., increments are calculated using calc_increment_ncio.x in run_fv3.sh
export WRITE_INCR_ZERO="incvars_to_zero= $INCREMENTS_TO_ZERO,"
export WRITE_ZERO_STRAT="incvars_zero_strat= $INCVARS_ZERO_STRAT,"
export WRITE_STRAT_EFOLD="incvars_efold= $INCVARS_EFOLD,"
export use_correlated_oberrs=".true."
export enkfscripts="${basedir}/scripts/${exptname}"
export homedir=$enkfscripts
export incdate="${enkfscripts}/incdate.sh"
export rungsi='run_gsi_4densvar.sh'

export python=/contrib/anaconda/2.3.0/bin/python
export fv3gfspath=/scratch1/NCEPDEV/global/glopara
export FIXFV3=${fv3gfspath}/fix_nco_gfsv16/fix_fv3_gmted2010
export FIXGLOBAL=${fv3gfspath}/fix_nco_gfsv16/fix_am
export gsipath=/scratch1/NCEPDEV/global/glopara/git/global-workflow/gfsv16b/sorc/gsi.fd
export fixgsi=${gsipath}/fix
export fixcrtm=/scratch2/NCEPDEV/nwprod/NCEPLIBS/fix/crtm_v2.3.0
export execdir=${enkfscripts}/exec_hera
export gsiexec=${execdir}/global_gsi
export ANAVINFO=${fixgsi}/global_anavinfo.l${LEVS}.txt
export ANAVINFO_ENKF=${ANAVINFO}
export HYBENSINFO=${fixgsi}/global_hybens_info.l${LEVS}.txt # only used if readin_beta or readin_localization=T
# comment out next line to disable smoothing of ensemble perturbations
# in stratosphere/mesosphere
#export HYBENSMOOTHINFO=${fixgsi}/global_hybens_smoothinfo.l${LEVS}.txt
export OZINFO=${fixgsi}/global_ozinfo.txt
export CONVINFO=${fixgsi}/global_convinfo.txt
export SATINFO=${fixgsi}/global_satinfo.txt
export NLAT=$((${LATA}+2))

export charnanal='ensmean' 
export charnanal2='ensmean2' 
export lobsdiag_forenkf='.false.'
export skipcat="false"

export cleanup_observer="true"
export analdate=2020031612
export nitermax=1
while [ $analdate -le 2020031818 ]; do
   export yr=`echo $analdate | cut -c1-4`
   export mon=`echo $analdate | cut -c5-6`
   export day=`echo $analdate | cut -c7-8`
   export hr=`echo $analdate | cut -c9-10`
   export analdatem1=`${incdate} $analdate -4`
   export analdatep1=`${incdate} $analdate 6`
   export hrp1=`echo $analdatep1 | cut -c9-10`
   export hrm1=`echo $analdatem1 | cut -c9-10`
   export datapath2="${datapath}/${analdate}/"
   export datapathm1="${datapath}/${analdatem1}/"
   export datapathp1="${datapath}/${analdatep1}/"
   export current_logdir="${datapath2}/logs"
   export PREINP="${RUN}.t${hr}z."
   export PREINP1="${RUN}.t${hrp1}z."
   export PREINPm1="${RUN}.t${hrm1}z."
   echo "$analdate run gsi observer with `printenv | grep charnanal` `date`"
   sh ${enkfscripts}/run_gsiobserver.sh > ${current_logdir}/run_gsi_observer2.out 2>&1
   # once observer has completed, check log files.
   gsi_done=`cat ${current_logdir}/run_gsi_observer.log`
   if [ $gsi_done == 'yes' ]; then
     echo "$analdate gsi observer completed successfully `date`"
   else
     echo "$analdate gsi observer did not complete successfully, exiting `date`"
     exit 1
   fi
   export analdate=`$incdate $analdate $ANALINC`
done