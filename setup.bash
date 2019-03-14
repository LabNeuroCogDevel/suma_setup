#!/usr/bin/env bash

# where is suma_mni 
# http://afni.nimh.nih.gov/pub/dist/tgz/suma_MNI_N27.tgz
SUMADIR="/mnt/v1/home/foranw/afni/suma_demo/suma_mni"

# MNI brains
MNI09c="/opt/ni_tools/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c.nii"
MNI06="/opt/ni_tools/standard/fsl_mni152/MNI152_T1_3mm.nii"

# defines views for suma
specFile="$SUMADIR/N27_both.spec"
t1="$SUMADIR/warped+tlrc"

# suma size
WSIZE=(800 600)

# ergonomic forms 
DriveAFNI(){ plugout_drive -com "$*" -quit;  }
# DriveSUMA(){ DriveSuma -echo_edu   -com  $@; }


# basename and use HEAD instead of BRIK or BRIK.gz
filetoafni(){
   basename  $1 | sed 's/.\(BRIK\|BRIK.gz\|HEAD\)$//i'
   # 's/nii$/nii.gz/' # at one point .nii wouldn't work but .nii.gz would
}


afni_set_range(){
   DriveAFNI SET_THRESHOLD A.10 2 # p = .01
   DriveAFNI SET_FUNC_RANGE 50    # scale bar max at 50
}

# 30 5 2 # funcrange is 30, threshold is  5*10^(2-1) (p=50)
afni_set_range_(){
   max_color=$1; shift
   thres=$1; shift
   [ -n "$1" ] && log=$1 || log=0
   DriveAFNI SET_FUNC_RANGE  $max_color
   DriveAFNI SET_THRESHOLD A.$thres $log
}

setup_afni(){
  echo "you probably need to click the 'overlaly' or 'underlay' button so afni will read in the datasets"
  echo "THEN RUN: "
  cat <<HEREDOC
  plugout_drive -com "SWITCH_UNDERLAY $(filetoafni $MNI09c)"    -quit
  plugout_drive -com "SWITCH_OVERLAY fullcoverage_taskconstrained_aos"  -quit
  plugout_drive -com "SET_SUBBRICKS -1 4 4" -quit

  afni_set_range

HEREDOC
}

afni_suma_talk(){
   DriveAFNI SWITCH_UNDERLAY $(basename $t1)
   # start talking
   DriveSuma -echo_edu -com  viewer_cont -key t
}

suma_global_record(){
   # dont use me
   # maybe use individual keys to record
   # start recorder and move screen around a bit so we have a recorder window
   DriveSuma -echo_edu   -com  viewer_cont -key R -key ctrl+right -key ctrl+left
}

#DriveSuma -echo_edu  -com  viewer_cont -switch_surf lh_inflated

# left  inflated is 2 away from standard display 
# right inflated is 10 away from standard display
# take shots of medial and lateral views of each

goto_view(){
   ctrlr=$1; shift
   n=$1; shift
   dir=$1; shift
   img=$1; shift
   # reset controler
   DriveSuma -echo_edu -com viewer_cont -viewer $ctrlr -viewer_size ${WSIZE[@]} -key SPACE
   # repeat . however many times to get to the view we want. and spin in the direction we want
   DriveSuma -echo_edu -com viewer_cont -viewer $ctrlr -key:r$n . -key ctrl+$dir
}
rec_view(){
   # send view to recorder
   DriveSuma -echo_edu -com viewer_cont -viewer $1 -key:r2 r
}

save_cur(){
   [[ ! "$1" =~ .jpg$ ]] && echo "save image should be .jpg" >&2 && return 1
   DriveSuma -echo_edu  -com  recorder_cont -save_as "${1}"
   mv ${1%.jpg}.*.jpg $1
   make_black_alpha $1
}

goto_l_med() { goto_view A 2 right; }
goto_l_lat() { goto_view B 2 left; }
goto_r_med() { goto_view C 10 left; }
goto_r_lat() { goto_view D 10 right; }



find_local_files(){
   find . -maxdepth 1 \( -type l -or -type f \) -iname '*HEAD' -or -iname '*.nii*'
}

afnimni() {
   afni  -niml -yesplugouts -com "SWITCH_UNDERLAY $(filetoafni $MNI09c)"  -dset $t1 $MNI09c $MNI06 $@ $(find_local_files) 
}

# waiting for suma to finish loading
# tries to connect (blocking until it does)
# command when connected sets first control to expected size -- something that shouldn't mess anything
wait_for_suma(){ DriveSuma -echo_edu -com viewer_cont -viewer A -viewer_size ${WSIZE[@]} || return 1; }

# launch n controlers -- each one will have a different view
suma_ncontrols(){
   [ -z "$1" ] && n=4 || n=$1
   # already have A, so start from 2
   for n in $(seq 2 $n); do
      DriveSuma -com viewer_cont -key ctrl+n  || return 1
   done
}

sumamni() {
   suma -niml -spec $specFile -sv $t1
}
launch_both() {
   afnimni &
   sumamni &
}

make_black_alpha() {
  input=$1
  # check input exists
  [ -z "$input" -o ! -r "$input" ] && echo "$FUNCNAME: no input file '$input'" >&2 && return 1

  # what to save as
  output=$(basename $1 .jpg)_alpha.png
  # use imagemagick to remove black and replace with alpha
  convert $input \
    -alpha set -channel alpha \
    -fuzz 18% -fill none \
    -floodfill +0+0 black $output
}



# do all of these
# optional first argument is prefix for output jpg
setup_both(){
   launch_both      # forks over, both running in background
   wait_for_suma    # block until suma is up and running
   suma_ncontrols 4 # launch controls for each view
   afni_suma_talk   # push t on suma
   wait_for_suma    # block until suma is responsive again
   # setup views
   goto_l_med
   goto_l_lat
   goto_r_med
   goto_r_lat
}
save_all_views(){
   rec_view A && sleep .5 && save_cur ${1}_l_med.jpg
   rec_view B && sleep .5 && save_cur ${1}_l_lat.jpg
   rec_view C && sleep .5 && save_cur ${1}_r_med.jpg
   rec_view D && sleep .5 && save_cur ${1}_r_lat.jpg
}

doit() {
   ! (pgrep afni && pgrep suma) && setup_both
   DriveAFNI SWITCH_UNDERLAY $(filetoafni $MNI09c)

   # example
   afni_set_range_ 30 .05 0 # color max at 30, thres at .05*10^0 (p=.05)


   # maybe iterate over files or over subbrick coef/ttest pairs
   #DriveAFNI SWITCH_OVERLAY fullcoverage_taskconstrained_aos
   #DriveAFNI SET_SUBBRICKS -1 4 4

   # save something
   DriveAFNI SWITCH_OVERLAY $(filetoafni $MNI09c)
   DriveAFNI SET_SUBBRICKS -1 0 0 # -1 = no change, 
   # save all view with "test" prefix
   save_all_views "./test"

}
