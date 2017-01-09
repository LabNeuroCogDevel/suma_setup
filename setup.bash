#!/usr/bin/env bash

# defines views for suma
specFile="/mnt/v1/home/foranw/afni/suma_demo/suma_mni/N27_both.spec"

# on will's computer we need to talk to afni using this
t1="/mnt/v1/home/foranw/afni/suma_demo/suma_mni/warped+tlrc"

# but to make sure we are drawing on a brain in afni, use this as the display
# (has no affect on suma)
mnit1="/mnt/v1/home/foranw/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c.nii"

# on other machines it is probably safe to do
# t1=$mnit1

filetoafni(){
 basename  $(echo $1|sed 's/nii$/nii.gz/') |
 sed 's/.\(BRIK\|BRIK.gz\|HEAD\)$//i'
}

afni_set_range(){
  plugout_drive -com 'SET_THRESHOLD A.10 2' -quit
  plugout_drive -com 'SET_FUNC_RANGE 50' -quit
}

setup_afni(){
  echo "you probably need to click the 'overlaly' or 'underlay' button so afni will read in the datasets"
  echo "THEN RUN: "
  cat <<HEREDOC
  plugout_drive -com "SWITCH_UNDERLAY $(filetoafni $mnit1)"    -quit
  plugout_drive -com "SWITCH_OVERLAY fullcoverage_taskconstrained_aos"  -quit
  plugout_drive -com "SET_SUBBRICKS -1 4 4" -quit

  afni_set_range


HEREDOC
}

setup_record(){
  plugout_drive -com "SWITCH_UNDERLAY $(basename $t1)"    -quit
  # start talking
  DriveSuma -echo_edu   -com  viewer_cont -key t
  # start recorder and move screen around a bit so we have a recorder window
  DriveSuma -echo_edu   -com  viewer_cont -key R -key ctrl+right -key ctrl+left
}

#DriveSuma -echo_edu  -com  viewer_cont -switch_surf lh_inflated

# left  inflated is 2 away from standard display 
# right inflated is 10 away from standard display
# take shots of medial and lateral views of each
go_to_left() {
  DriveSuma -echo_edu  -com  viewer_cont -key SPACE -key:r2 . -key ctrl+left
  DriveSuma -echo_edu  -com  recorder_cont -save_as ${1}left_lat.jpg 
  DriveSuma -echo_edu  -com  viewer_cont -key SPACE -key:r2 . -key ctrl+right
  DriveSuma -echo_edu  -com  recorder_cont -save_as ${1}left_med.jpg 
}

go_to_right() {
  DriveSuma -echo_edu  -com  viewer_cont -key SPACE -key:r10 . -key ctrl+left
  DriveSuma -echo_edu  -com  recorder_cont -save_as ${1}right_med.jpg 
  DriveSuma -echo_edu  -com  viewer_cont -key SPACE -key:r10 . -key ctrl+right
  DriveSuma -echo_edu  -com  recorder_cont -save_as ${1}right_lat.jpg 
}



launch_both(){
   suma -niml -spec $specFile -sv $t1 &
   afni  -niml -yesplugouts -dset $t1 $mnit1 $(find -maxdepth 1 -type f -iname '*HEAD' -or -iname '*.nii*') &
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
doit(){
 launch_both
 sleep 20
 setup_record
 sleep 30
 afni_set_range
 setup_afni
 sleep 2

 echo -e "\n\n=== WAITING FOR YOU (to do above and push enter)  ===\n"
 echo "ready?"
 read

 go_to_left  $1
 go_to_right $1


 for img in ${1}{left,right}_{lat,med}.jpg; do
   [ -r $img ] && make_black_alpha  $img
 done
}
